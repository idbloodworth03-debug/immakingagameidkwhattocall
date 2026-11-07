"""Renders the material library (materials.py) under the standard studio
lights, one sample of each on a row of pedestals, for the style guide
(docs/ART_DIRECTION.md):

    python material_sheet.py out.png [samples]

Short, long and fluffy fur; feathers; scales; shell; skin; horn and a
claw; an eye. Each in one of our bold palette colors.
"""
import math
import sys
import time

import bpy
import numpy as np

import materials as M

OUT = sys.argv[1] if len(sys.argv) > 1 else "materials.png"
SAMPLES = int(sys.argv[2]) if len(sys.argv) > 2 else 96
# --quick: half size and a tenth of the hair, to check a change fast.
QUICK = "--quick" in sys.argv

# Each sample: (label, palette color) in a 5 x 2 grid.
SPACING = 1.45


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = SAMPLES
    sc.cycles.use_denoising = True
    sc.render.film_transparent = False
    sc.view_settings.view_transform = "Standard"
    sc.view_settings.look = "Medium High Contrast"
    sc.render.resolution_x = 1800
    sc.render.resolution_y = 1000
    sc.render.resolution_percentage = 50 if QUICK else 100
    return sc


def sphere(name, loc, radius=0.42, subdiv=5):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=subdiv, radius=radius, location=loc)
    obj = bpy.context.object
    obj.name = name
    bpy.ops.object.shade_smooth()
    return obj


def fibonacci_sphere(n, radius, lower_cut=-0.75):
    pts, nrm = [], []
    golden = math.pi * (3 - math.sqrt(5))
    for i in range(n):
        z = 1 - (i + 0.5) / n * 2
        if z < lower_cut:
            continue
        r = math.sqrt(1 - z * z)
        a = golden * i
        p = np.array([math.cos(a) * r, math.sin(a) * r, z])
        pts.append(p * radius)
        nrm.append(p)
    return pts, nrm


def ground(color=(0.16, 0.22, 0.33, 1.0)):
    bpy.ops.mesh.primitive_plane_add(size=40, location=(0, 0, 0))
    plane = bpy.context.object
    m = bpy.data.materials.new("ground")
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = color
    b.inputs["Roughness"].default_value = 0.9
    plane.data.materials.append(m)
    # A backdrop curving up behind, so the samples stand in a little studio.
    bpy.ops.mesh.primitive_plane_add(size=40, location=(0, 6, 8), rotation=(math.radians(90), 0, 0))
    wall = bpy.context.object
    wall.data.materials.append(m)


def main():
    t0 = time.time()
    reset()
    ground()
    # The step for the back row.
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 1.7, 0.27))
    step = bpy.context.object
    step.scale = (8.0, 1.2, 0.55)
    step.data.materials.append(bpy.data.materials["ground"])
    M.studio_lights(target=(0, 0.6, 0.45), scale=1.8)
    rgba = M.rgba
    cols = [-2, -1, 0, 1, 2]
    z = 0.45
    def at(i, row):
        # The back row stands on a step, so the front row doesn't hide it.
        return (cols[i] * SPACING, row * 1.7, z + row * 0.55)

    # Row 0 (front): the three furs, feathers, scales.
    fur_specs = [("short", "#ef6f24"), ("long", "#7cc2f2"), ("fluffy", "#f2b234")]
    for i, (kind, color) in enumerate(fur_specs):
        s = sphere("fur_" + kind, at(i, 0), radius=0.36)
        under = M.skin_material(M.shade(rgba(color), 0.45), "under_" + kind)
        s.data.materials.append(under)
        M.add_fur(s, rgba(color), kind, seed=i, density=0.15 if QUICK else 1.0)
    # Feathers on a sphere, combed down and back.
    body = sphere("feather_body", at(3, 0), radius=0.34)
    body.data.materials.append(M.skin_material(M.shade(rgba("#2f86e0"), 0.5), "feather_under"))
    pts, nrm = fibonacci_sphere(int(M.MAT["feathers"]["count"] * (0.5 if QUICK else 1.0)), 0.34, lower_cut=-0.9)
    pts = [p + np.array(at(3, 0)) for p in pts]
    M.scatter_feathers(pts, nrm, comb=(0.0, 0.25, -1.0), color=rgba("#2f86e0"), seed=3, follow=0.34)
    s = sphere("scales", at(4, 0), radius=0.38)
    s.data.materials.append(M.scales_material(rgba("#3fae4a")))

    # Row 1 (back): shell, skin, horn + claw, eye.
    shell = sphere("shell", at(0, 1), radius=0.4)
    shell.scale = (1.0, 1.0, 0.72)
    shell.data.materials.append(M.shell_material(rgba("#7a9a3a")))
    skin = sphere("skin", at(1, 1), radius=0.38)
    skin.data.materials.append(M.skin_material(rgba("#7fb3e8")))
    # A horn (a curved cone) and a claw beside it.
    bpy.ops.mesh.primitive_cone_add(vertices=48, radius1=0.2, radius2=0.025, depth=0.95, location=(at(2, 1)[0] - 0.12, at(2, 1)[1], 0.38 + 0.55))
    horn = bpy.context.object
    bpy.ops.object.shade_smooth()
    bend = horn.modifiers.new("bend", "SIMPLE_DEFORM")
    bend.deform_method = "BEND"
    bend.angle = math.radians(55)
    bend.deform_axis = "Y"
    horn.data.materials.append(M.horn_material(rgba("#f2e6c8"), axis_len=0.95))
    # Object space runs from -depth/2: shift the horn's own origin to its base.
    for v in horn.data.vertices:
        v.co.z += 0.475
    horn.location.z = 0.57
    bpy.ops.mesh.primitive_cone_add(vertices=32, radius1=0.1, radius2=0.006, depth=0.42, location=(at(2, 1)[0] + 0.24, at(2, 1)[1] - 0.15, 0.69), rotation=(math.radians(70), 0, 0))
    claw = bpy.context.object
    bpy.ops.object.shade_smooth()
    claw.data.materials.append(M.claw_material())
    # An eye: looking at the camera (its -Y axis).
    eye = sphere("eye", at(3, 1), radius=0.36, subdiv=6)
    eye.data.materials.append(M.eye_material(rgba("#3b8ff0")))
    eye.rotation_euler = (math.radians(-12), 0, math.radians(8))
    # A last fluffy-skin sample: a cartoon nose (skin, darker, glossy).
    nose = sphere("nose", at(4, 1), radius=0.3)
    nose.scale = (1.15, 0.9, 0.85)
    nm = M.skin_material(rgba("#3a2d3a"), "nose")
    nm.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.25
    nose.data.materials.append(nm)

    bpy.ops.object.camera_add(location=(0, -8.6, 4.6))
    cam = bpy.context.object
    cam.data.lens = 40
    from mathutils import Vector
    cam.rotation_euler = (Vector((0, 0.9, 0.55)) - cam.location).to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.camera = cam
    bpy.context.scene.render.filepath = OUT
    bpy.ops.render.render(write_still=True)
    print("rendered %s in %.0f s" % (OUT, time.time() - t0))


main()
