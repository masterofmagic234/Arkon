"""Independent acceptance of actual native vocal mixer PCM; FFmpeg + stdlib."""
from pathlib import Path
import argparse
import array
import json
import math
import subprocess
import sys


def check(ok, why):
    if not ok:
        raise AssertionError(why)


def db(value):
    return 20 * math.log10(max(value, 1e-12))


def rms(values):
    return math.sqrt(sum(v * v for v in values) / max(1, len(values)))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("recording", type=Path)
    parser.add_argument("timeline", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    timeline = json.loads(args.timeline.read_text())
    rate = 48000
    raw = subprocess.check_output(["ffmpeg", "-v", "error", "-i", str(args.recording), "-vn", "-ac", "2", "-ar", str(rate), "-f", "f32le", "-"])
    samples = array.array("f", raw)
    if sys.byteorder != "little":
        samples.byteswap()
    check(len(samples) / (rate * 2) >= 34.5, "native timeline cut short")

    def region(start, end):
        return samples[round(start * rate) * 2:round(end * rate) * 2]

    def channels(start, end):
        data = region(start, end)
        return [rms(data[c::2]) for c in [0, 1]]

    events = timeline["requested_events"]
    left = channels(1.0, 1.45)
    right = channels(70 / 30, 70 / 30 + .5)
    check(left[0] > left[1] * 1.2, "actual squirrel voice did not pan left")
    check(right[1] > right[0] * 1.2, "actual guardian voice did not pan right")
    local = channels(520 / 30 + .01, 520 / 30 + .25)
    check(min(local) > .01 and abs(local[0] - local[1]) / max(local) < .04, "player weapon lost centred priority mix")
    burst = [e for e in events if e["frame"] == 560 and e["accepted_immediately"]]
    check(len(burst) == 5 and burst[-1]["kind"] == "encounter_entry", "startup chorus lost the reserved phase start or exceeded cap")
    gallery = next(e for e in events if e["kind"] == "encounter_gallery")
    check(not gallery["accepted_immediately"] and gallery["phase_pending"], "phase leader stole protected weapon slot instead of briefly waiting")
    accepted_gallery = [e for e in timeline["mix_events"] if e["requested"] == "encounter_gallery"]
    check(len(accepted_gallery) == 1, "queued gallery leader was lost or duplicated")
    escape = [e for e in events if e["kind"] == "encounter_escape"]
    check(len(escape) == 2 and all(e["accepted_immediately"] for e in escape), "isolated/full-mix escape calibration missing")
    check(60 < timeline["escape_distance"] < 65, "actual authored escape distance was not exercised")
    check(all(e["max_distance"] >= 120 and e["unit_size"] >= 16 for e in escape), "projected call range is too short for the actual route")
    ambient = rms(region(23.5, 24.25))
    # With the bed lowered by46dB, this is the actual spatial voice, compared
    # against the real authored ambience measured just before it. Use the best
    #150ms so the brief call is not diluted by its intentional terminal silence.
    isolated_start = escape[0]["seconds"]
    best = max(rms(region(isolated_start + offset / 100, isolated_start + offset / 100 + .15)) for offset in range(0, 46, 2))
    margin = db(best) - db(ambient)
    check(margin >= 4, "62m escape leader lacks4dB active-call RMS margin over authored ambience: " + str(margin))
    peak = max(abs(v) for v in samples)
    check(db(peak) <= -.8, "native vocal/weapon overload exceeded limiter ceiling")
    check(max(abs(v) for v in region(625 / 30, 625 / 30 + .35)) > .8, "protected weapon stress did not exercise limiter")
    pause_peak = max(abs(v) for v in region(29.25, 30.35))
    mute_peak = max(abs(v) for v in region(33, 34.5))
    check(pause_peak < 1e-5 and timeline["dropped_paused"] > 0, "vocal or ambience continued through pause")
    check(mute_peak < 1e-5 and timeline["dropped_muted"] > 0, "vocal or ambience continued after mute")
    report = {"result": "PASS", "seconds": len(samples) / (rate * 2), "rate": rate, "channels": 2, "peak_dbfs": db(peak), "squirrel_left_rms": left, "guardian_right_rms": right, "local_weapon_rms": local, "escape_distance": timeline["escape_distance"], "ambient_rms_dbfs": db(ambient), "escape_active_150ms_rms_dbfs": db(best), "escape_margin_db": margin, "pause_peak": pause_peak, "mute_peak": mute_peak, "scope": "Independent native MovieMaker PCM decode: actual vocal panning, centred weapon, critical start budget/queue,62m projected call vs real ambience, limiter, pause and mute. Staged recording; no subjective listening or full gameplay claim."}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2) + "\n")
    print("WOODLAND VOICES149 RECORDING: PASS")


if __name__ == "__main__":
    main()
