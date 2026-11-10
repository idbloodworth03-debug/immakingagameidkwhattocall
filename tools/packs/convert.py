"""Turns an animal from an art pack into the game's 3D models.

    python convert.py test_colobus --pack <the pack's folder>
    python convert.py test_colobus test_taipan --pack <folder> --lod battle
    python convert.py --all --pack <folder>
    python convert.py test_colobus --pack <folder> --strikes   # where each clip strikes

Writes game/art/models/<id>.glb (the 3D viewer's: the pack's finest mesh,
every facial blendshape) and game/art/models/battle/<id>.glb (fights: a
lighter mesh, the blendshapes fights use) with battle/models.json's size
for it. Both hold the game's own animations (idle, walk, attack...), built
from the pack's clips as packs.json says and timed like the animal named
there, so a fight's choreography is the same whatever the art.

What changes on the way in:
  * the palette texture becomes vertex colors (sRGB, as the game's models);
  * the eyes and tear drops (all the blendshapes move) become a second
    small mesh, <id>_toon_face, so the body carries no blendshapes;
  * the animal is turned to face +Y;
  * the meshes are named <id>_toon: the game draws them in its flat-color
    look (game/scripts/fx/model_toon.gdshader, viewer.json "toon_look").
"""
import argparse
import json
import os
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import bpy

import pack as P

OUT = os.path.join(P.GAME, "art", "models")


def bake(loaded, animal_id, rate):
    """The game's animations as actions, sampled at `rate` keys a second."""
    sc = bpy.context.scene
    sc.render.fps = int(rate)
    clips = P.recipes(loaded, animal_id)
    arm = loaded.arm
    arm.animation_data_create()
    made = []
    for name, (frames, fps, loops, hit) in P.timing(animal_id).items():
        spec = clips[name]
        seconds = frames / float(fps)
        keys = max(2, int(round(seconds * rate)))
        action = bpy.data.actions.new(name)
        action.use_fake_user = True
        arm.animation_data.action = action
        for i in range(keys + 1):
            p = i / keys
            P.apply(arm, P.pose_at(loaded, spec, 0.0 if (loops and i == keys) else p, hit))
            for pb in arm.pose.bones:
                pb.keyframe_insert("location", frame=i)
                pb.keyframe_insert("rotation_quaternion", frame=i)
                pb.keyframe_insert("scale", frame=i)
        made.append(name)
    arm.animation_data.action = None
    P.rest(arm)
    return made


def export(animal_id, lod_name, where, index=None):
    started = time.time()
    lod = int(P.SETTINGS["lods"][lod_name])
    loaded = P.load(animal_id, lod, where, encode="srgb")
    P.keep_shapes(loaded.face, P.SETTINGS["shapes"][lod_name])
    info = P.animal(animal_id)
    made = bake(loaded, animal_id, float(P.SETTINGS["keys_per_second"][lod_name]))
    # The game picks its look by these names (ModelStage.is_toon).
    loaded.body.name = loaded.body.data.name = animal_id + "_toon"
    parts = [loaded.body]
    if loaded.face is not None:
        loaded.face.name = loaded.face.data.name = animal_id + "_toon_face"
        parts.append(loaded.face)
    skin = bpy.data.materials.new("skin")
    for ob in parts:
        ob.data.materials.clear()
        ob.data.materials.append(skin)
    pts = P.points(loaded)
    lo, hi = pts.min(axis=0), pts.max(axis=0)
    length = float(max(hi[0] - lo[0], hi[1] - lo[1]))
    if index is not None:
        index[animal_id] = {"tile_scale": round(float(info["tiles_long"]) / length, 5)}
    out_dir = os.path.join(OUT, "battle") if lod_name == "battle" else OUT
    os.makedirs(out_dir, exist_ok=True)
    path = os.path.join(out_dir, animal_id + ".glb")
    bpy.ops.object.select_all(action="DESELECT")
    loaded.arm.select_set(True)
    for ob in parts:
        ob.select_set(True)
    bpy.ops.export_scene.gltf(
        filepath=path, export_format="GLB", use_selection=True,
        export_vertex_color="ACTIVE", export_all_vertex_colors=False,
        export_normals=True, export_texcoords=False, export_materials="PLACEHOLDER",
        export_skins=True, export_def_bones=True, export_animations=True,
        export_animation_mode="ACTIONS", export_force_sampling=True,
        export_optimize_animation_size=True, export_yup=True, export_apply=False,
        export_morph=True, export_morph_normal=True, export_morph_tangent=False,
        export_extras=False, export_cameras=False, export_lights=False)
    tris = sum(sum(len(p.vertices) - 2 for p in ob.data.polygons) for ob in parts)
    shapes = len(loaded.face.data.shape_keys.key_blocks) - 1 if loaded.face is not None and loaded.face.data.shape_keys else 0
    print(f"[pack] {animal_id} {lod_name}: {tris} triangles, {shapes} blendshapes on {len(loaded.face.data.vertices) if loaded.face else 0} "
          f"face vertices, animations {', '.join(made)}; {os.path.getsize(path) / 1024:.0f} KB in {time.time() - started:.1f} s -> {path}")
    return path


def strikes(animal_id, where):
    loaded = P.load(animal_id, int(P.SETTINGS["lods"]["battle"]), where)
    for clip in sorted(loaded.clips):
        print(f"  {clip:10s} strikes at {P.strike_of(loaded, clip):.3f}")


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    parser = argparse.ArgumentParser()
    parser.add_argument("animals", nargs="*")
    parser.add_argument("--all", action="store_true")
    parser.add_argument("--pack", default=None, help="the pack's folder (or PACK_DIR)")
    parser.add_argument("--lod", choices=["viewer", "battle", "both"], default="both")
    parser.add_argument("--strikes", action="store_true", help="only print where each clip strikes")
    args = parser.parse_args(argv)
    where = P.pack_dir(args.pack)
    ids = list(P.SETTINGS["animals"]) if args.all else args.animals
    index_path = os.path.join(OUT, "battle", "models.json")
    for animal_id in ids:
        if args.strikes:
            strikes(animal_id, where)
            continue
        if args.lod in ("viewer", "both"):
            export(animal_id, "viewer", where)
        if args.lod in ("battle", "both"):
            index = json.load(open(index_path)) if os.path.exists(index_path) else {}
            export(animal_id, "battle", where, index)
            with open(index_path, "w") as f:
                json.dump(dict(sorted(index.items())), f, indent=1)


if __name__ == "__main__":
    main()
