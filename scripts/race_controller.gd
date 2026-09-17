extends RefCounted

# Оркестратор Level 2.

const RaceLevelData = preload("res://scripts/race_level_data.gd")
const RaceMath = preload("res://scripts/race_math.gd")
const RaceQueries = preload("res://scripts/race_queries.gd")
const RaceCarController = preload("res://scripts/race_car_controller.gd")
const RaceAIController = preload("res://scripts/race_ai_controller.gd")

var root
var player_visual
var ai_visuals: Array = []
var camera
var hud
var audio_controller
var message_view
var mission_view
var state
var player
var ais: Array = []
var track_pattern: Array = []
var track_x: PackedFloat32Array = PackedFloat32Array()
var on_mission_end: Callable

func setup(root_node, player_node, ai_nodes: Array, cam, hud_ref, audio, messages, mission, race_state, mission_end_callback: Callable) -> void:
    root = root_node
    player_visual = player_node
    ai_visuals = ai_nodes
    camera = cam
    hud = hud_ref
    audio_controller = audio
    message_view = messages
    mission_view = mission
    state = race_state
    on_mission_end = mission_end_callback

func start() -> void:
    track_pattern = RaceLevelData.TRACK_PATTERN.duplicate()
    track_x = RaceMath.accumulate_track_x(track_pattern)
    state.setup(RaceLevelData.TOTAL_LAPS, RaceLevelData.RACER_COUNT)
    state.reset_race()
    state.acorns_total = RaceLevelData.ACORN_PICKUPS.size()

    player = RaceCarController.new()
    player.setup(true)
    player.place_on_grid(0, 0.0, track_x)

    ais.clear()
    for i in ai_visuals.size():
        var ai_car := RaceCarController.new()
        ai_car.setup(false)
        var lane: float = RaceLevelData.LANE_OFFSETS[(i + 1) % RaceLevelData.LANE_OFFSETS.size()]
        ai_car.place_on_grid(i + 1, lane, track_x)
        var ai := RaceAIController.new()
        var bias := lane / (RaceLevelData.ROAD_WIDTH * 0.5)
        var skill: float = RaceLevelData.AI_SKILLS[i] if i < RaceLevelData.AI_SKILLS.size() else 0.7
        ai.setup(ai_car, track_pattern, track_x, skill, bias)
        ais.append(ai)

    if message_view:
        message_view.set_text("ОПЕРАЦИЯ «ЖЁЛУДЬ»: ГОНКА")
    state.message_time = 2.4

func handle_input(steer: float, throttle: float, brake: float) -> void:
    if not RaceQueries.can_control(state):
        return
    player.set_inputs(steer, throttle, brake)

func handle_fire() -> void:
    pass

func update(delta: float) -> void:
    if not state.race_started:
        state.countdown -= delta
        if state.countdown <= 0.0:
            state.countdown = 0.0
            state.race_started = true
        player.tick(delta, false, track_pattern, track_x)
        for ai in ais:
            ai.tick(delta)
            ai.car.tick(delta, false, track_pattern, track_x)
    else:
        state.race_time += delta
        state.lap_time += delta
        var allow := RaceQueries.can_control(state)
        player.tick(delta, allow, track_pattern, track_x)
        for ai in ais:
            ai.tick(delta)
            ai.car.tick(delta, allow, track_pattern, track_x)

    if state.race_started and player.last_segment_index >= 0:
        _check_lap(player)

    var player_p: float = player.progress(track_pattern.size())
    state.player_progress = player_p
    state.position = 1
    for i in ais.size():
        var ap: float = ais[i].car.progress(track_pattern.size())
        state.ai_progress[i] = ap
        if ap > player_p:
            state.position += 1

    if state.race_started and not state.race_finished and player.lap >= state.total_laps:
        _finish_race(player)

    _sync_visuals()
    _sync_hud()

func _check_lap(car) -> void:
    if car.segment_index < car.last_segment_index:
        if car.is_player:
            state.last_lap_time = state.lap_time
            if state.best_lap == 0.0 or state.lap_time < state.best_lap:
                state.best_lap = state.lap_time
            state.lap_time = 0.0
            state.lap = car.lap
            if state.lap < state.total_laps and message_view:
                message_view.set_text("КРУГ %d / %d" % [state.lap + 1, state.total_laps])
                state.message_time = 1.6

func _finish_race(car) -> void:
    state.race_finished = true
    state.mission_complete = true
    car.finish_time = state.race_time
    if on_mission_end.is_valid():
        on_mission_end.call()
    if mission_view:
        mission_view.show_finished(state)

func fail() -> void:
    state.mission_failed = true
    state.race_finished = true
    if on_mission_end.is_valid():
        on_mission_end.call()
    if mission_view:
        mission_view.show_failed()

func set_message(text: String, duration: float) -> void:
    if message_view:
        message_view.set_text(text)
    state.message_time = duration

func _sync_visuals() -> void:
    if player_visual:
        player_visual.position = Vector3(player.world_x, 0.9, player.world_z)
        player_visual.rotation_degrees = Vector3(0, rad_to_deg(player.sprite_yaw), 0)
    for i in ai_visuals.size():
        if i >= ais.size():
            break
        var c = ais[i].car
        ai_visuals[i].position = Vector3(c.world_x, 0.9, c.world_z)
        ai_visuals[i].rotation_degrees = Vector3(0, rad_to_deg(c.sprite_yaw), 0)

func _sync_hud() -> void:
    if hud == null:
        return
    hud.set_lap(state.lap + 1, state.total_laps)
    hud.set_position(state.position, state.racer_count)
    hud.set_time(state.race_time, state.last_lap_time, state.best_lap)
    hud.set_speed(int(player.speed * 8.0))
    if not state.race_started:
        var n := int(ceil(state.countdown))
        hud.show_countdown(str(n) if n > 0 else "GO!")
    else:
        hud.hide_countdown()
