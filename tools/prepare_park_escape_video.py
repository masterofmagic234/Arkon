#!/usr/bin/env python3
"""Assemble and validate the silent monochrome park-departure manga film.

Authoring: --assemble --raw-dir <four reviewed takes> --output-dir <staging>
creates a candidate film.mp4 and assembly-report.json outside the repository.
The full first-to-last action of each take is retimed to its timeline slot;
neighboring source pictures are blended when more temporal samples are needed.
--nearest-shots scouts keeps that shot on original, crisp source pictures at
its natural retimed manga cadence while the container remains 30fps CFR. Use
this explicit option when blending a fast ink gesture doubles eyes or ears.
There are intentional hard cuts between slots, not decoder handoffs.

Build: the default mode checks the reviewed master SHA256 in
art/intro/park_escape145/authoring.json, converts it to q9 Theora, validates the
actual runtime timeline and writes compiled.json. --check skips conversion.
Requires only Python3 and FFmpeg/ffprobe with libx264 and libtheora. Numerical
checks do not establish likeness, anatomy or convincing vehicle motion.
"""
from __future__ import annotations

import argparse
from fractions import Fraction
import hashlib
import json
import math
from pathlib import Path
import shlex
import shutil
import subprocess
import sys
import tempfile


ROOT = Path(__file__).resolve().parents[1]
AUTHORING = ROOT / "art/intro/park_escape145/authoring.json"
TIMELINE = ROOT / "assets/cinematics/park_escape/timeline.json"
RUNTIME = TIMELINE.parent
APPROVED_MASTER = AUTHORING.parent / "film.mp4"
FPS = 30
SIZE = (1280, 720)
SAMPLE = (160, 90)
SHOT_IDS = ("departure", "scouts", "commander", "helicopter")


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for block in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def run(command: list[str]) -> None:
    subprocess.run(command, check=True)


def probe(path: Path) -> dict:
    data = json.loads(subprocess.check_output([
        "ffprobe", "-v", "error", "-count_frames", "-show_entries",
        "stream=codec_type,codec_name,width,height,avg_frame_rate,r_frame_rate,nb_read_frames:format=duration",
        "-of", "json", str(path),
    ]))
    videos = [stream for stream in data["streams"] if stream["codec_type"] == "video"]
    if len(videos) != 1:
        raise ValueError(f"Expected one video stream: {path}")
    video = videos[0]
    rate = video["avg_frame_rate"]
    if rate == "0/0":
        rate = video["r_frame_rate"]
    result = {
        "codec": video["codec_name"], "width": video["width"], "height": video["height"],
        "fps": float(Fraction(rate)), "frames": int(video["nb_read_frames"]),
        "duration": float(data["format"]["duration"]),
        "audio_streams": sum(stream["codec_type"] == "audio" for stream in data["streams"]),
    }
    if not math.isfinite(result["fps"]) or result["fps"] <= 0 or result["frames"] < 1:
        raise ValueError(f"Invalid source cadence or picture count: {path}")
    return result


def timeline(path: Path) -> dict:
    data = json.loads(path.read_text())
    if data.get("version") != 1 or data.get("fps") != FPS or data.get("resolution") != list(SIZE):
        raise ValueError("Expected version1,1280x720,30fps timeline metadata")
    duration = float(data["duration"])
    if not math.isfinite(duration) or duration <= 0:
        raise ValueError("Invalid film duration")
    shots = data["shots"]
    if tuple(shot["id"] for shot in shots) != SHOT_IDS:
        raise ValueError(f"Expected the four ordered shots: {SHOT_IDS}")
    previous = 0
    for shot in shots:
        start, end = float(shot["start"]), float(shot["end"])
        if not all(math.isfinite(value) for value in [start, end]) or abs(start - previous) > .000001 or end <= start:
            raise ValueError("Shots must cover one continuous, ordered timeline")
        for value in [start, end]:
            if abs(value * FPS - round(value * FPS)) > .00001:
                raise ValueError("Shot boundaries must align with 30fps frames")
        previous = end
    if abs(previous - duration) > .000001:
        raise ValueError("Shots do not cover the film duration")
    return data


def decode_samples(path: Path) -> tuple[list[bytes], dict]:
    """Reconstruct repeat packets as a full CFR timeline; inspect real chroma."""
    width, height = SAMPLE
    luma_size = width * height
    stride = luma_size * 3 // 2
    raw = subprocess.check_output([
        "ffmpeg", "-v", "error", "-xerror", "-i", str(path), "-map", "0:v:0",
        "-vf", f"scale={width}:{height}:flags=area,setsar=1,fps={FPS}",
        "-pix_fmt", "yuv420p", "-f", "rawvideo", "pipe:1",
    ])
    if not raw or len(raw) % stride:
        raise ValueError(f"Incomplete decoded sample: {path}")
    frames = []
    chroma_sum, chroma_max, chroma_count = 0, 0, 0
    for offset in range(0, len(raw), stride):
        frames.append(raw[offset:offset + luma_size])
        chroma = raw[offset + luma_size:offset + stride]
        deviations = [abs(value - 128) for value in chroma]
        chroma_sum += sum(deviations)
        chroma_max = max(chroma_max, max(deviations))
        chroma_count += len(chroma)
    return frames, {
        "mean_chroma_deviation": chroma_sum / chroma_count,
        "max_chroma_deviation": chroma_max,
        "neutral_chroma": 128,
    }


def mean_delta(a: bytes, b: bytes) -> float:
    return sum(abs(x - y) for x, y in zip(a, b)) / len(a)


def validate(path: Path, spec: dict, theora: bool = False) -> dict:
    info = probe(path)
    count = round(float(spec["duration"]) * FPS)
    expected_codec = "theora" if theora else "h264"
    if info["codec"] != expected_codec or info["audio_streams"]:
        raise ValueError(f"Expected silent {expected_codec}: {path}")
    if (info["width"], info["height"]) != SIZE or abs(info["fps"] - FPS) >= .001:
        raise ValueError(f"Wrong dimensions/frame rate: {info}")
    tolerance = 1 / FPS + .0001 if theora else .0001
    if abs(info["duration"] - count / FPS) > tolerance:
        raise ValueError(f"Truncated or extended film timeline: {info}")
    if not theora and info["frames"] != count:
        raise ValueError(f"Master must contain exactly {count} pictures: {info}")
    # Theora legally represents held manga pictures with repeat packets. Its
    # decoded-picture count is not the playback timeline: validate reconstructed
    # coverage and actual movement within each shot instead of a 90% quota.
    if theora and not 0 < info["frames"] <= count + 1:
        raise ValueError(f"Invalid Theora decoded-picture count: {info}")
    frames, gray = decode_samples(path)
    frame_tolerance = 1 if theora else 0
    if abs(len(frames) - count) > frame_tolerance:
        raise ValueError(f"Expected {count} CFR timeline samples, decoded {len(frames)}")
    if gray["max_chroma_deviation"] > 2 or gray["mean_chroma_deviation"] > .25:
        raise ValueError(f"Film is not neutral grayscale: {gray}")
    blanks = [index for index, picture in enumerate(frames)
              if max(picture) - min(picture) < 3 and (max(picture) < 24 or min(picture) > 230)]
    if blanks:
        raise ValueError(f"Unexpected blank video pictures: {blanks[:12]}")
    shots = []
    for shot in spec["shots"]:
        start, end = round(shot["start"] * FPS), round(shot["end"] * FPS)
        pictures = frames[start:end]
        changes = [mean_delta(a, b) for a, b in zip(pictures, pictures[1:])]
        moving = sum(change > .01 for change in changes)
        if len(pictures) < end - start - frame_tolerance or moving < 3:
            raise ValueError(f"Missing timeline coverage or real motion in shot {shot['id']}")
        shots.append({
            **shot, "timeline_frames": len(pictures), "moving_transitions": moving,
            "mean_frame_delta": sum(changes) / len(changes), "max_frame_delta": max(changes),
        })
    return {
        "file": path.name, **info, "expected_frames": count, "timeline_frames": len(frames),
        "bytes": path.stat().st_size, "sha256": sha256(path), "grayscale": gray, "shots": shots,
        "note": "Intentional hard cuts are excluded from per-shot motion metrics; visual review remains required.",
    }


def assemble(raw_dir: Path, output: Path, spec: dict, overwrite: bool, keep_work: bool,
             nearest_shots: set[str]) -> None:
    output = output.resolve()
    if output == ROOT or output.is_relative_to(ROOT):
        raise ValueError("Stage assembly candidates outside the repository; never replace the approved master automatically")
    target = output / "film.mp4"
    if target.resolve() == APPROVED_MASTER.resolve() or (target.exists() and not overwrite):
        raise ValueError(f"Candidate exists or is protected: {target}")
    sources = [raw_dir / f"{shot['id']}.mp4" for shot in spec["shots"]]
    if any(target.resolve() == source.resolve() for source in sources):
        raise ValueError("An assembly output cannot overwrite an input")
    output.mkdir(parents=True, exist_ok=True)
    work = Path(tempfile.mkdtemp(prefix="assembly-", dir=output))
    nearest = [name for name in SHOT_IDS if name in nearest_shots]
    command = ["python3", "tools/prepare_park_escape_video.py", "--assemble",
               "--raw-dir", str(raw_dir), "--output-dir", str(output)]
    if nearest:
        command += ["--nearest-shots", *nearest]
    report = {"kind": "park_escape_candidates", "fps": FPS, "resolution": list(SIZE),
              "duration": spec["duration"], "sources": [], "nearest_shots": nearest,
              "reproduction_command": shlex.join(command),
              "note": "Candidate only; no approved source or manifest is modified."}
    try:
        pieces = []
        for source, shot in zip(sources, spec["shots"]):
            info = probe(source)
            count = round((shot["end"] - shot["start"]) * FPS)
            source_span = (info["frames"] - 1) / info["fps"]
            if source_span <= 0 or count < 2:
                raise ValueError(f"Source needs at least two filmed pictures: {source}")
            ratio = ((count - 1) / FPS) / source_span
            fit = (f"scale={SIZE[0]}:{SIZE[1]}:flags=lanczos:force_original_aspect_ratio=decrease,"
                   f"pad={SIZE[0]}:{SIZE[1]}:(ow-iw)/2:(oh-ih)/2:color=black,setsar=1")
            # eq=saturation=0 rounds neutral chroma to127 in some FFmpeg
            # builds. Explicit centre values keep the delivered ink achromatic.
            sampling = "nearest" if shot["id"] in nearest_shots else "blend"
            # Frame holds preserve the source's single crisp ink outlines.
            # They are deliberate manga cadence, not missing timeline frames.
            cadence = (f"fps={FPS}:start_time=0:round=near" if sampling == "nearest" else
                       f"framerate=fps={FPS}:interp_start=0:interp_end=255:flags=0")
            graph = (f"setpts={ratio:.15g}*(PTS-STARTPTS),{fit},lutyuv=u=128:v=128,"
                     f"tpad=stop_mode=clone:stop_duration=0.25,"
                     f"{cadence},"
                     f"tpad=stop_mode=clone:stop_duration=1,trim=end_frame={count},"
                     f"setpts=N/({FPS}*TB),format=yuv420p")
            piece = work / f"{shot['id']}.mp4"
            print(f"PARK ESCAPE SHOT: {shot['id']} — {info['frames']} source pictures → {count} frames ({sampling})", flush=True)
            run([
                "ffmpeg", "-v", "error", "-nostdin", "-y", "-threads", "2", "-i", str(source),
                "-map", "0:v:0", "-vf", graph, "-filter_threads", "1", "-an",
                "-frames:v", str(count), "-r", str(FPS), "-fps_mode", "cfr",
                "-c:v", "libx264", "-preset", "medium", "-crf", "16", "-threads", "2",
                "-g", "30", "-keyint_min", "30", "-sc_threshold", "0",
                "-pix_fmt", "yuv420p", "-color_range", "tv", "-colorspace", "bt709",
                "-color_trc", "bt709", "-color_primaries", "bt709", "-movflags", "+faststart", str(piece),
            ])
            report["sources"].append({"file": str(source), "sha256": sha256(source), **info,
                                      "target_frames": count, "timestamp_ratio": ratio,
                                      "temporal_sampling": sampling,
                                      "retimed_source_fps": info["fps"] / ratio})
            pieces.append(piece)
        listing = work / "concat.txt"
        listing.write_text("".join("file '" + str(path).replace("'", "'\\''") + "'\n" for path in pieces))
        combined = work / "film.mp4"
        run(["ffmpeg", "-v", "error", "-nostdin", "-y", "-f", "concat", "-safe", "0",
             "-i", str(listing), "-map", "0:v:0", "-an", "-c:v", "copy", "-movflags", "+faststart", str(combined)])
        report["master"] = validate(combined, spec)
        combined.replace(target)
        report["candidate"] = str(target)
        print(f"PARK ESCAPE ASSEMBLY: PASS — {report['master']['timeline_frames']} neutral monochrome frames, four complete actions")
    except Exception as exc:
        report["error"] = f"{type(exc).__name__}: {exc}"
        report["work_dir"] = str(work)
        raise
    finally:
        (output / "assembly-report.json").write_text(json.dumps(report, indent=2) + "\n")
        if not keep_work and "error" not in report:
            shutil.rmtree(work)


def convert(manifest_path: Path, output: Path, spec: dict, check: bool, timeline_path: Path) -> None:
    authoring = json.loads(manifest_path.read_text())
    master = authoring["master"]
    source = Path(master["file"])
    if not source.is_absolute():
        source = ROOT / source
    if sha256(source) != master["sha256"]:
        raise ValueError("Master does not match the reviewed source hash")
    count = round(float(spec["duration"]) * FPS)
    if (master["frames"] != count or master["fps"] != FPS or master["resolution"] != list(SIZE)
            or abs(float(master["duration"]) - float(spec["duration"])) > .000001):
        raise ValueError("Reviewed master metadata disagrees with the runtime timeline")
    source_report = validate(source, spec)
    print(f"PARK ESCAPE MASTER: pinned SHA256 verified, {count} monochrome frames", flush=True)
    output.mkdir(parents=True, exist_ok=True)
    target = output / "film.ogv"
    if not check:
        run(["ffmpeg", "-v", "error", "-nostdin", "-y", "-threads", "2", "-i", str(source),
             "-map", "0:v:0", "-vf", "scale=1280:720:flags=lanczos,setsar=1", "-an",
             "-fps_mode", "passthrough", "-c:v", "libtheora", "-q:v", "9", "-g", "60", str(target)])
    report = {"version": 1, "source": source_report, "video": validate(target, spec, theora=True),
              "timeline_sha256": sha256(timeline_path), "spoken_language": spec["spoken_language"],
              "subtitle_language": spec["subtitle_language"]}
    (output / "compiled.json").write_text(json.dumps(report, indent=2) + "\n")
    print(f"PARK ESCAPE VIDEO: {report['video']['timeline_frames']} timeline frames, {report['video']['frames']} decoded pictures, 1280x720@30")
    print("PARK ESCAPE VIDEO: PASS — pinned master, silent neutral Theora, complete timeline and motion in four shots")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--assemble", action="store_true", help="Create reviewed-source candidates outside the repository")
    parser.add_argument("--raw-dir", type=Path, default=AUTHORING.parent / "raw")
    parser.add_argument("--output-dir", type=Path, help="Assembly staging directory or generated runtime output directory")
    parser.add_argument("--timeline", type=Path, default=TIMELINE)
    parser.add_argument("--manifest", type=Path, default=AUTHORING)
    parser.add_argument("--check", action="store_true", help="Validate existing runtime outputs without encoding")
    parser.add_argument("--overwrite", action="store_true", help="Replace assembly candidates only")
    parser.add_argument("--keep-work", action="store_true")
    parser.add_argument("--nearest-shots", nargs="+", choices=SHOT_IDS, default=[],
                        help="Assemble these shots using crisp source-frame holds instead of temporal blending")
    args = parser.parse_args()
    spec = timeline(args.timeline)
    if args.assemble:
        if args.check:
            raise ValueError("--check and --assemble are mutually exclusive")
        output = args.output_dir or ROOT.parent / "scratch/manga-145/candidates"
        assemble(args.raw_dir.resolve(), output, spec, args.overwrite, args.keep_work, set(args.nearest_shots))
    else:
        if args.nearest_shots:
            raise ValueError("--nearest-shots applies only to raw-source assembly")
        convert(args.manifest, args.output_dir or RUNTIME, spec, args.check, args.timeline)
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, ValueError, KeyError, subprocess.CalledProcessError) as exc:
        print(f"PARK ESCAPE VIDEO: {type(exc).__name__}: {exc}", file=sys.stderr)
        raise SystemExit(1)
