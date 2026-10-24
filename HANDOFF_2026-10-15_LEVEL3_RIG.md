# Level 3 — full animal rigs, Android 1.18 / code 19

Read this first. Repository masterofmagic234/Arkon, branch
fix/level2-final-game-flow, PR 11. Do not merge. Started from verified
published HEAD 7aa53bac4237044392f940059d37abde7d759b5c (successful Actions #1019).
The user explicitly requested complete model AND movement redesign after
the earlier head/tail overlay. That earlier approach is now superseded.

## Final change

- Entire grey squirrel torsos, haunches, paws, heads, tails and held weapons
  replace all human walking/body frames. Three distinct pixel roles remain:
  cautious ivory/teal gunman, springier blue-grey bat squirrel and bulky
  ivory/ochre butcher with a cleaver. The flat, small-palette pixel style stays.
- Built-in ImageGen made the selected modular rig and closed-eye head sheets.
  Exact source files/prompts and hashes are in assets/level3/squirrels/source;
  ASSET_PROVENANCE.md documents the complete bake and runtime behavior.
- Offline baker creates 132 complete poses: idle8, walk12, windup8, attack6,
  stun4 and fall6 for each role. Baked 80px frames share a single body origin
  and right heading; old human offsets/quarter-turns are removed, scale .78.
- SquirrelSkins shares immutable SpriteFrames per role. SquirrelAnimator
  manually advances distance-based signed walking and selects idle/states.
  Tail lag and paw/body mechanics are baked, not assembled during gameplay.
  Runtime still draws one AnimatedSprite2D per opponent.
- Existing .48s/.34s attack timers own all shots/damage. The new animation
  follows those timers and adds visual recovery. Stun cancels pending attacks
  and recovery. Dead enemies finish their .36s fall then hold; health,
  collisions, defeat signals and mission still resolve immediately.
- No balance, map, navigation, input or Level 1/2 changes.

## Validation and release

Fourteen local behavior gates passed, including the new animation lifecycle
and actual gun/bat/cleaver timing gate. The real-input Level 3 playthrough
still defeated all ten live guards, collected the order, returned and changed
to the menu: 15 shots, 76 HP, 73.783 simulated seconds. No player teleport,
health/ammo/progress override is used in that mission test.

The native squirrel fixture stages all 44 poses at four headings, warnings,
stun and settled fall in the real scene, plus a 24fps animation preview.
The eight standard whole-level/mobile captures also passed. Native Mesa
software rendering is not phone FPS or user visual acceptance.

Android is version 1.18/code 19, arm64 debug, com.acornhunter.carolina.
Existing build output remains build/AcornHunter-MoonlightSprint.apk. CI adds
one animation gate alongside the original thirteen and native race gate.
Always verify current remote HEAD, successful matching Actions run and APK;
never claim a green build from the preceding revision. Source-generation
sheets are excluded from Android. Do not stage incidental Godot import drift.

Read HANDOFF_2026-10-15.md for Level 1 and HANDOFF_2026-10-13_SPRINT.md for the
scenic race. HANDOFF_2026-10-15_LEVEL3.md is historical, accessory-only work.
