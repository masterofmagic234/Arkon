"""Independent decoder checks for the new guardian cues and preserved originals."""
from pathlib import Path
import array
import hashlib
import json
import math
import re
import subprocess
import sys
import wave

ROOT = Path(__file__).resolve().parents[1]


def check(ok, reason):
    if not ok: raise AssertionError(reason)


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def rms(values):
    return math.sqrt(sum(x * x for x in values) / max(1, len(values)))


def db(value):
    return 20 * math.log10(max(value, 1e-12))


def decode(path, oversample=False):
    args = ["ffmpeg", "-v", "error", "-i", str(path)]
    if oversample: args += ["-af", "aresample=176400:filter_size=32"]
    values = array.array("f", subprocess.check_output(args + ["-f", "f32le", "-"]))
    if sys.byteorder != "little": values.byteswap()
    return values


def main():
    p = json.loads((ROOT / "assets/level1/audio/guardian153/PROVENANCE.json").read_text())
    check(sha(ROOT / p["tool"]) == p["tool_sha256"], "authoring source/provenance differ")
    sources = p["generator"]["takes"]
    check(len(sources) == 2 and sum(x["credits"] for x in sources) == 6, "generator inventory incomplete")
    for row in sources:
        check(sha(ROOT / row["source_file"]) == row["sha256"], "recording changed")
        check(row["task_id"] and row["prompt"], "source provenance incomplete")
    check(len(p["preserved_original_pcm"]) == 65, "old PCM inventory incomplete")
    for row in p["preserved_original_pcm"]:
        check(sha(ROOT / row["file"]) == row["sha256"], "original PCM changed: " + row["file"])
    bank = (ROOT / "scripts/woodland_audio_bank.gd").read_text()
    expected = {"guardian_warn": .90, "guardian_attack": .50, "guardian_rally": 1.80}
    hashes = set()
    roles = {}
    records = []
    for row in p["assets"]:
        path = ROOT / row["file"]
        check(sha(path) == row["sha256"], "prepared cue changed: " + row["id"])
        check(row["role"] in expected, "unrelated event replaced")
        params = Path(str(path) + ".import").read_text()
        check(all(x in params for x in ["compress/mode=0", "force/8_bit=false", "force/max_rate=false", "edit/normalize=false"]), "lossless importer settings lost")
        with wave.open(str(path), "rb") as wav:
            check(wav.getframerate() == 44100 and wav.getnchannels() == 1 and wav.getsampwidth() == 2, "spatial PCM layout changed")
            count = wav.getnframes()
            digest = hashlib.sha256(wav.readframes(count)).hexdigest()
        check(digest not in hashes, "duplicated waveform presented as variation")
        hashes.add(digest)
        check(count == row["samples"] and .20 <= count / 44100 <= expected[row["role"]], "cue exceeds combat timing budget")
        values, over = decode(path), decode(path, True)
        metrics = {"id": row["id"], "seconds": count / 44100, "rms_dbfs": db(rms(values)), "true_peak_dbfs": db(max(abs(x) for x in over)), "first50ms_rms_dbfs": db(rms(values[:2205])), "last30ms_rms_dbfs": db(rms(values[-1323:]))}
        check(-29 < metrics["rms_dbfs"] < -20, "cue inaudible or excessively loud")
        check(metrics["true_peak_dbfs"] <= -8.7, "intersample clipping headroom insufficient")
        check(metrics["first50ms_rms_dbfs"] > -48, "combat cue has delayed onset")
        check(metrics["last30ms_rms_dbfs"] < -50, "terminal cut/tail too loud")
        check(max(abs(values[0]), abs(values[-1])) < .0001, "clickable boundary")
        check(abs(sum(values) / len(values)) < .003, "DC bias")
        check(row["id"] in bank, "Bank does not select new cue")
        roles.setdefault(row["role"], []).append(row["id"])
        records.append(metrics)
    check(set(roles) == set(expected) and all(len(x) == 3 for x in roles.values()), "missing guardian variation family")
    for role, ids in roles.items():
        active = re.search(r'&"' + role + r'": \[([^\]]+)\]', bank)
        check(active and set(re.findall(r'"([^\"]+)"', active.group(1))) == set(ids), "active family uses unexpected old/missing cues")
    for role in ["hit", "defeat"]:
        check(f'&"guardian_{role}": ["voice_guardian_{role}_01", "voice_guardian_{role}_02", "voice_guardian_{role}_03"]' in bank, "existing guardian hurt/defeat changed")
    total = sum((ROOT / row["file"]).stat().st_size for row in p["assets"])
    check(total < 900000, "unbounded new PCM budget")
    report = {"result": "PASS", "source_recordings": len(sources), "new_cues": len(records), "preserved_original_pcm": 65, "bytes": total, "assets": records, "scope": "Independent FFmpeg decode/oversampling, PCM format, source/provenance digests, all65original PCM hashes, nine distinct excerpts, bounded timing, quiet tails and Bank mapping. Subjective listening not available in this runtime."}
    if "--output" in sys.argv:
        target = Path(sys.argv[sys.argv.index("--output") + 1]); target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
    print("GUARDIAN153 ASSETS: PASS;9curated cues,2source recordings,65original PCM unchanged")


if __name__ == "__main__": main()
