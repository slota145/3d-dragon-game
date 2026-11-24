"""Zamek w baśniowym stylu low-poly: moduły murów, wież, bramy, donżonu oraz balista.

    .venv-tools/bin/python tools/blender/gen_castle.py   # -> assets/models/castle.glb

Obiekty (pivot na ziemi, Z w górę, „na zewnątrz” = −Y, czyli +Z w Godocie):
  Castle_Wall       odcinek muru 10 m wzdłuż X, wys. 9 m, chodnik na szczycie (z = 9)
  Castle_Tower      okrągła wieża z blankami i platformą na balistę (z = 15)
  Castle_TowerRoof  wieża ze stożkowym dachem i chorągwią
  Castle_Gate       budynek bramny 14 m szeroki, przejazd 6 × 7 m
  Castle_Keep       donżon 18 × 18 m z wieżyczkami, drzwi od −Y
  Castle_BallistaBase  podstawa balisty (statyw)
  Castle_BallistaBow   łoże z łukiem — obraca się (pivot w osi, z = 1.3), strzela w −Y
  Castle_Bolt          bełt 2.4 m, grot w −Y
Gra składa z nich zamek (scripts/game/castle.gd) i dodaje kolizje.
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
from gen_animals import make_materials  # noqa: E402
from gen_landmarks import box  # noqa: E402
from meshkit import MeshBuilder, face_color_variation, flat_shade, tri_count  # noqa: E402

PALETTE = {
    "Castle_Stone": (0.42, 0.39, 0.35),
    "Castle_StoneDark": (0.24, 0.22, 0.21),
    "Castle_Roof": (0.06, 0.13, 0.42),
    "Castle_Banner": (0.62, 0.05, 0.05),
    "Castle_Gold": (1.0, 0.68, 0.15),
    "Castle_Wood": (0.3, 0.17, 0.07),
    "Castle_Window": (0.03, 0.04, 0.07),
    "Castle_Iron": (0.1, 0.1, 0.11),
    "Castle_Rope": (0.75, 0.65, 0.45),
}
NAMES = list(PALETTE)


def V(x, y, z) -> Vector:
    return Vector((x, y, z))


def ring(r: float, z: float, n: int, rot: float = 0.0, cx: float = 0.0, cy: float = 0.0) -> list[Vector]:
    return [V(cx + math.cos(rot + i / n * math.tau) * r, cy + math.sin(rot + i / n * math.tau) * r, z)
            for i in range(n)]


def merlons_line(b: MeshBuilder, x0: float, x1: float, y: float, z: float, mat: str, step: float = 2.0) -> None:
    x = x0 + step * 0.25
    while x < x1 - step * 0.2:
        box(b, V(x + step * 0.25, y, z), (step * 0.5, 0.7, 1.3), mat)
        x += step


def merlons_ring(b: MeshBuilder, r: float, z: float, n: int, mat: str, cx: float = 0.0, cy: float = 0.0) -> None:
    for i in range(n):
        a = (i + 0.5) / n * math.tau
        box(b, V(cx + math.cos(a) * r, cy + math.sin(a) * r, z), (math.tau * r / n * 0.5, 0.7, 1.3), mat,
            rot=a + math.pi / 2)


def wall(mats) -> bpy.types.Object:
    b = MeshBuilder(NAMES)
    box(b, V(0, 0, -1.0), (10.0, 3.6, 10.0), "Castle_Stone", taper=0.97)
    box(b, V(0, 0, 8.9), (10.0, 3.3, 0.15), "Castle_StoneDark")  # chodnik
    merlons_line(b, -5.0, 5.0, -1.45, 9.0, "Castle_Stone")  # blanki od zewnątrz
    box(b, V(0, 1.5, 9.0), (10.0, 0.4, 0.7), "Castle_Stone")  # niski parapet od dziedzińca
    for x in (-2.5, 2.5):  # strzelnice (ciemne szczeliny) i przypory
        box(b, V(x, -1.82, 4.5), (0.35, 0.1, 1.6), "Castle_Window")
    box(b, V(0, -1.9, -1.0), (10.0, 0.6, 1.8), "Castle_StoneDark", taper=0.8)  # cokół
    return b.to_object("Castle_Wall", mats)


def tower(mats, roof: bool) -> bpy.types.Object:
    b = MeshBuilder(NAMES)
    n = 12
    b.loft([ring(5.2, -1.5, n), ring(4.6, 1.0, n), ring(4.3, 13.5, n), ring(4.9, 14.2, n), ring(4.9, 15.0, n)],
           "Castle_Stone", cap_start=True, cap_end=False)
    b.loft([ring(4.6, 15.0, n)], "Castle_StoneDark", cap_start=False, cap_end=True)  # platforma
    b.add_face([b.add_vert(p) for p in ring(4.9, 15.0, n)], "Castle_StoneDark")
    box(b, V(0, -4.4, 0.0), (1.6, 0.6, 2.6), "Castle_Wood")  # drzwi
    for k, z in enumerate((5.0, 9.5)):  # okienka
        a = k * 2.1 + 0.6
        box(b, V(math.cos(a) * 4.45, math.sin(a) * 4.45, z), (0.5, 0.5, 1.2), "Castle_Window", rot=a + math.pi / 2)
    if roof:
        b.loft([ring(5.4, 15.2, n), V(0, 0, 24.5)], "Castle_Roof", cap_start=True, cap_end=False)
        b.tube([V(0, 0, 24.3), V(0, 0, 27.5)], [0.08, 0.06], 4, "Castle_Wood", tip=False)
        flag = [V(0, 0, 27.4), V(0, 0, 26.2), V(2.4, 0.25, 26.7)]
        b.add_face([b.add_vert(p) for p in flag], "Castle_Banner")
        b.add_face([b.add_vert(p) for p in reversed(flag)], "Castle_Banner")
    else:
        merlons_ring(b, 4.6, 15.0, 10, "Castle_Stone")
    return b.to_object("Castle_TowerRoof" if roof else "Castle_Tower", mats)


def gate(mats) -> bpy.types.Object:
    b = MeshBuilder(NAMES)
    for x in (-5.0, 5.0):  # filary bramy
        box(b, V(x, 0, -1.0), (4.0, 8.0, 13.0), "Castle_Stone")
        merlons_line(b, x - 2.0, x + 2.0, -3.7, 12.0, "Castle_Stone", step=1.6)
        b.loft([ring(2.6, 12.0, 8, cx=x, cy=-3.0), V(x, -3.0, 17.5)], "Castle_Roof", cap_start=True, cap_end=False)
    box(b, V(0, 0, 7.0), (6.0, 8.0, 5.0), "Castle_Stone")  # nadproże nad przejazdem
    merlons_line(b, -3.0, 3.0, -3.7, 12.0, "Castle_Stone", step=1.6)
    box(b, V(0, -3.6, 6.2), (6.2, 0.6, 0.8), "Castle_StoneDark")  # łuk
    box(b, V(0, -3.0, 5.4), (5.8, 0.25, 1.6), "Castle_Iron")  # podniesiona brona
    for x in (-2.0, 0.0, 2.0):
        box(b, V(x, -3.0, 4.7), (0.18, 0.18, 0.9), "Castle_Iron")
    box(b, V(0, -4.05, 9.3), (1.6, 0.1, 2.6), "Castle_Banner")  # chorągiew herbowa
    box(b, V(0, -4.1, 10.0), (0.6, 0.1, 0.6), "Castle_Gold")
    return b.to_object("Castle_Gate", mats)


def keep(mats) -> bpy.types.Object:
    b = MeshBuilder(NAMES)
    box(b, V(0, 0, -1.5), (18.0, 18.0, 23.5), "Castle_Stone", taper=0.94)
    box(b, V(0, 0, 21.8), (17.4, 17.4, 0.4), "Castle_StoneDark")
    b.loft([[V(-8, -8, 22.2), V(8, -8, 22.2), V(8, 8, 22.2), V(-8, 8, 22.2)], V(0, 0, 31.0)], "Castle_Roof",
           cap_start=True, cap_end=False)
    for sx, sy in ((1, 1), (1, -1), (-1, 1), (-1, -1)):  # narożne wieżyczki
        cx, cy = sx * 8.6, sy * 8.6
        b.loft([ring(2.4, 14.0, 8, cx=cx, cy=cy), ring(2.4, 25.0, 8, cx=cx, cy=cy)], "Castle_Stone",
               cap_start=True, cap_end=False)
        b.loft([ring(2.9, 25.0, 8, cx=cx, cy=cy), V(cx, cy, 31.5)], "Castle_Roof", cap_start=True, cap_end=False)
    box(b, V(0, -8.75, 0.0), (3.6, 0.6, 5.0), "Castle_Wood")  # wrota
    box(b, V(0, -8.9, 4.9), (4.4, 0.6, 0.7), "Castle_StoneDark")
    rnd = random.Random(5)
    for side in range(4):  # okna na czterech ścianach
        a = side * math.pi / 2
        for z in (9.0, 15.0):
            for o in (-4.5, 0.0, 4.5):
                if side == 0 and z == 9.0 and o == 0.0:
                    continue
                c = V(math.cos(a - math.pi / 2) * 8.55 + math.cos(a) * o, math.sin(a - math.pi / 2) * 8.55 + math.sin(a) * o,
                      z + rnd.uniform(-0.2, 0.2))
                box(b, c, (1.0, 0.3, 1.8), "Castle_Window", rot=a)
    for x in (-3.0, 3.0):  # proporce przy wejściu
        box(b, V(x, -8.9, 6.0), (1.5, 0.15, 4.0), "Castle_Banner")
    return b.to_object("Castle_Keep", mats)


def ballista(mats) -> list[bpy.types.Object]:
    b = MeshBuilder(NAMES)
    for k in range(3):  # statyw
        a = k / 3 * math.tau
        b.tube([V(math.cos(a) * 1.0, math.sin(a) * 1.0, 0.0), V(0, 0, 1.2)], [0.1, 0.08], 5, "Castle_Wood", tip=False)
    b.tube([V(0, 0, 0.9), V(0, 0, 1.3)], [0.22, 0.2], 6, "Castle_Iron", tip=False)
    base = b.to_object("Castle_BallistaBase", mats)
    b = MeshBuilder(NAMES)
    box(b, V(0, 0.3, 1.15), (0.45, 3.4, 0.3), "Castle_Wood")  # łoże
    box(b, V(0, -1.2, 1.1), (0.7, 0.4, 0.45), "Castle_Iron")
    for s in (1, -1):  # ramiona łuku
        b.tube([V(0.2 * s, -1.2, 1.3), V(1.0 * s, -0.95, 1.35), V(1.7 * s, -0.5, 1.35)], [0.11, 0.09, 0.06], 5,
               "Castle_Wood", tip=False)
        b.tube([V(1.7 * s, -0.5, 1.35), V(0.0, 1.0, 1.35)], [0.025, 0.025], 3, "Castle_Rope", tip=False, samples=1)
    box(b, V(0, 1.85, 1.0), (0.8, 0.3, 0.5), "Castle_Wood")  # kołowrót
    bow = b.to_object("Castle_BallistaBow", mats)
    for v in bow.data.vertices:  # pivot w osi obrotu
        v.co.z -= 1.3
    bow.location = (0, 0, 1.3)
    b = MeshBuilder(NAMES)
    b.tube([V(0, 1.2, 0), V(0, -1.0, 0)], [0.07, 0.07], 5, "Castle_Wood", tip=False)
    b.tube([V(0, -1.0, 0), V(0, -1.4, 0)], [0.16, 0.0], 4, "Castle_Iron", tip=True)
    for a in (0.0, math.pi / 2):  # lotki
        c, s = math.cos(a) * 0.25, math.sin(a) * 0.25
        face = [V(c, 1.2, s), V(-c, 1.2, -s), V(0, 0.7, 0)]
        b.add_face([b.add_vert(p) for p in face], "Castle_Banner")
        b.add_face([b.add_vert(p) for p in reversed(face)], "Castle_Banner")
    bolt = b.to_object("Castle_Bolt", mats)
    return [base, bow, bolt]


if __name__ == "__main__":
    common.reset_scene()
    MATS = make_materials(PALETTE)
    objs = [wall(MATS), tower(MATS, False), tower(MATS, True), gate(MATS), keep(MATS)] + ballista(MATS)
    for i, o in enumerate(objs):
        flat_shade(o)
        face_color_variation(o, 0.08, seed=i + 40)
        print(f"{o.name}: {tri_count(o)} trójkątów")
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    path = common.MODELS_DIR / "castle.glb"
    bpy.ops.export_scene.gltf(filepath=str(path), export_format="GLB", use_selection=True, export_yup=True,
                              export_vertex_color="MATERIAL")
    print(f"Wyeksportowano: {path}")
