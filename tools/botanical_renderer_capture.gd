extends SceneTree
## Frozen production frames for matching the garden across native renderers.
const POSES=[
    ["entry",Vector3(0,1.6,65),Vector3(-5,0,0)],
    ["concept",Vector3(-22,4.6,22),Vector3(0,6,-47)],
    ["pond",Vector3(25,4.6,31),Vector3(0,8,-20)],
    ["conservatory",Vector3(0,8.6,-19),Vector3(0,14,-38)],
    ["upper",Vector3(-23,13.6,-88),Vector3(26,15,-61)],
    ["p60-entry",Vector3(0,1.6,65),Vector3(-2.7,28.4,0)],
    ["p60-140",Vector3(-16,3,35.3),Vector3(-1.2,51.3,0)],
    ["scout",Vector3(-5,1.6,58),Vector3(-3,.75,56)],
    ["guardian",Vector3(5,8.6,-22),Vector3(0,8.4,-27)],
]
var output="user://botanical-renderer"
var expected=""
var only_view=""
var capture_contract: Dictionary={}
var frozen_guards: Array=[]
func _init() -> void:
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
        if arg.begins_with("--view="):only_view=arg.trim_prefix("--view=")
        if arg.begins_with("--expect-renderer="):expected=arg.trim_prefix("--expect-renderer=")
    call_deferred("run")
func draw() -> void:
    await process_frame;call_deferred("force_draw");await RenderingServer.frame_post_draw
func force_draw() -> void:RenderingServer.force_draw(true)
func poses() -> Array:return POSES
func freeze_ready_garden(game) -> bool:
    var waited=0
    while not game.ready_for_play and waited<120:
        await physics_frame;waited+=1
    if not game.ready_for_play:
        push_error("Renderer capture: garden startup did not complete");return false
    # Garden startup awaits physics registration before it enables the player
    # and creates the guards. Freeze only after that lifecycle has completed.
    game.set_physics_process(false);game.player.set_physics_process(false);game.player.set_process_unhandled_input(false)
    game.player.process_mode=Node.PROCESS_MODE_DISABLED
    for guard in game.guards:
        guard.set_physics_process(false);guard.process_mode=Node.PROCESS_MODE_DISABLED
        frozen_guards.append({"actor":guard,"transform":guard.global_transform})
    var animations=game.find_children("*","AnimationPlayer",true,false)
    for animation in animations:animation.active=false
    capture_contract={"garden_ready":true,"waited_physics_frames":waited,"frozen_guard_count":frozen_guards.size(),"frozen_player":true,"frozen_animation_players":animations.size(),"actor_transforms_unchanged":true,"camera_transforms_unchanged":true}
    print("BOTANICAL RENDERER FREEZE: ",capture_contract)
    return true
func frozen_actors_unchanged() -> bool:
    for frozen in frozen_guards:
        if not frozen.actor.global_transform.is_equal_approx(frozen.transform):return false
    return true
func run() -> void:
    var method=RenderingServer.get_current_rendering_method()
    if not expected.is_empty() and method!=expected:
        push_error("Renderer fallback: expected "+expected+", got "+method);quit(1);return
    DirAccess.make_dir_recursive_absolute(output)
    root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
    root.get_node("GameState").start_new_run();root.get_node("GameState").music_muted=true;root.get_node("GameState").sfx_muted=true
    RenderingServer.set_render_loop_enabled(false)
    var game=load("res://game.tscn").instantiate();root.add_child(game);current_scene=game
    if not await freeze_ready_garden(game):quit(1);return
    assert(game.world.baked_lighting.enabled)
    # Shader TIME keeps advancing under pause. Freeze water for a lighting /
    # ordering comparison rather than counting animated ripples as regressions.
    var water=Shader.new();water.code=game.world.mats.water.shader.code.replace("TIME","0.0");game.world.mats.water.shader=water
    game.hud.hide();game.weapon.hide()
    for label in game.find_children("*","Label3D",true,false):label.hide()
    game.world.set_meta("force_mobile_profile",true)
    var camera=game.player.camera;var results=[]
    for pose in poses():
        if not only_view.is_empty() and pose[0]!=only_view:continue
        root.size=Vector2i(2582,1220) if pose[0].begins_with("p60-") else Vector2i(1600,1000)
        game.world._mobile_profile();camera.global_position=pose[1]
        if pose[0].begins_with("p60-") or pose[0]=="entry":camera.global_rotation_degrees=pose[2]
        else:camera.look_at(pose[2])
        var fixed_camera: Transform3D=camera.global_transform
        var fixed_player: Transform3D=game.player.global_transform
        for i in range(5):await draw()
        if not frozen_actors_unchanged() or not game.player.global_transform.is_equal_approx(fixed_player):
            push_error("Renderer capture: actor moved after freeze: "+pose[0]);quit(1);return
        if not camera.global_transform.is_equal_approx(fixed_camera):
            push_error("Renderer capture: camera drifted from authored pose: "+pose[0]);quit(1);return
        root.get_texture().get_image().save_png(output.path_join(pose[0]+".png"))
        var row={"view":pose[0],"calls":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),"triangles":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),"scale_3d":root.scaling_3d_scale,"msaa":root.msaa_3d,"camera_position":[camera.global_position.x,camera.global_position.y,camera.global_position.z],"camera_rotation_degrees":[camera.global_rotation_degrees.x,camera.global_rotation_degrees.y,camera.global_rotation_degrees.z],"actor_transforms_unchanged":true,"camera_transform_unchanged":true}
        results.append(row);print("BOTANICAL RENDERER FRAME: ",row)
        if row.calls>550 or row.triangles>260000:
            push_error("Production workload exceeded 550 calls / 260k triangles");quit(1);return
    FileAccess.open(output.path_join("renderer.json"),FileAccess.WRITE).store_string(JSON.stringify({"renderer":method,"adapter":RenderingServer.get_video_adapter_name(),"baked":game.world.baked_lighting.enabled,"capture_contract":capture_contract,"views":results},"  "))
    game.queue_free();current_scene=null
    for i in range(5):await process_frame
    await load("res://tools/level3_test_teardown.gd").drain_audio(self)
    RenderingServer.set_render_loop_enabled(true);print("BOTANICAL RENDERER CAPTURE: PASS");quit()
