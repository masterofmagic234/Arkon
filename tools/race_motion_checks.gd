extends RefCounted
const Car=preload("res://scripts/race_car_controller.gd")
const Pose=preload("res://scripts/race_render_car.gd")
const Data=preload("res://scripts/race_level_data.gd")
const Math=preload("res://scripts/race_math.gd")
static func run() -> String:
    var track := PackedFloat32Array();track.resize(1000);track.fill(0)
    var pattern: Array=[];pattern.resize(1000);pattern.fill(0)
    var car=Car.new();car.setup(true);car.place_on_grid(0,0,track);car.speed=40
    var pose=Pose.new();pose.setup(car)
    var mid_frames := 0
    var squeal := 0.0
    for step in range(120):
        car.set_inputs(.15,1,0);car.tick(1.0/60,true,pattern,track);pose.capture()
        pose.sample(.25);var first: float=pose.world_z
        pose.sample(.75);var second: float=pose.world_z
        if second>first+.1: mid_frames+=1
        if absf(float(pose.world_z)-car.world_z)>2: return "Presentation falls multiple physics steps behind the car"
        squeal=maxf(squeal,float(car.tyre_squeal))
    if mid_frames!=120: return "Vehicle presentation repeats physics poses between display frames"
    if squeal>.05: return "Ordinary steering constantly triggers tire squeal"
    # A noisy thumb and a hard reversal must not teleport the wheel/chassis.
    car=Car.new();car.setup(true);car.place_on_grid(0,0,track);car.speed=110*.32
    var previous_wheel := 0.0;var previous_yaw := 0.0
    var max_wheel_step := 0.0;var max_yaw_step := 0.0
    for tick in range(180):
        car.lateral_offset=0;car.world_x=0
        car.set_inputs((.6 if tick<60 else -.6)+sin(tick*2.7)*.035,0,0)
        car.tick(1.0/60,true,pattern,track)
        max_wheel_step=maxf(max_wheel_step,absf(car.steering_angle-previous_wheel))
        max_yaw_step=maxf(max_yaw_step,absf(car.heading_yaw-previous_yaw))
        if tick==0 and absf(car.heading_yaw)>.001: return "Touch input instantly jerks the chassis"
        if tick==59 and car.steering_angle<.25: return "Usable front wheel lock is missing at 110km/h"
        previous_wheel=car.steering_angle;previous_yaw=car.heading_yaw
    if max_wheel_step>.05 or max_yaw_step>.009: return "Hard steering reversal has a discontinuous pose"
    if car.steering_angle>=0 or car.heading_yaw>=0: return "Weighted steering does not recover into the opposite turn"
    car=Car.new();car.setup(true);car.place_on_grid(0,0,track)
    for tick in range(90): car.set_inputs(1,0,0);car.tick(1.0/60,true,pattern,track)
    if car.steering_angle<deg_to_rad(35) or absf(car.world_x)>.001 or absf(car.heading_yaw)>.001: return "Full parking lock moves the stationary chassis or lacks lock"
    var route := Data.get_track_pattern();var centers := Math.accumulate_track_x(route)
    var contacts: Array[int]=[]
    for braking in [false,true]:
        car=Car.new();car.setup(true);car.place_on_grid(0,0,centers)
        var z := 280.0;car.segment_index=floori(z/40);car.segment_progress=z/40-car.segment_index
        car.world_z=z;car.world_x=Math.track_center_x(z/40,centers);car.speed=Data.PLAYER_MAX_SPEED
        var hits := 0
        for tick in range(750):
            var at: float=car.track_phase()
            var tangent := atan2(Math.track_center_slope(at+.6,centers),40)
            var error: float=Math.track_center_x(at,centers)-car.world_x
            var target := tangent+clampf(error*.08,-.15,.15)
            var steer := Data.steer_for_heading(target,car.speed/Data.PLAYER_MAX_SPEED)
            var safe := Math.safe_corner_speed(at,centers,Data.PLAYER_MAX_SPEED,Data.NFS_MAX_HEADING_YAW,Data.CORNER_GRIP_ACCEL)
            car.set_inputs(steer,1,clampf((car.speed-safe)/3,0,.85) if braking else 0)
            car.tick(1.0/60,true,route,centers)
            if car.wall_contact>0: hits+=1
            if car.world_z>720: break
        contacts.append(hits)
    if contacts[0]==0 or contacts[1]>0: return "Full-speed corner succeeds without braking, or a braked corner cannot be driven cleanly: %s"%[contacts]
    print("RACE MOTION: PASS — 120Hz presentation advances between physics poses; ordinary steering is quiet; 219km/h corner meets rail, braked corner is clean")
    return ""
