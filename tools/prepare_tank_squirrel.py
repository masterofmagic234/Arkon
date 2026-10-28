#!/usr/bin/env python3
"""Prepare the supplied Tripo tank for mobile, preserving its weighted rig.

Run with Python 3 + Pillow and Blender 4.3.2 on PATH. No network calls.
The original attachment is kept byte-for-byte under characters/source.
"""
from __future__ import annotations
import argparse
import io
import json
from pathlib import Path
import shutil
import struct
import subprocess
import sys


def blender_step(source: str, output: str) -> None:
    import bpy
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    bpy.ops.import_scene.gltf(filepath=source)
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH" and o.name != "Icosphere"]
    armatures = [o for o in bpy.context.scene.objects if o.type == "ARMATURE"]
    for obj in meshes:
        bpy.context.view_layer.objects.active = obj
        # glTF splits coincident positions at UV/normal seams. Collapse on
        # disconnected islands opens cracks; weld positions while retaining
        # per-corner UV coordinates and vertex weights before simplification.
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.mesh.remove_doubles(threshold=0.000001)
        bpy.ops.mesh.normals_make_consistent(inside=False)
        bpy.ops.object.mode_set(mode="OBJECT")
        if obj.data.has_custom_normals:
            bpy.ops.mesh.customdata_custom_splitnormals_clear()
        for face in obj.data.polygons:
            face.use_smooth = True
        modifier = obj.modifiers.new(name="Mobile silhouette budget", type="DECIMATE")
        # Keep the supplied silhouette and the elbow/knee loops. The former
        # 0.38 reduction damaged the fur fringe and left very coarse joints.
        modifier.ratio = 0.68
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    for image in bpy.data.images:
        if image.source == "FILE" and max(image.size) > 1024:
            image.scale(1024, 1024)
            image.pack()
    bpy.ops.object.select_all(action="DESELECT")
    for obj in meshes + armatures:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = armatures[0] if armatures else meshes[0]
    bpy.ops.export_scene.gltf(
        filepath=output, export_format="GLB", use_selection=True,
        export_apply=False, export_animations=False, export_materials="EXPORT",
        export_texcoords=True, export_normals=True, export_image_format="AUTO",
        export_yup=True, export_skins=True,
    )


def compact_images(path: Path) -> dict:
    from PIL import Image
    data = path.read_bytes()
    json_length, _ = struct.unpack_from("<II", data, 12)
    document = json.loads(data[20:20 + json_length])
    binary_start = 28 + json_length
    images = {image["bufferView"]: image for image in document.get("images", [])}
    binary = bytearray()
    for index, view in enumerate(document["bufferViews"]):
        start = binary_start + view.get("byteOffset", 0)
        payload = data[start:start + view["byteLength"]]
        if index in images:
            image = Image.open(io.BytesIO(payload)).convert("RGB")
            stream = io.BytesIO()
            image.save(stream, format="JPEG", quality=94, optimize=True, subsampling=0)
            payload = stream.getvalue()
            images[index]["mimeType"] = "image/jpeg"
        binary.extend(b"\0" * (-len(binary) % 4))
        view["byteOffset"] = len(binary)
        view["byteLength"] = len(payload)
        binary.extend(payload)
    document["buffers"][0]["byteLength"] = len(binary)
    binary.extend(b"\0" * (-len(binary) % 4))
    encoded = json.dumps(document, separators=(",", ":")).encode()
    encoded += b" " * (-len(encoded) % 4)
    length = 12 + 8 + len(encoded) + 8 + len(binary)
    result = struct.pack("<III", 1179937895, 2, length)
    result += struct.pack("<II", len(encoded), 1313821514) + encoded
    result += struct.pack("<II", len(binary), 5130562) + binary
    path.write_bytes(result)
    return document


def main() -> None:
    root = Path(__file__).resolve().parents[1]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=root / "assets/level1/characters/source/tank_original.glb")
    parser.add_argument("--output", type=Path, default=root / "assets/level1/characters/tank_squirrel.glb")
    args = parser.parse_args()
    blender = shutil.which("blender")
    if not blender:
        parser.error("Blender must be on PATH")
    if not args.source.is_file():
        parser.error(f"Missing source: {args.source}")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    expression = (
        f"import runpy; runpy.run_path({str(Path(__file__).resolve())!r})"
        f"['blender_step']({str(args.source.resolve())!r}, {str(args.output.resolve())!r})"
    )
    subprocess.run([blender, "-b", "-t", "4", "--python-expr", expression], check=True)
    document = compact_images(args.output)
    # Preserve all original weighted joints, repair the misplaced tail skin,
    # and add the complete offline animation library used by the game.
    from prepare_squirrel_rigs import complete_tank
    complete_tank(args.output)
    raw = args.output.read_bytes()
    json_length, _ = struct.unpack_from("<II", raw, 12)
    document = json.loads(raw[20:20 + json_length])
    triangles = sum(document["accessors"][primitive["indices"]]["count"] // 3
                    for mesh in document["meshes"] for primitive in mesh["primitives"])
    print(json.dumps({"output": str(args.output), "triangles": triangles,
                      "bones": len(document["skins"][0]["joints"]), "bytes": args.output.stat().st_size}))


if __name__ == "__main__":
    main()
