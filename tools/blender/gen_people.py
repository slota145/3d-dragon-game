"""Ludzie low-poly: wieśniak (widły), pasterz (kij pasterski), myśliwy (łuk, kołczan).

    .venv-tools/bin/python tools/blender/gen_people.py   # -> assets/models/people.glb

Bez szkieletu: każda postać to osobne obiekty <Rola>_Body, _LegL, _LegR, _ArmL, _ArmR
z punktem obrotu w stawie (biodro / bark) — gra macha nimi w kodzie (chód, bieg, dźganie).
Wzrost ~1,75 m (pisklę 1 m jest mniejsze od człowieka!). Przód = -Y (w Godocie +Z).
"""

from __future__ import annotations

import math
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))

import bpy  # noqa: E402
from mathutils import Vector  # noqa: E402

import common  # noqa: E402
from gen_animals import blob, make_materials  # noqa: E402
from meshkit import MeshBuilder, face_color_variation, flat_shade, tri_count  # noqa: E402

PALETTE = {
    "People_Skin": (0.75, 0.48, 0.32),
    "People_Hair": (0.12, 0.07, 0.03),
    "People_Brown": (0.25, 0.13, 0.05),
    "People_Green": (0.12, 0.28, 0.08),
    "People_Blue": (0.08, 0.15, 0.4),
    "People_Cream": (0.8, 0.72, 0.5),
    "People_Dark": (0.05, 0.06, 0.04),
    "People_Wood": (0.35, 0.2, 0.08),
    "People_Iron": (0.4, 0.4, 0.42),
    "People_Straw": (0.8, 0.62, 0.22),
}
NAMES = list(PALETTE)
ROLES = {  # tunika, spodnie, nakrycie głowy
    "Villager": ("People_Brown", "People_Cream", "People_Straw"),
    "Shepherd": ("People_Blue", "People_Brown", "People_Cream"),
    "Hunter": ("People_Green", "People_Dark", "People_Green"),
}


def V(x, y, z) -> Vector:
    return Vector((x, y, z))


def part(name: str, b: MeshBuilder, mats, pivot: Vector) -> bpy.types.Object:
    """Obiekt z punktem obrotu w `pivot` (siatka budowana we współrzędnych świata)."""
    obj = b.to_object(name, mats)
    for v in obj.data.vertices:
        v.co -= pivot
    obj.location = pivot
    return obj


def person(role: str, mats) -> list[bpy.types.Object]:
    tunic, pants, hat = ROLES[role]
    objs = []
    # tułów + głowa
    b = MeshBuilder(NAMES)
    b.tube([V(0, 0, 0.88), V(0, 0, 1.15), V(0, 0, 1.45)], [0.2, 0.19, 0.17], 7, tunic, tip=False, flatten=0.7)
    b.tube([V(0, 0, 0.75), V(0, 0, 0.92)], [0.24, 0.21], 7, tunic, tip=False, flatten=0.75)  # poła tuniki
    blob(b, (0, 0, 1.5), (0.06, 0.06, 0.06), "People_Skin", seg=5, rings=3)  # szyja
    blob(b, (0, 0, 1.62), (0.12, 0.13, 0.14), "People_Skin", seg=7, rings=5)  # głowa
    blob(b, (0, 0.03, 1.66), (0.125, 0.125, 0.12), "People_Hair", seg=7, rings=4)
    blob(b, (0, -0.12, 1.6), (0.03, 0.03, 0.03), "People_Skin", seg=4, rings=2)  # nos
    if role == "Villager":  # słomkowy kapelusz
        b.tube([V(0, 0, 1.72), V(0, 0, 1.74)], [0.3, 0.3], 9, hat, tip=False)
        blob(b, (0, 0, 1.78), (0.13, 0.13, 0.08), hat, seg=7, rings=3)
    elif role == "Shepherd":  # czapka i płaszcz
        blob(b, (0, 0.02, 1.73), (0.14, 0.14, 0.08), hat, seg=7, rings=3)
        b.tube([V(0, 0.08, 1.45), V(0, 0.16, 0.95), V(0, 0.18, 0.55)], [0.2, 0.26, 0.3], 7, "People_Brown",
               tip=False, flatten=0.35)
    else:  # kaptur i kołczan
        blob(b, (0, 0.03, 1.68), (0.15, 0.15, 0.16), hat, seg=7, rings=4)
        b.tube([V(0.08, 0.17, 1.0), V(-0.08, 0.2, 1.5)], [0.07, 0.07], 6, "People_Brown", tip=False)
        for k in range(3):
            b.tube([V(-0.06 + k * 0.03, 0.21, 1.45), V(-0.1 + k * 0.03, 0.22, 1.62)], [0.01, 0.01], 4,
                   "People_Cream", tip=True)
    objs.append(part(f"{role}_Body", b, mats, V(0, 0, 0)))
    for side, sx in (("L", 1), ("R", -1)):
        b = MeshBuilder(NAMES)
        hip = V(0.1 * sx, 0, 0.9)
        b.tube([hip, hip + V(0, 0, -0.45), hip + V(0, 0.01, -0.84)], [0.085, 0.07, 0.06], 6, pants, tip=False)
        blob(b, (hip.x, -0.05, 0.05), (0.07, 0.13, 0.06), "People_Dark", seg=5, rings=3)  # but
        objs.append(part(f"{role}_Leg{side}", b, mats, hip))
        b = MeshBuilder(NAMES)
        sh = V(0.25 * sx, 0, 1.42)
        b.tube([sh, sh + V(0.03 * sx, 0, -0.3), sh + V(0.02 * sx, -0.04, -0.58)], [0.06, 0.05, 0.045], 6, tunic,
               tip=False)
        blob(b, sh + V(0.02 * sx, -0.05, -0.64), (0.05, 0.05, 0.06), "People_Skin", seg=5, rings=3)
        if side == "R":  # narzędzie w prawej dłoni (pionowo, wzdłuż ciała)
            hand = sh + V(0.02 * sx, -0.06, -0.64)
            if role == "Villager":  # widły
                b.tube([hand + V(0, 0, -0.7), hand + V(0, 0, 0.75)], [0.022, 0.022], 5, "People_Wood", tip=False)
                for k in (-1, 0, 1):
                    b.tube([hand + V(k * 0.06, 0, 0.75), hand + V(k * 0.07, 0, 1.05)], [0.012, 0.0], 4,
                           "People_Iron", tip=True)
                b.tube([hand + V(-0.08, 0, 0.75), hand + V(0.08, 0, 0.75)], [0.015, 0.015], 4, "People_Iron",
                       tip=False)
            elif role == "Shepherd":  # kij z hakiem
                b.tube([hand + V(0, 0, -0.75), hand + V(0, 0, 0.7), hand + V(0, -0.12, 0.85),
                        hand + V(0, -0.18, 0.75)], [0.025, 0.025, 0.022, 0.02], 5, "People_Wood", tip=False)
            else:  # łuk
                pts = [hand + V(0, 0.05 * math.sin(t * math.pi) - 0.02, (t - 0.5) * 1.3) for t in
                       [k / 6 for k in range(7)]]
                b.tube(pts, [0.02] * 7, 5, "People_Wood", tip=False)
                b.tube([pts[0], pts[-1]], [0.005, 0.005], 3, "People_Cream", tip=False)
        objs.append(part(f"{role}_Arm{side}", b, mats, sh))
    return objs


if __name__ == "__main__":
    common.reset_scene()
    MATS = make_materials(PALETTE)
    all_objs = []
    for i, role in enumerate(ROLES):
        objs = person(role, MATS)
        total = 0
        for o in objs:
            flat_shade(o)
            face_color_variation(o, 0.06, seed=i * 7 + len(o.name))
            total += tri_count(o)
        print(f"{role}: {total} trójkątów")
        all_objs += objs
    bpy.ops.object.select_all(action="DESELECT")
    for o in all_objs:
        o.select_set(True)
    path = common.MODELS_DIR / "people.glb"
    bpy.ops.export_scene.gltf(filepath=str(path), export_format="GLB", use_selection=True, export_yup=True,
                              export_vertex_color="MATERIAL")
    print(f"Wyeksportowano: {path}")
