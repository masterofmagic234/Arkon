#!/usr/bin/env python3
import json
import math
import struct
from collections import defaultdict, deque

GLB_PATH = "nfs_shift_psp_-_london_short.glb"


def mat_identity():
    return (
        1.0, 0.0, 0.0, 0.0,
        0.0, 1.0, 0.0, 0.0,
        0.0, 0.0, 1.0, 0.0,
        0.0, 0.0, 0.0, 1.0,
    )


def mat_mul(a, b):
    out = [0.0] * 16
    for r in range(4):
        for c in range(4):
            out[r * 4 + c] = sum(a[r * 4 + k] * b[k * 4 + c] for k in range(4))
    return tuple(out)


def mat_translate(v):
    x, y, z = v
    m = list(mat_identity())
    m[3], m[7], m[11] = x, y, z
    return tuple(m)


def mat_scale(v):
    x, y, z = v
    m = list(mat_identity())
    m[0], m[5], m[10] = x, y, z
    return tuple(m)


def mat_from_quat(q):
    x, y, z, w = q
    return (
        1 - 2 * (y*y + z*z), 2 * (x*y - z*w), 2 * (x*z + y*w), 0,
        2 * (x*y + z*w), 1 - 2 * (x*x + z*z), 2 * (y*z - x*w), 0,
        2 * (x*z - y*w), 1 - 2 * (x*x + z*z), 0,
        0, 0, 0, 1,
    )


def mat_transform(m, p):
    x, y, z = p
    return (
        m[0] * x + m[1] * y + m[2] * z + m[3],
        m[4] * x + m[5] * y + m[6] * z + m[7],
        m[8] * x + m[9] * y + m[10] * z + m[11],
    )


def node_matrix(node):
    if "matrix" in node:
        # glTF matrices are column-major.
        src = node["matrix"]
        return (
            src[0], src[4], src[8], src[12],
            src[1], src[5], src[9], src[13],
            src[2], src[6], src[10], src[14],
            src[3], src[7], src[11], src[15],
        )

    t = node.get("translation", [0.0, 0.0, 0.0])
    r = node.get("rotation", [0.0, 0.0, 0.0, 1.0])
    s = node.get("scale", [1.0, 1.0, 1.0])

    # Build row-major matrices from the standard glTF TRS convention.
    x, y, z, w = r
    rot = (
        1 - 2 * (y*y + z*z), 2 * (x*y - z*w), 2 * (x*z + y*w), 0,
        2 * (x*y + z*w), 1 - 2 * (x*x + z*z), 0, 0,
        2 * (x*z - y*w), 2 * (y*z + x*w), 1 - 2 * (x*x + y*y), 0,
        0, 0, 0, 1,
    )
    return mat_mul(mat_translate(t), mat_mul(rot, mat_scale(s)))


def read_glb(path):
    with open(path, "rb") as f:
        raw = f.read()

    magic, version, length = struct.unpack_from("<4sII", raw, 0)
    if magic != b"glTF" or version != 2:
        raise RuntimeError("Not a GLB 2.0 file")

    offset = 12
    json_chunk = None
    bin_chunk = b""
    while offset < length:
        chunk_len, chunk_type = struct.unpack_from("<II", raw, offset)
        offset += 8
        chunk = raw[offset:offset + chunk_len]
        offset += chunk_len
        if chunk_type == 0x4E4F534A:
            json_chunk = json.loads(chunk.decode("utf-8"))
        elif chunk_type == 0x004E4942:
            bin_chunk = chunk

    if json_chunk is None:
        raise RuntimeError("GLB JSON chunk missing")
    return json_chunk, bin_chunk


COMPONENT_FMT = {
    5120: ("b", 1),
    5121: ("B", 1),
    5122: ("h", 2),
    5123: ("H", 2),
    5125: ("I", 4),
    5126: ("f", 4),
}
TYPE_COMPONENTS = {
    "SCALAR": 1,
    "VEC2": 2,
    "VEC3": 3,
    "VEC4": 4,
}


def read_accessor(gltf, binary, accessor_index):
    acc = gltf["accessors"][accessor_index]
    bv = gltf["bufferViews"][acc["bufferView"]]
    fmt_char, component_size = COMPONENT_FMT[acc["componentType"]]
    component_count = TYPE_COMPONENTS[acc["type"]]
    count = acc["count"]
    stride = bv.get("byteStride", component_size * component_count)
    start = bv.get("byteOffset", 0) + acc.get("byteOffset", 0)

    fmt = "<" + fmt_char * component_count
    raw_values = []
    for i in range(count):
        off = start + i * stride
        values = struct.unpack_from(fmt, binary, off)
        raw_values.append(values)

    return raw_values


def node_world_matrices(gltf):
    nodes = gltf.get("nodes", [])
    children = defaultdict(list)
    parent_of = {}
    for i, node in enumerate(nodes):
        for child in node.get("children", []):
            children[i].append(child)
            parent_of[child] = i

    roots = [i for i in range(len(nodes)) if i not in parent_of]
    world = [mat_identity() for _ in nodes]
    q = deque(roots)
    while q:
        i = q.popleft()
        local = node_matrix(nodes[i])
        if i in parent_of:
            world[i] = mat_mul(world[parent_of[i]], local)
        else:
            world[i] = local
        for child in children[i]:
            q.append(child)
    return world


def main():
    gltf, binary = read_glb(GLB_PATH)
    worlds = node_world_matrices(gltf)

    meshes = gltf.get("meshes", [])
    nodes = gltf.get("nodes", [])

    scene_min = [float("inf")] * 3
    scene_max = [float("-inf")] * 3
    flat_cells = defaultdict(int)
    flat_points = []
    flat_triangle_count = 0

    for node_index, node in enumerate(nodes):
        mesh_index = node.get("mesh")
        if mesh_index is None:
            continue
        mesh = meshes[mesh_index]
        world = worlds[node_index]

        for prim in mesh.get("primitives", []):
            attrs = prim.get("attributes", {})
            pos_accessor = attrs.get("POSITION")
            if pos_accessor is None:
                continue

            positions = read_accessor(gltf, binary, pos_accessor)
            positions_world = [mat_transform(world, p) for p in positions]

            for p in positions_world:
                for axis in range(3):
                    scene_min[axis] = min(scene_min[axis], p[axis])
                    scene_max[axis] = max(scene_max[axis], p[axis])

            if "indices" in prim:
                indices = read_accessor(gltf, binary, prim["indices"])
                indices = [v[0] for v in indices]
            else:
                indices = list(range(len(positions_world)))

            for j in range(0, len(indices) - 2, 3):
                a = positions_world[indices[j]]
                b = positions_world[indices[j + 1]]
                c = positions_world[indices[j + 2]]

                ab = (b[0]-a[0], b[1]-a[1], b[2]-a[2])
                ac = (c[0]-a[0], c[1]-a[1], c[2]-a[2])
                nx = ab[1] * ac[2] - ab[2] * ac[1]
                ny = ab[2] * ac[0] - ab[0] * ac[2]
                nz = ab[0] * ac[1] - ab[1] * ac[0]

                cross_len = math.sqrt(nx*nx + ny*ny + nz*nz)
                if cross_len < 1e-7:
                    continue

                area = cross_len * 0.5
                normal_y = abs(ny) / cross_len
                cy = (a[1] + b[1] + c[1]) / 3.0
                cx = (a[0] + b[0] + c[0]) / 3.0
                cz = (a[2] + b[2] + c[2]) / 3.0

                # Road surfaces are large, nearly horizontal triangles.
                if normal_y >= 0.96 and area >= 0.02:
                    flat_triangle_count += 1
                    flat_points.append((cx, cy, cz, area))
                    cell = (math.floor(cx / 2.0), math.floor(cz / 2.0))
                    flat_cells[cell] += 1

    print(
        "GLB SCENE BOUNDS: "
        "min=(%.2f, %.2f, %.2f) max=(%.2f, %.2f, %.2f)"
        % (*scene_min, *scene_max)
    )
    print(
        "GLB FLAT TRIANGLES: %d; occupied_2m_cells=%d"
        % (flat_triangle_count, len(flat_cells))
    )

    components = []
    unvisited = set(flat_cells)
    while unvisited:
        start = unvisited.pop()
        cells = [start]
        q = deque([start])
        while q:
            x, z = q.popleft()
            for dx in (-1, 0, 1):
                for dz in (-1, 0, 1):
                    if dx == 0 and dz == 0:
                        continue
                    n = (x + dx, z + dz)
                    if n in unvisited:
                        unvisited.remove(n)
                        q.append(n)
                        cells.append(n)

        min_x = min(c[0] for c in cells)
        max_x = max(c[0] for c in cells)
        min_z = min(c[1] for c in cells)
        max_z = max(c[1] for c in cells)

        point_count = 0
        area_sum = 0.0
        y_min = float("inf")
        y_max = float("-inf")
        for p in flat_points:
            cell = (math.floor(p[0] / 2.0), math.floor(p[2] / 2.0))
            if cell in set(cells):
                point_count += 1
                area_sum += p[3]
                y_min = min(y_min, p[1])
                y_max = max(y_max, p[1])

        components.append({
            "cells": len(cells),
            "points": point_count,
            "area": area_sum,
            "bbox": (min_x * 2.0, min_z * 2.0, (max_x + 1) * 2.0, (max_z + 1) * 2.0),
            "y": (y_min, y_max),
        })

    components.sort(key=lambda c: c["cells"], reverse=True)
    print("GLB FLAT SURFACE COMPONENTS:")
    for i, comp in enumerate(components[:20]):
        bx0, bz0, bx1, bz1 = comp["bbox"]
        print(
            "  COMPONENT %02d cells=%d points=%d area=%.1f "
            "bbox=(%.1f,%.1f)-(%.1f,%.1f) y=(%.2f,%.2f)"
            % (
                i,
                comp["cells"],
                comp["points"],
                comp["area"],
                bx0, bz0, bx1, bz1,
                comp["y"][0], comp["y"][1],
            )
        )

    print("GLB REPORT COMPLETE")



def triangle_area2_xy(a, b, c):
    return abs(
        (b[0]-a[0]) * (c[1]-a[1])
        - (b[1]-a[1]) * (c[0]-a[0])
    )


def mark_triangle(grid, a, b, c, x0, z0, res, width, height):
    min_x = max(0, int(math.floor(min(a[0], b[0], c[0]) / res)) - x0)
    max_x = min(width - 1, int(math.floor(max(a[0], b[0], c[0]) / res)) - x0)
    min_z = max(0, int(math.floor(min(a[2], b[2], c[2]) / res)) - z0)
    max_z = min(height - 1, int(math.floor(max(a[2], b[2], c[2]) / res)) - z0)
    den = (b[2] - c[2]) * (a[0] - c[0]) + (c[0] - b[0]) * (a[2] - c[2])
    if abs(den) < 1e-9:
        return
    for gz in range(min_z, max_z + 1):
        z = (gz + z0 + 0.5) * res
        for gx in range(min_x, max_x + 1):
            x = (gx + x0 + 0.5) * res
            u = ((b[2] - c[2]) * (x - c[0]) + (c[0] - b[0]) * (z - c[2])) / den
            v = ((c[2] - a[2]) * (x - c[0]) + (a[0] - c[0]) * (z - c[2])) / den
            w = 1.0 - u - v
            if u >= -0.02 and v >= -0.02 and w >= -0.02:
                grid[gz][gx] = 1


def skeletonize(binary):
    changed = True
    h = len(binary)
    w = len(binary[0]) if h else 0

    def neighbors(y, x):
        return [
            binary[y-1][x], binary[y-1][x+1], binary[y][x+1], binary[y+1][x+1],
            binary[y+1][x], binary[y+1][x-1], binary[y][x-1], binary[y-1][x-1]
        ]

    while changed:
        changed = False
        for step in (0, 1):
            remove = []
            for y in range(1, h - 1):
                for x in range(1, w - 1):
                    if not binary[y][x]:
                        continue
                    n = neighbors(y, x)
                    count = sum(n)
                    if count < 2 or count > 6:
                        continue
                    transitions = sum(
                        1 for i in range(8) if n[i] == 0 and n[(i + 1) % 8] == 1
                    )
                    if transitions != 1:
                        continue
                    if step == 0:
                        if n[0] and n[2] and n[4]:
                            continue
                        if n[2] and n[4] and n[6]:
                            continue
                    else:
                        if n[0] and n[2] and n[6]:
                            continue
                        if n[0] and n[4] and n[6]:
                            continue
                    remove.append((y, x))
            if remove:
                changed = True
                for y, x in remove:
                    binary[y][x] = 0
    return binary


def skeleton_components(binary):
    h = len(binary)
    w = len(binary[0]) if h else 0
    seen = set()
    comps = []
    for y in range(h):
        for x in range(w):
            if not binary[y][x] or (y, x) in seen:
                continue
            q = deque([(y, x)])
            seen.add((y, x))
            comp = []
            while q:
                cy, cx = q.popleft()
                comp.append((cy, cx))
                for dy in (-1, 0, 1):
                    for dx in (-1, 0, 1):
                        if dy == 0 and dx == 0:
                            continue
                        ny, nx = cy + dy, cx + dx
                        if 0 <= ny < h and 0 <= nx < w and binary[ny][nx] and (ny, nx) not in seen:
                            seen.add((ny, nx))
                            q.append((ny, nx))
            comps.append(comp)
    comps.sort(key=len, reverse=True)
    return comps


def order_skeleton_component(comp, binary):
    cells = set(comp)
    degree = {}
    for y, x in comp:
        d = []
        for dy in (-1, 0, 1):
            for dx in (-1, 0, 1):
                if dy == 0 and dx == 0:
                    continue
                if (y + dy, x + dx) in cells:
                    d.append((y + dy, x + dx))
        degree[(y, x)] = d

    start = None
    endpoints = [p for p in comp if len(degree[p]) == 1]
    if endpoints:
        start = min(endpoints)
    else:
        start = min(comp, key=lambda p: (p[1], p[0]))

    ordered = [start]
    prev = None
    cur = start
    max_steps = len(comp) * 2
    for _ in range(max_steps):
        candidates = [p for p in degree[cur] if p != prev]
        if not candidates:
            break
        if len(candidates) > 1:
            # Prefer the neighbor that keeps moving away from the previous
            # direction, which is stable enough for a thin closed road mask.
            if prev is not None:
                vy = cur[0] - prev[0]
                vx = cur[1] - prev[1]
                def score(p):
                    wy = p[0] - cur[0]
                    wx = p[1] - cur[1]
                    return -(vy * wy + vx * wx)
                candidates.sort(key=score)
        nxt = candidates[0]
        if nxt == start and len(ordered) > 10:
            break
        if nxt in ordered:
            break
        ordered.append(nxt)
        prev, cur = cur, nxt
    return ordered


def main():
    gltf, binary = read_glb(GLB_PATH)
    worlds = node_world_matrices(gltf)
    meshes = gltf.get("meshes", [])
    nodes = gltf.get("nodes", [])

    flat_triangles = []
    scene_min = [float("inf")] * 3
    scene_max = [float("-inf")] * 3

    for node_index, node in enumerate(nodes):
        mesh_index = node.get("mesh")
        if mesh_index is None:
            continue
        mesh = meshes[mesh_index]
        world = worlds[node_index]
        for prim in mesh.get("primitives", []):
            pos_accessor = prim.get("attributes", {}).get("POSITION")
            if pos_accessor is None:
                continue
            positions = read_accessor(gltf, binary, pos_accessor)
            positions_world = [mat_transform(world, p) for p in positions]
            for p in positions_world:
                for axis in range(3):
                    scene_min[axis] = min(scene_min[axis], p[axis])
                    scene_max[axis] = max(scene_max[axis], p[axis])
            if "indices" in prim:
                inds = [v[0] for v in read_accessor(gltf, binary, prim["indices"])]
            else:
                inds = list(range(len(positions_world)))
            for j in range(0, len(inds) - 2, 3):
                a = positions_world[inds[j]]
                b = positions_world[inds[j + 1]]
                c = positions_world[inds[j + 2]]
                ab = (b[0]-a[0], b[1]-a[1], b[2]-a[2])
                ac = (c[0]-a[0], c[1]-a[1], c[2]-a[2])
                nx = ab[1] * ac[2] - ab[2] * ac[1]
                ny = ab[2] * ac[0] - ab[0] * ac[2]
                nz = ab[0] * ac[1] - ab[1] * ac[0]
                cross_len = math.sqrt(nx*nx + ny*ny + nz*nz)
                if cross_len < 1e-7:
                    continue
                area = cross_len * 0.5
                normal_y = abs(ny) / cross_len
                if normal_y >= 0.96 and area >= 0.02:
                    flat_triangles.append((a, b, c, area))

    # The dominant connected flat component from the first pass identifies the
    # road envelope. Keep only triangles whose centroids fall inside that envelope.
    min_x = min(
        (p[0] + q[0] + r[0]) / 3.0
        for p, q, r, _ in flat_triangles
    )
    max_x = max(
        (p[0] + q[0] + r[0]) / 3.0
        for p, q, r, _ in flat_triangles
    )
    min_z = min(
        (p[2] + q[2] + r[2]) / 3.0
        for p, q, r, _ in flat_triangles
    )
    max_z = max(
        (p[2] + q[2] + r[2]) / 3.0
        for p, q, r, _ in flat_triangles
    )

    # Use the known dominant road envelope from the flat-surface pass.
    res = 0.5
    x0 = int(math.floor(min_x / res)) - 2
    x1 = int(math.ceil(max_x / res)) + 2
    z0 = int(math.floor(min_z / res)) - 2
    z1 = int(math.ceil(max_z / res)) + 2
    width = x1 - x0 + 1
    height = z1 - z0 + 1
    grid = [[0 for _ in range(width)] for _ in range(height)]

    for a, b, c, _ in flat_triangles:
        cx = (a[0] + b[0] + c[0]) / 3.0
        cz = (a[2] + b[2] + c[2]) / 3.0
        if (
            cx < min_x - 3.0
            or cx > max_x + 3.0
            or cz < min_z - 3.0
            or cz > max_z + 3.0
        ):
            continue
        mark_triangle(grid, a, b, c, x0, z0, res, width, height)

    skeleton = skeletonize(grid)
    comps = skeleton_components(skeleton)
    if not comps:
        print("CENTERLINE: no skeleton component found")
        return

    main_comp = comps[0]
    ordered = order_skeleton_component(main_comp, skeleton)
    sample_count = min(64, max(12, len(ordered) // 4))
    samples = []
    for i in range(sample_count):
        idx = int(round(i * (len(ordered) - 1) / max(sample_count - 1, 1)))
        gy, gx = ordered[idx]
        samples.append(
            (
                (gx + x0 + 0.5) * res,
                (gy + z0 + 0.5) * res
            )
        )

    print(
        "CENTERLINE: skeleton_cells=%d ordered=%d samples=%d"
        % (len(main_comp), len(ordered), len(samples))
    )
    for i, (x, z) in enumerate(samples):
        print("CENTER_%02d = %.3f, %.3f" % (i, x, z))


if __name__ == "__main__":
    main()
