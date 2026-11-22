"""Narzędzia do proceduralnego modelowania: splajny, lofty, rury, płaty Coonsa,
kolce, budowanie siatek z grupami wierzchołków i wagami do szkieletu.

Konwencja: Z w górę, przód modelu = -Y (Blender), X = prawa strona modelu.
"""

from __future__ import annotations

import math
import random

import bmesh
import bpy
from mathutils import Vector

# --------------------------------------------------------------------------
# Krzywe
# --------------------------------------------------------------------------


def vec(p) -> Vector:
    return p.copy() if isinstance(p, Vector) else Vector(p)


def catmull_rom(points, samples_per_seg: int = 6) -> list[Vector]:
    """Splajn Catmull-Rom przez punkty (dowolny wymiar wektorów)."""
    pts = [vec(p) for p in points]
    if len(pts) < 2:
        return pts
    ext = [pts[0] * 2 - pts[1]] + pts + [pts[-1] * 2 - pts[-2]]
    out = []
    for i in range(1, len(ext) - 2):
        p0, p1, p2, p3 = ext[i - 1], ext[i], ext[i + 1], ext[i + 2]
        for s in range(samples_per_seg):
            t = s / samples_per_seg
            t2, t3 = t * t, t * t * t
            out.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2
                              + (-p0 + 3 * p1 - 3 * p2 + p3) * t3))
    out.append(pts[-1].copy())
    return out


def polyline_length(pts) -> float:
    return sum((pts[i + 1] - pts[i]).length for i in range(len(pts) - 1))


def polyline_at(pts, t: float) -> Vector:
    """Punkt na łamanej dla parametru t∈[0,1] (wg długości łuku)."""
    pts = [vec(p) for p in pts]
    if len(pts) == 1:
        return pts[0].copy()
    total = polyline_length(pts)
    target = max(0.0, min(1.0, t)) * total
    acc = 0.0
    for i in range(len(pts) - 1):
        seg = (pts[i + 1] - pts[i]).length
        if acc + seg >= target or i == len(pts) - 2:
            k = 0.0 if seg == 0 else (target - acc) / seg
            return pts[i].lerp(pts[i + 1], min(1.0, k))
        acc += seg
    return pts[-1].copy()


def resample(pts, n: int) -> list[Vector]:
    return [polyline_at(pts, i / (n - 1)) for i in range(n)]


def frames(points, up_hint=(0, 0, 1)):
    """Dla każdego punktu ścieżki: (styczna, bok, góra)."""
    up_hint = vec(up_hint).normalized()
    out = []
    n = len(points)
    for i in range(n):
        a = points[max(0, i - 1)]
        b = points[min(n - 1, i + 1)]
        t = (b - a).normalized()
        side = up_hint.cross(t)
        if side.length < 1e-4:
            side = Vector((1, 0, 0)).cross(t)
        side.normalize()
        up = t.cross(side).normalized()
        out.append((t, side, up))
    return out


# --------------------------------------------------------------------------
# Profile przekrojów
# --------------------------------------------------------------------------


def ellipse_profile(n: int, w: float, ht: float, hb: float, ridge: float = 0.0,
                    keel: float = 0.0) -> list[tuple[float, float]]:
    """Przekrój (bok, góra): elipsa z osobną wysokością góry i dołu,
    opcjonalnym grzbietem (ridge) i stępką (keel). Start na górze, zgodnie z zegarem."""
    pts = []
    for i in range(n):
        a = 2 * math.pi * i / n
        x = w * math.sin(a)
        c = math.cos(a)
        z = (ht if c > 0 else hb) * c
        if c > 0:
            z += ridge * c ** 10
        else:
            z -= keel * (-c) ** 6
        pts.append((x, z))
    return pts


def mirror_half_profile(half):
    """Pół-profil [(x, z, mat), ...] od środka góry do środka dołu (x>=0)
    -> pełny pierścień punktów i materiałów krawędzi."""
    n = len(half) - 1
    pts = [(h[0], h[1]) for h in half]
    mats = [h[2] for h in half[:-1]]
    for i in range(n - 1, 0, -1):
        pts.append((-half[i][0], half[i][1]))
    # krawędzie lustrzane: od mirror(i) do mirror(i-1) mają materiał half[i-1]
    mirrored = [half[i - 1][2] for i in range(n, 0, -1)]
    return pts, mats + mirrored


# --------------------------------------------------------------------------
# Budowniczy siatki
# --------------------------------------------------------------------------


def _is_point(r) -> bool:
    return isinstance(r, Vector) or (isinstance(r, tuple) and len(r) == 3
                                     and all(isinstance(c, (int, float)) for c in r))


def lerp_list(values, t: float) -> float:
    """Interpolacja liniowa po liście wartości dla t∈[0,1]."""
    if len(values) == 1:
        return values[0]
    x = max(0.0, min(1.0, t)) * (len(values) - 1)
    i = min(int(x), len(values) - 2)
    return values[i] + (values[i + 1] - values[i]) * (x - i)


class MeshBuilder:
    """Zbiera wierzchołki, ściany, materiały ścian i wagi grup wierzchołków."""

    def __init__(self, materials: list[str]):
        self.materials = materials
        self.verts: list[Vector] = []
        self.faces: list[tuple[int, ...]] = []
        self.face_mats: list[int] = []
        self.groups: list[dict[str, float]] = []

    def _mat(self, m) -> int:
        return m if isinstance(m, int) else self.materials.index(m)

    def add_vert(self, p, groups=None) -> int:
        self.verts.append(vec(p))
        self.groups.append(dict(groups or {}))
        return len(self.verts) - 1

    def add_face(self, idx, mat) -> None:
        idx = tuple(idx)
        if len(set(idx)) < 3:
            return
        self.faces.append(idx)
        self.face_mats.append(self._mat(mat))

    def loft(self, rings, mats, groups=None, cap_start=True, cap_end=True,
             cap_mat=None) -> list[list[int]]:
        """rings: lista pierścieni (listy punktów, równa liczba) lub pojedynczych
        punktów (czubek). mats: materiał lub lista materiałów krawędzi pierścienia.
        groups: dict lub funkcja (punkt) -> dict."""
        idx_rings = []
        for ring in rings:
            if _is_point(ring):
                ring = [ring]
            ids = []
            for p in ring:
                g = groups(vec(p)) if callable(groups) else groups
                ids.append(self.add_vert(p, g))
            idx_rings.append(ids)
        n = max(len(r) for r in idx_rings)
        if not isinstance(mats, (list, tuple)):
            mats = [mats] * n
        cap_mat = cap_mat if cap_mat is not None else mats[0]
        for a, b in zip(idx_rings, idx_rings[1:]):
            if len(a) == 1 and len(b) == 1:
                continue
            if len(a) == 1:
                for j in range(n):
                    self.add_face((a[0], b[(j + 1) % n], b[j]), mats[j])
            elif len(b) == 1:
                for j in range(n):
                    self.add_face((a[j], a[(j + 1) % n], b[0]), mats[j])
            else:
                for j in range(n):
                    self.add_face((a[j], a[(j + 1) % n], b[(j + 1) % n], b[j]), mats[j])
        if cap_start and len(idx_rings[0]) > 2:
            self.add_face(list(reversed(idx_rings[0])), cap_mat)
        if cap_end and len(idx_rings[-1]) > 2:
            self.add_face(idx_rings[-1], cap_mat)
        return idx_rings

    def tube(self, path, radii, sides: int, mat, groups=None, up_hint=(0, 0, 1),
             tip: bool = True, flatten: float = 1.0, twist: float = 0.0, samples: int = 4):
        """Rura po krzywej (Catmull-Rom) z promieniami interpolowanymi wzdłuż;
        gdy tip=True, kończy się ostrym czubkiem."""
        pts = catmull_rom(path, samples) if len(path) > 2 else [vec(p) for p in path]
        if len(path) == 2:
            pts = [vec(path[0]).lerp(vec(path[1]), i / samples) for i in range(samples + 1)]
        n = len(pts)
        fr = frames(pts, up_hint)
        rings = []
        last = n - 1 if tip else n
        for i in range(last):
            t = i / (n - 1)
            r = lerp_list(radii, t)
            _, side, up = fr[i]
            ring = []
            for k in range(sides):
                a = 2 * math.pi * k / sides + twist
                ring.append(pts[i] + side * (math.sin(a) * r) + up * (math.cos(a) * r * flatten))
            rings.append(ring)
        if tip:
            rings.append(pts[-1])
        return self.loft(rings, mat, groups, cap_start=True, cap_end=not tip)

    def blade(self, base, direction, length, width_dir, width, thick_dir, thick, mat, groups=None,
              bend=None):
        """Płaski kolec/łuska: podstawa (szerokość wzdłuż width_dir), czubek w kierunku
        direction, grubość wzdłuż thick_dir. bend: wektor wygięcia czubka."""
        base, d = vec(base), vec(direction).normalized()
        wd, td = vec(width_dir).normalized(), vec(thick_dir).normalized()
        tip = base + d * length + (vec(bend) if bend is not None else Vector())
        b1 = self.add_vert(base + wd * width, groups)
        b2 = self.add_vert(base - wd * width, groups)
        r1 = self.add_vert(base + td * thick + d * length * 0.25, groups)
        r2 = self.add_vert(base - td * thick + d * length * 0.25, groups)
        t = self.add_vert(tip, groups)
        for f in ((b1, r1, t), (r1, b2, t), (b2, r2, t), (r2, b1, t), (b1, b2, r1), (b2, b1, r2)):
            self.add_face(f, mat)

    def blade2(self, base, direction, length, width_dir, width, thick_dir, thick, mat, tip_mat,
               groups=None, split: float = 0.55, bend=None):
        """Kolec dwukolorowy: podstawa w `mat`, czubek w `tip_mat`."""
        base, d = vec(base), vec(direction).normalized()
        wd, td = vec(width_dir).normalized(), vec(thick_dir).normalized()
        tip = base + d * length + (vec(bend) if bend is not None else Vector())
        mid = base.lerp(tip, split)
        k = 1.0 - split * 0.8
        ring0 = [base + wd * width, base + td * thick + d * (length * 0.12), base - wd * width,
                 base - td * thick + d * (length * 0.12)]
        ring1 = [mid + wd * (width * k), mid + td * (thick * k), mid - wd * (width * k), mid - td * (thick * k)]
        self.loft([ring0, ring1], mat, groups, cap_start=True, cap_end=False)
        self.loft([ring1, tip], tip_mat, groups, cap_start=False, cap_end=False)

    def to_object(self, name: str, mat_objs: dict[str, bpy.types.Material]) -> bpy.types.Object:
        mesh = bpy.data.meshes.new(name)
        mesh.from_pydata(self.verts, [], self.faces)
        mesh.update()
        for m in self.materials:
            mesh.materials.append(mat_objs[m])
        for poly, mi in zip(mesh.polygons, self.face_mats):
            poly.material_index = mi
        obj = bpy.data.objects.new(name, mesh)
        bpy.context.collection.objects.link(obj)
        names = sorted({g for gs in self.groups for g in gs})
        vgs = {g: obj.vertex_groups.new(name=g) for g in names}
        for i, gs in enumerate(self.groups):
            for g, w in gs.items():
                vgs[g].add([i], w, "REPLACE")
        fix_normals(obj)
        return obj


def fix_normals(obj) -> None:
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(obj.data)
    bm.free()


# --------------------------------------------------------------------------
# Płaty (membrany skrzydeł)
# --------------------------------------------------------------------------


def coons(c0, c1, d0, d1, nu: int, nv: int, offset=None):
    """Płat Coonsa. c0(u)=S(u,0), c1(u)=S(u,1), d0(v)=S(0,v), d1(v)=S(1,v) – łamane.
    Zwraca siatkę punktów [v][u]. offset(u, v) -> Vector (np. wybrzuszenie)."""
    p00, p10 = polyline_at(c0, 0), polyline_at(c0, 1)
    p01, p11 = polyline_at(c1, 0), polyline_at(c1, 1)
    grid = []
    for j in range(nv + 1):
        v = j / nv
        row = []
        for i in range(nu + 1):
            u = i / nu
            p = ((1 - v) * polyline_at(c0, u) + v * polyline_at(c1, u)
                 + (1 - u) * polyline_at(d0, v) + u * polyline_at(d1, v)
                 - ((1 - u) * (1 - v) * p00 + u * (1 - v) * p10 + (1 - u) * v * p01 + u * v * p11))
            if offset:
                p = p + offset(u, v)
            row.append(p)
        grid.append(row)
    return grid


def add_grid(builder: MeshBuilder, grid, mat, groups=None) -> None:
    ids = [[builder.add_vert(p, groups(p) if callable(groups) else groups) for p in row] for row in grid]
    for j in range(len(ids) - 1):
        for i in range(len(ids[0]) - 1):
            a, b, c, d = ids[j][i], ids[j][i + 1], ids[j + 1][i + 1], ids[j + 1][i]
            # przekątna naprzemiennie = ładniejsza triangulacja
            if (i + j) % 2:
                builder.add_face((a, b, c), mat)
                builder.add_face((a, c, d), mat)
            else:
                builder.add_face((a, b, d), mat)
                builder.add_face((b, c, d), mat)


# --------------------------------------------------------------------------
# Wagi do szkieletu
# --------------------------------------------------------------------------


def seg_distance(p: Vector, a: Vector, b: Vector) -> float:
    ab = b - a
    t = 0.0 if ab.length_squared == 0 else max(0.0, min(1.0, (p - a).dot(ab) / ab.length_squared))
    return (p - (a + ab * t)).length


def distance_weights(p: Vector, bones, top: int = 3, power: float = 4.0) -> dict[str, float]:
    """bones: [(nazwa, head, tail, skala_wpływu)]. Wagi odwrotnie proporcjonalne
    do (odległość/skala)^power, top-N kości, znormalizowane."""
    scored = []
    for name, a, b, scale in bones:
        d = seg_distance(p, a, b) / scale
        scored.append((d, name))
    scored.sort()
    scored = scored[:top]
    ws = [(1.0 / (d ** power + 1e-6), n) for d, n in scored]
    total = sum(w for w, _ in ws)
    out = {n: w / total for w, n in ws if w / total > 0.02}
    total = sum(out.values())
    return {n: w / total for n, w in out.items()}


def assign_distance_weights(obj, bones, top: int = 3, power: float = 4.0) -> None:
    for vg in list(obj.vertex_groups):
        obj.vertex_groups.remove(vg)
    vgs = {b[0]: obj.vertex_groups.new(name=b[0]) for b in bones}
    mw = obj.matrix_world
    for v in obj.data.vertices:
        for name, w in distance_weights(mw @ v.co, bones, top, power).items():
            vgs[name].add([v.index], w, "REPLACE")


# --------------------------------------------------------------------------
# Wykończenie
# --------------------------------------------------------------------------


def face_color_variation(obj, amount: float = 0.08, seed: int = 1, name: str = "Col") -> None:
    """Losowa jasność per ściana (atrybut koloru) – efekt "ręcznie ciosanego" low-poly."""
    rnd = random.Random(seed)
    mesh = obj.data
    attr = mesh.color_attributes.new(name=name, type="BYTE_COLOR", domain="CORNER")
    for poly in mesh.polygons:
        f = 1.0 - rnd.uniform(0.0, 2 * amount)
        for li in poly.loop_indices:
            attr.data[li].color = (f, f, f, 1.0)


def flat_shade(obj) -> None:
    for p in obj.data.polygons:
        p.use_smooth = False


def tri_count(obj) -> int:
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)
