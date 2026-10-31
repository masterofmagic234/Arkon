#!/usr/bin/env python3
"""Check a real 1.47/1.48 Compatibility ABBA capture, without pixel identity.

The user's priority is throughput. Report visible scene changes and actual
structural reductions; keep all measured samples and timing drift explicit.
Native software-GPU timings remain software measurements, never device FPS.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path
import statistics

from PIL import Image, ImageChops, ImageStat


def require(ok, reason, failures):
    if not ok:
        failures.append(reason)


def geometric(values):
    return math.exp(sum(math.log(x) for x in values) / len(values)) if values else None


def flatten(blocks, field):
    return [float(v) for block in blocks for v in block[field]["samples"]]


def compare(path: Path, frozen: Path | None = None):
    data = json.loads(path.read_text())
    failures, warnings, views = [], [], []
    require(not data.get("failures"), "capture reported runtime contract failures", failures)
    require(data.get("renderer") == "gl_compatibility", "wrong native renderer", failures)
    require(not data.get("isolated_original_147"), "isolated baseline alone cannot prove an optimization", failures)
    require(data.get("depth_prepass_setting") is False, "phone-like Adreno depth policy was not set before process startup", failures)
    require(data.get("max_fps") == 0 and data.get("vsync") == 0, "A/B was frame capped", failures)
    expected = {"entry-3088x1440", "pond-3088x1440", "conservatory-3088x1440", "upper-3088x1440", "west-ramp-3088x1440", "entry-reverse-3088x1440", "entry-1280x720"}
    require({v["view"] for v in data["views"]} == expected, "incomplete phone/desktop camera coverage", failures)
    reference_source = json.loads(frozen.read_text()) if frozen else None
    frozen_views = {v["view"]: v for v in reference_source["views"]} if reference_source else {}
    if reference_source:
        require(reference_source.get("isolated_original_147") is True, "independent baseline is not the frozen original", failures)
        require(reference_source.get("source_commit") == data.get("baseline_commit"), "independent 1.47 source commit differs", failures)
        require(reference_source.get("depth_prepass_setting") is False, "independent baseline used a different depth policy", failures)
    for item in data["views"]:
        name = item["view"]
        blocks = item["blocks"]
        require([b["profile"] for b in blocks] == ["reference147", "production148", "production148", "reference147"], name + ": incomplete ABBA sequence", failures)
        if len(blocks) != 4:
            continue
        a, b = [blocks[0], blocks[3]], [blocks[1], blocks[2]]
        for block in blocks:
            for field in ("frame_ms", "draw_calls", "triangles"):
                values = block[field]["samples"]
                require(len(values) >= 3 and all(math.isfinite(float(x)) and float(x) > 0 for x in values), name + ": invalid or undersampled " + field, failures)
        require(abs(float(item["nominal_3d_pixels"]) - 921600) < 5, name + ": pixel cap changed", failures)
        require(item["msaa"] == 1 and item["fov"] == 65, name + ": MSAA/FOV changed", failures)
        call_a, call_b = statistics.median(flatten(a, "draw_calls")), statistics.median(flatten(b, "draw_calls"))
        tri_a, tri_b = statistics.median(flatten(a, "triangles")), statistics.median(flatten(b, "triangles"))
        time_a, time_b = statistics.median(flatten(a, "frame_ms")), statistics.median(flatten(b, "frame_ms"))
        drift = float(a[1]["frame_ms"]["median"]) / float(a[0]["frame_ms"]["median"])
        timing_stable = abs(math.log(drift)) <= math.log(1.25)
        if not timing_stable:
            warnings.append(name + ": baseline brackets drift by over 25%; retain raw timings, do not interpret this view as a device speed measurement")
        require(abs(float(a[0]["draw_calls"]["median"]) - float(a[1]["draw_calls"]["median"])) <= 1, name + ": reference scene draw calls changed across brackets", failures)
        require(abs(float(a[0]["triangles"]["median"]) - float(a[1]["triangles"]["median"])) <= max(600, tri_a * .01), name + ": reference geometry did not restore", failures)
        ref_image_path = path.parent / name / a[0]["image"]
        new_image_path = path.parent / name / b[0]["image"]
        with Image.open(ref_image_path) as ai, Image.open(new_image_path) as bi:
            ai.load(); bi.load()
            require(list(ai.size) == item["window"] and ai.size == bi.size, name + ": native frames have incorrect/different size", failures)
            ar, br = ai.convert("RGB"), bi.convert("RGB")
            ast, bst = ImageStat.Stat(ar), ImageStat.Stat(br)
            require(max(bst.stddev) > 4, name + ": blank/constant production frame", failures)
            ma = sum(ast.mean) / 3
            mb = sum(bst.mean) / 3
            require(ma * .25 < mb < max(12, ma * 3), name + ": gross missing exposure or scene", failures)
            image_report = {"reference_mean_rgb": ast.mean, "production_mean_rgb": bst.mean, "mean_absolute_change_255": sum(ImageStat.Stat(ImageChops.difference(ar, br)).mean) / 3, "reference_sha256": hashlib.sha256(ref_image_path.read_bytes()).hexdigest(), "production_sha256": hashlib.sha256(new_image_path.read_bytes()).hexdigest(), "note": "Image change is reported for human review; foliage density, LOD and lighting approximations are authorized. No old tiny-MAE gate."}
        if name in frozen_views:
            original = frozen_views[name]
            require(original["window"] == item["window"] and abs(original["scale_3d"] - item["scale_3d"]) < .00001 and original["msaa"] == item["msaa"], name + ": independent original uses different pixels/MSAA", failures)
            original_image = frozen.parent / name / original["blocks"][0]["image"]
            with Image.open(original_image) as oi, Image.open(ref_image_path) as ri:
                require(oi.size == ri.size, name + ": independent reference dimensions differ", failures)
                delta = sum(ImageStat.Stat(ImageChops.difference(oi.convert("RGB"), ri.convert("RGB"))).mean) / 3
            image_report["independent_original_147_mean_error_255"] = delta
            # The reference path must actually restore the original garden.
            # This applies only to A=1.47, never to the optimized image.
            require(delta <= .35, name + ": claimed 1.47 reference differs from frozen 1.47", failures)
        views.append({"view": name, "reference_calls": call_a, "production_calls": call_b, "draw_call_ratio": call_b / call_a, "reference_triangles": tri_a, "production_triangles": tri_b, "triangle_ratio": tri_b / tri_a, "reference_frame_ms": time_a, "production_frame_ms": time_b, "software_speedup": time_a / time_b, "reference_bracket_ratio": drift, "timing_stable": timing_stable, "image": image_report})
    phone = [v for v in views if v["view"].endswith("3088x1440")]
    call_ratio = geometric([v["draw_call_ratio"] for v in phone])
    triangle_ratio = geometric([v["triangle_ratio"] for v in phone])
    # Submission work must materially decrease, rather than merely passing the
    # old 500-call/260k cap. The paired timing remains separately visible.
    if call_ratio and triangle_ratio:
        require(call_ratio * triangle_ratio <= .55, "geometry/submission work was not materially reduced vs 1.47", failures)
        require(triangle_ratio <= .80, "production retained over 80% of baseline submitted triangles", failures)
        require(call_ratio <= 1.05, "draw-call cost grew despite the CPU-render bottleneck", failures)
    moving = {v["profile"]: v for v in data.get("moving", [])}
    require(set(moving) == {"reference147", "production148"}, "missing moving CPU/upload comparison", failures)
    movement_report = {}
    if len(moving) == 2:
        a, b = moving["reference147"], moving["production148"]
        require(a["steps"] == b["steps"] and a["steps"] >= 60, "moving routes differ or are too short", failures)
        require(b["stationary_uploads"] == 0, "stationary production camera uploads buffers", failures)
        p95_ratio = float(b["visibility_update_us"]["p95"]) / max(1, float(a["visibility_update_us"]["p95"]))
        median_ratio = float(b["visibility_update_us"]["median"]) / max(1, float(a["visibility_update_us"]["median"]))
        require(median_ratio <= .70, "walking/turning visibility CPU did not improve by at least 30%", failures)
        if int(a["buffer_upload_bytes"]) > 0:
            require(int(b["buffer_upload_bytes"]) <= int(a["buffer_upload_bytes"]) * .65, "moving buffer traffic did not fall by at least 35%", failures)
        movement_report = {"median_cpu_ratio": median_ratio, "p95_cpu_ratio": p95_ratio, "reference_uploads": a["buffer_uploads"], "production_uploads": b["buffer_uploads"], "reference_upload_bytes": a["buffer_upload_bytes"], "production_upload_bytes": b["buffer_upload_bytes"]}
    return {"result": "PASS" if not failures else "FAIL", "failures": failures, "warnings": warnings, "baseline_commit": data.get("baseline_commit"), "source_commit": data.get("source_commit"), "renderer": data.get("renderer"), "adapter": data.get("adapter"), "phone_geomean_draw_call_ratio": call_ratio, "phone_geomean_triangle_ratio": triangle_ratio, "advisory_software_geomean_speedup": geometric([v["software_speedup"] for v in phone]), "views": views, "movement": movement_report, "note": "Original 1.47 vs production 1.48 at matched pixels/MSAA and Adreno-like no-prepass startup policy. Work/CPU gates are explicit; software timing includes identical readback and cannot establish Huawei/Samsung FPS. Native frames require visual review."}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("capture", type=Path)
    parser.add_argument("--baseline-147", type=Path)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    report = compare(args.capture, args.baseline_147)
    output = args.output or args.capture.parent / "comparison.json"
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report, indent=2))
    if report["failures"]:
        return 1
    print("BOTANICAL OPTIMIZATION: PASS — substantial actual submission/CPU/traffic reduction vs 1.47; images retained; software timing is advisory")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
