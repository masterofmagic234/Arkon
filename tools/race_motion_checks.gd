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
    var route := Data.get_track_pattern();var centers := Math.accumulate_track_x(route)
    var contacts: Array[int]=[]
    for braking in [false,true]:
        car=Car.new();car.setup(true);car.place_on_grid(0,0,centers)
        var z := 280.0;car.segment_index=floori(z/40);car.segment_progress=z/40-car.segment_index
        car.world_z=z;car.world_x=Math.track_center_x(z/40,centers);car.speed=Data.PLAYER_MAX_SPEED
        var hits := 0
        for tick in range(750):
            var at: float=car.track_phase()
            var tangent := atan2(Math.track_center_slope(at+.25,centers),40)
            var error: float=Math.track_center_x(at,centers)-car.world_x
            var target := tangent+clampf(error*.08,-.15,.15)
            var steer := clampf(target/(Data.NFS_MAX_HEADING_YAW*lerpf(1,.48,car.speed/Data.PLAYER_MAX_SPEED)),-1,1)
            var safe := Math.safe_corner_speed(at,centers,Data.PLAYER_MAX_SPEED,Data.NFS_MAX_HEADING_YAW,Data.CORNER_GRIP_ACCEL)
            car.set_inputs(steer,1,clampf((car.speed-safe)/3,0,.85) if braking else 0)
            car.tick(1.0/60,true,route,centers)
            if car.wall_contact>0: hits+=1
            if car.world_z>720: break
        contacts.append(hits)
    if contacts[0]==0 or contacts[1]>0: return "Full-speed corner succeeds without braking, or a braked corner cannot be driven cleanly: %s"%[contacts]
    print("RACE MOTION: PASS — 120Hz presentation advances between physics poses; ordinary steering is quiet; 219km/h corner meets rail, braked corner is clean")
    return ""
