# Android 1.47 — characters, weapons, squirrel combat and raid direction

This follows the owner's review of 1.46. Keep Godot 4.7.2, Compatibility,
branch `fix/level2-final-game-flow` and draft PR 11. Do not merge automatically.
Android is 1.47 / code 48, with the existing package and signing certificate.
The evening service quest, physical pursuit and complete diner story from
`HANDOFF_2026-10-28_THREE_LEVELS.md` remain the campaign foundation.

## Carolina and the cone-weapon family

Level 3 uses original painted pixel parts and the actual `Level3HeroVisual`
Node2D rig. Walking follows travelled distance; the supporting and trigger arms
solve their grip positions through two-joint chains. Aim, recoil, movement and
death act on this model. There is no hidden legacy human sprite driving tests.
The heroine keeps the approved dark/burgundy hair and charcoal clothing.

Weapon IDs `pistol` and `shotgun` remain for physics, inventory and saved state;
their visible equipment is now the ШИШКОЛЁТ and ШИШКОВИК. The compact CEDAR
carbine on the sling matches the same graphite/olive material family. Held
weapons, floor pickups, cone projectiles, ammunition and pneumatic muzzle puffs
use the new art. The live projectile path consumes WeaponData fields rather
than silently retaining the old hardcoded bullet texture. Player shots also
use the new compact/scatter Foley variants.

The generated source atlas and preparation manifest are retained under
`assets/level3/carolina147/source/`, ignored by the editor and excluded from
Android. Runtime files are tiny prepared PNGs. The accepted dialogue portraits,
dialogue content, heroine collider and safe-muzzle collision remain.

## Diner raid

The van's old negative vertical drift arc crossed the diner/curb with its
rotated body. The new street-only trajectory is checked using the entire swept
vehicle footprint, including the parked 240 and street boundaries. Real actors
leave the door and follow collision-safe routes around the van.

`level3_raid_director.gd` composes close views of arrival, sliding door, entrance
teams, Carolina's reaction and the window breach. Composition is bounded in
world units on wide phone screens; it never zooms out to display a whole-map
parade. Actors still physically reach their stacks. Optional staging facing
holds them toward their assigned opening and clears at the real assault.
Pause, focus, explicit Skip, player-camera return, pizza and automatic boarding
retain the existing lifecycle contract.

## First-person CEDAR

The first-person weapon is an original Blender model with a modern graphite
receiver, olive panels, open muzzle and small scaled pine-cone rounds. An
anatomically modelled female left hand supports the foregrip, with a continuous
wrist and charcoal cuff. Native checks must inspect both the full composition
and finger/foregrip contact. The model uses three opaque atlas batches and
roughly sixteen thousand triangles, with no runtime mesh construction.

The hand uses a restricted left-hand/forearm subset of explicitly CC0 MakeHuman
anatomy, posed with its original bone lengths and weights. Its source, licence
and extraction/pose tools stay offline under `art/level1/cedar/source/`; the small
`CEDAR_HAND_CC0.txt` notice ships with the runtime model. The weapon and finishes
are original. `tools/build_modern_conegun.py` and the asset provenance retain the
authoring process. `PineConeLauncher` and `WeaponOnlyReadabilityLight` remain
stable diagnostic bindings. The hand and weapon share actual recoil and walk
motion. Preserve the existing viewmodel layer and world rendering budgets.

## Squirrels

Two former pond squirrels were visual-only models without AI, hitboxes or
animation ticks. They are removed. Five authored scouts and the guardian are
real encounter actors. IDs 0–3 retain their meaning, with guardian ID 3;
additional scout IDs 4/5 round-trip in current saves without inventing progress
in legacy saves.

The old floating-body/direct-line steering and analytic height snapping are
replaced by grounded movement and shared physical walkability/routes. Patrol,
hearing, investigation, search, reacquisition, repositioning and attacks remain
active around terraces, walls and the pond. Nearby attack pressure is bounded
for readable mobile dodges. Scout cones are actual swept projectiles, and the
guardian retains its telegraphed two-phase fight. Both garden routes use normal
player input and supplies rather than disabling actors or overriding resources.

Rig repairs address the source defects rather than hiding them with tiny poses:
the scout previously used one rigid weight per vertex and only seven affecting
joints, with essentially static three-sample locomotion clips. The supplied tank
also contained arm/finger influence on tail/chest regions. The offline rig
pipeline corrects anatomical influences, joint transitions and articulated tail,
then densely samples locomotion, turns, alerts, throws, hit/recovery and death.
Both models contain 17 clips. The guardian's 1.05-second charge is a dedicated
launch/tuck/landing lunge driven by the physical action phase, preserving its
speed and dodge timing without forcing a frantic running cadence.
Actual skinned native poses, strain and foot-contact checks are required.
Preserve the supplied squirrel identities, original source files and materials.

## Sound

Eight generated sound takes cost 28 Runway credits in total. Immutable MP3
sources remain offline under `art/level1/audio147/source/`, with hashes and
provenance; no signed service URL belongs in the repository. No further paid
generation is required for this bank.

The prepared bank has 35 short PCM WAVs, including independent footfalls,
launcher/compact/scatter variants, material impacts, attack cues and ambience.
Their import compression is explicitly disabled (`compress/mode=0`), preserving
the small bank's transients and allowing exact exported PCM verification.
The mixer owns its limited local/spatial voice pools, non-repeating selection,
SFX preferences, priority, limiter, mute/pause and cleanup.

Footstep materials derive from the same paths, stairs and stone discs that
build the garden, through `audio_paths` and `audio_surface_zones`. World impacts
use the actual hit collider/material and hit point. Accepted actor impacts are
owned by the actor, preventing duplicate hits. Footsteps require horizontal
grounded travel. Reticle misses retain their event without the obsolete joke
that implied the guards were ignoring shots.

Do not equate waveform metrics with subjective listening. Recorded native mixer
PCM verifies panning, headroom and silent pause/mute windows; a separate real
gameplay excerpt exercises walking, actual shots and hit events.

## Verification and release

Retain the previous gameplay, input, rendering, media and package gates. Add
actual heroine, equipment, director, guard AI, rig, weapon and audio checks.
Prepared artwork, GLB models and audio must be commonly imported before native
acceptance, so captures cannot silently use stale cached assets. Source bakes
and native frames complement each other; neither alone proves final appearance.

The four reviewed bedroom clips/17 lines and manga departure/26 seconds/six
Russian squirrel captions are preserved, including their accepted soundtrack.
Offline authoring sources stay out of Android. The final source/merge tree,
all three CI jobs, actual artifact digests and the independently verified signed
APK belong in PR 11. Actual Huawei P60 FPS is not inferred from software renders.
