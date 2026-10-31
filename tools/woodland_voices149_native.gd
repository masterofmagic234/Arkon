extends SceneTree
## Staged native-mixer recording. This is not an end-to-end gameplay replay.
var mix
var output := "/workspace/scratch/overhaul-149/voices-native"
var requested: Array[Dictionary] = []
var changes: Array[Dictionary] = []
var listener: AudioListener3D
var camera: Camera3D
var label: Label
const ESCAPE_PLAYER := Vector3(0, 7, -36)
const ESCAPE_LEADER := Vector3(-40, 3, 11)

class Fixture extends Node3D:
    var world: Node3D

func _init() -> void:
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
    call_deferred("run")

func sound(kind: StringName, position_: Vector3, frame: int) -> void:
    var before: int = mix.event_log.size()
    root.get_node("SignalBus").emit_audio_event(kind, position_)
    var entry := {"frame": frame, "seconds": frame / 30.0, "kind": String(kind), "position": [position_.x, position_.y, position_.z], "accepted_immediately": mix.event_log.size() > before, "phase_pending": not mix._pending_phase_event.is_empty()}
    if mix.event_log.size() > before:
        entry.take = mix.event_log[-1].take
        for voice in mix.pool:
            if voice.playing and voice.get_meta("take_id", "") == entry.take:
                entry.max_distance = voice.max_distance
                entry.unit_size = voice.unit_size
                entry.gain_db = voice.volume_db
                break
    requested.append(entry)
    label.text = "Staged mixer audit: Arkon1.49\n" + String(kind) + "\n" + ("accepted" if entry.accepted_immediately else "suppressed / briefly queued")

func mark(kind: String, frame: int) -> void:
    changes.append({"kind": kind, "frame": frame, "seconds": frame / 30.0})

func run() -> void:
    if DisplayServer.get_name() == "headless":
        push_error("WOODLAND VOICES149 NATIVE: native MovieMaker recording required")
        quit(1)
        return
    DirAccess.make_dir_recursive_absolute(output)
    root.size = Vector2i(320, 180)
    root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
    root.get_node("GameState").music_muted = true
    root.get_node("GameState").sfx_muted = false
    root.get_node("GameState").sfx_volume_db = 0
    root.get_node("PauseManager").set_paused(false)
    var scene := Fixture.new()
    root.add_child(scene)
    current_scene = scene
    scene.world = Node3D.new()
    scene.add_child(scene.world)
    camera = Camera3D.new()
    camera.position = Vector3(0, 1.6, 0)
    scene.add_child(camera)
    camera.current = true
    listener = AudioListener3D.new()
    camera.add_child(listener)
    listener.make_current()
    var canvas := CanvasLayer.new()
    scene.add_child(canvas)
    label = Label.new()
    label.position = Vector2(12, 12)
    label.add_theme_font_size_override("font_size", 15)
    label.text = "Staged mixer audit: Arkon1.49\nAmbience calibration"
    canvas.add_child(label)
    mix = load("res://scripts/woodland_audio.gd").new()
    scene.add_child(mix)
    mix.set_variation_seed(149)
    var near_left := Vector3(-4, 1, -3)
    var near_right := Vector3(4, 1, -3)
    for frame in range(1050):
        if frame == 30: sound(&"squirrel_warn", near_left, frame)
        if frame == 70: sound(&"guardian_warn", near_right, frame)
        if frame == 110: sound(&"squirrel_attack", near_left, frame)
        if frame == 145: sound(&"guardian_attack", near_right, frame)
        if frame == 180: sound(&"squirrel_hit", near_left, frame)
        if frame == 205: sound(&"guardian_hit", near_right, frame)
        if frame == 240: sound(&"squirrel_defeat", near_left, frame)
        if frame == 310: sound(&"guardian_defeat", near_right, frame)
        if frame == 380: sound(&"squirrel_rally", near_left, frame)
        if frame == 425: sound(&"guardian_rally", near_right, frame)
        if frame == 470: sound(&"squirrel_chatter", near_left, frame)
        if frame == 520: sound(&"shoot", Vector3.ZERO, frame)
        if frame == 560:
            mark("vocal_burst_and_reserved_phase", frame)
            for index in range(40): sound(&"squirrel_attack", Vector3(index * 8, 1, -5), frame)
            sound(&"encounter_entry", Vector3(0, 1, -5), frame)
        if frame == 625:
            mark("protected_weapon_pool", frame)
            for voice in mix.pool: voice.stop()
            for index in range(12): sound(&"enemy_shoot", Vector3(-4 + index * .7, 1, -3), frame)
            for index in range(6): sound(&"shoot", Vector3.ZERO, frame)
        if frame == 626: sound(&"encounter_gallery", near_right, frame)
        if frame == 690:
            camera.position = ESCAPE_PLAYER
            camera.look_at(ESCAPE_LEADER, Vector3.UP)
            mark("escape_listener_actual_reward_position", frame)
        if frame == 735:
            mix.wind.volume_db = -60
            mark("quiet_bed_for_isolated_escape_calibration", frame)
        if frame == 740: sound(&"encounter_escape", ESCAPE_LEADER, frame)
        if frame == 780:
            mix.wind.volume_db = -14
            mark("restore_game_ambience", frame)
        # A second call is solely a controlled full-mix comparison. Gameplay
        # mission code emits each phase once, with its matching Russian caption.
        if frame == 810: sound(&"encounter_escape", ESCAPE_LEADER, frame)
        if frame == 870:
            root.get_node("PauseManager").set_paused(true)
            mark("pause", frame)
            sound(&"guardian_warn", ESCAPE_PLAYER + near_left, frame)
        if frame == 915:
            root.get_node("PauseManager").set_paused(false)
            mark("resume", frame)
        if frame == 925: sound(&"guardian_warn", ESCAPE_PLAYER + near_left, frame)
        if frame == 980:
            root.get_node("GameState").sfx_muted = true
            mix._apply_mix()
            mark("mute", frame)
            sound(&"guardian_warn", ESCAPE_PLAYER + near_right, frame)
        await process_frame
    root.get_node("PauseManager").set_paused(false)
    var report := {"result": "RECORDED", "fps": 30, "frames": 1050, "requested_events": requested, "changes": changes, "mix_events": mix.event_log, "dropped_vocal_budget": mix.dropped_vocal_budget, "dropped_paused": mix.dropped_paused, "dropped_muted": mix.dropped_muted, "peak_active_voices": mix.peak_active_voices, "vocal_concurrency_cap": mix.VOCAL_VOICE_LIMIT, "vocal_start_cap": mix.VOCAL_WINDOW_LIMIT, "reserved_phase_starts": mix.VOCAL_RESERVED_PHASE_STARTS, "escape_listener": [ESCAPE_PLAYER.x, ESCAPE_PLAYER.y, ESCAPE_PLAYER.z], "escape_leader": [ESCAPE_LEADER.x, ESCAPE_LEADER.y, ESCAPE_LEADER.z], "escape_distance": ESCAPE_PLAYER.distance_to(ESCAPE_LEADER), "scope": "Actual native Godot MovieMaker PCM: staged spatial vocals, real protected weapon overload, reserved phase slot, queued phase recovery, actual62m escape calibration with isolated and restored ambience, pause and mute. No full gameplay or subjective listening claim."}
    FileAccess.open(output.path_join("voices149-native-report.json"), FileAccess.WRITE).store_string(JSON.stringify(report, "  ") + "\n")
    current_scene = null
    scene.queue_free()
    for index in range(6): await process_frame
    await load("res://tools/level3_test_teardown.gd").drain_audio(self)
    print("WOODLAND VOICES149 NATIVE: RECORDED")
    quit()
