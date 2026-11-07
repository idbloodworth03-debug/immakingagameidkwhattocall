"""The animated-movie look (docs/ART_DIRECTION.md, "Style guide"): an animal
listed in movie.json is built this way instead of as a flat cartoon.

Its shape is the cartoon's (cartoon.py), with gentler proportions from its
design: a big, simple, appealing shape. On top of it:

  * eyes set into the face under a brow, with a colored iris, a big pupil
    and a glossy cornea that catches the key light (not big googly ones);
  * painted in the bold palette by body part: its fur, a deeper shade of it
    where the clumps part, bare skin (face, hands, feet) with its own
    deeper shade, glossy dark nails, horns;
  * for hero art (`dress`): real groomed fur strands (materials.py), skin,
    horn, nail and eye materials, the studio lights and no outline;
  * for the game's real-time models (`locks`): the same coat as sculpted
    fur clumps in the mesh, shaded root to tip, with the soft shadow between
    clumps baked in, many and fine for the 3D viewer, few and chunky for
    the battlefield.

    import movie
    if movie.wants("yeti"):
        creature = movie.load("yeti")
"""
import copy
import importlib
import json
import math
import os

import numpy as np

import cartoon
from anatomy import Extra
from sdf import ellipsoid, surface_point

HERE = os.path.dirname(os.path.abspath(__file__))
DESIGNS = json.load(open(os.path.join(HERE, "movie.json")))


def wants(species):
    return species in DESIGNS and not species.startswith("_")


def load(species):
    module = importlib.import_module(species)
    c = module.make()
    design = copy.deepcopy(DESIGNS[species])
    c.cartoon = dict(design["shape"])
    cartoon.cartoonify(c)
    c.style = "movie"
    c.design = design
    _face(c, design)
    _eyes(c, design["eyes"])
    if design.get("digits"):
        _digits(c, design["digits"])
    if design.get("paint") == "species":
        # The species' own markings (a falcon's helmet and barred breast),
        # in the bold palette: its colors swapped for the design's.
        if hasattr(module, "COLORS"):
            module.COLORS.update(design.get("palette", {}))
        c.bare_regions = set(design.get("bare", []))
        c.palette = dict(c.palette or {}, **design.get("face_lines", {}))
    else:
        _paint(c, design)
    _parts(c, design)
    return c


def _hex(h):
    from scene import hex_color
    return np.asarray(hex_color(h), float)


# --- Face -------------------------------------------------------------------------------

def _face(c, design):
    """Hides the ears in the fur if asked, and puts the nose and a carved
    grin on the face's actual surface."""
    if design.get("tail") is False:
        c.shapes = [s for s in c.shapes if s.region != "tail"]
    if design.get("ears") is False:
        ears = {b.name for b in c.bones if b.name.startswith("ear")}
        c.parts = [p for p in c.parts if p.get("bone") not in ears]
        c.shapes = [s for s in c.shapes if s.bone not in ears]
    if "skull" not in c.joints:
        return
    skull = c.joint("skull")
    k = design.get("muzzle")
    if k:
        d = np.asarray(k["dir"], float)
        d /= np.linalg.norm(d)
        r = np.asarray(k["radii"], float)
        p = surface_point(c.shapes, skull, d, sink=0.0)
        c.shapes.append(ellipsoid(tuple(p - d * r[1] * (1 - k["out"])), tuple(r), "face", "head", blend=0.025))
    k = design.get("nose")
    if k:
        d = np.asarray(k["dir"], float)
        d /= np.linalg.norm(d)
        r = np.asarray(k["radii"], float)
        c.extras = [e for e in c.extras if e.material != "nose"]
        p = surface_point(c.shapes, skull, d, sink=float(r[1]) * float(k["sink"]))
        c.extras.append(Extra("ellipsoid", "nose", "head", center=tuple(p), radii=tuple(r), direction=tuple(d)))
        c.nose = (p, float(r.max()))
    m = design.get("mouth")
    if m:
        from anatomy import add_mouth
        d = np.asarray(m["dir"], float)
        d /= np.linalg.norm(d)
        r = np.asarray(m["radii"], float)
        p = surface_point(c.shapes, skull, d, sink=float(r[1]) * float(m["inset"]))
        add_mouth(c, tuple(p), tuple(r))
        if m.get("smile"):
            # The corners turned up: a slab each side, tilted.
            tilt = math.radians(float(m["smile"]))
            for side in (1, -1):
                corner = p + np.array([side * m["corner"], -r[1] * 0.25, r[0] * 0.18])
                c.shapes.append(ellipsoid(tuple(corner), (r[0] * 0.55, r[1] * 0.9, r[2]), "mouth", "jaw",
                                          blend=0.01, roll=-side * tilt, subtract=True))


# --- Eyes -------------------------------------------------------------------------------

def _eyes(c, k):
    """The cartoon's googly eyes become eyes set into the face: sunk deeper,
    a colored iris, and a brow ridge above each one."""
    skull = c.joint("skull") if "skull" in c.joints else None
    eyes = []
    for e in [e for e in c.extras if e.material == "eye"]:
        d = np.asarray(e.direction, float)
        r = max(e.radii) / 1.05
        origin = skull if skull is not None else np.asarray(e.center) - d * r * 3
        p = surface_point(c.shapes, origin, d, sink=r * float(k["sink"]))
        sq = k.get("squash", (0.9, 1.0, 0.8))
        e.center = tuple(p)
        e.radii = (r * sq[0], r * sq[1], r * sq[2])
        e.pupil = "movie"
        e.color = k["iris"]
        eyes.append((p, r, d))
    c.eyes = [(p, r) for p, r, _ in eyes]
    # A brow over each eye: a soft ridge that shades it and carries the
    # expression.
    b = k.get("brow")
    if b:
        for p, r, d in eyes:
            up = np.array([0.0, 0.0, 1.0]) - d * d[2]
            up /= np.linalg.norm(up)
            center = p + up * r * float(k["brow_lift"]) + d * r * float(k["brow_forward"])
            # Part of the head, so a species' own paint covers it too.
            c.shapes.append(ellipsoid(tuple(center), (r * b[0], r * b[1], r * b[2]), "head", "head",
                                      blend=r * 0.8))


# --- Fingers and toes ----------------------------------------------------------------------

def _digits(c, k):
    """Fingers and toes grown out of the end of each paw, along its length,
    curling a little toward the palm, each with a glossy nail on its back."""
    from sdf import cone
    for spec in k.values():
        for paw in [s for s in c.shapes if s.region == spec["paw"] and s.kind == "cone"]:
            a, b = np.asarray(paw.a, float), np.asarray(paw.b, float)
            axis = (b - a) / np.linalg.norm(b - a)
            side = 1.0 if b[0] > 0 else -1.0
            # The palm faces in toward the body (hands) or down (feet).
            palm = np.array([-side, 0.0, 0.0]) if spec["palm"] == "in" else np.array([0.0, 0.0, -1.0])
            palm = palm - axis * (palm @ axis)
            palm /= np.linalg.norm(palm)
            width = np.cross(axis, palm)
            n = int(spec["count"])
            r0, r1 = spec["radius"]
            for i in range(n):
                off = (i - (n - 1) / 2) * spec["spacing"]
                # The middle fingers reach a little further.
                reach = spec["length"] * (1.0 - 0.18 * abs(off) / max(spec["spacing"] * n / 2, 1e-6))
                base = b + width * off - axis * paw.rb * 0.35
                tip = base + axis * (paw.rb * 0.35 + reach) + palm * reach * spec["curl"]
                c.shapes.append(cone(tuple(base), tuple(tip), r0, r1, spec["paw"], paw.bone, blend=0.01))
                # The nail: on the finger's end, on the back of it.
                d = (tip - base) / np.linalg.norm(tip - base)
                nr, nl = spec["nail"]
                start = tip - d * nl * 0.55 - palm * r1 * 0.45
                c.extras.append(Extra("cone", "claw", paw.bone, center=tuple(start),
                                      tip=tuple(start + d * nl + palm * nl * 0.25), radius=nr, tip_radius=nr * 0.35))


# --- Paint ------------------------------------------------------------------------------

def _paint(c, design):
    """Bold palette by body part: fur with a deeper shade low down and
    between clumps, bare skin with its own deeper shade, and the mouth."""
    col = design["colors"]
    bare_regions = set(design.get("bare", []))
    fur, fur_deep = _hex(col["fur"]), _hex(col["fur_deep"])
    skin, skin_deep = _hex(col["skin"]), _hex(col["skin_deep"])

    face = design.get("face")
    skull = c.joint("skull") if "skull" in c.joints else None

    def face_weight(mesh):
        """The bare face: the front of the head, round the eyes and down to
        the chin, framed by the fur hood."""
        if not face or skull is None:
            return np.zeros(len(mesh.verts))
        head = np.zeros(len(mesh.verts))
        for r in face["regions"]:
            try:
                head = np.maximum(head, mesh.region_weight(r))
            except (ValueError, IndexError):
                pass
        to = mesh.verts - skull
        to /= np.maximum(np.linalg.norm(to, axis=1, keepdims=True), 1e-9)
        fwd = np.asarray(face["forward"], float)
        fwd /= np.linalg.norm(fwd)
        front = np.clip((to @ fwd - face["from"]) / (face["to"] - face["from"]), 0, 1)
        if "below" in face:
            # The chin and throat keep their fur.
            front *= np.clip((to[:, 2] - face["below"]) / 0.08, 0, 1)
        return np.clip(head * 2.0, 0, 1) * front

    c.face_weight = face_weight

    def painted(mesh, creature):
        if design.get("surface", "fur") != "fur":
            # No coat: the skin's colors everywhere (the species' own paint,
            # in the bold palette, if it keeps one).
            return _skin_paint(mesh, creature, design)
        bare = np.maximum(_bare_weight(mesh, bare_regions), face_weight(mesh))
        v = mesh.verts
        lo, hi = v[:, 2].min(), v[:, 2].max()
        low = np.clip((hi - v[:, 2]) / max(hi - lo, 1e-6), 0, 1) ** 2
        k = float(design.get("shade_low", 0.3))
        coat = fur[None, :] * (1 - k * low[:, None]) + fur_deep[None, :] * (k * low[:, None])
        bare_col = skin[None, :] * (1 - k * low[:, None]) + skin_deep[None, :] * (k * low[:, None])
        return coat * (1 - bare[:, None]) + bare_col * bare[:, None]

    c.paint = painted
    c.palette = dict(c.palette or {}, eye_line_size=0.0, mouth=col.get("mouth", "#2a2a40"))
    c.bare_regions = bare_regions


def _skin_paint(mesh, creature, design):
    """A scaly or bare-skinned animal: its skin color, a deeper shade low
    down and underneath (soft occlusion), and its own markings on top
    (design "markings": the species' paint, re-colored by the palette)."""
    col = design["colors"]
    skin, deep = _hex(col["skin"]), _hex(col["skin_deep"])
    v = mesh.verts
    lo, hi = v[:, 2].min(), v[:, 2].max()
    low = np.clip((hi - v[:, 2]) / max(hi - lo, 1e-6), 0, 1) ** 2
    k = float(design.get("shade_low", 0.3))
    out = skin[None, :] * (1 - k * low[:, None]) + deep[None, :] * (k * low[:, None])
    n = _normals(mesh)
    under = np.clip(-n[:, 2], 0, 1) * float(design.get("underside", 0.0))
    belly = _hex(col.get("belly", col["skin"]))
    out = out * (1 - under[:, None]) + belly[None, :] * under[:, None]
    for spec in design.get("spots", []):
        # Spots or flecks on top (a Komodo's orange flecks), in the palette.
        from paint import Painter
        p = Painter(mesh, {"spot": spec["color"]})
        p.colors = out
        mask = np.clip(n[:, 2] * spec.get("on_top", 1.0) + (1.0 - spec.get("on_top", 1.0)), 0, 1)
        p.spots("spot", spec["cell"], spec["radius"], ring=spec.get("ring", 0.0), mask=mask,
                strength=spec.get("strength", 1.0), seed=spec.get("seed", 17))
        out = p.colors
    return out


def _bare_weight(mesh, regions):
    w = np.zeros(len(mesh.verts))
    for r in regions:
        try:
            w = np.maximum(w, mesh.region_weight(r))
        except (ValueError, IndexError):
            pass
    return np.clip(w * 1.6 - 0.25, 0, 1)


def _parts(c, design):
    col = design["colors"]
    horns = design.get("horns")
    claw_scale = float(design.get("claw_scale", 1.0))
    for e in c.extras:
        if e.material == "claw" and e.bone == "jaw" and "tongue" in col:
            # A tongue (species build it from "claw" cones on the jaw).
            e.material = "tongue"
            e.color = col["tongue"]
        elif e.material == "claw":
            e.color = col["nails"]
            e.radius *= claw_scale
            e.tip_radius *= claw_scale
            if e.tip is not None and claw_scale != 1.0:
                base, tip = np.asarray(e.center, float), np.asarray(e.tip, float)
                e.tip = tuple(base + (tip - base) * claw_scale)
        elif e.material == "nose" and "nose" in col:
            e.color = col["nose"]
        elif e.material in ("horn", "tusk"):
            e.color = col.get("horn", e.color)
            if horns and e.material == "horn" and e.tip is not None:
                # Swept out to the side and back instead of straight up.
                base = np.asarray(e.center, float)
                side = 1.0 if base[0] > 0 else -1.0
                d = np.array([side * horns["out"], -horns["back"], horns["up"]], float)
                d /= np.linalg.norm(d)
                e.center = tuple(base - d * horns["length"] * 0.25)
                e.tip = tuple(base + d * horns["length"])
                e.radius *= horns.get("thick", 1.0)


# --- Hero art: strands, materials, studio lights ------------------------------------------

def dress(c, arm, body, mesh, quality=1.0, size=1.0):
    """Turns a built creature (scene.build) into hero art: bare skin and
    fur strands on the body, eye, nail, horn and nose materials on its
    pieces, and the studio lights round it. `size`: how big the animal is
    (meters), for the lights."""
    import bpy
    import materials as M
    design = c.design
    col = design["colors"]
    surface = design.get("surface", "fur")
    if surface == "feathers":
        # Smooth skin in the painted colors (the wings' blades, the tail,
        # legs and beak), with feather cards laid over the body.
        skin = M.skin_material(M.rgba(col["skin"]), "movie_skin")
        nt = skin.node_tree
        bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
        attr = nt.nodes.new("ShaderNodeVertexColor")
        attr.layer_name = "Col"
        nt.links.new(attr.outputs["Color"], bsdf.inputs["Base Color"])
        bsdf.inputs["Sheen Weight"].default_value = M.MAT["feathers"]["sheen"] * 0.5
        bsdf.inputs["Subsurface Weight"].default_value = 0.0
        # Feathers are matte: no glossy highlight washing dark markings out
        # (even a rough highlight swamps a navy helmet seen at a low angle).
        bsdf.inputs["Roughness"].default_value = 0.85
        bsdf.inputs["Specular IOR Level"].default_value = 0.0
        bsdf.inputs["Sheen Weight"].default_value = 0.04
        body.data.materials.clear()
        body.data.materials.append(skin)
        if quality > 0:
            _feather_cards(c, body, mesh, design["feathers"], hero=True)
    elif surface == "scales":
        # Scales all over, in the painted colors.
        sc = design.get("scales", {})
        body.data.materials.clear()
        body.data.materials.append(M.scales_material(M.rgba(col["skin"]), "movie_scales", color_attribute="Col",
                                                     cell=sc.get("cell")))
    else:
        # Skin: the painted colors, soft, a little sheen.
        skin = M.skin_material(M.rgba(col["skin"]), "movie_skin")
        nt = skin.node_tree
        bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
        attr = nt.nodes.new("ShaderNodeVertexColor")
        attr.layer_name = "Col"
        # Under the fur the skin is a deeper shade of it, so the gaps between
        # clumps read as soft shadow.
        under = nt.nodes.new("ShaderNodeAttribute")
        under.attribute_name = "under_fur"
        deep = M._mix_color(nt, under.outputs["Fac"], attr.outputs["Color"], M.rgba(col["fur_deep"]))
        nt.links.new(deep, bsdf.inputs["Base Color"])
        body.data.materials.clear()
        body.data.materials.append(skin)
    _dress_pieces(c, design, quality)
    # The lights round the animal where it really is (a flier hangs at its
    # altitude), sized to its longest side (a wingspan, a long tail).
    lo, hi = mesh.verts.min(axis=0), mesh.verts.max(axis=0)
    center = (lo + hi) / 2 + np.asarray(arm["rest_offset"], float)
    reach = float(max(hi - lo))
    M.studio_lights(target=(float(center[0]), float(center[1]), float(center[2])), scale=max(size, reach * 0.8))
    if surface != "fur":
        return
    # Where fur grows, and how long: by body part, none on bare skin, eyes
    # and mouth.
    f = design["fur"]
    w = fur_lengths(c, mesh)
    vg = body.vertex_groups.new(name="fur")
    a = body.data.attributes.new("under_fur", "FLOAT", "POINT")
    a.data.foreach_set("value", np.clip(w * 2.0, 0, 1) * float(f.get("under", 0.7)))
    for i in np.nonzero(w > 0.01)[0]:
        vg.add([int(i)], float(w[i]), "REPLACE")
    if quality > 0:
        M.add_fur(body, M.rgba(col["fur"]), f["kind"], density=f.get("density", 1.0) * quality,
                  weight_group="fur", seed=3, comb=tuple(f["comb"]), color_attribute="HairCol",
                  length=f.get("length"), groom=f.get("groom"), deep=M.rgba(col["fur_deep"]))
        # Particle hair must come after the armature so it follows the pose.
        with bpy.context.temp_override(object=body):
            while body.modifiers.find("fur_" + f["kind"]) < body.modifiers.find("rig"):
                bpy.ops.object.modifier_move_down(modifier="fur_" + f["kind"])


def _dress_pieces(c, design, quality):
    """Eye, nail, horn and nose materials on the pieces stuck to the body."""
    import bpy
    import materials as M
    col = design["colors"]
    for obj in list(bpy.data.objects):
        if obj.type != "MESH" or obj.name.endswith("_body") or not obj.data.materials:
            continue
        name = obj.data.materials[0].name
        if name.startswith("eye") or name.startswith("cartoon_eye"):
            mat = M.eye_material(M.rgba(design["eyes"]["iris"]), forward="+Z")
        elif name.startswith("extra_claw"):
            mat = M.claw_material()
            mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = M.rgba(col["nails"])
        elif name.startswith("extra_horn") or name.startswith("extra_tusk"):
            depth = float(obj.dimensions.z / max(obj.scale.z, 1e-9))
            mat = M.horn_material(M.rgba(col["horn"]), axis_len=depth, offset=depth / 2,
                                  tip_color=M.rgba(col.get("horn_tip", col["horn"])))
        elif name.startswith("extra_tongue"):
            mat = M.skin_material(M.rgba(col["tongue"]), "tongue")
            mat.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.3
            mat.node_tree.nodes["Principled BSDF"].inputs["Coat Weight"].default_value = 0.6
        elif name.startswith("extra_nose"):
            mat = M.skin_material(M.rgba(col["nose"]) if "nose" in col else M.shade(M.rgba(col["skin_deep"]), 0.45),
                                  "nose")
            mat.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.25
        else:
            continue
        obj.data.materials.clear()
        obj.data.materials.append(mat)


# --- Feathers ----------------------------------------------------------------------------

def feather_weight(c, mesh):
    """Where feathers lie: the design's regions, not round the eyes or the
    beak."""
    k = c.design.get("feathers", {})
    w = np.zeros(len(mesh.verts))
    for r in k.get("regions", []):
        try:
            w = np.maximum(w, mesh.region_weight(r))
        except (ValueError, IndexError):
            pass
    for center, radius in list(c.eyes):
        d = np.linalg.norm(mesh.verts - center, axis=1)
        w *= np.clip((d - radius * 1.8) / (radius * 1.5), 0, 1)
    return np.clip(w * 1.5 - 0.2, 0, 1)


def _even_points(mesh, weight, count, rng):
    """`count` vertices spread evenly where `weight` is high (a cheap
    Poisson disk), with their normals and the weight there."""
    v = mesh.verts
    f = np.asarray(mesh.faces)
    tri = np.linalg.norm(np.cross(v[f[:, 1]] - v[f[:, 0]], v[f[:, 2]] - v[f[:, 0]]), axis=1) / 2
    area = float((tri * weight[f].mean(axis=1).clip(0, 1)).sum())
    spacing = math.sqrt(area / max(count, 1)) * 0.9
    cand = np.nonzero(weight > 0.3)[0]
    rng.shuffle(cand)
    chosen, grid = [], {}
    for i in cand:
        p = v[i]
        cell = tuple((p // spacing).astype(int))
        near = False
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                for dz in (-1, 0, 1):
                    for j in grid.get((cell[0] + dx, cell[1] + dy, cell[2] + dz), ()):
                        if np.linalg.norm(v[j] - p) < spacing:
                            near = True
                            break
                    if near:
                        break
                if near:
                    break
            if near:
                break
        if not near:
            grid.setdefault(cell, []).append(i)
            chosen.append(i)
        if len(chosen) >= count:
            break
    return np.asarray(chosen, int)


def _feather_cards(c, body, mesh, k, hero=True):
    """Feather cards laid over the body like shingles (materials.py
    scatter_feathers), each in the skin's painted color where it grows,
    pointing along the comb (toward the tail), stuck to the body's bones."""
    import bpy
    import materials as M
    rng = np.random.default_rng(int(k.get("seed", 5)))
    w = feather_weight(c, mesh)
    idx = _even_points(mesh, w, int(k["count"]), rng)
    if not len(idx):
        return None
    normals = _normals(mesh)
    attr = body.data.color_attributes["Col"]
    flat = np.empty(len(attr.data) * 4)
    attr.data.foreach_get("color", flat)
    colors = flat.reshape(-1, 4)[:, :3]
    size = k["size"]
    obj = M.scatter_feathers(mesh.verts[idx], normals[idx], comb=tuple(k.get("comb", (0.0, -1.0, -0.2))),
                             color=M.rgba(c.design["colors"]["skin"]), size=size, tilt=k.get("tilt"),
                             jitter=k.get("jitter"), seed=int(k.get("seed", 5)), name=c.name + "_feathers",
                             follow=float(k.get("follow", 0.06)), colors=colors[idx],
                             lift_off=float(k.get("lift_off", 0.0)))
    # Skinned like the body: each card follows the bone under its root.
    from sdf import bone_weights
    weights = bone_weights(mesh)
    per_card = len(obj.data.vertices) // len(idx)
    for name, bw in weights.items():
        lw = bw[idx]
        hit = np.nonzero(lw > 0.01)[0]
        if not len(hit):
            continue
        vg = obj.vertex_groups.new(name=name)
        for i in hit:
            vg.add(list(range(int(i) * per_card, (int(i) + 1) * per_card)), float(lw[i]), "REPLACE")
    arm = body.parent
    mod = obj.modifiers.new("rig", "ARMATURE")
    mod.object = arm
    obj.parent = arm
    obj.matrix_parent_inverse = body.matrix_parent_inverse.copy()
    obj.matrix_basis = body.matrix_basis.copy()
    return obj


def feather_geometry(c, mesh, colors, lod):
    """The coat as feather cards for the real-time models (movie.json
    "feathers" <lod>): fewer, bigger cards than the hero art's, laid like
    shingles, each in the paint's color where it grows, shaded darker at the
    base and lighter at the edge by the game's shader. Returns (verts,
    faces, colors, uv, uv2, root vertex per vertex); uv is (across, along)
    and uv2 (a random number, 4)."""
    import materials as M
    k = dict(c.design["feathers"])
    k.update(c.design["feathers"].get(lod, {}))
    rng = np.random.default_rng(int(k.get("seed", 5)))
    w = feather_weight(c, mesh)
    idx = _even_points(mesh, w, int(k["count"]), rng)
    if not len(idx):
        return None
    normals = _normals(mesh)
    size = k["size"]
    cv, cf, cu = M.feather_card(size[0], size[1], float(k.get("follow", 0.06)), segments=int(k.get("segments", 4)))
    cv = np.asarray(cv, float)
    comb = np.asarray(k.get("comb", (0.0, -1.0, -0.2)), float)
    tilt = math.radians(float(k.get("tilt", 8)))
    jitter = float(k.get("jitter", 0.1))
    lift_off = float(k.get("lift_off", 0.0))
    out_v, out_f, out_c, out_uv, out_uv2, out_root = [], [], [], [], [], []
    for i in idx:
        p, n = mesh.verts[i], normals[i]
        t = comb - n * (comb @ n)
        if np.linalg.norm(t) < 1e-4:
            t = np.cross(n, (1.0, 0.0, 0.0))
        t /= np.linalg.norm(t)
        ang = rng.normal(0, jitter)
        b = np.cross(n, t)
        t = t * math.cos(ang) + b * math.sin(ang)
        b = np.cross(n, t)
        lift = tilt * (1 + rng.normal(0, 0.2))
        up = t * math.cos(lift) + n * math.sin(lift)
        nn = np.cross(b, up)
        sc = 1.0 + rng.normal(0, 0.12)
        basis = np.stack([b, up, nn], axis=1) * sc
        rnd = float(rng.random())
        start = len(out_v)
        pts = (cv @ basis.T) + p + n * lift_off
        out_v.extend(list(pts))
        out_c.extend([colors[i]] * len(pts))
        out_uv.extend(cu)
        out_uv2.extend([(rnd, 4.0)] * len(pts))
        out_root.extend([i] * len(pts))
        out_f.extend([tuple(j + start for j in f) for f in cf])
    return (np.asarray(out_v), out_f, np.asarray(out_c), np.asarray(out_uv), np.asarray(out_uv2),
            np.asarray(out_root))


# --- Real-time models: sculpted fur locks -------------------------------------------------

def fur_lengths(c, mesh):
    """How long the fur is at each vertex, in shares of the longest: by body
    part, none on bare skin, round the eyes or on the lips."""
    from anatomy import mouth_mask
    if c.design.get("surface", "fur") != "fur":
        return np.zeros(len(mesh.verts))
    f = c.design["fur"]
    length = np.zeros(len(mesh.verts))
    for region, share in f["lengths"].items():
        try:
            length = np.maximum(length, mesh.region_weight(region) * share)
        except (ValueError, IndexError):
            pass
    length *= 1 - _bare_weight(mesh, c.bare_regions)
    face = getattr(c, "face_weight", None)
    if face is not None:
        length *= 1 - np.clip(face(mesh) * 1.5, 0, 1)
    for center, radius in list(c.eyes):
        d = np.linalg.norm(mesh.verts - center, axis=1)
        length *= np.clip((d - radius * 1.6) / (radius * 1.5), 0, 1)
    length *= 1 - mouth_mask(c, mesh.verts, reach=4.0)
    return length / max(float(length.max()), 1e-6)


def _normals(mesh):
    v, f = mesh.verts, np.asarray(mesh.faces)
    fn = np.cross(v[f[:, 1]] - v[f[:, 0]], v[f[:, 2]] - v[f[:, 0]])
    n = np.zeros_like(v)
    for k in range(3):
        np.add.at(n, f[:, k], fn)
    return n / np.maximum(np.linalg.norm(n, axis=1, keepdims=True), 1e-12)


def lock_geometry(c, mesh, colors, lod):
    """The coat as sculpted locks (movie.json "locks" for this level of
    detail): `count` tapering clumps rooted in the skin where fur grows,
    spread evenly, each leaving the skin a little (lift) and falling along
    the comb, flattened against the body, shaded from a deep root to a light
    tip. Returns (verts, faces, colors, uv, uv2, root vertex per vertex);
    uv is (round the lock, root to tip) and uv2 (the lock's random number,
    2) for the game's shader."""
    from scipy.spatial import cKDTree
    k = c.design["locks"][lod]
    col = c.design["colors"]
    rng = np.random.default_rng(int(k.get("seed", 7)))
    share = fur_lengths(c, mesh)
    normals = _normals(mesh)
    # Even roots: random candidates where fur is long enough, accepted only
    # far enough from those already chosen.
    cand = np.nonzero(share > 0.2)[0]
    rng.shuffle(cand)
    v = mesh.verts
    f = np.asarray(mesh.faces)
    tri = np.linalg.norm(np.cross(v[f[:, 1]] - v[f[:, 0]], v[f[:, 2]] - v[f[:, 0]]), axis=1) / 2
    furred = float((tri * share[f].mean(axis=1).clip(0, 1) ** 0.5).sum())
    spacing = math.sqrt(furred / max(int(k["count"]), 1)) * 0.92
    chosen = []
    tree_pts = []
    grid = {}
    for i in cand:
        p = v[i]
        cell = tuple((p // spacing).astype(int))
        near = False
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                for dz in (-1, 0, 1):
                    for j in grid.get((cell[0] + dx, cell[1] + dy, cell[2] + dz), ()):
                        if np.linalg.norm(v[j] - p) < spacing:
                            near = True
                            break
                    if near:
                        break
                if near:
                    break
            if near:
                break
        if not near:
            grid.setdefault(cell, []).append(i)
            chosen.append(i)
        if len(chosen) >= int(k["count"]):
            break
    comb = np.asarray(c.design["fur"]["comb"], float)
    comb /= np.linalg.norm(comb)
    deep, white = _hex(col["fur_deep"]), np.ones(3)
    sides, rings = int(k["sides"]), int(k["rings"])
    out_v, out_f, out_c, out_uv, out_uv2, out_root = [], [], [], [], [], []
    for i in chosen:
        p, n = v[i], normals[i]
        t = comb - n * (comb @ n)
        if np.linalg.norm(t) < 1e-3:
            t = np.cross(n, (1.0, 0.0, 0.0))
        t /= np.linalg.norm(t)
        L = k["length"] * (0.45 + 0.55 * share[i]) * (1 + rng.normal(0, 0.15))
        W = k["width"] * (1 + rng.normal(0, 0.12))
        ang = rng.normal(0, 0.25)
        side0 = np.cross(n, t)
        t = t * math.cos(ang) + side0 * math.sin(ang)
        d0 = n * k["lift"] + t
        d0 /= np.linalg.norm(d0)
        p0 = p - n * W * 0.35
        p1 = p + d0 * L * 0.55
        # The end curls back toward the body (hug), so locks lie on it like
        # shingles instead of sticking out like quills.
        p2 = p1 + (t - n * k.get("hug", 0.0)) * L * 0.5
        base = np.asarray(colors[i], float)
        root_c = base * (1 - k["root_darken"]) + deep * k["root_darken"]
        tip_c = base * (1 - k["tip_lighten"]) + white * k["tip_lighten"]
        vary = 1 + rng.normal(0, k["variation"])
        rnd = float(rng.random())
        start = len(out_v)
        flat = float(k.get("flat", 0.5))
        end = float(k.get("end", 0.9))
        for r in range(rings):
            s = r / max(rings - 1, 1) * end
            pos = (1 - s) ** 2 * p0 + 2 * s * (1 - s) * p1 + s * s * p2
            tan = 2 * (1 - s) * (p1 - p0) + 2 * s * (p2 - p1)
            tan /= np.linalg.norm(tan)
            sd = np.cross(tan, n)
            sd /= max(np.linalg.norm(sd), 1e-9)
            up = np.cross(sd, tan)
            # Widest in the middle and rounded at the end: a soft clump,
            # not a spike.
            if k.get("tip", "round") == "point":
                # Tapering to a soft point, like a clump of hair.
                taper = (0.85 + 0.3 * math.sin(math.pi * s)) * max(1 - s, 0.0) ** 0.7
            else:
                taper = (0.8 + 0.3 * math.sin(math.pi * s)) * max(1 - s ** 2.5, 0.0) ** 0.5
            cc = np.clip((root_c + (tip_c - root_c) * s ** 0.7) * vary, 0, 1)
            for j in range(sides):
                a = 2 * math.pi * j / sides
                out_v.append(pos + sd * math.cos(a) * W * taper + up * math.sin(a) * W * flat * taper)
                out_c.append(cc)
                out_uv.append((j / sides, s / end))
                out_uv2.append((rnd, 2.0))
                out_root.append(i)
        tip = p2
        out_v.append(tip)
        out_c.append(np.clip(tip_c * vary, 0, 1))
        out_uv.append((0.0, 1.0))
        out_uv2.append((rnd, 2.0))
        out_root.append(i)
        # Wound so the faces look outward (the outline pass relies on it).
        for r in range(rings - 1):
            for j in range(sides):
                a0 = start + r * sides + j
                a1 = start + r * sides + (j + 1) % sides
                out_f.append((a0, a0 + sides, a1 + sides, a1))
        last = start + (rings - 1) * sides
        for j in range(sides):
            out_f.append((last + j, start + rings * sides, last + (j + 1) % sides))
    return (np.asarray(out_v), out_f, np.asarray(out_c), np.asarray(out_uv), np.asarray(out_uv2),
            np.asarray(out_root))


def under_fur(c, mesh, colors, lod):
    """The skin where fur grows, a deeper shade of the fur: the soft shadow
    between locks, baked into the colors."""
    k = c.design["locks"][lod]
    share = np.clip(fur_lengths(c, mesh) * 2.0, 0, 1)
    deep = _hex(c.design["colors"]["fur_deep"])
    amount = (share * k["occlusion"])[:, None]
    return np.asarray(colors, float) * (1 - amount) + deep[None, :] * amount
