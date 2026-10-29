"""Independent decoded-PCM checks for new vocals and the preserved v1.47 bank."""
from pathlib import Path
import array
import hashlib
import json
import math
import subprocess
import sys
import wave

ROOT = Path(__file__).resolve().parents[1]


def check(ok, why):
    if not ok:
        raise AssertionError(why)


def rms(a):
    return math.sqrt(sum(x * x for x in a) / max(1, len(a)))


def db(x):
    return 20 * math.log10(max(x, 1e-12))


def floats(raw):
    result = array.array("f", raw)
    if sys.byteorder != "little":
        result.byteswap()
    return result


def main():
    p = json.loads((ROOT / "assets/level1/audio/voices149/PROVENANCE.json").read_text())
    check(hashlib.sha256((ROOT / p["tool"]).read_bytes()).hexdigest() == p["tool_sha256"], "preparation tool changed without provenance")
    g = p["generator"]
    check(len(g["takes"]) == 6 and g["total_credits"] == 48, "source-take/budget record incomplete")
    check(len(p["preserved_147"]) == 35, "baseline preservation inventory incomplete")
    for row in [*g["takes"], *p["preserved_147"]]:
        path = ROOT / row.get("source_file", row.get("file", ""))
        check(hashlib.sha256(path.read_bytes()).hexdigest() == row["sha256"], "immutable recording changed: " + str(path))
    roles = {}
    hashes = set()
    rows = []
    check(len(p["assets"]) == 30, "vocal inventory must contain30 prepared distinct takes")
    for row in p["assets"]:
        path = ROOT / row["file"]
        check(hashlib.sha256(path.read_bytes()).hexdigest() == row["sha256"], "prepared vocal differs from provenance: " + str(path))
        params = Path(str(path) + ".import").read_text()
        check(all(x in params for x in ["compress/mode=0", "force/8_bit=false", "force/max_rate=false", "edit/normalize=false"]), "lossless import settings lost")
        with wave.open(str(path), "rb") as wav:
            check(wav.getframerate() == 44100 and wav.getsampwidth() == 2 and wav.getnchannels() == 1, "voices must be spatial mono44.1kHz/16bit PCM")
            count = wav.getnframes()
            payload = wav.readframes(count)
        digest = hashlib.sha256(payload).hexdigest()
        check(digest not in hashes, "duplicate waveform passed off as a variation")
        hashes.add(digest)
        check(count == row["samples"] and .20 <= count / 44100 <= 2.0, "voice empty, untrimmed or too long")
        # Separate FFmpeg decoder and resampler, independent of preparation.
        a = floats(subprocess.check_output(["ffmpeg", "-v", "error", "-i", str(path), "-f", "f32le", "-"]))
        oversampled = floats(subprocess.check_output(["ffmpeg", "-v", "error", "-i", str(path), "-af", "aresample=176400:filter_size=32", "-f", "f32le", "-"]))
        true_peak = db(max(abs(x) for x in oversampled))
        check(true_peak <= -8.7, "vocal has insufficient intersample headroom")
        check(-34 < db(rms(a)) < -20, "voice level inaudible or over-loud")
        check(abs(sum(a) / len(a)) < .003, "vocal DC offset")
        check(max(abs(a[0]), abs(a[-1])) < .0001, "vocal edge can click")
        check(db(rms(a[-1323:])) < -42, "vocal ends in a cut-off loud call or uncontrolled tail")
        check(db(rms(a[:2205])) > -48, "excessive onset silence delays combat reaction")
        check(any(s["source"].startswith("art/level1/audio149/source/") and s["source"].endswith(".mp3") for s in row["source_slices"]), "vocal event is still mechanical foley")
        if row["role"].endswith("_defeat"):
            check(row["body_fall"] and any(s.get("purpose", "").startswith("soft body") for s in row["source_slices"]), "defeat missing quiet body settle")
        if row["role"].startswith("guardian_"):
            check(any("/guardian" in s["source"] for s in row["source_slices"]), "guardian is only a pitched ordinary voice")
        roles.setdefault(row["role"], []).append(row)
        rows.append({"id": row["id"], "seconds": count / 44100, "true_peak_dbfs": true_peak,
                     "rms_dbfs": db(rms(a)), "terminal_rms_dbfs": db(rms(a[-1323:]))})
    expected = {actor + "_" + event for actor in ["squirrel", "guardian"] for event in ["warn", "attack", "hit", "defeat", "rally"]}
    check(set(roles) == expected and all(len(r) >= 3 for r in roles.values()), "missing3-take actor/action family")
    total = sum((ROOT / r["file"]).stat().st_size for r in p["assets"])
    check(total < 3 * 1024 * 1024, "unbounded vocal asset size")
    report = {"result": "PASS", "files": len(rows), "source_takes": len(g["takes"]), "credits": g["total_credits"],
              "preserved_147": len(p["preserved_147"]), "bytes": total, "assets": rows,
              "scope": "Actual independent decode/oversampling, immutable source/baseline hashes, distinct waveform inventory, quiet edge/tail and level checks. No subjective listening claim."}
    if "--output" in sys.argv:
        destination = Path(sys.argv[sys.argv.index("--output") + 1])
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_text(json.dumps(report, indent=2) + "\n")
    print("WOODLAND VOICES149 ASSETS: PASS —30 vocals,35 preserved PCM files,48credit provenance, independent headroom/tail checks")


if __name__ == "__main__":
    main()
