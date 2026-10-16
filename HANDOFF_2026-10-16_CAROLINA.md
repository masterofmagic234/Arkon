# Continuous Carolina intro — Android 1.23 / code 24

Repository masterofmagic234/Arkon, branch fix/level2-final-game-flow, PR 11.
Do not merge automatically. Repair starts at 6f1312523de0ffd52a46dc4c90b77c9798e6f8bd,
the successful 1.22 build which the user rejected for visible motion defects.
Preserve all three levels, squirrel radio/tactics/contacts/helicopter, 240SX
handling/camera/219 km/h route, Forward+ and non-HDR 2D.

1.22 had independently generated source shots with changing room/character
placement, head-key swaps and non-cyclic reading loops. Passing behavior tests
and four still captures did not establish motion quality. Do not restore that
pipeline or represent it as visually approved.

Version 3 is controlled illustrated 2D animation. One room plate and two fixed
character drawings preserve spatial layout and identity. Two registered blink
references affect eyelids only. All five ImageGen drawings and the complete
source animator are retained in art/intro and tools/animate_intro.py. The
likeness photograph is private. The obsolete head-swap utility was removed.
There is no paid service/trial, Runway video output or per-frame image generation.

The animation shows Carolina waking and Darina approaching with her toy,
with smooth body/neck motion, breathing/nods, localized blinks, planted steps,
contact shadows and duvet occlusion. It does not copy every movement of the
rejected footage. All root masters are 1920x1080, 30 fps. Chronological order:
1789650644963: 121 opening frames; 1789649201942: 125 dialogue-0–4 frames;
1789650878847: 121 silent approaching frames; 1789649329293: 121 dialogue-5–16
frames. Total 488 frames / 16.266667 s. Adjacent sections share boundary poses
and camera; both reading loops have equal endpoints. The authoring report
retains hashes, raw frame deltas and joint trajectories. Authoring sources
are excluded from import/export with .gdignore and export presets.

The runtime retains the previous decoded texture until the next decoder has
started and then blends the hold away briefly, eliminating dark dips between
continuous sections. The outro retains its image too. Keep the existing story
menu/reset, 17 Russian dialogue lines, safe skip/mobile layout and SceneFlow
handoff into Level 1. No other gameplay changes are intended.

tools/prepare_intro_videos.py checks source hashes and actual 1280x720 q9 Theora
decoding, frame counts, 30 fps, all frame deltas, section boundaries and both
reading-loop seams. OGVs/compiled.json remain generated build products. Native
intro validation samples the actual framebuffer during transitions and around
one real loop wrap, catching abrupt rendered changes/black flashes, alongside
all existing dialogue/input/layout/campaign assertions.

All previous sixteen behavior gates and renderer/aircraft checks remain.
Before delivering, verify exact published head, matching PR merge tree,
successful current Actions, native motion report and actual packaged videos.
Record final evidence in PR metadata after CI; this is not a phone FPS test.
Deliver the verified APK and standalone movie, preserving existing file identities.
