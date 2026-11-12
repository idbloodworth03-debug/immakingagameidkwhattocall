"""Exports a creature as a small real-3D model for the game's 3D animal
viewer (the Animals tab): one smooth mesh painted with the same vertex colors
as the sprites, a skeleton, and a few baked animations (idle, a fidget, the
attack and a victory dance) the viewer plays when you tap the animal.

    python export_gltf.py red_fox            # -> game/art/models/red_fox.glb
    python export_gltf.py red_fox wolf_pack
    python export_gltf.py --all             # every animal in data/animals.json
    python export_gltf.py --all --lod battle   # the light battle models

What goes into it (look.json "model"):
  * the body and every piece stuck to it (ears, eyes, nose, claws, horns),
    joined into one mesh with one skin, so the game draws one thing;
  * the body cut down to about `triangles` triangles (the sprites use the
    full marching-cubes mesh, far finer than a phone needs);
  * vertex colors (COLOR_0) for the skin, sRGB-encoded (the game keeps them
    in 8 bits); the big cartoon eyes carry their eyeball coordinates in UV
    (x, y) and UV2 (z, 1) (UV2.y is 1 on an eye, 0 elsewhere) so the game's
    shader can draw a crisp pupil and shine at any zoom;
  * animations sampled at `keys_per_second`; the whole-body offsets the
    sprites put on the armature object (a hop, a roll) go onto the root
    bones instead, so every animation is bone animation.

"""
import argparse
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "species"))

import bpy
import numpy as np
from mathutils import Euler, Matrix

import cartoon
import motion
import scene as S

MODEL = S.LOOK.get("model", {})
OUT = os.path.join(HERE, "..", "..", "game", "art", "models")
ANIMS = MODEL.get("animations", ["idle", "fidget", "attack", "victory"])
# The battle's lighter models (look.json "model" "battle"): far fewer
# triangles (an animal is a few dozen pixels tall in a fight), every
# animation the battle plays, and their size in field tiles.
LODS = {"viewer": {}, "battle": MODEL.get("battle", {})}
LOD = dict(LODS["viewer"])
# Which of LODS is being made (an animal with the movie look, movie.py,
# grows its fur locks to suit it).
LOD_NAME = ["viewer"]


def _setting(key, fallback):
    return LOD.get(key, MODEL.get(key, fallback))


def _rest(arm):
    motion.apply(arm, {})
    for pb in arm.pose.bones:
        pb.rotation_mode = "XYZ"
        pb.rotation_euler = (0, 0, 0)
        pb.location = (0, 0, 0)
    bpy.context.view_layer.update()


def _colors_of(obj):
    attr = obj.data.color_attributes.get("Col")
    if attr is None:
        return None
    out = np.empty(len(obj.data.vertices) * 4)
    attr.data.foreach_get("color", out)
    return out.reshape(-1, 4)


def _material_color(obj):
    """An extra's flat color, from its material (or the eye's white)."""
    mat = obj.data.materials[0] if obj.data.materials else None
    if mat is None or not mat.use_nodes:
        return (0.5, 0.5, 0.5)
    if mat.name.startswith("cartoon_eye"):
        return (0.9, 0.9, 0.87)
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    return tuple(bsdf.inputs["Base Color"].default_value[:3]) if bsdf else (0.5, 0.5, 0.5)


def _paint(obj, rgb, eye=False):
    """Gives a flat-colored extra the skin's color attribute."""
    n = len(obj.data.vertices)
    me = obj.data
    for name in ("Col", "HairCol"):
        if me.color_attributes.get(name):
            me.color_attributes.remove(me.color_attributes[name])
    rgba = np.ones((n, 4))
    rgba[:, :3] = rgb
    me.color_attributes.new("Col", "FLOAT_COLOR", "POINT").data.foreach_set("color", rgba.ravel())


def _eye_uv(obj):
    """The cartoon eye's pupil is drawn from its own sphere coordinates
    (local +Z faces out, +Y up), like the render's eye material."""
    me = obj.data
    co = np.empty(len(me.vertices) * 3)
    me.vertices.foreach_get("co", co)
    co = co.reshape(-1, 3)
    # Unit sphere coordinates (the eyes are UV spheres scaled by the object).
    r = np.linalg.norm(co, axis=1, keepdims=True)
    unit = co / np.maximum(r, 1e-9)
    loops = np.empty(len(me.loops), int)
    me.loops.foreach_get("vertex_index", loops)
    for name in list(me.uv_layers.keys()):
        me.uv_layers.remove(me.uv_layers[name])
    # glTF flips V (v -> 1 - v); flipped here so the game reads them as is.
    xy = unit[loops][:, :2].copy()
    xy[:, 1] = 1.0 - xy[:, 1]
    me.uv_layers.new(name="UVMap").data.foreach_set("uv", xy.ravel())
    zz = np.zeros((len(loops), 2))
    zz[:, 0] = unit[loops][:, 2]
    me.uv_layers.new(name="UV2").data.foreach_set("uv", zz.ravel())


def _plain_uv(obj):
    me = obj.data
    for name in list(me.uv_layers.keys()):
        me.uv_layers.remove(me.uv_layers[name])
    # All (0, 0) in the game (a new UV layer starts with every face mapped
    # to a square, which would split the mesh at every corner). glTF flips V.
    zero = np.tile([0.0, 1.0], len(me.loops))
    me.uv_layers.new(name="UVMap").data.foreach_set("uv", zero)
    me.uv_layers.new(name="UV2").data.foreach_set("uv", zero)


def _to_srgb(obj):
    """The game keeps vertex colors in 8 bits, so they go out sRGB-encoded
    (linear 8-bit colors band in the dark fur); its shader decodes them."""
    attr = obj.data.color_attributes["Col"]
    c = np.empty(len(attr.data) * 4)
    attr.data.foreach_get("color", c)
    c = c.reshape(-1, 4)
    rgb = np.clip(c[:, :3], 0.0, 1.0)
    c[:, :3] = np.where(rgb <= 0.0031308, rgb * 12.92, 1.055 * rgb ** (1 / 2.4) - 0.055)
    attr.data.foreach_set("color", c.ravel())


def _into_armature_space(obj, arm, bone):
    """Moves a piece stuck to a bone into the armature's own space, weighted
    fully to that bone, so it joins the body's skin."""
    m = arm.matrix_world.inverted() @ obj.matrix_world
    obj.parent = None
    obj.data.transform(m)
    obj.matrix_world = arm.matrix_world.copy()
    for vg in list(obj.vertex_groups):
        obj.vertex_groups.remove(vg)
    vg = obj.vertex_groups.new(name=bone)
    vg.add(list(range(len(obj.data.vertices))), 1.0, "REPLACE")


def _decimate(obj, triangles):
    count = sum(len(p.vertices) - 2 for p in obj.data.polygons)
    if count <= triangles:
        return count
    mod = obj.modifiers.new("cut", "DECIMATE")
    mod.decimate_type = "COLLAPSE"
    mod.ratio = triangles / count
    mod.use_collapse_triangulate = True
    bpy.context.view_layer.objects.active = obj
    # The armature modifier would be applied with it; apply only the cut.
    rig = [m for m in obj.modifiers if m.type == "ARMATURE"]
    for m in rig:
        obj.modifiers.remove(m)
    with bpy.context.temp_override(object=obj, active_object=obj):
        bpy.ops.object.modifier_apply(modifier="cut")
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


def _skin_material(name="skin"):
    """The model's one material. The game only reads its name: "movie" for
    an animal with the movie look (its own shader: fur locks, eyes with an
    iris, studio lighting), "skin" otherwise."""
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    return mat


def _movie_locks(creature, arm, body, mesh):
    """An animal with the movie look: its coat as sculpted fur locks (the
    skin under them a deeper shade) or as feather cards (movie.py), skinned
    to the bones of the skin they grow from. Returns the coat's object."""
    import movie
    from sdf import bone_weights
    lod = LOD_NAME[0]
    me = body.data
    attr = me.color_attributes["Col"]
    flat = np.empty(len(attr.data) * 4)
    attr.data.foreach_get("color", flat)
    colors = flat.reshape(-1, 4)[:, :3].copy()
    if creature.design.get("surface", "fur") == "feathers":
        made = movie.feather_geometry(creature, mesh, colors, lod)
        if made is None:
            return None
        verts, faces, cols, uv, uv2, roots = made
    else:
        deeper = movie.under_fur(creature, mesh, colors, lod)
        rgba = np.ones((len(deeper), 4))
        rgba[:, :3] = deeper
        attr.data.foreach_set("color", rgba.ravel())
        verts, faces, cols, uv, uv2, roots = movie.lock_geometry(creature, mesh, colors, lod)
    lm = bpy.data.meshes.new(creature.name + "_locks")
    lm.from_pydata(verts.tolist(), [], faces)
    lm.update()
    for poly in lm.polygons:
        poly.use_smooth = True
    rgba = np.ones((len(cols), 4))
    rgba[:, :3] = cols
    lm.color_attributes.new("Col", "FLOAT_COLOR", "POINT").data.foreach_set("color", rgba.ravel())
    loops = np.empty(len(lm.loops), int)
    lm.loops.foreach_get("vertex_index", loops)
    # glTF flips V (v -> 1 - v): flipped here so the game reads them as is.
    a = uv[loops].copy()
    a[:, 1] = 1.0 - a[:, 1]
    lm.uv_layers.new(name="UVMap").data.foreach_set("uv", a.ravel())
    b = uv2[loops].copy()
    b[:, 1] = 1.0 - b[:, 1]
    lm.uv_layers.new(name="UV2").data.foreach_set("uv", b.ravel())
    if creature.design.get("surface", "fur") == "feathers":
        # Cards show both sides.
        lm["double_sided"] = True
    locks = bpy.data.objects.new(lm.name, lm)
    bpy.context.scene.collection.objects.link(locks)
    weights = bone_weights(mesh)
    for name, w in weights.items():
        lw = w[roots]
        idx = np.nonzero(lw > 0.01)[0]
        if not len(idx):
            continue
        vg = locks.vertex_groups.new(name=name)
        for i in idx:
            vg.add([int(i)], float(lw[i]), "REPLACE")
    mod = locks.modifiers.new("rig", "ARMATURE")
    mod.object = arm
    locks.parent = arm
    tris = sum(len(p.vertices) - 2 for p in lm.polygons)
    print(f"[model] {creature.name}: {lod} fur locks {tris} triangles")
    return locks


def assemble(creature):
    """Builds the creature and joins everything into one skinned mesh."""
    S.reset()
    arm, body, mesh = S.build(creature, with_fur=False)
    facing = bpy.data.objects.get("facing")
    # The armature stands on its own (the facing empty is only for sprites).
    world = arm.matrix_world.copy()
    arm.parent = None
    arm.matrix_world = world
    if facing is not None:
        bpy.data.objects.remove(facing)
    _rest(arm)

    movie_look = getattr(creature, "style", "") == "movie"
    locks = _movie_locks(creature, arm, body, mesh) if movie_look and creature.design.get("surface", "fur") in ("fur", "feathers") else None
    target = int(_setting("triangles", 16000))
    if movie_look:
        target = int(creature.design.get("body_triangles", {}).get(LOD_NAME[0], target))
    piece_cap = int(_setting("piece_triangles", 0))
    pieces = []
    for obj in list(bpy.data.objects):
        if obj.type != "MESH" or obj == body or obj == locks:
            continue
        if obj.parent == arm and obj.parent_type == "BONE":
            bone = obj.parent_bone
        else:
            continue
        eye = bool(obj.data.materials) and obj.data.materials[0].name.startswith("cartoon_eye")
        movie_eye = movie_look and bool(obj.data.materials) and obj.data.materials[0].name.startswith("eye")
        if movie_eye:
            # The movie look's eye: its color is the iris (the shader draws
            # the white, iris, pupil and catchlight).
            eye = True
            _paint(obj, S.hex_color(creature.design["eyes"]["iris"]), eye)
        elif _colors_of(obj) is None or eye:
            _paint(obj, _material_color(obj), eye)
        if eye:
            _eye_uv(obj)
        else:
            _plain_uv(obj)
        _into_armature_space(obj, arm, bone)
        pieces.append(obj)
    # Ears and other finely meshed parts get cut down too, a share each.
    for obj in pieces:
        tris = sum(len(p.vertices) - 2 for p in obj.data.polygons)
        if piece_cap > 0 and tris > piece_cap * 1.3:
            _decimate(obj, piece_cap)
        elif tris > 3000:
            _decimate(obj, max(800, int(target * 0.06)))

    body_tris = _decimate(body, target)
    # The body's own extra color layer (fur strands) isn't needed.
    if body.data.color_attributes.get("HairCol"):
        body.data.color_attributes.remove(body.data.color_attributes["HairCol"])
    _plain_uv(body)
    if movie_look and creature.design.get("surface") in ("scales", "shell"):
        # Scales: the game's shader draws the cells (UV2.y is 3 on scaly skin;
        # UV2.x: the cell size in meters). A turtle's shell stays plain (its
        # scute lines are painted).
        sc = creature.design.get(creature.design["surface"], {})
        cell = float(sc.get("cell", 0.035))
        me = body.data
        loops = np.empty(len(me.loops), int)
        me.loops.foreach_get("vertex_index", loops)
        scaly = np.ones(len(me.vertices), bool)
        if creature.design["surface"] == "shell":
            import movie
            # The body was cut down: judge by the nearest original vertex.
            from scipy.spatial import cKDTree
            co = np.empty(len(me.vertices) * 3)
            me.vertices.foreach_get("co", co)
            _, nearest = cKDTree(mesh.verts).query(co.reshape(-1, 3))
            scaly = movie.shell_weight(creature, mesh)[nearest] < 0.5
        a = np.zeros((len(me.loops), 2))
        a[:, 0] = np.where(scaly[loops], cell, 0.0)
        a[:, 1] = np.where(scaly[loops], 1.0 - 3.0, 1.0)
        me.uv_layers["UV2"].data.foreach_set("uv", a.ravel())
    for obj in pieces:
        if obj.data.color_attributes.get("HairCol"):
            obj.data.color_attributes.remove(obj.data.color_attributes["HairCol"])

    if locks is not None:
        pieces.append(locks)
    # One mesh, one material slot (the game draws it with its own shader).
    for obj in [body] + pieces:
        obj.data.materials.clear()
        obj.data.materials.append(_skin_material("movie" if movie_look else "skin"))
        for attr in [a.name for a in obj.data.attributes if a.domain == "POINT" and a.data_type == "FLOAT"
                     and not a.name.startswith(".")]:
            if attr not in ("position",):
                obj.data.attributes.remove(obj.data.attributes[attr])
    bpy.ops.object.select_all(action="DESELECT")
    for obj in [body] + pieces:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = body
    with bpy.context.temp_override(active_object=body, selected_editable_objects=[body] + pieces,
                                   selected_objects=[body] + pieces):
        bpy.ops.object.join()
    _to_srgb(body)
    body.data.color_attributes.active_color = body.data.color_attributes["Col"]
    body.data.color_attributes.render_color_index = list(body.data.color_attributes.keys()).index("Col")
    if not any(m.type == "ARMATURE" for m in body.modifiers):
        mod = body.modifiers.new("rig", "ARMATURE")
        mod.object = arm
    body.parent = arm
    body.matrix_parent_inverse = Matrix.Identity(4)
    body.matrix_basis = Matrix.Identity(4)
    if movie_look:
        # The game picks its shader by this name (ModelStage.is_movie).
        body.name = creature.name + "_movie"
        body.data.name = creature.name + "_movie"
    tris = sum(len(p.vertices) - 2 for p in body.data.polygons)
    print(f"[model] {creature.name}: body {body_tris} triangles, {tris} in all, {len(body.data.vertices)} vertices")
    return arm, body, mesh


def bake(creature, arm):
    """Samples each animation into its own action. Root offsets (root_loc,
    root_rot) go onto the bones without a parent."""
    rate = float(_setting("keys_per_second", 30))
    sc = bpy.context.scene
    sc.render.fps = int(rate)
    roots = [pb for pb in arm.pose.bones if pb.parent is None]
    for pb in roots:
        pb.rotation_mode = "QUATERNION"
    arm.animation_data_create()
    have = motion.animations_for(creature, ["victory"])
    for name in _setting("animations", ANIMS):
        if name not in motion.ANIMATIONS:
            continue
        if name in ("attack2", "special") and name not in have:
            continue
        fn, frames, fps, loops = motion.ANIMATIONS[name]
        seconds = frames / float(fps) * float(MODEL.get("slow", {}).get(name, 1.0))
        keys = max(2, int(round(seconds * rate)))
        action = bpy.data.actions.new(name)
        action.use_fake_user = True
        arm.animation_data.action = action
        prev = {}
        poses = [fn(creature, 0.0 if (loops and i == keys) else i / keys) for i in range(keys + 1)]
        # Bones a pose of this clip resizes or slides (strikes.py): keyed
        # through the whole clip, so they are plain again where it doesn't.
        sized = {name for pose in poses for name in pose.get("scale", {})}
        slid = {name for pose in poses for name in pose.get("shift", {})}
        for i, pose in enumerate(poses):
            motion.apply(arm, pose)
            arm.location = arm["rest_offset"]
            arm.rotation_euler = (0, 0, 0)
            m = Matrix.Translation(pose.get("root_loc", (0, 0, 0))) @ Euler(pose.get("root_rot", (0, 0, 0))).to_matrix().to_4x4()
            for pb in roots:
                rest = pb.bone.matrix_local
                basis = Euler(pose.get(pb.name, (0, 0, 0))).to_matrix().to_4x4()
                loc, rot, _ = (rest.inverted() @ m @ rest @ basis).decompose()
                if pb.name in prev:
                    rot.make_compatible(prev[pb.name])
                prev[pb.name] = rot.copy()
                pb.location = loc
                pb.rotation_quaternion = rot
                pb.keyframe_insert("location", frame=i)
                pb.keyframe_insert("rotation_quaternion", frame=i)
                if pb.name in sized:
                    pb.keyframe_insert("scale", frame=i)
            for pb in arm.pose.bones:
                if pb.parent is not None:
                    pb.keyframe_insert("rotation_euler", frame=i)
                    if pb.name in sized:
                        pb.keyframe_insert("scale", frame=i)
                    if pb.name in slid:
                        pb.keyframe_insert("location", frame=i)
    arm.animation_data.action = None
    _rest(arm)
    for pb in roots:
        # _rest put every bone back in XYZ mode; the glTF exporter writes a
        # bone's rotation in its current mode, so the roots must stay in
        # quaternion mode or their baked rotation (a rear, a roll) is lost.
        pb.rotation_mode = "QUATERNION"
        pb.rotation_quaternion = (1, 0, 0, 0)


def export(species, out_dir=OUT, index=None):
    creature = cartoon.load(species, style="cartoon")
    arm, body, mesh = assemble(creature)
    bake(creature, arm)
    if index is not None:
        # Its size in field tiles, as the sprites have it: its longest side
        # (nose to tail, or a wingspan) is tiles_long tiles.
        lo, hi = mesh.verts.min(axis=0), mesh.verts.max(axis=0)
        length = float(max(hi[0] - lo[0], hi[1] - lo[1]))
        index[species] = {"tile_scale": round(float(creature.tiles_long) / length, 5)}
    os.makedirs(out_dir, exist_ok=True)
    path = os.path.join(out_dir, species + ".glb")
    bpy.ops.object.select_all(action="DESELECT")
    arm.select_set(True)
    body.select_set(True)
    bpy.ops.export_scene.gltf(
        filepath=path, export_format="GLB", use_selection=True,
        export_vertex_color="ACTIVE", export_all_vertex_colors=True,
        export_normals=True, export_texcoords=True, export_materials="PLACEHOLDER",
        export_skins=True, export_def_bones=True, export_animations=True,
        export_animation_mode="ACTIONS", export_force_sampling=True,
        export_optimize_animation_size=True, export_yup=True, export_apply=False,
        export_extras=False, export_cameras=False, export_lights=False)
    print(f"[model] wrote {path} ({os.path.getsize(path) / 1024:.0f} KB)")
    return path


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    parser = argparse.ArgumentParser()
    parser.add_argument("species", nargs="*")
    parser.add_argument("--all", action="store_true")
    parser.add_argument("--out", default=None)
    parser.add_argument("--lod", choices=list(LODS), default="viewer",
                        help="viewer (the 3D viewer's detailed model) or battle (light, for fights)")
    args = parser.parse_args(argv)
    LOD.clear()
    LOD.update(LODS[args.lod])
    LOD_NAME[0] = args.lod
    out = args.out or (os.path.join(OUT, "battle") if args.lod == "battle" else OUT)
    ids = args.species
    if args.all:
        # The animals in the game (data/animals.json).
        import json
        with open(os.path.join(HERE, "..", "..", "game", "data", "animals.json")) as f:
            ids = [a["id"] for a in json.load(f)]
    import json
    index_path = os.path.join(out, "models.json")
    index = None
    if args.lod == "battle":
        index = json.load(open(index_path)) if os.path.exists(index_path) else {}
    for sid in ids:
        export(sid, out, index)
        if index is not None:
            with open(index_path, "w") as f:
                json.dump(dict(sorted(index.items())), f, indent=1)


if __name__ == "__main__":
    main()
