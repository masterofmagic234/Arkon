extends SceneTree
## Actual imported-model inspection and optional real gameplay motion recording.
const Weapon = preload("res://scripts/botanical_conegun.gd")
var output := "user://cedar-inspection"
var motion := false
var candidate_path := ""
var world: Node3D
var game: Node3D
func _init() -> void:
    for arg in OS.get_cmdline_user_args():
        if arg == "--motion": motion = true
        elif arg.begins_with("--candidate="): candidate_path = arg.trim_prefix("--candidate=")
        elif arg.begins_with("--output="): output = arg.trim_prefix("--output=")
    call_deferred("run")
func draw(count := 4) -> void:
    for i in range(count):
        await process_frame
        RenderingServer.force_draw(true)
func run() -> void:
    if DisplayServer.get_name() == "headless":
        push_error("CEDAR INSPECTION: native framebuffer required");quit(1);return
    root.size = Vector2i(1280, 800)
    root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
    DirAccess.make_dir_recursive_absolute(output)
    root.get_node("GameState").start_new_run()
    root.get_node("GameState").music_muted = true
    root.get_node("GameState").sfx_muted = not motion
    if motion:
        root.size = Vector2i(1280, 720)
        await motion_run()
        return
    RenderingServer.set_render_loop_enabled(false)
    world = Node3D.new()
    root.add_child(world)
    current_scene = world
    var environment_node := WorldEnvironment.new()
    var environment := Environment.new()
    environment.background_mode = Environment.BG_COLOR
    environment.background_color = Color("18222e")
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color("9faebb")
    environment.ambient_light_energy = .4
    environment.adjustment_enabled = true
    environment.adjustment_contrast = .94
    environment_node.environment = environment
    world.add_child(environment_node)
    var camera := Camera3D.new()
    camera.fov = 48
    camera.current = true
    world.add_child(camera)
    var lamp := DirectionalLight3D.new()
    lamp.rotation_degrees = Vector3(-40, -25, 0)
    lamp.light_energy = .7
    world.add_child(lamp)
    var weapon := Weapon.new()
    world.add_child(weapon)
    if not candidate_path.is_empty():
        var state := GLTFState.new()
        var importer := GLTFDocument.new()
        assert(importer.append_from_file(candidate_path, state) == OK)
        weapon.model.free()
        weapon.model = importer.generate_scene(state)
        weapon.model.name = "CedarModel"
        weapon.model.scale = Vector3.ONE * Weapon.MODEL_SCALE
        weapon.add_child(weapon.model)
        for node in weapon.model.find_children("*", "MeshInstance3D", true, false):
            node.layers = Weapon.VIEW_LAYER
            node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
            node.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
    var views := [
        ["whole-left", Vector3(-.95, .32, .70), Vector3(-.035, -.04, -.12)],
        ["whole-right", Vector3(.90, .32, .65), Vector3(-.035, -.04, -.12)],
        ["support-hand", Vector3(-.30, .05, -.035), Vector3(-.045, -.065, -.18)],
        ["wrapped-fingers", Vector3(.17, -.09, -.10), Vector3(-.025, -.065, -.185)],
        ["pine-cone-cassette", Vector3(-.28, .13, .10), Vector3(-.043, .002, .025)],
        ["hollow-muzzle", Vector3(.09, .10, -.68), Vector3(0, .026, -.43)],
    ]
    var frames: Array[String] = []
    for view in views:
        camera.position = view[1]
        camera.look_at(view[2])
        await draw(4)
        var file := output.path_join(view[0] + ".png")
        root.get_texture().get_image().save_png(file)
        frames.append(file)
    FileAccess.open(output.path_join("inspection.json"), FileAccess.WRITE).store_string(JSON.stringify({"captures":frames,"metrics":weapon.mesh_metrics(),"note":"Native views of actual imported GLB, not generated pictures or a phone FPS benchmark."},"  "))
    world.queue_free();current_scene=null
    for i in range(5): await process_frame
    RenderingServer.set_render_loop_enabled(true)
    print("CEDAR INSPECTION: PASS")
    quit()
func motion_run() -> void:
    # This captures an actual moving player and actual requests to fire. No
    # weapon-specific pose drive, teleport, recoil override or frame compositing.
    game = load("res://game.tscn").instantiate()
    root.add_child(game)
    current_scene = game
    for i in range(6): await physics_frame
    for guard in game.guards: guard.set_physics_process(false)
    game.player.handle_mouse_motion(Vector2(0, 37))
    game.hud.set_mobile_preview(true)
    game.hud.message_remaining = 0
    game.hud._refresh()
    Input.action_press("l1_move_forward")
    for i in range(54):
        if i == 27: Input.action_release("l1_move_forward")
        if i in [12, 26, 39]: game.player.request_fire()
        await process_frame
    Input.action_release("l1_move_forward")
    var audio = get_first_node_in_group("level1_audio")
    var events: Array = audio.event_log.duplicate(true) if audio != null else []
    FileAccess.open(output.path_join("motion-events.json"), FileAccess.WRITE).store_string(JSON.stringify({"actual_audio_events":events,"shots_requested":3,"frames":54,"note":"Actual player movement/fire and synchronized game SFX; guards are frozen for a clean weapon/audio excerpt. No teleport, damage/ammo or recoil override; not a phone FPS measure."},"  "))
    game.queue_free();current_scene=null
    for i in range(4): await process_frame
    await load("res://tools/level3_test_teardown.gd").drain_audio(self)
    print("CEDAR MOTION: PASS — actual walking and fire requests; staged quiet guard fixture")
    quit()
