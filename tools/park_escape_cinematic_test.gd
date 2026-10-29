extends SceneTree
## Real media, campaign state and device input for the park/pursuit interlude.
## Physical boarding is also exercised by botanical_playthrough.gd. Here its
## completion fact is staged so the full film can be checked independently.

const FILM := "res://scenes/park_escape_cutscene.tscn"
const PURSUIT := "res://scenes/level2.tscn"
const MANIFEST := "res://assets/cinematics/park_escape/timeline.json"
const Teardown = preload("res://tools/level3_test_teardown.gd")
const PROFILE_FILES := [
    "user://settings.cfg", "user://botanical_garden.json",
    "user://botanical_garden.json.tmp", "user://woodland_journey.json",
    "user://woodland_journey.json.tmp",
]

var visual := false
var output_dir := ""
var failures: Array[String] = []
var captures: Array[String] = []
var original_files: Dictionary = {}
var state: Node
var flow: Node
var pause_manager: Node
var manifest: Dictionary = {}
var movie: Control
var video: VideoStreamPlayer
var soundtrack: AudioStreamPlayer
var caption: Label
var speaker: Label
var subtitle_band: Panel
var seen_cues: Array[int] = []
var seen_shots: Array[int] = []
var decoded_samples := 0
var audio_length := 0.0
var natural_end := false
var duplicate_end_delivered := false
var pause_checked := false
var background_checked := false
var muted_captions_checked := false
var staged_checkpoint := PackedByteArray()

func _init() -> void:
    for arg in OS.get_cmdline_user_args():
        if arg == "--visual": visual = true
        elif arg.begins_with("--output="): output_dir = arg.trim_prefix("--output=")
    call_deferred("_run")

func check(ok: bool, why: String) -> bool:
    if not ok:
        failures.append(why)
        push_error("PARK ESCAPE CINEMATIC: " + why)
    return ok

func frames(count: int = 4) -> void:
    for index in range(count): await process_frame

func _wait_scene(path: String, limit: int = 360) -> bool:
    for index in range(limit):
        await process_frame
        if current_scene != null and current_scene.scene_file_path == path and not bool(flow.get("_transitioning")):
            await frames(3)
            return true
    return check(false, "did not reach " + path)

func _bind_film() -> bool:
    if not check(current_scene != null and current_scene.scene_file_path == FILM, "expected the park film scene"):
        return false
    movie = current_scene as Control
    video = movie.get_node("Frame/VideoPlayer") as VideoStreamPlayer
    soundtrack = movie.get_node("AudioPlayer") as AudioStreamPlayer
    caption = movie.get_node("Frame/SubtitleBand/Text") as Label
    speaker = movie.get_node("Frame/SubtitleBand/Speaker") as Label
    subtitle_band = movie.get_node("Frame/SubtitleBand") as Panel
    for index in range(180):
        await process_frame
        if bool(movie.get("ready_for_playback")) and bool(movie.get("audio_started")) and video.stream_position > .08:
            return true
    return check(false, "real video/audio playback did not become ready")

func _validate_manifest() -> bool:
    if not check(FileAccess.file_exists(MANIFEST), "missing authored timeline"):
        return false
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
    if not check(parsed is Dictionary, "timeline must be a JSON object"):
        return false
    manifest = parsed
    check(int(manifest.get("version", 0)) == 1, "unsupported timeline version")
    var resolution: Variant = manifest.get("resolution", [])
    check(float(manifest.get("fps", 0.0)) == 30.0 and resolution is Array and resolution.size() == 2 and float(resolution[0]) == 1280.0 and float(resolution[1]) == 720.0, "expected 720p30 delivery metadata")
    check(String(manifest.get("spoken_language", "")).begins_with("squirrel"), "film speech must be identified as squirrel language")
    check(String(manifest.get("subtitle_language", "")) == "ru", "Russian translations are required")
    var duration := float(manifest.get("duration", 0.0))
    check(is_finite(duration) and duration > 0.0 and duration < 180.0, "invalid film duration")
    for kind in ["video", "audio"]:
        var path := String(manifest.get(kind, ""))
        check(FileAccess.file_exists(path) and FileAccess.get_file_as_bytes(path).size() > 4096, "missing/empty real " + kind)
    var cues: Variant = manifest.get("cues", [])
    if not check(cues is Array and not cues.is_empty(), "subtitle cues are required"):
        return false
    var previous_end := 0.0
    for cue in cues:
        if not check(cue is Dictionary, "subtitle cue must be an object"):
            return false
        var start := float(cue.get("start", -1.0))
        var end := float(cue.get("end", -1.0))
        check(start >= previous_end and end > start and end <= duration + .001, "subtitle cue overlaps or leaves the film timeline")
        check(not String(cue.get("speaker", "")).is_empty() and not String(cue.get("text", "")).is_empty(), "missing speaker or translation")
        previous_end = end
    var shots: Variant = manifest.get("shots", [])
    if not check(shots is Array and shots.size() >= 3, "expected the authored departure, order and launch shots"):
        return false
    previous_end = 0.0
    for shot in shots:
        if not check(shot is Dictionary, "shot must be an object"):
            return false
        var start := float(shot.get("start", -1.0))
        var end := float(shot.get("end", -1.0))
        check(absf(start - previous_end) < .05 and end > start, "shot timeline has a gap, overlap or empty interval")
        previous_end = end
    check(absf(previous_end - duration) < .05, "shot coverage does not reach the film end")
    return failures.is_empty()

func _check_campaign(where: String) -> bool:
    return check(state.is_completed(&"level1") and not state.is_completed(&"level2") and state.completed_levels.size() == 1 and state.acorns_collected == 6 and state.player_hp == 83 and state.player_ammo == 27, "film reset/advanced campaign resources " + where)

func _stage_completed_park_checkpoint() -> bool:
    var progress := preload("res://scripts/botanical_state.gd").new()
    progress.journal = true
    progress.water = true
    progress.valves.assign([true, false, true])
    progress.parts.assign([true, true, true])
    progress.installed = true
    progress.gate_unlatched = true
    progress.guardian = true
    progress.reward = true
    progress.encounters_completed.assign(["entry", "pump_repair", "pump", "gallery", "guardian", "escape"])
    progress.hp = 83
    progress.ammo = 27
    if not check(progress.save(), "completed park checkpoint could not be staged"):
        return false
    staged_checkpoint = FileAccess.get_file_as_bytes(progress.PATH)
    return true

func _check_pending_checkpoint() -> bool:
    return check(FileAccess.file_exists("user://botanical_garden.json") and FileAccess.get_file_as_bytes("user://botanical_garden.json") == staged_checkpoint, "pending park checkpoint was changed/retired before pursuit arrival")

func _center(control: Control) -> Vector2:
    return control.get_global_transform_with_canvas() * (control.size * .5)

func _mouse(point: Vector2, pressed: bool) -> void:
    var event := InputEventMouseButton.new()
    event.device = InputEvent.DEVICE_ID_EMULATION
    event.button_index = MOUSE_BUTTON_LEFT
    event.position = point
    event.global_position = point
    event.pressed = pressed
    root.push_input(event, true)

func _click(control: Control) -> void:
    var point := _center(control)
    _mouse(point, true)
    await process_frame
    _mouse(point, false)
    await frames(3)

func _touch_mouse(control: Control, duplicate_finished: bool = false) -> void:
    # Android's raw finger and emulated GUI mouse may arrive on different frames.
    var point := _center(control)
    var touch := InputEventScreenTouch.new()
    touch.index = 6
    touch.position = point
    touch.pressed = true
    root.push_input(touch, true)
    await process_frame
    _mouse(point, true)
    await process_frame
    touch = InputEventScreenTouch.new()
    touch.index = 6
    touch.position = point
    touch.pressed = false
    root.push_input(touch, true)
    _mouse(point, false)
    if duplicate_finished and is_instance_valid(video):
        # A decoder completion racing a real Skip must not advance twice.
        video.finished.emit()
        video.finished.emit()
        duplicate_end_delivered = true
    await frames(3)

func _key(code: Key) -> void:
    var event := InputEventKey.new()
    event.keycode = code
    event.physical_keycode = code
    event.pressed = true
    root.push_input(event, true)
    await process_frame
    event = InputEventKey.new()
    event.keycode = code
    event.physical_keycode = code
    root.push_input(event, true)
    await frames(3)

func _expected_cue(position: float) -> int:
    for index in range(manifest.cues.size()):
        var cue: Dictionary = manifest.cues[index]
        if position >= float(cue.start) and position < float(cue.end): return index
    return -1

func _near_cue_edge(position: float) -> bool:
    for cue in manifest.cues:
        if minf(absf(position - float(cue.start)), absf(position - float(cue.end))) < .09: return true
    return false

func _caption_matches(position: float) -> bool:
    if _near_cue_edge(position): return true
    var expected := _expected_cue(position)
    if not check(int(movie.get("current_cue_index")) == expected, "caption index does not follow decoded movie time"):
        return false
    if expected < 0:
        return check(not subtitle_band.visible, "stale translation remains in a cue gap")
    var cue: Dictionary = manifest.cues[expected]
    return check(subtitle_band.visible and caption.text == String(cue.text) and speaker.text == String(cue.speaker), "displayed Russian speaker/translation differs from its timed cue")

func _screen_rect(control: Control) -> Rect2:
    return control.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, control.size)

func _check_layout() -> bool:
    var window := Rect2(Vector2.ZERO, Vector2(root.size))
    var image := _screen_rect(video)
    check(absf(image.size.x / image.size.y - 16.0 / 9.0) < .001, "movie face/body proportions are stretched")
    check(window.grow(.5).encloses(image), "movie leaves the visible phone frame")
    for path in ["Frame/SkipButton", "Frame/PauseButton", "Frame/SoundButton", "Frame/SubtitleBand"]:
        check(image.grow(.5).encloses(_screen_rect(movie.get_node(path))), "cinematic control/caption leaves the fitted film: " + path)
    return failures.is_empty()

func _capture(name: String) -> bool:
    if not visual: return true
    await RenderingServer.frame_post_draw
    var picture := root.get_texture().get_image()
    if not check(picture != null and not picture.is_empty(), "empty native framebuffer"):
        return false
    var image := _screen_rect(video)
    # Evaluate the actual illustration, excluding caption and control overlays.
    var core := Rect2i(image.position + image.size * Vector2(.05, .18), image.size * Vector2(.9, .55))
    var sample := picture.get_region(core)
    sample.resize(80, 45, Image.INTERPOLATE_LANCZOS)
    var lit := 0
    var chroma := 0.0
    for y in range(sample.get_height()):
        for x in range(sample.get_width()):
            var color := sample.get_pixel(x, y)
            if color.get_luminance() > .03: lit += 1
            chroma += maxf(color.r, maxf(color.g, color.b)) - minf(color.r, minf(color.g, color.b))
    check(lit > 180, "native manga illustration is black/undecoded")
    check(chroma / 3600.0 < .025, "manga illustration is not black and white")
    var texture := video.get_video_texture()
    check(texture != null and texture.get_width() == 1280 and texture.get_height() == 720, "native decoder did not present 1280x720 video")
    DirAccess.make_dir_recursive_absolute(output_dir)
    var path := output_dir.path_join(name + ".png")
    check(picture.save_png(path) == OK, "native screenshot could not be written")
    captures.append(path)
    decoded_samples += 1
    return failures.is_empty()

func _lifecycle_and_skip() -> bool:
    state.current_level = &"level1"
    root.get_node("SignalBus").emit_signal(&"level_completed", &"level1")
    root.get_node("SignalBus").emit_signal(&"level_completed", &"level1")
    if not await _wait_scene(FILM) or not await _bind_film(): return false
    _check_campaign("at entry")
    _check_pending_checkpoint()
    var instance := movie.get_instance_id()
    root.get_node("SignalBus").emit_signal(&"level_completed", &"level1")
    await frames(6)
    check(current_scene == movie and movie.get_instance_id() == instance, "late duplicate boarding restarted/skipped the film")
    check(state.current_level == &"park_escape", "SceneFlow did not identify its interstitial")
    check(video.stream is VideoStreamTheora and video.is_playing(), "actual Theora stream is not playing")
    check(soundtrack.stream != null and soundtrack.playing and bool(movie.get("audio_started")), "real squirrel soundtrack is not playing")
    audio_length = soundtrack.stream.get_length()
    check(absf(audio_length - float(manifest.duration)) < .25, "soundtrack does not cover the full film")
    check(state.music_muted and not state.sfx_muted and soundtrack.volume_db > -60.0, "music mute incorrectly silences squirrel dialogue")
    for size_ in [Vector2i(2582, 1220), Vector2i(1440, 900), Vector2i(1280, 720)]:
        root.size = size_
        await frames(5)
        _check_layout()
    if not failures.is_empty(): return false
    # Reach the middle of the first real speech cue before testing mute.
    var first: Dictionary = manifest.cues[0]
    var cue_middle := (float(first.start) + float(first.end)) * .5
    for index in range(2400):
        if video.stream_position >= cue_middle: break
        await process_frame
    if not check(_expected_cue(video.stream_position) >= 0, "first speech cue was not reached"):
        return false
    await _click(movie.get_node("Frame/SoundButton"))
    check(state.sfx_muted and soundtrack.playing and soundtrack.volume_db <= -70.0, "mute stopped/desynchronized dialogue instead of silencing it")
    _caption_matches(video.stream_position)
    check(subtitle_band.visible, "mute hid the required Russian translation")
    if not await _capture("01-muted-squirrel-subtitles"): return false
    muted_captions_checked = true
    await _click(movie.get_node("Frame/SoundButton"))
    check(not state.sfx_muted and soundtrack.playing and soundtrack.volume_db > -60.0, "unmute did not restore the in-time soundtrack")
    await _touch_mouse(movie.get_node("Frame/PauseButton"))
    if not check(pause_manager.is_paused and video.paused and soundtrack.stream_paused, "one phone pause tap did not pause both media streams"):
        return false
    await frames(4)
    var video_time := video.stream_position
    var audio_time := soundtrack.get_playback_position()
    var cue_index := int(movie.get("current_cue_index"))
    var paused_caption := caption.text
    await frames(24)
    check(absf(video.stream_position - video_time) < .035 and absf(soundtrack.get_playback_position() - audio_time) < .12, "paused film/audio clock continued")
    check(int(movie.get("current_cue_index")) == cue_index and caption.text == paused_caption, "captions advanced while paused")
    await _key(KEY_ESCAPE)
    check(not pause_manager.is_paused and not video.paused and not soundtrack.stream_paused, "Escape was double-handled or failed to resume")
    await _key(KEY_SPACE)
    check(pause_manager.is_paused and video.paused and soundtrack.stream_paused, "Space did not pause exactly once")
    await _click(movie.get_node("PauseOverlay/ResumeButton"))
    check(not pause_manager.is_paused and not video.paused and not soundtrack.stream_paused, "explicit GUI Continue failed")
    pause_checked = true
    movie.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
    movie.notification(NOTIFICATION_APPLICATION_PAUSED)
    await frames(4)
    video_time = video.stream_position
    movie.notification(NOTIFICATION_APPLICATION_RESUMED)
    movie.notification(NOTIFICATION_APPLICATION_FOCUS_IN)
    await frames(12)
    check(pause_manager.is_paused and video.paused and soundtrack.stream_paused and absf(video.stream_position - video_time) < .035, "returning to Android auto-resumed or lost the film position")
    await _click(movie.get_node("PauseOverlay/ResumeButton"))
    check(not pause_manager.is_paused and not video.paused and not soundtrack.stream_paused, "explicit resume after background failed")
    background_checked = true
    _check_pending_checkpoint()
    if not failures.is_empty(): return false
    await _touch_mouse(movie.get_node("Frame/SkipButton"), true)
    check(duplicate_end_delivered, "duplicate decoder completion was not delivered with Skip")
    check(bool(movie.get("finishing")) and String(movie.get("finish_reason")) == "skip", "decoder completion overrode or repeated the user's Skip")
    check(not soundtrack.playing and video.paused, "Skip left the former soundtrack/movie advancing during handoff")
    if not await _wait_scene(PURSUIT): return false
    check(state.current_level == &"level2" and not paused, "Skip did not enter the playable pursuit unpaused")
    _check_campaign("after phone Skip/duplicate decoder events")
    check(not FileAccess.file_exists("user://botanical_garden.json"), "garden checkpoint remained after confirmed pursuit arrival")
    return failures.is_empty()

func _natural_playback() -> bool:
    if not _stage_completed_park_checkpoint(): return false
    flow.go_to(&"park_escape")
    if not await _wait_scene(FILM) or not await _bind_film(): return false
    var previous_time := 0.0
    var last_time := 0.0
    var budget := int(ceil(float(manifest.duration) * 60.0)) + 720
    for index in range(budget):
        await process_frame
        if current_scene == null: continue
        if current_scene.scene_file_path != FILM: break
        if bool(movie.get("finishing")):
            natural_end = String(movie.get("finish_reason")) == "natural"
            _check_pending_checkpoint()
            continue
        var position := video.stream_position
        if not check(position + .002 >= previous_time, "film clock rewound during natural playback"): return false
        previous_time = position
        last_time = position
        if not _caption_matches(position): return false
        var cue := _expected_cue(position)
        if cue >= 0 and not _near_cue_edge(position) and not seen_cues.has(cue):
            seen_cues.append(cue)
            check(caption.get_line_count() <= caption.get_visible_line_count(), "Russian translation is clipped by its panel")
        for shot_index in range(manifest.shots.size()):
            var shot: Dictionary = manifest.shots[shot_index]
            var middle := (float(shot.start) + float(shot.end)) * .5
            if position >= middle and not seen_shots.has(shot_index):
                if not check(position < float(shot.end), "decoder skipped a complete manga shot"): return false
                seen_shots.append(shot_index)
                if not await _capture("shot-%02d" % (shot_index + 1)): return false
        if not failures.is_empty(): return false
    if not await _wait_scene(PURSUIT): return false
    check(natural_end and last_time >= float(manifest.duration) - .15, "film did not reach its natural decoded ending")
    check(seen_cues.size() == manifest.cues.size(), "not every Russian translation appeared during actual playback")
    check(seen_shots.size() == manifest.shots.size(), "not every manga shot decoded")
    _check_campaign("after natural ending")
    check(state.current_level == &"level2" and not paused, "natural ending did not enter the playable pursuit unpaused")
    check(not FileAccess.file_exists("user://botanical_garden.json"), "natural ending did not retire the completed park checkpoint after pursuit arrival")
    return failures.is_empty()

func _run() -> void:
    state = root.get_node("GameState")
    flow = root.get_node("SceneFlow")
    pause_manager = root.get_node("PauseManager")
    for path in PROFILE_FILES:
        original_files[path] = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null
    if visual and not check(not output_dir.is_empty() and DisplayServer.get_name() != "headless", "visual mode requires native rendering and an output directory"):
        await _finish(); return
    if not _validate_manifest(): await _finish(); return
    root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
    root.size = Vector2i(1280, 720)
    state.start_new_run()
    state.music_muted = true
    state.sfx_muted = false
    state.sfx_volume_db = -9.0
    state.acorns_collected = 6
    state.player_hp = 83
    state.player_ammo = 27
    if not _stage_completed_park_checkpoint(): await _finish(); return
    pause_manager.resume()
    if not await _lifecycle_and_skip(): await _finish(); return
    if not await _natural_playback(): await _finish(); return
    await _finish()

func _finish() -> void:
    if is_instance_valid(pause_manager): pause_manager.resume()
    if current_scene != null:
        current_scene.queue_free()
        current_scene = null
    await frames(6)
    await Teardown.drain_audio(self)
    for path in original_files:
        var content: Variant = original_files[path]
        if content == null:
            if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
        else:
            FileAccess.open(path, FileAccess.WRITE).store_buffer(content)
    if not output_dir.is_empty():
        DirAccess.make_dir_recursive_absolute(output_dir)
        var report_cues: Variant = manifest.get("cues", [])
        var report_shots: Variant = manifest.get("shots", [])
        var report := {
            "renderer": RenderingServer.get_current_rendering_method(), "manifest": MANIFEST,
            "duration": manifest.get("duration", 0), "cues": report_cues.size() if report_cues is Array else 0,
            "shots": report_shots.size() if report_shots is Array else 0, "seen_cues": seen_cues,
            "seen_shots": seen_shots, "captures": captures, "decoded_samples": decoded_samples,
            "audio_length": audio_length, "pause": pause_checked, "background": background_checked,
            "muted_subtitles": muted_captions_checked, "duplicate_finish": duplicate_end_delivered,
            "natural_end": natural_end, "failures": failures,
        }
        FileAccess.open(output_dir.path_join("park-escape-report.json"), FileAccess.WRITE).store_string(JSON.stringify(report, "  "))
    if failures.is_empty():
        print("PARK ESCAPE CINEMATIC: PASS — real manga video/audio, Russian timed captions, mute, pause/background, touch Skip, natural ending and preserved park/pursuit progress")
    quit(0 if failures.is_empty() else 1)
