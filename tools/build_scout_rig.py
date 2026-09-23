#!/usr/bin/env python3
"""Build ACORN HUNTER's Scout from the uploaded unrigged Meshy mesh.

Creates a small game-oriented animal skeleton, 4-influence skin weights, and
lightweight embedded glTF animation clips. Output is scout_rigged.glb in repo root.
"""

import io
import json
import math
import struct
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "Meshy_AI_Acorn_Guardian_0923182156_texture (1).glb"
OUT = ROOT / "scout_rigged.glb"


def read_glb(path: Path):
    data = path.read_bytes()
    magic, version, total = struct.unpack_from("<4sII", data, 0)
    if magic != b"glTF" or version != 2:
        raise RuntimeError("Not a glTF 2.0 GLB")
    off = 12
    gltf = None
    binary = None
    while off < total:
        size, kind = struct.unpack_from("<II", data, off)
        off += 8
        chunk = data[off:off + size]
        off += size
        if kind == 0x4E4F534A:
            gltf = json.loads(chunk.decode("utf-8"))
        elif kind == 0x004E4942:
            binary = chunk
    if gltf is None or binary is None:
        raise RuntimeError("GLB missing JSON or BIN chunk")
    return gltf, binary


def q_axis(axis, angle):
    axis = np.asarray(axis, dtype=float)
    axis /= np.linalg.norm(axis)
    h = angle * 0.5
    s = math.sin(h)
    return np.array([axis[0] * s, axis[1] * s, axis[2] * s, math.cos(h)], np.float32)


def q_mul(a, b):
    x1, y1, z1, w1 = a
    x2, y2, z2, w2 = b
    return np.array([
        w1*x2 + x1*w2 + y1*z2 - z1*y2,
        w1*y2 - x1*z2 + y1*w2 + z1*x2,
        w1*z2 + x1*y2 - y1*x2 + z1*w2,
        w1*w2 - x1*x2 - y1*y2 - z1*z2,
    ], np.float32)


def q_xyz(rx, ry, rz):
    return q_mul(q_mul(q_axis((1, 0, 0), rx), q_axis((0, 1, 0), ry)), q_axis((0, 0, 1), rz))


def build():
    gltf, old_bin = read_glb(SRC)

    # Read the source mesh.
    pos_acc = gltf["accessors"][0]
    pos_view = gltf["bufferViews"][1]
    vertices = np.frombuffer(
        old_bin,
        dtype="<f4",
        count=pos_acc["count"] * 3,
        offset=pos_view.get("byteOffset", 0) + pos_acc.get("byteOffset", 0),
    ).reshape(-1, 3).copy()

    # Keep the base-color texture at 1K for Android.
    img_view = gltf["bufferViews"][4]
    raw_img = old_bin[
        img_view["byteOffset"]:img_view["byteOffset"] + img_view["byteLength"]
    ]
    image = Image.open(io.BytesIO(raw_img)).convert("RGB")
    image.thumbnail((1024, 1024), Image.Resampling.LANCZOS)
    img_out = io.BytesIO()
    image.save(img_out, format="JPEG", quality=72, optimize=True, progressive=True)
    compact_img = img_out.getvalue()

    # Compact original binary sections: indices, position, UV, normal, image.
    original_parts = []
    for i in range(4):
        view = gltf["bufferViews"][i]
        original_parts.append(old_bin[view["byteOffset"]:view["byteOffset"] + view["byteLength"]])

    binary = bytearray()
    new_views = []
    for i, part in enumerate(original_parts + [compact_img]):
        while len(binary) % 4:
            binary.append(0)
        off = len(binary)
        binary.extend(part)
        old_view = gltf["bufferViews"][i]
        view = {"buffer": 0, "byteOffset": off, "byteLength": len(part)}
        if "target" in old_view:
            view["target"] = old_view["target"]
        new_views.append(view)

    out_gltf = json.loads(json.dumps(gltf))
    out_gltf["bufferViews"] = new_views
    out_gltf["accessors"][0]["bufferView"] = 1
    out_gltf["accessors"][1]["bufferView"] = 2
    out_gltf["accessors"][2]["bufferView"] = 3
    out_gltf["accessors"][3]["bufferView"] = 0

    bones = [
        ("root", None, (0, 0, 0)),
        ("pelvis", 0, (0, -0.42, 0.06)),
        ("spine", 1, (0, 0.22, 0)),
        ("chest", 2, (0, 0.28, 0)),
        ("neck", 3, (0, 0.28, -0.01)),
        ("head", 4, (0, 0.18, -0.01)),
        ("jaw", 5, (0, -0.16, -0.17)),
        ("ear.L", 5, (-0.18, 0.18, 0)),
        ("ear.R", 5, (0.18, 0.18, 0)),
        ("arm.upper.L", 3, (-0.24, 0.04, 0)),
        ("arm.fore.L", 9, (-0.13, -0.23, 0)),
        ("hand.L", 10, (0, -0.18, -0.01)),
        ("arm.upper.R", 3, (0.24, 0.04, 0)),
        ("arm.fore.R", 12, (0.13, -0.23, 0)),
        ("hand.R", 13, (0, -0.18, -0.01)),
        ("leg.thigh.L", 1, (-0.18, -0.28, 0)),
        ("leg.shin.L", 15, (-0.05, -0.26, -0.02)),
        ("foot.L", 16, (0, -0.12, -0.12)),
        ("leg.thigh.R", 1, (0.18, -0.28, 0)),
        ("leg.shin.R", 18, (0.05, -0.26, -0.02)),
        ("foot.R", 19, (0, -0.12, -0.12)),
        ("tail.01", 1, (0.02, 0.02, 0.22)),
        ("tail.02", 21, (0.10, 0.12, 0.24)),
        ("tail.03", 22, (0.02, 0.18, 0.22)),
        ("tail.04", 23, (-0.07, 0.16, 0.16)),
    ]
    globals_ = []
    for _, parent, local in bones:
        lp = np.array(local, float)
        globals_.append((globals_[parent] if parent is not None else np.zeros(3)) + lp)
    globals_ = np.asarray(globals_)

    segments = []
    for i, (_, parent, _) in enumerate(bones):
        segments.append((globals_[parent] if parent is not None else globals_[i], globals_[i]))

    radii = np.full(len(bones), 0.16)
    for i, (name, _, _) in enumerate(bones):
        if i == 0:
            radii[i] = 0.30
        if name in ("head", "jaw", "ear.L", "ear.R"):
            radii[i] = 0.20
        if name.startswith("tail"):
            radii[i] = 0.24
    idx = {name: i for i, (name, _, _) in enumerate(bones)}

    def seg_dist2(v, a, b):
        ab = b - a
        denom = float(ab @ ab)
        if denom < 1e-10:
            return float((v - a) @ (v - a))
        t = max(0.0, min(1.0, float((v - a) @ ab) / denom))
        q = a + t * ab
        return float((v - q) @ (v - q))

    joints = np.zeros((len(vertices), 4), np.uint16)
    weights = np.zeros((len(vertices), 4), np.float32)

    for vi, v in enumerate(vertices):
        scores = np.exp(
            -np.array([seg_dist2(v, a, b) for a, b in segments]) / (2.0 * radii * radii)
        )
        x, y, z = v
        if y > 0.42:
            for name, boost in (("neck", .25), ("head", .35), ("jaw", .15), ("ear.L", .08), ("ear.R", .08)):
                scores[idx[name]] *= 1.0 + boost
        if x < -0.16 and y > -0.55:
            for name, boost in (("arm.upper.L", .35), ("arm.fore.L", .22), ("hand.L", .10)):
                scores[idx[name]] *= 1.0 + boost
        if x > 0.16 and y > -0.55:
            for name, boost in (("arm.upper.R", .35), ("arm.fore.R", .22), ("hand.R", .10)):
                scores[idx[name]] *= 1.0 + boost
        if y < -0.35:
            names = ("leg.thigh.L", "leg.shin.L", "foot.L") if x < 0 else ("leg.thigh.R", "leg.shin.R", "foot.R")
            for name, boost in zip(names, (.40, .26, .12)):
                scores[idx[name]] *= 1.0 + boost
        if z > 0.28:
            for name, boost in (("tail.01", .25), ("tail.02", .32), ("tail.03", .28), ("tail.04", .18)):
                scores[idx[name]] *= 1.0 + boost
        scores[0] *= 0.15

        top = np.argsort(scores)[-4:][::-1]
        sw = scores[top]
        if sw.sum() <= 1e-10:
            top = np.array([0, 1, 2, 3])
            sw = np.array([1.0, 0.0, 0.0, 0.0])
        joints[vi] = top
        weights[vi] = sw / sw.sum()

    def align4():
        while len(binary) % 4:
            binary.append(0)

    def append_blob(blob):
        align4()
        off = len(binary)
        binary.extend(blob)
        return off, len(blob)

    def add_view(off, length, target=None):
        v = {"buffer": 0, "byteOffset": off, "byteLength": length}
        if target is not None:
            v["target"] = target
        out_gltf["bufferViews"].append(v)
        return len(out_gltf["bufferViews"]) - 1

    def add_accessor(view, component, count, typ):
        out_gltf["accessors"].append({
            "bufferView": view,
            "byteOffset": 0,
            "componentType": component,
            "normalized": False,
            "count": count,
            "type": typ,
        })
        return len(out_gltf["accessors"]) - 1

    jo, jl = append_blob(joints.astype("<u2").tobytes())
    jo_v = add_view(jo, jl, 34962)
    jo_a = add_accessor(jo_v, 5123, len(vertices), "VEC4")
    wo, wl = append_blob(weights.astype("<f4").tobytes())
    wo_v = add_view(wo, wl, 34962)
    wo_a = add_accessor(wo_v, 5126, len(vertices), "VEC4")
    primitive = out_gltf["meshes"][0]["primitives"][0]["attributes"]
    primitive["JOINTS_0"] = jo_a
    primitive["WEIGHTS_0"] = wo_a

    ibm = []
    for gp in globals_:
        m = np.eye(4, dtype=np.float32)
        m[:3, 3] = gp
        ibm.append(np.linalg.inv(m).T.reshape(-1))
    ib_o, ib_l = append_blob(np.stack(ibm).astype("<f4").tobytes())
    ib_v = add_view(ib_o, ib_l)
    ib_a = add_accessor(ib_v, 5126, len(bones), "MAT4")

    armature = len(out_gltf["nodes"])
    out_gltf["nodes"].append({"name": "Scout_Armature", "children": []})
    bone_nodes = []
    for i, (name, parent, local) in enumerate(bones):
        node = len(out_gltf["nodes"])
        bone_nodes.append(node)
        out_gltf["nodes"].append({"name": name, "translation": [float(v) for v in local]})
        if parent is None:
            out_gltf["nodes"][armature]["children"].append(node)
        else:
            out_gltf["nodes"][bone_nodes[parent]].setdefault("children", []).append(node)

    out_gltf.setdefault("skins", []).append({
        "inverseBindMatrices": ib_a,
        "joints": bone_nodes,
        "skeleton": bone_nodes[0],
    })
    out_gltf["nodes"][0]["skin"] = len(out_gltf["skins"]) - 1

    I = np.array([0, 0, 0, 1], np.float32)

    def pose(clip, t):
        q = [I.copy() for _ in bones]
        ph = 2 * math.pi * t
        s = math.sin(ph)
        s2 = math.sin(2 * ph)

        if clip == "idle":
            q[idx["spine"]] = q_xyz(.025*s, 0, 0)
            q[idx["chest"]] = q_xyz(.015*s, 0, 0)
            q[idx["head"]] = q_xyz(0, 0, .018*s)
            for n, a, z in (("tail.01", .05, .045), ("tail.02", .06, .054), ("tail.03", .055, .050), ("tail.04", .045, .040)):
                q[idx[n]] = q_xyz(a*s, 0, z*s)
        elif clip in ("ходьба", "бег"):
            a = .42 if clip == "ходьба" else .62
            arm = .28 if clip == "ходьба" else .42
            q[idx["leg.thigh.L"]] = q_xyz(a*s2, 0, 0)
            q[idx["leg.thigh.R"]] = q_xyz(-a*s2, 0, 0)
            q[idx["leg.shin.L"]] = q_xyz(-.16*max(0, -s2), 0, 0)
            q[idx["leg.shin.R"]] = q_xyz(.16*max(0, s2), 0, 0)
            q[idx["arm.upper.L"]] = q_xyz(-arm*s2, 0, 0)
            q[idx["arm.upper.R"]] = q_xyz(arm*s2, 0, 0)
            q[idx["arm.fore.L"]] = q_xyz(.10*max(0, s2), 0, 0)
            q[idx["arm.fore.R"]] = q_xyz(-.10*max(0, -s2), 0, 0)
            q[idx["spine"]] = q_xyz(.035*s, 0, .045*s)
            q[idx["chest"]] = q_xyz(.025*s, 0, .03*s)
            q[idx["head"]] = q_xyz(0, 0, .03*s)
            for n, a, z in (("tail.01", .08, .06), ("tail.02", .11, .08), ("tail.03", .09, .07), ("tail.04", .07, .05)):
                q[idx[n]] = q_xyz(a*s, 0, z*s)
        elif clip == "поражение":
            e = math.sin(max(0.0, min(1.0, t)) * math.pi * .5)
            q[idx["spine"]] = q_xyz(math.radians(-18)*e, 0, 0)
            q[idx["chest"]] = q_xyz(math.radians(-22)*e, 0, 0)
            q[idx["head"]] = q_xyz(math.radians(-14)*e, 0, 0)
            q[idx["arm.upper.L"]] = q_xyz(math.radians(28)*e, 0, math.radians(-10)*e)
            q[idx["arm.upper.R"]] = q_xyz(math.radians(28)*e, 0, math.radians(10)*e)
        elif clip == "бокс_02":
            j = math.sin(ph)
            q[idx["spine"]] = q_xyz(0, math.radians(6)*j, 0)
            q[idx["arm.upper.L"]] = q_xyz(math.radians(-20)*j, math.radians(-18)*j, 0)
            q[idx["arm.upper.R"]] = q_xyz(math.radians(20)*j, math.radians(18)*j, 0)
        elif clip == "бокс_03":
            j = math.sin(ph)
            q[idx["spine"]] = q_xyz(0, math.radians(-8)*j, 0)
            q[idx["arm.upper.L"]] = q_xyz(math.radians(18)*j, math.radians(18)*j, 0)
            q[idx["arm.upper.R"]] = q_xyz(math.radians(-18)*j, math.radians(-18)*j, 0)
        return np.stack(q)

    def animation(name, duration, clip):
        times = np.array([0, duration * .5, duration], dtype="<f4")
        to, tl = append_blob(times.tobytes())
        tv = add_view(to, tl)
        ta = add_accessor(tv, 5126, 3, "SCALAR")
        samplers = []
        channels = []
        poses = [pose(clip, 0), pose(clip, .5), pose(clip, 1)]
        for bi, node in enumerate(bone_nodes):
            rots = np.stack([p[bi] for p in poses]).astype("<f4")
            oo, ol = append_blob(rots.tobytes())
            ov = add_view(oo, ol)
            oa = add_accessor(ov, 5126, 3, "VEC4")
            si = len(samplers)
            samplers.append({"input": ta, "output": oa, "interpolation": "LINEAR"})
            channels.append({"sampler": si, "target": {"node": node, "path": "rotation"}})
        out_gltf.setdefault("animations", []).append({
            "name": name,
            "samplers": samplers,
            "channels": channels,
        })

    animation("idle", 1.2, "idle")
    animation("ходьба", .56, "ходьба")
    animation("бег", .46, "бег")
    animation("поражение", .70, "поражение")
    animation("бокс_02", .55, "бокс_02")
    animation("бокс_03", .55, "бокс_03")

    out_gltf["buffers"][0]["byteLength"] = len(binary)

    json_bytes = json.dumps(out_gltf, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
    while len(json_bytes) % 4:
        json_bytes += b" "
    while len(binary) % 4:
        binary.append(0)

    total_len = 12 + 8 + len(json_bytes) + 8 + len(binary)
    glb = (
        struct.pack("<4sII", b"glTF", 2, total_len)
        + struct.pack("<II", len(json_bytes), 0x4E4F534A)
        + json_bytes
        + struct.pack("<II", len(binary), 0x004E4942)
        + bytes(binary)
    )
    OUT.write_bytes(glb)
    print(f"SCOUT RIG BUILD: wrote {OUT.name} ({len(glb)} bytes), bones={len(bones)}, animations=6")


if __name__ == "__main__":
    build()
