"""Skarby low-poly: moneta, kielich, korona, skrzynia ze złotem, klejnot.

    .venv-tools/bin/python tools/blender/gen_treasure.py   # -> assets/models/treasure.glb

Każdy przedmiot to osobny obiekt (Treasure_Coin, Treasure_Goblet, Treasure_Crown, Treasure_Chest,
Treasure_Gem) z pivotem na ziemi. Gra używa ich do znalezisk w świecie i do proceduralnego
stosu skarbu w legowisku (MultiMesh monet). Monety są przesadnie duże (r = 0.15 m) — stylizacja,
żeby stos był czytelny także dla dużego smoka.
"""

from __future__ import annotations

import math
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))

import bpy  # noqa: E402
from mathutils import Vector  # noqa: E402

import common  # noqa: E402
from gen_animals import make_materials  # noqa: E402
from meshkit import MeshBuilder, face_color_variation, flat_shade, tri_count  # noqa: E402

PALETTE = {
    "Treasure_Gold": (1.0, 0.62, 0.12),
    "Treasure_Wood": (0.2, 0.1, 0.04),
    "Treasure_Iron": (0.08, 0.08, 0.09),
    "Treasure_Ruby": (0.75, 0.03, 0.06),
    "Treasure_Emerald": (0.05, 0.6, 0.2),
}


def V(x, y, z) -> Vector:
    return Vector((x, y, z))


def ring(cx, cy, z, r, n, rot=0.0):
    return [V(cx + math.cos(rot + i / n * math.tau) * r, cy + math.sin(rot + i / n * math.tau) * r, z)
            for i in range(n)]


def lathe(b: MeshBuilder, profile, mat, n: int = 8) -> None:
    """Bryła obrotowa z profilu [(promień, z), ...] (od dołu do góry)."""
    rings = [ring(0, 0, z, max(r, 0.001), n) for r, z in profile]
    b.loft(rings, mat, cap_start=True, cap_end=True)


def box(b: MeshBuilder, c, size, mat) -> None:
    x, y, z = (s / 2 for s in size)
    cx, cy, cz = c
    bottom = [V(cx - x, cy - y, cz - z), V(cx + x, cy - y, cz - z), V(cx + x, cy + y, cz - z), V(cx - x, cy + y, cz - z)]
    top = [p + V(0, 0, 2 * z) for p in bottom]
    b.loft([bottom, top], mat, cap_start=True, cap_end=True)


def coin() -> bpy.types.Object:
    b = MeshBuilder(list(PALETTE))
    lathe(b, [(0.15, 0.0), (0.15, 0.03), (0.12, 0.035)], "Treasure_Gold", n=8)
    return b.to_object("Treasure_Coin", MATS)


def goblet() -> bpy.types.Object:
    b = MeshBuilder(list(PALETTE))
    lathe(b, [(0.16, 0.0), (0.14, 0.03), (0.04, 0.08), (0.035, 0.25), (0.08, 0.3), (0.16, 0.42),
              (0.17, 0.5), (0.15, 0.5)], "Treasure_Gold", n=8)
    for k in range(4):  # klejnoty na czaszy
        a = k / 4 * math.tau
        b.loft([ring(math.cos(a) * 0.16, math.sin(a) * 0.16, 0.4, 0.035, 4),
                ring(math.cos(a) * 0.18, math.sin(a) * 0.18, 0.4, 0.001, 4)], "Treasure_Ruby",
               cap_start=True, cap_end=False)
    return b.to_object("Treasure_Goblet", MATS)


def crown() -> bpy.types.Object:
    b = MeshBuilder(list(PALETTE))
    n = 10
    base = ring(0, 0, 0.0, 0.22, n)
    mid = ring(0, 0, 0.1, 0.23, n)
    tips = []
    for i, p in enumerate(ring(0, 0, 0.0, 0.24, n)):
        tips.append(V(p.x, p.y, 0.26 if i % 2 == 0 else 0.14))
    b.loft([base, mid, tips], "Treasure_Gold", cap_start=False, cap_end=False)
    inner = [p * 0.92 for p in tips]
    b.loft([tips, inner, [V(p.x * 0.92, p.y * 0.92, 0.0) for p in base]], "Treasure_Gold",
           cap_start=False, cap_end=False)
    for i in range(0, n, 2):  # klejnoty w czubkach
        a = i / n * math.tau
        c = V(math.cos(a) * 0.245, math.sin(a) * 0.245, 0.07)
        b.loft([ring(c.x, c.y, c.z - 0.03, 0.03, 4), ring(c.x, c.y, c.z + 0.03, 0.03, 4)],
               "Treasure_Emerald" if i % 4 == 0 else "Treasure_Ruby")
    return b.to_object("Treasure_Crown", MATS)


def chest() -> bpy.types.Object:
    b = MeshBuilder(list(PALETTE))
    w, d, h = 1.2, 0.8, 0.55
    box(b, (0, 0, h / 2), (w, d, h), "Treasure_Wood")
    # wieko uchylone (łuk) + złoto wysypujące się ze środka
    lid = []
    for k in range(6):
        a = k / 5 * math.pi
        lid.append([V(-w / 2, -math.cos(a) * d / 2 + 0.0, h + math.sin(a) * 0.22),
                    V(w / 2, -math.cos(a) * d / 2 + 0.0, h + math.sin(a) * 0.22)])
    for k in range(5):
        a0, a1 = lid[k], lid[k + 1]
        b.add_face([b.add_vert(a0[0]), b.add_vert(a0[1]), b.add_vert(a1[1]), b.add_vert(a1[0])], "Treasure_Wood")
    for x in (-0.45, 0.45):  # okucia
        box(b, (x, 0, h / 2), (0.08, d + 0.04, h + 0.04), "Treasure_Iron")
    for k in range(7):  # górka monet nad krawędzią
        a = k / 7 * math.tau
        box(b, (math.cos(a) * 0.35, math.sin(a) * 0.2, h + 0.06), (0.22, 0.22, 0.05), "Treasure_Gold")
    lathe_center = [ring(0, 0, h, 0.4, 7), ring(0, 0, h + 0.18, 0.15, 7)]
    b.loft(lathe_center, "Treasure_Gold", cap_start=False, cap_end=True)
    return b.to_object("Treasure_Chest", MATS)


def gem() -> bpy.types.Object:
    b = MeshBuilder(list(PALETTE))
    b.loft([ring(0, 0, 0.0, 0.001, 6), ring(0, 0, 0.12, 0.12, 6), ring(0, 0, 0.18, 0.08, 6)], "Treasure_Ruby",
           cap_start=False, cap_end=True)
    return b.to_object("Treasure_Gem", MATS)


if __name__ == "__main__":
    common.reset_scene()
    MATS = make_materials(PALETTE)
    objs = [coin(), goblet(), crown(), chest(), gem()]
    for i, o in enumerate(objs):
        flat_shade(o)
        face_color_variation(o, 0.08, seed=i + 1)
        o.location.x = i * 1.6  # rozstaw tylko dla podglądu (gra bierze same siatki)
        print(f"{o.name}: {tri_count(o)} trójkątów")
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    path = common.MODELS_DIR / "treasure.glb"
    bpy.ops.export_scene.gltf(filepath=str(path), export_format="GLB", use_selection=True, export_yup=True,
                              export_vertex_color="MATERIAL")
    print(f"Wyeksportowano: {path}")
