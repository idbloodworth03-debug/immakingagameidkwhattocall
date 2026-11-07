"""The material library every animal shares, and the standard studio
lighting (look.json "materials" and "studio"; the style guide is in
docs/ART_DIRECTION.md).

Hero renders (card portraits, cage reveals, the VS screen) use the full
materials: groomed fur strands, feather cards, domed scales, shell plates,
soft skin, ridged horn, glossy claws and glossy eyes with a catchlight.
Every one is built from a base color in our bold palette: the library adds
the craftsmanship (root-to-tip shading, clumps, grooves, gloss), never pale
or washed-out color.
"""
import json
import math
import os

import bpy
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
LOOK = json.load(open(os.path.join(HERE, "look.json")))
MAT = LOOK["materials"]


def hex_rgb(h):
    h = h.lstrip("#")
    return [int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]


def linear(c):
    return [x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c]


def rgba(h):
    return tuple(linear(hex_rgb(h)) + [1.0])


def shade(color, k):
    """`color` (linear rgba) darker (k > 0) or lighter (k < 0)."""
    c = np.asarray(color[:3], float)
    c = c * (1.0 - k) if k > 0 else c + (1.0 - c) * (-k)
    return tuple(list(c) + [1.0])


# --- Lighting -------------------------------------------------------------------------

def studio_lights(target=(0.0, 0.0, 0.45), scale=1.0):
    """The standard rig (look.json "studio"): soft key, cool fill, rim, sky.
    `scale` grows the rig for a bigger subject."""
    st = LOOK["studio"]
    for name in ("key", "fill", "rim"):
        spec = st[name]
        light = bpy.data.lights.new(name, "AREA")
        light.shape = "DISK"
        light.size = spec["size"] * scale
        light.energy = spec["energy"] * scale * scale
        light.color = spec["color"]
        obj = bpy.data.objects.new(name, light)
        obj.location = [x * scale for x in spec["location"]]
        bpy.context.scene.collection.objects.link(obj)
        _aim(obj, target)
    world = bpy.context.scene.world or bpy.data.worlds.new("world")
    bpy.context.scene.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    bg.inputs["Color"].default_value = tuple(st["sky"]["color"]) + (1.0,)
    bg.inputs["Strength"].default_value = st["sky"]["strength"]
    bpy.context.scene.view_settings.exposure = st.get("exposure", 0.0)


def _aim(obj, target):
    """Points a light (down its -Z axis) at `target`."""
    from mathutils import Vector
    d = Vector(target) - Vector(obj.location)
    obj.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()


# --- Node helpers ---------------------------------------------------------------------

def _new_material(name):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    return m, nt, out


def _principled(nt):
    b = nt.nodes.new("ShaderNodeBsdfPrincipled")
    return b


def _math(nt, op, a, b=None, clamp=False):
    n = nt.nodes.new("ShaderNodeMath")
    n.operation = op
    n.use_clamp = clamp
    _feed(nt, n.inputs[0], a)
    if b is not None:
        _feed(nt, n.inputs[1], b)
    return n.outputs[0]


def _feed(nt, socket, value):
    if hasattr(value, "is_output") or isinstance(value, bpy.types.NodeSocket):
        nt.links.new(value, socket)
    else:
        socket.default_value = value


def _mix_color(nt, factor, a, b):
    n = nt.nodes.new("ShaderNodeMix")
    n.data_type = "RGBA"
    _feed(nt, n.inputs["Factor"], factor)
    _feed(nt, n.inputs[6], a)
    _feed(nt, n.inputs[7], b)
    return n.outputs[2]


def _bump(nt, height, strength, distance=0.01):
    b = nt.nodes.new("ShaderNodeBump")
    b.inputs["Strength"].default_value = strength
    b.inputs["Distance"].default_value = distance
    nt.links.new(height, b.inputs["Height"])
    return b.outputs["Normal"]


# --- Fur ------------------------------------------------------------------------------

def fur_material(color, kind="short", color_attribute=None, groom=None, deep=None):
    """Hair strands: darker at the root, lighter at the tip, each strand a
    shade different (look.json materials.fur.<kind>). With
    `color_attribute`, each strand takes its color from the skin's paint
    where it grows (a tiger's stripes) instead of one `color`."""
    f = dict(MAT["fur"][kind], **(groom or {}))
    m, nt, out = _new_material("fur_" + kind)
    info = nt.nodes.new("ShaderNodeHairInfo")
    ramp = _math(nt, "POWER", info.outputs["Intercept"], 0.6)
    if color_attribute:
        attr = nt.nodes.new("ShaderNodeVertexColor")
        attr.layer_name = color_attribute
        base = attr.outputs["Color"]
        # Root: the paint darker (or toward its `deep` shade); tip: lighter.
        root = _mix_color(nt, f["root_darken"], base, deep or (0.0, 0.0, 0.0, 1.0))
        tip = _mix_color(nt, f["tip_lighten"], base, (1.0, 1.0, 1.0, 1.0))
        col = _mix_color(nt, ramp, root, tip)
        var = _math(nt, "MULTIPLY", _math(nt, "SUBTRACT", info.outputs["Random"], 0.5), f["variation"] * 2.0)
        col = _mix_color(nt, _math(nt, "ABSOLUTE", var), col, (0.0, 0.0, 0.0, 1.0))
    else:
        root = shade(color, f["root_darken"])
        tip = shade(color, -f["tip_lighten"])
        col = _mix_color(nt, ramp, root, tip)
        # A little per-strand variation.
        var = _math(nt, "MULTIPLY", _math(nt, "SUBTRACT", info.outputs["Random"], 0.5), f["variation"] * 2.0)
        col = _mix_color(nt, _math(nt, "ABSOLUTE", var), col, shade(color, 0.25 if f["variation"] > 0 else 0))
    if f.get("shading") == "soft":
        # Soft solid fibres: the color as painted in the light, the sky's
        # color in the shade (a real hair shader grays light coats).
        b = _principled(nt)
        nt.links.new(col, b.inputs["Base Color"])
        b.inputs["Roughness"].default_value = f["hair_roughness"]
        b.inputs["Sheen Weight"].default_value = f.get("sheen", 0.5)
        b.inputs["Specular IOR Level"].default_value = 0.3
        nt.links.new(b.outputs[0], out.inputs["Surface"])
        return m
    hair = nt.nodes.new("ShaderNodeBsdfHairPrincipled")
    hair.parametrization = "COLOR"
    nt.links.new(col, hair.inputs["Color"])
    hair.inputs["Roughness"].default_value = f["hair_roughness"]
    hair.inputs["Radial Roughness"].default_value = 0.6
    hair.inputs["Coat"].default_value = f["coat"]
    nt.links.new(hair.outputs[0], out.inputs["Surface"])
    return m


def add_fur(obj, color, kind="short", density=1.0, weight_group=None, seed=0, comb=(0.0, 0.3, -1.0),
            color_attribute=None, length=None, groom=None, deep=None):
    """Groomed fur on `obj`: guide strands from the skin, combed down a
    little (droop), with child strands clumped round each guide. `groom`
    overrides any of the coat's settings (look.json materials.fur.<kind>)."""
    f = dict(MAT["fur"][kind], **(groom or {}))
    area = sum(p.area for p in obj.data.polygons) * (obj.scale[0] * obj.scale[1])
    mod = obj.modifiers.new("fur_" + kind, "PARTICLE_SYSTEM")
    ps = mod.particle_system
    ps.seed = seed
    s = ps.settings
    s.type = "HAIR"
    s.use_advanced_hair = True
    s.count = max(50, int(area * f["parents"] * density))
    hair_len = f["length"] if length is None else length
    s.hair_length = hair_len
    s.hair_step = 5
    # Mostly laid down along the comb direction (droop), standing up off
    # the skin only a little (normal): groomed, not a dandelion.
    s.normal_factor = hair_len * f.get("normal", 0.4)
    c = np.asarray(comb, float)
    c = c / (np.linalg.norm(c) + 1e-9) * hair_len * f["droop"]
    s.object_align_factor = tuple(c)
    s.use_hair_bspline = True
    # Interpolated children make an even coat; simple ones gather round
    # each guide into its own lock (a shaggy coat).
    s.child_type = f.get("child_type", "INTERPOLATED")
    s.child_percent = 6
    s.rendered_child_count = f["children"]
    s.child_radius = f.get("child_radius", 0.02)
    s.clump_factor = f["clump"]
    s.clump_shape = f["clump_shape"]
    s.roughness_1 = f["roughness"]
    s.roughness_endpoint = f["roughness"] * 0.5
    s.child_length = 1.0
    if f["kink"] > 0:
        s.kink = "CURL"
        s.kink_amplitude = f["kink"]
        s.kink_frequency = 3.0
    s.root_radius = f["root_mm"] / 1000.0
    s.tip_radius = f["tip_mm"] / 1000.0
    s.radius_scale = 1.0
    s.shape = 0.2
    s.use_close_tip = True
    if weight_group:
        ps.vertex_group_density = weight_group
        ps.vertex_group_length = weight_group
    s.material_slot = _slot(obj, fur_material(color, kind, color_attribute, groom, deep))
    _calibrate(obj, ps, hair_len)
    return ps


def _calibrate(obj, ps, length):
    """Blender grows long hair from launch speeds, not from its length
    setting: measure the longest strands and rescale them to `length`."""
    s = ps.settings
    for _ in range(3):
        dg = bpy.context.evaluated_depsgraph_get()
        evaluated = obj.evaluated_get(dg).particle_systems[ps.name]
        longest = []
        for p in evaluated.particles[:4000]:
            keys = np.array([tuple(h.co) for h in p.hair_keys])
            if len(keys) > 1:
                longest.append(np.linalg.norm(np.diff(keys, axis=0), axis=1).sum())
        if not longest:
            return
        scale = length / float(np.percentile(longest, 98))
        if abs(scale - 1) < 0.04:
            return
        s.normal_factor *= scale
        s.object_align_factor = tuple(v * scale for v in s.object_align_factor)


def _slot(obj, mat):
    obj.data.materials.append(mat)
    return mat.name


# --- Skin, scales, shell, horn, claws, eyes -----------------------------------------------

def skin_material(color, name="skin"):
    """Soft, a little translucent, faint mottling, a soft sheen."""
    k = MAT["skin"]
    m, nt, out = _new_material(name)
    b = _principled(nt)
    noise = nt.nodes.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = 18.0
    noise.inputs["Detail"].default_value = 3.0
    mot = _math(nt, "MULTIPLY", _math(nt, "SUBTRACT", noise.outputs["Fac"], 0.5), k["mottle"] * 2)
    col = _mix_color(nt, _math(nt, "ABSOLUTE", mot), color, shade(color, 0.3))
    nt.links.new(col, b.inputs["Base Color"])
    b.inputs["Roughness"].default_value = k["roughness"]
    b.inputs["Subsurface Weight"].default_value = k["subsurface"]
    b.inputs["Subsurface Scale"].default_value = k["subsurface_scale"]
    b.inputs["Sheen Weight"].default_value = k["sheen"]
    nt.links.new(b.outputs[0], out.inputs["Surface"])
    return m


def _voronoi(nt, scale, feature="F1"):
    v = nt.nodes.new("ShaderNodeTexVoronoi")
    v.feature = feature
    v.inputs["Scale"].default_value = scale
    return v


def scales_material(color, name="scales"):
    """Domed scales with deep grooves between, each a shade different."""
    k = MAT["scales"]
    m, nt, out = _new_material(name)
    b = _principled(nt)
    tex = nt.nodes.new("ShaderNodeTexCoord")
    scale = 1.0 / k["cell"]
    cells = _voronoi(nt, scale, "F1")
    edges = _voronoi(nt, scale, "DISTANCE_TO_EDGE")
    nt.links.new(tex.outputs["Object"], cells.inputs["Vector"])
    nt.links.new(tex.outputs["Object"], edges.inputs["Vector"])
    # Dome: high in each cell's middle, falling to a groove at its edge.
    groove = _math(nt, "MINIMUM", _math(nt, "DIVIDE", edges.outputs["Distance"], k["groove"]), 1.0)
    dome = _math(nt, "SUBTRACT", 1.0, _math(nt, "MULTIPLY", cells.outputs["Distance"], k["dome"]))
    height = _math(nt, "MULTIPLY", groove, dome)
    vary = nt.nodes.new("ShaderNodeSeparateColor")
    nt.links.new(cells.outputs["Color"], vary.inputs[0])
    var = _math(nt, "MULTIPLY", vary.outputs[0], k["shade_variation"] * 2.0)
    col = _mix_color(nt, var, color, shade(color, 0.3))
    # Grooves darker.
    col = _mix_color(nt, _math(nt, "SUBTRACT", 1.0, groove), col, shade(color, 0.6))
    nt.links.new(col, b.inputs["Base Color"])
    nt.links.new(_bump(nt, height, 0.7, 0.004), b.inputs["Normal"])
    b.inputs["Roughness"].default_value = k["roughness"]
    b.inputs["Coat Weight"].default_value = k["coat"]
    nt.links.new(b.outputs[0], out.inputs["Surface"])
    return m


def shell_material(color, name="shell"):
    """Big plates with growth rings and a waxy coat."""
    k = MAT["shell"]
    m, nt, out = _new_material(name)
    b = _principled(nt)
    tex = nt.nodes.new("ShaderNodeTexCoord")
    scale = 1.0 / k["cell"]
    cells = _voronoi(nt, scale, "F1")
    edges = _voronoi(nt, scale, "DISTANCE_TO_EDGE")
    for v in (cells, edges):
        nt.links.new(tex.outputs["Object"], v.inputs["Vector"])
    groove = _math(nt, "MINIMUM", _math(nt, "DIVIDE", edges.outputs["Distance"], k["groove"]), 1.0)
    rings = _math(nt, "SINE", _math(nt, "MULTIPLY", cells.outputs["Distance"], k["rings"] * math.pi * 2))
    ring_h = _math(nt, "MULTIPLY", rings, k["ring_depth"])
    height = _math(nt, "ADD", groove, ring_h)
    col = _mix_color(nt, _math(nt, "SUBTRACT", 1.0, groove), color, shade(color, 0.55))
    col = _mix_color(nt, _math(nt, "MULTIPLY", _math(nt, "ADD", rings, 1.0), 0.15), col, shade(color, -0.25))
    nt.links.new(col, b.inputs["Base Color"])
    nt.links.new(_bump(nt, height, 0.6, 0.006), b.inputs["Normal"])
    b.inputs["Roughness"].default_value = k["roughness"]
    b.inputs["Coat Weight"].default_value = k["coat"]
    nt.links.new(b.outputs[0], out.inputs["Surface"])
    return m


def horn_material(color, name="horn", axis_len=1.0, centered=False, tip_color=None, offset=0.0):
    """Ivory-to-dark-tip, fine ridges, satin shine. The horn runs up its
    object's Z axis from its origin, `axis_len` long; or, `centered`, over
    its whole length (a cone made round its middle). `tip_color`: the tip's
    own color instead of the base color darker."""
    k = MAT["horn"]
    m, nt, out = _new_material(name)
    b = _principled(nt)
    tex = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(tex.outputs["Generated" if centered else "Object"], sep.inputs[0])
    # `offset`: where the base is on the object's Z axis (a cone made round
    # its middle starts half its length down).
    along = sep.outputs["Z"] if centered else _math(nt, "DIVIDE", _math(nt, "ADD", sep.outputs["Z"], offset), axis_len)
    along = _math(nt, "MINIMUM", _math(nt, "MAXIMUM", along, 0.0), 1.0)
    col = _mix_color(nt, _math(nt, "POWER", along, k.get("tip_power", 1.6)), color, tip_color or shade(color, k["tip_darken"]))
    ridges = _math(nt, "SINE", _math(nt, "MULTIPLY", along, k["ridges"] * math.pi))
    nt.links.new(col, b.inputs["Base Color"])
    nt.links.new(_bump(nt, _math(nt, "MULTIPLY", ridges, k["ridge_depth"]), 0.4, 0.003), b.inputs["Normal"])
    b.inputs["Roughness"].default_value = k["roughness"]
    b.inputs["Coat Weight"].default_value = k["coat"]
    nt.links.new(b.outputs[0], out.inputs["Surface"])
    return m


def horn_mesh(length, radius, bend=40.0, tip=0.12, segments=20, sides=20, name="horn"):
    """A horn: a round tube tapering to a point (`tip` of the base radius),
    curving `bend` degrees over its length. Its base sits at the origin, it
    grows up +Z and curves toward +Y. Returns the object."""
    verts, faces = [], []
    bend_r = math.radians(max(bend, 0.01))
    arc = length / bend_r
    for i in range(segments + 1):
        t = i / segments
        a = bend_r * t
        # The centerline on an arc in the YZ plane.
        cy, cz = arc * (1 - math.cos(a)), arc * math.sin(a)
        ty, tz = math.sin(a), math.cos(a)          # along the arc
        ny, nz = tz, -ty                           # in-plane normal
        r = radius * (1 - (1 - tip) * t ** 1.3)
        for j in range(sides):
            phi = 2 * math.pi * j / sides
            x = r * math.cos(phi)
            k = r * math.sin(phi)
            verts.append((x, cy + ny * k, cz + nz * k))
    for i in range(segments):
        for j in range(sides):
            a0 = i * sides + j
            a1 = i * sides + (j + 1) % sides
            faces.append((a0, a1, a1 + sides, a0 + sides))
    verts.append((0.0, arc * (1 - math.cos(bend_r)), arc * math.sin(bend_r)))
    top = len(verts) - 1
    for j in range(sides):
        faces.append((segments * sides + j, segments * sides + (j + 1) % sides, top))
    me = bpy.data.meshes.new(name)
    me.from_pydata(verts, [], faces)
    for poly in me.polygons:
        poly.use_smooth = True
    obj = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def claw_material(name="claw"):
    k = MAT["claw"]
    m, nt, out = _new_material(name)
    b = _principled(nt)
    b.inputs["Base Color"].default_value = rgba(k["color"])
    b.inputs["Roughness"].default_value = k["roughness"]
    b.inputs["Coat Weight"].default_value = k["coat"]
    b.inputs["Coat Roughness"].default_value = 0.05
    nt.links.new(b.outputs[0], out.inputs["Surface"])
    return m


def eye_material(iris_color, name="eye", forward="-Y", radius=1.0):
    """A glossy cornea over the iris and a big pupil: the key light makes a
    crisp catchlight. The eye looks down its object's -Y axis, or its +Z
    axis with forward="+Z" (the creatures' eyes); `radius`: the eyeball's
    radius in its object's own space."""
    k = dict(MAT["eye"])
    k["iris"] *= radius
    k["pupil"] *= radius
    m, nt, out = _new_material(name)
    b = _principled(nt)
    tex = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(tex.outputs["Object"], sep.inputs[0])
    # Distance from the eye's front axis, on the front half only.
    a1, a2, ahead = ("X", "Z", "Y") if forward == "-Y" else ("X", "Y", "Z")
    r = _math(nt, "SQRT", _math(nt, "ADD", _math(nt, "MULTIPLY", sep.outputs[a1], sep.outputs[a1]),
                                 _math(nt, "MULTIPLY", sep.outputs[a2], sep.outputs[a2])))
    front = (_math(nt, "LESS_THAN", sep.outputs[ahead], 0.0) if forward == "-Y"
             else _math(nt, "GREATER_THAN", sep.outputs[ahead], 0.0))
    in_iris = _math(nt, "MULTIPLY", _math(nt, "LESS_THAN", r, k["iris"]), front)
    in_pupil = _math(nt, "MULTIPLY", _math(nt, "LESS_THAN", r, k["pupil"]), front)
    # Rays in the iris, and a darker ring round its edge.
    angle = _math(nt, "ARCTAN2", sep.outputs[a1], sep.outputs[a2])
    rays = _math(nt, "MULTIPLY", _math(nt, "ABSOLUTE", _math(nt, "SINE", _math(nt, "MULTIPLY", angle, 24.0))), k["iris_rays"])
    iris_col = _mix_color(nt, rays, iris_color, shade(iris_color, -0.35))
    rim = _math(nt, "GREATER_THAN", r, k["iris"] * 0.86)
    iris_col = _mix_color(nt, rim, iris_col, shade(iris_color, 0.55))
    col = _mix_color(nt, in_iris, rgba(k["sclera"]), iris_col)
    col = _mix_color(nt, in_pupil, col, (0.005, 0.005, 0.008, 1.0))
    nt.links.new(col, b.inputs["Base Color"])
    b.inputs["Roughness"].default_value = 0.4
    b.inputs["Coat Weight"].default_value = 1.0
    b.inputs["Coat Roughness"].default_value = k["coat_roughness"]
    nt.links.new(b.outputs[0], out.inputs["Surface"])
    return m


# --- Feathers ---------------------------------------------------------------------------

def feather_material(color, name="feather"):
    """Darker at the base, a pale edge, a stiff pale shaft down the middle
    (UV: u across the vane, 0-1; v along it, base to tip)."""
    k = MAT["feathers"]
    m, nt, out = _new_material(name)
    b = _principled(nt)
    uv = nt.nodes.new("ShaderNodeUVMap")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(uv.outputs["UV"], sep.inputs[0])
    u, v = sep.outputs["X"], sep.outputs["Y"]
    across = _math(nt, "ABSOLUTE", _math(nt, "SUBTRACT", u, 0.5))
    col = _mix_color(nt, _math(nt, "SUBTRACT", 1.0, v), color, shade(color, k["base_darken"]))
    col = _mix_color(nt, _math(nt, "POWER", _math(nt, "MULTIPLY", across, 2.0), 6.0), col, shade(color, -k["edge_lighten"]))
    shaft = _math(nt, "LESS_THAN", across, 0.03)
    col = _mix_color(nt, shaft, col, tuple(linear(k["shaft"])) + (1.0,))
    # Barbs: fine diagonal lines.
    barbs = _math(nt, "SINE", _math(nt, "MULTIPLY", _math(nt, "ADD", v, _math(nt, "MULTIPLY", across, 0.8)), 160.0))
    nt.links.new(col, b.inputs["Base Color"])
    nt.links.new(_bump(nt, _math(nt, "MULTIPLY", barbs, 0.5), 0.15, 0.002), b.inputs["Normal"])
    b.inputs["Roughness"].default_value = k["roughness"]
    b.inputs["Sheen Weight"].default_value = k["sheen"]
    nt.links.new(b.outputs[0], out.inputs["Surface"])
    return m


def feather_card(length, width, follow=0.5, segments=8):
    """One feather: a tapering card with a rounded tip, in its own space:
    base at the origin, running up +Y, lying in the XY plane, bending
    toward +Z (into the body) to follow a body `follow` meters round, with
    UVs (u across, v along)."""
    verts, uvs = [], []
    for i in range(segments + 1):
        t = i / segments
        # Widest a third of the way up, rounded at the tip.
        w = width * (0.35 + 0.65 * math.sin(math.pi * min(1.0, t * 1.15)) ** 0.7) * (1 - t ** 6)
        y = length * t
        # Bends into the body so the tip lies on it instead of sticking out.
        z = y * y / (2.0 * max(follow, 0.05))
        for side in (-1, 1):
            verts.append((side * w / 2, y, z + abs(side) * 0.0))
            uvs.append((0.5 + side * 0.5, t))
    faces = []
    for i in range(segments):
        a = i * 2
        faces.append((a, a + 1, a + 3, a + 2))
    return verts, faces, uvs


def scatter_feathers(points, normals, comb, color, size=None, tilt=None, jitter=None, seed=0, name="feathers", follow=0.5):
    """Feathers laid over a body like shingles: one card at each point,
    flat on the surface, pointing along `comb` (combed backward/down),
    lifted `tilt` degrees, sized and turned a little at random. Returns one
    mesh object."""
    k = MAT["feathers"]
    size = size or k["size"]
    tilt = math.radians(k["tilt"] if tilt is None else tilt)
    jitter = k["jitter"] if jitter is None else jitter
    rng = np.random.default_rng(seed)
    cv, cf, cu = feather_card(size[0], size[1], follow)
    cv = np.asarray(cv, float)
    all_v, all_f, all_uv = [], [], []
    comb = np.asarray(comb, float)
    for p, n in zip(points, normals):
        n = n / (np.linalg.norm(n) + 1e-9)
        t = comb - np.dot(comb, n) * n
        if np.linalg.norm(t) < 1e-4:
            t = np.cross(n, (1, 0, 0))
        t = t / np.linalg.norm(t)
        # Turn a little and lift off the body.
        ang = rng.normal(0, jitter)
        b = np.cross(n, t)
        t = t * math.cos(ang) + b * math.sin(ang)
        b = np.cross(n, t)
        lift = tilt * (1 + rng.normal(0, 0.2))
        up = t * math.cos(lift) + n * math.sin(lift)
        nn = np.cross(b, up)
        s = 1.0 + rng.normal(0, 0.12)
        basis = np.stack([b, up, nn], axis=1) * s
        base = len(all_v)
        all_v.extend(list((cv @ basis.T) + p))
        all_f.extend([tuple(i + base for i in f) for f in cf])
        all_uv.extend(cu)
    me = bpy.data.meshes.new(name)
    me.from_pydata([tuple(v) for v in all_v], [], all_f)
    uv = me.uv_layers.new(name="UVMap")
    for poly in me.polygons:
        for li in poly.loop_indices:
            uv.data[li].uv = all_uv[me.loops[li].vertex_index]
    me.materials.append(feather_material(color, name + "_mat"))
    for poly in me.polygons:
        poly.use_smooth = True
    obj = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(obj)
    return obj
