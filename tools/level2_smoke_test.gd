extends SceneTree

const RaceState = preload("res://scripts/race_state.gd")
const RaceController = preload("res://scripts/race_controller.gd")
const RaceLevelData = preload("res://scripts/race_level_data.gd")

class HudStub:
    func set_lap(_lap: int, _total: int) -> void: pass
    func set_position(_pos: int, _total: int) -> void: pass
    func set_time(_race: float, _last: float, _best: float) -> void: pass
    func set_speed(_kmh: int) -> void: pass
    func show_countdown(_text: String) -> void: pass
    func hide_countdown() -> void: pass

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    var state = RaceState.new()
    var controller = RaceController.new()
    var hud = HudStub.new()
    var finish_observation := {"calls": 0}
    var on_finish := func() -> void:
        finish_observation["calls"] = int(finish_observation["calls"]) + 1
    controller.setup(root, null, [], null, hud, null, null, null, state, on_finish)
    controller.start()

    if controller.track_pattern.size() <= 0:
        _fail("TRACK_PATTERN is empty")
        return
    if controller.track_x.size() != controller.track_pattern.size():
        _fail("track_x size mismatch: %d vs %d" % [controller.track_x.size(), controller.track_pattern.size()])
        return
    if controller.player == null:
        _fail("Player car was not created")
        return
    if controller.ais.size() != RaceLevelData.RACER_COUNT - 1:
        _fail("AI racer count mismatch: %d" % controller.ais.size())
        return
    if controller.player.segment_index != 0 or controller.player.grid_index != 0:
        _fail("Player did not start on grid slot 0")
        return

    # Verify the countdown position logic remains grid-based.
    controller.update(0.016)
    if state.position != 1:
        _fail("Countdown position is not 1/4: %d/%d" % [state.position, state.racer_count])
        return

    var car_overlay_script := FileAccess.get_file_as_string("res://scripts/race_240sx_overlay.gd")
    if not car_overlay_script.contains("240_sx_nfs_pro_street.glb") or not car_overlay_script.contains("SubViewport"):
        _fail("240SX player preview is not backed by a dedicated 3D viewport")
        return
    if RaceLevelData.ACTIVE_HANDLING_PROFILE != RaceLevelData.HandlingProfile.NFS_UNDERGROUND2:
        _fail("Level 2 smoke is not running the requested NFS Underground 2 handling profile")
        return

    # Zero-speed lateral behavior: steering while stationary must not slide the
    # car sideways. This is a regression test for the old max(speed, 4.0) path.
    controller.player.speed = 0.0
    controller.player.segment_progress = 0.0
    controller.player.lateral_offset = 0.0
    controller.player.set_inputs(1.0, 0.0, 0.0)
    controller.player.tick(0.1, true, controller.track_pattern, controller.track_x)
    if absf(controller.player.lateral_offset) > 0.001:
        _fail("Stationary player still moves laterally: %.4f" % controller.player.lateral_offset)
        return

    # Off-road behavior: allow a small body/contact margin beyond the visible
    # asphalt before the shoulder penalty begins.
    var road_half := RaceLevelData.ROAD_WIDTH * 0.5
    var soft_edge := (
        road_half
        + RaceLevelData.OFFROAD_VEHICLE_HALF_WIDTH
        + RaceLevelData.OFFROAD_ASPHALT_MARGIN
    )
    controller.player.speed = RaceLevelData.PLAYER_MAX_SPEED
    controller.player.lateral_offset = soft_edge - 0.05
    controller.player.set_inputs(0.0, 1.0, 0.0)
    controller.player.tick(0.05, true, controller.track_pattern, controller.track_x)
    var speed_before_penalty: float = controller.player.speed

    controller.player.speed = RaceLevelData.PLAYER_MAX_SPEED
    controller.player.lateral_offset = soft_edge + 0.10
    controller.player.set_inputs(0.0, 1.0, 0.0)
    controller.player.tick(0.05, true, controller.track_pattern, controller.track_x)
    if controller.player.speed >= speed_before_penalty - 0.2:
        _fail("Off-road shoulder penalty did not begin after the vehicle/contact margin")
        return

    # Behavioral finish gate: cross the real track boundary for each lap.
    # This exercises RaceCarController progress wrapping, RaceController lap
    # bookkeeping, and the completion callback without bypassing production code.
    state.race_started = true
    state.race_finished = false
    state.mission_complete = false
    state.mission_failed = false
    controller.player.speed = RaceLevelData.PLAYER_MAX_SPEED
    controller.player.set_inputs(0.0, 0.0, 0.0)

    for _lap in range(state.total_laps):
        controller.player.segment_index = controller.track_pattern.size() - 1
        controller.player.segment_progress = 0.999
        controller.update(0.01)

    if not state.race_finished or not state.mission_complete:
        _fail("Level 2 finish did not set completed race state")
        return
    if state.lap < state.total_laps:
        _fail("Level 2 finish did not complete all laps: %d/%d" % [state.lap, state.total_laps])
        return
    if int(finish_observation["calls"]) != 1:
        _fail("Level 2 completion callback count is %d, expected exactly 1" % int(finish_observation["calls"]))
        return
    if controller.player.finish_time < 0.0:
        _fail("Level 2 finish time was not recorded")
        return
    controller.update(0.01)
    if int(finish_observation["calls"]) != 1:
        _fail("Level 2 completion callback fired more than once")
        return
    var active_scene := FileAccess.get_file_as_string("res://scenes/level2.tscn")
    if not active_scene.contains("game_level2_pseudo3d.gd") or not active_scene.contains("race_renderer_pseudo3d.gd"):
        _fail("Active Level 2 scene is not the pseudo-3D scene")
        return
    print("LEVEL2 SMOKE TEST: PASS; track_size=%d; pseudo3d=240SX" % controller.track_pattern.size())
    quit(0)

func _fail(message: String) -> void:
    push_error("LEVEL2 SMOKE TEST: " + message)
    quit(1)
