#!/usr/bin/env python3
"""Assemble four Runway clips into the existing silent, interactive intro.

This is an offline authoring tool. It never replaces the approved root MP4s or
edits the manifest. Supply three canonical, full-room stills and four downloaded
source videos. Review the candidates before manually promoting their bytes and
hashes. No character cutouts or synthetic joint/camera motion are introduced.

Transitions retain the filmed motion, retimed to the existing clip lengths.
Reading clips can keep a naturally cyclic take, or use a short forward/reverse
idle segment. Short endpoint blends share the exact A/B/C poses across clips.
Low-rate source footage is temporally interpolated when the target cadence
requires more pictures; the default blends neighboring frames, while optional
MCI estimates motion. Neither option replaces full-size face/step inspection.
Those blends and reversed idle motion require visual inspection: numerical
continuity does not establish a faithful face or correct anatomy.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

from prepare_intro_videos import delta, motion_frames, probe

ROOT = Path(__file__).resolve().parents[1]
FPS = 30
WIDTH, HEIGHT = 1280, 720
SPECS = (
    ("1789650644963", 121, "A", "B"),
    ("1789649201942", 125, "B", "B"),
    ("1789650878847", 121, "B", "C"),
    ("1789649329293", 121, "C", "C"),
)


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def run(command: list[str]) -> None:
    subprocess.run(command, check=True)


def still_size(path: Path) -> tuple[int, int]:
    info = json.loads(subprocess.check_output([
        "ffprobe", "-v", "error", "-select_streams", "v:0",
        "-show_entries", "stream=width,height", "-of", "json", str(path),
    ]))["streams"][0]
    return info["width"], info["height"]


def gray_endpoints(path: Path) -> tuple[bytes, bytes]:
    raw = subprocess.check_output([
        "ffmpeg", "-v", "error", "-i", str(path), "-vf", "scale=160:90,fps=30",
        "-pix_fmt", "gray", "-f", "rawvideo", "pipe:1",
    ])
    stride = 160 * 90
    if len(raw) < 2 * stride or len(raw) % stride:
        raise ValueError(f"Could not decode a full video timeline: {path}")
    return raw[:stride], raw[-stride:]


def choose_loop_mode(source: Path, requested: str) -> tuple[str, float]:
    first, last = gray_endpoints(source)
    seam = delta(first, last)
    if requested == "auto":
        return ("natural" if seam < .8 else "pingpong"), seam
    return requested, seam


def parse_time_map(spec: str, source_span: float, output_span: float) -> list[tuple[float, float]]:
    """Explicit source-second → output-second knots, never omitted states."""
    knots = []
    for pair in spec.split(","):
        a, b = pair.split(":")
        x = source_span if a.strip() == "end" else float(a)
        y = output_span if b.strip() == "end" else float(b)
        if not math.isfinite(x) or not math.isfinite(y):
            raise ValueError("Timestamp knots must be finite")
        knots.append((x, y))
    if len(knots) < 2 or abs(knots[0][0]) > .000001 or abs(knots[0][1]) > .000001:
        raise ValueError("A timestamp map must begin at 0:0")
    if abs(knots[-1][0] - source_span) > .00001 or abs(knots[-1][1] - output_span) > .00001:
        raise ValueError(f"A timestamp map must end at {source_span:g}:{output_span:g} (or end:end)")
    for a, b in zip(knots, knots[1:]):
        if b[0] <= a[0] or b[1] <= a[1]:
            raise ValueError("Timestamp maps must strictly increase in both coordinates")
    return knots


def smooth_time_expression(knots: list[tuple[float, float]]) -> str:
    """Monotone cubic Hermite timing; preserve filmed poses, not rigid layers.

    The first/last segments are linear, protecting explicit quiet lead/settle
    timing and endpoint blends. Interior positive harmonic slopes avoid abrupt
    speed changes. A balanced selector keeps FFmpeg expression depth bounded.
    """
    h = [b[0] - a[0] for a, b in zip(knots, knots[1:])]
    slopes = [(b[1] - a[1]) / span for a, b, span in zip(knots, knots[1:], h)]
    derivatives = [slopes[0]]
    for i in range(1, len(knots) - 1):
        w1, w2 = 2 * h[i] + h[i - 1], h[i] + 2 * h[i - 1]
        derivatives.append((w1 + w2) / (w1 / slopes[i - 1] + w2 / slopes[i]))
    derivatives.append(slopes[-1])
    if len(knots) > 2:
        derivatives[1] = slopes[0]
        derivatives[-2] = slopes[-1]
    # Fritsch–Carlson bound protects monotonicity for unusually steep user maps.
    for i, slope in enumerate(slopes):
        alpha, beta = derivatives[i] / slope, derivatives[i + 1] / slope
        norm = math.hypot(alpha, beta)
        if norm > 3:
            factor = 3 / norm
            derivatives[i] = factor * alpha * slope
            derivatives[i + 1] = factor * beta * slope
    time = "((PTS-STARTPTS)*TB)"
    segments = []
    for i, ((x, y), (_, end_y), span) in enumerate(zip(knots, knots[1:], h)):
        u = f"(({time}-{x:.15g})/{span:.15g})"
        a = 2 * y - 2 * end_y + span * (derivatives[i] + derivatives[i + 1])
        b = -3 * y + 3 * end_y - span * (2 * derivatives[i] + derivatives[i + 1])
        c = span * derivatives[i]
        segments.append(f"((({a:.15g}*{u}+{b:.15g})*{u}+{c:.15g})*{u}+{y:.15g})")
    def select(lo: int, hi: int) -> str:
        if hi - lo == 1:
            return segments[lo]
        mid = (lo + hi) // 2
        return f"if(lt({time},{knots[mid][0]:.15g}),{select(lo, mid)},{select(mid, hi)})"
    return f"'({select(0, len(segments))})/TB'"


def graph_for_clip(
    source_info: dict, count: int, mode: str,
    head_frames: int, tail_frames: int, interpolation: str,
    window_seconds: float | None = None,
    time_map: list[tuple[float, float]] | None = None,
) -> str:
    """Use timestamp weights so the first/last pictures are canonical stills."""
    end_time = (count - 1) / FPS
    head_seconds, tail_seconds = head_frames / FPS, tail_frames / FPS
    fit = (
        f"scale={WIDTH}:{HEIGHT}:flags=lanczos:force_original_aspect_ratio=decrease,"
        f"pad={WIDTH}:{HEIGHT}:(ow-iw)/2:(oh-ih)/2:color=black,setsar=1"
    )
    source_span = (source_info["frames"] - 1) / source_info["fps"]
    if source_span <= 0:
        raise ValueError("A filmed source needs at least two decoded pictures")
    half = (count + 1) // 2
    window_frames = None
    if window_seconds is not None:
        if mode != "pingpong":
            raise ValueError("A reading source window requires ping-pong assembly")
        if not 0 < window_seconds <= source_info["frames"] / source_info["fps"] + .001:
            raise ValueError("Reading source window must fit inside the filmed source")
        window_frames = min(source_info["frames"], 1 + math.floor(window_seconds * source_info["fps"] + .000001))
        if window_frames < 2:
            raise ValueError("Reading source window must contain at least two source pictures")
        selected_span = (window_frames - 1) / source_info["fps"]
        ratio = ((half - 1) / FPS) / selected_span
    else:
        ratio = 1.0 if mode == "pingpong" else end_time / source_span
    effective_rate = source_info["fps"] / ratio
    if effective_rate < FPS - .001 or time_map is not None:
        if interpolation == "mci":
            cadence = (
                f"minterpolate=fps={FPS}:mi_mode=mci:mc_mode=obmc:me_mode=bilat:"
                "me=epzs:mb_size=16:search_param=16:vsbmc=0"
            )
        else:
            cadence = f"framerate=fps={FPS}:interp_start=0:interp_end=255"
    else:
        cadence = f"fps={FPS}:start_time=0:round=near"
    graph: list[str] = []
    if mode == "pingpong":
        # Odd clip lengths give F0..Fk,F(k-1)..F0 with no repeated turn picture.
        if window_frames is None and source_info["frames"] / source_info["fps"] + .001 < half / FPS:
            raise ValueError(f"Idle source is shorter than the {half / FPS:.3f}s loop window")
        trim_window = f"trim=end_frame={window_frames}," if window_frames is not None else ""
        graph.append(
            f"[0:v]{trim_window}setpts={ratio:.15g}*(PTS-STARTPTS),{fit},format=yuv420p,"
            f"tpad=stop_mode=clone:stop_duration=0.25,{cadence},"
            f"format=gbrp,tpad=stop_mode=clone:stop_duration=1,trim=end_frame={half},"
            f"setpts=N/({FPS}*TB),split=2[forward][back_source]"
        )
        graph.append("[back_source]reverse,trim=start_frame=1,setpts=PTS-STARTPTS[backward]")
        graph.append("[forward][backward]concat=n=2:v=1:a=0[filmed]")
    else:
        # tpad only supplies an endpoint rounding frame; trim fixes the contract.
        timestamp = smooth_time_expression(time_map) if time_map is not None else f"{ratio:.15g}*(PTS-STARTPTS)"
        graph.append(
            f"[0:v]setpts={timestamp},{fit},format=yuv420p,"
            f"tpad=stop_mode=clone:stop_duration=0.25,{cadence},format=gbrp,"
            f"tpad=stop_mode=clone:stop_duration=1,trim=end_frame={count},"
            f"setpts=N/({FPS}*TB)[filmed]"
        )
    for index, name in [(1, "start"), (2, "end")]:
        graph.append(
            f"[{index}:v]{fit},format=rgba,"
            f"loop=loop=-1:size=1:start=0,trim=end_frame={count},setpts=N/({FPS}*TB)[{name}]"
        )
    # Native fade/overlay kernels compute one opacity per frame. A per-pixel
    # blend expression repeats timestamp arithmetic millions of times needlessly.
    graph.append(f"[start]fade=t=out:st=0:d={head_seconds:.15g}:alpha=1[start_fade]")
    graph.append(f"[end]fade=t=in:st={end_time-tail_seconds:.15g}:d={tail_seconds:.15g}:alpha=1[end_fade]")
    graph.append("[filmed][start_fade]overlay=shortest=1:format=gbrp[head]")
    graph.append("[head][end_fade]overlay=shortest=1:format=gbrp,")
    # State the RGB→YUV matrix explicitly; encode matching HD color metadata.
    graph[-1] += "scale=in_range=full:out_range=tv:out_color_matrix=bt709,format=yuv420p[out]"
    return ";".join(graph)


def assemble(
    source: Path, start: Path, end: Path, target: Path,
    source_info: dict, count: int, mode: str, head_frames: int, tail_frames: int,
    interpolation: str, window_seconds: float | None = None,
    time_map: list[tuple[float, float]] | None = None,
) -> None:
    graph = graph_for_clip(source_info, count, mode, head_frames, tail_frames, interpolation, window_seconds, time_map)
    run([
        "ffmpeg", "-hide_banner", "-loglevel", "error", "-y",
        "-threads", "2", "-i", str(source),
        "-framerate", str(FPS), "-i", str(start),
        "-framerate", str(FPS), "-i", str(end),
        "-filter_complex_threads", "1", "-filter_complex", graph,
        "-map", "[out]", "-an", "-frames:v", str(count), "-r", str(FPS),
        "-fps_mode", "cfr", "-c:v", "libx264", "-preset", "medium", "-crf", "16",
        "-g", "30", "-keyint_min", "30", "-sc_threshold", "0", "-threads", "2",
        "-force_key_frames", f"expr:eq(n,0)+eq(n,{count-1})",
        "-pix_fmt", "yuv420p", "-color_range", "tv", "-colorspace", "bt709",
        "-color_trc", "bt709", "-color_primaries", "bt709", "-movflags", "+faststart",
        str(target),
    ])


def validate_sequence(paths: list[Path], theora: bool = False) -> tuple[list[dict], list[str]]:
    rows, failures = [], []
    previous = None
    for index, (path, (_, count, _, _)) in enumerate(zip(paths, SPECS)):
        actual = probe(path)
        row = {"file": path.name, **actual, "bytes": path.stat().st_size, "sha256": sha256(path)}
        if (actual["width"], actual["height"]) != (WIDTH, HEIGHT):
            failures.append(f"{path.name}: expected {WIDTH}x{HEIGHT}")
        if abs(actual["fps"] - FPS) >= .001:
            failures.append(f"{path.name}: expected {FPS}fps")
        minimum = math.ceil(count * .9) if theora else count
        if not minimum <= actual["frames"] <= count:
            failures.append(f"{path.name}: invalid decoded-picture coverage")
        if abs(round(actual["duration"] * FPS) - count) > 1:
            failures.append(f"{path.name}: invalid duration")
        if abs(actual["duration"] - count / FPS) > 1 / FPS + .0001:
            failures.append(f"{path.name}: invalid timeline span")
        if theora and not 10_000 < row["bytes"] < 20_000_000:
            failures.append(f"{path.name}: outside runtime size limits")
        decoded = motion_frames(path, count, FPS)
        row.update(
            timeline_frames=len(decoded),
            boundary_delta=delta(previous, decoded[0]) if previous is not None else 0.,
            loop_delta=delta(decoded[-1], decoded[0]),
            max_frame_delta=max(delta(a, b) for a, b in zip(decoded, decoded[1:])),
        )
        if row["boundary_delta"] >= .8:
            failures.append(f"{path.name}: boundary {row['boundary_delta']:.4f} >= .8")
        if index in [1, 3] and row["loop_delta"] >= .8:
            failures.append(f"{path.name}: reading-loop seam {row['loop_delta']:.4f} >= .8")
        if row["max_frame_delta"] >= 2.5:
            failures.append(f"{path.name}: frame jump {row['max_frame_delta']:.4f} >= 2.5")
        previous = decoded[-1]
        rows.append(row)
    return rows, failures


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--a", type=Path, required=True, help="Canonical sleep/no-child full-room still")
    parser.add_argument("--b", type=Path, required=True, help="Canonical awake/reclining + child doorway still")
    parser.add_argument("--c", type=Path, required=True, help="Canonical seated + child holding plush still")
    for index in range(4):
        parser.add_argument(f"--video{index}", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, default=ROOT.parent / "scratch" / "intro-runway-candidates")
    parser.add_argument("--head-blend-seconds", type=float, default=8 / FPS)
    parser.add_argument("--tail-blend-seconds", type=float, default=8 / FPS)
    parser.add_argument("--loop-mode", choices=["auto", "natural", "pingpong"], default="auto")
    parser.add_argument("--loop1-window-seconds", type=float,
                        help="Use only this initial source window for reading loop1, slowed to the forward half, then reverse")
    parser.add_argument("--loop3-window-seconds", type=float,
                        help="Use only this initial source window for reading loop3, slowed to the forward half, then reverse")
    parser.add_argument("--interpolation", choices=["blend", "mci"], default="blend",
                        help="Temporal upsampling when needed; inspect face/hair ghosting or motion-warp artifacts")
    for index in [0, 2]:
        parser.add_argument(f"--time-map{index}",
                            help="Optional smooth source:output second knots for this transition, e.g.0:0,1:0.55,3.5:3.25,end:end")
    parser.add_argument("--overwrite", action="store_true", help="Allow replacing candidates in a staging directory, never root masters")
    parser.add_argument("--keep-work", action="store_true", help="Retain intermediate Theora/candidate files for visual diagnosis")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    output = args.output_dir.resolve()
    if output == ROOT:
        raise ValueError("Stage outside the repository root; reviewed masters must be promoted manually")
    frames = {name: getattr(args, name.lower()).resolve() for name in "ABC"}
    sources = [getattr(args, f"video{i}").resolve() for i in range(4)]
    for path in [*frames.values(), *sources]:
        if not path.is_file():
            raise FileNotFoundError(path)
    for name, path in frames.items():
        width, height = still_size(path)
        if abs(width / height / (16 / 9) - 1) > .01:
            raise ValueError(f"Canonical {name} must be a full near-16:9 frame, got {width}x{height}")
    head_frames = round(args.head_blend_seconds * FPS)
    tail_frames = round(args.tail_blend_seconds * FPS)
    if min(head_frames, tail_frames) < 1 or max(head_frames, tail_frames) > 30:
        raise ValueError("Endpoint blends must be between 1/30 and 1 second")
    targets = [output / f"{stem}.mp4" for stem, _, _, _ in SPECS]
    protected = {(ROOT / f"{stem}.mp4").resolve() for stem, _, _, _ in SPECS}
    for target in targets:
        if target.resolve() in protected:
            raise ValueError(f"Refusing to overwrite an approved master: {target}")
        if target.exists() and not args.overwrite:
            raise FileExistsError(f"Candidate exists: {target}; use a new staging directory or explicit --overwrite")
        if target.resolve() in {path.resolve() for path in sources}:
            raise ValueError(f"Output cannot replace an input source: {target}")
    output.mkdir(parents=True, exist_ok=True)
    work = Path(tempfile.mkdtemp(prefix="assembly-", dir=output))
    report = {
        "kind": "runway_intro_candidates", "fps": FPS, "runtime_resolution": [WIDTH, HEIGHT],
        "head_blend_frames": head_frames, "tail_blend_frames": tail_frames,
        "temporal_upsampling": args.interpolation, "image_fit": "aspect-fit with padding; no stretch",
        "canonical_frames": {name: {"path": str(path), "sha256": sha256(path)} for name, path in frames.items()},
        "sources": [], "failures": [], "visual_review_required": [
            "New heroine's face, hair, proportions and identity across every shot",
            "Hands/anatomy, child/cat/room continuity and lighting",
            "Endpoint blend ghosting and reversed hair/body motion at idle turns",
        ],
        "note": "Numerical continuity is not likeness approval. No approved root source or manifest is modified.",
    }
    try:
        candidates = []
        for index, (source, (stem, count, start, end)) in enumerate(zip(sources, SPECS)):
            info = probe(source)
            mode, raw_seam = (choose_loop_mode(source, args.loop_mode) if index in [1, 3] else ("transition", None))
            window = getattr(args, f"loop{index}_window_seconds", None)
            if window is not None:
                if args.loop_mode == "natural":
                    raise ValueError("Source windows require --loop-mode auto or pingpong")
                mode = "pingpong"
            map_spec = getattr(args, f"time_map{index}", None)
            time_map = parse_time_map(map_spec, (info["frames"] - 1) / info["fps"], (count - 1) / FPS) if map_spec else None
            report["sources"].append({
                "path": str(source), "sha256": sha256(source), "assembly_mode": mode,
                "raw_loop_delta": raw_seam, "reading_source_window_seconds": window, **info,
                "timestamp_map_seconds": time_map,
            })
            target = work / f"{stem}.mp4"
            assemble(source, frames[start], frames[end], target, info, count, mode,
                     head_frames, tail_frames, args.interpolation, window, time_map)
            candidates.append(target)
        report["mp4"], mp4_failures = validate_sequence(candidates)
        report["failures"].extend(mp4_failures)
        theoras = []
        for path, (_, count, _, _) in zip(candidates, SPECS):
            target = path.with_suffix(".ogv")
            run([
                "ffmpeg", "-v", "error", "-y", "-i", str(path), "-map", "0:v:0",
                "-vf", "scale=1280:720:flags=lanczos,setsar=1", "-fps_mode", "passthrough",
                "-c:v", "libtheora", "-q:v", "9", "-g", "60", "-an", str(target),
            ])
            theoras.append(target)
        report["theora"], theora_failures = validate_sequence(theoras, theora=True)
        report["failures"].extend(theora_failures)
        if report["failures"]:
            raise ValueError("Candidates failed existing continuity gates; inspect assembly-report.json")
        for source, target in zip(candidates, targets):
            source.replace(target)
        report["candidate_paths"] = [str(path) for path in targets]
        print("RUNWAY INTRO ASSEMBLY: PASS — exact frames, source motion, canonical boundaries and Theora continuity")
        return 0
    except Exception as exc:
        report["error"] = f"{type(exc).__name__}: {exc}"
        report["work_dir"] = str(work)
        print(report["error"], file=sys.stderr)
        return 1
    finally:
        (output / "assembly-report.json").write_text(json.dumps(report, indent=2) + "\n")
        if not args.keep_work and not report.get("error"):
            shutil.rmtree(work)


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(f"RUNWAY INTRO ASSEMBLY: {type(exc).__name__}: {exc}", file=sys.stderr)
        raise SystemExit(1)
