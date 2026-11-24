"""Zabudowa wiejska low-poly: chata (strzecha), stodoła, studnia, przęsło płotu, stóg siana.

    .venv-tools/bin/python tools/blender/gen_village.py   # -> assets/models/village.glb

Obiekty Village_Cottage, Village_Barn, Village_Well, Village_Fence (4 m wzdłuż X), Village_Hay;
pivot na ziemi w środku, wejście chaty/stodoły od -Y (w Godocie +Z). Gra układa z nich wioski
(scripts/game/villages.gd) i dodaje proste kolizje (pudełka).
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
from gen_animals import blob, make_materials  # noqa: E402
from gen_landmarks import box  # noqa: E402
from meshkit import MeshBuilder, face_color_variation, flat_shade, tri_count  # noqa: E402

PALETTE = {
    "Village_Wall": (0.75, 0.68, 0.52),
    "Village_Beam": (0.18, 0.1, 0.04),
    "Village_Thatch": (0.6, 0.42, 0.14),
    "Village_Stone": (0.25, 0.24, 0.22),
    "Village_Wood": (0.3, 0.17, 0.07),
    "Village_RedWood": (0.42, 0.08, 0.05),
    "Village_Hay": (0.85, 0.66, 0.2),
    "Village_Window": (0.05, 0.07, 0.12),
    "Village_Canvas": (0.85, 0.8, 0.65),
    "Village_Horse": (0.3, 0.16, 0.07),
    "Village_Mane": (0.06, 0.04, 0.03),
}
NAMES = list(PALETTE)


def V(x, y, z) -> Vector:
    return Vector((x, y, z))


def gable_roof(b: MeshBuilder, w: float, d: float, z0: float, h: float, over: float, mat: str) -> None:
    """Dach dwuspadowy (kalenica wzdłuż Y) z okapem `over`."""
    x, y = w / 2 + over, d / 2 + over
    l0, l1 = V(-x, -y, z0), V(-x, y, z0)
    r0, r1 = V(x, -y, z0), V(x, y, z0)
    t0, t1 = V(0, -y, z0 + h), V(0, y, z0 + h)
    for quad in ([l0, t0, t1, l1], [r1, t1, t0, r0]):
        b.add_face([b.add_vert(p) for p in quad], mat)
    # spód dachu (od środka widać strzechę)
    for quad in ([l1, t1, t0, l0], [r0, t0, t1, r1]):
        b.add_face([b.add_vert(p - V(0, 0, 0.15)) for p in quad], mat)
    # szczyty (trójkąty ścian)
    for yy in (-d / 2, d / 2):
        b.add_face([b.add_vert(V(-w / 2, yy, z0)), b.add_vert(V(w / 2, yy, z0)), b.add_vert(V(0, yy, z0 + h - 0.3))],
                   "Village_Wall")
        b.add_face([b.add_vert(V(w / 2, yy, z0)), b.add_vert(V(-w / 2, yy, z0)), b.add_vert(V(0, yy, z0 + h - 0.3))],
                   "Village_Wall")


def cottage(mats) -> bpy.types.Object:
    b = MeshBuilder(NAMES)
    w, d, h = 5.0, 7.0, 2.8
    box(b, V(0, 0, -0.4), (w + 0.4, d + 0.4, 0.6), "Village_Stone")  # podmurówka
    box(b, V(0, 0, 0), (w, d, h), "Village_Wall")
    for x in (-w / 2, w / 2):  # belki szkieletu
        for y in (-d / 2, 0, d / 2):
            box(b, V(x, y, 0), (0.25, 0.25, h), "Village_Beam")
    box(b, V(0, -d / 2 - 0.05, 0), (1.1, 0.12, 1.9), "Village_Wood")  # drzwi
    for x in (-1.6, 1.6):
        box(b, V(x, -d / 2 - 0.05, 1.2), (0.8, 0.1, 0.7), "Village_Window")  # okna (nocą świecą)
    for y in (-1.6, 1.6):
        box(b, V(w / 2 + 0.05, y, 1.2), (0.1, 0.8, 0.7), "Village_Window")  # okna boczne
    gable_roof(b, w, d, h, 2.6, 0.6, "Village_Thatch")
    box(b, V(1.2, 1.5, h), (0.7, 0.7, 2.6), "Village_Stone")  # komin
    return b.to_object("Village_Cottage", mats)


def barn(mats) -> bpy.types.Object:
    b = MeshBuilder(NAMES)
    w, d, h = 8.0, 11.0, 4.0
    box(b, V(0, 0, -0.3), (w, d, h + 0.3), "Village_RedWood")
    for x in (-w / 2, w / 2):
        for y in (-d / 2, d / 2):
            box(b, V(x, y, -0.3), (0.35, 0.35, h + 0.3), "Village_Beam")
    box(b, V(0, -d / 2 - 0.06, 0), (3.4, 0.14, 3.2), "Village_Wood")  # wrota
    for s in (-1, 1):  # krzyż na wrotach
        b.loft([[V(-1.6 * s, -d / 2 - 0.14, 0.1), V(-1.45 * s, -d / 2 - 0.14, 0.1)],
                [V(1.45 * s, -d / 2 - 0.14, 3.1), V(1.6 * s, -d / 2 - 0.14, 3.1)]], "Village_Beam",
               cap_start=False, cap_end=False)
    gable_roof(b, w, d, h, 3.4, 0.5, "Village_Wood")
    return b.to_object("Village_Barn", mats)


def well(mats) -> bpy.types.Object:
    b = MeshBuilder(NAMES)
    n = 10
    ring_out = [[V(math.cos(a) * 1.0, math.sin(a) * 1.0, z) for a in [k / n * math.tau for k in range(n)]]
                for z in (-0.3, 0.9)]
    ring_in = [[V(math.cos(a) * 0.75, math.sin(a) * 0.75, z) for a in [k / n * math.tau for k in range(n)]]
               for z in (0.9, 0.1)]
    b.loft(ring_out + ring_in, "Village_Stone", cap_start=False, cap_end=True)
    for x in (-0.9, 0.9):
        box(b, V(x, 0, 0.9), (0.15, 0.15, 1.6), "Village_Wood")
    gable_roof(b, 2.0, 1.2, 2.4, 0.7, 0.2, "Village_Thatch")
    b.tube([V(-0.9, 0, 1.9), V(0.9, 0, 1.9)], [0.08, 0.08], 6, "Village_Wood", tip=False)
    return b.to_object("Village_Well", mats)


def fence(mats) -> bpy.types.Object:
    b = MeshBuilder(NAMES)
    for x in (-2.0, 0.0, 2.0):
        box(b, V(x, 0, -0.3), (0.14, 0.14, 1.4), "Village_Wood")
    for z in (0.45, 0.85):
        box(b, V(0, 0, z), (4.1, 0.07, 0.12), "Village_Wood")
    return b.to_object("Village_Fence", mats)


def hay(mats) -> bpy.types.Object:
    b = MeshBuilder(NAMES)
    blob(b, (0, 0, 0.9), (1.4, 1.4, 1.5), "Village_Hay", seg=9, rings=5, jitter=0.06, rnd=random.Random(5))
    return b.to_object("Village_Hay", mats)


def wagon(mats) -> bpy.types.Object:
    """Wóz kupiecki z plandeką i skrzyniami (przód = -Y, dyszel do konia)."""
    b = MeshBuilder(NAMES)
    box(b, V(0, 0, 0.75), (1.8, 3.4, 0.6), "Village_Wood")
    for x in (-1.0, 1.0):  # koła
        for y in (-1.1, 1.1):
            b.loft([[V(x, y + math.cos(a) * 0.55, 0.55 + math.sin(a) * 0.55) for a in
                     [k / 10 * math.tau for k in range(10)]],
                    [V(x + 0.12 * (1 if x > 0 else -1), y + math.cos(a) * 0.55, 0.55 + math.sin(a) * 0.55) for a in
                     [k / 10 * math.tau for k in range(10)]]], "Village_Beam", cap_start=True, cap_end=True)
    for k in range(6):  # plandeka (łuk)
        a0, a1 = k / 6 * math.pi, (k + 1) / 6 * math.pi
        p = [V(math.cos(a0) * 0.95, -1.2, 1.35 + math.sin(a0) * 1.0), V(math.cos(a1) * 0.95, -1.2, 1.35 + math.sin(a1) * 1.0),
             V(math.cos(a1) * 0.95, 1.4, 1.35 + math.sin(a1) * 1.0), V(math.cos(a0) * 0.95, 1.4, 1.35 + math.sin(a0) * 1.0)]
        b.add_face([b.add_vert(q) for q in p], "Village_Canvas")
        b.add_face([b.add_vert(q) for q in reversed(p)], "Village_Canvas")
    for k in range(3):  # skrzynie z tyłu
        box(b, V(-0.5 + k * 0.5, 1.5, 1.05), (0.45, 0.45, 0.45), "Village_RedWood" if k % 2 else "Village_Wood")
    b.tube([V(0, -1.7, 0.8), V(0, -3.2, 0.9)], [0.06, 0.05], 5, "Village_Beam", tip=False)  # dyszel
    return b.to_object("Village_Wagon", mats)


def horse(mats) -> bpy.types.Object:
    """Koń pociągowy (przód = -Y), stoi przed wozem."""
    b = MeshBuilder(NAMES)
    blob(b, (0, 0, 1.35), (0.42, 1.0, 0.45), "Village_Horse", seg=8, rings=5)
    b.tube([V(0, -0.8, 1.55), V(0, -1.15, 2.0)], [0.26, 0.2], 6, "Village_Horse", tip=False)  # szyja
    blob(b, (0, -1.4, 2.05), (0.17, 0.4, 0.2), "Village_Horse", seg=6, rings=4)  # głowa
    b.tube([V(0, -0.85, 1.85), V(0, -1.15, 2.25)], [0.07, 0.05], 4, "Village_Mane", tip=False)
    for x in (-0.25, 0.25):
        for y in (-0.65, 0.65):
            b.tube([V(x, y, 1.1), V(x, y, 0.0)], [0.09, 0.07], 5, "Village_Horse", tip=False)
    b.tube([V(0, 0.95, 1.5), V(0, 1.3, 0.9)], [0.08, 0.03], 4, "Village_Mane", tip=False)  # ogon
    return b.to_object("Village_Horse", mats)


if __name__ == "__main__":
    common.reset_scene()
    MATS = make_materials(PALETTE)
    objs = [cottage(MATS), barn(MATS), well(MATS), fence(MATS), hay(MATS), wagon(MATS), horse(MATS)]
    for i, o in enumerate(objs):
        flat_shade(o)
        face_color_variation(o, 0.08, seed=i + 3)
        o.location.x = i * 14
        print(f"{o.name}: {tri_count(o)} trójkątów")
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    path = common.MODELS_DIR / "village.glb"
    bpy.ops.export_scene.gltf(filepath=str(path), export_format="GLB", use_selection=True, export_yup=True,
                              export_vertex_color="MATERIAL")
    print(f"Wyeksportowano: {path}")
