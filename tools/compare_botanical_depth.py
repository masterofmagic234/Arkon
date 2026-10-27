#!/usr/bin/env python3
"""Strict whole-frame visual gate for leaf ordering, under baked lighting."""
from pathlib import Path
import argparse
import json
from PIL import Image, ImageChops, ImageStat

parser = argparse.ArgumentParser()
parser.add_argument("directory", type=Path)
args = parser.parse_args()
rows = json.loads((args.directory / "depth.json").read_text())
views = sorted({row["view"] for row in rows})
failures, results = [], []
for view in views:
    before = Image.open(args.directory / f"{view}-1.40.png").convert("RGB")
    after = Image.open(args.directory / f"{view}-depth.png").convert("RGB")
    if before.size != after.size:
        failures.append(f"{view}: image dimensions changed")
        continue
    delta = ImageChops.difference(before, after)
    mae = sum(ImageStat.Stat(delta).mean) / 3
    red, green, blue = delta.split()
    histogram = ImageChops.lighter(ImageChops.lighter(red, green), blue).histogram()
    changed = sum(histogram[9:]) / (before.width * before.height)
    if mae > .2 or changed > .001:
        failures.append(f"{view}: MAE {mae:.6f}, changed >8 {changed:.6%}")
    pair = [row for row in rows if row["view"] == view]
    if len(pair) != 2 or {r["depth_enabled"] for r in pair} != {True, False}:
        failures.append(f"{view}: missing production / 1.40 control")
    results.append({"view": view, "mean_error_255": mae, "changed_gt8_fraction": changed, "workload": pair})
report = {"views": results, "failures": failures, "note": "Whole-frame MAE <= .2/255 and changed >8 <= .1%; same baked light, geometry, masks, textures, camera, MSAA and resolution. Software GPU is not P60 FPS."}
(args.directory / "comparison.json").write_text(json.dumps(report, indent=2) + "\n")
print(json.dumps(report, indent=2))
raise SystemExit(bool(failures))
