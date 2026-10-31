> Current Level1 phone performance and masonry work: `HANDOFF_2026-10-21_LEVEL1_PHONE.md` (1.28/code29). The 1.27 map and helicopter history below remain background.

# Lake estate / helicopter tile-GPU repair

Repo masterofmagic234/Arkon, branch fix/level2-final-game-flow, PR 11.
Do not merge automatically. Start from 04abe6b44fe2029207d62e962c99c1c9bb5a306c,
verified successful Actions #1047 (39501801277), Android 1.26/code27.
The user liked heist mechanics but rejected the old small four-quadrant map.
This work is a replacement of its spatial design, plus a P0 helicopter fix.

## P0 helicopter

The 1.25 shared viewport fix retained nine complete mutable projected scenery
meshes. Shader discards outside the aircraft rectangle do not stop those road,
verge and foliage triangles from entering rasterization; alpha/discard prevents
the usual cheap opaque depth path. This is an unnecessary tile-GPU workload.
Now two dedicated depth meshes consume existing CPU source arrays, with no
mesh readback and no 2D/3D shared mutable mesh. Triangles behind the farthest
part of the aircraft or outside its rectangle are rejected; intersecting ones
are clipped with reciprocal depth, coverage UV and vertex-alpha interpolation.
The mask is rebuilt after the current frame's projection, through an explicit
renderer binding. Inactive/offscreen/tunnel phases have no mask submission.
The model, flight, screen resolution, atlas coverage, bias, camera roll, cars,
rotor blur, radio and spikes are retained. No extra viewport/texture pass.

At native 1920x864 production poses (forest 900m, mountain 4400m, city 7700m),
source triangles 2184/2164/1926 become 153/156/126 (93–94% fewer submitted).
CPU clipping measured 1.3–1.8ms on this host. Software Vulkan total draw/readback
medians with helicopter: 343->361ms, 383->354ms, 300->281ms. Forest is slightly
slower on this CPU renderer; do not claim universal FPS gains or device proof.
The material/submission and raster workload reduction targets the phone issue.
Real phone FPS remains acceptance work, not something measured by this host.

Local pursuit mechanics, C2 flight and full input-driven 8.88km escape pass.
Native Forward+ retains all 12 opaque/foliage/front/back/roll cases across
1280x720 and 1920x864 with original pixel thresholds. The fixture now also
asserts two submissions and CPU-clipped vertices. Moving-flight native checks
assert the same invariant, which the old visual-only tests could not detect.

## Android 1.27 / code 28: full Level 1 replacement

The old 48x36 four-quadrant layout is replaced by an authored 88x64 estate:
158.4 x 115.2 metres, 2878 walkable cells. This is roughly 3.26 times the
bounding area. It is not a rescale of the old maze. Four outdoor rooms frame
two bodies of water: gardener's alley, lakeside observatory, ruined greenhouse
and the lantern grove. A 19m clock tower and 18m oak orient the player across
long views; cover, shoreline, flanks and rewards shape local movement.

Progression after Key01 is genuinely branching. It unlocks both Door01 and
Door02; the observatory and greenhouse can be completed in either order.
Door03 needs both Key02 and Key03, including when collected in reverse order.
The oak seal also needs both real puzzle completions. The moon mechanism opens
two physical gates: the southern MoonWicket and the northern link to the
other branch. The oak opens ReturnGate across the lake. There is no redundant
"open every gate" finish quota: taking the northern shortcut can bypass Door02.
The six real acorns, boarding Area3D and campaign transition remain authoritative.

Three shortcuts use the same Level1Door physics/tween/navigation lifecycle as
key gates. Zone entry activates existing finite encounters even when approached
through a shortcut. Sound connectivity now traverses the real open-gate graph,
not the old linear zone chain. Navigation readiness resets at the beginning of
a rebuild, so callers cannot mistake the old mesh for an updated gate state.

Keep the existing 1.26 quiet movement, physical dash, distraction bells, three
lenses, relay sabotage, oak work, six acorns, three keys, notes, supplies, result
screen and persisted record. There are still 14 finite guards. No health,
ammo, enemy HP, fire cadence or invulnerability cheats compensate for geometry.
Quiet outer flanks and useful bell positions provide a genuine zero-shot route.
Escape reveals gold ground chevrons towards the newly opened return bridge.
The HUD now names the actual area and presents a choice of the two branches.

## Geometry ownership and rendering

- tools/generate_level1_layout.py is the sole source for map cells, water rows,
  cover rectangles, path routes, bridge alignment, scene collision and actor
  positions. Its --check mode must pass without rewriting anything.
- scripts/level1_estate.gd builds macro architecture and uses shared existing
  materials/geometry. Paths share one material and 37 spatial batches of 16m,
  rather than dozens of independently authored ribbons. Existing scenery
  batching, occlusion and vegetation LOD remain in use.
- scripts/level1_estate_water.gd renders only physics-blocked water cells, with
  bevelled shores, rounded bank contours and sparse reeds. Bridge landings stay
  clear. The two water bodies share existing reflection/shader assets.
- 280 merged horizontal collision runs replace individual wall-cell bodies.
  Cover silhouettes, bridge rails, columns and scanner footprints are shared
  with navigation and the physics fixtures. Occluder faces are inset into real
  opaque blockers. No invisible polygon masks extend into walkable ground.
- Four flower focal points, 16 lamps, six benches, sparse grass/fireflies and
  above-wall tree crowns give each space breathing room. No new heavy external
  assets or realtime lights were introduced. Camera far 140m contains fog end
  108m; the old 85m clip was too short for the new views.

## Deferred helicopter pipeline warm-up

In addition to CPU-clipped scenery submission, idle native rendering now
submits the actual production hull, rotor and depth-mask pipelines before
first ingress. The hull is wholly behind the camera, with explicit culling
bounds; tiny production-format mask triangles are wholly outside the viewport.
A one-shot frame_post_draw callback restores transforms/bounds and retires all
warm-up draws. Headless tests and fixtures with a disabled render loop skip
automatic warm-up. There is no extra viewport, visible flash, persistent mask
submission or reduced render resolution. Flight and deployment stay unchanged.

The native depth fixture primes the transparent vehicle composite before its
startup comparison, then explicitly exercises warm-up and verifies unchanged
pixels and retired visibility. This avoids comparing against the target's
uninitialised first composite. All twelve existing front/back, wall/foliage,
roll and two-resolution occlusion cases retain their original thresholds.

## Local evidence and release procedure

Godot 4.7.2 official ed1daf0bf, native Forward+ Vulkan via llvmpipe LLVM20;
software rendering is visual evidence and is NOT phone FPS evidence.

The 21 headless CI gates pass locally after the path batch optimisation, with
runtime/parser errors checked, including intro decoding, park physics/polish,
heist interactions, all three routes, race/pursuit and diner/campaign checks.
The new estate fixture exercises real pickups/gates, reverse key order, both
branches, capsule-clear flanks and shortened navigation paths. Moon shortcut
48.1 -> 30.7m; return 104.8 -> 54.2m. The gallery-first no-shot input route
finishes with HP100, shots0, roughly 324 simulation seconds. Normal and optional
exploration routes also reach the actual Level2 handoff through production input.
The water/physics fixture checks 6500 triangle samples and park coverage checks
22528 physics samples. Native startup and all twelve airframe depth cases pass.

Recheck the current branch SHA and exact matching Actions run before claiming
an APK. PR11 remains open: do not merge automatically. Record final source SHA,
CI run, tested PR-merge tree and APK integrity/version evidence in PR11's body,
so release evidence does not itself create another untested source HEAD.
