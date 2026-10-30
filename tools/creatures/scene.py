"""Builds a creature in Blender (mesh, armature, extras, materials) and sets
up the camera and lights for rendering.

Coordinates match sdf.py: the animal faces +Y with +Z up.
"""
import math

import bpy
import numpy as np
from mathutils import Matrix, Vector

from sdf import build_mesh, bone_weights


def srgb_to_linear(c):
    c = np.asarray(c, float)
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def hex_color(h):
    h = h.lstrip("#")
    return srgb_to_linear([int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)])


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 48
    scene.cycles.use_denoising = True
    scene.cycles.max_bounces = 6
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.view_settings.view_transform = "AgX"
    scene.view_settings.look = "AgX - Medium High Contrast"
    world = bpy.data.worlds.new("World")
    scene.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs[0].default_value = (0.55, 0.62, 0.72, 1.0)
    bg.inputs[1].default_value = 0.55
    return scene


# --- Building ------------------------------------------------------------------

def build(creature, with_fur=False, fur_quality=1.0):
    """Makes the creature. Returns (armature, body object, body mesh data).
    The armature sits inside an empty called "facing": turn that to point
    the animal somewhere; the armature's own location and rotation are for
    animation."""
    mesh = build_mesh(creature.shapes, voxel=creature.voxel)
    arm = _armature(creature)
    facing = bpy.data.objects.new("facing", None)
    bpy.context.scene.collection.objects.link(facing)
    arm.parent = facing
    # Center the animal over the origin.
    root = creature.joints["root"]
    arm["rest_offset"] = (-root[0], -root[1], float(creature.motion.get("altitude", 0.0)))
    arm.location = arm["rest_offset"]
    body = _body(creature, mesh, arm)
    if with_fur:
        import fur
        fur.add_fur(creature, body, mesh, quality=fur_quality)
    for i, part in enumerate(creature.parts):
        _part(creature, part, arm, i, with_fur, fur_quality)
    for i, extra in enumerate(creature.extras):
        _extra(creature, extra, arm, i)
    return arm, body, mesh


def _set_colors(me, colors):
    """Per-vertex colors for the skin, plus the per-corner byte copy that fur
    strands read their color from."""
    rgba = np.ones((len(colors), 4))
    rgba[:, :3] = colors
    me.color_attributes.new("Col", "FLOAT_COLOR", "POINT").data.foreach_set("color", rgba.ravel())
    loop_verts = np.empty(len(me.loops), int)
    me.loops.foreach_get("vertex_index", loop_verts)
    me.color_attributes.new("HairCol", "BYTE_COLOR", "CORNER").data.foreach_set("color", rgba[loop_verts].ravel())
    me.color_attributes.active_color_index = 0


def _face_paint(creature, mesh, colors):
    """Dark lining around the eyes and dark skin around the nose."""
    dark = hex_color(creature.palette.get("eye_line", "#1b1210")) if creature.palette else hex_color("#1b1210")
    colors = np.array(colors)
    size = float(creature.palette.get("eye_line_size", 1.55)) if creature.palette else 1.55
    for center, radius in creature.eyes:
        d = np.linalg.norm(mesh.verts - center, axis=1)
        amount = np.clip((radius * size - d) / (radius * 0.4), 0, 1)
        colors = colors * (1 - amount[:, None]) + dark * amount[:, None]
    if creature.nose is not None:
        center, radius = creature.nose
        d = np.linalg.norm(mesh.verts - center, axis=1)
        amount = np.clip((radius * 1.6 - d) / (radius * 0.5), 0, 1)
        colors = colors * (1 - amount[:, None]) + dark * amount[:, None]
    return colors


def _part(creature, part, arm, index, with_fur=False, fur_quality=1.0):
    """A finely meshed piece (an ear) colored like the body, stuck to a bone."""
    mesh = build_mesh(part["shapes"], voxel=part["voxel"], padding=part["voxel"] * 4)
    me = bpy.data.meshes.new(f"{creature.name}_part{index}")
    me.from_pydata(mesh.verts.tolist(), [], mesh.faces.tolist())
    me.update()
    for poly in me.polygons:
        poly.use_smooth = True
    obj = bpy.data.objects.new(me.name, me)
    bpy.context.scene.collection.objects.link(obj)
    _set_colors(me, creature.paint(mesh, creature))
    obj.data.materials.append(bpy.data.materials.get(creature.name + "_fur") or _fur_material(creature))
    if with_fur and part.get("fur"):
        import fur
        fur.add_fur(creature, obj, mesh, quality=fur_quality, overrides=part["fur"])
    _stick_to_bone(obj, arm, part["bone"], Matrix.Identity(4))


def _armature(creature):
    data = bpy.data.armatures.new(creature.name + "_rig")
    arm = bpy.data.objects.new(creature.name + "_rig", data)
    bpy.context.scene.collection.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    for b in creature.bones:
        eb = data.edit_bones.new(b.name)
        eb.head = Vector(creature.joints[b.head])
        eb.tail = Vector(creature.joints[b.tail])
        d = (eb.tail - eb.head).normalized()
        # Roll so the bone's X axis points to the animal's right: then a
        # positive X rotation always turns the bone the same way (toes
        # forward, nose up, tail down). Wings say "up" instead.
        z = Vector(b.up) if b.up is not None else Vector((1, 0, 0)).cross(d)
        if z.length < 1e-4:
            z = Vector((0, 1, 0))
        eb.align_roll(z)
        eb.use_deform = True
    for b in creature.bones:
        if b.parent:
            data.edit_bones[b.name].parent = data.edit_bones[b.parent]
    bpy.ops.object.mode_set(mode="OBJECT")
    for pb in arm.pose.bones:
        pb.rotation_mode = "XYZ"
    return arm


def _body(creature, mesh, arm):
    me = bpy.data.meshes.new(creature.name + "_body")
    me.from_pydata(mesh.verts.tolist(), [], mesh.faces.tolist())
    me.update()
    for poly in me.polygons:
        poly.use_smooth = True
    body = bpy.data.objects.new(creature.name + "_body", me)
    bpy.context.scene.collection.objects.link(body)

    _set_colors(me, _face_paint(creature, mesh, creature.paint(mesh, creature)))
    # Extra per-vertex numbers the material can use (fur length, shine).
    for key, values in getattr(creature, "vertex_data", lambda m, c: {})(mesh, creature).items():
        a = me.attributes.new(key, "FLOAT", "POINT")
        a.data.foreach_set("value", np.asarray(values, float))

    weights = bone_weights(mesh)
    for name, w in weights.items():
        vg = body.vertex_groups.new(name=name)
        for i in np.nonzero(w > 0.01)[0]:
            vg.add([int(i)], float(w[i]), "REPLACE")
    mod = body.modifiers.new("rig", "ARMATURE")
    mod.object = arm
    body.parent = arm
    body.data.materials.append(_fur_material(creature))
    return body


def _extra(creature, extra, arm, index):
    name = f"{creature.name}_{extra.material}_{index}"
    if extra.kind == "sphere":
        bpy.ops.mesh.primitive_uv_sphere_add(radius=extra.radius, location=extra.center, segments=24, ring_count=12)
    elif extra.kind == "ellipsoid":
        bpy.ops.mesh.primitive_uv_sphere_add(radius=1.0, location=extra.center, segments=32, ring_count=16)
        obj = bpy.context.object
        obj.scale = extra.radii
        if extra.direction is not None:
            # Turn local +Z toward `direction`, keeping local X roughly level.
            obj.rotation_mode = "QUATERNION"
            obj.rotation_quaternion = Vector(extra.direction).to_track_quat("Z", "Y")
        else:
            obj.rotation_euler = extra.rot
    else:
        a, b = Vector(extra.center), Vector(extra.tip)
        bpy.ops.mesh.primitive_cone_add(radius1=extra.radius, radius2=extra.tip_radius, depth=(b - a).length,
                                        vertices=16, location=(a + b) / 2)
        obj = bpy.context.object
        obj.rotation_mode = "QUATERNION"
        obj.rotation_quaternion = Vector((0, 0, 1)).rotation_difference((b - a).normalized())
    obj = bpy.context.object
    obj.name = name
    bpy.ops.object.shade_smooth()
    obj.data.materials.append(_extra_material(extra))
    _stick_to_bone(obj, arm, extra.bone, obj.matrix_world.copy())


def _stick_to_bone(obj, arm, bone, creature_space):
    """Parents obj to a bone. `creature_space` is where it sits in the
    creature's own coordinates (the ones the joints use); the armature is
    shifted to center the animal, so place it relative to the armature."""
    bpy.context.view_layer.update()
    world = arm.matrix_world @ creature_space
    obj.parent = arm
    obj.parent_type = "BONE"
    obj.parent_bone = bone
    bpy.context.view_layer.update()
    obj.matrix_world = world


# --- Materials -----------------------------------------------------------------

def _fur_material(creature):
    fur = creature.fur
    mat = bpy.data.materials.new(creature.name + "_fur")
    mat.use_nodes = True
    nt = mat.node_tree
    nodes, links = nt.nodes, nt.links
    bsdf = nodes["Principled BSDF"]
    col = nodes.new("ShaderNodeVertexColor")
    col.layer_name = "Col"
    # Fine streaky noise along the body for a fur feel.
    coord = nodes.new("ShaderNodeTexCoord")
    mapping = nodes.new("ShaderNodeMapping")
    mapping.inputs["Scale"].default_value = (fur.get("streak_x", 260.0), fur.get("streak_y", 60.0), fur.get("streak_z", 260.0))
    noise = nodes.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = 1.0
    noise.inputs["Detail"].default_value = 6.0
    noise.inputs["Roughness"].default_value = 0.65
    links.new(coord.outputs["Object"], mapping.inputs["Vector"])
    links.new(mapping.outputs["Vector"], noise.inputs["Vector"])
    # Color: vertex color brightened/darkened a little by the noise.
    shade = nodes.new("ShaderNodeMapRange")
    shade.inputs["To Min"].default_value = 1.0 - fur.get("variation", 0.16)
    shade.inputs["To Max"].default_value = 1.0 + fur.get("variation", 0.16)
    links.new(noise.outputs["Fac"], shade.inputs["Value"])
    mult = nodes.new("ShaderNodeMix")
    mult.data_type = "RGBA"
    mult.blend_type = "MULTIPLY"
    mult.inputs["Factor"].default_value = 1.0
    links.new(col.outputs["Color"], mult.inputs[6])
    links.new(shade.outputs["Result"], mult.inputs[7])
    links.new(mult.outputs[2], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = fur.get("roughness", 0.78)
    bsdf.inputs["Sheen Weight"].default_value = fur.get("sheen", 0.25)
    bsdf.inputs["Sheen Roughness"].default_value = 0.45
    bsdf.inputs["Specular IOR Level"].default_value = fur.get("specular", 0.25)
    bsdf.inputs["Subsurface Weight"].default_value = fur.get("subsurface", 0.04)
    bsdf.inputs["Subsurface Radius"].default_value = (0.02, 0.01, 0.006)
    bump = nodes.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = fur.get("bump", 0.35)
    bump.inputs["Distance"].default_value = 0.002
    links.new(noise.outputs["Fac"], bump.inputs["Height"])
    links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
    return mat


EXTRA_LOOKS = {
    "eye": {"color": "#1a0f08", "roughness": 0.05, "specular": 0.9},
    "nose": {"color": "#141010", "roughness": 0.3, "specular": 0.6},
    "claw": {"color": "#2a2420", "roughness": 0.4, "specular": 0.5},
    "horn": {"color": "#3a3128", "roughness": 0.45, "specular": 0.4},
    "tusk": {"color": "#e8dfc8", "roughness": 0.35, "specular": 0.5},
    "hoof": {"color": "#2b2420", "roughness": 0.5, "specular": 0.4},
    "teeth": {"color": "#f1ece0", "roughness": 0.3, "specular": 0.5},
    "beak": {"color": "#e0b040", "roughness": 0.35, "specular": 0.5},
    "skin": {"color": "#d08070", "roughness": 0.6, "specular": 0.3},
}


def _eye_material(extra):
    """Iris and pupil painted by position on the eyeball: the front cap
    (local +Z) is the iris, with a round or slit pupil in the middle."""
    mat = bpy.data.materials.new("eye")
    mat.use_nodes = True
    nt = mat.node_tree
    nodes, links = nt.nodes, nt.links
    bsdf = nodes["Principled BSDF"]
    coord = nodes.new("ShaderNodeTexCoord")
    sep = nodes.new("ShaderNodeSeparateXYZ")
    links.new(coord.outputs["Object"], sep.inputs[0])
    iris_color = hex_color(extra.color) if isinstance(extra.color, str) else (0.6, 0.35, 0.08)
    # Pupil shape: an ellipse in local X/Y on the front of the eye.
    sx = 0.16 if getattr(extra, "pupil", "round") == "slit" else 0.32
    sy = 0.5 if getattr(extra, "pupil", "round") == "slit" else 0.32
    def math_node(op, a=None, b=None, value=None):
        n = nodes.new("ShaderNodeMath")
        n.operation = op
        if a is not None:
            links.new(a, n.inputs[0])
        if b is not None:
            links.new(b, n.inputs[1])
        if value is not None:
            n.inputs[1].default_value = value
        return n
    px = math_node("DIVIDE", sep.outputs["X"], value=sx)
    py = math_node("DIVIDE", sep.outputs["Y"], value=sy)
    px2 = math_node("MULTIPLY", px.outputs[0], px.outputs[0])
    py2 = math_node("MULTIPLY", py.outputs[0], py.outputs[0])
    ell = math_node("ADD", px2.outputs[0], py2.outputs[0])
    pupil = math_node("LESS_THAN", ell.outputs[0], value=1.0)
    front = math_node("GREATER_THAN", sep.outputs["Z"], value=0.35)
    iris_ring = math_node("GREATER_THAN", sep.outputs["Z"], value=0.55)
    mix_iris = nodes.new("ShaderNodeMix")
    mix_iris.data_type = "RGBA"
    mix_iris.inputs[6].default_value = (0.05, 0.03, 0.02, 1)       # dark edge of the eye
    mix_iris.inputs[7].default_value = (*iris_color, 1)
    links.new(iris_ring.outputs[0], mix_iris.inputs["Factor"])
    pupil_mask = math_node("MULTIPLY", pupil.outputs[0], front.outputs[0])
    mix_pupil = nodes.new("ShaderNodeMix")
    mix_pupil.data_type = "RGBA"
    links.new(mix_iris.outputs[2], mix_pupil.inputs[6])
    mix_pupil.inputs[7].default_value = (0.01, 0.01, 0.01, 1)
    links.new(pupil_mask.outputs[0], mix_pupil.inputs["Factor"])
    links.new(mix_pupil.outputs[2], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.25
    bsdf.inputs["Coat Weight"].default_value = 1.0
    bsdf.inputs["Coat Roughness"].default_value = 0.03
    return mat


def _extra_material(extra):
    if extra.material == "eye":
        return _eye_material(extra)
    look = dict(EXTRA_LOOKS.get(extra.material, {"color": "#808080", "roughness": 0.5, "specular": 0.5}))
    mat = bpy.data.materials.new("extra_" + extra.material)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    color = extra.color if extra.color is not None else hex_color(look["color"])
    if isinstance(color, str):
        color = hex_color(color)
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = look["roughness"]
    bsdf.inputs["Specular IOR Level"].default_value = look["specular"]
    if extra.material == "eye":
        bsdf.inputs["Coat Weight"].default_value = 1.0
        bsdf.inputs["Coat Roughness"].default_value = 0.02
    return mat


# --- Camera and lights ------------------------------------------------------------

def lights(strength=1.0):
    """Key light from above and slightly toward the viewer (so mirrored
    sprites still look right), a cool fill, and a rim light from behind."""
    def sun(name, rot, energy, color, angle):
        light = bpy.data.lights.new(name, "SUN")
        light.energy = energy * strength
        light.color = color
        light.angle = math.radians(angle)
        light.use_shadow = name == "key"
        obj = bpy.data.objects.new(name, light)
        obj.rotation_euler = [math.radians(a) for a in rot]
        bpy.context.scene.collection.objects.link(obj)
        return obj
    sun("key", (22, 0, 0), 3.4, (1.0, 0.95, 0.86), 14)
    sun("rim", (-60, 0, 180), 2.2, (0.85, 0.9, 1.0), 4)
    sun("side", (60, 0, 75), 0.6, (1.0, 0.92, 0.85), 10)


def shadow_catcher(size=4.0):
    bpy.ops.mesh.primitive_plane_add(size=size, location=(0, 0, 0))
    plane = bpy.context.object
    plane.name = "ground"
    plane.is_shadow_catcher = True
    return plane


def ortho_camera(elevation_deg, ortho_scale, target=(0, 0, 0.2), distance=10.0):
    """An orthographic camera south of the animal (at -Y), looking down."""
    cam_data = bpy.data.cameras.new("cam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = ortho_scale
    cam = bpy.data.objects.new("cam", cam_data)
    bpy.context.scene.collection.objects.link(cam)
    el = math.radians(elevation_deg)
    t = Vector(target)
    cam.location = t + Vector((0, -math.cos(el), math.sin(el))) * distance
    cam.rotation_euler = (math.pi / 2 - el, 0, 0)
    bpy.context.scene.camera = cam
    return cam


def perspective_camera(location, target, lens=85):
    cam_data = bpy.data.cameras.new("cam")
    cam_data.lens = lens
    cam = bpy.data.objects.new("cam", cam_data)
    bpy.context.scene.collection.objects.link(cam)
    cam.location = location
    direction = Vector(target) - Vector(location)
    cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.camera = cam
    return cam
