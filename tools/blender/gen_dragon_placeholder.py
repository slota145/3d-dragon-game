"""Placeholder smoka w stylu low-poly — test pipeline'u Blender -> glTF -> Godot.

Uruchomienie (z katalogu repo):
    .venv-tools/bin/python tools/blender/gen_dragon_placeholder.py
    .venv-tools/bin/python tools/blender/gen_dragon_placeholder.py -- --preview /tmp/dragon.png

Wynik: assets/models/dragon_placeholder.glb (model patrzy w +Z w Godocie).
"""

import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))

from common import (MODELS_DIR, cone, export_glb, ico, join, material, assign,  # noqa: E402
                    poly_mesh, preview_path_from_argv, render_preview, reset_scene,
                    segment, stats)

SIDES = (1, -1)


def build():
    reset_scene()
    scales = material("Dragon_Scales", (0.55, 0.08, 0.06), roughness=0.7)
    belly = material("Dragon_Belly", (0.90, 0.72, 0.42), roughness=0.9)
    membrane = material("Dragon_Membrane", (0.30, 0.04, 0.08), roughness=0.9)
    bone = material("Dragon_Bone", (0.92, 0.88, 0.75), roughness=0.6)
    eyes = material("Dragon_Eyes", (1.0, 0.8, 0.1), emission=3.0)

    parts = []
    add = parts.append

    # --- Tułów ---
    add(assign(ico("Body", 1.0, (0, 0, 1.3), scale=(0.7, 1.3, 0.65), subdiv=2), scales))
    add(assign(ico("Belly", 1.0, (0, -0.1, 1.08), scale=(0.52, 1.05, 0.45), subdiv=1), belly))

    # --- Szyja i głowa (przód = -Y) ---
    neck = [(0, -0.9, 1.55), (0, -1.45, 2.15), (0, -1.85, 2.6)]
    radii = [0.42, 0.32, 0.26]
    for i in range(len(neck) - 1):
        add(assign(segment(f"Neck{i}", neck[i], neck[i + 1], radii[i], radii[i + 1]), scales))
    add(assign(ico("Head", 1.0, (0, -2.15, 2.8), scale=(0.36, 0.5, 0.3), subdiv=1), scales))
    add(assign(segment("Snout", (0, -2.45, 2.75), (0, -2.95, 2.62), 0.22, 0.1), scales))
    add(assign(segment("Jaw", (0, -2.3, 2.58), (0, -2.85, 2.5), 0.16, 0.06), belly))
    for s in SIDES:
        add(assign(segment(f"Horn{s}", (0.17 * s, -2.0, 3.0), (0.38 * s, -1.55, 3.45), 0.08, 0.0, verts=5), bone))
        add(assign(ico(f"Eye{s}", 0.07, (0.24 * s, -2.42, 2.88)), eyes))

    # --- Grzbiet: kolce ---
    for i, y in enumerate([-0.7, -0.25, 0.2, 0.65, 1.05]):
        h = 0.35 - abs(y - 0.0) * 0.1
        add(assign(cone(f"Spike{i}", 0.12, 0.0, h, (0, y, 1.88 + h / 2), rot=(0.35, 0, 0), verts=4), bone))

    # --- Ogon ---
    tail = [(0, 1.1, 1.25), (0, 1.9, 0.95), (0, 2.8, 0.75), (0, 3.6, 0.8), (0, 4.3, 1.05)]
    tail_r = [0.45, 0.32, 0.22, 0.13, 0.06]
    for i in range(len(tail) - 1):
        add(assign(segment(f"Tail{i}", tail[i], tail[i + 1], tail_r[i], tail_r[i + 1]), scales))
    add(assign(poly_mesh("TailSpade", [(0, 4.2, 1.0), (0.3, 4.45, 1.12), (0, 4.95, 1.3), (-0.3, 4.45, 1.12)],
                         [(0, 1, 2, 3)], thickness=0.04), bone))

    # --- Nogi (udo -> kolano -> stopa) + pazury ---
    legs = {"Front": (-0.55, 0.42), "Back": (0.65, 0.5)}
    for name, (y, x) in legs.items():
        for s in SIDES:
            hip = (x * s, y, 1.15)
            knee = ((x + 0.12) * s, y - 0.15, 0.55)
            foot = ((x + 0.1) * s, y - 0.05, 0.08)
            add(assign(segment(f"{name}Thigh{s}", hip, knee, 0.24, 0.15), scales))
            add(assign(segment(f"{name}Shin{s}", knee, foot, 0.15, 0.11), scales))
            for c in (-1, 0, 1):
                tip = ((x + 0.1 + 0.09 * c) * s, y - 0.32, 0.02)
                add(assign(segment(f"{name}Claw{s}{c}", foot, tip, 0.045, 0.0, verts=4), bone))

    # --- Skrzydła: kości + błona ---
    for s in SIDES:
        shoulder = (0.45 * s, -0.45, 1.85)
        elbow = (1.6 * s, -0.2, 2.55)
        wrist = (2.8 * s, 0.15, 2.85)
        tips = [(3.9 * s, 0.45, 2.15), (3.5 * s, 1.15, 1.75), (2.6 * s, 1.45, 1.55)]
        root = (0.5 * s, 0.7, 1.65)
        add(assign(segment(f"WingArm{s}", shoulder, elbow, 0.13, 0.09), scales))
        add(assign(segment(f"WingForearm{s}", elbow, wrist, 0.09, 0.06), scales))
        for i, tip in enumerate(tips):
            add(assign(segment(f"WingFinger{s}{i}", wrist, tip, 0.05, 0.015, verts=4), scales))
        add(assign(cone(f"WingClaw{s}", 0.05, 0.0, 0.25, (wrist[0], wrist[1] - 0.1, wrist[2] + 0.12),
                        rot=(-0.6, 0, 0), verts=4), bone))
        v = [shoulder, elbow, wrist, tips[0], tips[1], tips[2], root]
        faces = [(0, 1, 6), (1, 2, 6), (2, 3, 4), (2, 4, 5), (2, 5, 6)]
        if s < 0:  # zachowaj zgodny kierunek normalnych po odbiciu
            faces = [tuple(reversed(f)) for f in faces]
        add(assign(poly_mesh(f"WingMembrane{s}", v, faces, thickness=0.03), membrane))

    dragon = join("DragonPlaceholder", parts)
    print(stats(dragon))
    return dragon


if __name__ == "__main__":
    build()
    export_glb(MODELS_DIR / "dragon_placeholder.glb")
    preview = preview_path_from_argv()
    if preview:
        render_preview(preview, target=(0, 0.6, 1.5), distance=11.0)
