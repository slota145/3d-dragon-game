"""Legowisko smoka: skalne wzgórze z jaskinią (tunel + komora), gniazdo i świecące kryształy.

    .venv-tools/bin/python tools/blender/gen_lair.py                  # -> assets/models/lair.glb
    .venv-tools/bin/python tools/blender/gen_lair.py -- --preview DIR  # + rendery

Konwencje: Z w górę, wejście do jaskini od -Y (w Godocie +Z), pivot = środek komory na ziemi
(tam jest gniazdo), 1 j. = 1 m. Jaskinia mieści dorosłego smoka (wejście ~15 m szerokości,
~10 m wysokości, komora ~34 m średnicy). Podłoga to ziemia świata (Y = 0) przykryta
płatem „Lair_Floor”; kolizję (trimesh) tworzy gra ze skały „Lair_Rock”.
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
from gen_animals import blob, export, make_materials  # noqa: E402
from meshkit import MeshBuilder, face_color_variation, flat_shade, tri_count  # noqa: E402

# kolory liniowe (Blender) — ok. 0.15 liniowo ≈ 0.42 sRGB
PALETTE = {
    "Lair_Rock": (0.085, 0.065, 0.05),
    "Lair_Floor": (0.075, 0.06, 0.045),
    "Lair_Nest": (0.36, 0.26, 0.12),
    "Lair_Stone": (0.12, 0.11, 0.1),
}
CRYSTAL = (0.25, 0.7, 1.0)

CHAMBER_R = 17.0      # promień komory (poziomo)
CHAMBER_H = 13.0      # wysokość kopuły
TUNNEL_R = 7.5        # promień łuku tunelu
TUNNEL_Z = 2.5        # środek łuku nad ziemią -> sklepienie na ~10 m
HILL = (42.0, 40.0, 30.0)
HILL_Z = -6.0


def face(b: MeshBuilder, pts, mat: str) -> None:
    b.add_face([b.add_vert(p) for p in pts], mat)


def apply_all(obj) -> None:
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    for mod in list(obj.modifiers):
        bpy.ops.object.modifier_apply(modifier=mod.name)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)


def craggy(obj, amount: float, freq: float, seed: int) -> None:
    """Skalne „wybrzuszenia”: przesunięcie wierzchołków wzdłuż kierunku od środka (szum)."""
    off = Vector((seed * 13.1, seed * 7.7, seed * 3.3))
    for v in obj.data.vertices:
        p = v.co
        n = noise.noise(p * freq + off) + 0.5 * noise.noise(p * freq * 2.3 + off)
        d = Vector((p.x, p.y, p.z * 0.6)).normalized()
        v.co = p + d * n * amount


def build_rock() -> bpy.types.Object:
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=5, radius=1.0, location=(0, 4.0, HILL_Z))
    hill = bpy.context.view_layer.objects.active
    hill.name = "Lair_Rock"
    hill.data.name = "Lair_Rock"
    hill.scale = HILL
    apply_all(hill)
    craggy(hill, 9.0, 0.035, 1)   # duże garby i turnie zamiast gładkiej kopuły
    craggy(hill, 2.5, 0.12, 4)    # drobne skalne załomy

    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=4, radius=1.0, location=(0, 0, -2.0))
    chamber = bpy.context.view_layer.objects.active
    chamber.scale = (CHAMBER_R, CHAMBER_R, CHAMBER_H + 2.0)
    apply_all(chamber)
    craggy(chamber, 1.6, 0.15, 2)

    bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=TUNNEL_R, depth=50.0,
                                        location=(0, -CHAMBER_R - 10.0, TUNNEL_Z),
                                        rotation=(math.radians(90), 0, 0))
    tunnel = bpy.context.view_layer.objects.active
    tunnel.scale = (1.05, 1.0, 1.0)
    apply_all(tunnel)
    craggy(tunnel, 0.9, 0.2, 3)

    for cutter in (chamber, tunnel):
        mod = hill.modifiers.new("cut", "BOOLEAN")
        mod.operation = "DIFFERENCE"
        mod.solver = "EXACT"
        mod.object = cutter
        apply_all(hill)
        bpy.data.objects.remove(cutter)

    # usuń wszystko głęboko pod ziemią (niewidoczne) — mniej trójkątów i prostsza kolizja
    bm = bmesh.new()
    bm.from_mesh(hill.data)
    bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], plane_co=(0, 0, -1.5),
                           plane_no=(0, 0, 1), clear_inner=True)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(hill.data)
    bm.free()

    dec = hill.modifiers.new("dec", "DECIMATE")
    dec.ratio = 0.6
    apply_all(hill)
    return hill


def build_floor(mats) -> bpy.types.Object:
    """Ciemna, ubita podłoga jaskini (komora + tunel) tuż nad ziemią świata."""
    b = MeshBuilder(["Lair_Floor"])
    rnd = random.Random(5)
    n = 20
    pts = []
    for i in range(n):  # obrys komory od wejścia dookoła
        a = -math.pi / 2 + 0.42 + (2 * math.pi - 0.84) * i / (n - 1)
        r = CHAMBER_R * 0.97 * rnd.uniform(0.95, 1.02)
        pts.append(Vector((math.cos(a) * r, math.sin(a) * r, 0.03)))
    w = TUNNEL_R * 0.95
    pts += [Vector((-w, -CHAMBER_R - 12.0, 0.03)), Vector((w, -CHAMBER_R - 12.0, 0.03))]
    # wachlarz z punktu środka (wypukły obrys komory + tunel)
    c = Vector((0, 0, 0.03))
    ring = pts[-1:] + pts
    for i in range(len(ring) - 1):
        face(b, [c, ring[i], ring[i + 1]], "Lair_Floor")
    face(b, [c, pts[-2], pts[-1]], "Lair_Floor")
    obj = b.to_object("Lair_Floor", mats)
    return obj


def build_nest(mats) -> bpy.types.Object:
    """Gniazdo w środku komory: pierścień kamieni i wyściółka z suchych traw."""
    b = MeshBuilder(["Lair_Stone", "Lair_Nest"])
    rnd = random.Random(7)
    for i in range(14):
        a = i / 14 * math.tau + rnd.uniform(-0.1, 0.1)
        r = 3.0 + rnd.uniform(-0.2, 0.3)
        s = rnd.uniform(0.25, 0.42)
        blob(b, (math.cos(a) * r, math.sin(a) * r, s * 0.45), (s, s * 0.9, s * 0.65), "Lair_Stone",
             seg=6, rings=4, jitter=0.15, rnd=rnd)
    # wyściółka: płaska, postrzępiona mata (pisklę stoi na niej, więc nisko)
    blob(b, (0, 0, -0.02), (2.7, 2.7, 0.1), "Lair_Nest", seg=12, rings=4, jitter=0.12, rnd=rnd)
    for i in range(10):  # wystające źdźbła / gałązki na brzegu
        a = rnd.uniform(0, math.tau)
        r = rnd.uniform(2.3, 2.8)
        blob(b, (math.cos(a) * r, math.sin(a) * r, 0.1), (0.9, 0.1, 0.08), "Lair_Nest", seg=4, rings=2)
    obj = b.to_object("Lair_Nest", mats)
    obj.rotation_euler.z = 0.3
    return obj


def build_crystals(mats) -> bpy.types.Object:
    """Świecące kryształy na ścianach komory (klimat + orientacja w ciemnej jaskini)."""
    mats = dict(mats)
    mats["Lair_Crystal"] = common.material("Lair_Crystal", CRYSTAL, roughness=0.3, emission=1.2)
    mat = "Lair_Crystal"
    b = MeshBuilder([mat])
    rnd = random.Random(11)
    for i in range(9):
        a = rnd.uniform(-math.pi / 2 + 0.9, 1.5 * math.pi - 0.9)  # z dala od wejścia (-Y = kąt 1.5π)
        base = Vector((math.cos(a) * (CHAMBER_R - 1.0), math.sin(a) * (CHAMBER_R - 1.0), rnd.uniform(0.0, 4.0)))
        for k in range(rnd.randint(2, 4)):
            d = (Vector((-math.cos(a), -math.sin(a), 1.6)) + Vector((rnd.uniform(-.5, .5), rnd.uniform(-.5, .5), 0)))
            d.normalize()
            h = rnd.uniform(1.2, 3.0)
            r = h * 0.16
            side = d.cross(Vector((0, 0, 1))).normalized()
            up = side.cross(d).normalized()
            ring = [base + (side * math.cos(t) + up * math.sin(t)) * r for t in (0, 2.1, 4.2)]
            tip = base + d * h
            for j in range(3):
                face(b, [ring[j], ring[(j + 1) % 3], tip], mat)
    obj = b.to_object("Lair_Crystal", mats)
    return obj


def build() -> list[bpy.types.Object]:
    common.reset_scene()
    mats = make_materials(PALETTE)
    rock = build_rock()
    common.assign(rock, mats["Lair_Rock"])
    face_color_variation(rock, 0.1, seed=1)
    flat_shade(rock)
    floor = build_floor(mats)
    nest = build_nest(mats)
    crystals = build_crystals(mats)
    objs = [rock, floor, nest, crystals]
    for o in objs[1:]:
        if not o.data.color_attributes.get("Col"):
            face_color_variation(o, 0.08, seed=3)
        flat_shade(o)
    for o in objs:
        print(f"{o.name}: {tri_count(o)} trójkątów")
    return objs


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    preview = pathlib.Path(argv[argv.index("--preview") + 1]).resolve() if "--preview" in argv else None
    objs = build()
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    path = common.MODELS_DIR / "lair.glb"
    bpy.ops.export_scene.gltf(filepath=str(path), export_format="GLB", use_selection=True, export_yup=True,
                              export_vertex_color="MATERIAL")
    print(f"Wyeksportowano: {path}")
    if preview:
        common.render_preview(preview / "lair_front.png", target=(0, -10, 6), distance=110, azimuth_deg=-25,
                              elevation_deg=18, resolution=(900, 600))
        common.render_preview(preview / "lair_inside.png", target=(0, 2, 2), distance=14, azimuth_deg=10,
                              elevation_deg=25, resolution=(900, 600))
