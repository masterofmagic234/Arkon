#!/usr/bin/env python3
"""Validate fresh-route input/combat evidence beside the sampled native film."""
import argparse
import json
import struct
from pathlib import Path


def require(value, why):
    if not value:
        raise AssertionError(why)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=Path)
    args = parser.parse_args()
    report = json.loads((args.directory / "walk-evidence.json").read_text())
    require(report["source_hashes"] and all(len(value) == 64 for value in report["source_hashes"].values()), "native source fingerprints are incomplete")
    require(report["gallery_extent"]["max_x"] < -8, "western guards entered the central boss plaza")
    inputs = report["input_counts"]
    require(report["scene_instances"] == 1, "route replaced the garden scene")
    require(inputs["movement_frames"] > 600 and inputs["l1_fire"] > 0 and inputs["l1_interact"] >= 5,
            "missing production movement, mouse fire or interaction input")
    require(report["shots"] >= 74 and report["accepted_hits"] >= 74,
            "fresh route did not physically defeat all mandatory defenders and guardian")
    require(report["boss_recovery_windows"] >= 5, "guardian skipped its multi-window two-phase fight")
    groups = {row["id"]: row for row in report["encounters"]}
    require(set(groups) == {"entry", "pump_repair", "pump", "gallery", "escape"},
            "mandatory encounter evidence is missing")
    for name, row in groups.items():
        require(row["remaining"] == 0 and row["shots"] > 0 and row["hp_after"] > 0,
                "encounter did not clear through real surviving combat: " + name)
    voices = report["audio_events"]
    for cue in ["squirrel_warn", "squirrel_hit", "squirrel_defeat", "guardian_warn", "guardian_attack", "guardian_hit", "guardian_defeat",
                "encounter_entry", "encounter_gallery", "encounter_escape"]:
        require(voices.get(cue, 0) > 0, "fresh route omitted its production vocal fact: " + cue)
    if report.get("version") in {"1.52", "1.53"}:
        # Reserves now defend their post before the fuse is installed. An
        # already defeated group must not shout a fictitious counterattack.
        pump = report["pump_reserves_before_install"]
        actors = pump["actors"]
        require(pump["installed"] is False and len(actors) == 4
                and {row["id"] for row in actors} == {12, 13, 14, 15},
                "missing physical pre-installation reserve snapshot")
        alive = sum(not row["defeated"] for row in actors)
        require(pump["remaining"] == alive
                and all((row["hp"] <= 0) == row["defeated"] for row in actors),
                "pump reserve health/defeat/remaining facts disagree")
        if alive:
            require(voices.get("encounter_pump", 0) > 0, "surviving pump reserves omitted their order")
        else:
            require(voices.get("encounter_pump", 0) == 0, "dead pump reserves emitted a phantom order")
    else:
        require(voices.get("encounter_pump", 0) > 0, "legacy route omitted its pump order")
    require(voices.get("enemy_shoot", 0) > 0, "route omitted real enemy projectile pressure")
    mandatory = {0, 1, 3, 4, *range(6, 19), *range(21, 25)}
    for actor_id in mandatory:
        row = report["animated_defeats"].get(str(actor_id), {})
        require(row.get("animated_frames", 0) > 0 and row.get("clip", "").startswith("death") and row.get("settled"),
                "actual imported defeat did not animate and settle: " + str(actor_id))
    frames = report["combat_frames"]
    require(len(frames) == report["frames"] and len(frames) >= 10, "native frame inventory is incomplete")
    attacking = {"aim", "fire", "melee", "windup", "charge", "stomp_windup", "shockwave"}
    group_ids = {"entry": {6, 7, 8, 9}, "pump_repair": {0, 4, 10, 11}, "pump": {12, 13, 14, 15},
                 "gallery": {1, 16, 17, 18}, "guardian": {3}, "escape": {21, 22, 23, 24}}
    for group, ids in group_ids.items():
        require(any(any(int(state.split(":", 1)[0]) in ids and state.split(":", 1)[1] in attacking
                        for state in row["active_states"]) for row in frames),
                "film omitted actual attack phases for " + group)
    require(any(row["stage"] == "cache" and any(state in {"3:stomp_windup", "3:shockwave"}
                for state in row["active_states"]) for row in frames),
            "film omitted the guardian's actual second phase")
    require("actual west glass wing" in report["visited"] and any(row["player"][0] < -17 and -40 < row["player"][2] < -29
                and row["player"][1] > 7 for row in frames), "native route never entered the actual western glass wing")
    require("physical bridge and escape encounters" in report["visited"] and "six acorns" in report["visited"],
            "route did not reach earned reward and final escape")
    require(any(row["stage"] == "reward" and abs(row["player"][0]) < 2.1
                and 14 < row["player"][2] < 34 and row["player"][1] > 4.3 for row in frames),
            "native samples did not physically cross the raised bridge deck")
    images = list(args.directory.glob("frame-*.png"))
    require(len(images) == report["frames"], "saved framebuffer samples do not match the input report")
    for path in images:
        header = path.read_bytes()[:24]
        require(header[:8] == b"\x89PNG\r\n\x1a\n" and struct.unpack(">II", header[16:24]) == (1280, 720),
                "native frame is missing or is not the requested720p: " + path.name)
    print("BOTANICAL WALK EVIDENCE: PASS — fresh normal input, all mandatory battles, five boss windows and actual combat frames")


if __name__ == "__main__":
    main()
