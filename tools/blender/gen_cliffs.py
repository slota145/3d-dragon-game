"""Skały krajobrazu low-poly: kamienne turnie (smukłe słupy piaskowca z warstwami i zielonym szczytem).

    .venv-tools/bin/python tools/blender/gen_cliffs.py   # -> assets/models/cliffs.glb

Obiekty (pivot na ziemi, Z w górę, wysokość w metrach — gra skaluje je lekko):
  Spire_A   turnia ~34 m, podstawa r ~ 7 m, z pochyloną „czapą”
  Spire_B   turnia ~24 m, dwa stopnie (półka w połowie)
  Spire_C   niska, gruba baszta ~14 m
Gra rozstawia je w scripts/game/landforms.gd (z kolizją walcową).
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
from meshkit import MeshBuilder, face_color_variation, flat_shade, tri_count  # noqa: E402

PALETTE = {
    "Cliff_Sand": (0.5, 0.3, 0.17),
    "Cliff_SandLight": (0.62, 0.42, 0.25),
    "Cliff_SandDark": (0.36, 0.21, 0.12),
    "Cliff_Moss": (0.14, 0.38, 0.08),
}
NAMES = list(PALETTE)


def V(x, y, z) -> Vector:
    return Vector((x, y, z))


def ring(r: float, z: float, n: int, rnd: random.Random, jitter: float, cx: float = 0.0, cy: float = 0.0,
         rot: float = 0.0) -> list[Vector]:
    return [V(cx + math.cos(rot + 2 * math.pi * k / n) * r * (1.0 + rnd.uniform(-jitter, jitter)),
              cy + math.sin(rot + 2 * math.pi * k / n) * r * (1.0 + rnd.uniform(-jitter, jitter)), z)
            for k in range(n)]


def spire(name: str, profile: list[tuple[float, float]], seed: int, lean: float = 0.0) -> bpy.types.Object:
    """Słup z pierścieni (z, promień) — warstwy na przemian jaśniejsze i ciemniejsze, mech na szczycie."""
    rnd = random.Random(seed)
    b = MeshBuilder(NAMES)
    n = 9
    rings = []
    mats = []
    for i, (z, r) in enumerate(profile):
        k = z / profile[-1][0]
        rings.append(ring(r, z, n, rnd, 0.14, cx=lean * k * k, rot=i * 0.35))
    for i in range(len(rings) - 1):
        mat = ["Cliff_Sand", "Cliff_SandLight", "Cliff_SandDark"][i % 3]
        b.loft([rings[i], rings[i + 1]], mat, cap_start=(i == 0), cap_end=False)
        mats.append(mat)
    top = rings[-1]
    c = sum(top, Vector()) / len(top)
    cap = [p.lerp(c, 0.25) + V(0, 0, 0.8) for p in top]
    b.loft([top, cap, c + V(0, 0, 1.6)], "Cliff_Moss", cap_start=False, cap_end=False)
    return b.to_object(name, common_mats)


if __name__ == "__main__":
    common.reset_scene()
    common_mats = make_materials(PALETTE)
    objs = [
        spire("Spire_A", [(-2, 7.5), (4, 6.6), (9, 5.4), (15, 5.8), (21, 4.6), (27, 4.9), (32, 4.2), (34, 4.4)], 3,
              lean=2.5),
        spire("Spire_B", [(-2, 8.0), (5, 7.0), (11, 6.4), (12, 4.6), (17, 4.0), (22, 3.6), (24, 3.8)], 7),
        spire("Spire_C", [(-2, 9.0), (4, 8.2), (8, 7.4), (12, 7.0), (14, 7.3)], 11),
    ]
    for i, o in enumerate(objs):
        flat_shade(o)
        face_color_variation(o, 0.08, seed=i + 5)
        o.location.x = i * 25
        print(f"{o.name}: {tri_count(o)} trójkątów")
        o.location.x = 0
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    path = common.MODELS_DIR / "cliffs.glb"
    bpy.ops.export_scene.gltf(filepath=str(path), export_format="GLB", use_selection=True, export_yup=True,
                              export_vertex_color="MATERIAL")
    print(f"Wyeksportowano: {path}")
