extends Control
## A timed film between the completed garden and the playable pursuit.
## Russian captions follow decoded video time, including pauses and slow frames.

const BASE_SIZE := Vector2(1280.0, 720.0)
const AUDIO_SYNC_INTERVAL := 0.35
const AUDIO_SYNC_TOLERANCE := 0.18

@export_file("*.json") var manifest_path := "res://assets/cinematics/park_escape/timeline.json"

var timeline: Dictionary = {}
var cues: Array[Dictionary] = []
var duration := 0.0
var current_cue_index := -1
var ready_for_playback := false
var audio_started := false
var finishing := false
var finish_reason := ""
var audio_resyncs := 0
var _audio_sync_clock := 0.0
var _fade_tween: Tween

@onready var frame: Control = $Frame
@onready var video_player: VideoStreamPlayer = $Frame/VideoPlayer
@onready var audio_player: AudioStreamPlayer = $AudioPlayer
@onready var subtitle_band: Panel = $Frame/SubtitleBand
@onready var speaker_label: Label = $Frame/SubtitleBand/Speaker
@onready var text_label: Label = $Frame/SubtitleBand/Text
@onready var pause_button: Button = $Frame/PauseButton
@onready var sound_button: Button = $Frame/SoundButton
@onready var pause_overlay: Control = $PauseOverlay
@onready var fade: ColorRect = $Fade

func _ready() -> void:
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    resized.connect(_fit_frame)
    _fit_frame()
    subtitle_band.hide()
    pause_overlay.hide()
    $Frame/SkipButton.pressed.connect(skip_to_pursuit)
    $PauseOverlay/SkipButton.pressed.connect(skip_to_pursuit)
    $PauseOverlay/ResumeButton.pressed.connect(_resume)
    pause_button.pressed.connect(_toggle_pause)
    sound_button.pressed.connect(_toggle_sound)
    PauseManager.pause_state_changed.connect(_on_pause_changed)
    video_player.finished.connect(_on_video_finished)
    $Frame/KeyboardHint.visible = not OS.has_feature("mobile")
    var error := _load_timeline()
    if not error.is_empty():
        push_warning("Park escape cinematic: " + error)
        _continue_without_media()
        return
    var stream := VideoStreamTheora.new()
    stream.file = String(timeline.video)
    video_player.stream = stream
    # This film has a separately mixed soundtrack; never play a second copy.
    video_player.volume_db = -80.0
    var soundtrack := load(String(timeline.audio)) as AudioStream
    if soundtrack == null:
        push_warning("Park escape cinematic: soundtrack could not be loaded")
        _continue_without_media()
        return
    audio_player.stream = soundtrack.duplicate() as AudioStream
    if audio_player.stream is AudioStreamOggVorbis:
        (audio_player.stream as AudioStreamOggVorbis).loop = false
    _apply_audio_settings()
    ready_for_playback = true
    video_player.play()
    _on_pause_changed(PauseManager.is_paused)

func _load_timeline() -> String:
    if not FileAccess.file_exists(manifest_path):
        return "timeline is missing: " + manifest_path
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
    if not parsed is Dictionary:
        return "timeline is not a JSON object"
    timeline = parsed
    if int(timeline.get("version", 0)) != 1:
        return "unsupported timeline version"
    duration = float(timeline.get("duration", 0.0))
    if not is_finite(duration) or duration <= 0.0:
        return "invalid duration"
    for key in ["video", "audio"]:
        var path := String(timeline.get(key, ""))
        # Imported audio is remapped in exported APKs; the source .ogg need
        # not exist there as a raw file. VideoStreamTheora reads its raw OGV.
        var exists := ResourceLoader.exists(path, "AudioStream") if key == "audio" else FileAccess.file_exists(path)
        if path.is_empty() or not exists:
            return "missing " + key + " resource: " + path
    var raw_cues: Variant = timeline.get("cues", null)
    if not raw_cues is Array or raw_cues.is_empty():
        return "subtitle cues are missing"
    var previous_end := 0.0
    for raw_cue in raw_cues:
        if not raw_cue is Dictionary:
            return "subtitle cue is not an object"
        var start := float(raw_cue.get("start", -1.0))
        var end := float(raw_cue.get("end", -1.0))
        if not is_finite(start) or not is_finite(end) or start < previous_end or end <= start or end > duration + 0.001:
            return "subtitle cues must be ordered, non-overlapping and inside the film"
        if String(raw_cue.get("speaker", "")).is_empty() or String(raw_cue.get("text", "")).is_empty():
            return "subtitle speaker/text is empty"
        cues.append(raw_cue.duplicate())
        previous_end = end
    return ""

func _fit_frame() -> void:
    var fit := minf(size.x / BASE_SIZE.x, size.y / BASE_SIZE.y)
    frame.size = BASE_SIZE
    frame.scale = Vector2.ONE * fit
    frame.position = (size - BASE_SIZE * fit) * 0.5

func get_playback_time() -> float:
    return video_player.stream_position if is_instance_valid(video_player) else 0.0

func _process(delta: float) -> void:
    if not ready_for_playback or finishing:
        return
    _apply_audio_settings()
    if PauseManager.is_paused:
        return
    var position := get_playback_time()
    if not audio_started and position > 0.0:
        audio_started = true
        audio_player.play(position)
        _fade_tween = create_tween()
        _fade_tween.tween_property(fade, "modulate:a", 0.0, 0.3)
    if audio_started:
        _audio_sync_clock += delta
        if _audio_sync_clock >= AUDIO_SYNC_INTERVAL:
            _audio_sync_clock = 0.0
            # Video time is authoritative. Correct material device/decoder drift,
            # including playback after a pause, rather than accumulating wall time.
            var audio_time := audio_player.get_playback_position() + AudioServer.get_time_since_last_mix()
            if position < duration - 0.25 and absf(audio_time - position) > AUDIO_SYNC_TOLERANCE:
                if audio_player.playing:
                    audio_player.seek(position)
                else:
                    audio_player.play(position)
                audio_resyncs += 1
    _update_caption(position)

func _update_caption(position: float) -> void:
    var next_index := -1
    for index in range(cues.size()):
        if position >= float(cues[index].start) and position < float(cues[index].end):
            next_index = index
            break
    if next_index == current_cue_index:
        return
    current_cue_index = next_index
    subtitle_band.visible = next_index >= 0
    if next_index >= 0:
        speaker_label.text = String(cues[next_index].speaker)
        text_label.text = String(cues[next_index].text)

func _apply_audio_settings() -> void:
    # Dialogue/foley belong to SFX. Keep the muted stream running in sync so
    # turning sound back on never restarts a sentence or the whole soundtrack.
    audio_player.volume_db = -80.0 if GameState.sfx_muted else GameState.sfx_volume_db
    sound_button.text = "ЗВУК: ВЫКЛ" if GameState.sfx_muted else "ЗВУК: ВКЛ"

func _toggle_sound() -> void:
    if finishing:
        return
    AudioManager.toggle_sfx()
    _apply_audio_settings()

func _toggle_pause() -> void:
    if not finishing:
        PauseManager.toggle()

func _resume() -> void:
    if not finishing:
        PauseManager.resume()

func _on_pause_changed(paused: bool) -> void:
    video_player.paused = paused or finishing
    audio_player.stream_paused = paused or finishing
    pause_overlay.visible = paused and not finishing
    pause_button.text = "ПРОДОЛЖИТЬ" if paused else "ПАУЗА"
    if _fade_tween != null and _fade_tween.is_valid() and not finishing:
        if paused:
            _fade_tween.pause()
        else:
            _fade_tween.play()

func _unhandled_input(event: InputEvent) -> void:
    if finishing:
        return
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode in [KEY_ENTER, KEY_KP_ENTER]:
            skip_to_pursuit()
            get_viewport().set_input_as_handled()
            return
        if event.keycode == KEY_SPACE:
            _toggle_pause()
            get_viewport().set_input_as_handled()
            return
    if event.is_action_pressed("ui_cancel"):
        _toggle_pause()
        # PauseManager also owns ui_cancel; consume it here exactly once.
        get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
    if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED] and is_node_ready() and not finishing:
        PauseManager.set_paused(true)
    # Focus-in deliberately leaves the film paused for explicit user resume.

func _on_video_finished() -> void:
    _finish_film("natural")

func skip_to_pursuit() -> void:
    _finish_film("skip")

func _finish_film(reason: String) -> void:
    if finishing:
        return
    finishing = true
    finish_reason = reason
    if _fade_tween != null and _fade_tween.is_valid():
        _fade_tween.kill()
    audio_player.stop()
    video_player.paused = true
    subtitle_band.hide()
    pause_overlay.hide()
    PauseManager.resume()
    _fade_tween = create_tween()
    _fade_tween.tween_property(fade, "modulate:a", 1.0, 0.3)
    _fade_tween.tween_callback(_handoff)

func _continue_without_media() -> void:
    finishing = true
    finish_reason = "missing_media"
    # SceneFlow has to finish arming the new scene before another transition.
    await get_tree().process_frame
    await get_tree().process_frame
    _handoff()

func _handoff() -> void:
    video_player.stop()
    video_player.stream = null
    audio_player.stop()
    audio_player.stream = null
    SceneFlow.go_to(&"level2")

func _exit_tree() -> void:
    var pause_manager := get_node_or_null("/root/PauseManager")
    if pause_manager != null and pause_manager.pause_state_changed.is_connected(_on_pause_changed):
        pause_manager.pause_state_changed.disconnect(_on_pause_changed)
    if _fade_tween != null and _fade_tween.is_valid():
        _fade_tween.kill()
    if is_instance_valid(video_player):
        video_player.stop()
        video_player.stream = null
    if is_instance_valid(audio_player):
        audio_player.stop()
        audio_player.stream = null
