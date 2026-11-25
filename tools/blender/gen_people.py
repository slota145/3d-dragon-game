"""Ludzie low-poly: wieśniak (widły), pasterz (kij pasterski), myśliwy (łuk, kołczan),
rycerz (hełm z pióropuszem, tarcza, włócznia), kusznik (kapalin, kusza) i koń bojowy (kropierz).

    .venv-tools/bin/python tools/blender/gen_people.py   # -> assets/models/people.glb

Bez szkieletu: każda postać to osobne obiekty <Rola>_Body, _LegL, _LegR, _ArmL, _ArmR
z punktem obrotu w stawie (biodro / bark) — gra macha nimi w kodzie (chód, bieg, dźganie).
Koń: Warhorse_Body, _LegFL/_LegFR/_LegBL/_LegBR (punkt obrotu w biodrze / łopatce).
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
    "People_Red": (0.62, 0.05, 0.05),
    "People_Gold": (1.0, 0.68, 0.15),
    "People_Steel": (0.55, 0.57, 0.62),
    "People_Horse": (0.3, 0.16, 0.07),
    "People_Mane": (0.06, 0.04, 0.03),
    "People_Navy": (0.06, 0.13, 0.42),
}
NAMES = list(PALETTE)
ROLES = {  # tunika, spodnie, nakrycie głowy
    "Villager": ("People_Brown", "People_Cream", "People_Straw"),
    "Shepherd": ("People_Blue", "People_Brown", "People_Cream"),
    "Hunter": ("People_Green", "People_Dark", "People_Green"),
    "Knight": ("People_Red", "People_Steel", "People_Steel"),
    "Crossbow": ("People_Red", "People_Dark", "People_Steel"),
    "Commander": ("People_Navy", "People_Steel", "People_Gold"),
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
    elif role == "Knight":  # hełm garnczkowy z wizurą i czerwonym pióropuszem, złoty pas
        b.tube([V(0, 0, 1.5), V(0, 0, 1.62), V(0, 0, 1.8)], [0.15, 0.155, 0.13], 8, hat, tip=False)
        b.tube([V(0, -0.02, 1.64), V(0, -0.02, 1.67)], [0.158, 0.158], 8, "People_Dark", tip=False)  # wizura
        b.tube([V(0, 0.02, 1.8), V(0, 0.12, 1.98), V(0, 0.32, 1.95)], [0.05, 0.06, 0.02], 5, "People_Red",
               tip=True)
        b.tube([V(0, 0, 0.9), V(0, 0, 0.96)], [0.215, 0.21], 7, "People_Gold", tip=False, flatten=0.72)
    elif role == "Commander":  # hełm z koroną, długi czerwony płaszcz, złoty pas
        b.tube([V(0, 0, 1.5), V(0, 0, 1.62), V(0, 0, 1.8)], [0.15, 0.155, 0.13], 8, "People_Steel", tip=False)
        b.tube([V(0, -0.02, 1.64), V(0, -0.02, 1.67)], [0.158, 0.158], 8, "People_Dark", tip=False)
        b.tube([V(0, 0, 1.78), V(0, 0, 1.86)], [0.145, 0.15], 8, hat, tip=False)  # obręcz korony
        for k in range(6):
            a = 2 * math.pi * k / 6
            b.blade(V(math.cos(a) * 0.14, math.sin(a) * 0.14, 1.85), (0, 0, 1), 0.12, (-math.sin(a), math.cos(a), 0),
                    0.04, (math.cos(a), math.sin(a), 0), 0.01, hat)
        b.tube([V(0, 0.12, 1.45), V(0, 0.24, 1.0), V(0, 0.34, 0.5)], [0.24, 0.3, 0.36], 8, "People_Red", tip=False,
               flatten=0.3)  # płaszcz
        b.tube([V(0, 0, 0.9), V(0, 0, 0.96)], [0.215, 0.21], 7, hat, tip=False, flatten=0.72)
    elif role == "Crossbow":  # kapalin (hełm z rondem) i bełty u pasa
        blob(b, (0, 0.0, 1.71), (0.14, 0.14, 0.1), hat, seg=8, rings=3)
        b.tube([V(0, 0, 1.68), V(0, 0, 1.7)], [0.25, 0.24], 9, hat, tip=False)
        b.tube([V(0.17, 0.1, 0.85), V(0.17, 0.1, 1.1)], [0.05, 0.05], 5, "People_Brown", tip=False)
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
        if role in ("Knight", "Crossbow", "Commander"):  # naramiennik
            blob(b, sh + V(0.02 * sx, 0, 0.02), (0.11, 0.11, 0.08), "People_Steel", seg=6, rings=3)
        if role in ("Knight", "Commander") and side == "L":  # tarcza ze złotym krzyżem, na zewnątrz ręki
            c = sh + V(0.1, -0.02, -0.4)
            ring = [c + V(0, -0.24, 0.26), c + V(0, 0.24, 0.26), c + V(0, 0.22, -0.1), c + V(0, 0, -0.36),
                    c + V(0, -0.22, -0.1)]
            b.loft([[p + V(0.03, 0, 0) for p in ring], [p - V(0.0, 0, 0) for p in ring]],
                   "People_Navy" if role == "Commander" else "People_Red")
            b.tube([c + V(0.035, 0, 0.22), c + V(0.035, 0, -0.3)], [0.03, 0.03], 4, "People_Gold", tip=False,
                   flatten=0.3)
            b.tube([c + V(0.035, -0.2, 0.08), c + V(0.035, 0.2, 0.08)], [0.03, 0.03], 4, "People_Gold", tip=False,
                   flatten=0.3)
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
            elif role == "Knight":  # włócznia (2,6 m) — w pionie; w szarży ręka kładzie ją do przodu
                b.tube([hand + V(0, 0, -0.9), hand + V(0, 0, 1.6)], [0.03, 0.03], 5, "People_Wood", tip=False)
                b.blade(hand + V(0, 0, 1.6), (0, 0, 1), 0.35, (1, 0, 0), 0.06, (0, 1, 0), 0.02, "People_Steel")
                b.add_face([b.add_vert(hand + V(0, 0, 1.55)), b.add_vert(hand + V(0, 0.4, 1.47)),
                            b.add_vert(hand + V(0, 0, 1.35))], "People_Red")  # proporczyk
                b.add_face([b.add_vert(hand + V(0, 0, 1.35)), b.add_vert(hand + V(0, 0.4, 1.47)),
                            b.add_vert(hand + V(0, 0, 1.55))], "People_Red")
            elif role == "Commander":  # kopia 3,4 m z proporcem, granatowo-złota
                b.tube([hand + V(0, 0, -0.9), hand + V(0, 0, 2.5)], [0.045, 0.03], 6, "People_Navy", tip=False)
                b.tube([hand + V(0, 0, -0.1), hand + V(0, 0, 0.25)], [0.09, 0.05], 6, "People_Gold", tip=False)
                b.blade(hand + V(0, 0, 2.5), (0, 0, 1), 0.45, (1, 0, 0), 0.07, (0, 1, 0), 0.025, "People_Steel")
                for f in ([hand + V(0, 0, 2.4), hand + V(0, 0.6, 2.25), hand + V(0, 0, 2.1)],):
                    b.add_face([b.add_vert(p) for p in f], "People_Gold")
                    b.add_face([b.add_vert(p) for p in reversed(f)], "People_Gold")
            elif role == "Crossbow":  # kusza: łoże wzdłuż ręki, łęczysko przy końcu (w celowaniu — przodem)
                b.tube([hand + V(0, 0, 0.15), hand + V(0, 0, -0.55)], [0.035, 0.03], 5, "People_Wood", tip=False)
                b.tube([hand + V(-0.33, 0.06, -0.42), hand + V(0, 0, -0.52), hand + V(0.33, 0.06, -0.42)],
                       [0.02, 0.03, 0.02], 4, "People_Steel", tip=False)
                b.tube([hand + V(-0.33, 0.06, -0.42), hand + V(0, 0.1, -0.3), hand + V(0.33, 0.06, -0.42)],
                       [0.006, 0.006, 0.006], 3, "People_Cream", tip=False)
            else:  # łuk
                pts = [hand + V(0, 0.05 * math.sin(t * math.pi) - 0.02, (t - 0.5) * 1.3) for t in
                       [k / 6 for k in range(7)]]
                b.tube(pts, [0.02] * 7, 5, "People_Wood", tip=False)
                b.tube([pts[0], pts[-1]], [0.005, 0.005], 3, "People_Cream", tip=False)
        objs.append(part(f"{role}_Arm{side}", b, mats, sh))
    return objs


def gryphon_tack(mats) -> list[bpy.types.Object]:
    """Rząd gryfa (Tack_Body) w układzie modelu gryfa z animals.glb: siodło na grzbiecie (z ~ 1,85),
    czerwona kapa ze złotym brzegiem, stalowy napierśnik i naczółek."""
    b = MeshBuilder(NAMES)

    def ring(z, rx, ry, cy, n=12):
        return [V(rx * math.cos(2 * math.pi * k / n), cy + ry * math.sin(2 * math.pi * k / n), z) for k in range(n)]
    b.loft([ring(1.83, 0.18, 0.45, 0.05), ring(1.7, 0.4, 0.62, 0.05), ring(1.3, 0.47, 0.7, 0.05)], "People_Red",
           cap_start=False, cap_end=False)
    b.loft([ring(1.31, 0.475, 0.705, 0.05), ring(1.2, 0.48, 0.71, 0.05)], "People_Gold", cap_start=False,
           cap_end=False)
    blob(b, (0, 0.0, 1.9), (0.26, 0.34, 0.1), "People_Brown", seg=7, rings=3)  # siodło
    b.tube([V(0, -0.82, 1.55), V(0, -0.95, 1.2)], [0.42, 0.34], 8, "People_Steel", tip=False, flatten=0.8)  # napierśnik
    for x in (-0.3, 0.3):  # strzemiona
        b.tube([V(x, 0.0, 1.85), V(x * 1.4, 0.0, 1.25)], [0.012, 0.012], 3, "People_Dark", tip=False)
    return [part("Tack_Body", b, mats, V(0, 0, 0))]


def warhorse(mats) -> list[bpy.types.Object]:
    """Koń bojowy w czerwonym kropierzu ze złotym brzegiem; siodło na wys. ~1,5 m, wiązka oszczepów."""
    objs = []
    b = MeshBuilder(NAMES)
    blob(b, (0, 0, 1.3), (0.4, 0.98, 0.42), "People_Horse", seg=8, rings=5)
    b.tube([V(0, -0.75, 1.5), V(0, -1.1, 1.95)], [0.25, 0.19], 6, "People_Horse", tip=False)  # szyja
    blob(b, (0, -1.35, 2.0), (0.16, 0.38, 0.19), "People_Horse", seg=6, rings=4)  # głowa
    b.tube([V(0, -1.3, 2.12), V(0, -1.55, 2.08)], [0.17, 0.12], 6, "People_Steel", tip=False)  # naczółek
    b.tube([V(0, -0.8, 1.8), V(0, -1.1, 2.2)], [0.07, 0.05], 4, "People_Mane", tip=False)
    b.tube([V(0, 0.95, 1.45), V(0, 1.3, 0.85)], [0.08, 0.03], 4, "People_Mane", tip=False)  # ogon
    # kropierz: płachta przewieszona przez grzbiet, opada do kolan (otwarta od spodu), złoty brzeg
    def ring(z, rx, ry, n=14):
        return [V(rx * math.cos(2 * math.pi * k / n), ry * math.sin(2 * math.pi * k / n), z) for k in range(n)]
    b.loft([ring(1.62, 0.2, 0.75), ring(1.5, 0.38, 0.95), ring(1.2, 0.45, 1.04), ring(0.82, 0.47, 1.07)],
           "People_Red", cap_start=False, cap_end=False)
    b.loft([ring(0.83, 0.475, 1.075), ring(0.72, 0.48, 1.08)], "People_Gold", cap_start=False, cap_end=False)
    blob(b, (0, 0.05, 1.74), (0.3, 0.38, 0.1), "People_Brown", seg=7, rings=3)  # siodło
    for x in (-0.33, 0.33):  # strzemiona
        b.tube([V(x, -0.05, 1.7), V(x * 1.1, -0.05, 1.05)], [0.012, 0.012], 3, "People_Dark", tip=False)
    for k in range(3):  # oszczepy przy siodle
        b.tube([V(0.52, 0.55 + k * 0.05, 1.0), V(0.5, -0.45 + k * 0.05, 1.85)], [0.025, 0.025], 4, "People_Wood",
               tip=False)
        b.blade(V(0.5, -0.45 + k * 0.05, 1.85), (0, -1.0, 0.85), 0.2, (1, 0, 0), 0.03, (0, 0, 1), 0.01,
                "People_Steel")
    objs.append(part("Warhorse_Body", b, mats, V(0, 0, 0)))
    for name, x, y in (("FL", 0.24, -0.6), ("FR", -0.24, -0.6), ("BL", 0.24, 0.62), ("BR", -0.24, 0.62)):
        b = MeshBuilder(NAMES)
        top = V(x, y, 1.1)
        b.tube([top, V(x, y, 0.55), V(x, y, 0.08)], [0.1, 0.075, 0.065], 5, "People_Horse", tip=False)
        b.tube([V(x, y, 0.1), V(x, y, -0.0)], [0.08, 0.08], 5, "People_Dark", tip=False)  # kopyto
        objs.append(part(f"Warhorse_Leg{name}", b, mats, top))
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
    objs = warhorse(MATS) + gryphon_tack(MATS)
    for o in objs:
        flat_shade(o)
        face_color_variation(o, 0.06, seed=91 + len(o.name))
    print(f"Warhorse: {sum(tri_count(o) for o in objs)} trójkątów")
    all_objs += objs
    bpy.ops.object.select_all(action="DESELECT")
    for o in all_objs:
        o.select_set(True)
    path = common.MODELS_DIR / "people.glb"
    bpy.ops.export_scene.gltf(filepath=str(path), export_format="GLB", use_selection=True, export_yup=True,
                              export_vertex_color="MATERIAL")
    print(f"Wyeksportowano: {path}")
