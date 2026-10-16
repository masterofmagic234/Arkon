# Level 2 helicopter depth / weighted flight — Android 1.24 / code 25

Repository masterofmagic234/Arkon, branch fix/level2-final-game-flow, PR 11.
Do not merge automatically. Starts at verified 9928ca0e413fa75036333305e4d112a4f030a9cd,
successful Actions #1037. User reports the helicopter drawing over scenery and
asks for the weight/thrust/directional feel of a Hot Pursuit helicopter.
Preserve the pseudo-3D road, shared player camera/handling, radio, car tactics,
solid contacts, route/finish, Levels 1/3 and the current repository intro.
The user's newer cutscene keyframes are separate art work; do not substitute
them or overwrite unrelated local intro/image edits while fixing Level 2.

## Actual causes and depth repair

The airframe's StandardMaterials knew only the vehicle-world Z buffer. The
canvas trees, facades, boards, bridge/terrain/roof never wrote to that buffer.
Hiding the whole aircraft in sector 4 could not fix partial occlusion elsewhere.

Scenery batches now retain reciprocal camera depth in the previously unused
mesh vertex Z. Canvas XY/colors/UVs/ordering stay unchanged. Screen clipping
interpolates reciprocal depth through the existing attribute-preserving clipper.
The air unit shares those exact ArrayMeshes with a small offscreen depth
rasterizer, including the existing ground/roof UV depth and foliage atlas alpha.
A flat raster camera does not own or move the production chase camera.
Its reverse-Z buffer resolves nearest scenery per pixel; 24-bit encoded depth
survives the LDR target with explicit color/output correction. All airframe
materials and mesh lettering compare their actual fragment depth against it.
The viewport-to-canvas transform includes the production yaw/alignment/roll.
Rotor blur uses the same occlusion. No CPU pixel loops/readback/ray marching,
new road model, scene-wide 3D conversion or duplicate per-frame meshes.

The auxiliary target is separate from the visible SubViewportContainer and
shares nine existing mesh surfaces. It is created lazily and updates only
while the aircraft's conservative sphere intersects the camera on open road.
Idle, out-of-frame and tunnel phases disable it. It never appears on screen.

## Flight repair

The previous independent smoothstep segments stopped/restarted the aircraft,
then imposed an immediate high-speed departure. Pitch was almost constant,
bank came from phase presets, yaw followed the future road, and only position
was interpolated. The rotor could also intersect the decorative intake fins.

race_helicopter_flight.gd now plans one C2 pass with continuous position,
velocity and acceleration, sampled acceleration/jerk/speed bounds (90 m/s,
6 m/s^2, 6 m/s^3) and an adaptive duration (minimum eight seconds). The craft
enters from behind the whole frustum already carrying airspeed, brakes into
a moving low pass and keeps that velocity through release. Gravity, quadratic
drag and required net acceleration define the rotor thrust vector. Disc tilt
follows that vector; a damped hull/yaw response and quaternion render
interpolation give the fuselage angular inertia. Departure integrates bounded
jerk/acceleration into an outward climbing turn, retaining entry/exit visibility
checks. This is feasible cinematic flight, not a full aviation simulator.

The rack inherits horizontal motion toward the locked ground target; the fall
speeds up vertically. The lane stays locked and the 3.8 m escape corridor,
wheel sweep, warnings, tire effects and AI evasion remain. Planning includes
flight, fall and dodge time. The raised rotor mast clears the intake fins;
load-related blade coning and subtle main/tail blur avoid blade strobing.
Rotor audio uses 3D distance and load, with small governed-RPM droop rather
than an unrelated sinusoid. Existing mute/volume/pause/lifecycle stay intact.

## Validation and release

New motion gate checks finite-difference acceleration/jerk across the complete
pass/release/departure, thrust/disc agreement, moving-rack landing and live
maximum-speed reaction time. Native Forward+ depth fixtures check opaque
wall and real atlas foliage pixels, transparent holes, near/far aircraft,
shared-camera roll and an idle target. Existing pursuit visual checks use
the planner and its bounded actual duration rather than the old fixed timing.

Local mechanics, motion, radio/tactics, full production-input escape,
park/race/camera/scenery budgets, second-pass and full campaign passed.
Current live escape: 209.73 s, five drops, zero spike hits, three contacts,
three completed brake checks and 0.000% AI offroad samples. Original 210 +/-6 s
and minimum-three-drops gates remain. Native production aircraft/spikes,
rotors, tunnel and stationary/moving-camera ingress/egress also passed.
Before delivery verify the final current head, matching merge tree and exact
successful Actions, all packaged scripts/shaders/includes, Android version
and Forward+ settings. Record final hashes/native evidence in PR metadata.
Host software Vulkan does not establish phone FPS. Deliver the verified APK;
any flight movie is a staged production-camera preview, not a phone recording.

Keep all prior gates, add motion and native depth checks before Android export.
Stage authored files only; ignore incidental import drift. PR 11 stays open.
