"""Shared code for bringing an animal from a bought (or free) art pack into
the game: loading its mesh, rig, clips and facial blendshapes into Blender,
baking its palette into vertex colors, and building the game's animations
(idle, walk, attack...) out of the pack's clips. Used by convert.py (the 3D
models) and render.py (the card portrait and the battle sprites).

Everything about a pack and each animal taken from it is in packs.json.
Two kinds of pack are read: "fbx" (Quirky Series: a mesh per level of
detail with facial blendshapes, the clips in their own file, colors from a
tiny palette picture) and "gltf" (Quaternius: one file per animal with its
mesh, rig and clips, colors from flat materials or a color atlas, no
blendshapes).

Each pack's files are in its own folder (packs.json "folder") under one
root: art_sources/ in this repository, or --pack <root> (or PACK_ROOT).
Only packs whose license allows it are in the repository (CC0: Quaternius);
a store-licensed pack's files stay on your computer.

Coordinates match tools/creatures: the animal faces +Y with +Z up.
"""
import json
import math
import os

import bpy
import numpy as np
from mathutils import Matrix, Quaternion, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
GAME = os.path.normpath(os.path.join(HERE, "..", "..", "game"))
SETTINGS = json.load(open(os.path.join(HERE, "packs.json")))
ANIMATIONS = ["idle", "walk", "attack", "attack2", "special", "fidget", "victory"]
# Timing for an animation its stand-in's sheet doesn't have: (frames, fps, loops, hit).
DEFAULT_TIMING = {"idle": (8, 6, True, None), "walk": (8, 12, True, None), "attack": (10, 16, False, 0.5),
                  "attack2": (10, 16, False, 0.5), "special": (12, 12, False, 0.6), "fidget": (10, 10, False, None),
                  "victory": (10, 10, True, None)}


def animal(animal_id):
    info = SETTINGS["animals"].get(animal_id)
    if info is None:
        raise SystemExit(f"packs.json has no animal '{animal_id}' (it has: {', '.join(SETTINGS['animals'])})")
    return info


def pack_of(animal_id):
    return SETTINGS["packs"][animal(animal_id)["pack"]]


ROOT = os.path.normpath(os.path.join(HERE, "..", "..", "art_sources"))


def pack_dir(given=None):
    """The root the packs' folders are under: --pack, PACK_ROOT, or the
    repository's art_sources/."""
    path = given or os.environ.get("PACK_ROOT", "") or ROOT
    if not os.path.isdir(path):
        raise SystemExit(f"No folder {path}: say where the art packs are with --pack <root> (or PACK_ROOT=<root>).")
    return path


def pack_folder(animal_id, root):
    """Where this animal's pack keeps its files (packs.json "folder", under
    the root)."""
    pack = pack_of(animal_id)
    path = os.path.join(root, pack["folder"])
    if not os.path.isdir(path):
        raise SystemExit(f"{pack['name']} isn't at {path}. Put its files there, or give the root they are under "
                         "with --pack <root> (or PACK_ROOT). A store-licensed pack's files are not in this repository.")
    return path


def timing(animal_id):
    """Each animation's (frames, fps, loops, hit): the same as the animal it
    is timed like (packs.json "timing": an animal already in the game), so
    the fight's choreography doesn't change with the art."""
    info = animal(animal_id)
    like = info.get("timing")
    sheet = {}
    if like:
        path = os.path.join(GAME, "art", "units", like, "sheet.json")
        sheet = json.load(open(path)).get("animations", {})
    out = {}
    for name, spec in info["clips"].items():
        if name in sheet:
            a = sheet[name]
            out[name] = (int(a["frames"]), int(a["fps"]), bool(a["loop"]), a.get("hit"))
        else:
            out[name] = DEFAULT_TIMING[name]
        # How long an idle, walk, fidget or victory lasts is the art's own
        # (a pack's 3-second idle isn't squeezed into ours); a swing's
        # length and hit moment never are.
        if name not in ATTACKS and ("frames" in spec or "fps" in spec):
            frames, fps, loops, hit = out[name]
            out[name] = (int(spec.get("frames", frames)), int(spec.get("fps", fps)), loops, hit)
    return out


# --- Loading -----------------------------------------------------------------

class Loaded:
    """One pack animal in the scene: its armature, its body mesh, its face
    mesh (the eyes and tear drops, the only parts the blendshapes move) and
    its clips (name -> list of poses, one per frame; a pose maps each bone
    to (location, quaternion, scale))."""
    def __init__(self):
        self.arm = None
        self.body = None
        self.face = None
        self.clips = {}
        self.source = ""


ATTACKS = ("attack", "attack2", "special")


def _import_fbx(path, anim):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=path, use_anim=anim)
    return [o for o in bpy.data.objects if o not in before]


def _slot(arm, action):
    data = arm.animation_data or arm.animation_data_create()
    data.action = action
    if action is not None and hasattr(data, "action_slot") and len(action.slots):
        data.action_slot = action.slots[0]


def _read_clips(arm, actions):
    """Every clip as its poses, frame by frame (the pack bakes a pose on
    every frame). Quaternions are kept on one side from frame to frame so
    they can be blended."""
    sc = bpy.context.scene
    clips = {}
    for action in actions:
        name = action.name.split("|")[-1]
        _slot(arm, action)
        f0, f1 = int(round(action.frame_range[0])), int(round(action.frame_range[1]))
        poses = []
        prev = {}
        for f in range(f0, f1 + 1):
            sc.frame_set(f)
            pose = {}
            for pb in arm.pose.bones:
                loc, rot, scale = pb.matrix_basis.decompose()
                if pb.name in prev and rot.dot(prev[pb.name]) < 0.0:
                    rot.negate()
                prev[pb.name] = rot.copy()
                pose[pb.name] = (np.array(loc), np.array(rot), np.array(scale))
            poses.append(pose)
        clips[name] = poses
    _slot(arm, None)
    for pb in arm.pose.bones:
        pb.matrix_basis = Matrix.Identity(4)
    return clips


def load(animal_id, lod, where, encode="srgb", fresh=True):
    """The animal in the scene (an empty one, unless `fresh` is False),
    ready for the game: facing +Y, its colors baked into the "Col" color
    attribute (`encode`: "srgb" as the game's models keep them, "linear"
    for rendering), its face split off (if it has blendshapes), its clips
    read. `where`: the root the packs are under; `lod`: which of the pack's
    level-of-detail meshes (packs that have them)."""
    info = animal(animal_id)
    pack = pack_of(animal_id)
    folder = pack_folder(animal_id, where)
    src = info["source"]
    if fresh:
        bpy.ops.wm.read_factory_settings(use_empty=True)
    out = Loaded()
    out.source = src
    if pack.get("format", "fbx") == "gltf":
        actions = _import_gltf(out, os.path.join(folder, pack["file"].format(source=src)))
    else:
        made = _import_fbx(os.path.join(folder, pack["meshes"].format(source=src, lod=lod)), False)
        out.arm = next(o for o in made if o.type == "ARMATURE")
        out.body = next(o for o in made if o.type == "MESH")
        # The clips come in their own file, on a copy of the same rig.
        old_actions = set(bpy.data.actions)
        extra = _import_fbx(os.path.join(folder, pack["clips"].format(source=src)), True)
        actions = [a for a in bpy.data.actions if a not in old_actions]
        for o in extra:
            bpy.data.objects.remove(o, do_unlink=True)
    for a in actions:
        a.use_fake_user = True
    out.clips = _read_clips(out.arm, actions)
    for a in actions:
        bpy.data.actions.remove(a)
    if out.arm.animation_data is not None:
        out.arm.animation_data_clear()
    if pack.get("format", "fbx") == "gltf":
        rgb = _material_colors(out.body)
    else:
        rgb = _palette_colors(out.body, os.path.join(folder, pack["palette"].format(source=src)))
    _paint(out.body, rgb, info.get("recolor", {}), encode)
    if pack.get("weld", False):
        _weld_smooth(out.body)
    out.face = _split_face(out.body)
    # A pack's animals may face -Y; the game's face +Y. (Turned through the
    # rig's matrix: a glTF rig's rotation is a quaternion, and setting its
    # Euler angles would do nothing.)
    if pack.get("faces", "-Y") == "-Y":
        out.arm.matrix_world = Matrix.Rotation(math.pi, 4, "Z") @ out.arm.matrix_world
    for pb in out.arm.pose.bones:
        pb.rotation_mode = "QUATERNION"
    bpy.context.view_layer.update()
    _bake_transform(out)
    if pack.get("handles", False):
        _plain_bones(out)
    return out


def _import_gltf(out, path):
    """A glTF animal: one skinned mesh (several are joined), its rig, and
    every clip as an action. Returns the actions."""
    sc = bpy.context.scene
    # (The importer places keys by the scene's frame rate; these packs are
    # keyed 30 times a second, so every key lands on a whole frame.)
    sc.render.fps = 30
    before = set(bpy.data.objects)
    old_actions = set(bpy.data.actions)
    bpy.ops.import_scene.gltf(filepath=path)
    made = [o for o in bpy.data.objects if o not in before]
    out.arm = next(o for o in made if o.type == "ARMATURE")
    skinned = [o for o in made if o.type == "MESH" and any(m.type == "ARMATURE" for m in o.modifiers)]
    for o in made:
        if o is not out.arm and o not in skinned:
            bpy.data.objects.remove(o, do_unlink=True)
    if len(skinned) > 1:
        bpy.ops.object.select_all(action="DESELECT")
        for o in skinned:
            o.select_set(True)
        bpy.context.view_layer.objects.active = skinned[0]
        bpy.ops.object.join()
    out.body = skinned[0]
    data = out.arm.animation_data
    if data is not None:
        for track in list(data.nla_tracks):
            data.nla_tracks.remove(track)
    return [a for a in bpy.data.actions if a not in old_actions]


def _plain_bones(loaded):
    """Bones that move no part of the mesh (a rig's handles: IK and pole
    targets) aren't part of the game's model: marked as not deforming, the
    exporter leaves them out unless a bone that does deform hangs off them."""
    weighted = set()
    for ob in (loaded.body, loaded.face):
        if ob is None:
            continue
        names = {g.index: g.name for g in ob.vertex_groups}
        for v in ob.data.vertices:
            for g in v.groups:
                if g.weight > 1e-4:
                    weighted.add(names[g.group])
    for bone in loaded.arm.data.bones:
        bone.use_deform = bone.name in weighted


def _bake_transform(loaded):
    """Bakes the rig object's own turn and scale (the pack's rigs are
    scaled 0.4) into the bones and meshes, leaving every object's transform
    plain: the game measures and scales its models by their meshes, and a
    scale hidden on the rig would throw that off. Bone moves in the clips
    shrink with it."""
    arm = loaded.arm
    m = arm.matrix_world.copy()
    scale = float(m.to_scale()[0])
    arm.data.transform(m)
    for ob in (loaded.body, loaded.face):
        if ob is None:
            continue
        local = ob.matrix_world.copy()
        ob.data.transform(local, shape_keys=True)
        ob.matrix_parent_inverse = Matrix.Identity(4)
        ob.matrix_basis = Matrix.Identity(4)
    arm.matrix_world = Matrix.Identity(4)
    for poses in loaded.clips.values():
        for pose in poses:
            for bone, (loc, rot, size) in pose.items():
                pose[bone] = (loc * scale, rot, size)
    bpy.context.view_layer.update()


def srgb_to_linear(c):
    c = np.asarray(c, float)
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def _palette_colors(ob, palette_path):
    """Each face corner's color (sRGB, 0-1) from a tiny palette picture
    through the mesh's UVs (each face sits inside one swatch)."""
    from PIL import Image
    im = np.asarray(Image.open(palette_path).convert("RGB"), float) / 255.0
    return _sample(ob.data, im)


def _sample(me, im, loops=None):
    """The picture's color under each face corner's UV (nearest pixel)."""
    h, w = im.shape[:2]
    uv = np.empty(len(me.loops) * 2)
    me.uv_layers[0].data.foreach_get("uv", uv)
    uv = uv.reshape(-1, 2)
    if loops is not None:
        uv = uv[loops]
    x = np.clip((uv[:, 0] % 1.0 * w).astype(int), 0, w - 1)
    y = np.clip(((1.0 - uv[:, 1] % 1.0) * h).astype(int), 0, h - 1)
    return im[y, x].copy()


def linear_to_srgb(c):
    c = np.clip(np.asarray(c, float), 0.0, 1.0)
    return np.where(c <= 0.0031308, c * 12.92, 1.055 * c ** (1 / 2.4) - 0.055)


def _material_colors(ob):
    """Each face corner's color (sRGB, 0-1) from its face's material: the
    material's flat color, or its color atlas under the corner's UV."""
    import io
    from PIL import Image
    me = ob.data
    rgb = np.zeros((len(me.loops), 3))
    mat_of_poly = np.empty(len(me.polygons), int)
    me.polygons.foreach_get("material_index", mat_of_poly)
    loop_total = np.empty(len(me.polygons), int)
    me.polygons.foreach_get("loop_total", loop_total)
    mat_of_loop = np.repeat(mat_of_poly, loop_total)
    for index, mat in enumerate(me.materials):
        mine = np.nonzero(mat_of_loop == index)[0]
        if not len(mine):
            continue
        color = (0.5, 0.5, 0.5)
        image = None
        bsdf = mat.node_tree.nodes.get("Principled BSDF") if mat is not None and mat.use_nodes else None
        if bsdf is not None:
            base = bsdf.inputs["Base Color"]
            color = tuple(base.default_value[:3])
            node = base.links[0].from_node if base.is_linked else None
            # (The importer may put a mix with the vertex color in between.)
            while node is not None and node.type != "TEX_IMAGE":
                linked = [i for i in node.inputs if i.is_linked]
                node = linked[0].links[0].from_node if linked else None
            if node is not None and node.image is not None:
                image = node.image
        if image is not None and len(me.uv_layers):
            if image.packed_file is not None:
                picture = Image.open(io.BytesIO(image.packed_file.data))
            else:
                picture = Image.open(bpy.path.abspath(image.filepath))
            rgb[mine] = _sample(me, np.asarray(picture.convert("RGB"), float) / 255.0, mine)
        else:
            rgb[mine] = linear_to_srgb(color)
    return rgb


def _paint(ob, rgb, recolor, encode):
    """Stores each face corner's color (sRGB, 0-1) as the "Col" color
    attribute: no texture to filter or bleed, and the game's own shaders
    already draw vertex colors. `recolor` swaps colors ("#rrggbb" ->
    "#rrggbb"), for making one animal into its cousin."""
    swaps = {tuple(int(k.lstrip("#")[i:i + 2], 16) for i in (0, 2, 4)): [int(v.lstrip("#")[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
             for k, v in recolor.items()}
    me = ob.data
    rgb = np.array(rgb, float)
    if swaps:
        as_bytes = np.round(rgb * 255).astype(int)
        for old, new in swaps.items():
            rgb[(as_bytes == np.array(old)).all(axis=1)] = new
    if encode == "linear":
        rgb = srgb_to_linear(rgb)
    rgba = np.ones((len(rgb), 4))
    rgba[:, :3] = rgb
    for name in [a.name for a in me.color_attributes]:
        me.color_attributes.remove(me.color_attributes[name])
    me.color_attributes.new("Col", "FLOAT_COLOR", "CORNER").data.foreach_set("color", rgba.ravel())
    me.color_attributes.active_color = me.color_attributes["Col"]
    me.color_attributes.render_color_index = 0
    for name in [u.name for u in me.uv_layers]:
        me.uv_layers.remove(me.uv_layers[name])
    me.materials.clear()


def _weld_smooth(ob):
    """Joins the vertices a faceted (flat-shaded) mesh has split along its
    edges and shades it smooth. The game's outline is the mesh pushed out
    along its normals: on a faceted mesh every face would move its own way
    and the line would tear at each edge."""
    import bmesh
    me = ob.data
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bm.to_mesh(me)
    bm.free()
    for poly in me.polygons:
        poly.use_smooth = True
    for edge in me.edges:
        edge.use_edge_sharp = False
    if me.has_custom_normals:
        with bpy.context.temp_override(object=ob, active_object=ob, selected_objects=[ob]):
            bpy.ops.mesh.customdata_custom_splitnormals_clear()
    me.update()


def _split_face(ob):
    """Splits off the pieces the blendshapes move (the eyes, the tear and
    sweat drops) into their own mesh, which keeps the blendshapes; the body
    loses them. A blendshape stores every vertex of its mesh again, so on
    the whole body thirty of them would be thirty copies of the animal."""
    me = ob.data
    if me.shape_keys is None:
        return None
    keys = me.shape_keys.key_blocks
    n = len(me.vertices)
    base = np.empty(n * 3)
    keys[0].data.foreach_get("co", base)
    moved = np.zeros(n, bool)
    for kb in keys[1:]:
        co = np.empty(n * 3)
        kb.data.foreach_get("co", co)
        moved |= (np.abs(co - base).reshape(-1, 3).max(axis=1) > 1e-6)
    # Whole loose pieces: any piece with a moved vertex.
    edges = np.empty(len(me.edges) * 2, int)
    me.edges.foreach_get("vertices", edges)
    edges = edges.reshape(-1, 2)
    label = np.arange(n)
    while True:
        low = np.minimum(label[edges[:, 0]], label[edges[:, 1]])
        new = label.copy()
        np.minimum.at(new, edges[:, 0], low)
        np.minimum.at(new, edges[:, 1], low)
        if (new == label).all():
            break
        label = new
    face_labels = np.unique(label[moved])
    in_face = np.isin(label, face_labels)
    if not in_face.any():
        return None
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_mode(type="VERT")
    bpy.ops.mesh.select_all(action="DESELECT")
    bpy.ops.object.mode_set(mode="OBJECT")
    me.vertices.foreach_set("select", in_face)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.separate(type="SELECTED")
    bpy.ops.object.mode_set(mode="OBJECT")
    face = next(o for o in bpy.context.selected_objects if o != ob)
    ob.shape_key_clear()
    bpy.ops.object.select_all(action="DESELECT")
    return face


def keep_shapes(face, wanted, drops=("teardrop", "sweat")):
    """Drops the blendshapes a model won't use, and the tear and sweat
    drops (pieces hidden inside the head until a blendshape named like
    `drops` brings them out) when no blendshape that is kept moves them."""
    if face is None or wanted == "all":
        return
    me = face.data
    keys = me.shape_keys.key_blocks
    n = len(me.vertices)
    base = np.empty(n * 3)
    keys[0].data.foreach_get("co", base)
    used = np.zeros(n, bool)
    is_drop = np.zeros(n, bool)
    for kb in list(keys[1:]):
        co = np.empty(n * 3)
        kb.data.foreach_get("co", co)
        moves = np.abs(co - base).reshape(-1, 3).max(axis=1) > 1e-6
        if kb.name.startswith(tuple(drops)):
            is_drop |= moves
        if kb.name in wanted:
            used |= moves
        else:
            face.shape_key_remove(kb)
    edges = np.empty(len(me.edges) * 2, int)
    me.edges.foreach_get("vertices", edges)
    edges = edges.reshape(-1, 2)
    label = np.arange(n)
    while True:
        low = np.minimum(label[edges[:, 0]], label[edges[:, 1]])
        new = label.copy()
        np.minimum.at(new, edges[:, 0], low)
        np.minimum.at(new, edges[:, 1], low)
        if (new == label).all():
            break
        label = new
    drop = np.zeros(n, bool)
    for piece in np.unique(label):
        mine = label == piece
        if is_drop[mine].any() and not used[mine].any():
            drop |= mine
    if drop.any():
        import bmesh
        bm = bmesh.new()
        bm.from_mesh(me)
        bm.verts.ensure_lookup_table()
        bmesh.ops.delete(bm, geom=[bm.verts[i] for i in np.nonzero(drop)[0]], context="VERTS")
        bm.to_mesh(me)
        bm.free()


# --- Animations ----------------------------------------------------------------

def sample(poses, u, loops=True):
    """A clip's pose at `u` (0-1 through it), eased through the pack's
    per-frame poses (a smooth curve through them, not straight lines from
    one to the next: slowed three times for an idle, straight lines would
    show as a twitch on every frame). A clip that `loops` ends on its first
    frame again and wraps round; one that doesn't holds at its ends."""
    n = len(poses) - 1
    if loops:
        x = (u % 1.0) * n
        i = int(math.floor(x)) % n
    else:
        x = min(max(u, 0.0), 1.0) * n
        i = min(int(math.floor(x)), n - 1)
    t = x - math.floor(x) if x < n else 1.0
    out = {}
    for bone in poses[0]:
        if loops:
            p = [poses[(i + k) % n][bone] for k in (-1, 0, 1, 2)]
        else:
            p = [poses[min(max(i + k, 0), n)][bone] for k in (-1, 0, 1, 2)]
        vals = []
        for part in range(3):
            a = [np.array(q[part], float) for q in p]
            if part == 1:
                # Quaternions: all on the side of the one we start from.
                for k in (0, 2, 3):
                    ref = a[1] if k != 3 else a[2]
                    if float(np.dot(a[k], ref)) < 0.0:
                        a[k] = -a[k]
            v = 0.5 * ((2 * a[1]) + (-a[0] + a[2]) * t + (2 * a[0] - 5 * a[1] + 4 * a[2] - a[3]) * t * t
                       + (-a[0] + 3 * a[1] - 3 * a[2] + a[3]) * t * t * t)
            if part == 1:
                v = v / max(np.linalg.norm(v), 1e-9)
            vals.append(v)
        out[bone] = tuple(vals)
    return out


def warp(p, hit, strike):
    """Where in a clip (0-1) an attack is at `p` of the game's animation: the
    clip's own strike moment lands exactly on the game's hit moment (`hit`:
    the share of the animation where the blow lands, from the sheet)."""
    if hit is None or strike is None:
        return p
    if p <= hit:
        return strike * (p / hit)
    return strike + (1.0 - strike) * ((p - hit) / (1.0 - hit))


def pose_at(loaded, spec, p, hit=None):
    """The pose of one of the game's animations at `p` (0-1), from its
    recipe in packs.json: {"clip": name} (one clip, start to end), with
    "strike" (where in the clip the blow lands), "times" (the clip played
    that many times), "clips": [names] (one after another) or "once" (the
    clip doesn't loop: it holds its last frame instead of wrapping)."""
    names = spec.get("clips") or [spec["clip"]] * int(spec.get("times", 1))
    x = min(max(p, 0.0), 1.0) * len(names)
    k = min(int(x), len(names) - 1)
    u = x - k
    if len(names) == 1:
        u = warp(u, hit, spec.get("strike"))
    lo, hi = spec.get("from", 0.0), spec.get("to", 1.0)
    u = lo + (hi - lo) * u
    return sample(loaded.clips[names[k]], u, not spec.get("once", False))


def apply(arm, pose):
    for pb in arm.pose.bones:
        loc, rot, scale = pose[pb.name]
        pb.location = Vector(loc)
        pb.rotation_quaternion = Quaternion(rot)
        pb.scale = Vector(scale)


def rest(arm):
    for pb in arm.pose.bones:
        pb.location = (0, 0, 0)
        pb.rotation_quaternion = (1, 0, 0, 0)
        pb.scale = (1, 1, 1)
    bpy.context.view_layer.update()


def points(loaded):
    """World positions of every vertex as posed now (body and face)."""
    deps = bpy.context.evaluated_depsgraph_get()
    out = []
    for ob in (loaded.body, loaded.face):
        if ob is None:
            continue
        ev = ob.evaluated_get(deps)
        me = ev.to_mesh()
        co = np.empty(len(me.vertices) * 3)
        me.vertices.foreach_get("co", co)
        ev.to_mesh_clear()
        m = np.array(ob.matrix_world)
        out.append(co.reshape(-1, 3) @ m[:3, :3].T + m[:3, 3])
    return np.concatenate(out)


def strike_of(loaded, clip, loops=True):
    """Where in a clip (0-1) the animal reaches furthest forward: its strike."""
    best, at = -1e9, 0.0
    for k in range(41):
        u = k / 40.0
        apply(loaded.arm, sample(loaded.clips[clip], u, loops))
        bpy.context.view_layer.update()
        reach = float(points(loaded)[:, 1].max())
        if reach > best + 1e-6:
            best, at = reach, u
    rest(loaded.arm)
    return round(at, 3)


def recipes(loaded, animal_id):
    """Each game animation's recipe (packs.json "clips"), with each attack's
    strike (where in its clip the blow lands) found when it isn't given."""
    out = {}
    for name, spec in animal(animal_id)["clips"].items():
        spec = dict(spec)
        if name in ATTACKS and "strike" not in spec and "clip" in spec:
            spec["strike"] = strike_of(loaded, spec["clip"], not spec.get("once", False))
        out[name] = spec
    return out


def set_face(loaded, shapes):
    """Sets the face's blendshapes ({name: 0-1}; the rest go to 0)."""
    if loaded.face is None or loaded.face.data.shape_keys is None:
        return
    for kb in loaded.face.data.shape_keys.key_blocks[1:]:
        kb.value = float(shapes.get(kb.name, 0.0))
