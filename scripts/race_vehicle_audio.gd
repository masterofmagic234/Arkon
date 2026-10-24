extends Node

# Recorded-style RPM bands are generated offline. Runtime only blends/pitches
# small PCM streams; no per-sample DSP or allocation runs on the game thread.
const BASE_RPMS := [900.0, 2700.0, 4500.0, 6300.0]
var car = null
var layers: Array = []
var tire_player: AudioStreamPlayer
var shift_player: AudioStreamPlayer
var last_shift: int = 0
var load_mix: float = 0.0
var tire_mix: float = 0.0

func _ready() -> void:
    for rpm in BASE_RPMS:
        for loaded in [false, true]:
            var path := "res://assets/vehicle_audio/engine_%04d_%s.wav" % [int(rpm), "load" if loaded else "coast"]
            var player := _player(path, true)
            layers.append({"player": player, "rpm": rpm, "loaded": loaded})
    tire_player = _player("res://assets/vehicle_audio/tire_scrub.wav", true)
    shift_player = _player("res://assets/vehicle_audio/automatic_shift.wav", false)

func _player(path: String, looping: bool) -> AudioStreamPlayer:
    var player := AudioStreamPlayer.new()
    var source := load(path) as AudioStreamWAV
    if source == null:
        push_error("Missing vehicle sound: " + path)
    else:
        var stream := source.duplicate() as AudioStreamWAV
        var frames := int(round(stream.get_length() * stream.mix_rate))
        stream.loop_begin = 0
        stream.loop_end = frames
        stream.loop_mode = AudioStreamWAV.LOOP_FORWARD if looping else AudioStreamWAV.LOOP_DISABLED
        player.stream = stream
    player.volume_db = -80.0
    player.bus = "Master"
    add_child(player)
    return player

func bind(car_ref) -> void:
    car = car_ref
    last_shift = car.powertrain.shift_serial

func _process(delta: float) -> void:
    if car == null:
        return
    var muted: bool = GameState.sfx_muted
    var rpm := float(car.engine_rpm)
    load_mix = lerpf(load_mix, float(car.engine_load), 1.0 - exp(-16.0 * delta))
    tire_mix = lerpf(tire_mix, float(car.tyre_squeal), 1.0 - exp(-12.0 * delta))
    for layer in layers:
        var index := BASE_RPMS.find(float(layer.rpm))
        var weight := 0.0
        if rpm <= BASE_RPMS[0]:
            weight = 1.0 if index == 0 else 0.0
        elif rpm >= BASE_RPMS[-1]:
            weight = 1.0 if index == BASE_RPMS.size() - 1 else 0.0
        else:
            for band in range(BASE_RPMS.size() - 1):
                if rpm >= BASE_RPMS[band] and rpm < BASE_RPMS[band + 1]:
                    var blend: float = (rpm - BASE_RPMS[band]) / (BASE_RPMS[band + 1] - BASE_RPMS[band])
                    if index == band:
                        weight = sqrt(1.0 - blend)
                    elif index == band + 1:
                        weight = sqrt(blend)
                    break
        var pedal_weight := sqrt(load_mix) if bool(layer.loaded) else sqrt(1.0 - load_mix) * 0.52
        var gain := weight * pedal_weight * lerpf(0.48, 1.0, smoothstep(850.0, 2200.0, rpm))
        var p: AudioStreamPlayer = layer.player
        p.pitch_scale = clampf(rpm / float(layer.rpm), 0.35, 2.5)
        p.volume_db = maxf(-80.0, linear_to_db(maxf(gain, 0.0001)) - 9.0 + GameState.sfx_volume_db)
        _play_loop(p, not muted and gain > 0.0005)
    tire_player.pitch_scale = lerpf(0.88, 1.18, clampf(float(car.speed) / 70.08, 0.0, 1.0))
    tire_player.volume_db = maxf(-80.0, linear_to_db(maxf(tire_mix, 0.0001)) - 6.0 + GameState.sfx_volume_db)
    _play_loop(tire_player, not muted and tire_mix > 0.002)
    if car.powertrain.shift_serial != last_shift:
        last_shift = car.powertrain.shift_serial
        if not muted:
            shift_player.volume_db = -20.0 + GameState.sfx_volume_db
            shift_player.play()
    if muted:
        shift_player.stop()

func _play_loop(player: AudioStreamPlayer, enabled: bool) -> void:
    if enabled and not player.playing:
        player.play()
    elif not enabled and player.playing:
        player.stop()

func _exit_tree() -> void:
    for child in get_children():
        if child is AudioStreamPlayer:
            child.stop()
            child.stream = null
    layers.clear()
