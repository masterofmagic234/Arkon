# Open forest trails — Android 1.32 / code33

Read this before the eight-locations handoff. The owner tested 1.31 and still
experienced only the original clearing. Its other locations were gated behind
completing the whole opening mission and an obscure interact ring. Do not call
that experience a clearly connected forest.

All trails now allow exploration before completing local quests. Actual gaps
in the perimeter, extended walkable paths, destination signs and automatic
crossings replace rings. Arrivals use the incoming end and cannot immediately
bounce back. A persistent direction/distance hint and drawn eight-node map
advertise the other places. The mill has a public footbridge; its separate
sluice puzzle and reward stay locked until solved. The ravine keeps its bridge
route, wind and rescue behavior.

Each location still loads separately through SceneFlow. This is not seamless
terrain streaming and should not be described that way. Finished quests restore;
partial local tasks restart on reentry. Completion still requires all eight
quest rewards plus the original car. The schema2 checkpoint adds visited/entry,
accepts schema1 and permits exploration beyond the completed frontier.

woodland_open_trails_test starts a clean run and uses production movement and
actual forward/backward crossings through all eight places with ZERO completed
quests, then verifies checkpoint resume. No staged checkpoint or player teleport
is allowed in that test. The full mission playthrough/rules/campaign gates remain.
Keep PR11 open. Record the matching CI/APK evidence in its body.
