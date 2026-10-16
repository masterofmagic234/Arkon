extends SceneTree
const Flight=preload("res://scripts/race_helicopter_flight.gd")
const Pursuit=preload("res://scripts/race_pursuit.gd")
const Data=preload("res://scripts/race_level_data.gd")
const Math=preload("res://scripts/race_math.gd")
var failed:=false

func _init() -> void: call_deferred("_run")
func check(ok: bool,message: String) -> void:
    if not ok: failed=true;push_error("AIRFRAME MOTION: "+message)

func _run() -> void:
    var maximum_speed:=0.0;var maximum_acceleration:=0.0;var maximum_jerk:=0.0
    for offset: float in [-85,0,85]:
        var f:=Flight.new();var start:=Vector3(0,24,-35);var target:=Vector3(offset,7.2,680)
        f.plan(start,target,.75,.025)
        var old_velocity:=f.velocity;var old_acceleration:=f.acceleration
        var old_position:=f.position
        var dt:=1.0/120;var count:=ceili(f.duration/dt)
        dt=f.duration/count
        for frame in range(1,count+1):
            f.pass_at(frame*dt,dt)
            var acceleration: float=(f.velocity-old_velocity).length()/dt
            var jerk: float=(f.acceleration-old_acceleration).length()/dt
            maximum_speed=maxf(maximum_speed,f.velocity.length());maximum_acceleration=maxf(maximum_acceleration,acceleration);maximum_jerk=maxf(maximum_jerk,jerk)
            check(f.position.distance_to(old_position)<Flight.MAX_SPEED*dt*1.01,"position discontinuity")
            check(acceleration<=Flight.MAX_ACCELERATION*1.02,"unbounded pass acceleration")
            check(jerk<=Flight.MAX_JERK*1.03,"unbounded pass jerk")
            var drag:=Vector3(f.velocity.x*absf(f.velocity.x),f.velocity.y*absf(f.velocity.y),f.velocity.z*absf(f.velocity.z))*Flight.DRAG
            check((f.thrust+Vector3.DOWN*Flight.GRAVITY-drag-f.acceleration).length()<.001,"rotor thrust does not support the required flight vector")
            var rotor:=Basis.from_euler(Vector3(f.rotor_pitch,f.yaw,f.rotor_bank))
            check(rotor.y.normalized().dot(f.thrust.normalized())>.999,"rotor disc tilts away from thrust")
            old_velocity=f.velocity;old_acceleration=f.acceleration;old_position=f.position
        var release_velocity:=f.velocity
        for frame in range(90): f.coast(.75/90)
        check(Vector2(f.position.x-target.x,f.position.z-target.z).length()<.05,"moving release misses the locked ground rack")
        check((f.velocity-release_velocity).length()<.001,"aircraft stops or jumps speed during release")
        old_velocity=f.velocity;old_acceleration=f.acceleration
        for frame in range(1200):
            f.depart(dt,-1 if offset<0 else 1,Data.PLAYER_MAX_SPEED)
            check((f.velocity-old_velocity).length()/dt<Flight.MAX_ACCELERATION*1.02,"departure jumps velocity")
            check((f.acceleration-old_acceleration).length()/dt<Flight.MAX_JERK*1.02,"departure jumps acceleration")
            check(absf(f.bank)<.85 and absf(f.pitch)<.85,"hull reaches an implausible attitude")
            old_velocity=f.velocity;old_acceleration=f.acceleration
    # Live controller boundaries must preserve the same motion, with real
    # maximum-speed car travel and a reaction margin after the rack lands.
    var controller=preload("res://scripts/race_controller.gd").new()
    var state=preload("res://scripts/race_state.gd").new()
    controller.setup(root,null,[],null,null,null,null,null,state,Callable());controller.start()
    var p=controller.player;var d=controller.pursuit
    state.race_started=true;state.race_time=20
    p.speed=Data.PLAYER_MAX_SPEED
    var z:=0.0
    for at in range(400,2400,20):
        p.world_z=at;p.world_x=Math.track_center_x(p.world_z/40,controller.track_x)
        z=d.planned_drop_z(p,controller.track_x)
        if d.safe_drop_zone(z,controller.track_x): break
    check(d.safe_drop_zone(z,controller.track_x),"no feasible live air pass")
    d._begin(p,z,controller.track_x)
    print("AIRFRAME LIVE PLAN: target=",z," duration=",d.flight.duration," speed=",d.flight.velocity," safe=",d.safe_drop_zone(z,controller.track_x))
    var velocity: Vector3=d.flight.velocity
    var acceleration: Vector3=d.flight.acceleration
    var last_phase: StringName=d.phase
    var landed:=false
    for frame in range(1500):
        var dt:=1.0/60
        d.prepare(dt,state,p,[]);p.world_z+=p.speed*dt
        d.tick(dt,state,p,[],controller.track_x)
        check((d.flight.velocity-velocity).length()/dt<Flight.MAX_ACCELERATION*1.03,"controller phase boundary changes velocity")
        check((d.flight.acceleration-acceleration).length()/dt<Flight.MAX_JERK*1.04,"controller phase boundary changes acceleration")
        if last_phase==&"drop" and d.phase==&"depart":
            landed=true
            check(z-p.world_z>p.speed*1.7,"deployment leaves insufficient evasive time")
        last_phase=d.phase;velocity=d.flight.velocity;acceleration=d.flight.acceleration
        if d.phase==&"idle": break
    check(landed,"live flight never releases its strip")
    controller.teardown()
    print("AIRFRAME MOTION: peaks speed/acceleration/jerk=",[maximum_speed,maximum_acceleration,maximum_jerk])
    if failed: quit(1)
    else: print("AIRFRAME MOTION: PASS — C2 pass, bounded acceleration/jerk, thrust-aligned disc, moving release, inertial departure and safe live timings");quit(0)
