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
