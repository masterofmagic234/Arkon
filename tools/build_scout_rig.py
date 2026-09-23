#!/usr/bin/env python3
"""Build a lightweight, genuinely skinned Scout GLB for ACORN HUNTER.

The source Meshy asset is intentionally unrigged. This tool:
1. exports a clean glTF mesh from the source using trimesh;
2. keeps one 1K base-color texture;
3. adds a 25-bone animal skeleton;
4. generates 4-influence skin weights;
5. embeds lightweight skeletal animation clips.
"""

from __future__ import annotations

import io
import json
import math
import struct
from pathlib import Path

import numpy as np
import trimesh
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "Meshy_AI_Acorn_Guardian_0923182156_texture (1).glb"
OUT = ROOT / "scout_rigged.glb"


def parse_glb(blob: bytes) -> tuple[dict, bytearray]:
    magic, version, total = struct.unpack_from("<4sII", blob, 0)
    if magic != b"glTF" or version != 2 or total > len(blob):
        raise RuntimeError("Invalid glTF 2.0 GLB")

    offset = 12
    gltf = None
    binary = None
    while offset < total:
        size, kind = struct.unpack_from("<II", blob, offset)
        offset += 8
        chunk = blob[offset:offset + size]
        offset += size
        if kind == 0x4E4F534A:
            gltf = json.loads(chunk.decode("utf-8"))
        elif kind == 0x004E4942:
            binary = bytearray(chunk)

    if gltf is None or binary is None:
        raise RuntimeError("GLB is missing JSON or BIN chunk")
    return gltf, binary


def write_glb(gltf: dict, binary: bytearray) -> None:
    while len(binary) % 4:
        binary.append(0)

    json_bytes = json.dumps(
        gltf, separators=(",", ":"), ensure_ascii=False
    ).encode("utf-8")
    while len(json_bytes) % 4:
        json_bytes += b" "

    total = 12 + 8 + len(json_bytes) + 8 + len(binary)
    blob = (
        struct.pack("<4sII", b"glTF", 2, total)
        + struct.pack("<II", len(json_bytes), 0x4E4F534A)
        + json_bytes
        + struct.pack("<II", len(binary), 0x004E4942)
        + bytes(binary)
    )
    OUT.write_bytes(blob)


def align4(binary: bytearray) -> None:
    while len(binary) % 4:
        binary.append(0)


def append_blob(binary: bytearray, blob: bytes) -> tuple[int, int]:
    align4(binary)
    offset = len(binary)
    binary.extend(blob)
    return offset, len(blob)


def add_view(gltf: dict, offset: int, length: int, target: int | None = None) -> int:
    view = {"buffer": 0, "byteOffset": offset, "byteLength": length}
    if target is not None:
        view["target"] = target
    gltf["bufferViews"].append(view)
    return len(gltf["bufferViews"]) - 1


def add_accessor(
    gltf: dict,
    view: int,
    component_type: int,
    count: int,
    accessor_type: str,
    normalized: bool = False,
) -> int:
    gltf["accessors"].append(
        {
            "bufferView": view,
            "byteOffset": 0,
            "componentType": component_type,
            "normalized": normalized,
            "count": count,
            "type": accessor_type,
        }
    )
    return len(gltf["accessors"]) - 1


def quat_axis(axis: tuple[float, float, float], angle: float) -> np.ndarray:
    a = np.asarray(axis, dtype=np.float64)
    a /= np.linalg.norm(a)
    h = angle * 0.5
    s = math.sin(h)
    return np.array([a[0] * s, a[1] * s, a[2] * s, math.cos(h)], dtype=np.float32)


def quat_mul(a: np.ndarray, b: np.ndarray) -> np.ndarray:
    x1, y1, z1, w1 = [float(x) for x in a]
    x2, y2, z2, w2 = [float(x) for x in b]
    return np.array(
        [
            w1 * x2 + x1 * w2 + y1 * z2 - z1 * y2,
            w1 * y2 - x1 * z2 + y1 * w2 + z1 * x2,
            w1 * z2 + x1 * y2 - y1 * x2 + z1 * w2,
            w1 * w2 - x1 * x2 - y1 * y2 - z1 * z2,
        ],
        dtype=np.float32,
    )


def quat_xyz(rx: float, ry: float, rz: float) -> np.ndarray:
    return quat_mul(
        quat_mul(quat_axis((1, 0, 0), rx), quat_axis((0, 1, 0), ry)),
        quat_axis((0, 0, 1), rz),
    )


BONES = [
    ("root", None, (0.00, -0.28, 0.00)),
    ("pelvis", 0, (0.00, 0.24, 0.02)),
    ("spine", 1, (0.00, 0.22, 0.00)),
    ("chest", 2, (0.00, 0.24, 0.00)),
    ("neck", 3, (0.00, 0.22, -0.01)),
    ("head", 4, (0.00, 0.20, -0.02)),
    ("jaw", 5, (0.00, -0.13, -0.11)),
    ("ear.L", 5, (-0.17, 0.13, 0.00)),
    ("ear.R", 5, (0.17, 0.13, 0.00)),
    ("arm.upper.L", 3, (-0.25, 0.05, -0.01)),
    ("arm.fore.L", 9, (-0.13, -0.22, -0.01)),
    ("hand.L", 10, (0.00, -0.17, -0.02)),
    ("arm.upper.R", 3, (0.25, 0.05, -0.01)),
    ("arm.fore.R", 12, (0.13, -0.22, -0.01)),
    ("hand.R", 13, (0.00, -0.17, -0.02)),
    ("leg.thigh.L", 1, (-0.17, -0.27, 0.00)),
    ("leg.shin.L", 15, (-0.03, -0.25, -0.02)),
    ("foot.L", 16, (0.00, -0.13, -0.10)),
    ("leg.thigh.R", 1, (0.17, -0.27, 0.00)),
    ("leg.shin.R", 18, (0.03, -0.25, -0.02)),
    ("foot.R", 19, (0.00, -0.13, -0.10)),
    ("tail.01", 1, (0.00, 0.03, 0.22)),
    ("tail.02", 21, (0.10, 0.10, 0.24)),
    ("tail.03", 22, (0.02, 0.15, 0.22)),
    ("tail.04", 23, (-0.09, 0.13, 0.15)),
]
BONE_INDEX = {name: i for i, (name, _, _) in enumerate(BONES)}


def bone_globals() -> tuple[np.ndarray, list[tuple[float, float, float]]]:
    raw_globals: list[np.ndarray] = []
    for _, parent, local in BONES:
        local_v = np.asarray(local, dtype=np.float32)
        parent_pos = raw_globals[parent] if parent is not None else np.zeros(3, dtype=np.float32)
        raw_globals.append(parent_pos + local_v)

    raw = np.asarray(raw_globals, dtype=np.float32)
    min_y = float(raw[:, 1].min())
    max_y = float(raw[:, 1].max())
    raw_height = max_y - min_y
    if raw_height <= 1e-5:
        raise RuntimeError("Scout skeleton has invalid height")

    skeleton_scale = 1.85 / raw_height
    globals_ = raw * skeleton_scale
    globals_[:, 1] -= min_y * skeleton_scale

    locals_: list[tuple[float, float, float]] = []
    for i, (_, parent, _) in enumerate(BONES):
        pos = globals_[i] if parent is None else globals_[i] - globals_[parent]
        locals_.append(tuple(float(x) for x in pos))
    return globals_, locals_


def segment_distance_sq(point: np.ndarray, a: np.ndarray, b: np.ndarray) -> float:
    ab = b - a
    denom = float(np.dot(ab, ab))
    if denom < 1e-8:
        d = point - a
        return float(np.dot(d, d))
    t = float(np.dot(point - a, ab) / denom)
    t = max(0.0, min(1.0, t))
    q = a + t * ab
    d = point - q
    return float(np.dot(d, d))


def make_skin_weights(vertices: np.ndarray, globals_: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    segments = []
    for i, (_, parent, _) in enumerate(BONES):
        a = globals_[parent] if parent is not None else globals_[i]
        b = globals_[i]
        segments.append((a, b))

    joints = np.zeros((len(vertices), 4), dtype=np.uint8)
    weights = np.zeros((len(vertices), 4), dtype=np.float32)

    def choose(candidates: list[int], point: np.ndarray) -> tuple[list[int], np.ndarray]:
        score = np.array(
            [1.0 / (0.012 + segment_distance_sq(point, *segments[i])) for i in candidates],
            dtype=np.float64,
        )
        score[0] *= 1.15
        take = np.argsort(score)[-min(4, len(score)):][::-1]
        selected = [candidates[int(i)] for i in take]
        selected_w = score[take]
        selected_w /= selected_w.sum()
        return selected, selected_w

    for vertex_i, point in enumerate(vertices):
        x, y, z = [float(q) for q in point]

        if y > 1.20:
            candidates = [
                BONE_INDEX["neck"], BONE_INDEX["head"],
                BONE_INDEX["jaw"],
                BONE_INDEX["ear.L"] if x < 0.0 else BONE_INDEX["ear.R"]
            ]
            selected, selected_w = choose(candidates, point)
            joints[vertex_i, :len(selected)] = selected[:4]
            weights[vertex_i, :len(selected)] = selected_w[:4]
            continue

        if z > 0.34 and y > 0.28 and abs(x) < 0.55:
            candidates = [
                BONE_INDEX["tail.01"], BONE_INDEX["tail.02"],
                BONE_INDEX["tail.03"], BONE_INDEX["tail.04"],
                BONE_INDEX["pelvis"]
            ]
            selected, selected_w = choose(candidates, point)
            selected_w = selected_w * np.array(
                [1.0 if int(b) != BONE_INDEX["pelvis"] else 0.25 for b in selected],
                dtype=np.float64,
            )
            selected_w /= selected_w.sum()
            joints[vertex_i, :len(selected)] = selected[:4]
            weights[vertex_i, :len(selected)] = selected_w[:4]
            continue

        if abs(x) > 0.34 and y > 0.45:
            candidates = (
                [BONE_INDEX["arm.upper.L"], BONE_INDEX["arm.fore.L"], BONE_INDEX["hand.L"]]
                if x < 0.0
                else [BONE_INDEX["arm.upper.R"], BONE_INDEX["arm.fore.R"], BONE_INDEX["hand.R"]]
            )
            selected, selected_w = choose(candidates, point)
            joints[vertex_i, :len(selected)] = selected[:4]
            weights[vertex_i, :len(selected)] = selected_w[:4]
            continue

        if y < 0.52 and abs(x) > 0.13:
            candidates = (
                [BONE_INDEX["leg.thigh.L"], BONE_INDEX["leg.shin.L"], BONE_INDEX["foot.L"]]
                if x < 0.0
                else [BONE_INDEX["leg.thigh.R"], BONE_INDEX["leg.shin.R"], BONE_INDEX["foot.R"]]
            )
            selected, selected_w = choose(candidates, point)
            joints[vertex_i, :len(selected)] = selected[:4]
            weights[vertex_i, :len(selected)] = selected_w[:4]
            continue

        # Rigid torso: one pelvis influence deliberately prevents belly wobble.
        joints[vertex_i, 0] = BONE_INDEX["pelvis"]
        weights[vertex_i, 0] = 1.0

    return joints, weights


def make_pose(kind: str, t: float) -> np.ndarray:
    identity = np.array([0, 0, 0, 1], dtype=np.float32)
    q = [identity.copy() for _ in BONES]
    phase = 2.0 * math.pi * t
    s = math.sin(phase)
    s2 = math.sin(2.0 * phase)
    bi = BONE_INDEX

    if kind == "idle":
        q[bi["spine"]] = quat_xyz(0.025 * s, 0, 0)
        q[bi["chest"]] = quat_xyz(0.015 * s, 0, 0)
        q[bi["head"]] = quat_xyz(0, 0, 0.018 * s)

    elif kind in ("walk", "run"):
        leg_amp = 0.42 if kind == "walk" else 0.60
        arm_amp = 0.26 if kind == "walk" else 0.40
        q[bi["leg.thigh.L"]] = quat_xyz(leg_amp * s2, 0, 0)
        q[bi["leg.thigh.R"]] = quat_xyz(-leg_amp * s2, 0, 0)
        q[bi["leg.shin.L"]] = quat_xyz(-0.16 * max(0.0, -s2), 0, 0)
        q[bi["leg.shin.R"]] = quat_xyz(0.16 * max(0.0, s2), 0, 0)
        q[bi["arm.upper.L"]] = quat_xyz(-arm_amp * s2, 0, 0)
        q[bi["arm.upper.R"]] = quat_xyz(arm_amp * s2, 0, 0)
        q[bi["arm.fore.L"]] = quat_xyz(0.10 * max(0.0, s2), 0, 0)
        q[bi["arm.fore.R"]] = quat_xyz(-0.10 * max(0.0, -s2), 0, 0)
        q[bi["spine"]] = identity.copy()
        q[bi["chest"]] = identity.copy()
        q[bi["head"]] = identity.copy()

    elif kind == "hit":
        e = math.sin(max(0.0, min(1.0, t)) * math.pi)
        q[bi["spine"]] = quat_xyz(math.radians(-12) * e, 0, 0)
        q[bi["chest"]] = quat_xyz(math.radians(-15) * e, 0, 0)
        q[bi["head"]] = quat_xyz(math.radians(-10) * e, 0, 0)
        q[bi["arm.upper.L"]] = quat_xyz(math.radians(22) * e, 0, math.radians(-8) * e)
        q[bi["arm.upper.R"]] = quat_xyz(math.radians(22) * e, 0, math.radians(8) * e)

    elif kind == "defeat":
        e = 1.0 - math.cos(max(0.0, min(1.0, t)) * math.pi * 0.5)
        q[bi["spine"]] = quat_xyz(math.radians(-25) * e, 0, 0)
        q[bi["chest"]] = quat_xyz(math.radians(-28) * e, 0, 0)
        q[bi["head"]] = quat_xyz(math.radians(-18) * e, 0, 0)
        q[bi["arm.upper.L"]] = quat_xyz(math.radians(32) * e, 0, math.radians(-14) * e)
        q[bi["arm.upper.R"]] = quat_xyz(math.radians(32) * e, 0, math.radians(14) * e)
        q[bi["leg.thigh.L"]] = quat_xyz(math.radians(-18) * e, 0, 0)
        q[bi["leg.thigh.R"]] = quat_xyz(math.radians(-10) * e, 0, 0)

    elif kind == "box1":
        j = math.sin(phase)
        q[bi["spine"]] = quat_xyz(0, math.radians(8) * j, 0)
        q[bi["arm.upper.L"]] = quat_xyz(math.radians(-24) * j, math.radians(-18) * j, 0)
        q[bi["arm.upper.R"]] = quat_xyz(math.radians(24) * j, math.radians(18) * j, 0)

    elif kind == "box2":
        j = math.sin(phase)
        q[bi["spine"]] = quat_xyz(0, math.radians(-8) * j, 0)
        q[bi["arm.upper.L"]] = quat_xyz(math.radians(20) * j, math.radians(18) * j, 0)
        q[bi["arm.upper.R"]] = quat_xyz(math.radians(-20) * j, math.radians(-18) * j, 0)

    # Tail motion is intentionally conservative to avoid over-deforming the mesh.
    tail_amp = 0.08 if kind in ("walk", "run") else 0.045
    for name, factor in (
        ("tail.01", 1.0), ("tail.02", 1.15), ("tail.03", 1.0), ("tail.04", 0.85)
    ):
        q[bi[name]] = quat_xyz(tail_amp * factor * s, 0, tail_amp * 0.75 * factor * s)

    return np.stack(q)


def add_animation(
    gltf: dict,
    binary: bytearray,
    bone_nodes: list[int],
    name: str,
    duration: float,
    kind: str,
) -> None:
    times = np.asarray([0.0, duration * 0.5, duration], dtype="<f4")
    to, tl = append_blob(binary, times.tobytes())
    ta = add_accessor(gltf, add_view(gltf, to, tl), 5126, 3, "SCALAR")

    samplers = []
    channels = []
    poses = [make_pose(kind, t) for t in (0.0, 0.5, 1.0)]

    for bone_i, node_i in enumerate(bone_nodes):
        rotations = np.asarray([p[bone_i] for p in poses], dtype="<f4")
        oo, ol = append_blob(binary, rotations.tobytes())
        oa = add_accessor(gltf, add_view(gltf, oo, ol), 5126, 3, "VEC4")
        sampler_i = len(samplers)
        samplers.append(
            {"input": ta, "output": oa, "interpolation": "LINEAR"}
        )
        channels.append(
            {"sampler": sampler_i, "target": {"node": node_i, "path": "rotation"}}
        )

    gltf.setdefault("animations", []).append(
        {"name": name, "samplers": samplers, "channels": channels}
    )


def build() -> None:
    if not SRC.exists():
        raise RuntimeError(f"Missing Scout source: {SRC}")

    source_scene = trimesh.load(str(SRC), force="scene")
    if not source_scene.geometry:
        raise RuntimeError("Scout source has no geometry")

    source_mesh = next(iter(source_scene.geometry.values()))
    vertices = np.asarray(source_mesh.vertices, dtype=np.float32).copy()
    faces = np.asarray(source_mesh.faces, dtype=np.uint32)

    if len(vertices) == 0 or len(faces) == 0:
        raise RuntimeError("Scout source mesh is empty")

    # Normalize the source mesh into the same 1.85-unit animal space used by the rig.
    mesh_min = vertices.min(axis=0)
    mesh_max = vertices.max(axis=0)
    mesh_height = float(mesh_max[1] - mesh_min[1])
    if mesh_height <= 1e-5:
        raise RuntimeError("Scout source mesh has invalid height")

    mesh_scale = 1.85 / mesh_height
    mesh_center_x = (float(mesh_min[0]) + float(mesh_max[0])) * 0.5
    mesh_center_z = (float(mesh_min[2]) + float(mesh_max[2])) * 0.5
    vertices[:, 0] = (vertices[:, 0] - mesh_center_x) * mesh_scale
    vertices[:, 1] = (vertices[:, 1] - float(mesh_min[1])) * mesh_scale
    vertices[:, 2] = (vertices[:, 2] - mesh_center_z) * mesh_scale

    source_image = source_mesh.visual.material._data.get("baseColorTexture")
    if source_image is None:
        raise RuntimeError("Scout source has no base-color texture")

    source_image = source_image.convert("RGB").copy()
    source_image.thumbnail((1024, 1024), Image.Resampling.LANCZOS)

    material = trimesh.visual.material.PBRMaterial(
        name="ScoutMat",
        baseColorTexture=source_image,
        metallicFactor=0.0,
        roughnessFactor=0.82,
        doubleSided=True,
    )
    visual = trimesh.visual.texture.TextureVisuals(
        uv=np.asarray(source_mesh.visual.uv, dtype=np.float32),
        material=material,
    )
    clean_mesh = trimesh.Trimesh(
        vertices=vertices,
        faces=faces,
        vertex_normals=np.asarray(source_mesh.vertex_normals, dtype=np.float32),
        visual=visual,
        process=False,
    )

    base_gltf_blob = trimesh.exchange.gltf.export_glb(
        clean_mesh, include_normals=True
    )
    gltf, source_binary = parse_glb(base_gltf_blob)

    # Rebuild the original buffer views so the 1K image is stored as JPEG.
    rebuilt = bytearray()
    remapped_views = []
    image_view_index = int(gltf["images"][0]["bufferView"])
    for view_index, view in enumerate(gltf["bufferViews"]):
        raw = source_binary[
            view["byteOffset"]:view["byteOffset"] + view["byteLength"]
        ]
        if view_index == image_view_index:
            image_io = io.BytesIO()
            source_image.save(image_io, format="JPEG", quality=72, optimize=True)
            raw = image_io.getvalue()

            gltf["images"][0]["mimeType"] = "image/jpeg"

        align4(rebuilt)
        new_offset = len(rebuilt)
        rebuilt.extend(raw)

        new_view = {"buffer": 0, "byteOffset": new_offset, "byteLength": len(raw)}
        if "target" in view:
            new_view["target"] = view["target"]
        if "byteStride" in view:
            new_view["byteStride"] = view["byteStride"]
        remapped_views.append(new_view)

    gltf["bufferViews"] = remapped_views
    binary = rebuilt

    globals_, local_transforms = bone_globals()
    joints, weights = make_skin_weights(vertices, globals_)

    jo, jl = append_blob(binary, joints.astype(np.uint8).tobytes())
    jo_view = add_view(gltf, jo, jl, 34962)
    jo_accessor = add_accessor(gltf, jo_view, 5121, len(vertices), "VEC4")

    wo, wl = append_blob(binary, weights.astype("<f4").tobytes())
    wo_view = add_view(gltf, wo, wl, 34962)
    wo_accessor = add_accessor(gltf, wo_view, 5126, len(vertices), "VEC4")

    primitive = gltf["meshes"][0]["primitives"][0]
    primitive["attributes"]["JOINTS_0"] = jo_accessor
    primitive["attributes"]["WEIGHTS_0"] = wo_accessor

    bone_nodes: list[int] = []
    for bone_i, (name, parent, _) in enumerate(BONES):
        node_i = len(gltf["nodes"])
        gltf["nodes"].append(
            {
                "name": name,
                "translation": list(local_transforms[bone_i]),
            }
        )
        bone_nodes.append(node_i)

        if parent is not None:
            gltf["nodes"][bone_nodes[parent]].setdefault("children", []).append(node_i)

    gltf["scenes"][0].setdefault("nodes", []).append(bone_nodes[0])

    # inverse bind matrices are column-major in glTF.
    ibms = []
    for global_pos in globals_:
        matrix = np.eye(4, dtype=np.float32)
        matrix[:3, 3] = global_pos
        ibms.append(np.linalg.inv(matrix))
    ibm_blob = np.transpose(
        np.asarray(ibms, dtype=np.float32), (0, 2, 1)
    ).tobytes()

    ibo, ibl = append_blob(binary, ibm_blob)
    ibm_accessor = add_accessor(
        gltf, add_view(gltf, ibo, ibl), 5126, len(BONES), "MAT4"
    )

    gltf["skins"] = [
        {
            "name": "ScoutSkin",
            "inverseBindMatrices": ibm_accessor,
            "joints": bone_nodes,
            "skeleton": bone_nodes[0],
        }
    ]

    mesh_node_index = next(
        i for i, node in enumerate(gltf["nodes"]) if "mesh" in node
    )
    gltf["nodes"][mesh_node_index]["skin"] = 0

    gltf.setdefault("animations", [])
    add_animation(gltf, binary, bone_nodes, "idle", 1.20, "idle")
    add_animation(gltf, binary, bone_nodes, "walk", 0.56, "walk")
    add_animation(gltf, binary, bone_nodes, "run", 0.46, "run")
    add_animation(gltf, binary, bone_nodes, "hit", 0.18, "hit")
    add_animation(gltf, binary, bone_nodes, "stunned", 0.70, "defeat")
    add_animation(gltf, binary, bone_nodes, "бокс_02", 0.55, "box1")
    add_animation(gltf, binary, bone_nodes, "бокс_03", 0.55, "box2")

    gltf["buffers"][0]["byteLength"] = len(binary)
    write_glb(gltf, binary)

    # Deterministic structural validation before Godot sees the file.
    assert int(gltf["accessors"][0]["max"][0]) < len(vertices)
    assert len(gltf["skins"][0]["joints"]) == len(BONES)
    assert len(gltf["animations"]) >= 7
    print(
        "SCOUT RIG BUILD: wrote %s (%d bytes), vertices=%d, triangles=%d, bones=%d, animations=%d"
        % (OUT.name, OUT.stat().st_size, len(vertices), len(faces), len(BONES), len(gltf["animations"]))
    )


if __name__ == "__main__":
    build()
