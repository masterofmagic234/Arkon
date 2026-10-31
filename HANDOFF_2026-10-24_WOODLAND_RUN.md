# Woodland Run — Android 1.30 / code31

The owner's screenshot supersedes Quiet Park: rebuild the FIRST LEVEL in full,
including gameplay, with cute atmospheric but grounded squirrel-matching art.
Remote audit before work found unchanged ae1bcdc74300859df024cebf78a69ca7e4467da3;
no implementation of the screenshot request was present.

`game.tscn` now launches `scripts/level1_woodland.gd`; campaign paths remain
unchanged. New modules own the authored world, mission, patrol/charge encounter,
HUD and spatial sound. Shared player/combat/health/scene routing are reused.
Legacy estate scene is reference-only and excluded from Android.

Mission: three independent trail tasks in any order -> protected tank encounter
with locked-direction windup/physical charge/recovery -> collect oak cache ->
explicit car interaction -> existing Level2. The supplied 78-bone tank rig uses
7,013 runtime triangles and 1K texture maps. Source, preparation script and
provenance are retained; source files are not packaged.

Native artwork uses textured bark/ground/foliage, soft dusk lighting and bounded
sun shadows. Spatial batches and a simple parked-car shadow proxy avoid paying
for the car's entire interior in the shadow map. Android keeps native UI while
capping 3D pixels to1280x720; prior lower scales are respected and restored on
scene exit. No full-screen glow. Real phone FPS remains unmeasured.

Tests: new normal/reverse input-driven mission, actual guard hitscan/dodge,
independent three-finger controls, tank rig, retry/pause/saved mute/cache action
priority, all campaign transitions. Existing intro/race/diner behavior and
native renderer fixtures remain. Old L1 grid-specific gates are replaced rather
than counted as evidence for the new level. Native9-view fixture includes actual
visible+shadow+canvas submission budgets and three phone aspect ratios.

Use latest PR11 body for matching final commit, successful CI and APK evidence.
Keep PR11 open; do not merge automatically. Acceptance of the new art and phone
performance require playing the delivered version on the owner's device.
