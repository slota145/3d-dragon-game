"""Zwierzyna w baśniowym stylu low-poly: królik, owca, sarna, dzik, koza, kaczka, kura.

    .venv-tools/bin/python tools/blender/gen_animals.py   # -> assets/models/animals.glb

Bez szkieletu: każde zwierzę to osobne części <Gatunek>_Body, _Head, _LegFL/_LegFR/_LegBL/_LegBR
(ptaki: _LegL/_LegR, _WingL/_WingR) z punktem obrotu w stawie — gra animuje je w kodzie
(scripts/game/wildlife.gd: chód, bieg, kicanie, skubanie trawy, machanie skrzydłami).

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


def part(name: str, b: MeshBuilder, mats, pivot) -> bpy.types.Object:
    """Część z punktem obrotu w `pivot` (siatka budowana we współrzędnych świata)."""
    obj = b.to_object(name, mats)
    pv = Vector(pivot)
    for v in obj.data.vertices:
        v.co -= pv
    obj.location = pv
    return obj


def quad_legs(name: str, mats, names, hips, length: float, r: float, mat: str, hoof: str | None,
              hoof_r: float | None = None) -> list:
    """Cztery nogi (FL, FR, BL, BR) od biodra/barku w dół do ziemi."""
    out = []
    for tag, (x, y, z) in zip(("FL", "FR", "BL", "BR"), hips):
        b = MeshBuilder(names)
        b.tube([V(x, y, z), V(x, y + 0.02, z - length * 0.55), V(x, y, z - length)], [r, r * 0.8, r * 0.65], 5,
               mat, tip=False)
        if hoof:
            blob(b, (x, y - 0.01, max(z - length, 0) + (hoof_r or r) * 0.5), ((hoof_r or r) * 1.1,
                 (hoof_r or r) * 1.3, (hoof_r or r) * 0.7), hoof, seg=5, rings=3)
        out.append(part(f"{name}_Leg{tag}", b, mats, (x, y, z)))
    return out


def rabbit():
    pal = {"Rabbit_Fur": (0.62, 0.44, 0.28), "Rabbit_Belly": (0.95, 0.9, 0.82), "Rabbit_Ear": (0.95, 0.62, 0.6),
           "Rabbit_Eye": (0.02, 0.02, 0.02), "Rabbit_Nose": (0.95, 0.45, 0.5)}
    mats, names = make_materials(pal), list(pal)
    objs = []
    b = MeshBuilder(names)
    blob(b, (0, 0.04, 0.2), (0.15, 0.22, 0.16), "Rabbit_Fur")
    blob(b, (0, -0.02, 0.16), (0.11, 0.15, 0.1), "Rabbit_Belly")
    blob(b, (0, 0.27, 0.24), (0.07, 0.06, 0.07), "Rabbit_Belly", seg=5, rings=3)
    objs.append(part("Rabbit_Body", b, mats, (0, 0, 0)))
    b = MeshBuilder(names)
    blob(b, (0, -0.2, 0.33), (0.1, 0.11, 0.1), "Rabbit_Fur")
    for s in (1, -1):
        b.tube([V(0.04 * s, -0.17, 0.4), V(0.07 * s, -0.12, 0.56), V(0.09 * s, -0.08, 0.68)],
               [0.05, 0.045, 0.0], 5, "Rabbit_Ear", flatten=0.4, tip=True)
        blob(b, (0.065 * s, -0.27, 0.36), (0.022, 0.022, 0.025), "Rabbit_Eye", seg=5, rings=3)
    blob(b, (0, -0.3, 0.31), (0.025, 0.02, 0.02), "Rabbit_Nose", seg=5, rings=3)
    objs.append(part("Rabbit_Head", b, mats, (0, -0.12, 0.28)))
    for tag, s in (("BL", 1), ("BR", -1)):  # tylne: udo + długa stopa
        b = MeshBuilder(names)
        blob(b, (0.1 * s, 0.1, 0.12), (0.06, 0.12, 0.08), "Rabbit_Fur", seg=6, rings=4)
        blob(b, (0.1 * s, 0.02, 0.02), (0.035, 0.1, 0.025), "Rabbit_Belly", seg=5, rings=3)
        objs.append(part(f"Rabbit_Leg{tag}", b, mats, (0.1 * s, 0.12, 0.16)))
    for tag, s in (("FL", 1), ("FR", -1)):
        b = MeshBuilder(names)
        b.tube([V(0.06 * s, -0.1, 0.14), V(0.06 * s, -0.12, 0.02)], [0.03, 0.025], 5, "Rabbit_Belly", tip=False)
        objs.append(part(f"Rabbit_Leg{tag}", b, mats, (0.06 * s, -0.1, 0.14)))
    return objs


def sheep():
    pal = {"Sheep_Wool": (0.93, 0.91, 0.86), "Sheep_Skin": (0.12, 0.11, 0.12), "Sheep_Eye": (0.95, 0.95, 0.9),
           "Sheep_Pupil": (0.02, 0.02, 0.02)}
    mats, names = make_materials(pal), list(pal)
    rnd = random.Random(3)
    objs = []
    b = MeshBuilder(names)
    for i in range(14):
        a = rnd.uniform(0, 2 * math.pi)
        y = rnd.uniform(-0.35, 0.4)
        r = rnd.uniform(0.2, 0.28)
        blob(b, (0.2 * math.cos(a) * rnd.uniform(0.6, 1), y, 0.72 + 0.16 * math.sin(a)), (r, r, r * 0.9),
             "Sheep_Wool", seg=6, rings=4, jitter=0.08, rnd=rnd)
    blob(b, (0, 0.0, 0.72), (0.36, 0.55, 0.3), "Sheep_Wool", seg=8, rings=5)
    objs.append(part("Sheep_Body", b, mats, (0, 0, 0)))
    b = MeshBuilder(names)
    blob(b, (0, -0.62, 0.86), (0.13, 0.19, 0.14), "Sheep_Skin")
    blob(b, (0, -0.55, 1.0), (0.13, 0.11, 0.08), "Sheep_Wool", seg=6, rings=4)
    for s in (1, -1):
        b.tube([V(0.1 * s, -0.56, 0.92), V(0.24 * s, -0.52, 0.88)], [0.05, 0.0], 5, "Sheep_Skin", flatten=0.4,
               tip=True, samples=2)
        blob(b, (0.085 * s, -0.74, 0.92), (0.035, 0.03, 0.04), "Sheep_Eye", seg=5, rings=3)
        blob(b, (0.1 * s, -0.765, 0.92), (0.015, 0.012, 0.022), "Sheep_Pupil", seg=4, rings=2)
    objs.append(part("Sheep_Head", b, mats, (0, -0.45, 0.82)))
    objs += quad_legs("Sheep", mats, names, [(0.17, -0.3, 0.5), (-0.17, -0.3, 0.5), (0.17, 0.3, 0.5),
                                             (-0.17, 0.3, 0.5)], 0.5, 0.07, "Sheep_Skin", None)
    return objs


def deer():
    pal = {"Deer_Fur": (0.55, 0.3, 0.12), "Deer_White": (0.92, 0.88, 0.8), "Deer_Dark": (0.08, 0.05, 0.03),
           "Deer_Antler": (0.75, 0.65, 0.5)}
    mats, names = make_materials(pal), list(pal)
    objs = []
    b = MeshBuilder(names)
    blob(b, (0, 0.0, 0.88), (0.2, 0.52, 0.24), "Deer_Fur", seg=8, rings=5)
    blob(b, (0, 0.47, 0.92), (0.15, 0.1, 0.17), "Deer_White", seg=6, rings=4)  # biały „lusterko”
    blob(b, (0, -0.05, 0.72), (0.15, 0.4, 0.1), "Deer_White", seg=6, rings=3)  # brzuch
    objs.append(part("Deer_Body", b, mats, (0, 0, 0)))
    b = MeshBuilder(names)
    b.tube([V(0, -0.42, 1.0), V(0, -0.58, 1.25), V(0, -0.66, 1.42)], [0.11, 0.09, 0.08], 6, "Deer_Fur", tip=False)
    blob(b, (0, -0.76, 1.45), (0.09, 0.17, 0.1), "Deer_Fur", seg=7, rings=4)
    blob(b, (0, -0.92, 1.42), (0.04, 0.04, 0.035), "Deer_Dark", seg=5, rings=3)
    for s in (1, -1):
        b.tube([V(0.06 * s, -0.68, 1.52), V(0.16 * s, -0.66, 1.62)], [0.05, 0.0], 5, "Deer_Fur", flatten=0.4,
               tip=True, samples=2)
        blob(b, (0.07 * s, -0.83, 1.5), (0.02, 0.02, 0.022), "Deer_Dark", seg=4, rings=2)
        b.tube([V(0.04 * s, -0.7, 1.55), V(0.08 * s, -0.68, 1.75), V(0.1 * s, -0.72, 1.88)], [0.025, 0.02, 0.0], 4,
               "Deer_Antler", tip=True)
        b.tube([V(0.07 * s, -0.69, 1.72), V(0.13 * s, -0.78, 1.8)], [0.015, 0.0], 4, "Deer_Antler", tip=True)
    objs.append(part("Deer_Head", b, mats, (0, -0.4, 1.0)))
    objs += quad_legs("Deer", mats, names, [(0.12, -0.36, 0.78), (-0.12, -0.36, 0.78), (0.12, 0.38, 0.8),
                                            (-0.12, 0.38, 0.8)], 0.78, 0.05, "Deer_Fur", "Deer_Dark", 0.035)
    return objs


def boar():
    pal = {"Boar_Fur": (0.16, 0.1, 0.07), "Boar_Bristle": (0.08, 0.05, 0.04), "Boar_Snout": (0.45, 0.3, 0.28),
           "Boar_Tusk": (0.92, 0.9, 0.82), "Boar_Eye": (0.02, 0.02, 0.02)}
    mats, names = make_materials(pal), list(pal)
    objs = []
    rnd = random.Random(8)
    b = MeshBuilder(names)
    blob(b, (0, 0.05, 0.55), (0.3, 0.58, 0.32), "Boar_Fur", seg=8, rings=5, jitter=0.05, rnd=rnd)
    for k in range(6):  # szczecina na grzbiecie
        b.tube([V(0, -0.3 + k * 0.12, 0.84), V(0, -0.26 + k * 0.12, 0.97)], [0.05, 0.0], 4, "Boar_Bristle", tip=True)
    b.tube([V(0, 0.6, 0.62), V(0, 0.68, 0.5)], [0.03, 0.01], 4, "Boar_Bristle", tip=False)
    objs.append(part("Boar_Body", b, mats, (0, 0, 0)))
    b = MeshBuilder(names)
    blob(b, (0, -0.62, 0.55), (0.22, 0.3, 0.24), "Boar_Fur", seg=7, rings=5)
    b.tube([V(0, -0.82, 0.5), V(0, -1.02, 0.42)], [0.12, 0.1], 6, "Boar_Fur", tip=False)
    blob(b, (0, -1.04, 0.42), (0.1, 0.03, 0.09), "Boar_Snout", seg=6, rings=3)
    for s in (1, -1):
        b.tube([V(0.08 * s, -0.95, 0.38), V(0.13 * s, -1.0, 0.5)], [0.025, 0.0], 4, "Boar_Tusk", tip=True)
        b.tube([V(0.13 * s, -0.5, 0.72), V(0.2 * s, -0.48, 0.85)], [0.06, 0.0], 4, "Boar_Fur", flatten=0.4, tip=True)
        blob(b, (0.13 * s, -0.75, 0.62), (0.025, 0.025, 0.025), "Boar_Eye", seg=4, rings=2)
    objs.append(part("Boar_Head", b, mats, (0, -0.45, 0.6)))
    objs += quad_legs("Boar", mats, names, [(0.16, -0.35, 0.38), (-0.16, -0.35, 0.38), (0.16, 0.4, 0.38),
                                            (-0.16, 0.4, 0.38)], 0.38, 0.065, "Boar_Fur", "Boar_Bristle", 0.05)
    return objs


def goat():
    pal = {"Goat_Fur": (0.85, 0.82, 0.76), "Goat_Grey": (0.45, 0.42, 0.4), "Goat_Horn": (0.3, 0.26, 0.2),
           "Goat_Eye": (0.6, 0.45, 0.1)}
    mats, names = make_materials(pal), list(pal)
    objs = []
    b = MeshBuilder(names)
    blob(b, (0, 0.0, 0.75), (0.2, 0.45, 0.24), "Goat_Fur", seg=8, rings=5)
    blob(b, (0, 0.42, 0.85), (0.06, 0.06, 0.08), "Goat_Grey", seg=5, rings=3)
    objs.append(part("Goat_Body", b, mats, (0, 0, 0)))
    b = MeshBuilder(names)
    b.tube([V(0, -0.36, 0.85), V(0, -0.5, 1.05)], [0.1, 0.08], 6, "Goat_Fur", tip=False)
    blob(b, (0, -0.6, 1.1), (0.09, 0.17, 0.1), "Goat_Fur", seg=7, rings=4)
    b.tube([V(0, -0.68, 1.0), V(0, -0.7, 0.86)], [0.04, 0.0], 4, "Goat_Grey", tip=True)  # bródka
    for s in (1, -1):
        b.tube([V(0.05 * s, -0.55, 1.18), V(0.08 * s, -0.42, 1.36), V(0.1 * s, -0.3, 1.38)], [0.035, 0.025, 0.0], 5,
               "Goat_Horn", tip=True)
        b.tube([V(0.08 * s, -0.52, 1.12), V(0.2 * s, -0.55, 1.08)], [0.04, 0.0], 4, "Goat_Fur", flatten=0.4,
               tip=True, samples=2)
        blob(b, (0.07 * s, -0.68, 1.15), (0.02, 0.02, 0.02), "Goat_Eye", seg=4, rings=2)
    objs.append(part("Goat_Head", b, mats, (0, -0.34, 0.85)))
    objs += quad_legs("Goat", mats, names, [(0.12, -0.3, 0.62), (-0.12, -0.3, 0.62), (0.12, 0.32, 0.62),
                                            (-0.12, 0.32, 0.62)], 0.62, 0.05, "Goat_Fur", "Goat_Grey", 0.035)
    return objs


def bird(name: str, pal: dict, body_mat: str, head_mat: str, beak_mat: str, leg_mat: str, wing_mat: str,
         scale: float, extra=None, head_extra=None):
    mats, names = make_materials(pal), list(pal)
    objs = []
    k = scale
    b = MeshBuilder(names)
    blob(b, (0, 0.02 * k, 0.3 * k), (0.15 * k, 0.22 * k, 0.15 * k), body_mat, seg=7, rings=5)
    b.tube([V(0, 0.18 * k, 0.34 * k), V(0, 0.3 * k, 0.45 * k)], [0.08 * k, 0.0], 5, wing_mat, flatten=0.4, tip=True)
    if extra:
        extra(b, k)
    objs.append(part(f"{name}_Body", b, mats, (0, 0, 0)))
    b = MeshBuilder(names)
    b.tube([V(0, -0.14 * k, 0.38 * k), V(0, -0.18 * k, 0.52 * k)], [0.06 * k, 0.05 * k], 5, head_mat, tip=False)
    blob(b, (0, -0.2 * k, 0.56 * k), (0.07 * k, 0.08 * k, 0.07 * k), head_mat, seg=6, rings=4)
    b.tube([V(0, -0.27 * k, 0.55 * k), V(0, -0.36 * k, 0.53 * k)], [0.03 * k, 0.005], 4, beak_mat, flatten=0.5,
           tip=True, samples=2)
    for s in (1, -1):
        blob(b, (0.045 * s * k, -0.24 * k, 0.58 * k), (0.012 * k, 0.012 * k, 0.012 * k), "Bird_Eye", seg=4, rings=2)
    if head_extra:
        head_extra(b, k)
    objs.append(part(f"{name}_Head", b, mats, (0, -0.13 * k, 0.38 * k)))
    for tag, s in (("L", 1), ("R", -1)):
        b = MeshBuilder(names)
        blob(b, (0.13 * s * k, 0.04 * k, 0.32 * k), (0.035 * k, 0.17 * k, 0.09 * k), wing_mat, seg=5, rings=3)
        objs.append(part(f"{name}_Wing{tag}", b, mats, (0.12 * s * k, 0.0, 0.36 * k)))
        b = MeshBuilder(names)
        b.tube([V(0.05 * s * k, 0.02 * k, 0.18 * k), V(0.05 * s * k, 0.0, 0.01)], [0.012 * k, 0.01 * k], 4, leg_mat,
               tip=False)
        blob(b, (0.05 * s * k, -0.04 * k, 0.01), (0.04 * k, 0.05 * k, 0.01), leg_mat, seg=4, rings=2)
        objs.append(part(f"{name}_Leg{tag}", b, mats, (0.05 * s * k, 0.02 * k, 0.18 * k)))
    return objs


def duck():
    pal = {"Duck_Brown": (0.42, 0.3, 0.18), "Duck_Green": (0.05, 0.35, 0.15), "Duck_Orange": (1.0, 0.55, 0.1),
           "Duck_Wing": (0.3, 0.25, 0.2), "Bird_Eye": (0.02, 0.02, 0.02), "Duck_Collar": (0.95, 0.95, 0.95)}
    return bird("Duck", pal, "Duck_Brown", "Duck_Green", "Duck_Orange", "Duck_Orange", "Duck_Wing", 0.9)


def chicken():
    pal = {"Chicken_White": (0.95, 0.93, 0.88), "Chicken_Red": (0.85, 0.1, 0.08), "Chicken_Yellow": (1.0, 0.75, 0.15),
           "Bird_Eye": (0.02, 0.02, 0.02)}

    def comb(b, k):
        for i in range(3):
            blob(b, (0, (-0.24 + i * 0.05) * k, (0.64 - abs(i - 1) * 0.015) * k), (0.015 * k, 0.025 * k, 0.03 * k),
                 "Chicken_Red", seg=4, rings=3)
        blob(b, (0, -0.28 * k, 0.5 * k), (0.015 * k, 0.015 * k, 0.03 * k), "Chicken_Red", seg=4, rings=3)  # korale

    def tail(b, k):
        for i in (-1, 0, 1):
            b.tube([V(0.03 * i * k, 0.15 * k, 0.35 * k), V(0.05 * i * k, 0.26 * k, 0.55 * k)], [0.05 * k, 0.0], 4,
                   "Chicken_White", flatten=0.4, tip=True)

    return bird("Chicken", pal, "Chicken_White", "Chicken_White", "Chicken_Yellow", "Chicken_Yellow",
                "Chicken_White", 1.0, extra=tail, head_extra=comb)


def finish_all(objs, seed: int):
    for i, o in enumerate(objs):
        flat_shade(o)
        face_color_variation(o, amount=0.06, seed=seed + i)


def export(obj: bpy.types.Object, path: pathlib.Path) -> None:
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.export_scene.gltf(filepath=str(path), export_format="GLB", use_selection=True, export_yup=True,
                              export_vertex_color="MATERIAL")
    print(f"Wyeksportowano: {path}")


if __name__ == "__main__":
    common.reset_scene()
    all_objs = []
    for i, build in enumerate((rabbit, sheep, deer, boar, goat, duck, chicken)):
        objs = build()
        finish_all(objs, i * 20)
        print(f"{objs[0].name.split('_')[0]}: {sum(tri_count(o) for o in objs)} trójkątów, {len(objs)} części")
        all_objs += objs
    bpy.ops.object.select_all(action="DESELECT")
    for o in all_objs:
        o.select_set(True)
    path = common.MODELS_DIR / "animals.glb"
    bpy.ops.export_scene.gltf(filepath=str(path), export_format="GLB", use_selection=True, export_yup=True,
                              export_vertex_color="MATERIAL")
    print(f"Wyeksportowano: {path}")
