extends Node
class_name RaceAudio

# Procedural Level 2 car audio. The Oka gets a continuous low-frequency engine
# bed whose pitch and gain follow speed, plus a looping tire squeal driven by
# steering load. Keeping these tiny mono PCM streams in code avoids another
# pair of large imported assets while remaining cheap on Android.

const SAMPLE_RATE := 22050
const ENGINE_SECONDS := 2.0
const TIRE_SECONDS := 0.75
const MAX_SPEED := 32.0

var player_movement: Node = null
var engine_player: AudioStreamPlayer
var tire_player: AudioStreamPlayer

func _ready() -> void:
    engine_player = AudioStreamPlayer.new()
    engine_player.name = "OkaEngine"
    engine_player.bus = &"Master"
    engine_player.max_polyphony = 1
    add_child(engine_player)

    tire_player = AudioStreamPlayer.new()
    tire_player.name = "TireSqueal"
    tire_player.bus = &"Master"
    tire_player.max_polyphony = 1
    add_child(tire_player)

    engine_player.stream = _make_engine_stream()
    tire_player.stream = _make_tire_stream()
    engine_player.volume_db = -24.0
    engine_player.pitch_scale = 0.82
    engine_player.play()

func bind_player(movement_ref: Node) -> void:
    player_movement = movement_ref
    if engine_player != null and not engine_player.playing:
        engine_player.play()

func _exit_tree() -> void:
    if is_instance_valid(engine_player):
        engine_player.stop()
    if is_instance_valid(tire_player):
        tire_player.stop()

func _process(_delta: float) -> void:
    if player_movement == null:
        return

    var speed: float = maxf(float(player_movement.get("speed")), 0.0)
    var speed_norm: float = clampf(speed / MAX_SPEED, 0.0, 1.0)
    var steer: float = absf(clampf(float(player_movement.get("steer_in")), -1.0, 1.0))
    var throttle: float = clampf(float(player_movement.get("throttle")), 0.0, 1.0)
    var brake: float = clampf(float(player_movement.get("brake_in")), 0.0, 1.0)
    var racing: bool = bool(player_movement.get("race_active"))

    # Give the Oka a subdued idle rumble and a much more aggressive note near
    # top speed. Pitch scaling is intentionally modest so the engine does not
    # turn into a cartoon whistle.
    var engine_load := clampf(
        speed_norm * 0.78
        + throttle * 0.18
        + brake * 0.04,
        0.0,
        1.0
    )

    if not racing:
        engine_load *= 0.35

    engine_player.pitch_scale = lerpf(0.78, 1.48, engine_load)
    engine_player.volume_db = lerpf(-25.0, -6.5, engine_load)

    # Tires complain when the driver asks for a large steering angle while
    # carrying speed. Braking during a turn increases the slip slightly.
    var slip := clampf(
        (speed_norm - 0.22) / 0.78
        * steer
        * (0.82 + brake * 0.35),
        0.0,
        1.0
    )

    if racing and slip > 0.08:
        tire_player.pitch_scale = lerpf(0.88, 1.22, slip)
        tire_player.volume_db = lerpf(-30.0, -7.0, slip)
        if not tire_player.playing:
            tire_player.play()
    elif tire_player.playing:
        tire_player.stop()

func _make_engine_stream() -> AudioStreamWAV:
    var sample_count := int(SAMPLE_RATE * ENGINE_SECONDS)
    var data := PackedByteArray()
    data.resize(sample_count * 2)

    # Exact integer cycles keep the loop boundary seamless.
    var base_hz := 55.0
    var cycles := int(base_hz * ENGINE_SECONDS)
    for i in range(sample_count):
        var phase := TAU * float(cycles) * float(i) / float(sample_count)
        var signal := (
            0.48 * sin(phase)
            + 0.23 * sin(phase * 2.0)
            + 0.13 * sin(phase * 3.0)
            + 0.08 * sin(phase * 4.0)
        )

        # Softly emphasize the middle of the loop and avoid a totally static
        # oscillator; this is a game-audio bed, not a diagnostic tone.
        var t := float(i) / float(sample_count)
        var modulation := 0.92 + 0.08 * sin(TAU * 2.0 * t)
        _write_pcm16(data, i * 2, signal * modulation * 0.56)

    var stream := AudioStreamWAV.new()
    stream.format = AudioStreamWAV.FORMAT_16_BITS
    stream.mix_rate = SAMPLE_RATE
    stream.stereo = false
    stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
    stream.loop_begin = 0
    stream.loop_end = sample_count
    stream.data = data
    return stream

func _make_tire_stream() -> AudioStreamWAV:
    var sample_count := int(SAMPLE_RATE * TIRE_SECONDS)
    var data := PackedByteArray()
    data.resize(sample_count * 2)

    var seed := 0x2A7F
    for i in range(sample_count):
        # Deterministic pseudo-random noise with a little high-frequency tone
        # mixed in produces a compact arcade tire-squeal texture.
        seed = int((seed * 1103515245 + 12345) & 0x7fffffff)
        var noise := float(seed % 20001) / 10000.0 - 1.0
        var t := float(i) / float(sample_count)
        var edge := minf(
            1.0,
            minf(t / 0.035, (1.0 - t) / 0.035)
        )
        var texture := noise * 0.55 + sin(TAU * 1450.0 * t) * 0.18
        _write_pcm16(data, i * 2, texture * edge * 0.48)

    var stream := AudioStreamWAV.new()
    stream.format = AudioStreamWAV.FORMAT_16_BITS
    stream.mix_rate = SAMPLE_RATE
    stream.stereo = false
    stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
    stream.loop_begin = 0
    stream.loop_end = sample_count
    stream.data = data
    return stream

func _write_pcm16(data: PackedByteArray, offset: int, sample: float) -> void:
    data.encode_s16(
        offset,
        clampi(
            int(round(clampf(sample, -1.0, 1.0) * 32767.0)),
            -32768,
            32767
        )
    )
