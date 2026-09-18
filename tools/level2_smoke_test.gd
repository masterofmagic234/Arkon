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
    controller.setup(Node.new(), null, [], null, hud, null, null, null, state, Callable())
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

    print("LEVEL2 SMOKE TEST: PASS; track_size=%d" % controller.track_pattern.size())
    quit(0)

func _fail(message: String) -> void:
    push_error("LEVEL2 SMOKE TEST: " + message)
    quit(1)
