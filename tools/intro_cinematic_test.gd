extends SceneTree

var visual := false
var output_dir := ""
var shots: Array[String] = []
var motion_signature := PackedByteArray()
var motion_samples := 0
var max_motion_delta := 0.0
var reading_loops := 0
var motion_picture: Image
var motion_position := 0.0

func _sample_motion() -> bool:
    if not visual:
        return true
    await RenderingServer.frame_post_draw
    var picture := root.get_texture().get_image()
    if picture == null or picture.is_empty():
        _fail("empty motion framebuffer")
        return false
    # Sample rendered video including its handoff, excluding changing UI.
    picture = picture.get_region(Rect2i(32,150,1216,330))
    # Antialias before comparison: bilinear minification aliases the room's
    # fine edges as the camera moves by fractions of a pixel.
    picture.resize(160,44,Image.INTERPOLATE_LANCZOS)
    picture.convert(Image.FORMAT_RGB8)
    var signature := picture.get_data()
    if not motion_signature.is_empty():
        var total := 0.0
        for index in range(signature.size()):
            total += absf(float(signature[index])-float(motion_signature[index]))
        var difference := total/float(signature.size())
        max_motion_delta = maxf(max_motion_delta,difference)
        if difference>2.5:
            DirAccess.make_dir_recursive_absolute(output_dir)
            if motion_picture != null:
                motion_picture.save_png(output_dir.path_join("motion-before.png"))
            picture.save_png(output_dir.path_join("motion-after.png"))
            print("INTRO MOTION FAILURE: previous=",motion_position," current=",current_scene.get_node("VideoPlayer").stream_position," clip=",current_scene.get("clip_index"))
            _fail("abrupt native video change/black flash: %.4f" % difference)
            return false
    motion_picture = picture
    motion_position = current_scene.get_node("VideoPlayer").stream_position
    motion_signature = signature
    motion_samples += 1
    return true

func _init() -> void:
    for arg in OS.get_cmdline_user_args():
        if arg == "--visual":
            visual = true
        elif arg.begins_with("--output="):
            output_dir = arg.trim_prefix("--output=")
    call_deferred("_run")

func _fail(message: String) -> void:
    push_error("INTRO CINEMATIC: " + message)
    quit(1)

func _wait_scene(path: String, _frames: int = 240) -> bool:
    var flow := root.get_node("SceneFlow")
    var deadline := Time.get_ticks_msec()+20000
    while Time.get_ticks_msec()<deadline:
        await process_frame
        if visual and RenderingServer.is_render_loop_enabled()==false:
            RenderingServer.call_deferred("force_draw",false)
            await RenderingServer.frame_post_draw
        if current_scene != null and current_scene.scene_file_path == path and not bool(flow.get("_transitioning")):
            return true
    return false

func _wait_clip(index: int) -> bool:
    motion_signature.clear()
    for frame in range(700):
        await process_frame
        if current_scene == null or current_scene.scene_file_path != "res://intro_cutscene.tscn":
            return false
        if visual and frame%2==0 and not await _sample_motion():
            return false
        if int(current_scene.get("clip_index")) == index and not bool(current_scene.get("clip_transitioning")):
            # Allow the video decoder to present actual frames.
            for settle in range(24):
                await process_frame
            return true
    return false

func _capture(name: String) -> bool:
    if not visual:
        return true
    await RenderingServer.frame_post_draw
    var picture := root.get_texture().get_image()
    if picture == null or picture.is_empty():
        _fail("empty native framebuffer: " + name)
        return false
    var bright := 0
    for y in range(40, picture.get_height() - 220, 20):
        for x in range(20, picture.get_width() - 20, 20):
            if picture.get_pixel(x,y).get_luminance() > 0.015:
                bright += 1
    if bright < 100:
        _fail("video framebuffer is black: " + name)
        return false
    DirAccess.make_dir_recursive_absolute(output_dir)
    var target := output_dir.path_join(name + ".png")
    if picture.save_png(target) != OK:
        _fail("could not save native capture")
        return false
    shots.append(target)
    return true

func _click(position: Vector2 = Vector2(80, 250)) -> void:
    var event := InputEventMouseButton.new()
    event.button_index = MOUSE_BUTTON_LEFT
    event.position = position
    event.global_position = position
    event.pressed = true
    Input.parse_input_event(event)
    await process_frame
    event = InputEventMouseButton.new()
    event.button_index = MOUSE_BUTTON_LEFT
    event.position = position
    event.global_position = position
    event.pressed = false
    Input.parse_input_event(event)
    await process_frame

func _run() -> void:
    if visual and output_dir.is_empty():
        _fail("visual capture directory required")
        return
    var flow := root.get_node("SceneFlow")
    var state := root.get_node("GameState")
    for clip in ["1789650644963", "1789649201942", "1789650878847", "1789649329293"]:
        var path: String = "res://assets/intro_video/" + clip + ".ogv"
        if not FileAccess.file_exists(path) or FileAccess.get_file_as_bytes(path).size() < 10000:
            _fail("missing/empty built video: " + path)
            return
    flow.go_to(&"menu")
    if not await _wait_scene("res://menu.tscn"):
        _fail("menu failed to load")
        return
    state.mark_completed(&"level2")
    var launch: Button = current_scene.get_node("LevelButtons/IntroButton")
    launch.pressed.emit()
    if not await _wait_scene("res://intro_cutscene.tscn"):
        _fail("story menu action did not open intro")
        return
    if state.is_completed(&"level2") or state.current_level != &"intro":
        _fail("story did not reset run or enter the intro through SceneFlow")
        return
    var intro := current_scene
    for frame in range(60):
        await process_frame
    if bool(intro.get("dialogue_started")):
        _fail("opening room shot must be silent")
        return
    # A casual touch on the establishing shot must not skip the story.
    var touch := InputEventScreenTouch.new()
    touch.pressed = true
    touch.position = Vector2(500, 300)
    Input.parse_input_event(touch)
    await process_frame
    touch = InputEventScreenTouch.new()
    touch.pressed = false
    Input.parse_input_event(touch)
    await process_frame
    if bool(intro.get("finished")):
        _fail("touch on silent opening unexpectedly skipped intro")
        return
    if not await _capture("01-opening"):
        return
    if not await _wait_clip(1):
        _fail("opening decoder did not naturally finish into first dialogue clip")
        return
    if int(intro.get("current_dialogue_index")) != 0:
        _fail("first dialogue did not start at line 0")
        return
    var player: VideoStreamPlayer = intro.get_node("VideoPlayer")
    if not player.is_playing() or player.get_video_texture() == null or player.get_video_texture().get_width() != 1280:
        _fail("Theora decoder did not expose the HD video")
        return
    if not await _capture("02-first-dialogue"):
        return
    # Check actual UI geometry at three supported landscape sizes.
    for size in [Vector2i(854,480), Vector2i(1280,720), Vector2i(1600,900), Vector2i(1600,720)]:
        root.size = size
        await process_frame
        await process_frame
        if absf(player.size.x / player.size.y - 16.0/9.0) > 0.01:
            _fail("video proportions stretched at %s" % size)
            return
        var panel: Control = intro.get_node("Dialogue")
        var label: Label = intro.get_node("Dialogue/Text")
        if label.get_global_rect().end.x > panel.get_global_rect().end.x - 20 or label.size.x < 400:
            _fail("dialogue overflows panel at %s" % size)
            return
    root.size = Vector2i(1280,720)
    await process_frame
    for expected in range(1,5):
        await _click()
        if int(intro.get("current_dialogue_index")) != expected:
            _fail("real mouse input did not advance line %d" % expected)
            return
    # First block may loop while the user reads; it must not advance silently.
    motion_signature.clear()
    var previous_position := player.stream_position
    for frame in range(310):
        await process_frame
        var position := player.stream_position
        if position<previous_position:
            reading_loops += 1
        previous_position = position
        if position>3.9 or position<.15:
            if not await _sample_motion():
                return
        else:
            motion_signature.clear()
    if int(intro.get("clip_index")) != 1 or int(intro.get("current_dialogue_index")) != 4:
        _fail("first dialogue block advanced without input")
        return
    if reading_loops<1:
        _fail("reading loop did not complete a real decoder cycle")
        return
    await _click()
    if not await _wait_clip(2):
        _fail("line 4 did not enter silent Darina transition")
        return
    if bool(intro.get("dialogue_started")):
        _fail("silent middle shot retained dialogue")
        return
    if not await _capture("03-transition"):
        return
    if not await _wait_clip(3):
        _fail("silent transition decoder did not naturally reach final dialogue")
        return
    if int(intro.get("current_dialogue_index")) != 5:
        _fail("final block did not start at line 5")
        return
    for frame in range(50):
        await process_frame
    if not await _capture("04-promise"):
        return
    for expected in range(6,17):
        await _click()
        if int(intro.get("current_dialogue_index")) != expected:
            _fail("real mouse input did not reach final line %d" % expected)
            return
    await _click()
    if not await _wait_scene("res://game.tscn") or state.current_level != &"level1":
        _fail("story completion did not enter Level 1 with correct campaign state")
        return
    # Explicit skip has the same safe handoff and cannot complete any level.
    flow.go_to(&"intro")
    if not await _wait_scene("res://intro_cutscene.tscn"):
        _fail("replay intro failed")
        return
    var skip_button: Button = current_scene.get_node("SkipButton")
    await _click(skip_button.global_position + skip_button.size * 0.5)
    if not await _wait_scene("res://game.tscn") or state.current_level != &"level1":
        _fail("skip did not enter Level 1 through SceneFlow")
        return
    if state.is_completed(&"level1"):
        _fail("intro or skip incorrectly completed Level 1")
        return
    if visual:
        if motion_samples<60:
            _fail("native motion sampling did not cover the scene")
            return
        var report := FileAccess.open(output_dir.path_join("intro-report.json"),FileAccess.WRITE)
        report.store_string(JSON.stringify({"renderer":RenderingServer.get_current_rendering_method(),"captures":shots,"dialogue_lines":17,"clips":4,"motion_samples":motion_samples,"max_motion_delta":max_motion_delta,"reading_loops":reading_loops},"  "))
    # Release the coroutine's input events and capture resources before exit.
    call_deferred("_finish")

func _finish() -> void:
    # Stop registered music while its scene-owned player still exists.
    root.get_node("AudioManager").shutdown()
    if is_instance_valid(current_scene):
        current_scene.queue_free()
    for frame in range(6):
        await process_frame
    # The mixer retires stopped MP3 playbacks asynchronously. Let it finish,
    # then process the releases before SceneTree quits.
    OS.delay_msec(200)
    for frame in range(3):
        await process_frame
    print("INTRO CINEMATIC: PASS — real four-clip decoding, 17 dialogue lines, input, looping, mobile layout, skip and campaign handoff")
    quit(0)
