"""Smok (wywerna) low-poly gotowy do gry: model + szkielet + animacje.

    .venv-tools/bin/python tools/blender/gen_dragon.py                 # -> assets/models/dragon.glb
    .venv-tools/bin/python tools/blender/gen_dragon.py -- --preview DIR  # + rendery podglądowe

Konwencje: Z w górę, przód = -Y (po eksporcie +Z w Godocie), 1 jednostka = 1 m.
"""

from __future__ import annotations

import math
import pathlib
import random
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))

import bpy  # noqa: E402
from mathutils import Quaternion, Vector  # noqa: E402

import common  # noqa: E402
from meshkit import (MeshBuilder, add_grid, assign_distance_weights, catmull_rom, coons,  # noqa: E402
                     ellipse_profile, face_color_variation, flat_shade, frames,
                     mirror_half_profile, tri_count)

SEED = 7
BODY_TRIS = 2800

# ---------------------------------------------------------------------------
# Paleta (kolory liniowe)
# ---------------------------------------------------------------------------
PALETTE = {
    "Dragon_Scales": dict(color=(0.075, 0.08, 0.066), rough=0.85),
    "Dragon_Membrane": dict(color=(0.048, 0.050, 0.044), rough=0.9, double=True),
    "Dragon_Frill": dict(color=(0.78, 0.74, 0.55), rough=0.8),
    "Dragon_Horn": dict(color=(0.11, 0.108, 0.092), rough=0.7),
    "Dragon_Claw": dict(color=(0.16, 0.152, 0.13), rough=0.55),
    "Dragon_Teeth": dict(color=(0.80, 0.76, 0.60), rough=0.5),
    "Dragon_Mouth": dict(color=(0.50, 0.015, 0.025), rough=0.6),
    "Dragon_Tongue": dict(color=(0.30, 0.012, 0.02), rough=0.6),
    "Dragon_Eye": dict(color=(1.0, 0.42, 0.04), rough=0.3, emission=1.2),
    "Dragon_Pupil": dict(color=(0.005, 0.005, 0.005), rough=0.3),
}
MAT_NAMES = list(PALETTE)
SCALES, MEMBRANE, FRILL, HORN, CLAW, TEETH, MOUTH, TONGUE, EYE, PUPIL = MAT_NAMES


def make_materials() -> dict[str, bpy.types.Material]:
    mats = {}
    for name, p in PALETTE.items():
        mat = common.material(name, p["color"], roughness=p["rough"], emission=p.get("emission", 0.0))
        mat.use_backface_culling = not p.get("double", False)
        nt = mat.node_tree
        bsdf = nt.nodes["Principled BSDF"]
        vc = nt.nodes.new("ShaderNodeVertexColor")
        vc.layer_name = "Col"
        mix = nt.nodes.new("ShaderNodeMix")
        mix.data_type = "RGBA"
        mix.blend_type = "MULTIPLY"
        mix.inputs["Factor"].default_value = 1.0
        mix.inputs[6].default_value = (*p["color"], 1.0)
        nt.links.new(vc.outputs["Color"], mix.inputs[7])
        nt.links.new(mix.outputs[2], bsdf.inputs["Base Color"])
        mats[name] = mat
    return mats


def V(x, y, z) -> Vector:
    return Vector((x, y, z))


def mx(p, s: int) -> Vector:
    """Odbicie punktu na stronę s (1 = prawa, -1 = lewa)."""
    return V(p[0] * s, p[1], p[2])


SIDES = ((1, "R"), (-1, "L"))

# ---------------------------------------------------------------------------
# Szkielet (prawa strona; lewa = odbicie X)
# ---------------------------------------------------------------------------
# Kręgosłup od czubka ogona do głowy: pozycja, (szerokość, góra, dół, grzbiet)
SPINE = [
    (V(0, 7.35, 1.05), (0.02, 0.02, 0.02, 0.0)),
    (V(0, 7.1, 1.05), (0.06, 0.06, 0.05, 0.0)),
    (V(0, 5.9, 1.0), (0.13, 0.13, 0.11, 0.02)),
    (V(0, 4.9, 1.07), (0.21, 0.21, 0.18, 0.03)),
    (V(0, 3.9, 1.25), (0.3, 0.31, 0.26, 0.04)),
    (V(0, 2.9, 1.55), (0.42, 0.44, 0.38, 0.05)),
    (V(0, 1.9, 1.88), (0.58, 0.56, 0.54, 0.06)),
    (V(0, 1.0, 2.1), (0.74, 0.62, 0.7, 0.07)),
    (V(0, 0.1, 2.2), (0.86, 0.68, 0.86, 0.07)),
    (V(0, -0.8, 2.42), (0.92, 0.74, 1.0, 0.07)),
    (V(0, -1.45, 2.75), (0.7, 0.66, 0.78, 0.06)),
    (V(0, -2.05, 3.05), (0.54, 0.52, 0.56, 0.05)),
    (V(0, -2.65, 3.2), (0.46, 0.45, 0.47, 0.04)),
    (V(0, -3.15, 3.15), (0.4, 0.4, 0.41, 0.03)),
    (V(0, -3.4, 3.03), (0.38, 0.39, 0.37, 0.02)),
    (V(0, -3.56, 3.0), (0.3, 0.3, 0.22, 0.0)),
]
SPINE_JOINTS = {  # kości kręgosłupa: nazwa -> (od, do)
    "Hips": (V(0, 1.0, 2.1), V(0, 0.1, 2.2)),
    "Spine": (V(0, 0.1, 2.2), V(0, -0.8, 2.42)),
    "Chest": (V(0, -0.8, 2.42), V(0, -1.45, 2.75)),
    "Neck1": (V(0, -1.45, 2.75), V(0, -2.05, 3.05)),
    "Neck2": (V(0, -2.05, 3.05), V(0, -2.65, 3.2)),
    "Neck3": (V(0, -2.65, 3.2), V(0, -3.15, 3.15)),
    "Neck4": (V(0, -3.15, 3.15), V(0, -3.5, 2.98)),
    "Tail1": (V(0, 1.0, 2.1), V(0, 1.9, 1.88)),
    "Tail2": (V(0, 1.9, 1.88), V(0, 2.9, 1.55)),
    "Tail3": (V(0, 2.9, 1.55), V(0, 3.9, 1.25)),
    "Tail4": (V(0, 3.9, 1.25), V(0, 4.9, 1.07)),
    "Tail5": (V(0, 4.9, 1.07), V(0, 5.9, 1.0)),
    "Tail6": (V(0, 5.9, 1.0), V(0, 7.25, 1.05)),
}
SPINE_PARENTS = {"Hips": None, "Spine": "Hips", "Chest": "Spine", "Neck1": "Chest", "Neck2": "Neck1",
                 "Neck3": "Neck2", "Neck4": "Neck3", "Tail1": "Hips", "Tail2": "Tail1", "Tail3": "Tail2",
                 "Tail4": "Tail3", "Tail5": "Tail4", "Tail6": "Tail5"}

# Głowa: początek, kierunek przodu i "góry" głowy
HEAD_ORIGIN = V(0, -3.5, 2.98)
HEAD_FWD = V(0, -1, -0.3).normalized()
HEAD_UP = HEAD_FWD.cross(V(1, 0, 0)).normalized()
HEAD_LEN = 1.45
HS = 1.32  # skala głowy
JAW_HINGE = (0.0, -0.15)  # (f, z) w układzie głowy
JAW_REST_OPEN = 0.0  # pysk domyślnie zamknięty

LEG = dict(hip=V(0.5, 0.95, 1.95), knee=V(0.8, 0.2, 1.3), ankle=V(0.76, 1.05, 0.55), ball=V(0.73, 0.78, 0.14))
TOE_TIPS = [V(0.5, 0.28, 0.07), V(0.74, 0.2, 0.07), V(0.97, 0.34, 0.07)]
BACK_TOE_TIP = V(0.73, 1.15, 0.06)

ARM = dict(shoulder=V(0.42, -0.95, 2.85), elbow=V(1.95, 0.15, 3.05), wrist=V(4.0, -0.75, 3.45))
FINGER_TIPS = [V(8.3, -0.25, 3.0), V(7.9, 1.65, 2.55), V(6.5, 3.15, 2.3), V(4.7, 3.65, 2.15)]
WING_ROOT_BACK = V(0.6, 1.75, 1.9)  # tylne zaczepienie błony przy biodrze
THUMB_DIR = V(0, -0.42, -0.72).normalized()  # ogólny kierunek szponów "dłoni"
WRIST_GROUND = V(1.3, -1.85, 0.3)  # nadgarstek oparty o ziemię w pozycji stojącej (prawa strona)


def head_point(x: float, f: float, z: float) -> Vector:
    return HEAD_ORIGIN + V(1, 0, 0) * x + HEAD_FWD * f + HEAD_UP * z


def jaw_local(f: float, z: float, angle: float) -> tuple[float, float]:
    """Obrót punktu żuchwy (f, z) wokół zawiasu o kąt otwarcia."""
    f0, z0 = JAW_HINGE
    df, dz = f - f0, z - z0
    c, s = math.cos(angle), math.sin(angle)
    return f0 + df * c + dz * s, z0 - df * s + dz * c


def jaw_point(x: float, f: float, z: float, angle: float = JAW_REST_OPEN) -> Vector:
    f2, z2 = jaw_local(f, z, angle)
    return head_point(x, f2, z2)


# ---------------------------------------------------------------------------
# Tułów (lofty -> voxel remesh -> wygładzenie -> decimate = "ciosane" low-poly)
# ---------------------------------------------------------------------------

def spine_samples(per_seg: int = 5):
    pos = catmull_rom([p for p, _ in SPINE], per_seg)
    prm = catmull_rom([Vector(q) for _, q in SPINE], per_seg)
    return list(zip(pos, frames(pos, (0, 0, 1)), prm))


def loft_path(b: MeshBuilder, ctrl, mat, up_hint=(0, 0, 1), n: int = 16, per_seg: int = 5, cap=True):
    """ctrl: [(punkt, (w, góra, dół[, grzbiet]))] -> loft z przekrojami eliptycznymi."""
    pos = catmull_rom([p for p, _ in ctrl], per_seg)
    prm = catmull_rom([Vector(tuple(q) + (0.0,) * (4 - len(q))) for _, q in ctrl], per_seg)
    rings = []
    for p, (t, side, up), q in zip(pos, frames(pos, up_hint), prm):
        rings.append([p + side * x + up * z for x, z in ellipse_profile(n, q[0], q[1], q[2], q[3])])
    b.loft(rings, mat, cap_start=cap, cap_end=cap)


def ellipsoid(b: MeshBuilder, center, radii, mat, groups=None, seg: int = 8, rings: int = 6):
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
            ring.append(c + V(radii[0] * math.sin(th) * math.cos(ph), radii[1] * math.sin(th) * math.sin(ph),
                              radii[2] * math.cos(th)))
        pts.append(ring)
    b.loft(pts, mat, groups, cap_start=False, cap_end=False)


def build_body(mats) -> bpy.types.Object:
    b = MeshBuilder(MAT_NAMES)
    rings = []
    for p, (t, side, up), q in spine_samples():
        rings.append([p + side * x + up * z for x, z in ellipse_profile(20, q[0], q[1], q[2], q[3])])
    b.loft(rings, SCALES)

    for s, _ in SIDES:
        L = {k: mx(v, s) for k, v in LEG.items()}
        loft_path(b, [(mx((0.2, 1.0, 2.3), s), (0.5, 0.55, 0.5)), (L["hip"], (0.66, 0.78, 0.6)),
                      (mx((0.74, 0.55, 1.6), s), (0.54, 0.64, 0.46)), (L["knee"], (0.3, 0.33, 0.28))],
                  SCALES, up_hint=(0, -1, 0))
        loft_path(b, [(L["knee"], (0.3, 0.3, 0.27)), (L["knee"].lerp(L["ankle"], 0.5), (0.24, 0.26, 0.21)),
                      (L["ankle"], (0.17, 0.17, 0.16))], SCALES, up_hint=(0, -1, 0))
        loft_path(b, [(L["ankle"], (0.17, 0.17, 0.16)), (L["ball"], (0.15, 0.15, 0.13))], SCALES,
                  up_hint=(0, -1, 0))
        ellipsoid(b, L["ball"] + V(0, -0.05, 0.0), (0.2, 0.24, 0.14), SCALES)
        for tip in TOE_TIPS + [BACK_TOE_TIP]:
            tip = mx(tip, s)
            knuckle = L["ball"].lerp(tip, 0.5) + V(0, 0, 0.1)
            b.tube([L["ball"] + V(0, 0, 0.02), knuckle, tip], [0.12, 0.1, 0.065], 8, SCALES, tip=False,
                   up_hint=(0, 0, 1))

        A = {k: mx(v, s) for k, v in ARM.items()}
        loft_path(b, [(mx((0.1, -0.9, 2.5), s), (0.5, 0.5, 0.5)), (A["shoulder"], (0.46, 0.46, 0.42)),
                      (mx((1.15, -0.4, 3.02), s), (0.33, 0.37, 0.3)), (A["elbow"], (0.2, 0.21, 0.19))],
                  SCALES, up_hint=(0, 0, 1))
        loft_path(b, [(A["elbow"], (0.2, 0.2, 0.19)), (mx((3.0, -0.3, 3.27), s), (0.17, 0.19, 0.15)),
                      (A["wrist"], (0.13, 0.13, 0.12))], SCALES, up_hint=(0, 0, 1))
        ellipsoid(b, A["wrist"], (0.2, 0.18, 0.17), SCALES)

    obj = b.to_object("DragonBody", mats)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    rem = obj.modifiers.new("Remesh", "REMESH")
    rem.mode = "VOXEL"
    rem.voxel_size = 0.03
    bpy.ops.object.modifier_apply(modifier=rem.name)
    sm = obj.modifiers.new("Smooth", "SMOOTH")
    sm.factor = 0.6
    sm.iterations = 6
    bpy.ops.object.modifier_apply(modifier=sm.name)
    dec = obj.modifiers.new("Decimate", "DECIMATE")
    dec.decimate_type = "COLLAPSE"
    dec.use_symmetry = True
    dec.symmetry_axis = "X"
    dec.ratio = min(1.0, BODY_TRIS / max(1, tri_count(obj)))
    bpy.ops.object.modifier_apply(modifier=dec.name)
    obj.data.materials.clear()
    for m in MAT_NAMES:
        obj.data.materials.append(mats[m])
    for p in obj.data.polygons:
        p.material_index = 0
    flat_shade(obj)
    return obj


# ---------------------------------------------------------------------------
# Głowa
# ---------------------------------------------------------------------------
S_, R_ = SCALES, MOUTH
# Pół-profile głowy: (f, [(x, z, materiał krawędzi zaczynającej się w punkcie)]) od środka góry do środka dołu.
# Górna szczęka: góra, brew, policzek, warga (zewn. dół) -> dziąsło -> podniebienie (czerwone).
HEAD_RINGS = [
    (-0.1, [(0, .32, S_), (.22, .3, S_), (.37, .14, S_), (.38, -.04, S_), (.36, -.17, S_), (.28, -.16, S_),
            (.12, -.08, R_), (0, -.06, S_)]),
    (0.33, [(0, .36, S_), (.2, .36, S_), (.4, .25, S_), (.38, .05, S_), (.35, -.15, S_), (.28, -.15, S_),
            (.12, -.06, R_), (0, -.04, S_)]),
    (0.6, [(0, .3, S_), (.15, .3, S_), (.29, .2, S_), (.32, .03, S_), (.3, -.14, S_), (.24, -.14, S_),
           (.1, -.05, R_), (0, -.03, S_)]),
    (0.88, [(0, .23, S_), (.12, .23, S_), (.23, .15, S_), (.26, .0, S_), (.25, -.13, S_), (.2, -.13, S_),
            (.08, -.05, R_), (0, -.03, S_)]),
    (1.08, [(0, .15, S_), (.11, .15, S_), (.2, .09, S_), (.22, -.03, S_), (.2, -.12, S_), (.15, -.12, S_),
            (.06, -.06, R_), (0, -.05, S_)]),
    (1.18, [(0, .07, S_), (.07, .07, S_), (.12, .03, S_), (.13, -.05, S_), (.11, -.1, S_), (.07, -.1, S_),
            (.03, -.07, S_), (0, -.07, S_)]),
]
# Żuchwa (zamknięta): dno pyska (czerwone) -> dziąsło -> zewnętrzna ściana -> podbródek.
# Leży wewnątrz górnej wargi (górna szczęka zachodzi na dolną).
JAW_RINGS = [
    (-0.05, [(0, -.2, R_), (.14, -.19, R_), (.3, -.14, S_), (.33, -.22, S_), (.3, -.33, S_), (.18, -.4, S_),
             (0, -.42, S_)]),
    (0.35, [(0, -.17, R_), (.13, -.16, R_), (.29, -.13, S_), (.31, -.2, S_), (.27, -.29, S_), (.16, -.34, S_),
            (0, -.35, S_)]),
    (0.7, [(0, -.15, R_), (.11, -.15, R_), (.24, -.12, S_), (.26, -.18, S_), (.23, -.25, S_), (.13, -.29, S_),
           (0, -.3, S_)]),
    (0.98, [(0, -.13, R_), (.08, -.13, R_), (.17, -.11, S_), (.19, -.17, S_), (.16, -.23, S_), (.09, -.26, S_),
            (0, -.27, S_)]),
    (1.15, [(0, -.145, S_), (.05, -.145, S_), (.11, -.135, S_), (.13, -.17, S_), (.11, -.21, S_), (.06, -.23, S_),
           (0, -.24, S_)]),
]
UPPER_LIP, UPPER_GUM, JAW_GUM, JAW_FLOOR = 4, 5, 2, 0
HEAD_G, JAW_G = {"Head": 1.0}, {"Jaw": 1.0}
NECK_BONES = ["Chest", "Neck1", "Neck2", "Neck3", "Neck4"]


def hp(x: float, f: float, z: float) -> Vector:
    return head_point(x * HS, f * HS, z * HS)


def jp(x: float, f: float, z: float, angle: float = JAW_REST_OPEN) -> Vector:
    f2, z2 = jaw_local(f, z, angle)
    return head_point(x * HS, f2 * HS, z2 * HS)


def ring_interp(rings, idx: int, f: float) -> tuple[float, float]:
    if f <= rings[0][0]:
        return rings[0][1][idx][:2]
    for (f0, h0), (f1, h1) in zip(rings, rings[1:]):
        if f <= f1:
            t = (f - f0) / (f1 - f0)
            return h0[idx][0] + (h1[idx][0] - h0[idx][0]) * t, h0[idx][1] + (h1[idx][1] - h0[idx][1]) * t
    return rings[-1][1][idx][:2]


def nearest_bone(p: Vector, names) -> str:
    from meshkit import seg_distance
    return min(names, key=lambda n: seg_distance(p, *SPINE_JOINTS[n]))


def ellipsoid_xf(b: MeshBuilder, xf, radii, mat, groups=None, seg: int = 8, rings: int = 4):
    """Elipsoida w lokalnym układzie: xf(Vector lokalny) -> punkt świata."""
    pts = []
    for i in range(rings + 1):
        th = math.pi * i / rings
        if i in (0, rings):
            pts.append(xf(V(0, 0, radii[2] * math.cos(th))))
            continue
        pts.append([xf(V(radii[0] * math.sin(th) * math.cos(2 * math.pi * k / seg),
                         radii[1] * math.sin(th) * math.sin(2 * math.pi * k / seg),
                         radii[2] * math.cos(th))) for k in range(seg)])
    b.loft(pts, mat, groups, cap_start=False, cap_end=False)


def _profile_loft(b: MeshBuilder, rings_def, point_fn, groups) -> None:
    """Loft głowy/żuchwy; materiały krawędzi z pierwszego przekroju (przód zamyka szara pokrywa)."""
    rings, mats = [], mirror_half_profile(rings_def[0][1])[1]
    for f, half in rings_def:
        pts, _ = mirror_half_profile(half)
        rings.append([point_fn(x, f, z) for x, z in pts])
    # ostatni odcinek (czubek nosa / brody) w całości w łuskach – bez czerwonego prześwitu
    b.loft(rings[:-1], mats, groups, cap_end=False, cap_mat=SCALES)
    b.loft(rings[-2:], SCALES, groups, cap_start=False, cap_mat=SCALES)


def tooth(b: MeshBuilder, base: Vector, d: Vector, length: float, r: float, groups, curve: Vector) -> None:
    """Ząb: czworokątny stożek, lekko zakrzywiony (curve = kierunek wygięcia czubka)."""
    mid = base + d * (length * 0.55) + curve * (length * 0.05)
    tip = base + d * length + curve * (length * 0.22)
    b.tube([base, mid, tip], [r, r * 0.6, 0.0], 4, TEETH, groups, tip=True, samples=2, twist=0.785)


def build_head(b: MeshBuilder) -> None:
    X = V(1, 0, 0)
    _profile_loft(b, HEAD_RINGS, hp, HEAD_G)
    _profile_loft(b, JAW_RINGS, jp, JAW_G)

    # kąciki pyska (policzki) i gardło – widoczne dopiero po otwarciu
    for s in (1, -1):
        prev = None
        for i in range(6):
            f = -0.08 + 0.08 * i
            ux, uz = ring_interp(HEAD_RINGS, UPPER_GUM, f)
            lx, lz = ring_interp(JAW_RINGS, JAW_GUM, f)
            cur = (b.add_vert(hp(s * ux * 0.95, f, uz), HEAD_G), b.add_vert(jp(s * lx * 0.92, f, lz), JAW_G))
            if prev:
                b.add_face((prev[0], cur[0], cur[1], prev[1]), MOUTH)
            prev = cur
    top = [b.add_vert(hp(s * x, -0.06, z), HEAD_G) for s, x, z in ((1, .27, -.15), (1, .12, -.08), (0, 0, -.06),
                                                                     (-1, .12, -.08), (-1, .27, -.15))]
    bot = [b.add_vert(jp(s * x, -0.06, z), JAW_G) for s, x, z in ((1, .27, -.15), (1, .13, -.2), (0, 0, -.21),
                                                                    (-1, .13, -.2), (-1, .27, -.15))]
    for i in range(4):
        b.add_face((top[i], top[i + 1], bot[i + 1], bot[i]), MOUTH)
    # język – w całości w żuchwie
    b.tube([jp(0, 0.0, -0.21), jp(0, 0.4, -0.18), jp(0, 0.8, -0.155)], [0.075 * HS, 0.06 * HS, 0.015 * HS], 8,
           TONGUE, JAW_G, up_hint=HEAD_UP, flatten=0.3)

    up_dir = HEAD_UP
    for s in (1, -1):
        out = X * s
        # zęby górne: mniej, większe, wystają za żuchwę przy zamkniętym pysku
        for f, ln, r in ((0.1, 0.08, 0.028), (0.25, 0.1, 0.03), (0.4, 0.11, 0.032), (0.54, 0.1, 0.03),
                         (0.67, 0.13, 0.034), (0.8, 0.24, 0.05), (0.93, 0.12, 0.032), (1.04, 0.09, 0.028)):
            lx, lz = ring_interp(HEAD_RINGS, UPPER_LIP, f)
            gx, gz = ring_interp(HEAD_RINGS, UPPER_GUM, f)
            base = hp(s * (lx * 0.62 + gx * 0.38), f, lz + 0.015)
            d = (-up_dir + out * 0.08).normalized()
            tooth(b, base, d, ln * HS, r * HS, HEAD_G, -HEAD_FWD)
        # zęby dolne (schowane za górną wargą), jeden kieł wystaje na zewnątrz
        for f, ln, r in ((0.18, 0.08, 0.026), (0.34, 0.09, 0.028), (0.5, 0.09, 0.028), (0.63, 0.1, 0.03),
                         (1.0, 0.08, 0.026)):
            gx, gz = ring_interp(JAW_RINGS, JAW_GUM, f)
            base = jp(s * gx * 0.97, f, gz - 0.015)
            d = (jp(s * gx, f, gz + 0.1) - jp(s * gx, f, gz)).normalized()
            tooth(b, base, d, ln * HS, r * HS, JAW_G, -HEAD_FWD)
        lx, lz = ring_interp(HEAD_RINGS, UPPER_LIP, 0.9)
        base = jp(s * (lx + 0.02), 0.9, -0.15)
        tooth(b, base, (up_dir + out * 0.12).normalized(), 0.17 * HS, 0.04 * HS, JAW_G, -HEAD_FWD)

        # oko pod łukiem brwiowym + pionowa źrenica
        def eye_xf(v, s=s):
            return hp(s * 0.335 + s * v.x, 0.43 + v.y, 0.1 + v.z)
        ellipsoid_xf(b, eye_xf, (0.045, 0.085, 0.05), EYE, HEAD_G, seg=8, rings=4)
        b.blade(hp(s * 0.378, 0.44, 0.055), HEAD_UP, 0.095 * HS, HEAD_FWD, 0.011, X, 0.01, PUPIL, HEAD_G)
        # łuk brwiowy: jeden mocny kolec do tyłu z krawędzi czaszki
        b.blade(hp(s * 0.38, 0.36, 0.23), (-HEAD_FWD + out * 0.35 + HEAD_UP * 0.15), 0.34 * HS, HEAD_FWD,
                0.09 * HS, HEAD_UP, 0.035 * HS, SCALES, HEAD_G)
        # nozdrza
        def nostril_xf(v, s=s):
            return hp(s * 0.075 + s * v.x, 1.13 + v.y, 0.05 + v.z)
        ellipsoid_xf(b, nostril_xf, (0.03, 0.04, 0.018), PUPIL, HEAD_G, seg=6, rings=3)
        # rogi
        for (x0, z0, ln, r0) in ((0.17, 0.3, 0.95, 0.09), (0.3, 0.16, 0.6, 0.065)):
            p0 = hp(s * x0, 0.02, z0)
            path = [p0, p0 + (-HEAD_FWD * 0.45 * ln + HEAD_UP * 0.12 + out * 0.08) * HS,
                    p0 + (-HEAD_FWD * 0.9 * ln + HEAD_UP * 0.2 + out * 0.18) * HS]
            b.tube(path, [r0 * HS, r0 * 0.6 * HS, 0.0], 6, HORN, HEAD_G, tip=True)
        # kolce policzkowe (tył czaszki) i pod żuchwą
        for f, z, ln in ((0.05, 0.0, 0.3), (-0.02, -0.1, 0.24)):
            b.blade(hp(s * 0.36, f, z), (-HEAD_FWD + out * 0.45 - HEAD_UP * 0.05), ln * HS, HEAD_FWD, 0.07 * HS,
                    HEAD_UP, 0.03 * HS, SCALES, HEAD_G)
        jaw_down = (jp(0, 0.3, -0.5) - jp(0, 0.3, -0.4)).normalized()
        jaw_back = -HEAD_FWD
        for f, ln in ((0.0, 0.24), (0.2, 0.17)):
            b.blade(jp(s * 0.22, f, -0.36), jaw_back + jaw_down * 0.5 + out * 0.35, ln * HS, jaw_back,
                    0.05 * HS, X, 0.02 * HS, SCALES, JAW_G)
    # małe kolce na nosie
    for f, ln in ((0.7, 0.09), (0.86, 0.07)):
        _, ztop = ring_interp(HEAD_RINGS, 0, f)
        b.blade(hp(0, f, ztop), HEAD_UP - HEAD_FWD * 0.6, ln * HS, HEAD_FWD, 0.035 * HS, X, 0.015 * HS, HORN, HEAD_G)


# ---------------------------------------------------------------------------
# Grzywa na szyi, kolce na grzbiecie i ogonie
# ---------------------------------------------------------------------------

def build_frill(b: MeshBuilder) -> None:
    """Grzywa: kołnierz z szerokich płytek ułożonych jak dachówki (kremowe, szare końce)
    + środkowy grzebień z szarych kolców."""
    rnd = random.Random(SEED + 2)
    neck = sorted([smp for smp in spine_samples(per_seg=6) if -3.8 <= smp[0].y <= -1.0], key=lambda m: m[0].y)
    n = len(neck)
    # (kąt od grzbietu, długość, materiał, materiał końca, odchylenie od szyi, pół-szerokość, podział koloru)
    rows = ((0.0, 0.42, SCALES, HORN, 1.0, 0.07, 0.6),
            (0.42, 0.8, FRILL, SCALES, 0.3, 0.2, 0.74),
            (0.8, 0.76, FRILL, FRILL, 0.26, 0.2, 0.8),
            (1.15, 0.56, FRILL, SCALES, 0.22, 0.17, 0.72))
    for i, (c, (t, side, up), q) in enumerate(neck):
        tn = i / (n - 1)
        env = 0.5 + 0.5 * math.sin(math.pi * min(1.0, 0.15 + tn * 0.9))
        bone = nearest_bone(c, NECK_BONES)
        for s in (1, -1):
            for r, (ang, ln, mat, tip_mat, out, w, split) in enumerate(rows):
                if (i + r) % 2 or (r == 0 and s < 0):
                    continue
                a = ang + rnd.uniform(-0.02, 0.02)
                nrm = (side * (s * math.sin(a)) + up * math.cos(a)).normalized()
                base = c + side * (s * math.sin(a) * q[0] * 0.95) + up * (math.cos(a) * q[1] * 0.95)
                d = (-t + nrm * out).normalized()
                length = ln * env * rnd.uniform(0.93, 1.07)
                b.blade2(base, d, length, t, w * (0.75 + 0.35 * env), d.cross(t), 0.015, mat, tip_mat, {bone: 1.0},
                         split=split + rnd.uniform(-0.04, 0.04))


def build_back_spikes(b: MeshBuilder) -> None:
    rnd = random.Random(SEED + 3)
    for c, (t, side, up), q in spine_samples(per_seg=3):
        y = c.y
        if not (-1.1 < y < 7.05):
            continue
        h = 0.28 + 0.55 * math.exp(-((y + 0.5) / 0.9) ** 2) + 0.22 * math.exp(-((y - 1.3) / 0.8) ** 2)
        h *= max(0.3, 1 - max(0.0, y - 1.5) / 7)
        bone = nearest_bone(c, list(SPINE_JOINTS))
        base = c + up * (q[1] * 0.95)
        d = (up - t * 0.8).normalized()
        b.blade(base, d, h * rnd.uniform(0.85, 1.1), t, 0.05 + h * 0.18, side, 0.03, HORN, {bone: 1.0})
        if -1.0 < y < 1.7:
            for s in (1, -1):
                a = 0.65
                nrm = (side * (s * math.sin(a)) + up * math.cos(a)).normalized()
                base2 = c + side * (s * math.sin(a) * q[0] * 0.9) + up * (math.cos(a) * q[1] * 0.9)
                d2 = (nrm * 0.8 - t * 0.9).normalized()
                b.blade(base2, d2, h * 0.6 * rnd.uniform(0.8, 1.1), t, 0.05, d2.cross(t), 0.02, HORN, {bone: 1.0})


# ---------------------------------------------------------------------------
# Skrzydła, pazury
# ---------------------------------------------------------------------------

def scallop(a: Vector, b_: Vector, toward: Vector, sag: float = 0.16, n: int = 6) -> list[Vector]:
    mid_dir = (toward - (a + b_) / 2).normalized()
    span = (a - b_).length
    return [a.lerp(b_, i / n) + mid_dir * (sag * span * math.sin(math.pi * i / n)) for i in range(n + 1)]


def billow(size: float):
    return lambda u, v: V(0, 0, -size * math.sin(math.pi * u) * math.sin(math.pi * v))


def build_wings(det: MeshBuilder, mem: MeshBuilder) -> None:
    for s, sfx in SIDES:
        W, E, S = (mx(ARM[k], s) for k in ("wrist", "elbow", "shoulder"))
        tips = [mx(t, s) for t in FINGER_TIPS]
        spars = []
        for k, tip in enumerate(tips):
            mid = W.lerp(tip, 0.45) + V(0, 0, 0.2)
            spars.append(catmull_rom([W, mid, tip], 4))
            det.tube([W, mid, tip], [0.1, 0.065, 0.02], 6, SCALES, {f"Finger{k + 1}.{sfx}": 1.0})
        lead0 = S + V(0, -0.15, 0.1)
        add_grid(mem, coons([lead0, S.lerp(W, 0.5) + V(0, -0.25, 0.12), W], [S, E, W], [lead0, S], [W, W], 8, 4,
                            billow(0.05)), MEMBRANE)
        for k in range(3):
            add_grid(mem, coons(spars[k], spars[k + 1], [W, W], scallop(tips[k], tips[k + 1], W), 8, 5,
                                billow(0.22)), MEMBRANE)
        flank = [WING_ROOT_BACK, V(0.72, 0.6, 2.3), V(0.62, -0.4, 2.75)]
        trail = scallop(tips[3], mx(WING_ROOT_BACK, s), W, 0.12, 8) + [mx(p, s) for p in flank[1:]] + [S]
        add_grid(mem, coons(spars[3], [W, E, S], [W, W], trail, 8, 7, billow(0.25)), MEMBRANE)
        # szpony "dłoni" na nadgarstku
        for k in range(3):
            dx = s * 0.09 * (k - 1)
            base = W + V(dx, -0.1, -0.05)
            path = [base, base + V(dx, -0.3, -0.05), base + V(dx * 1.6, -0.5, -0.35), base + V(dx * 2, -0.42, -0.72)]
            det.tube(path, [0.075, 0.06, 0.04, 0.0], 6, CLAW, {f"Thumb.{sfx}": 1.0})
        # ostroga na łokciu
        det.blade(E + V(0, 0.1, 0.1), V(s * 0.2, 1, 0.25), 0.45, V(1, 0, 0), 0.08, V(0, 0, 1), 0.04, HORN,
                  {f"UpperArm.{sfx}": 1.0})


def build_leg_claws(b: MeshBuilder) -> None:
    for s, sfx in SIDES:
        ball = mx(LEG["ball"], s)
        for k, tip in enumerate(TOE_TIPS + [BACK_TOE_TIP]):
            tip = mx(tip, s)
            d = tip - ball
            d.z = 0
            d.normalize()
            path = [tip - d * 0.04 + V(0, 0, 0.04), tip + d * 0.2, tip + d * 0.32 + V(0, 0, -0.08)]
            group = f"Foot.{sfx}" if k == 3 else f"Toes.{sfx}"
            b.tube(path, [0.075, 0.05, 0.0], 6, CLAW, {group: 1.0})


# ---------------------------------------------------------------------------
# Szkielet, wagi, animacje
# ---------------------------------------------------------------------------

def bone_defs() -> list[tuple[str, Vector, Vector, str | None, float]]:
    """(nazwa, head, tail, rodzic, skala_wpływu do wag)."""
    radius = {"Hips": 0.75, "Spine": 0.8, "Chest": 0.75, "Neck1": 0.55, "Neck2": 0.45, "Neck3": 0.4,
              "Neck4": 0.38, "Tail1": 0.55, "Tail2": 0.4, "Tail3": 0.3, "Tail4": 0.22, "Tail5": 0.15, "Tail6": 0.1}
    out = [(n, a, b, SPINE_PARENTS[n], radius[n]) for n, (a, b) in SPINE_JOINTS.items()]
    out.append(("Head", HEAD_ORIGIN, HEAD_ORIGIN + HEAD_FWD * HEAD_LEN, "Neck4", 0.4))
    out.append(("Jaw", jp(0, *JAW_HINGE), jp(0, 1.05, -0.13), "Head", 0.25))
    for s, sfx in SIDES:
        L = {k: mx(v, s) for k, v in LEG.items()}
        A = {k: mx(v, s) for k, v in ARM.items()}
        out += [
            (f"Thigh.{sfx}", L["hip"], L["knee"], "Hips", 0.6),
            (f"Shin.{sfx}", L["knee"], L["ankle"], f"Thigh.{sfx}", 0.3),
            (f"Foot.{sfx}", L["ankle"], L["ball"], f"Shin.{sfx}", 0.18),
            (f"Toes.{sfx}", L["ball"], L["ball"] + V(0, -0.45, 0), f"Foot.{sfx}", 0.12),
            (f"UpperArm.{sfx}", A["shoulder"], A["elbow"], "Chest", 0.42),
            (f"Forearm.{sfx}", A["elbow"], A["wrist"], f"UpperArm.{sfx}", 0.2),
            (f"Thumb.{sfx}", A["wrist"], A["wrist"] + THUMB_DIR * 0.5, f"Forearm.{sfx}", 0.15),
            (f"Hand.{sfx}", A["wrist"], A["wrist"] + (mx(FINGER_TIPS[0], s) - A["wrist"]).normalized() * 0.4,
             f"Forearm.{sfx}", 0.18),
        ]
        for k, tip in enumerate(FINGER_TIPS):
            out.append((f"Finger{k + 1}.{sfx}", A["wrist"], mx(tip, s), f"Hand.{sfx}", 0.5))
    return out


def build_armature(defs) -> bpy.types.Object:
    data = bpy.data.armatures.new("DragonRig")
    arm = bpy.data.objects.new("DragonRig", data)
    bpy.context.collection.objects.link(arm)
    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.view_layer.objects.active = arm
    arm.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    for name, head, tail, parent, _ in defs:
        eb = data.edit_bones.new(name)
        eb.head, eb.tail = head, tail
        d = (tail - head).normalized()
        eb.align_roll(V(0, 0, 1) if abs(d.z) < 0.8 else V(0, -1, 0))
        if parent:
            eb.parent = data.edit_bones[parent]
    bpy.ops.object.mode_set(mode="OBJECT")
    return arm


def skin(mesh_objs, arm, defs) -> bpy.types.Object:
    body, details, membrane = mesh_objs
    body_bones = [(n, a, b, r) for n, a, b, _, r in defs if not n.startswith(("Finger", "Jaw"))]
    assign_distance_weights(body, body_bones, top=3, power=4.0)
    wing_bones = [(n, a, b, 1.0) for n, a, b, _, r in defs
                  if n.startswith(("UpperArm", "Forearm", "Hand", "Finger")) or n in ("Chest", "Spine", "Hips")]
    assign_distance_weights(membrane, wing_bones, top=3, power=3.0)
    bpy.ops.object.select_all(action="DESELECT")
    for o in mesh_objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = body
    bpy.ops.object.join()
    dragon = bpy.context.view_layer.objects.active
    dragon.name = dragon.data.name = "Dragon"
    flat_shade(dragon)
    face_color_variation(dragon, amount=0.07, seed=SEED)
    dragon.parent = arm
    mod = dragon.modifiers.new("Armature", "ARMATURE")
    mod.object = arm
    return dragon


AX, AY, AZ = V(1, 0, 0), V(0, 1, 0), V(0, 0, 1)


def _local_quat(arm, bone: str, rots) -> Quaternion:
    rest = arm.data.bones[bone].matrix_local.to_3x3().inverted()
    q = Quaternion()
    for axis, angle in rots:
        q = q @ Quaternion((rest @ axis).normalized(), angle)
    return q


def make_action(arm, name: str, length: int, pose_fn, step: int = 2, loop: bool = True):
    """pose_fn(faza 0..1) -> ({kość: [(oś_świata, kąt)]}, {kość: przesunięcie_świata})."""
    action = bpy.data.actions.new(name)
    action.use_fake_user = True
    arm.animation_data_create()
    arm.animation_data.action = action
    frames_ = list(range(0, length + 1, step))
    if frames_[-1] != length:
        frames_.append(length)
    for fr in frames_:
        rots, locs = pose_fn(fr / length)
        for pb in arm.pose.bones:
            pb.rotation_mode = "QUATERNION"
            pb.rotation_quaternion = _local_quat(arm, pb.name, rots.get(pb.name, []))
            off = locs.get(pb.name)
            pb.location = (arm.data.bones[pb.name].matrix_local.to_3x3().inverted() @ off) if off else V(0, 0, 0)
            pb.keyframe_insert("rotation_quaternion", frame=fr + 1)
            pb.keyframe_insert("location", frame=fr + 1)
    track = arm.animation_data.nla_tracks.new()
    track.name = name
    track.strips.new(name, 1, action)
    arm.animation_data.action = None
    return action


def side_rot(sfx: str, axis: Vector, angle: float):
    """Obrót lustrzany: dla lewej strony odwracamy kąt wokół osi Y i Z."""
    if sfx == "L" and axis in (AY, AZ):
        angle = -angle
    return (axis, angle)


RIG: bpy.types.Object | None = None  # armatura dla funkcji pozujących (ustawiana w build_animations)


def aim_chain(targets: dict[str, Vector]) -> dict[str, list]:
    """Solver kierunków: {kość: docelowy kierunek w przestrzeni armatury} -> obroty względne
    (oś, kąt) w świecie dla make_action. Rodzice muszą występować przed dziećmi."""
    world: dict[str, Quaternion] = {}
    out = {}
    for name, target in targets.items():
        bone = RIG.data.bones[name]
        rest_dir = (bone.tail_local - bone.head_local).normalized()
        world[name] = rest_dir.rotation_difference(target.normalized())
        parent_w = world.get(bone.parent.name, Quaternion()) if bone.parent else Quaternion()
        axis, angle = (parent_w.inverted() @ world[name]).to_axis_angle()
        out[name] = [(axis, angle)]
    return out


def two_bone_ik(root: Vector, target: Vector, len_a: float, len_b: float, pole: Vector) -> Vector:
    """Pozycja stawu środkowego (łokcia) dla łańcucha 2 kości; pole = kierunek wygięcia."""
    d = target - root
    dist = min(d.length, (len_a + len_b) * 0.999)
    u = d.normalized()
    along = (len_a ** 2 - len_b ** 2 + dist ** 2) / (2 * dist)
    h = math.sqrt(max(0.0, len_a ** 2 - along ** 2))
    v = (pole - u * pole.dot(u)).normalized()
    return root + u * along + v * h


def planted_wing(s: int, sfx: str, wrist: Vector, body_off: Vector = V(0, 0, 0), breath: float = 0.0):
    """Skrzydło złożone, nadgarstek w punkcie `wrist` (świat), łokieć w górze i z tyłu."""
    S, E, W = (mx(ARM[k], s) for k in ("shoulder", "elbow", "wrist"))
    S = S + body_off
    elbow = two_bone_ik(S, wrist, (E - S).length, (W - E).length, V(0.55 * s, 0.9, 0.7 + breath))
    up_arm = (elbow - wrist).normalized()
    back, out = V(0, 1, 0), V(s, 0, 0)
    t = {
        f"UpperArm.{sfx}": elbow - S,
        f"Forearm.{sfx}": wrist - elbow,
        f"Thumb.{sfx}": Quaternion(V(1, 0, 0), -0.45) @ THUMB_DIR,
        f"Hand.{sfx}": up_arm + back * 0.2,
    }
    for k in range(4):
        t[f"Finger{k + 1}.{sfx}"] = up_arm * 0.8 + back * (0.7 + 0.35 * k) + out * 0.12 - V(0, 0, 0.1 * k)
    return aim_chain(t)


def standing_wings(breath: float = 0.0) -> dict[str, list]:
    """Wywerna stoi na złożonych skrzydłach: nadgarstki na ziemi, łokcie w górze i z tyłu,
    palce z błoną złożone wzdłuż ramienia, szpony skierowane do przodu w ziemię."""
    rots = {}
    for s, sfx in SIDES:
        rots.update(planted_wing(s, sfx, mx(WRIST_GROUND, s), breath=breath))
    return rots


def planted_leg(s: int, sfx: str, ball: Vector, body_off: Vector, toe_lift: float = 0.0):
    """Noga z IK: biodro (przesunięte z ciałem) -> kolano -> kostka -> śródstopie w punkcie `ball`."""
    L = {k: mx(v, s) for k, v in LEG.items()}
    hip = L["hip"] + body_off
    ankle = ball + (L["ankle"] - L["ball"])
    knee = two_bone_ik(hip, ankle, (L["knee"] - L["hip"]).length, (L["ankle"] - L["knee"]).length, V(0, -1, 0.2))
    return aim_chain({
        f"Thigh.{sfx}": knee - hip,
        f"Shin.{sfx}": ankle - knee,
        f"Foot.{sfx}": ball - ankle,
        f"Toes.{sfx}": V(0, -1, toe_lift),
    })


WALK_STRIDE = 1.6  # m na cykl
WALK_FRAMES = 32  # 24 fps -> 1.33 s -> 1.2 m/s przy speed_scale = 1
WALK_DUTY = 0.65


def step_offset(p: float) -> tuple[float, float]:
    """Faza kroku p∈[0,1) -> (przesunięcie wzdłuż Y względem ciała, uniesienie)."""
    p %= 1.0
    if p < WALK_DUTY:  # podparcie: stopa jedzie do tyłu względem ciała
        return -WALK_STRIDE / 2 + WALK_STRIDE * p / WALK_DUTY, 0.0
    q = (p - WALK_DUTY) / (1 - WALK_DUTY)
    smooth = q * q * (3 - 2 * q)
    return WALK_STRIDE / 2 - WALK_STRIDE * smooth, math.sin(math.pi * q)


def pose_walk(t: float):
    """Chód czworonożny (sekwencja boczna): lewa noga, lewe skrzydło, prawa noga, prawe skrzydło."""
    ph = 2 * math.pi * t
    body = V(0.04 * math.sin(ph), 0, -0.06 + 0.05 * math.cos(2 * ph))
    rots = {}
    phases = {"L": (0.0, 0.25), "R": (0.5, 0.75)}
    for s, sfx in SIDES:
        leg_p, wing_p = phases[sfx]
        dy, lift = step_offset(t + leg_p)
        ball = mx(LEG["ball"], s) + V(0, dy, 0.32 * lift)
        rots.update(planted_leg(s, sfx, ball, body, toe_lift=0.4 * lift))
        dy, lift = step_offset(t + wing_p)
        wrist = mx(WRIST_GROUND, s) + V(0, dy, 0.45 * lift)
        rots.update(planted_wing(s, sfx, wrist, body))
    rots.update({
        "Neck1": [(AX, 0.03 * math.cos(2 * ph))],
        "Neck2": [(AZ, 0.04 * math.sin(ph))],
        "Head": [(AX, -0.03 * math.cos(2 * ph + 0.6)), (AZ, -0.04 * math.sin(ph))],
    })
    for k in range(1, 7):
        rots[f"Tail{k}"] = [(AZ, 0.08 * math.sin(ph - k * 0.5)), (AX, 0.015 * math.cos(2 * ph - k * 0.4))]
    return rots, {"Hips": body}


def tucked_legs(rots: dict) -> None:
    for _, sfx in SIDES:
        rots[f"Thigh.{sfx}"] = [(AX, 1.55)]
        rots[f"Shin.{sfx}"] = [(AX, -0.5)]
        rots[f"Foot.{sfx}"] = [(AX, 0.9)]
        rots[f"Toes.{sfx}"] = [(AX, 0.6)]


def pose_fly(t: float):
    ph = 2 * math.pi * t
    rots, locs = {}, {}
    for _, sfx in SIDES:
        e1 = 0.62 * math.cos(ph)
        e2 = 0.32 * math.cos(ph - 0.7)
        e3 = 0.3 * math.cos(ph - 1.3)
        up_fold = max(0.0, -math.sin(ph))  # w ruchu w górę skrzydło lekko się składa
        rots[f"UpperArm.{sfx}"] = [side_rot(sfx, AY, -e1), side_rot(sfx, AZ, 0.12 * math.sin(ph))]
        rots[f"Forearm.{sfx}"] = [side_rot(sfx, AY, -e2), side_rot(sfx, AZ, 0.3 * up_fold)]
        rots[f"Hand.{sfx}"] = [side_rot(sfx, AY, -e3), side_rot(sfx, AZ, 0.35 * up_fold)]
        for k in range(1, 5):
            rots[f"Finger{k}.{sfx}"] = [side_rot(sfx, AY, -0.08 * math.cos(ph - 1.8))]
    tucked_legs(rots)
    for k in range(1, 7):
        rots[f"Tail{k}"] = [(AX, -0.05 + 0.06 * math.sin(ph - k * 0.55)), (AZ, 0.04 * math.sin(ph * 0.5 - k * 0.5))]
    rots["Spine"] = [(AX, 0.04 * math.sin(ph))]
    rots["Neck1"] = [(AX, -0.12)]
    rots["Neck2"] = [(AX, 0.03 * math.sin(ph - 0.8))]
    rots["Neck3"] = [(AX, 0.04 * math.sin(ph - 1.2))]
    rots["Head"] = [(AX, 0.05 * math.cos(ph) - 0.03)]  # głowa stabilizuje się względem kołysania ciała
    locs["Hips"] = V(0, 0, -0.18 * math.cos(ph))
    return rots, locs


def pose_takeoff(t: float):
    """Start: przysiad na tylnych łapach ze skrzydłami w górze (0–0.35), wybicie z łap
    i potężne machnięcie w dół (0.35–0.6), wyprost w locie (0.6–1)."""
    def ease(a: float, b: float) -> float:
        x = clampf01((t - a) / (b - a))
        return x * x * (3 - 2 * x)
    crouch = ease(0.0, 0.33) * (1.0 - ease(0.36, 0.46))
    leap = ease(0.33, 0.5) * (1.0 - ease(0.7, 1.0))
    stroke = ease(0.36, 0.58)  # 0 = skrzydła w górze, 1 = po uderzeniu w dół
    up_amount = ease(0.0, 0.3) * (1.0 - stroke)
    body = V(0, 0.2 * crouch, -0.75 * crouch + 0.55 * leap)
    rots = {}
    for s, sfx in SIDES:
        e1 = 1.05 * up_amount - 0.75 * stroke * (1.0 - ease(0.75, 1.0))
        e2 = 0.45 * up_amount - 0.35 * stroke * (1.0 - ease(0.75, 1.0))
        rots[f"UpperArm.{sfx}"] = [side_rot(sfx, AY, -e1), side_rot(sfx, AZ, -0.15 * up_amount)]
        rots[f"Forearm.{sfx}"] = [side_rot(sfx, AY, -e2)]
        rots[f"Hand.{sfx}"] = [side_rot(sfx, AY, -0.3 * up_amount + 0.25 * stroke)]
        if leap < 0.5:
            rots.update(planted_leg(s, sfx, mx(LEG["ball"], s), body))
        else:  # w powietrzu łapy się wyprostowują i podkulają
            k = (leap - 0.5) * 2
            rots[f"Thigh.{sfx}"] = [(AX, 1.2 * (1 - k) + 0.6 * k)]
            rots[f"Shin.{sfx}"] = [(AX, -0.2)]
            rots[f"Foot.{sfx}"] = [(AX, 0.8)]
            rots[f"Toes.{sfx}"] = [(AX, 0.6)]
    rots["Neck1"] = [(AX, 0.18 * crouch - 0.22 * leap)]
    rots["Neck2"] = [(AX, 0.08 * crouch - 0.1 * leap)]
    rots["Head"] = [(AX, -0.15 * crouch - 0.12 * leap)]
    rots["Jaw"] = [(AX, 0.25 * leap)]
    for k in range(1, 7):
        rots[f"Tail{k}"] = [(AX, 0.06 * crouch - 0.05 * leap)]
    return rots, {"Hips": body}


def clampf01(x: float) -> float:
    return max(0.0, min(1.0, x))


def pose_dive(t: float):
    """Nurkowanie: skrzydła złożone do tyłu wzdłuż ciała (jak sokół), łapy podkulone,
    szyja wyciągnięta, lekkie drżenie końcówek."""
    ph = 2 * math.pi * t
    rots = {}
    for s, sfx in SIDES:
        flutter = 0.04 * math.sin(ph * 2 + s)
        t_dirs = {
            f"UpperArm.{sfx}": V(0.75 * s, 0.55, 0.22),
            f"Forearm.{sfx}": V(0.5 * s, 0.86, 0.02),
            f"Thumb.{sfx}": Quaternion(V(1, 0, 0), 0.6) @ THUMB_DIR,
            f"Hand.{sfx}": V(0.22 * s, 1.0, 0.0),
        }
        for k in range(4):
            t_dirs[f"Finger{k + 1}.{sfx}"] = V((0.24 - 0.05 * k) * s, 1.0, -0.04 * k + flutter)
        rots.update(aim_chain(t_dirs))
    tucked_legs(rots)
    rots["Neck1"] = [(AX, -0.2)]
    rots["Neck2"] = [(AX, -0.05)]
    rots["Head"] = [(AX, 0.12 + 0.02 * math.sin(ph))]
    for k in range(1, 7):
        rots[f"Tail{k}"] = [(AX, -0.03), (AZ, 0.02 * math.sin(ph - k * 0.6))]
    return rots, {}


def pose_glide(t: float):
    ph = 2 * math.pi * t
    rots = {}
    for _, sfx in SIDES:
        rots[f"UpperArm.{sfx}"] = [side_rot(sfx, AY, -0.14 - 0.04 * math.sin(ph)), side_rot(sfx, AZ, 0.08)]
        rots[f"Forearm.{sfx}"] = [side_rot(sfx, AY, 0.06 + 0.03 * math.sin(ph - 0.6))]
        rots[f"Hand.{sfx}"] = [side_rot(sfx, AY, 0.05 * math.sin(ph - 1.2))]
    tucked_legs(rots)
    for k in range(1, 7):
        rots[f"Tail{k}"] = [(AX, -0.04), (AZ, 0.06 * math.sin(ph - k * 0.5))]
    rots["Neck1"] = [(AX, -0.14)]
    rots["Neck2"] = [(AZ, 0.08 * math.sin(ph * 0.5))]
    rots["Neck3"] = [(AZ, 0.06 * math.sin(ph * 0.5 - 0.6))]
    rots["Head"] = [(AX, 0.04), (AZ, 0.05 * math.sin(ph * 0.5 - 1.2))]
    rots["Spine"] = [(AY, 0.04 * math.sin(ph))]  # lekkie przechylanie
    return rots, {"Hips": V(0, 0, 0.06 * math.sin(ph))}


def pose_idle(t: float):
    ph = 2 * math.pi * t
    breath = math.sin(ph * 3)  # 3 oddechy na cykl
    look = math.sin(ph)  # powolne rozglądanie się
    rots = standing_wings(0.03 * breath)
    rots.update({
        "Chest": [(AX, 0.008 * breath)],
        "Neck1": [(AX, 0.03 * math.sin(ph * 3 + 0.5))],
        "Neck2": [(AX, 0.03 * math.sin(ph * 3 + 1.0)), (AZ, 0.12 * look)],
        "Neck3": [(AZ, 0.1 * math.sin(ph - 0.4))],
        "Head": [(AX, -0.04 * math.sin(ph * 3 + 1.6)), (AZ, 0.12 * math.sin(ph - 0.8)),
                 (AY, 0.06 * math.sin(ph * 2))],
        "Jaw": [(AX, 0.03 * max(0.0, math.sin(ph * 3 - 1.0)))],  # lekkie dyszenie
    })
    for k in range(1, 7):
        rots[f"Tail{k}"] = [(AZ, 0.09 * math.sin(ph * 2 - k * 0.6)), (AX, 0.02 * math.sin(ph * 3 - k * 0.4))]
    return rots, {"Hips": V(0, 0, 0.02 * breath)}


def pose_roar(t: float):
    # 0 -> 0.25 zamach (głowa w górę), 0.25 -> 0.45 wyrzut, 0.45 -> 0.8 ryk, 0.8 -> 1 powrót
    def env(a, b, c, d):
        if t < a or t > d:
            return 0.0
        if t < b:
            return (1 - math.cos(math.pi * (t - a) / (b - a))) / 2
        if t <= c:
            return 1.0
        return (1 + math.cos(math.pi * (t - c) / (d - c))) / 2
    up = env(0.0, 0.22, 0.25, 0.42)
    roar = env(0.25, 0.42, 0.8, 1.0)
    shake = 0.03 * math.sin(2 * math.pi * t * 14) * roar
    rots = {
        "Neck1": [(AX, -0.12 * up + 0.12 * roar)], "Neck2": [(AX, -0.15 * up + 0.12 * roar)],
        "Neck3": [(AX, -0.1 * up + 0.1 * roar + shake)], "Neck4": [(AX, 0.08 * roar)],
        "Head": [(AX, -0.3 * up - 0.5 * roar + shake)], "Jaw": [(AX, 0.1 * up + 0.78 * roar)],
        "Chest": [(AX, 0.06 * roar - 0.04 * up)],
    }
    for _, sfx in SIDES:
        rots[f"UpperArm.{sfx}"] = [side_rot(sfx, AY, -0.25 * up - 0.4 * roar), side_rot(sfx, AZ, -0.15 * roar)]
        rots[f"Forearm.{sfx}"] = [side_rot(sfx, AY, 0.2 * roar)]
        for k in range(1, 5):
            rots[f"Finger{k}.{sfx}"] = [side_rot(sfx, AY, 0.06 * roar * math.sin(2 * math.pi * t * 10 + k))]
        rots[f"Thigh.{sfx}"] = [(AX, -0.35 * roar)]
        rots[f"Shin.{sfx}"] = [(AX, 0.55 * roar)]
        rots[f"Foot.{sfx}"] = [(AX, -0.2 * roar)]
    for k in range(1, 7):
        rots[f"Tail{k}"] = [(AX, 0.06 * roar), (AZ, 0.07 * roar * math.sin(2 * math.pi * t * 3 - k))]
    return rots, {"Hips": V(0, 0, -0.32 * roar)}


def build_animations(arm) -> None:
    global RIG
    RIG = arm
    make_action(arm, "Idle", 144, pose_idle)
    make_action(arm, "Glide", 96, pose_glide)
    make_action(arm, "Dive", 24, pose_dive)
    make_action(arm, "TakeOff", 24, pose_takeoff, step=1, loop=False)
    make_action(arm, "Walk", WALK_FRAMES, pose_walk)
    make_action(arm, "Fly", 36, pose_fly)
    make_action(arm, "Roar", 60, pose_roar, loop=False)


# ---------------------------------------------------------------------------
# Złożenie, podgląd
# ---------------------------------------------------------------------------

def build_all():
    common.reset_scene()
    random.seed(SEED)
    mats = make_materials()
    body = build_body(mats)
    print(f"Tułów: {tri_count(body)} trójkątów")
    det = MeshBuilder(MAT_NAMES)
    build_head(det)
    build_frill(det)
    build_back_spikes(det)
    build_leg_claws(det)
    mem = MeshBuilder(MAT_NAMES)
    build_wings(det, mem)
    details = det.to_object("DragonDetails", mats)
    membrane = mem.to_object("DragonMembrane", mats)
    print(f"Detale: {tri_count(details)}, błona: {tri_count(membrane)} trójkątów")
    defs = bone_defs()
    arm = build_armature(defs)
    dragon = skin((body, details, membrane), arm, defs)
    print(f"Smok: {tri_count(dragon)} trójkątów, {len(dragon.data.vertices)} wierzchołków, {len(defs)} kości")
    build_animations(arm)
    return dragon, arm


def export(arm, dragon, path: pathlib.Path) -> None:
    bpy.ops.object.select_all(action="DESELECT")
    arm.select_set(True)
    dragon.select_set(True)
    bpy.context.view_layer.objects.active = arm
    path.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=str(path), export_format="GLB", use_selection=True, export_yup=True,
                              export_apply=False, export_skins=True, export_animations=True,
                              export_animation_mode="NLA_TRACKS", export_force_sampling=True,
                              export_vertex_color="MATERIAL")
    print(f"Wyeksportowano: {path}")


def pose_at(arm, action_name: str, frame: int) -> None:
    for tr in arm.animation_data.nla_tracks:
        tr.mute = tr.name != action_name
    bpy.context.scene.frame_set(frame)


def preview(out_dir: pathlib.Path):
    shots = {
        "ref": dict(target=(0, -1.6, 2.4), distance=12.5, azimuth_deg=-62, elevation_deg=6),
        "side": dict(target=(0, 1.2, 2.0), distance=17, azimuth_deg=-90, elevation_deg=4),
        "top": dict(target=(0, 1.0, 2.0), distance=20, azimuth_deg=0, elevation_deg=89),
        "front": dict(target=(0, -1.0, 2.4), distance=16, azimuth_deg=0, elevation_deg=10),
        "head": dict(target=(0, -3.6, 2.9), distance=4.5, azimuth_deg=-55, elevation_deg=8),
    }
    for name, kw in shots.items():
        common.render_preview(out_dir / f"dragon_{name}.png", resolution=(960, 600), exposure=2.2, background=(0.3, 0.3, 0.3), **kw)


if __name__ == "__main__":
    dragon, arm = build_all()
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if "--preview" in argv:
        out = pathlib.Path(argv[argv.index("--preview") + 1]).resolve()
        pose_at(arm, "", 1)
        preview(out)
        for anim, frame in (("Idle", 1), ("Fly", 1), ("Fly", 19), ("Roar", 30)):
            pose_at(arm, anim, frame)
            common.render_preview(out / f"pose_{anim}_{frame}.png", resolution=(960, 600), exposure=2.2,
                                  background=(0.3, 0.3, 0.3), target=(0, 0.5, 2.4), distance=17,
                                  azimuth_deg=-55, elevation_deg=15)
        for tr in arm.animation_data.nla_tracks:
            tr.mute = False
    export(arm, dragon, common.MODELS_DIR / "dragon.glb")
