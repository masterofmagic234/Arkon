# ACORN HUNTER — LATEST CHAT CONTINUITY / 2026-09-25

Repository: masterofmagic234/Arkon
Branch: main
Engine: Godot 4.7.x
Renderer: GL Compatibility
Primary platform: Android

This file is a recent-session overlay for continuity. It complements PROJECT_CONTEXT_HANDOFF.md.
At the beginning of the next chat, read BOTH files and then inspect the actual current main. Do not rely on memory or ask the user to repeat this context.

## CURRENT REPOSITORY STATE

Current main HEAD after this continuity update:
58370ce799255fbed2f7085f9986fcebabf07bf0

Latest commit before this continuity file:
8564ac62f062ccadb5310d55b87f0e44a2b81688
Message: "Remove unreachable Level 3 self-damage hitscan path"

Latest checked successful APK workflow before this continuity-only commit:
Build V20 APK #750
Run ID: 36058589319
Conclusion: success

Continuity-file commit itself triggered:
Build V20 APK #751
Run ID: 36059418821
At the moment this file was refreshed, #751 was queued. Do not claim it passed without checking.

## PROTECTED GAME FLOW

TITLE -> INTRO CUTSCENE -> LEVEL 1 -> LEVEL 2 PSEUDO-3D

Do not break this flow.

## CRITICAL PERFORMANCE CONTEXT

The freezes under investigation are specifically in LEVEL 1. They are NOT the current Level 2 renderer problem.

Observed Godot Profiler data from Level 1:
- Frame Time: about 20.56 ms
- Process Time: about 16.4 ms
- Physics Time: about 4.15 ms
- Physics 3D: about 0.05 ms
- Script Functions: about 2.53 ms
- _physics_process: about 3.74 ms
- _update_level1_progression: about 2.31 ms

Do not redirect this investigation to Level 2 unless new evidence proves it.

## USER'S BUG AUDIT — REQUIRED END STATE

The user explicitly asked: "Всё, что описано тут, если не пофикшено уже — исправить."

Before editing each item, inspect current main. If it is already fixed, keep the fix and do not regress it.

### LEVEL 3 — CRASH / SAFETY

1. Enemy death during physics-query flush
File: scripts/level3_enemy.gd
CURRENT STATUS: FIXED.
kill() uses:
collision_shape.set_deferred("disabled", true)
Do not change this back to direct collision_shape.disabled = true.

2. Delayed blood puddle spawn after scene reload
File: scripts/level3_blood_particles.gd
CURRENT STATUS: FIXED.
After await, current code checks:
if not is_inside_tree(): return
and later checks is_inside_tree() before queue_free.
It also has a get_parent() null guard.
Do not regress.

### LEVEL 3 — GAMEPLAY / LOGIC

3. Shotgun multi-hit
File: scripts/level3_store.gd
CURRENT STATUS: FIXED in current main.
A shotgun blast still fires five visible pellets, but a per-shot dictionary of enemy instance IDs prevents duplicate damage/blood/death on the same enemy.
Verify behavior before changing.

4. Wrong enemy identified as shooter
Files: scripts/level3_enemy.gd + scripts/level3_store.gd
CURRENT STATUS: FIXED in current main.
level3_enemy.gd signal is:
shot_requested(shooter, origin, direction)
and emits self.
level3_store.gd receives shooter explicitly and uses shooter.get_rid().
Do not reintroduce nearest-enemy inference or _find_enemy_by_origin().

5. Visual bullet / damage timing
File: scripts/level3_store.gd
CURRENT STATUS: FIXED in current main.
Player hit handling now passes an impact callback into _spawn_projectile_visual(), so enemy blood/death happens when the visible bullet reaches the hit position rather than immediately at raycast time.
Preserve responsive controls.

6. Weapon pickup burns existing ammo
File: scripts/level3_player.gd
CURRENT STATUS: FIXED.
For pistol/shotgun:
ammo += maxi(new_ammo, 0)
Ammo is shared reserve. Do not regress to overwrite behavior.

7. Doors kick corpses
File: scripts/level3_door.gd
CURRENT STATUS: FIXED.
_on_hit_area_body_entered() checks:
if enemy.state == enemy.State.DEAD: return
Dead enemies must not consume the slam or receive push.

8. Unreachable player self-damage hitscan branch
File: scripts/level3_store.gd
CURRENT STATUS: FIXED.
Latest HEAD commit "Remove unreachable Level 3 self-damage hitscan path" removed this dead branch.
Do not re-add it.

### LEVEL 2

9. Race HUD total timer
File: scripts/race_hud_panel_pseudo3d.gd
CURRENT STATUS: FIXED.
Current _process() does NOT overwrite the total race timer with lap_time.
RaceController/set_time owns the total race time.
This was committed in:
8243e0e1e83e1f8601d352eec03ec486f1d8f7cb
Message: "Keep Level 2 HUD total race timer authoritative"
Do not regress.

### LEVEL 1 — PERFORMANCE

10. Minimap recursive find_child() every frame
File: scripts/minimap_view.gd
CURRENT STATUS: FIXED.
DynamicLayer now resolves acorn/squirrel/key/door Node3D references once in setup().
_draw() uses cached dictionaries and is_instance_valid(), with no recursive scene-tree lookup.
StaticLayer's one-time setup search for trees is not a per-frame _draw() search.

11. Level 1 progression recursive find_child() every physics tick
File: scripts/game.gd
CURRENT STATUS: FIXED.
game.gd now has key_nodes and door_nodes dictionaries resolved during initialization, and _update_level1_progression() reads cached references.
Do not restore recursive find_child() calls to the hot loop.

## CURRENT IMPORTANT SOURCE SHAS

scripts/level3_enemy.gd
SHA: current main must be inspected; it contains deferred collision and explicit shooter signal.

scripts/level3_store.gd
Current main contains:
- shotgun duplicate-hit cache
- delayed player hit callback
- explicit shooter argument
- no self-damage hitscan branch

scripts/level3_player.gd
Current main contains additive ammo pickup behavior.

scripts/level3_door.gd
Current main checks DEAD before door slam push.

scripts/level3_blood_particles.gd
Current main performs post-await is_inside_tree() checks.

scripts/minimap_view.gd
Current main caches dynamic node references.

scripts/game.gd
Current main caches Level 1 keys/doors.

scripts/race_hud_panel_pseudo3d.gd
Current main keeps total race timer authoritative.

## LEVEL 1 PROFILING NEXT STEP

After the above fixes are preserved, re-run the Level 1 profiler.

The user's current performance evidence points to Level 1, and the previously identified scene-tree searches are already cached in main. If freezes remain, continue profiling Level 1 instead of assuming the issue is Level 2.

Do not perform a giant refactor.
Do not rewrite the renderer from memory.
Use small, evidence-driven changes.

Important existing Level 1 architecture:
- Compatibility renderer
- wall visuals already batched into MultiMeshes
- fixed-height Wolfenstein-style camera
- gameplay/presentation separation
- modular controllers

## DEVELOPMENT RULES

- Work directly on masterofmagic234/Arkon:main.
- Inspect actual current files before modifications.
- Small targeted commits.
- Preserve unrelated work.
- Check GitHub Actions after meaningful code changes.
- Never claim build success without checking the current Actions run.
- Preserve TITLE -> INTRO -> LEVEL 1.
- Do not turn game.gd into a monolith.
- Do not reintroduce the abandoned fence experiment.
- Do not blindly port the old raycaster.
- Do not publish private Telegram/contact material.
- If an audit item is already fixed, verify it and leave it alone.
- If this file conflicts with actual current main, trust actual code + Git history and update this continuity file.

## NEXT CHAT OPERATING INSTRUCTION

Start the next chat with this exact intent:

1. Read PROJECT_CONTEXT_HANDOFF.md completely.
2. Read CHAT_CONTINUITY_2026-09-25.md completely.
3. Inspect current main HEAD.
4. Confirm which audited items are already fixed and which are still incomplete.
5. Do NOT ask the user to repeat the bug list.
6. Continue from the actual repository.
7. For Level 1 freezes, treat Level 1 as the active performance target.
8. Re-profile after the known find_child hot-loop fixes before making speculative changes.

## USER COMMUNICATION CONTRACT

Speak Russian.
Be direct.
When the user says "делай", implement directly.
Do not substitute a long theoretical explanation for actual repository work.
At the end of meaningful work report:
- exact changes
- commit SHA(s)
- current GitHub Actions/build status
- what still requires Android/runtime verification

Never claim that an edit is working merely because it was written.

## AUDIT FIXES — 2026-09-25

Verified against current main after the additional gameplay audit.

Fixed:
- Level 1 WorldCollision/WorldQueries now treat "#" as wall cells, matching CANONICAL_MAP.
- Level 1 stunned squirrels still receive presentation updates, so the stunned skeletal animation does not freeze.
- Level 3 player hitscan now revalidates the original enemy at the visual projectile impact point, preventing ghost hits after dodges/wall changes.
- Level 3 enemy death disables both the body collider and HitboxComponent collision.
- Level 3 mouse firing is suppressed across the dialogue-finalization click until the physical mouse button is released.
- Level 3 enemy facing is state-aware: ALERT faces the target, IDLE follows movement/patrol direction, STUNNED keeps its facing.
- Level 3 stunned enemies ignore noise until stun expires.
- Level 3 bottle impact LOS is checked from the explosion point to the target, not from the original throw point.
- Level 2 AI cars remain rendered when alongside the player; the near-distance cull was reduced from 0.1 to 0.01 segment.
- The previously identified Level 3 enemy-projectile far-end fix was already present in main and was preserved.

Commits:
- e0c5beb460cc1770f72c1167d2fa781ec021b391 — Level 1 wall collision + stunned squirrel animation.
- 00deb2e440761147f3ab9ba434dab9a2de3a35f8 — Level 3 gameplay logic fixes.
- 9c4ad76dab5ba9f4a839b3d10aaa6d55fdc93d30 — Level 2 AI car visibility.

Current main HEAD: 9c4ad76dab5ba9f4a839b3d10aaa6d55fdc93d30.
GitHub Actions for the three gameplay-fix commits are pending/in progress at the time of this update; do not claim green until the latest run completes successfully.

## AUDIT FIXES — RACE/GRASS/DOOR — 2026-09-25

- Level 2 race cars now retain their negative start-grid world-Z offset when control begins; canonical progress remains unchanged.
- Level 1 hero-grass shader now uses depth_draw_never so transparent fade pixels do not write opaque depth.
- Level 3 door slam tracks enemy instance IDs for each slam, allowing multiple enemies to be stunned while preventing repeat hits on the same enemy.
Commit: b01955c6e80b8c335d05b4d4f0de86f8db74049c.

- Follow-up CI fix: explicit Vector2 typing for Level 3 patrol candidates in `scripts/level3_enemy.gd`; prior #789/#790 validation failures were caused by this parser/type-inference issue.
