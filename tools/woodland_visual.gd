extends SceneTree
# Staged native production-scene evidence. Actors are frozen for repeatable
# images; this fixture is not a gameplay replay or a phone FPS benchmark.
const Teardown = preload("res://tools/level3_test_teardown.gd")
const CALL_LIMIT := 260
const TRIANGLE_LIMIT := 150000
const PIXEL_LIMIT := 1280.0 * 720.0
const POSES := [
    {"name":"entry", "position":Vector3(0,.65,21), "target":Vector3(0,3.5,-27.5)},
    {"name":"lake", "position":Vector3(-18,.65,-4), "target":Vector3(-27,.65,-18)},
    {"name":"hut", "position":Vector3(17,.65,5), "target":Vector3(28,1.8,-1)},
    {"name":"tank", "position":Vector3(0,.65,-3), "target":Vector3(0,1.2,-10)},
    {"name":"oak", "position":Vector3(7,.65,-18), "target":Vector3(0,4,-27.5)},
]
var output := "user://woodland-visual"
var failures: Array[String] = []
var report: Dictionary = {}
var game: Node3D
var saved_scale := 1.0
var saved_window_size := Vector2i.ZERO
var saved_content_mode := Window.CONTENT_SCALE_MODE_DISABLED

func _initialize() -> void:
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--output="):
            output = argument.trim_prefix("--output=")
    call_deferred("_run")

func _check(condition: bool, message: String) -> void:
    if condition:
        return
    failures.append(message)
    push_error("WOODLAND VISUAL: " + message)

func _force_frame() -> void:
    RenderingServer.force_draw(true)

func _draw() -> Image:
    # Register for completion before forcing a frame. A disabled continuous
    # loop avoids spending CI time rendering unchanged software-Vulkan frames.
    await process_frame
    call_deferred("_force_frame")
    await RenderingServer.frame_post_draw
    return root.get_texture().get_image()

func _capture(name_: String) -> Image:
    await _draw()
    var image: Image = await _draw()
    _check(image != null and not image.is_empty(), name_ + ": empty native framebuffer")
    if image == null or image.is_empty():
        return image
    _check(image.get_size() == root.size, name_ + ": native UI/framebuffer size changed")
    var low := 1.0
    var high := 0.0
    for y in range(1,8):
        for x in range(1,12):
            var pixel := image.get_pixel(image.get_width()*x/12, image.get_height()*y/8)
            var luminance := pixel.get_luminance()
            low=minf(low,luminance); high=maxf(high,luminance)
    _check(high > .025 and high-low > .025, name_ + ": blank or uniform scene")
    _check(image.save_png(output.path_join(name_ + ".png")) == OK, name_ + ": cannot save evidence")
    return image

func _pose(position_: Vector3, target: Vector3) -> void:
    game.player.position=position_
    game.player.rotation=Vector3.ZERO
    game.player.velocity=Vector3.ZERO
    game.player.camera.look_at(target)
    game.hud.message_remaining=0
    game.hud._refresh()

func _native_mobile_check(name_: String) -> void:
    var scale_: float=root.scaling_3d_scale
    var pixels: float=root.size.x*root.size.y*scale_*scale_
    _check(game.world.mobile_rendering, name_ + ": mobile profile is not active")
    _check(pixels <= PIXEL_LIMIT+4, name_ + ": 3D pixel cap exceeded")
    _check(not game.world.environment.glow_enabled, name_ + ": expensive fullscreen glow enabled")
    _check(game.hud.root.size.is_equal_approx(Vector2(root.size)), name_ + ": UI is not at native resolution")
    var screen := Rect2(Vector2.ZERO,Vector2(root.size))
    for control: Control in [game.hud.joystick,game.hud.fire_button,game.hud.interact_button,game.hud.dash_button,game.hud.quiet_button,game.hud.pause_button]:
        var rect := control.get_global_rect()
        _check(control.visible and screen.encloses(rect), name_ + ": mobile control is hidden or offscreen: " + str(control.name))
    var hint: Label=game.hud.mission_hint
    var hint_height: float=hint.get_theme_font("font").get_height(hint.get_theme_font_size("font"))*hint.get_line_count()
    _check(hint_height<=hint.size.y+2,name_ + ": objective hint clips vertically")
    _check(game.hud.mission.get_global_rect().end.y<=hint.get_global_rect().position.y,
        name_ + ": objective title overlaps hint")
    _check(hint.get_global_rect().end.y<=game.hud.lanterns.get_global_rect().position.y,
        name_ + ": objective hint overlaps task count")
    if game.hud.boss_panel.visible:
        _check(not hint.get_global_rect().intersects(game.hud.boss_panel.get_global_rect()),
            name_ + ": objective hint overlaps tank health panel")
    report.layouts.append({"view":name_,"native_ui":[root.size.x,root.size.y],"scale_3d":scale_,"pixels_3d":pixels,"hint_lines":hint.get_line_count()})

func _textures() -> void:
    var expected := {
        "ground":["meadow","leaf_litter","contact_shade"],
        "gravel":["meadow","leaf_litter","contact_shade"],
        "tree_bark":["bark"],
        "tree_leaf":["leaves"],
        "tree_leaf_light":["leaves"],
        "tree_gold":["leaves"],
    }
    for material_name: String in expected:
        var material: ShaderMaterial=game.world.materials.get(material_name) as ShaderMaterial
        _check(material != null, "missing production material " + material_name)
        if material == null:
            continue
        for parameter: String in expected[material_name]:
            var texture=material.get_shader_parameter(parameter)
            _check(texture is Texture2D and texture.get_width()>0 and texture.get_height()>0,
                "missing production texture " + material_name + "/" + parameter)
    _check(game.tank.visual.model_path == "res://assets/level1/characters/tank_squirrel.glb", "tank uses the wrong character")
    _check(game.tank.visual.skeleton_ready and game.tank.visual.skeleton.get_bone_count()>=78, "supplied tank rig missing")
    var tank_meshes: Array[Node] = game.tank.visual.model_instance.find_children("*","MeshInstance3D",true,false)
    _check(not tank_meshes.is_empty(),"tank mesh missing")
    for mesh: MeshInstance3D in tank_meshes:
        for surface in range(mesh.mesh.get_surface_count()):
            var material := mesh.get_active_material(surface) as StandardMaterial3D
            _check(material != null and material.albedo_texture != null,"tank base-color texture missing")

func _run() -> void:
    if DisplayServer.get_name()=="headless" or RenderingServer.get_current_rendering_method()!="forward_plus":
        push_error("WOODLAND VISUAL: native Forward+ required")
        quit(1)
        return
    _check(DirAccess.make_dir_recursive_absolute(output)==OK,"cannot create evidence directory")
    if not failures.is_empty():
        quit(1)
        return
    RenderingServer.set_render_loop_enabled(false)
    saved_scale=root.scaling_3d_scale
    saved_window_size=root.size
    saved_content_mode=root.content_scale_mode
    root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
    root.size=Vector2i(1920,1080)
    root.get_node("GameState").music_muted=true
    root.get_node("GameState").sfx_muted=true
    root.get_node("PauseManager").resume()
    game=load("res://game.tscn").instantiate()
    root.add_child(game)
    current_scene=game
    # Freeze the real actors immediately: the native fixture cannot win/lose
    # the mission while a software renderer prepares its first frame.
    game.set_physics_process(false)
    game.set_process_unhandled_input(false)
    game.player.set_physics_process(false)
    game.player.input_enabled=false
    for guard in game.guards:
        guard.set_physics_process(false)
        guard.visual._face_direction(guard.position.direction_to(Vector3(0,0,3)))
    Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
    game.world.set_meta("force_mobile_profile",true)
    game.world._mobile_profile()
    game.hud.set_mobile_preview(true)
    for index in range(3):
        await process_frame
    report={"adapter":RenderingServer.get_video_adapter_name(),
        "renderer":RenderingServer.get_current_rendering_method(),
        "scene":"res://game.tscn","staged_actors":true,
        "note":"Native software rendering is visual/submission evidence, not phone FPS.",
        "limits":{"draw_calls":CALL_LIMIT,"triangles":TRIANGLE_LIMIT,"pixels_3d":PIXEL_LIMIT},
        "probes":[],"layouts":[]}
    _textures()
    for pose in POSES:
        game.stage="cache" if pose.name=="tank" else "trail"
        _pose(pose.position,pose.target)
        await _capture(pose.name)
        var visible_calls := RenderingServer.viewport_get_render_info(root.get_viewport_rid(),RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)
        var visible_triangles := RenderingServer.viewport_get_render_info(root.get_viewport_rid(),RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME)
        var shadow_calls := RenderingServer.viewport_get_render_info(root.get_viewport_rid(),RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW,RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)
        var shadow_triangles := RenderingServer.viewport_get_render_info(root.get_viewport_rid(),RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW,RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME)
        var canvas_calls := RenderingServer.viewport_get_render_info(root.get_viewport_rid(),RenderingServer.VIEWPORT_RENDER_INFO_TYPE_CANVAS,RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)
        var canvas_triangles := RenderingServer.viewport_get_render_info(root.get_viewport_rid(),RenderingServer.VIEWPORT_RENDER_INFO_TYPE_CANVAS,RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME)
        var global_calls := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
        var global_triangles := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
        # Include actual shadow and native HUD work. There is one production
        # viewport in this fixture; global counters cannot hide off-camera
        # shadow casters or an extra renderer pass.
        var calls := maxi(global_calls, visible_calls+shadow_calls+canvas_calls)
        var triangles := maxi(global_triangles,visible_triangles+shadow_triangles+canvas_triangles)
        _check(calls>0 and triangles>0,pose.name + ": renderer returned no submission counters")
        _check(calls<=CALL_LIMIT,pose.name + ": exceeds draw-call budget: " + str(calls))
        _check(triangles<=TRIANGLE_LIMIT,pose.name + ": exceeds triangle budget: " + str(triangles))
        var probe := {"view":pose.name,"draw_calls":calls,"triangles":triangles,
            "visible_calls":visible_calls,"visible_triangles":visible_triangles,
            "shadow_calls":shadow_calls,"shadow_triangles":shadow_triangles,
            "canvas_calls":canvas_calls,"canvas_triangles":canvas_triangles,
            "global_calls":global_calls,"global_triangles":global_triangles,
            "position":[pose.position.x,pose.position.y,pose.position.z]}
        report.probes.append(probe)
        print("WOODLAND MOBILE PROBE: ",probe)
    _native_mobile_check("full-hd")
    game.stage="trail"
    _pose(Vector3(-22,.65,-4.4),Vector3(-22,1.6,-7))
    await _capture("station")
    _check(not game.hud.prompt.text.is_empty(),"real station context prompt is missing")
    for layout in [{"name":"mobile-small","size":Vector2i(960,540)},
                   {"name":"mobile-ultrawide","size":Vector2i(2340,1080)}]:
        root.size=layout.size
        for index in range(3):
            await process_frame
        _pose(Vector3(0,.65,-3),Vector3(0,1.2,-10))
        game.stage="cache"
        game.hud._refresh()
        await _capture(layout.name)
        _native_mobile_check(layout.name)
    root.size=Vector2i(1280,720)
    for index in range(3):
        await process_frame
    root.get_node("PauseManager").set_paused(true)
    game.hud._refresh()
    await _capture("pause")
    _check(game.hud.modal.visible and game.hud.resume_button.visible,"pause panel missing")
    root.get_node("PauseManager").resume()
    game.queue_free()
    current_scene=null
    for index in range(4):
        await process_frame
    _check(is_equal_approx(root.scaling_3d_scale,saved_scale),"3D scale leaked after leaving Level1")
    report["scale_restored"]=root.scaling_3d_scale
    report["failures"]=failures
    var file:=FileAccess.open(output.path_join("woodland-evidence.json"),FileAccess.WRITE)
    _check(file!=null,"cannot write evidence report")
    if file!=null:
        file.store_string(JSON.stringify(report,"  "))
        file.close()
    root.size=saved_window_size
    root.content_scale_mode=saved_content_mode
    await Teardown.drain_audio(self)
    RenderingServer.set_render_loop_enabled(true)
    if failures.is_empty():
        print("WOODLAND VISUAL: PASS — production scene, tank, textures, native controls, bounded mobile rendering and profile restoration")
        quit(0)
    else:
        quit(1)
