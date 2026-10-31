#!/usr/bin/env python3
"""Audit emitted production geometry, not placement-policy pass flags.

The Godot collector supplies actual mesh triangles and physics-query results.
This process independently calculates paving, soil and furniture intersections,
grades, root clearance, support gaps and walking-surface connectivity. Native
images remain a separate required visual review; a geometry pass is not an FPS
or normal campaign claim.
"""
from __future__ import annotations

import argparse
from collections import Counter
import itertools
import hashlib
import json
import math
import re
from pathlib import Path

from shapely.geometry import LineString, Point, Polygon, box
from shapely.ops import unary_union

SOURCES = {
    "scripts/botanical_world.gd", "scripts/botanical_world151.gd",
    "scripts/botanical_layout.gd", "scripts/botanical_lighting.gd",
    "scripts/botanical_collision150.gd", "scripts/botanical_waterworks.gd",
    "scripts/botanical_evening.gd", "scripts/botanical_garden.gd",
}
CAPTURES = {
    "bank-west-original", "west-promenade-bank", "east-promenade-turn",
    "bench-east-canal-original", "bench-east-front", "gallery-promenade-original-row",
    "gallery-recessed-soil", "entry-stair-west-foot", "entry-stair-east-foot",
    "central-stair-foot", "central-landing-west-seam", "upper-stair-foot",
    "entry-bench-alcove", "orchard-pavilion-route", "whole-layout-overview",
    "canal-footbridge-crossing",
}


def require(value, message):
    if not value:
        raise AssertionError(message)


def vec(value, length, context):
    require(isinstance(value, list) and len(value) == length, context + ": malformed vector")
    require(all(isinstance(v, (float, int)) and math.isfinite(v) for v in value), context + ": nonfinite vector")
    return value


def rect(value, context):
    x, z = vec(value["position"], 2, context)
    w, h = vec(value["size"], 2, context)
    require(w > 0 and h > 0, context + ": invalid rectangle size")
    return box(x, z, x+w, z+h)


def mesh(value, context, *, top_only=False):
    """Return projected nondegenerate triangles and their actual 3D vertices."""
    require(isinstance(value, list) and len(value) >= 3 and len(value) % 3 == 0, context + ": missing triangle faces")
    rows = []
    for offset in range(0, len(value), 3):
        tri = [vec(v, 3, context) for v in value[offset:offset+3]]
        polygon = Polygon([(v[0], v[2]) for v in tri])
        if polygon.area <= 1e-8:
            continue  # Real box side faces project to a line, not a floor.
        require(polygon.is_valid, context + ": invalid projected triangle")
        a, b, c = tri
        normal_y = (b[2]-a[2])*(c[0]-a[0])-(b[0]-a[0])*(c[2]-a[2])
        # Godot uses clockwise front faces. A visible upward BoxMesh top has
        # conventional (b-a).cross(c-a).y < 0; > 0 selects its underside.
        if not top_only or normal_y < -1e-8:
            rows.append((polygon, tri))
    require(rows, context + ": no nondegenerate walking triangles")
    return rows


def triangle_multiset(value):
    rows = Counter()
    require(len(value) % 3 == 0, "Invalid authored triangle count")
    for offset in range(0, len(value), 3):
        vertices = [tuple(round(v*10000) for v in vec(p, 3, "authored triangle"))
                    for p in value[offset:offset+3]]
        rotations = [tuple(vertices[i:]+vertices[:i]) for i in range(3)]
        rows[min(rotations)] += 1
    return rows


def compare_triangles(actual, authored, tolerance=.0001):
    """One-to-one cyclic matching without quantization-boundary false positives.

    SurfaceTool indexing stores float32 vertices. Binning only finds candidate
    neighbors; acceptance always compares all nine coordinates directly and
    permits cyclic rotation, never reversed vertex order.
    """
    if len(actual) != len(authored) or len(actual) % 3:
        return {"equal": False, "maximum_component_error": None, "unmatched_triangles": 1}
    source, buckets = {}, {}
    for offset in range(0, len(authored), 3):
        triangle = authored[offset:offset+3]
        for point in triangle:
            vec(point, 3, "authored triangle")
        key = tuple(math.floor(sum(v[k] for v in triangle)/3*100) for k in range(3))
        source[offset] = triangle
        buckets.setdefault(key, set()).add(offset)
    maximum, unmatched = 0.0, 0
    for offset in range(0, len(actual), 3):
        triangle = actual[offset:offset+3]
        key = tuple(math.floor(sum(v[k] for v in triangle)/3*100) for k in range(3))
        best = (float("inf"), None, None)
        for delta in itertools.product([-1, 0, 1], repeat=3):
            neighbor = tuple(key[i]+delta[i] for i in range(3))
            for index in buckets.get(neighbor, ()):
                reference = source[index]
                error = min(max(abs(triangle[j][k]-reference[(j+rotation) % 3][k])
                                for j in range(3) for k in range(3)) for rotation in range(3))
                if error < best[0]:
                    best = error, index, neighbor
        if best[0] > tolerance:
            unmatched += 1
        else:
            maximum = max(maximum, best[0])
            buckets[best[2]].remove(best[1])
    unmatched += sum(len(rows) for rows in buckets.values())
    return {"equal": unmatched == 0, "maximum_component_error": maximum, "unmatched_triangles": unmatched}


def grade(tri):
    a, b, c = tri
    u, v = [[p[i]-a[i] for i in range(3)] for p in [b, c]]
    n = [u[1]*v[2]-u[2]*v[1], u[2]*v[0]-u[0]*v[2], u[0]*v[1]-u[1]*v[0]]
    return math.degrees(math.atan2(math.hypot(n[0], n[2]), abs(n[1])))


def height_at(tri, x, z):
    a, b, c = tri
    determinant = (b[2]-c[2])*(a[0]-c[0])+(c[0]-b[0])*(a[2]-c[2])
    first = ((b[2]-c[2])*(x-c[0])+(c[0]-b[0])*(z-c[2]))/determinant
    second = ((c[2]-a[2])*(x-c[0])+(a[0]-c[0])*(z-c[2]))/determinant
    return first*a[1]+second*b[1]+(1-first-second)*c[1]


def audit(data, *, source_root=None, require_native=False, captures_dir=None):
    failures, measurements = [], {}

    def check(value, why):
        if not value:
            failures.append(why)

    check(data.get("native") is True or not require_native, "Native renderer/display required")
    check(data.get("bake_enabled") is True, "Retained baked garden lighting is disabled")
    pins = data.get("source_hashes", {})
    check(set(pins) == SOURCES, "Exact eight production source identities required")
    for path, digest in pins.items():
        check(isinstance(digest, str) and re.fullmatch(r"[0-9a-f]{64}", digest) is not None,
              "Invalid source digest: " + path)
        if source_root is not None:
            check(hashlib.sha256((Path(source_root)/path).read_bytes()).hexdigest() == digest,
                  "Report differs from current reviewed source: " + path)

    paths, triangles = {}, {}
    seen_sources, seams, path_stats = set(), {}, []
    for row in data.get("paths", []):
        name = row["id"]
        require(name not in paths and row["source_id"] not in seen_sources, "Duplicate emitted path identity")
        seen_sources.add(row["source_id"])
        rows = mesh(row["triangles"], name)
        identity = compare_triangles(row["triangles"], row.get("authored_triangles", []))
        check(identity["equal"], "Actual emitted path differs from authored orientation-preserving triangles: " + name)
        triangles[name] = rows
        paths[name] = unary_union([poly for poly, _ in rows])
        maximum = max(grade(tri) for _, tri in rows)
        check(maximum <= 20.05, f"Park path {name} grade {maximum:.3f}° exceeds 20°")
        downward_faces = sum((b[2]-a[2])*(c[0]-a[0])-(b[0]-a[0])*(c[2]-a[2]) >= 0
                             for _, (a, b, c) in rows)
        check(downward_faces == 0, f"Actual paving {name} has {downward_faces} backface-culled/downward faces")
        for _, tri in rows:
            for x, y, z in tri:
                seams.setdefault((round(x, 4), round(z, 4)), []).append(y)
        path_stats.append({"id": name, "triangles": len(rows), "area": paths[name].area,
                           "maximum_grade_degrees": maximum, "backface_culled_faces": downward_faces,
                           "authored_identity": identity})
    require(len(paths) >= 16 and {"main_0", "main_1", "main_2", "main_3", "main_4", "main_5", "main_6", "main_7", "main_8"} <= paths.keys(), "Missing main routes/bench spurs")
    for key, values in seams.items():
        check(max(values)-min(values) <= .011, f"Paving height disagreement at {key}: {max(values)-min(values):.4f}m")
    paving = unary_union(list(paths.values()))
    measurements["paths"] = path_stats
    measurements["paving_union_area_m2"] = paving.area

    circulation = data["circulation"]
    canonical_routes = {row["id"]: row["points"] for row in circulation["paths"]}
    check(set(paths) == set(canonical_routes), "Actual emitted route IDs differ from complete canonical route census")
    for row in data["paths"]:
        check(row["route"] == canonical_routes[row["id"]], "Emitted route metadata differs from canonical route: " + row["id"])
    # The authored channel and its clipping corridor use JOIN_ROUND. A miter
    # invents a sharp outer wedge at each bend that the actual channel lacks.
    channel = LineString(circulation["channel"]).buffer(circulation["channel_half_width"], join_style=1)
    stair_footprints = []
    for a, b, width, count in circulation["stairs"]:
        vec(a, 3, "stair"); vec(b, 3, "stair")
        check(count >= 20 and b[1] > a[1], "Invalid authored stair flight")
        stair_footprints.append(box(a[0]-width/2-2, b[2]-2, a[0]+width/2+2, a[2]+2))
    for name, polygon in paths.items():
        for index, footprint in enumerate(stair_footprints):
            check(polygon.intersection(footprint).area <= .002, f"Paving {name} overlaps stair/landing {index}")

    # Crossings need an actual elevated deck and its physical support records;
    # an authored 'bridge=true' flag cannot exempt paving laid over water.
    bridges = []
    for bridge in data.get("bridges", []):
        rows = mesh(bridge["triangles"], "bridge " + bridge["id"], top_only=True)
        check(max(grade(tri) for _, tri in rows) <= 20.05, "Bridge has unreasonable walking grade")
        geometry = unary_union([p for p, _ in rows])
        samples = bridge.get("support_samples", [])
        check(len(samples) == 7, "Bridge requires actual center, bank and ramp supporting rays")
        for sample in samples:
            point = vec(sample["point"], 3, "bridge support")
            floor = sample.get("floor_hit", {})
            check(bool(floor), "Bridge support ray misses actual collision")
            candidates = [height_at(tri, point[0], point[2]) for poly, tri in rows
                          if poly.buffer(.001).covers(Point(point[0], point[2]))]
            check(bool(candidates), "Bridge sample is outside its actual walking deck")
            if floor and candidates:
                check(abs(max(candidates)-floor["position"][1]) <= .025,
                      "Bridge actual collision does not match emitted deck height")
        crossing = geometry.intersection(channel)
        check(crossing.area > .5, "Bridge does not actually span the channel")
        for poly, tri in rows:
            overlap = poly.intersection(channel)
            if overlap.area <= 1e-6:
                continue
            rings = [overlap] if overlap.geom_type == "Polygon" else list(overlap.geoms)
            for ring in rings:
                for x, z in ring.exterior.coords:
                    check(height_at(tri, x, z)-bridge["water_y"] >= .15,
                          "Actual bridge deck does not clear water along the crossing")
        bridges.append((bridge, geometry, rows))
    check(len(bridges) == 1, "The actual raised canal footbridge must be exported exactly once")
    channel_clashes = []
    for name, rows in triangles.items():
        for poly, tri in rows:
            overlap = poly.intersection(channel)
            if overlap.area <= 1e-5:
                continue
            covered = unary_union([geometry for _, geometry, _ in bridges]) if bridges else Polygon()
            uncovered = overlap.difference(covered.buffer(.002)).area
            if uncovered > 1e-4:
                channel_clashes.append({"path": name, "area_m2": uncovered,
                                        "centroid": [overlap.centroid.x, overlap.centroid.y]})
    check(not channel_clashes, "Paving laid over open channel without a real deck: " + str(channel_clashes[:6]))
    measurements["channel_clashes"] = channel_clashes

    soils, pots = [], []
    for row in data.get("soil", []):
        if row["kind"] == "soil_bed":
            outer = rect(row["rect"], row["id"])
            inner = rect(row["soil_rect"], row["id"] + " inset")
            check(outer.contains(inner), "Soil is not inset inside stone lip: " + row["id"])
            check(row["soil_y"] < row["lip_y"], "Soil must sit below its lip: " + row["id"])
            check(outer.intersection(paving).area <= .002, "Formal bed overlaps walking paving: " + row["id"])
            check(all(outer.intersection(s).area <= .002 for s in stair_footprints), "Formal bed overlaps stair/landing: " + row["id"])
            soils.append((row, inner, outer))
        elif row["kind"] == "pot_soil":
            x, _, z = vec(row["root"], 3, "pot")
            require(row["radius"] > 0, "Invalid pot radius")
            pots.append((row, Point(x, z).buffer(row["radius"])))
        else:
            failures.append("Unrecognized explicit planting support")

    plants = data.get("plants", [])
    require(len(plants) > 500 and len(soils) >= 16 and len(pots) >= 40, "Incomplete whole-level planting census")
    plant_stats = {"grass": 0, "soil_bed": 0, "pot": 0}
    plant_failures = []
    for index, row in enumerate(plants):
        root = vec(row["root"], 3, "plant root")
        base = vec(row["base"], 3, "plant base")
        point = Point(root[0], root[2])
        support = row["support_class"]
        require(support in plant_stats, "Unknown plant support class")
        plant_stats[support] += 1
        local = []
        bounds = row["mesh_bounds"]
        expected_y = root[1] + bounds["position"][1]*row["scale"]
        if abs(base[1]-expected_y) > .0001 or abs(root[0]-base[0]) > .0001 or abs(root[2]-base[2]) > .0001:
            local.append("base differs from actual mesh minimum")
        hit = row.get("floor_hit", {})
        if not hit:
            local.append("no actual floor")
        else:
            gap = base[1]-vec(hit["position"], 3, "plant support")[1]
            if abs(gap) > .04:
                local.append(f"actual supporting surface gap {gap:.4f}m")
        if support == "grass":
            radius = row.get("clearance_radius", 0)
            require(radius > 0, "Loose plant has no physical clearance radius")
            if point.distance(paving) < radius-.01:
                local.append("loose crown intersects walking paving")
            if point.distance(channel) < radius-.01:
                local.append("loose crown intersects water channel")
            if any(point.distance(s) < radius-.01 for s in stair_footprints):
                local.append("loose crown intersects stair/landing")
            if hit and hit.get("surface") != "grass":
                local.append("loose root grows from " + str(hit.get("surface")))
        elif support == "soil_bed":
            matches = [s for s, geometry, _ in soils if geometry.buffer(.001).covers(point) and abs(s["soil_y"]-base[1]) <= .02]
            if len(matches) != 1:
                local.append("root not on exactly one actual inset soil surface")
        elif support == "pot":
            matches = [s for s, geometry in pots if geometry.buffer(.001).covers(point) and abs(s["soil_y"]-base[1]) <= .02]
            if len(matches) != 1:
                local.append("root not on exactly one actual pot soil surface")
        if local:
            plant_failures.append({"index": index, "root": root, "problems": local})
    check(not plant_failures, "Invalid actual plant supports/clearance: " + str(plant_failures[:12]))
    measurements["plant_counts"] = plant_stats
    measurements["plant_failures"] = plant_failures

    bench_stats = []
    for row in data.get("benches", []):
        context = "Bench " + str(row["id"])
        pad = Polygon([vec(v, 2, context) for v in row["pad"]])
        check(pad.is_valid and pad.area > 5, context + " has invalid authored pad")
        check(pad.intersection(channel).area <= .002, context + " pad crosses channel")
        check(pad.distance(paving) <= .02, context + " has no paved approach")
        check(len(row["feet"]) == len(row["foot_hits"]) == 4, context + " lacks all four supporting foot rays")
        foot_gaps = []
        for foot, hit in zip(row["feet"], row["foot_hits"]):
            if not hit:
                failures.append(context + " foot has no floor")
                continue
            gap = foot[1]-hit["position"][1]
            foot_gaps.append(gap)
            check(abs(gap) <= .025, context + f" foot floats/sinks {gap:.4f}m")
        check(bool(row.get("approach_hit")), context + " has no supported front approach")
        check(row.get("approach_capsule_hits") == [], context + " front approach capsule blocked")
        if row.get("approach_hit"):
            check(abs(row["front"][1]-row["approach_hit"]["position"][1]) <= .04, context + " approach is not grounded")
        bench_stats.append({"id": row["id"], "foot_gaps_m": foot_gaps, "paving_distance_m": pad.distance(paving)})
    check(len(bench_stats) == 7, "All seven authored benches required")
    measurements["benches"] = bench_stats

    lamps = data.get("lamps", [])
    check(len(lamps) == 14 and len({row.get("id") for row in lamps}) == 14,
          "All eight decorative posts and six actual evening lamps must be exported once")
    check(sum(row.get("realtime_light") is True for row in lamps) == 6,
          "Retained six realtime evening lights missing/added")
    lamp_stats = []
    bridge_geometry = unary_union([geometry for _, geometry, _ in bridges]) if bridges else Polygon()
    for row in lamps:
        root = vec(row["root"], 3, "lamp root")
        foot = vec(row["visible_foot"], 3, "lamp visible foot")
        point = Point(root[0], root[2])
        radius = row["radius"]
        check(radius >= .05, "Lamp lacks its physical/visual clearance footprint")
        clearances = {"paving": point.distance(paving)-radius,
                      "channel": point.distance(channel)-radius,
                      "bridge": point.distance(bridge_geometry)-radius if bridges else float("inf"),
                      "stairs": min(point.distance(s) for s in stair_footprints)-radius}
        for label, gap in clearances.items():
            check(gap >= -.01, f"Lamp {row['id']} occupies {label}: {gap:.4f}m clearance")
        for soil, _, outer in soils:
            check(point.distance(outer) >= radius-.01, "Lamp grows through formal planter: " + row["id"])
        floor = row.get("floor_hit", {})
        check(bool(floor), "Lamp has no actual supporting floor: " + row["id"])
        if floor:
            check(abs(foot[1]-floor["position"][1]) <= .04,
                  "Lamp visible foot floats/sinks against actual floor: " + row["id"])
        if row.get("realtime_light"):
            check(row.get("energy") == 1.15 and row.get("range") == 11.0,
                  "Lamp relocation changed retained light energy/range")
        lamp_stats.append({"id": row["id"], "clearance_m": clearances,
                           "visible_floor_gap_m": foot[1]-floor["position"][1] if floor else None})
    measurements["lamps"] = lamp_stats

    # Connectivity and terminal supports are mandatory; the collector must
    # export actual stair/landing/deck surfaces before this can certify a level.
    walking = [paving]
    walking_surfaces = data.get("walking_surfaces", [])
    tread_ids = [row["id"] for row in walking_surfaces if row["id"].startswith("stair_")]
    check(len(tread_ids) == len(set(tread_ids)) == 110, "All 110 actual authored stair treads must be exported once")
    for row in walking_surfaces:
        walking.append(unary_union([p for p, _ in mesh(row["triangles"], row["id"], top_only=True)]))
    walking.extend(p for _, p, _ in bridges)
    check(bool(data.get("walking_surfaces")), "Actual stair/landing faces missing for walking connectivity")
    network = unary_union(walking).buffer(.025)
    parts = list(network.geoms) if network.geom_type == "MultiPolygon" else [network]
    components = [p for p in parts if p.area > .02]
    route_components = [part for part in components if part.intersection(paving).area > .01]
    check(len(route_components) == 1, f"Paved walking network has {len(route_components)} disconnected components")
    measurements["walking_component_areas_m2"] = sorted([p.area for p in components], reverse=True)
    measurements["paved_network_component_areas_m2"] = sorted([p.area for p in route_components], reverse=True)
    terminals = data.get("route_terminals", [])
    terminal_keys = [(row.get("path_id"), row.get("end")) for row in terminals]
    check(len(terminals) == len(paths)*2 and set(terminal_keys) == {(name, end) for name in paths for end in [0, 1]},
          "Every actual route endpoint needs exactly one named physical support/capsule sample")
    for row in terminals:
        point = vec(row["point"], 3, "route terminal")
        route = canonical_routes[row["path_id"]]
        endpoint = route[0 if row["end"] == 0 else -1]
        check(math.hypot(point[0]-endpoint[0], point[2]-endpoint[1]) <= .001,
              "Terminal sample was moved away from actual route endpoint: " + str(row.get("name")))
        check(bool(row.get("name")), "Unexplained route dead end")
        check(network.covers(Point(point[0], point[2])), "Route terminal is outside actual walking network: " + str(row.get("name")))
        check(bool(row.get("floor_hit")), "Route end has no actual physical support: " + str(row.get("name")))
        check(row.get("capsule_hits") == [], "Route endpoint capsule is blocked: " + str(row.get("name")))
        if row.get("floor_hit"):
            check(abs(point[1]-row["floor_hit"]["position"][1]) <= .45,
                  "Route end floor is far above/below its authored route: " + str(row.get("name")))

    terrain = data.get("terrain", [])
    check({row["source_id"] for row in terrain} == {"terrain:"+str(i) for i in range(25)}, "Missing/duplicate actual terrain tile identities")
    critical = [t for t in terrain if t.get("critical_full_resolution")]
    check(len(data.get("terrain", [])) == 25 and len(critical) == 9, "Exact whole terrain/critical playable tile census required")
    check(all(t["actual_triangle_count"] == 2048 for t in critical), "Playable terrain lost full-resolution triangles")
    if require_native:
        captures = data.get("captures", [])
        check(len(captures) == len(CAPTURES) and {r.get("id") for r in captures} == CAPTURES,
              "Exact reported-badspot, footbridge and whole-layout native captures required")
        if captures_dir is not None:
            from PIL import Image, ImageStat
            for name in CAPTURES:
                with Image.open(Path(captures_dir)/(name+".png")) as image:
                    image.load()
                    check(image.size == (1280, 720), "Wrong actual native image size: " + name)
                    rgb = image.convert("RGB")
                    extrema = rgb.getextrema()
                    check(max(high-low for low, high in extrema) >= 10,
                          "Native architecture capture is uniform/occluded: " + name)
                    if name != "whole-layout-overview":
                        check(max(ImageStat.Stat(rgb).stddev) >= 5,
                              "Native architecture capture does not reveal scene detail: " + name)
    return {"result": "PASS" if not failures else "FAIL", "failures": failures,
            "measurements": measurements, "source_hashes": pins,
            "scope": "Independent actual geometry/support math. Staged world collector; no campaign-completion, visual-equivalence or phone-FPS claim."}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("report", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--source-root", type=Path)
    parser.add_argument("--native", action="store_true")
    parser.add_argument("--captures-dir", type=Path)
    args = parser.parse_args()
    try:
        result = audit(json.loads(args.report.read_text()), source_root=args.source_root,
                       require_native=args.native, captures_dir=args.captures_dir)
    except Exception as error:
        result = {"result": "FAIL", "failures": [str(error)], "error_type": type(error).__name__}
    result["report_sha256"] = hashlib.sha256(args.report.read_bytes()).hexdigest()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2)+"\n")
    print("BOTANICAL LAYOUT152 INDEPENDENT: " + result["result"])
    if result["result"] != "PASS":
        for problem in result["failures"]:
            print(problem)
        raise SystemExit(1)


if __name__ == "__main__":
    main()
