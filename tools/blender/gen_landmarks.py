"""Ciekawe miejsca (punkty orientacyjne) w baśniowym świecie, low-poly:
kamienny krąg, ruiny wieży, pradawne drzewo, szkielet olbrzymiego smoka, skalny łuk.

    .venv-tools/bin/python tools/blender/gen_landmarks.py   # -> assets/models/landmarks.glb

Każde miejsce to osobny obiekt Landmark_<Nazwa> z pivotem na ziemi (środek), Z w górę.
Gra rozstawia je po świecie (scripts/game/landmarks.gd), osadza w terenie i robi kolizję.
Rozmiary są „smocze” — miejsca mają być widoczne z lotu i ciekawe także dla dużego smoka.
"""

from __future__ import annotations

import math
import pathlib
import random
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))

import bpy  # noqa: E402
import bmesh  # noqa: E402
from mathutils import Vector, noise  # noqa: E402

import common  # noqa: E402
from gen_animals import blob, make_materials  # noqa: E402
from meshkit import MeshBuilder, face_color_variation, flat_shade, tri_count  # noqa: E402

PALETTE = {
    "Landmark_Stone": (0.2, 0.19, 0.18),
    "Landmark_Moss": (0.08, 0.2, 0.05),
    "Landmark_Brick": (0.3, 0.26, 0.2),
    "Landmark_Bark": (0.12, 0.07, 0.04),
    "Landmark_Leaves": (0.75, 0.35, 0.05),
    "Landmark_Bone": (0.75, 0.7, 0.58),
    "Landmark_Rock": (0.14, 0.12, 0.1),
}
NAMES = list(PALETTE)


def V(x, y, z) -> Vector:
    return Vector((x, y, z))


def box(b: MeshBuilder, c, size, mat, rot: float = 0.0, tilt=(0.0, 0.0), taper: float = 1.0) -> None:
    """Prostopadłościan (opcjonalnie zwężony ku górze, obrócony i przechylony)."""
    sx, sy, sz = size
    ca, sa = math.cos(rot), math.sin(rot)

    def xf(x, y, z):
        # przechył: przesunięcie góry
        x += tilt[0] * z
        y += tilt[1] * z
        return Vector(c) + V(x * ca - y * sa, x * sa + y * ca, z)

    bottom = [xf(-sx / 2, -sy / 2, 0), xf(sx / 2, -sy / 2, 0), xf(sx / 2, sy / 2, 0), xf(-sx / 2, sy / 2, 0)]
    t = taper
    top = [xf(-sx / 2 * t, -sy / 2 * t, sz), xf(sx / 2 * t, -sy / 2 * t, sz), xf(sx / 2 * t, sy / 2 * t, sz),
           xf(-sx / 2 * t, sy / 2 * t, sz)]
    b.loft([bottom, top], mat, cap_start=True, cap_end=True)


def stone_circle(mats) -> bpy.types.Object:
    b = MeshBuilder(NAMES)
    rnd = random.Random(1)
    n = 9
    for i in range(n):
        a = i / n * math.tau
        h = rnd.uniform(4.0, 5.5)
        c = V(math.cos(a) * 10, math.sin(a) * 10, -0.5)
        box(b, c, (1.8, 1.0, h), "Landmark_Stone", rot=a + math.pi / 2,
            tilt=(rnd.uniform(-0.06, 0.06), rnd.uniform(-0.06, 0.06)), taper=0.8)
        box(b, c + V(0, 0, h - 0.3), (1.5, 0.85, 0.4), "Landmark_Moss", rot=a + math.pi / 2, taper=0.7)
        if i % 3 == 0:  # nadproże na parze kamieni
            a2 = (i + 1) / n * math.tau
            mid = (c + V(math.cos(a2) * 10, math.sin(a2) * 10, -0.5)) / 2
            box(b, mid + V(0, 0, 4.6), (7.5, 1.1, 0.9), "Landmark_Stone", rot=(a + a2) / 2 + math.pi / 2)
    box(b, V(0, 0, -0.2), (3.2, 2.0, 1.2), "Landmark_Stone", rot=0.3)  # ołtarz
    return b.to_object("Landmark_StoneCircle", mats)


def ruined_tower(mats) -> bpy.types.Object:
    b = MeshBuilder(NAMES)
    rnd = random.Random(2)
    n = 18
    r = 6.0
    for i in range(n):
        if i in (0, 1):  # wejście (od -Y po obrocie)
            continue
        a = (i + 0.5) / n * math.tau - math.pi / 2
        # wyższa strona wieży i postrzępiona korona
        h = 6.0 + 14.0 * (0.5 + 0.5 * math.cos(a - 0.8)) + rnd.uniform(-2.0, 2.0)
        c = V(math.cos(a) * r, math.sin(a) * r, -0.5)
        box(b, c, (2.2, 1.4, h), "Landmark_Brick", rot=a + math.pi / 2)
        if rnd.random() < 0.4:
            box(b, c + V(0, 0, h), (1.2, 1.2, rnd.uniform(0.5, 1.4)), "Landmark_Brick", rot=a)
    for i in range(14):  # gruz dookoła
        a = rnd.uniform(0, math.tau)
        d = rnd.uniform(7.5, 14.0)
        s = rnd.uniform(0.6, 1.6)
        box(b, V(math.cos(a) * d, math.sin(a) * d, -0.3), (s * 1.5, s, s), "Landmark_Brick", rot=rnd.uniform(0, 3),
            tilt=(rnd.uniform(-0.3, 0.3), 0))
    return b.to_object("Landmark_Tower", mats)


def ancient_tree(mats) -> bpy.types.Object:
    b = MeshBuilder(NAMES)
    rnd = random.Random(3)
    trunk = [V(0, 0, -1), V(0.5, 0.3, 8), V(-0.6, 0.2, 16), V(0.4, -0.5, 24)]
    b.tube(trunk, [3.4, 2.4, 1.6, 1.1], 9, "Landmark_Bark", tip=False)
    for k in range(6):  # korzenie
        a = k / 6 * math.tau + 0.3
        d = V(math.cos(a), math.sin(a), 0)
        b.tube([V(0, 0, 2.5) + d * 1.5, d * 5.0 + V(0, 0, 0.6), d * 8.0 + V(0, 0, -0.6)], [1.3, 0.8, 0.2], 6,
               "Landmark_Bark")
    crowns = [(V(0.4, -0.5, 26), 9), (V(6, 2, 22), 6.5), (V(-6, -3, 21), 6), (V(2, 6, 19), 5.5), (V(-3, 5, 24), 6)]
    for c, r in crowns:
        if c.z < 25:  # gałąź do bocznej korony
            b.tube([V(0, 0, c.z - 6), (V(0, 0, c.z - 4) + c) / 2, c], [1.0, 0.7, 0.4], 6, "Landmark_Bark", tip=False)
        blob(b, c, (r, r, r * 0.75), "Landmark_Leaves", seg=9, rings=6, jitter=0.18, rnd=rnd)
    return b.to_object("Landmark_Tree", mats)


def dragon_bones(mats) -> bpy.types.Object:
    """Szkielet pradawnego smoka: kręgosłup łukiem, żebra, czaszka z rogami."""
    b = MeshBuilder(NAMES)
    spine = [V(0, -18 + i * 2.2, 2.0 + 2.2 * math.sin(i / 16 * math.pi)) + V(math.sin(i * 0.35) * 1.5, 0, 0)
             for i in range(17)]
    for i, p in enumerate(spine):
        s = 1.0 - abs(i - 6) / 20.0
        blob(b, p, (0.9 * s, 0.7 * s, 0.9 * s), "Landmark_Bone", seg=6, rings=4)
        if 3 <= i <= 10:  # żebra: łuki do ziemi po obu stronach
            for side in (-1, 1):
                rib = [p, p + V(side * 3.5 * s, 0.4, 0.8), p + V(side * 6.0 * s, 0.9, -1.2),
                       p + V(side * 5.5 * s, 1.2, -p.z + 0.3)]
                b.tube(rib, [0.35, 0.3, 0.22, 0.12], 5, "Landmark_Bone")
    # ogon: zwężające się kręgi dalej wzdłuż
    tail = [spine[-1] + V(math.sin(k * 0.5) * 3, 2.0 * (k + 1), -0.15 * (k + 1)) for k in range(8)]
    for k, p in enumerate(tail):
        r = 0.6 * (1 - k / 9)
        blob(b, V(p.x, p.y, max(p.z, r)), (r, r, r), "Landmark_Bone", seg=5, rings=3)
    # czaszka (przód = -Y)
    head = spine[0] + V(0, -3.5, -1.0)
    blob(b, head, (2.0, 3.2, 1.6), "Landmark_Bone", seg=8, rings=5, jitter=0.08, rnd=random.Random(4))
    blob(b, head + V(0, -2.4, -0.7), (1.3, 2.2, 0.8), "Landmark_Bone", seg=7, rings=4)  # pysk
    for side in (-1, 1):
        b.tube([head + V(side * 1.2, 1.2, 1.0), head + V(side * 2.4, 3.6, 2.4), head + V(side * 2.0, 6.0, 2.0)],
               [0.55, 0.35, 0.0], 6, "Landmark_Bone")
        blob(b, head + V(side * 1.1, -0.8, 0.5), (0.5, 0.5, 0.45), "Landmark_Rock", seg=5, rings=3)  # oczodół
    return b.to_object("Landmark_Bones", mats)


def rock_arch(mats) -> bpy.types.Object:
    bpy.ops.mesh.primitive_torus_add(major_radius=15.0, minor_radius=4.5, major_segments=22, minor_segments=8,
                                     location=(0, 0, 0), rotation=(math.radians(90), 0, 0))
    arch = bpy.context.view_layer.objects.active
    arch.scale = (1.0, 1.0, 1.35)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    bm = bmesh.new()
    bm.from_mesh(arch.data)
    bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], plane_co=(0, 0, -2.0),
                           plane_no=(0, 0, 1), clear_inner=True)
    for v in bm.verts:  # skalne nierówności
        n = noise.noise(v.co * 0.25 + Vector((3.1, 1.7, 0.4)))
        v.co += v.co.normalized() * n * 2.2
    bm.to_mesh(arch.data)
    bm.free()
    arch.name = "Landmark_Arch"
    arch.data.name = "Landmark_Arch"
    common.assign(arch, mats["Landmark_Rock"])
    return arch


if __name__ == "__main__":
    common.reset_scene()
    MATS = make_materials(PALETTE)
    objs = [stone_circle(MATS), ruined_tower(MATS), ancient_tree(MATS), dragon_bones(MATS), rock_arch(MATS)]
    for i, o in enumerate(objs):
        flat_shade(o)
        face_color_variation(o, 0.09, seed=i + 1)
        o.location.x = i * 50  # rozstaw tylko dla podglądu
        print(f"{o.name}: {tri_count(o)} trójkątów")
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    path = common.MODELS_DIR / "landmarks.glb"
    bpy.ops.export_scene.gltf(filepath=str(path), export_format="GLB", use_selection=True, export_yup=True,
                              export_vertex_color="MATERIAL")
    print(f"Wyeksportowano: {path}")
