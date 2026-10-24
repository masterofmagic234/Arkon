# Eight connected locations — Android1.31/code32

The owner approved Woodland Run's concept/art but explicitly requested many
more locations in the SAME first level, with new ideas. The prior single
clearing is now location0 of8. Read this before the1.30 Woodland Run handoff.

The root remains scripts/level1_woodland.gd, with active region_index0..7.
WoodlandJourneyState stores entry checkpoints/resources/completed regions as
atomic user:// JSON. start_new_run clears it; retry retains prior areas; the
menu now resumes an existing checkpoint instead of erasing it. Each region is
one SceneFlow level1 scene reload; only the final car emits level1 completion.
Northern trails unlock after a local goal, southern trails allow backtracking,
and region7's shortcut returns to the original car at region0.

New modules: woodland_region_world builds seven authored landmarks with the
same materials/trees; woodland_region_mission owns seven distinct mechanics;
woodland_target routes actual slingshot rays to rune targets. Shared guard adds
limited-view quiet patrols and a12HP final tank's telegraphed ground shockwave.
Completed locations restore their solved world state, not only their labels.
The ravine's rope reward builds a visible shortcut; off-bridge rescue remains.
The mill's bridge has a visible raised blocker and changing water/working wheel.
Two mirrors use distinct physical normals and actual reflection vectors.

Tests: starter normal/reverse now stop at the next area and explicitly reject
premature Level1 completion. Journey input driver walks all7 new areas, then
returns to the car and enters Level2. Rules fixture checks negative optics,
physical gate, changing water, wind/bracing/rescue, rune failure/ammo recovery,
checkpoint retry/menu resume/map touches/new-run clearing. Campaign and the
existing intro/race/diner gates remain. Native fixture records all8 regions and
map plus shadow-aware budgets, alongside the earlier phone-layout fixture.

Real phone FPS/art acceptance remain device checks. Current exact source,
matching successful CI/APK and image evidence belong in PR11, not a source
commit made only to record a build. Keep PR11 open; do not merge automatically.
