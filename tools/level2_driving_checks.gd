extends RefCounted

const Car = preload("res://scripts/race_car_controller.gd")
const CameraState = preload("res://scripts/race_camera_state.gd")
const Data = preload("res://scripts/race_level_data.gd")

static func run(tree: SceneTree) -> String:
    var pattern: Array = [0, 0, 0, 0]
    var track := PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
    var car = Car.new()
    car.setup(true)
    car.place_on_grid(0, 0.0, track)
    car.set_inputs(1.0, 0.0, 0.0)
    car.lateral_velocity = 3.0
    for _step in range(60):
        car.tick(1.0 / 60.0, true, pattern, track)
    if absf(car.lateral_offset) > 0.001 or absf(car.heading_yaw) > 0.001:
        return "Stationary car translates/yaws with steering or residual momentum"
    if car.steering_angle < 0.40:
        return "Front wheels cannot steer at rest"
    car.set_inputs(0.0, 1.0, 0.0)
    for _step in range(600):
        car.tick(1.0 / 60.0, true, pattern, track)
    if absf(car.speed / Data.SPEED_UNITS_PER_KMH - 219.0) > 0.1:
        return "Player cannot reach the requested 219 km/h"
    car.set_inputs(0.5, 1.0, 0.0)
    for _step in range(30):
        car.tick(1.0 / 60.0, true, pattern, track)
    if car.lateral_offset <= 0.0 or car.heading_yaw <= 0.0 or car.travel_yaw <= 0.0:
        return "Right input disagrees with movement or body direction"
    var camera = CameraState.new()
    camera.reset(car)
    camera.update_from_race_car(car, 1.0 / 60.0)
    if absf(camera.yaw_offset - car.heading_yaw) > 0.0001:
        return "Main camera direction is not bound to the actual nose"
    car.set_inputs(0.0, 1.0, 1.0)
    for _step in range(180):
        car.tick(1.0 / 60.0, true, pattern, track)
    if car.speed > 0.001:
        return "Brake cannot stop the car while the throttle is held"
    car.lateral_offset = Data.ROAD_WIDTH * 0.5 + Data.OFFROAD_VEHICLE_HALF_WIDTH + Data.OFFROAD_ASPHALT_MARGIN + 1.0
    car.set_inputs(0.0, 1.0, 0.0)
    for _step in range(120):
        car.tick(1.0 / 60.0, true, pattern, track)
    if car.speed < 5.0:
        return "Player cannot drive back from the shoulder"
    car.speed = Data.PLAYER_MAX_SPEED
    for _step in range(180):
        car.tick(1.0 / 60.0, true, pattern, track)
    if car.speed > Data.PLAYER_MAX_SPEED * 0.9:
        return "Full throttle cancels the shoulder penalty"
    var offsets: Array[float] = []
    for hz in [60, 120]:
        var sample = Car.new()
        sample.setup(true)
        sample.place_on_grid(0, 0.0, track)
        sample.speed = 30.0
        sample.set_inputs(0.4, 1.0, 0.0)
        for _step in range(hz):
            sample.tick(1.0 / float(hz), true, pattern, track)
        offsets.append(sample.lateral_offset)
    if absf(offsets[0] - offsets[1]) > 0.10:
        return "Handling changes materially between 60 and 120 simulation steps"

    var bend_car = Car.new()
    bend_car.setup(true)
    var curved_track := PackedFloat32Array([0.0, 1.0, 2.0, 1.0])
    bend_car.place_on_grid(0, 0.0, curved_track)
    bend_car.speed = 20.0
    bend_car.set_inputs(0.0, 1.0, 0.0)
    for _step in range(60):
        bend_car.tick(1.0 / 60.0, true, pattern, curved_track)
    if absf(bend_car.world_x) > 0.001:
        return "The moving road carries an unsteered car around a bend"

    var game_state = tree.root.get_node("GameState")
    var music_was_muted: bool = game_state.music_muted
    game_state.music_muted = true
    var level = load("res://scenes/level2.tscn").instantiate()
    tree.root.add_child(level)
    await tree.process_frame
    await tree.process_frame
    level.set_process(false)
    level.set_physics_process(false)
    var errors: Array[String] = []
    var overlay = level.car_3d_overlay
    var renderer = level.renderer
    var shared = level.camera_state
    if not overlay.is_model_ready() or overlay.rig == null:
        errors.append("240SX rig did not become ready")
    else:
        if renderer.camera_state != shared or overlay.camera_state != shared:
            errors.append("World and model use different camera states")
        car = level.controller.player
        car.speed = 30.0
        car.set_inputs(0.5, 1.0, 0.0)
        for _step in range(12):
            car.tick(1.0 / 60.0, true, level.controller.track_pattern, level.controller.track_x)
            level._process(1.0 / 60.0)
        if absf(overlay.camera_rig.rotation.y - shared.yaw_offset) > 0.001:
            errors.append("Model camera has an independent chase yaw")
        if overlay.rig.wheels.size() != 4:
            errors.append("240SX does not have four independent wheels")
        var centres: Array[Vector3] = []
        for wheel in overlay.rig.wheels:
            centres.append(wheel.steer.position)
            if wheel.roll.rotation.x <= 0.001:
                errors.append("A wheel does not spin with distance travelled")
            var angle: float = wheel.steer.rotation.y
            if bool(wheel.front) and angle <= 0.0:
                errors.append("Front wheel steering disagrees with right input")
            if not bool(wheel.front) and absf(angle) > 0.001:
                errors.append("Rear wheels steer with the front wheels")
        for i in range(centres.size()):
            for j in range(i + 1, centres.size()):
                if centres[i].distance_to(centres[j]) < 0.5:
                    errors.append("Wheel pivot centres overlap")
        var ray := Vector2(sin(shared.yaw_offset), cos(shared.yaw_offset)) * 20.0
        var camera_ray: Vector2 = renderer._world_to_camera(ray.x, ray.y)
        if absf(camera_ray.x) > 0.001 or absf(camera_ray.y - 20.0) > 0.001:
            errors.append("World projection disagrees with the shared camera heading")
        var old_phase: float = overlay.rig.wheel_phase
        car.speed = 0.0
        car.set_inputs(0.0, 0.0, 1.0)
        for _step in range(15):
            car.tick(1.0 / 60.0, true, level.controller.track_pattern, level.controller.track_x)
            level._process(1.0 / 60.0)
        if absf(overlay.rig.wheel_phase - old_phase) > 0.001:
            errors.append("Stopped wheels keep spinning")
        if overlay.rig.brake_strength < 0.95 or overlay.rig.brake_materials[0].emission_energy_multiplier < 2.0:
            errors.append("Brake lights do not brighten while the brake is held")
        car.set_inputs(0.0, 0.0, 0.0)
        for _step in range(20):
            car.tick(1.0 / 60.0, true, level.controller.track_pattern, level.controller.track_x)
            level._process(1.0 / 60.0)
        if overlay.rig.brake_strength > 0.02:
            errors.append("Brake lights remain bright after pedal release")
        if overlay.rig.front_materials.size() != 2 or overlay.rig.front_materials[0].emission_energy_multiplier < 1.0 or renderer.headlight_texture == null:
            errors.append("Headlight lenses or world light pools are missing")
    level.race_music.stop()
    level.race_music.stream = null
    level.queue_free()
    await tree.create_timer(0.10).timeout
    game_state.music_muted = music_was_muted
    return "; ".join(errors)
