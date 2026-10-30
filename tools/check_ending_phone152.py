#!/usr/bin/env python3
"""Independently audit actual shaped phone text and physical screen bounds.

This checker consumes the real ending_phone152_test.gd report. It does not
accept producer 'inside' flags as proof, nor does it start Godot. Native PNGs
are decoded when --captures-dir is supplied. A local report is not final CI
or APK acceptance; source and canonical artifact bindings remain separate.
"""
from __future__ import annotations

import argparse
import hashlib
import itertools
import json
import math
from pathlib import Path

HER = "Ты не поверишь что мне только что приснилось......"
HIS = "вещай, любимая"
SCREENS = {(1280, 720), (2582, 1220), (3088, 1440), (854, 480), (720, 1280)}
STAGES = {"draft", "message", "reply"}
FONTS = {"phone-native", "wide-pixel-stress"}
MODES = {0, 1}  # Godot Window: DISABLED, CANVAS_ITEMS.
SOURCE_PATHS = {"scripts/ending_cutscene.gd", "tools/ending_phone152_test.gd"}


def require(ok, message):
    if not ok:
        raise AssertionError(message)


def rectangle(value, label):
    require(isinstance(value, list) and len(value) == 4, label + ": missing rect")
    require(all(isinstance(x, (int, float)) and math.isfinite(x) for x in value), label + ": nonfinite rect")
    x, y, width, height = value
    require(width > 0 and height > 0, label + ": zero/negative rect")
    return x, y, x + width, y + height


def contains(inner, outer, tolerance=1.25):
    return (inner[0] >= outer[0] - tolerance and inner[1] >= outer[1] - tolerance
            and inner[2] <= outer[2] + tolerance and inner[3] <= outer[3] + tolerance)


def union(rects):
    return (min(r[0] for r in rects), min(r[1] for r in rects),
            max(r[2] for r in rects), max(r[3] for r in rects))


def intersection_area(a, b):
    return max(0, min(a[2], b[2]) - max(a[0], b[0])) * max(0, min(a[3], b[3]) - max(a[1], b[1]))


def audit(report, *, expected_source_hashes=None, require_native=False, captures_dir=None):
    require(report.get("result") == "PASS" and report.get("failures") == [], "Producer did not finish cleanly")
    require(not require_native or report.get("native") is True, "Actual native display required")
    hashes = report.get("source_hashes", {})
    require(set(hashes) == SOURCE_PATHS, "Unexpected/missing phone source pins")
    require(all(isinstance(v, str) and len(v) == 64 and all(c in "0123456789abcdef" for c in v) for v in hashes.values()), "Invalid source digest")
    if expected_source_hashes is not None:
        require(hashes == expected_source_hashes, "Phone source differs from exact reviewed source")
    cases = report.get("cases", [])
    expected = set(itertools.product(SCREENS, MODES, FONTS, STAGES))
    seen = set()
    require(len(cases) == 60 and len({r.get("case_id") for r in cases}) == 60, "Expected 60 distinct actual size/stretch/font/stage cases")
    label_count = glyph_count = 0
    minimum_effective_pixels = float("inf")
    for row in cases:
        context = row.get("case_id", "missing case id")
        screen = tuple(row.get("screen", []))
        require(screen == tuple(row.get("requested_screen", [])), context + ": framebuffer was clamped to another screen size")
        key = (screen, row.get("stretch_mode"), row.get("font_variant"), row.get("stage"))
        require(key in expected and key not in seen, context + ": repeated/unexpected case matrix cell")
        seen.add(key)
        transform = row.get("canvas_to_pixel_transform", [])
        require(len(transform) == 6 and all(isinstance(x, (float, int)) and math.isfinite(x) for x in transform), context + ": invalid physical transform")
        require(abs(transform[0] * transform[3] - transform[1] * transform[2]) > .0001, context + ": singular physical transform")
        rects = {name: rectangle(row[name + "_rect"], context + "/" + name) for name in ["device", "display", "conversation", "composer", "header"]}
        require(contains(rects["device"], (0, 0, *screen)), context + ": device escapes framebuffer")
        require(contains(rects["display"], rects["device"]), context + ": display escapes bezel")
        for child in ["conversation", "composer", "header"]:
            require(contains(rects[child], rects["display"]), context + ": " + child + " escapes display")
        require(intersection_area(rects["conversation"], rects["composer"]) <= 1.25 * screen[0], context + ": composer occludes the conversation")
        require(intersection_area(rects["conversation"], rects["header"]) <= 1.25 * screen[0], context + ": header occludes the conversation")
        labels = row.get("labels", [])
        expected_texts = [HER, HIS] if row["stage"] == "reply" else [HER]
        require([label.get("text") for label in labels] == expected_texts, context + ": exact complete outgoing/draft/reply text is absent")
        for label in labels:
            label_count += 1
            text = label["text"]
            bounds = rectangle(label["rect"], context + "/label")
            bubble = rectangle(label["bubble_rect"], context + "/bubble")
            require(contains(bounds, bubble) and contains(bounds, rects["display"]), context + ": actual label escapes bubble/display")
            parent = rects["composer"] if row["stage"] == "draft" else rects["conversation"]
            require(contains(bubble, parent), context + ": bubble escapes its actual conversation/composer")
            require(isinstance(label["lines"], int) and 0 < label["lines"] <= label["visible_lines"], context + ": shaped lines are clipped")
            expected_indices = [i for i, character in enumerate(text) if character not in " \n\t"]
            glyphs = label.get("glyph_bounds", [])
            require(len(glyphs) == label["glyphs_checked"] == len(expected_indices), context + ": some nonblank characters have no shaped bounds")
            require([g["index"] for g in glyphs] == expected_indices, context + ": missing/repeated glyph indices")
            actual_rects = []
            for glyph in glyphs:
                require(glyph["character"] == text[glyph["index"]], context + ": glyph character does not match exact text")
                actual = rectangle(glyph["rect"], context + "/glyph")
                require(contains(actual, bounds) and contains(actual, bubble) and contains(actual, rects["display"]), context + ": a shaped glyph escapes its physical text/bubble/display")
                actual_rects.append(actual)
            combined = union(actual_rects)
            declared = rectangle(label["glyph_union_rect"], context + "/glyph union")
            require(all(abs(a - b) <= 1.25 for a, b in zip(combined, declared)), context + ": glyph union does not match individual shaped bounds")
            padding = [bounds[0] - bubble[0], bounds[1] - bubble[1], bubble[2] - bounds[2], bubble[3] - bounds[3]]
            require(all(x >= -.25 for x in padding) and len(label["padding_pixels"]) == 4 and all(abs(a - b) <= 1.25 for a, b in zip(padding, label["padding_pixels"])), context + ": invalid/invented text padding")
            native_font = row["font_variant"] == "phone-native"
            expected_font_size = (16 if row["stage"] == "draft" else 18) if native_font else 24
            require(label["font_size"] == expected_font_size and label.get("font_family"), context + ": text was shrunk to evade fit constraints")
            pixels = label["effective_font_pixels"]
            require(isinstance(pixels, (int, float)) and math.isfinite(pixels) and pixels >= 9, context + ": effective text is too small")
            if screen[0] >= 2000:
                require(pixels >= 18, context + ": actual phone text is not readable at target framebuffer size")
            if screen == (720, 1280):
                require(pixels >= 12, context + ": portrait phone insert shrinks text to an unreadable size")
            minimum_effective_pixels = min(minimum_effective_pixels, pixels)
            glyph_count += len(glyphs)
    require(seen == expected, "Missing physical phone matrix cases")
    captures = report.get("captures", [])
    desired = {f"{w}x{h}-{stage}.png" for w, h in SCREENS for stage in STAGES}
    if require_native or report.get("native"):
        require(len(captures) == 15 and set(captures) == desired, "Missing/duplicated native phone captures")
    decoded = []
    if captures_dir is not None:
        from PIL import Image
        folder = Path(captures_dir)
        for name in captures:
            require(Path(name).name == name and name in desired, "Unsafe/unexpected native phone capture name")
            with Image.open(folder / name) as image:
                image.load()
                target = tuple(int(x) for x in name.split("-", 1)[0].split("x"))
                require(image.format == "PNG" and image.size == target, "Native capture dimensions differ from actual target: " + name)
            decoded.append(name)
    return {"result": "PASS", "cases": len(cases), "labels": label_count, "individually_bounded_glyphs": glyph_count,
            "minimum_effective_font_pixels": minimum_effective_pixels, "native": report.get("native") is True,
            "decoded_native_captures": decoded, "source_hashes": hashes,
            "scope": "Independent report mathematics and exact text/glyph coverage; native PNG decode when supplied. Device execution, visual appearance, final source/CI/artifact bindings are separate acceptance gates."}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("report", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--native", action="store_true")
    parser.add_argument("--captures-dir", type=Path)
    parser.add_argument("--source-root", type=Path)
    args = parser.parse_args()
    report = json.loads(args.report.read_text())
    expected = None
    if args.source_root is not None:
        expected = {path: hashlib.sha256((args.source_root / path).read_bytes()).hexdigest() for path in SOURCE_PATHS}
    try:
        result = audit(report, expected_source_hashes=expected, require_native=args.native, captures_dir=args.captures_dir)
    except (AssertionError, KeyError, TypeError, ValueError, OSError) as error:
        result = {"result": "FAIL", "failure": str(error)}
    result["report_sha256"] = hashlib.sha256(args.report.read_bytes()).hexdigest()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps(result, ensure_ascii=False))
    return 0 if result["result"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
