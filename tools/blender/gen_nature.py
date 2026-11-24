"""Przyroda low-poly w baśniowych pastelach: drzewa, kamienie, krzewy, żywopłot, kamienny murek.

    .venv-tools/bin/python tools/blender/gen_nature.py   # -> assets/models/nature.glb

Obiekty (pivot na ziemi, Z w górę): Tree_Pine, Tree_PineTall, Tree_Oak, Tree_Birch, Tree_Autumn,
Tree_Blossom, Rock_A, Rock_B, Rock_Flat, Rock_Mossy, Bush_Round, Bush_Berry, Hedge (4 m wzdłuż X),
StoneWall (4 m wzdłuż X). Gra rozstawia je MultiMeshem (scripts/game/terrain_decor.gd) — kolor
instancji lekko zmienia odcień, więc las nie jest jednolity.
"""

from __future__ import annotations

import math
import pathlib
import random
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))

import bpy  # noqa: E402
from mathutils import Vector, noise  # noqa: E402

import common  # noqa: E402
from gen_animals import blob, make_materials  # noqa: E402
from gen_landmarks import box  # noqa: E402
from meshkit import MeshBuilder, face_color_variation, flat_shade, tri_count  # noqa: E402

# baśniowy pastel (kolory liniowe)
PALETTE = {
    "Nature_Bark": (0.16, 0.08, 0.035),
    "Nature_BirchBark": (0.85, 0.83, 0.78),
    "Nature_BirchMark": (0.04, 0.04, 0.04),
    "Nature_Pine": (0.05, 0.22, 0.12),
    "Nature_PineLight": (0.09, 0.32, 0.14),
    "Nature_Oak": (0.12, 0.42, 0.08),
    "Nature_Birch": (0.32, 0.6, 0.12),
    "Nature_Autumn": (0.85, 0.32, 0.04),
    "Nature_AutumnGold": (0.9, 0.58, 0.06),
    "Nature_Blossom": (0.95, 0.5, 0.62),
    "Nature_Rock": (0.2, 0.19, 0.19),
    "Nature_RockWarm": (0.27, 0.21, 0.16),
    "Nature_Moss": (0.16, 0.42, 0.08),
    "Nature_Bush": (0.1, 0.38, 0.1),
    "Nature_Berry": (0.75, 0.05, 0.12),
    "Nature_Cloud": (0.92, 0.94, 0.98),
}
NAMES = list(PALETTE)


def V(x, y, z) -> Vector:
    return Vector((x, y, z))


def trunk(b: MeshBuilder, h: float, r: float, mat: str, bend: float = 0.3, seed: int = 0) -> list[Vector]:
    rnd = random.Random(seed)
    pts = [V(0, 0, -0.3), V(rnd.uniform(-bend, bend), rnd.uniform(-bend, bend), h * 0.5),
           V(rnd.uniform(-bend, bend), rnd.uniform(-bend, bend), h)]
    b.tube(pts, [r, r * 0.75, r * 0.5], 6, mat, tip=False)
    return pts


def trunk_at(pts: list[Vector], radii: list[float], z: float) -> tuple[Vector, float]:
    """Punkt na osi pnia (łamana przez `pts`) na wysokości `z` i promień pnia w tym miejscu."""
    for i in range(len(pts) - 1):
        a, b = pts[i], pts[i + 1]
        if a.z <= z <= b.z:
            t = (z - a.z) / max(b.z - a.z, 1e-4)
            return a.lerp(b, t), radii[i] + (radii[i + 1] - radii[i]) * t
    return pts[-1], radii[-1]


def pine(mats, tall: bool) -> bpy.types.Object:
    b = MeshBuilder(NAMES)
    h = 11.0 if tall else 7.5
    trunk(b, h * 0.35, 0.35 if tall else 0.3, "Nature_Bark", bend=0.05)
    tiers = 5 if tall else 4
    for k in range(tiers):
        z0 = h * 0.2 + k * (h * 0.75 / tiers)
        r = (2.8 if tall else 2.6) * (1.0 - k / (tiers + 0.6))
        mat = "Nature_Pine" if k % 2 == 0 else "Nature_PineLight"
        ring = [V(math.cos(a) * r, math.sin(a) * r, z0 - 0.2 * math.sin(a * 3)) for a in
                [i / 8 * math.tau + k * 0.4 for i in range(8)]]
        b.loft([ring, V(0, 0, z0 + h * 0.75 / tiers * 1.7)], mat, cap_start=True, cap_end=False)
    return b.to_object("Tree_PineTall" if tall else "Tree_Pine", mats)


def round_tree(mats, name: str, leaf: str, alt: str | None, bark: str, seed: int, h: float = 6.0,
               crowns: int = 4, scale: float = 1.0) -> bpy.types.Object:
    b = MeshBuilder(NAMES)
    rnd = random.Random(seed)
    pts = trunk(b, h * 0.6, 0.32, bark, bend=0.12 if bark == "Nature_BirchBark" else 0.3, seed=seed)
    top = pts[-1]
    if bark == "Nature_BirchBark":  # czarne paski brzozy — na osi wygiętego pnia, szerokość jak pień
        for k in range(6):
            z = 0.6 + k * h * 0.09
            c, r = trunk_at(pts, [0.32, 0.24, 0.16], z)
            # krótki pierścień o kształcie pnia (6 ścianek), odrobinę grubszy niż pień
            b.tube([c - V(0, 0, 0.05), c + V(0, 0, 0.05)], [r * 1.08, r * 1.06], 6, "Nature_BirchMark", tip=False)
    for k in range(crowns):
        a = k / crowns * math.tau + rnd.uniform(-0.3, 0.3)
        d = 0.0 if k == 0 else rnd.uniform(1.0, 1.8) * scale
        c = top + V(math.cos(a) * d, math.sin(a) * d, rnd.uniform(-0.4, 1.2) + (1.2 if k == 0 else 0.0))
        r = rnd.uniform(1.6, 2.3) * scale * (1.25 if k == 0 else 1.0)
        mat = alt if (alt and k % 2 == 1) else leaf
        blob(b, c, (r, r, r * 0.85), mat, seg=7, rings=5, jitter=0.12, rnd=rnd)
    return b.to_object(name, mats)


def rock(mats, name: str, scale, mat: str, seed: int, moss: bool = False) -> bpy.types.Object:
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=1.0, location=(0, 0, 0.3))
    o = bpy.context.view_layer.objects.active
    o.scale = scale
    bpy.ops.object.transform_apply(scale=True)
    off = Vector((seed * 3.1, seed * 1.7, 0.5))
    for v in o.data.vertices:
        v.co += v.co.normalized() * noise.noise(v.co * 0.9 + off) * 0.35 * max(scale)
        if v.co.z < 0.0:
            v.co.z *= 0.4  # spłaszczone dno
    o.name = name
    o.data.name = name
    common.assign(o, mats[mat])
    if moss:  # mech na wierzchu: osobny materiał dla górnych ścianek
        o.data.materials.append(mats["Nature_Moss"])
        for p in o.data.polygons:
            if p.normal.z > 0.75:
                p.material_index = 1
    return o


def bush(mats, name: str, berries: bool, seed: int) -> bpy.types.Object:
    b = MeshBuilder(NAMES)
    rnd = random.Random(seed)
    for k in range(4):
        a = k / 4 * math.tau
        blob(b, (math.cos(a) * 0.5, math.sin(a) * 0.5, 0.55 + rnd.uniform(0, 0.3)), (0.75, 0.75, 0.65),
             "Nature_Bush", seg=6, rings=4, jitter=0.12, rnd=rnd)
    if berries:
        for k in range(14):
            a = rnd.uniform(0, math.tau)
            z = rnd.uniform(0.4, 1.2)
            r = 1.15 - abs(z - 0.75) * 0.5
            blob(b, (math.cos(a) * r, math.sin(a) * r, z), (0.09, 0.09, 0.09), "Nature_Berry", seg=4, rings=3)
    return b.to_object(name, mats)


def hedge(mats) -> bpy.types.Object:
    b = MeshBuilder(NAMES)
    rnd = random.Random(21)
    for k in range(5):
        x = -1.8 + k * 0.9
        blob(b, (x, 0, 0.75), (0.75, 0.6, 0.85), "Nature_Bush", seg=6, rings=4, jitter=0.1, rnd=rnd)
    return b.to_object("Hedge", mats)


def stone_wall(mats) -> bpy.types.Object:
    b = MeshBuilder(NAMES)
    rnd = random.Random(22)
    for row in range(3):
        x = -2.0 + (0.3 if row % 2 else 0.0)
        while x < 1.9:
            w = rnd.uniform(0.5, 0.8)
            box(b, V(x + w / 2, rnd.uniform(-0.03, 0.03), row * 0.3), (w * 0.95, 0.5 - row * 0.06, 0.3),
                "Nature_Rock" if rnd.random() < 0.7 else "Nature_RockWarm", rot=rnd.uniform(-0.05, 0.05))
            x += w
    for k in range(4):  # mech na koronie
        box(b, V(-1.5 + k, 0, 0.88), (0.6, 0.38, 0.08), "Nature_Moss")
    return b.to_object("StoneWall", mats)


def cloud(mats, name: str, seed: int) -> bpy.types.Object:
    """Chmura low-poly: kilka spłaszczonych kul (ok. 12 × 7 m przed skalowaniem w grze)."""
    b = MeshBuilder(NAMES)
    rnd = random.Random(seed)
    for k in range(rnd.randint(5, 7)):
        c = (rnd.uniform(-5, 5), rnd.uniform(-2.5, 2.5), rnd.uniform(0, 1.2))
        r = rnd.uniform(2.0, 3.4)
        blob(b, c, (r, r * 0.9, r * 0.6), "Nature_Cloud", seg=7, rings=4, jitter=0.1, rnd=rnd)
    return b.to_object(name, mats)


if __name__ == "__main__":
    common.reset_scene()
    MATS = make_materials(PALETTE)
    objs = [
        pine(MATS, False), pine(MATS, True),
        round_tree(MATS, "Tree_Oak", "Nature_Oak", None, "Nature_Bark", 1, h=6.5, crowns=5, scale=1.2),
        round_tree(MATS, "Tree_Birch", "Nature_Birch", None, "Nature_BirchBark", 2, h=7.5, crowns=3, scale=0.8),
        round_tree(MATS, "Tree_Autumn", "Nature_Autumn", "Nature_AutumnGold", "Nature_Bark", 3, h=6.0, crowns=5),
        round_tree(MATS, "Tree_Blossom", "Nature_Blossom", None, "Nature_Bark", 4, h=5.0, crowns=4, scale=0.9),
        rock(MATS, "Rock_A", (1.0, 0.9, 0.75), "Nature_Rock", 1),
        rock(MATS, "Rock_B", (1.3, 0.8, 0.55), "Nature_RockWarm", 2),
        rock(MATS, "Rock_Flat", (1.4, 1.2, 0.35), "Nature_Rock", 3),
        rock(MATS, "Rock_Mossy", (1.1, 1.0, 0.8), "Nature_Rock", 4, moss=True),
        bush(MATS, "Bush_Round", False, 5), bush(MATS, "Bush_Berry", True, 6),
        hedge(MATS), stone_wall(MATS),
        cloud(MATS, "Cloud_A", 31), cloud(MATS, "Cloud_B", 32),
    ]
    for i, o in enumerate(objs):
        flat_shade(o)
        face_color_variation(o, 0.08, seed=i + 7)
        o.location.x += i * 8
        print(f"{o.name}: {tri_count(o)} trójkątów")
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    path = common.MODELS_DIR / "nature.glb"
    bpy.ops.export_scene.gltf(filepath=str(path), export_format="GLB", use_selection=True, export_yup=True,
                              export_vertex_color="MATERIAL")
    print(f"Wyeksportowano: {path}")
