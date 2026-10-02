extends SceneTree

const RaceDirector = preload("res://scripts/race_director.gd")
const Level2Racer = preload("res://scripts/level2_racer.gd")
const RaceLevelData = preload("res://scripts/race_level_data.gd")

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    var bus := root.get_node_or_null("SignalBus")
    if bus == null:
        _fail("SignalBus autoload missing")
        return

    for action in [
        "race_left",
        "race_right",
        "race_accel",
        "race_brake"
    ]:
        if not InputMap.has_action(action):
            _fail("Missing Level 2 InputMap action: %s" % action)
            return

    for legacy_path in [
        "res://scripts/race_controller.gd",
        "res://scripts/race_car_controller.gd",
        "res://scripts/race_ai_controller.gd",
        "res://scripts/race_input.gd",
        "res://scripts/race_state.gd"
    ]:
        if ResourceLoader.exists(legacy_path):
            _fail("Legacy Level 2 controller still exists: %s" % legacy_path)
            return

    var racer_scene := load("res://scenes/level2_racer.tscn") as PackedScene
    if racer_scene == null:
        _fail("Base Level 2 racer scene failed to load")
        return

    var player: Level2Racer = racer_scene.instantiate() as Level2Racer
    var ai_1: Level2Racer = racer_scene.instantiate() as Level2Racer
    var ai_2: Level2Racer = racer_scene.instantiate() as Level2Racer
    var ai_3: Level2Racer = racer_scene.instantiate() as Level2Racer

    player.name = "SmokePlayer"
    player.is_player = true
    player.grid_index = 0
    player.lane_offset = 0.0

    var ai_nodes := [ai_1, ai_2, ai_3]
    var lanes := [-0.9, 0.9, 2.7]
    var skills := [0.86, 0.78, 0.70]

    for i in ai_nodes.size():
        var ai := ai_nodes[i] as Level2Racer
        ai.name = "SmokeAI%d" % (i + 1)
        ai.is_player = false
        ai.grid_index = i + 1
        ai.lane_offset = lanes[i]
        ai.ai_skill = skills[i]

    root.add_child(player)
    for ai in ai_nodes:
        root.add_child(ai)

    var director := RaceDirector.new()
    director.name = "RaceDirectorSmoke"
    root.add_child(director)
    director.setup([player, ai_1, ai_2, ai_3])

    if director.track_pattern.is_empty():
        _fail("TRACK_PATTERN is empty")
        return
    if director.track_x.size() != director.track_pattern.size():
        _fail(
            "track_x size mismatch: %d vs %d"
            % [director.track_x.size(), director.track_pattern.size()]
        )
        return
    if director.racers.size() != RaceLevelData.RACER_COUNT:
        _fail("Racer count mismatch: %d" % director.racers.size())
        return
    if director.player != player:
        _fail("Director did not resolve the player racer")
        return
    if player.movement.segment_index != 0 or player.movement.grid_index != 0:
        _fail("Player did not start on grid slot 0")
        return

    if player.movement.position != 1:
        _fail("Initial player position should be 1")
        return

    var position_event := false
    var on_position_changed := func(racer: Node, position: int) -> void:
        if racer == player and position == 1:
            position_event = true
    bus.racer_position_changed.connect(on_position_changed)
    director._emit_ranking(true)
    bus.racer_position_changed.disconnect(on_position_changed)

    if not position_event:
        _fail("racer_position_changed fact was not published")
        return

    player.start_race()
    Input.action_press("race_accel", 1.0)
    player._process(0.5)
    Input.action_release("race_accel")

    if player.movement.speed <= 0.0 or player.movement.progress(director.track_pattern.size()) <= 0.0:
        _fail("Player racer did not read InputMap and advance autonomously")
        return

    print(
        "LEVEL2 SMOKE TEST: PASS; track_size=%d racers=%d"
        % [director.track_pattern.size(), director.racers.size()]
    )
    quit(0)

func _fail(message: String) -> void:
    push_error("LEVEL2 SMOKE TEST: " + message)
    quit(1)
