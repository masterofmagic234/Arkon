"""Curate generated squirrel calls into short spatial, lossless game vocals.

Offline only: FFmpeg, NumPy and SciPy. No oscillator, voice synthesis, pitch
shifting or runtime filters. Exact raw recordings and edit decisions are pinned
in art/level1/audio149. This script never modifies the v1.47 audio bank.
"""
from pathlib import Path
import hashlib
import json
import subprocess
import wave

import numpy as np
import scipy
from scipy.signal import butter, resample_poly, sosfilt

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "art/level1/audio149/source"
OUT = ROOT / "assets/level1/audio/voices149"
RATE = 44100
OUT.mkdir(parents=True, exist_ok=True)
RECORDS = []


def decode(path):
    raw = subprocess.check_output(["ffmpeg", "-v", "error", "-i", str(path),
                                   "-ar", str(RATE), "-ac", "1", "-f", "f32le", "-"])
    return np.frombuffer(raw, dtype="<f4").astype(np.float64)


SOURCES = {p.stem: decode(p) for p in sorted(SOURCE.glob("*.mp3"))}


def excerpt(source, start, end):
    return SOURCES[source][round(start * RATE):round(end * RATE)].copy(), {
        "source": f"art/level1/audio149/source/{source}.mp3", "start_seconds": start,
        "end_seconds": end, "gain": 1.0, "offset_seconds": 0.0}


def filter_voice(a):
    # Remove only rumble and MP3-band hiss, retaining natural vocal harmonics.
    return sosfilt(butter(2, [100, 14500], btype="bandpass", fs=RATE, output="sos"), a)


def combine(parts):
    length = max(len(a) + round(d["offset_seconds"] * RATE) for a, d in parts)
    result = np.zeros(length)
    for a, d in parts:
        begin = round(d["offset_seconds"] * RATE)
        result[begin:begin + len(a)] += a * d["gain"]
    return result


def true_peak(a):
    return max(float(np.max(np.abs(resample_poly(a, 4, 1)))), 1e-10)


def save(role, index, parts, body_fall=False):
    a = filter_voice(combine(parts))
    if body_fall:
        path = ROOT / f"assets/level1/audio/polished147/defeat_{1 + index % 2:02}.wav"
        fall = decode(path)
        # The fall follows the call; it is deliberately much quieter than it.
        offset = max(.14, len(a) / RATE - .15)
        gain = max(float(np.sqrt(np.mean(a * a))), 1e-6) / max(float(np.sqrt(np.mean(fall * fall))), 1e-6) * .22
        descriptor = {"source": str(path.relative_to(ROOT)), "start_seconds": 0.0,
                      "end_seconds": len(fall) / RATE, "offset_seconds": offset, "gain": gain,
                      "purpose": "soft body/leaf settling after vocal, immutable v1.47 foley"}
        a = combine([(a, {"gain": 1.0, "offset_seconds": 0.0}), (fall, descriptor)])
        parts = [*parts, (fall, descriptor)]
    # Trim actual quiet edges, not the arbitrary generation length. Retain
    # natural breath and short dry decays; never loop or stretch a vocal.
    block = 220
    n = len(a) // block
    env = np.sqrt(np.mean(a[:n * block].reshape(n, block) ** 2, axis=1))
    active = np.flatnonzero(env > max(float(env.max()) * .035, .00005))
    begin = max(0, int(active[0] * block) - round(.012 * RATE))
    end = min(len(a), int((active[-1] + 1) * block) + round(.065 * RATE))
    a = a[begin:end]
    a -= np.mean(a)
    edge_in = min(round(.0025 * RATE), len(a))
    edge_out = min(round(.080 * RATE), len(a))
    a[:edge_in] *= np.linspace(0, 1, edge_in)
    a[-edge_out:] *= np.linspace(1, 0, edge_out) ** 2
    target_rms = -25.0 if body_fall else -23.0
    a *= 10 ** (target_rms / 20) / max(float(np.sqrt(np.mean(a * a))), 1e-10)
    a *= min(1.0, 10 ** (-9.0 / 20) / true_peak(a))
    pcm = np.round(a * 32767).astype("<i2")
    name = f"voice_{role}_{index:02}"
    path = OUT / (name + ".wav")
    with wave.open(str(path), "wb") as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(RATE)
        output.writeframes(pcm.tobytes())
    decoded = pcm.astype(np.float64) / 32768
    # Pin explicit lossless Godot import settings before the coordinated import.
    respath = "res://" + str(path.relative_to(ROOT))
    imported = "res://.godot/imported/" + path.name + "-" + hashlib.md5(respath.encode()).hexdigest() + ".sample"
    importer = Path(str(path) + ".import")
    if not importer.exists():
        importer.write_text(f'''[remap]\n\nimporter="wav"\ntype="AudioStreamWAV"\npath="{imported}"\n\n[deps]\n\nsource_file="{respath}"\ndest_files=["{imported}"]\n\n[params]\n\nforce/8_bit=false\nforce/mono=false\nforce/max_rate=false\nforce/max_rate_hz=44100\nedit/trim=false\nedit/normalize=false\nedit/loop_mode=0\nedit/loop_begin=0\nedit/loop_end=-1\ncompress/mode=0\n''')
    terminal = min(round(.03 * RATE), len(decoded))
    RECORDS.append({"id": name, "role": role, "file": str(path.relative_to(ROOT)),
                    "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
                    "source_slices": [d for _, d in parts], "trim_samples": [begin, end],
                    "sample_rate": RATE, "channels": 1, "bits": 16, "samples": len(pcm),
                    "seconds": len(pcm) / RATE, "true_peak_dbfs": 20 * np.log10(true_peak(decoded)),
                    "rms_dbfs": 20 * np.log10(max(float(np.sqrt(np.mean(decoded * decoded))), 1e-10)),
                    "terminal_rms_dbfs": 20 * np.log10(max(float(np.sqrt(np.mean(decoded[-terminal:] ** 2))), 1e-10)),
                    "editing": ["independent vocal excerpt(s), no pitch shifting", "100Hz highpass /14.5kHz lowpass",
                                "quiet-edge trim preserving12ms onset/65ms decay", "2.5ms onset /80ms squared terminal fade",
                                "RMS normalization with -9dBFS oversampled true-peak ceiling"],
                    "body_fall": body_fall})


WINDOWS = {
    "squirrel_warn": ("warning", [(0.27, .70), (2.01, 2.47), (2.86, 3.29)]),
    "squirrel_attack": ("attack", [(.10, .65), (1.62, 2.30), (5.78, 6.43)]),
    "squirrel_hit": ("hurt", [(.08, .53), (1.70, 2.09), (3.00, 3.40)]),
    "squirrel_defeat": ("defeat", [(0.0, .69), (.84, 1.84), (4.45, 5.98)]),
    "squirrel_rally": ("attack", [(.73, 1.55), (3.78, 4.55), (6.45, 7.48)]),
    "guardian_warn": ("guardian", [(.01, .49), (2.94, 3.48), (5.51, 6.06)]),
    "guardian_hit": ("guardian_distress", [(0.0, .38), (.40, .94), (1.02, 1.59)]),
    "guardian_defeat": ("guardian_distress", [(2.05, 2.78), (4.08, 5.47), (5.67, 7.38)]),
}
for role, (source, windows) in WINDOWS.items():
    for index, (start, end) in enumerate(windows, 1):
        save(role, index, [excerpt(source, start, end)], body_fall=role.endswith("_defeat"))

# Guardian attack/rally uses its independently generated lower kuk source,
# combined with the recorded quick chitter. It is never a lowered ordinary call.
for index, (guard_window, effort_window) in enumerate(zip(
        [(1.17, 1.55), (4.20, 4.58), (7.12, 7.54)],
        [(2.61, 3.08), (3.49, 3.93), (6.03, 6.40)]), 1):
    guard = excerpt("guardian", *guard_window)
    effort = excerpt("attack", *effort_window)
    effort[1]["gain"] = .32
    effort[1]["offset_seconds"] = .10
    save("guardian_attack", index, [guard, effort])
    chatter = excerpt("attack", *[(.12, .78), (4.10, 4.88), (6.44, 7.35)][index - 1])
    chatter[1]["gain"] = .45
    chatter[1]["offset_seconds"] = .22
    save("guardian_rally", index, [guard, chatter])

generation = json.loads((ROOT / "art/level1/audio149/generation.json").read_text())
old = json.loads((ROOT / "assets/level1/audio/polished147/PROVENANCE.json").read_text())
provenance = {"version": 1, "purpose": "Natural squirrel and armored guardian battle/encounter vocals",
              "generator": generation, "tool": str(Path(__file__).relative_to(ROOT)),
              "tool_sha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
              "authoring_versions": {"numpy": np.__version__, "scipy": scipy.__version__,
                                     "ffmpeg": subprocess.check_output(["ffmpeg", "-version"], text=True).splitlines()[0]},
              "runtime_processing": "bounded selection, under1% pitch variation, gain, distance/panning and existing scene-local limiter; no synthesis",
              "quality_scope": "All six recordings were requested as audio tool content, but this agent runtime rejected audio input. No subjective listening is claimed. Spectrograms, independent decoding, PCM/headroom/tail checks and an audition reel support review; human listening is still useful.",
              "preserved_147": [{"file": r["file"], "sha256": r["sha256"]} for r in old["assets"]],
              "assets": RECORDS}
(OUT / "PROVENANCE.json").write_text(json.dumps(provenance, ensure_ascii=False, indent=2) + "\n")
reel = []
for row in RECORDS:
    reel.extend([decode(ROOT / row["file"]), np.zeros(round(.3 * RATE))])
with wave.open(str(ROOT / "art/level1/audio149/audition_reel.wav"), "wb") as output:
    output.setnchannels(1)
    output.setsampwidth(2)
    output.setframerate(RATE)
    output.writeframes(np.round(np.concatenate(reel) * 32767).astype("<i2").tobytes())
print(json.dumps({"files": len(RECORDS), "credits": generation["total_credits"],
                  "bytes": sum((ROOT / r["file"]).stat().st_size for r in RECORDS),
                  "max_true_peak_dbfs": max(r["true_peak_dbfs"] for r in RECORDS)}, indent=2))
