extends RefCounted
const Data=preload("res://scripts/race_level_data.gd")
const Math=preload("res://scripts/race_math.gd")
const Barriers=preload("res://scripts/race_barriers.gd")
const Car=preload("res://scripts/race_car_controller.gd")
static func run() -> String:
    var pattern := Data.get_track_pattern()
    var track := Math.accumulate_track_x(pattern)
    var car := Car.new();car.setup(true);car.place_on_grid(0,0,track)
    car.set_inputs(0,1,0)
    var contacts := 0
    for i in range(3600):
        car.tick(1.0/60,true,pattern,track)
        if car.wall_contact>0: contacts+=1
    if contacts==0 or car.world_z>800 or absf(car.world_x)>.02 or absf(car.heading_yaw)>.001:
        return "An unsteered car is automatically carried through the first bend"
    for z: float in [1500,2300,3500]:
        var c := Math.track_center_x(z/40,track)
        for side: float in [-1,1]:
            var result := Barriers.sweep(Vector2(c,z),Vector2(c+side*30,z+6),pattern,track,0)
            var limits := Barriers.limits(result.y,pattern,track)
            if result.z==0 or result.x<limits.x-.001 or result.x>limits.y+.001:
                return "A swept body crosses a field fence, bridge rail or tunnel wall"
            var driven := Car.new();driven.setup(true);driven.place_on_grid(0,0,track)
            driven.segment_index=floori(z/40);driven.segment_progress=z/40-driven.segment_index
            driven.world_z=z;driven.world_x=c;driven.speed=Data.PLAYER_MAX_SPEED
            driven.set_inputs(side,1,0)
            var impacts := 0
            for step in range(240):
                driven.tick(1.0/60,true,pattern,track)
                if driven.wall_contact>0: impacts+=1
                var clearance := Barriers.BODY_HALF_WIDTH*absf(cos(driven.heading_yaw))+Barriers.BODY_HALF_LENGTH*absf(sin(driven.heading_yaw))
                var body_bounds := Barriers.limits(driven.world_z,pattern,track,clearance)
                if driven.world_x<body_bounds.x-.002 or driven.world_x>body_bounds.y+.002:
                    return "Production driving lets the rotated body pass through a scenic wall"
            if impacts==0: return "Full steering never reaches the expected scenic wall"
    var z := Data.TUNNEL_START-8
    var c := Math.track_center_x(z/40,track)
    var portal := Barriers.sweep(Vector2(c+8,z),Vector2(c+8,Data.TUNNEL_START+8),pattern,track,0)
    if portal.z==0 or portal.y>=Data.TUNNEL_START:
        return "A car outside the opening drives through the mountain portal"
    # An impact must allow deliberate recovery rather than pinning the car.
    var before: float=car.world_z
    car.set_inputs(1,1,0)
    for i in range(180): car.tick(1.0/60,true,pattern,track)
    if car.world_z<before+2 or car.world_x<.5:
        return "Steering cannot recover a car after a real wall contact"
    print("RACE BARRIERS: PASS — gas-only stops at bend without world-X/yaw assistance; swept fences/bridge/tunnel; blocked portal; deliberate steering recovery")
    return ""
