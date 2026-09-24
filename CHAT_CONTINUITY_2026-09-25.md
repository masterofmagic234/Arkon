# ACORN HUNTER — LATEST CHAT CONTINUITY / 2026-09-25

Repository: masterofmagic234/Arkon
Branch: main
Engine: Godot 4.7.x
Renderer: GL Compatibility
Primary platform: Android

IMPORTANT: this file is a recent-session overlay. It complements PROJECT_CONTEXT_HANDOFF.md. At the start of the next chat, read BOTH files, then inspect the actual current main. Do not rely on memory.

## CURRENT STATE

Current main HEAD at the end of this session:
8564ac62f062ccadb5310d55b87f0e44a2b81688

Latest successful GitHub Actions run checked:
Build V20 APK #750
Run ID: 36058589319
Conclusion: success

Latest HEAD commit message:
"Remove unreachable Level 3 self-damage hitscan path"

The protected game flow remains:
TITLE -> INTRO CUTSCENE -> LEVEL 1 -> LEVEL 2 PSEUDO-3D

Do not break this flow.

## CRITICAL CORRECTION ABOUT THE CURRENT PERFORMANCE PROBLEM

The user explicitly confirmed that the freezes being investigated are in LEVEL 1, NOT LEVEL 2.

Observed Godot Profiler data from LEVEL 1:
- Frame Time: about 20.56 ms
- Process Time: about 16.4 ms
- Physics Time: about 4.15 ms
- Physics 3D: about 0.05 ms
- Script Functions: about 2.53 ms
- _physics_process: about 3.74 ms
- _update_level1_progression: about 2.31 ms

This corresponds to roughly 49 FPS average at that sample, but the user experiences visible freezes. Do not redirect this diagnosis to Level 2 renderer. The current Level 1 audit specifically includes recursive find_child() calls every frame/tick.

## USER REQUEST AT THE END OF THIS SESSION

The user provided a code audit and wants EVERYTHING below fixed if it is not already fixed. Work directly on GitHub, use small targeted commits, inspect actual current files before editing, and verify Actions after changes.

### LEVEL 3 — CRASH / SAFETY

1. Enemy death during RayCast2D physics-query flush
File: scripts/level3_enemy.gd
Status: FIXED in current main.
kill() now uses:
collision_shape.set_deferred("disabled", true)

Do not regress this back to direct .disabled assignment.

2. Blood particle delayed puddle spawn
File: scripts/level3_blood_particles.gd
The code currently already checks:
var stain_parent := get_parent()
if stain_parent != null:
    stain_parent.add_child(puddle)
However, because _ready() awaits 0.26 seconds before calling _spawn_permanent_puddle(), add an explicit safe post-await lifecycle check before attempting to spawn the puddle. Do not claim this was still an unguarded null add_child; the current parent-null guard is already present.

### LEVEL 3 — GAMEPLAY / LOGIC

3. Shotgun multi-hit bug
Files: scripts/level3_store.gd
Current behavior: shotgun fires five traces:
for spread in [-0.12, -0.06, 0.0, 0.06, 0.12]
All five can hit the same enemy in one frame before its collision is deferred/removed, producing repeated blood effects and multiple puddles.
Required behavior:
- one enemy can receive at most one shotgun hit per shot;
- multiple unique enemies may be hit by different pellets;
- blood/death should happen once per enemy;
- avoid five overlapping permanent puddles on one target.

Use a per-shot Set/Dictionary of already-hit enemies or equivalent identity-safe approach. Preserve the five-pellet feel.

4. Wrong enemy identified as shooter
Files: scripts/level3_enemy.gd and scripts/level3_store.gd
IMPORTANT CURRENT STATE:
level3_enemy.gd has already been changed so the signal is now:
signal shot_requested(shooter, origin: Vector2, direction: Vector2)
and emits:
shot_requested.emit(self, origin, direction)

But level3_store.gd still needs to be reconciled with this new signal signature.
Required behavior:
- pass the actual shooter object through the signal;
- _on_enemy_shot_requested() must accept shooter explicitly;
- never infer shooter by nearest-enemy search;
- remove/retire _find_enemy_by_origin() once no longer needed;
- use shooter.get_rid() for query exclusion.

5. Visual bullet / damage timing mismatch
File: scripts/level3_store.gd
Current player fire is hitscan: _trace_weapon_shot() applies damage immediately, while _spawn_projectile_visual() animates a bullet over 0.08–0.22 s.
Required behavior:
- synchronize visible bullet impact and gameplay damage;
- enemy should not visually die before the projectile reaches it;
- preserve responsive controls;
- use a lightweight delayed-impact mechanism keyed to the actual hit result, or otherwise make the visual event and damage event occur in the same apparent moment.
Do not introduce unnecessary physics-projectile complexity.

6. Weapon pickup burns existing ammo
File: scripts/level3_player.gd
Current equip_weapon() overwrites ammo:
ammo = maxi(new_ammo, 1)
For pistol/shotgun pickup behavior, existing ammo must not be silently destroyed.
Required behavior:
- if picking up the same ammo-bearing weapon or ammo from a floor pickup, add new_ammo rather than replacing existing ammo;
- preserve sensible minimum ammo behavior for an empty starting state;
- do not make ammo infinite.
Check current call sites in level3_store.gd before editing so the semantics match the pickup design.

7. Doors kick corpses
File: scripts/level3_door.gd
Current _on_hit_area_body_entered() reportedly checks Level3Enemy but does not exclude DEAD state.
Required behavior:
- dead enemies/turret corpses must not consume the door slam impulse;
- dead enemies must not be pushed;
- door impulse should only apply to living enemies.
Inspect actual current level3_door.gd before editing; do not assume the old version is unchanged.

8. Unreachable Level 3 self-damage hitscan path
File: scripts/level3_store.gd
Current main was already changed to remove this dead branch in commit:
"Remove unreachable Level 3 self-damage hitscan path"
HEAD: 8564ac62f...
Treat this as ALREADY FIXED unless current inspection shows it reappeared.
Do not re-add it.

### LEVEL 2

9. Race HUD total timer
File: scripts/race_hud_panel_pseudo3d.gd
This issue appears ALREADY FIXED in current main by commit:
8243e0e1e83e1f8601d352eec03ec486f1d8f7cb
commit message:
"Keep Level 2 HUD total race timer authoritative"
GitHub Actions #749 for that commit succeeded.
Verify current code before touching it. Do not regress total race time back to per-lap time.

### LEVEL 1 — PERFORMANCE

10. Recursive per-frame find_child() in minimap
File: scripts/minimap_view.gd
Current code in DynamicLayer._draw() performs recursive:
game.find_child(name, true, false)
for acorns, squirrels, keys and doors.
This is a performance hotspot and the user is specifically experiencing LEVEL 1 freezes.
Required behavior:
- cache node references once after the level is ready;
- _draw() should only use cached Node3D references and current visibility/state;
- no recursive scene-tree search from _draw().

Keep the minimap appearance and coordinates unchanged.

11. Recursive per-physics-tick find_child() in Level 1 progression
File: scripts/game.gd
Current _update_level1_progression() performs:
level1_layout.find_child(key_name, true, false)
and
level1_layout.find_child(door_name, true, false)
inside _physics_process().
Required behavior:
- cache the key and door nodes once in _ready() or another initialization phase;
- _update_level1_progression() must iterate cached references;
- preserve existing key pickup and door logic;
- do not alter map layout, collision behavior, or gameplay semantics.

## LEVEL 1 FREEZE INVESTIGATION RULE

The user has already established that the visible freezes are in Level 1.
After fixing the recursive find_child() calls, re-profile Level 1.
Do not switch the diagnosis to Level 2 unless new profiler evidence proves that Level 2 is involved.

The existing Level 1 architecture intentionally batches wall visuals into MultiMeshes and uses Compatibility renderer. Do not perform a giant renderer rewrite. Prefer small profiling-driven fixes.

## WORKFLOW / DEVELOPMENT RULES

- Work directly on masterofmagic234/Arkon:main.
- Inspect current source before each modification.
- Small targeted commits only.
- Never overwrite unrelated changes.
- After meaningful code changes, check GitHub Actions.
- Never claim a build is successful without checking the current run.
- Preserve TITLE -> INTRO -> LEVEL 1.
- Preserve gameplay behavior while optimizing.
- Do not turn game.gd into a monolith.
- Do not reintroduce the abandoned fence experiment.
- Do not blindly port the old raycaster.
- Do not publish private Telegram/contact material.
- If a listed issue is already fixed, verify it and leave it alone.
- If current code differs from this file, trust current code + Git history and update this file if needed.

## NEXT CHAT INSTRUCTION

The next chat should begin by reading:
1. PROJECT_CONTEXT_HANDOFF.md
2. CHAT_CONTINUITY_2026-09-25.md

Then inspect:
- current main HEAD
- scripts/game.gd
- scripts/minimap_view.gd
- scripts/level3_enemy.gd
- scripts/level3_store.gd
- scripts/level3_door.gd
- scripts/level3_player.gd
- scripts/level3_blood_particles.gd
- scripts/race_hud_panel_pseudo3d.gd

Then continue implementing the remaining fixes above. Do not ask the user to repeat the audit.

## USER COMMUNICATION

Speak Russian.
Be direct.
If the user says "делай", implement directly.
At the end of meaningful development work report:
- exact changes;
- commit SHA(s);
- current GitHub Actions/build status;
- what still needs real Android/runtime verification.

Never claim something works just because it was edited. Verify it.
