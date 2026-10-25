# Botanical garden — read before all previous Level1 handoffs

Owner rejected the eight separately loaded areas and chose concept B, the
botanical garden. Level1 now uses botanical_garden.gd / botanical_world.gd:
ONE continuously resident scene with real terraced terrain, central stairs,
side ramps, reflecting pool, conservatory, upper orchard and pavilion. No
active region selection, automatic portals or SceneFlow calls between garden
landmarks. The inherited director supplies weapon/basic input helpers; its old
regional state and travel methods are unused.
`game.tscn` loads the new director. Core weapon/touch/health helpers are reused.

GardenState stores all partial objectives, valves, mirrors, seeds, companion
progress, guardian outcome, player checkpoint/resources and defeated guards in
atomic schema1 user://botanical_garden.json. Retry keeps objectives and returns
to safe entrance; menu Continue resumes; New Adventure clears it. Old Woodland
checkpoints are separate and do not define the new level.

Quest: restore real visible irrigation, collect three specimens, reflect the
beam through two physically oriented mirrors to the conservatory flower, then
resolve the guardian. Escorting the actual Scout allows a peaceful outcome;
without the escort, a two-phase guardian fight is available. Six acorns are
collected only afterward. Only the original entrance car advances to Level2.

Native botanical_visual captures actual production geometry/lighting/GLBs.
Clean frames hide UI/weapon and freeze actors. Desktop overview disables
geometry distance limits and is not a phone budget. Gameplay uses native UI,
scene-local MSAA2 and a 1280x720 3D pixel cap; settings restore on exit. Current
fixture limits are 300 calls/550k triangles INCLUDING shadows/UI. Device FPS
is unmeasured. The concept is richer than the current render: do not claim an
exact visual match or approval of the implementation. Keep PR11 in draft until
the owner reviews the real result; do not merge automatically.

botanical_playthrough uses production input, gravity, hitscan, real stairs,
ramps and one scene instance to complete objectives and return to the car.
--combat drives the alternative guardian fight. botanical_rules_test checks
negative solutions, independent destinations, partial saves, retry, touch map,
menu resume, profile restoration and New Adventure. Retain intro/race/diner gates.

Android1.33/code34. A stable PUBLIC TEST debug keystore is pinned from now on.
Older1.31/1.32 APKs had unrelated ephemeral signatures and require removal before
installing this test version. Future debug builds preserve this test key. It is
not a store/release signing key. Verify matching CI/source/artifacts in PR11.
