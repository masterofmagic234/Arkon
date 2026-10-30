"""Curate two generated guardian recordings into bounded spatial combat cues.

Offline FFmpeg edits only: no runtime DSP, pitch shifting, new synthesis or
changes to the preserved 65 original clips. Nine excerpts are not nine
independent generated recordings; exact source windows are recorded below.
"""
from pathlib import Path
import array
import hashlib
import json
import math
import subprocess
import sys
import wave

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "art/level1/audio153/source"
OUT = ROOT / "assets/level1/audio/guardian153"
RATE = 44100
SOURCES = {
    "guardian_warning": {
        "task_id": "0d5e7c58-661f-42ad-9f4a-6f6fc5997435", "duration_seconds": 4,
        "credits": 4,
        "prompt": "A gigantic angry squirrel beast in a ruined greenhouse: ferocious raspy guttural chattering, fast incisors clacking and harsh animal snorts, builds into one short threatening snarl. Recognizable rodent, fierce and believable, not human speech or a dinosaur. Dry close isolated sound, no music, no ambience, clean tail.",
    },
    "guardian_attack": {
        "task_id": "08e430d7-d3ea-4750-8971-f02d774a589e", "duration_seconds": 2,
        "credits": 2,
        "prompt": "An enraged giant squirrel lunges: one abrupt, fierce raspy rodent attack bark with sharp chittering teeth, a tight throaty growl and forceful breath, naturally pitched animal voice. Dry close sound, fast onset, ends quickly with a tiny tail. No speech, music, ambience, impact, cinematic boom or long reverb.",
    },
}
WINDOWS = {
    "guardian_warn": [("guardian_warning", .28, 1.04), ("guardian_warning", 2.08, 2.76), ("guardian_warning", 2.90, 3.72)],
    "guardian_attack": [("guardian_attack", .00, .27), ("guardian_attack", .27, .65), ("guardian_attack", .66, 1.00)],
    "guardian_rally": [("guardian_warning", .00, 1.57), ("guardian_warning", 1.58, 2.77), ("guardian_attack", .00, 1.04)],
}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def floats(raw):
    values = array.array("f", raw)
    if sys.byteorder != "little": values.byteswap()
    return values


def db(value):
    return 20 * math.log10(max(value, 1e-12))


def rms(values):
    return math.sqrt(sum(x * x for x in values) / max(1, len(values)))


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    assets = []
    for role, windows in WINDOWS.items():
        for index, (source, begin, end) in enumerate(windows, 1):
            duration = end - begin
            # Dry short fades make excerpt boundaries safe; retain45ms silence
            # after the decay so the mixer never terminates on a loud sample.
            filters = f"atrim=start={begin}:end={end},asetpts=PTS-STARTPTS,highpass=f=100,lowpass=f=14000,acompressor=threshold=0.06:ratio=3:attack=1:release=40:makeup=1,afade=t=in:st=0:d=0.003,afade=t=out:st={max(0,duration-.10):.6f}:d=0.10,apad=pad_dur=0.045"
            samples = floats(subprocess.check_output(["ffmpeg", "-v", "error", "-i", str(SOURCE / (source + ".mp3")), "-af", filters, "-ar", str(RATE), "-ac", "1", "-f", "f32le", "-"]))
            mean = sum(samples) / len(samples)
            samples = array.array("f", [x - mean for x in samples])
            gain = 10 ** (-23 / 20) / max(rms(samples), 1e-10)
            # Four-times independent FFmpeg resampling detects intersample peaks.
            probe = array.array("f", samples)
            if sys.byteorder != "little": probe.byteswap()
            over = floats(subprocess.check_output(["ffmpeg", "-v", "error", "-f", "f32le", "-ar", str(RATE), "-ac", "1", "-i", "-", "-af", "aresample=176400:filter_size=32", "-f", "f32le", "-"], input=probe.tobytes()))
            gain = min(gain, 10 ** (-9 / 20) / max(max(abs(x) for x in over), 1e-10))
            pcm = array.array("h", [round(max(-1, min(1, x * gain)) * 32767) for x in samples])
            pcm[0] = pcm[-1] = 0
            if sys.byteorder != "little": pcm.byteswap()
            name = f"voice_{role}_153_{index:02}"
            path = OUT / (name + ".wav")
            with wave.open(str(path), "wb") as output:
                output.setnchannels(1); output.setsampwidth(2); output.setframerate(RATE)
                output.writeframes(pcm.tobytes())
            respath = "res://" + str(path.relative_to(ROOT))
            imported = "res://.godot/imported/" + path.name + "-" + hashlib.md5(respath.encode()).hexdigest() + ".sample"
            Path(str(path) + ".import").write_text(f'''[remap]\n\nimporter="wav"\ntype="AudioStreamWAV"\npath="{imported}"\n\n[deps]\n\nsource_file="{respath}"\ndest_files=["{imported}"]\n\n[params]\n\nforce/8_bit=false\nforce/mono=false\nforce/max_rate=false\nforce/max_rate_hz=44100\nedit/trim=false\nedit/normalize=false\nedit/loop_mode=0\nedit/loop_begin=0\nedit/loop_end=-1\ncompress/mode=0\n''')
            assets.append({"id": name, "role": role, "file": str(path.relative_to(ROOT)), "sha256": sha(path), "source_file": str((SOURCE / (source + ".mp3")).relative_to(ROOT)), "source_window_seconds": [begin, end], "samples": len(pcm), "sample_rate": RATE, "channels": 1, "bits": 16, "seconds": len(pcm) / RATE, "editing": "FFmpeg100Hz highpass/14kHz lowpass,offline3:1 transient compression (1ms attack/40ms release),3ms onset/100ms terminal fade,45ms quiet tail,RMS-23dBFS subject to-9dBFS oversampled peak ceiling; no pitch shift or synthesis"})
    old = []
    for family in ["polished147", "voices149"]:
        for row in json.loads((ROOT / f"assets/level1/audio/{family}/PROVENANCE.json").read_text())["assets"]:
            path = ROOT / row["file"]
            if sha(path) != row["sha256"]: raise AssertionError("original PCM was changed: " + str(path))
            old.append({"file": row["file"], "sha256": row["sha256"]})
    generated = [{"name": name, **info, "source_file": str((SOURCE / (name + ".mp3")).relative_to(ROOT)), "sha256": sha(SOURCE / (name + ".mp3"))} for name, info in SOURCES.items()]
    report = {"version": 153, "purpose": "Ferocious guardian anticipation, lunge and rally; existing hurt/defeat preserved", "generator": {"service": "Runway connected workspace sound effects", "takes": generated, "total_credits": 6}, "tool": str(Path(__file__).relative_to(ROOT)), "tool_sha256": sha(Path(__file__)), "assets": assets, "preserved_original_pcm": old, "quality_scope": "Source metadata, actual decoded waveform and spectral/headroom checks. This runtime offers no audio listening tool; no subjective listening claim. Nine edited cues use two generated recordings, not nine independent takes. Runtime gain, variation, distance and concurrency are unchanged."}
    (OUT / "PROVENANCE.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps({"files": len(assets), "original_pcm_preserved": len(old), "bytes": sum((ROOT / row["file"]).stat().st_size for row in assets)}))


if __name__ == "__main__": main()
