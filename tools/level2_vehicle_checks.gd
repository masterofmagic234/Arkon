extends RefCounted

const Car = preload("res://scripts/race_car_controller.gd")
const Data = preload("res://scripts/race_level_data.gd")
const Marks = preload("res://scripts/race_skid_marks.gd")

static func run_dynamics() -> String:
    var track := PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
    var pattern: Array = [0, 0, 0, 0]
    var car = Car.new()
    car.setup(true)
    car.place_on_grid(0, 0.0, track)
    car.set_inputs(0.0, 1.0, 0.0)
    var hundred_time := -1.0
    var shift_rpm := 0.0
    var shift_count := 0
    var rpm_dropped := false
    var shift_check_time := -1.0
    for step in range(7200):
        var before_rpm: float = car.engine_rpm
        car.tick(1.0 / 60.0, true, pattern, track)
        var seconds := float(step + 1) / 60.0
        var kmh: float = car.speed / Data.SPEED_UNITS_PER_KMH
        if step == 59 and kmh > 22.0:
            return "Launch still accelerates like a supercar"
        if hundred_time < 0.0 and kmh >= 100.0:
            hundred_time = seconds
        if car.powertrain.shift_serial != shift_count:
            shift_count = car.powertrain.shift_serial
            if shift_count == 1:
                shift_rpm = before_rpm
                shift_check_time = seconds + 0.45
                if car.engine_load > 0.50:
                    return "Automatic upshift does not interrupt drive torque"
        if shift_check_time > 0.0 and seconds >= shift_check_time:
            rpm_dropped = car.engine_rpm < shift_rpm - 800.0
            shift_check_time = -1.0
        if car.engine_rpm < 800.0 or car.engine_rpm > 6550.0 or car.gear < 1 or car.gear > 4:
            return "Automatic gear/RPM range is invalid"
    if hundred_time < 7.5 or hundred_time > 11.5:
        return "0-100 km/h is outside the tuned coupe acceleration range: %s" % hundred_time
    if not rpm_dropped or shift_count != 3 or car.gear != 4:
        return "Full-throttle acceleration does not produce three stable automatic upshifts with an RPM drop"
    if absf(car.speed / Data.SPEED_UNITS_PER_KMH - 219.0) > 0.1:
        return "219 km/h cap is not reachable after realistic acceleration"
    if car.tyre_squeal > 0.01:
        return "Tires squeal during straight-line acceleration"
    car.set_inputs(0.0, 1.0, 1.0)
    var marks = Marks.new()
    for step in range(540):
        car.tick(1.0 / 60.0, true, pattern, track)
        marks.update(car, pattern.size(), Data.SEGMENT_HEIGHT, 1.0 / 60.0)
        if step == 20 and car.tyre_squeal < 0.75:
            return "Heavy braking does not produce tire friction"
    if car.speed > 0.001 or car.gear != 1 or absf(car.engine_rpm - 850.0) > 5.0:
        return "Braking cannot return the automatic to a stationary first gear and idle"
    if car.tyre_squeal > 0.001 or marks.segments.is_empty() or marks.segments.size() > Marks.MAX_SEGMENTS:
        return "Skid marks are missing/unbounded, or stopped tires still squeal"
    var first: PackedVector2Array = marks.segments[0].points.duplicate()
    var count: int = marks.segments.size()
    for step in range(30):
        car.tick(1.0 / 60.0, true, pattern, track)
        marks.update(car, pattern.size(), Data.SEGMENT_HEIGHT, 1.0 / 60.0)
    if marks.segments.size() != count or marks.segments[0].points != first:
        return "Skid marks move with the player or keep spawning at rest"
    marks.update(car, pattern.size(), Data.SEGMENT_HEIGHT, Marks.LIFETIME + 1.0)
    if not marks.segments.is_empty():
        return "Old tire traces do not expire"
    car.speed = 32.0
    car.powertrain.gear = 4
    car.powertrain.engine_rpm = car.powertrain.road_rpm(car.speed / 1.152, 4)
    car.set_inputs(0.0, 1.0, 0.0)
    car.tick(1.0 / 60.0, true, pattern, track)
    if car.gear != 3 or car.powertrain.shift_up:
        return "Automatic kickdown does not select a lower safe gear"
    car.speed = Data.PLAYER_MAX_SPEED
    car.lateral_offset = 0.0
    car.set_inputs(1.0, 0.0, 0.0)
    for step in range(24):
        car.tick(1.0 / 60.0, true, pattern, track)
    if car.tyre_squeal < 0.4:
        return "A hard high-speed corner does not produce tire scrub"
    print("LEVEL2 VEHICLE: PASS; 0-100=", hundred_time, "s; automatic=4-speed; top=219km/h; skids bounded and stationary")
    return ""

static func check_presentation(level) -> String:
    var car = level.controller.player
    var overlay = level.car_3d_overlay
    var audio = level.vehicle_audio
    var viewport_size: Vector2 = level.get_viewport_rect().size
    car.set_inputs(0.0, 0.0, 0.0)
    car.speed = 0.0
    car.heading_yaw = 0.0
    level.camera_state.reset(car)
    level._process(1.0 / 60.0)
    for wheel in overlay.rig.wheels:
        var point: Vector3 = overlay.model_instance.global_transform * (wheel.steer.position - Vector3(0.0, float(wheel.radius), 0.0))
        if absf(point.y) > 0.001:
            return "A tire contact is above the common ground plane"
        var local_screen: Vector2 = overlay.camera.unproject_position(point)
        var actual: Vector2 = overlay.position + overlay.pivot_offset + (local_screen - overlay.pivot_offset).rotated(overlay.rotation)
        var target: Vector2 = level.renderer.project_ground(car.world_x - point.x, 0.45 + point.z, viewport_size)
        if actual.distance_to(target) > 0.10:
            return "A model tire contact disagrees with the main ground projection: %s px" % actual.distance_to(target)
        if bool(wheel.front):
            var tire = wheel.roll.get_child(0)
            var bounds: AABB = tire.mesh.get_aabb()
            if bounds.size.x > bounds.size.z * 0.60:
                return "The source 25-degree front-wheel steering is still baked into neutral geometry"
    var contact_before: Vector3 = overlay.rig.wheels[0].steer.global_position
    car.longitudinal_acceleration = 12.0
    level._process(1.0)
    if overlay.rig.wheels[0].steer.global_position.distance_to(contact_before) > 0.001 or absf(overlay.body_pivot.rotation.x) < 0.005:
        return "Suspension lifts tires instead of moving the sprung body"
    if audio.car != car or audio.layers.size() != 8:
        return "Vehicle audio does not consume the authoritative engine state"
    for layer in audio.layers:
        if layer.player.stream == null or layer.player.stream.get_length() < 1.9:
            return "A generated engine RPM/load loop is missing"
    var game_state = level.get_node("/root/GameState")
    var muted_before: bool = game_state.sfx_muted
    game_state.sfx_muted = false
    audio._process(0.1)
    var active := false
    for layer in audio.layers:
        active = active or layer.player.playing
    game_state.sfx_muted = true
    audio._process(0.1)
    for layer in audio.layers:
        if layer.player.playing:
            game_state.sfx_muted = muted_before
            return "SFX mute does not stop a vehicle engine layer"
    if not active or audio.tire_player.stream == null or audio.shift_player.stream == null:
        game_state.sfx_muted = muted_before
        return "Engine playback, tire friction or shift sound is absent"
    game_state.sfx_muted = muted_before
    return ""
