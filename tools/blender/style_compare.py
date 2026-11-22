"""Renderuje tego samego smoka w 3 stylach: low-poly, voxel, smooth/kreskówkowy.

    .venv-tools/bin/python tools/blender/style_compare.py -- --out docs/img
"""

import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))

import bpy  # noqa: E402
from mathutils.bvhtree import BVHTree  # noqa: E402

import gen_dragon_placeholder  # noqa: E402
from common import render_preview  # noqa: E402


def out_dir() -> pathlib.Path:
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    return pathlib.Path(argv[argv.index("--out") + 1] if "--out" in argv else "build/style").resolve()


def transfer_materials(src: bpy.types.Object, dst: bpy.types.Object) -> None:
    """Remesh gubi przypisanie materiałów — odtwarzamy je z najbliższej ściany oryginału."""
    bvh = BVHTree.FromObject(src, bpy.context.evaluated_depsgraph_get())
    for mat in src.data.materials:
        dst.data.materials.append(mat)
    for poly in dst.data.polygons:
        _, _, idx, _ = bvh.find_nearest(poly.center)
        if idx is not None:
            poly.material_index = src.data.polygons[idx].material_index


def variant(style: str, path: pathlib.Path) -> None:
    dragon = gen_dragon_placeholder.build()
    if style == "voxel":
        src = dragon.copy()
        src.data = dragon.data.copy()
        bpy.context.collection.objects.link(src)
        mod = dragon.modifiers.new("Voxel", "REMESH")
        mod.mode = "BLOCKS"
        mod.octree_depth = 7
        mod.scale = 0.9
        mod.use_remove_disconnected = False
        bpy.context.view_layer.objects.active = dragon
        bpy.ops.object.modifier_apply(modifier="Voxel")
        dragon.data.materials.clear()
        transfer_materials(src, dragon)
        bpy.data.objects.remove(src)
    elif style == "smooth":
        mod = dragon.modifiers.new("Subsurf", "SUBSURF")
        mod.levels = mod.render_levels = 2
        for poly in dragon.data.polygons:
            poly.use_smooth = True
    render_preview(path, target=(0, 0.6, 1.5), distance=11.0, resolution=(640, 480))


if __name__ == "__main__":
    out = out_dir()
    for style in ("lowpoly", "voxel", "smooth"):
        variant(style, out / f"style_{style}.png")
