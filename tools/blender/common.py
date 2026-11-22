"""Wspólne helpery do generowania assetów w Blenderze (bpy, tryb headless).

Konwencje (patrz CLAUDE.md):
- 1 jednostka Blendera = 1 metr w Godocie.
- Model "patrzy" w -Y w Blenderze -> po eksporcie glTF patrzy w +Z,
  czyli zgodnie z Godot `Vector3.MODEL_FRONT`.
- Pivot (origin) na ziemi, pod środkiem modelu.
"""

from __future__ import annotations

import math
import pathlib
import sys

import bpy
import bmesh
from mathutils import Vector

REPO_ROOT = pathlib.Path(__file__).resolve().parents[2]
MODELS_DIR = REPO_ROOT / "assets" / "models"


def reset_scene() -> None:
    """Czyści domyślną scenę (kostka, kamera, światło) i osierocone dane."""
    bpy.ops.wm.read_factory_settings(use_empty=True)


def material(name: str, color: tuple[float, float, float], roughness: float = 0.8,
             metallic: float = 0.0, emission: float = 0.0) -> bpy.types.Material:
    """Prosty materiał PBR z jednolitym kolorem (styl low-poly / flat)."""
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    if emission > 0:
        bsdf.inputs["Emission Color"].default_value = (*color, 1.0)
        bsdf.inputs["Emission Strength"].default_value = emission
    mat.diffuse_color = (*color, 1.0)
    return mat


def assign(obj: bpy.types.Object, mat: bpy.types.Material) -> bpy.types.Object:
    obj.data.materials.clear()
    obj.data.materials.append(mat)
    return obj


def _active() -> bpy.types.Object:
    return bpy.context.view_layer.objects.active


def ico(name: str, radius: float, loc, scale=(1, 1, 1), subdiv: int = 1) -> bpy.types.Object:
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=subdiv, radius=radius, location=loc)
    obj = _active()
    obj.name = name
    obj.scale = scale
    return obj


def cone(name: str, r1: float, r2: float, depth: float, loc, rot=(0, 0, 0),
         verts: int = 6) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r1, radius2=r2, depth=depth,
                                    location=loc, rotation=rot)
    obj = _active()
    obj.name = name
    return obj


def segment(name: str, start, end, r1: float, r2: float, verts: int = 6) -> bpy.types.Object:
    """Stożek ścięty rozpięty między dwoma punktami (kości, szyja, ogon, nogi)."""
    start, end = Vector(start), Vector(end)
    direction = end - start
    obj = cone(name, r1, r2, direction.length, (start + end) / 2, verts=verts)
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = direction.to_track_quat("Z", "Y")
    return obj


def poly_mesh(name: str, verts: list, faces: list, thickness: float = 0.0) -> bpy.types.Object:
    """Siatka z listy wierzchołków i ścian (np. błona skrzydła)."""
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata([Vector(v) for v in verts], [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    if thickness > 0:
        mod = obj.modifiers.new("Solidify", "SOLIDIFY")
        mod.thickness = thickness
        mod.offset = 0
    return obj


def join(name: str, objects: list[bpy.types.Object]) -> bpy.types.Object:
    """Aplikuje modyfikatory i transformacje, łączy w jeden obiekt z flat shadingiem."""
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        for mod in list(obj.modifiers):
            bpy.ops.object.modifier_apply(modifier=mod.name)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    bpy.ops.object.join()
    result = _active()
    result.name = name
    result.data.name = name
    # Flat shading = wyraźne ścianki low-poly.
    for poly in result.data.polygons:
        poly.use_smooth = False
    bm = bmesh.new()
    bm.from_mesh(result.data)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(result.data)
    bm.free()
    return result


def stats(obj: bpy.types.Object) -> str:
    mesh = obj.data
    tris = sum(len(p.vertices) - 2 for p in mesh.polygons)
    return f"{obj.name}: {len(mesh.vertices)} wierzchołków, {tris} trójkątów, {len(mesh.materials)} materiałów"


def export_glb(path: pathlib.Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=str(path), export_format="GLB", export_yup=True,
                              export_apply=True)
    print(f"Wyeksportowano: {path.relative_to(REPO_ROOT)}")


def render_preview(path: pathlib.Path, target=(0, 0, 1), distance: float = 8.0,
                   azimuth_deg: float = 35.0, elevation_deg: float = 20.0,
                   resolution=(800, 600)) -> None:
    """Szybki render podglądowy (Workbench, CPU) do weryfikacji wizualnej."""
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "MATERIAL"
    scene.display.shading.show_shadows = True
    scene.render.resolution_x, scene.render.resolution_y = resolution
    scene.render.film_transparent = False
    world = bpy.data.worlds.get("World") or bpy.data.worlds.new("World")
    world.color = (0.55, 0.7, 0.85)
    scene.world = world

    az, el = math.radians(azimuth_deg), math.radians(elevation_deg)
    target = Vector(target)
    # Kamera z przodu-boku (model patrzy w -Y).
    offset = Vector((math.sin(az) * math.cos(el), -math.cos(az) * math.cos(el), math.sin(el)))
    cam_data = bpy.data.cameras.new("PreviewCam")
    cam = bpy.data.objects.new("PreviewCam", cam_data)
    bpy.context.collection.objects.link(cam)
    cam.location = target + offset * distance
    cam.rotation_mode = "QUATERNION"
    cam.rotation_quaternion = (target - cam.location).to_track_quat("-Z", "Y")
    scene.camera = cam

    path.parent.mkdir(parents=True, exist_ok=True)
    scene.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)
    bpy.data.objects.remove(cam)
    print(f"Podgląd: {path}")


def preview_path_from_argv() -> pathlib.Path | None:
    """`python gen_x.py -- --preview /tmp/x.png` -> ścieżka podglądu."""
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    if "--preview" in argv:
        return pathlib.Path(argv[argv.index("--preview") + 1]).resolve()
    return None
