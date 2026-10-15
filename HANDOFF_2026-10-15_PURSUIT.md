# Level 2 — squirrel pursuit / ORЕХ-1, Android 1.20 / code 21

Read this first. Repository masterofmagic234/Arkon, branch
fix/level2-final-game-flow, PR 11. Do not merge. Starting verified published
HEAD 18b25e088a7cb6693bfbdac269bc16eb0c39674e, successful Actions #1025.
The user clarified that Level 2 is an escape from squirrels in cars, not a
race, and requested a squirrel helicopter dropping spikes like Hot Pursuit.
Level 1 optimization was explicitly deferred. Leave Levels 1 and 3 intact.

## Final mechanics

- Existing 240SX input/handling, shared nose-follow camera, interpolation,
  219 km/h powertrain, 8.88 km physical route/seven sectors and Continue to
  Level 3 remain. Player origin/physical finish offset stay unchanged.
- The three live Camrys start 21/35/49 metres behind the player. Their AI
  regulates relative distance rather than trying to win. One attacker at a
  time lines up for .9s, attempts a .8s side ram, then withdraws/cools down.
  The HUD announces the side. Tires/steering remain controlled by the player.
- Swept relative car contacts apply capped opposing lateral impulses and a
  small speed loss, with a 1.6s per-pair cooldown. The shove is integrated and
  decayed by the existing car physics/barrier sweep; it does not change the
  steering response, turn the camera independently or teleport cars.
- RacePursuit owns the air unit, warnings and physical strips on the fixed
  clock. ORЕХ-1 approaches for 2.4s, drops a strip over .75s, banks away for
  four seconds and waits 20s. The first warning starts after 12s and 350m.
  Actual attack positions also require open, gentle road; the tunnel, steep
  grades and final 350m are excluded. At speed the target is at least
  speed*4+45m ahead (minimum 180m). The announced side locks immediately.
- A 5.2m rack blocks only part of the 9m road, leaving a 3.8m corridor. Road
  chevrons and a distance/direction alert identify that corridor. Falling or
  warning strips cannot puncture tires. Swept wheel-track crossing handles
  fast cars; a per-car mask prevents repeated hits. Enemy cars are vulnerable
  too and fall back/evade during an air attack; deliberate rams pause then.
- A hit retains 62% speed and imposes a 3.6s reduced drive limit, then fully
  recovers. No forced steering, permanent tire damage, zero-speed lock, new
  health system or automatic failure. Stopping/pausing is still controllable.
- Pause freezes the simulation. Finish/failure clear air hazards; retry makes
  fresh AI/aircraft/tire state. The finish UI celebrates escape, not a rank;
  HUD shows pursuer count and distance to escape. Internal race-prefixed
  classes/ranking bookkeeping remain for the proven physical route math.
  Explicit float division also fixes the progress percentage staying at 0%.

## Visual/audio implementation

One original procedural 3D craft with a dark/ivory/amber hull, glazed cabin,
ear intake fins, solid acorn emblems, tapered curled tail stabilizer, skids,
stinger magazines, chin searchlight and rotating main/tail rotors. It joins
the existing vehicle SubViewport/world/camera. No new cameras, real lights,
particles, source models or full-screen passes. Moving airframe/rotors use
fixed-step interpolation; projected road warnings/spikes share the main
road lens, height, terrain visibility and near/screen clipping.

Three small original PCM rotor/radio/impact clips are generated offline by
tools/generate_pursuit_audio.py. No runtime synthesis. They respect persisted
SFX mute/volume and pause; scene exit stops/releases every audio player.
assets/level2/pursuit/README.md records provenance.

## Validation / release contract

Keep all fourteen prior behavior gates, adding level2_pursuit_test.gd as the
fifteenth. Its checks cover announcement/lane lock, real fall/deployment,
swept hits/safe lane/enemy tires, bounded contact, recovery and actual scene
pause/failure/retry/shared camera. The real-input route now reacts to locked
hazards using normal steering, without teleport, immunity or disabling AI.
Current local route: 211.02s, six completed drops, zero spike hits, ten car
contacts, 0.190% AI offroad samples; actual Continue loads the diner. The
existing 210 +/- 6s clean-drive timing gate is retained.

Native level2_pursuit_visual.gd draws the production aircraft and grounded
spikes through Forward+/Vulkan, checks that it changes real framebuffer
pixels, animates rotors and hides the craft inside the tunnel. Its three
shots are staged presentation fixtures, not screenshots of a live mission.
The previous paired whole-game/native race depth gates stay intact. All
native checks precede Android export; shots stay outside res:// and build/*
stays excluded. Never infer phone FPS from host software Vulkan.

Android 1.20/code 21, arm64 debug, same com.acornhunter.carolina package and
build/AcornHunter-MoonlightSprint.apk output. Verify the final remote HEAD,
successful matching Actions run, PR merge tree and actual APK manifest,
renderer settings, new controller/model/audio resources before delivery.
Native and behavior validation of the published final revision is pending.
Stage authored files only; restore incidental import drift after local QA.

Read HANDOFF_2026-10-15_FORWARD_PLUS.md for renderer/color handling,
HANDOFF_2026-10-15_LEVEL3_RIG.md for squirrels and
HANDOFF_2026-10-13_SPRINT.md for historical route/camera/scenery decisions.
