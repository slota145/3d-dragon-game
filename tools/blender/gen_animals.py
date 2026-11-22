"""Zwierzyna w baśniowym stylu low-poly: królik i owca (bez szkieletu — ruch robi kod gry).

    .venv-tools/bin/python tools/blender/gen_animals.py                  # -> assets/models/rabbit.glb, sheep.glb
    .venv-tools/bin/python tools/blender/gen_animals.py -- --preview DIR  # + rendery

Konwencje jak smok: Z w górę, przód = -Y (w Godocie +Z), pivot na ziemi, 1 j. = 1 m.
Kolory: jasne, nasycone, „zabawkowe” — kontrast z mrocznym smokiem.
"""

from __future__ import annotations

import math
import pathlib
import random
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))

import bpy  # noqa: E402
from mathutils import Vector  # noqa: E402

import common  # noqa: E402
from meshkit import MeshBuilder, face_color_variation, flat_shade, tri_count  # noqa: E402


def V(x, y, z) -> Vector:
    return Vector((x, y, z))


def make_materials(palette: dict[str, tuple]) -> dict[str, bpy.types.Material]:
    mats = {}
    for name, color in palette.items():
        mat = common.material(name, color, roughness=0.9)
        nt = mat.node_tree
        bsdf = nt.nodes["Principled BSDF"]
        vc = nt.nodes.new("ShaderNodeVertexColor")
        vc.layer_name = "Col"
        mix = nt.nodes.new("ShaderNodeMix")
        mix.data_type = "RGBA"
        mix.blend_type = "MULTIPLY"
        mix.inputs["Factor"].default_value = 1.0
        mix.inputs[6].default_value = (*color, 1.0)
        nt.links.new(vc.outputs["Color"], mix.inputs[7])
        nt.links.new(mix.outputs[2], bsdf.inputs["Base Color"])
        mats[name] = mat
    return mats


def blob(b: MeshBuilder, center, radii, mat, seg: int = 7, rings: int = 5, jitter: float = 0.0,
         rnd: random.Random | None = None) -> None:
    """Elipsoida low-poly (opcjonalnie lekko „pogięta” dla naturalności)."""
    c = Vector(center)
    pts = []
    for i in range(rings + 1):
        th = math.pi * i / rings
        if i in (0, rings):
            pts.append(c + V(0, 0, radii[2] * math.cos(th)))
            continue
        ring = []
        for k in range(seg):
            ph = 2 * math.pi * k / seg
            j = 1.0 + (rnd.uniform(-jitter, jitter) if rnd else 0.0)
            ring.append(c + V(radii[0] * math.sin(th) * math.cos(ph) * j, radii[1] * math.sin(th) * math.sin(ph) * j,
                              radii[2] * math.cos(th) * j))
        pts.append(ring)
    b.loft(pts, mat, cap_start=False, cap_end=False)


def finish(name: str, b: MeshBuilder, mats) -> bpy.types.Object:
    obj = b.to_object(name, mats)
    flat_shade(obj)
    face_color_variation(obj, amount=0.06, seed=len(name))
    print(f"{name}: {tri_count(obj)} trójkątów")
    return obj


def build_rabbit() -> bpy.types.Object:
    pal = {"Rabbit_Fur": (0.62, 0.44, 0.28), "Rabbit_Belly": (0.95, 0.9, 0.82), "Rabbit_Ear": (0.95, 0.62, 0.6),
           "Rabbit_Eye": (0.02, 0.02, 0.02), "Rabbit_Nose": (0.95, 0.45, 0.5)}
    mats = make_materials(pal)
    b = MeshBuilder(list(pal))
    blob(b, (0, 0.04, 0.2), (0.15, 0.22, 0.16), "Rabbit_Fur")          # tułów
    blob(b, (0, -0.02, 0.16), (0.11, 0.15, 0.1), "Rabbit_Belly")       # brzuch
    blob(b, (0, -0.2, 0.33), (0.1, 0.11, 0.1), "Rabbit_Fur")           # głowa
    blob(b, (0, 0.27, 0.24), (0.07, 0.06, 0.07), "Rabbit_Belly", seg=5, rings=3)  # ogonek
    for s in (1, -1):
        b.tube([V(0.04 * s, -0.17, 0.4), V(0.07 * s, -0.12, 0.56), V(0.09 * s, -0.08, 0.68)],
               [0.05, 0.045, 0.0], 5, "Rabbit_Ear", flatten=0.4, tip=True)   # uszy
        blob(b, (0.065 * s, -0.27, 0.36), (0.022, 0.022, 0.025), "Rabbit_Eye", seg=5, rings=3)
        blob(b, (0.1 * s, 0.1, 0.1), (0.06, 0.12, 0.08), "Rabbit_Fur", seg=6, rings=4)   # udo
        blob(b, (0.06 * s, -0.12, 0.05), (0.03, 0.05, 0.05), "Rabbit_Belly", seg=5, rings=3)  # przednia łapka
    blob(b, (0, -0.3, 0.31), (0.025, 0.02, 0.02), "Rabbit_Nose", seg=5, rings=3)
    return finish("Rabbit", b, mats)


def build_sheep() -> bpy.types.Object:
    pal = {"Sheep_Wool": (0.93, 0.91, 0.86), "Sheep_Skin": (0.12, 0.11, 0.12), "Sheep_Eye": (0.95, 0.95, 0.9),
           "Sheep_Pupil": (0.02, 0.02, 0.02)}
    mats = make_materials(pal)
    rnd = random.Random(3)
    b = MeshBuilder(list(pal))
    # wełna: chmurka kłębków
    for i in range(14):
        a = rnd.uniform(0, 2 * math.pi)
        y = rnd.uniform(-0.35, 0.4)
        r = rnd.uniform(0.2, 0.28)
        blob(b, (0.2 * math.cos(a) * rnd.uniform(0.6, 1), y, 0.72 + 0.16 * math.sin(a)), (r, r, r * 0.9),
             "Sheep_Wool", seg=6, rings=4, jitter=0.08, rnd=rnd)
    blob(b, (0, 0.0, 0.72), (0.36, 0.55, 0.3), "Sheep_Wool", seg=8, rings=5)
    # głowa (ciemna), uszy, oczy, kłębek na czubku
    blob(b, (0, -0.62, 0.86), (0.13, 0.19, 0.14), "Sheep_Skin")
    blob(b, (0, -0.55, 1.0), (0.13, 0.11, 0.08), "Sheep_Wool", seg=6, rings=4)
    for s in (1, -1):
        b.tube([V(0.1 * s, -0.56, 0.92), V(0.24 * s, -0.52, 0.88)], [0.05, 0.0], 5, "Sheep_Skin", flatten=0.4,
               tip=True, samples=2)
        blob(b, (0.085 * s, -0.74, 0.92), (0.035, 0.03, 0.04), "Sheep_Eye", seg=5, rings=3)
        blob(b, (0.1 * s, -0.765, 0.92), (0.015, 0.012, 0.022), "Sheep_Pupil", seg=4, rings=2)
        for y in (-0.3, 0.3):  # nogi
            b.tube([V(0.17 * s, y, 0.48), V(0.17 * s, y, 0.0)], [0.075, 0.06], 5, "Sheep_Skin", tip=False,
                   samples=1)
    return finish("Sheep", b, mats)


def export(obj: bpy.types.Object, path: pathlib.Path) -> None:
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.export_scene.gltf(filepath=str(path), export_format="GLB", use_selection=True, export_yup=True,
                              export_vertex_color="MATERIAL")
    print(f"Wyeksportowano: {path}")


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    preview = pathlib.Path(argv[argv.index("--preview") + 1]).resolve() if "--preview" in argv else None
    for name, build, target, dist in (("rabbit", build_rabbit, (0, 0, 0.3), 1.6),
                                      ("sheep", build_sheep, (0, 0, 0.6), 3.4)):
        common.reset_scene()
        obj = build()
        export(obj, common.MODELS_DIR / f"{name}.glb")
        if preview:
            common.render_preview(preview / f"{name}.png", target=target, distance=dist, azimuth_deg=-50,
                                  elevation_deg=15, resolution=(480, 400), exposure=0.8,
                                  background=(0.55, 0.75, 0.45))
