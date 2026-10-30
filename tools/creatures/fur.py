"""Real fur: hair strands grown from the body, colored by the coat paint
underneath, combed backward and down, longer on the tail and cheeks.

Uses a hair particle system after the armature modifier, so the fur follows
every pose.
"""
import bpy
import numpy as np

from anatomy import mouth_mask

# Body part -> fur length (as a share of the creature's fur["length"]).
DEFAULT_LENGTHS = {
    "torso": 0.75, "neck": 0.9, "shoulder": 0.7, "thigh": 0.7,
    "head": 0.28, "cheek": 0.75, "snout": 0.1, "jaw": 0.25,
    "front_upper": 0.5, "front_lower": 0.22, "front_paw": 0.18,
    "hind_lower": 0.25, "hind_paw": 0.18,
    "tail": 1.6, "tail_tip": 1.5,
}


def add_fur(creature, body, mesh, quality=1.0, overrides=None):
    fur = dict(creature.fur)
    if not fur.get("strands", True):
        return
    lengths = dict(DEFAULT_LENGTHS)
    lengths.update(fur.get("lengths", {}))
    if overrides:
        fur.update(overrides)
        lengths = dict(overrides.get("lengths", lengths))
    weight = np.zeros(len(mesh.verts))
    for region, share in lengths.items():
        weight += mesh.region_weight(region) * share
    if not overrides and "weight_fn" in fur:
        # A species can vary fur length by position (a bison's woolly cape).
        weight = weight * np.asarray(fur["weight_fn"](mesh), float)
    for center, radius in list(creature.eyes) + ([creature.nose] if creature.nose is not None else []):
        d = np.linalg.norm(mesh.verts - center, axis=1)
        weight *= np.clip((d - radius * 1.3) / (radius * 1.2), 0, 1)
    weight *= 1 - mouth_mask(creature, mesh.verts, reach=3.5)
    peak = max(lengths.values())
    if overrides and "peak" in overrides:
        peak = overrides["peak"]
    vg = body.vertex_groups.new(name="fur_length")
    w = np.clip(weight / peak, 0.0, 1.0)
    for i in range(len(w)):
        vg.add([i], float(w[i]), "REPLACE")

    mod = body.modifiers.new("fur", "PARTICLE_SYSTEM")
    psys = mod.particle_system
    settings = psys.settings
    settings.type = "HAIR"
    settings.use_advanced_hair = True
    area = sum(p.area for p in body.data.polygons)
    settings.count = int(area * fur.get("density", 60000) * quality)
    # With advanced hair the emit speeds set each strand's direction and
    # length, so scale them by the fur length.
    length = fur.get("length", 0.03) * peak
    settings.hair_length = length
    settings.hair_step = 4
    settings.render_step = 3
    settings.display_step = 2
    settings.emit_from = "FACE"
    settings.use_emit_random = True
    lift = fur.get("lift", 0.55)
    comb = np.asarray(fur.get("comb", (0.0, -0.7, -0.35)), float)
    total = np.linalg.norm(comb + np.array([0, 0, lift]))
    # Blender grows advanced hair about 4x the emit speed.
    speed = length / 4.0
    settings.normal_factor = lift * speed / total
    # Comb backward and a little down.
    settings.object_align_factor = tuple(comb * speed / total)
    settings.factor_random = speed * fur.get("messy", 0.15)
    settings.child_type = "INTERPOLATED"
    settings.rendered_child_count = int(fur.get("children", 8))
    settings.child_length = 1.0
    settings.child_radius = fur.get("child_radius", 0.01)
    settings.clump_factor = fur.get("clump", 0.25)
    settings.roughness_1 = fur.get("frizz", 0.002)
    settings.roughness_2 = fur.get("frizz", 0.002) * 0.6
    settings.roughness_endpoint = 0.003
    settings.root_radius = 1.0
    settings.tip_radius = 0.0
    settings.radius_scale = fur.get("strand", 0.0012)
    settings.use_close_tip = True
    psys.vertex_group_length = "fur_length"
    psys.vertex_group_density = "fur_length"
    _calibrate(body, length)
    # Hair gets its own material, colored from the body's paint at the root.
    body.data.materials.append(bpy.data.materials.get(creature.name + "_hair") or _hair_material(creature))
    settings.material = len(body.data.materials)
    # Particle systems must come after the armature so the fur follows poses.
    while body.modifiers.find("fur") < body.modifiers.find("rig"):
        bpy.ops.object.modifier_move_down({"object": body}, modifier="fur")


def _calibrate(body, length):
    """Blender works out advanced hair length from the emit speeds in a way
    that is hard to predict, so measure the longest strands and rescale."""
    for _ in range(2):
        dg = bpy.context.evaluated_depsgraph_get()
        ps = body.evaluated_get(dg).particle_systems[0]
        longest = []
        for p in ps.particles[:3000]:
            keys = np.array([tuple(h.co) for h in p.hair_keys])
            if len(keys) > 1:
                longest.append(np.linalg.norm(np.diff(keys, axis=0), axis=1).sum())
        if not longest:
            return
        measured = float(np.percentile(longest, 98))
        scale = length / measured
        settings = body.particle_systems[0].settings
        if abs(scale - 1) < 0.05:
            return
        settings.normal_factor *= scale
        settings.object_align_factor = tuple(v * scale for v in settings.object_align_factor)
        settings.factor_random *= scale


def _hair_material(creature):
    mat = bpy.data.materials.new(creature.name + "_hair")
    mat.use_nodes = True
    nt = mat.node_tree
    nodes, links = nt.nodes, nt.links
    for n in list(nodes):
        if n.type == "BSDF_PRINCIPLED":
            nodes.remove(n)
    out = nodes["Material Output"]
    hair = nodes.new("ShaderNodeBsdfHairPrincipled")
    hair.parametrization = "COLOR"
    col = nodes.new("ShaderNodeVertexColor")
    col.layer_name = "HairCol"
    # Hair looks lighter than skin paint: darken a touch to match.
    gamma = nodes.new("ShaderNodeGamma")
    gamma.inputs["Gamma"].default_value = creature.fur.get("hair_gamma", 1.6)
    links.new(col.outputs["Color"], gamma.inputs["Color"])
    links.new(gamma.outputs["Color"], hair.inputs["Color"])
    hair.inputs["Roughness"].default_value = 0.45
    hair.inputs["Radial Roughness"].default_value = 0.6
    hair.inputs["Coat"].default_value = 0.15
    links.new(hair.outputs[0], out.inputs["Surface"])
    return mat
