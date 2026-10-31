extends SceneTree
## Actual game frames. Both lighting modes share the same camera and geometry.
const POSES=[
    ["entry",Vector3(0,.65,65),Vector3(0,11,-30)],
    ["concept",Vector3(-22,3.65,22),Vector3(0,6,-47)],
    ["conservatory",Vector3(0,7.65,-19),Vector3(0,14,-38)],
    ["upper",Vector3(-23,12.65,-88),Vector3(26,15,-61)],
    ["p60-entry",Vector3(0,.65,65),Vector3(3.4745514651,-2.7577871374,15.3115991062)],
    ["scout",Vector3(-5,.65,58),Vector3(-3,.75,56)],
    ["guardian",Vector3(5,7.65,-22),Vector3(0,8.4,-27)],
]
var output="user://botanical-lighting"
var only_view=""
var small:=false
var baked_only:=false
var hide_receivers:=false
var frozen_guards: Array=[]
var capture_contract: Dictionary={}
func _init() -> void:
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
        if arg.begins_with("--view="):only_view=arg.trim_prefix("--view=")
        if arg=="--small":small=true
        if arg=="--baked-only":baked_only=true
        if arg=="--hide-receivers":hide_receivers=true
    call_deferred("run")
func draw() -> void:
    await process_frame;call_deferred("force_draw");await RenderingServer.frame_post_draw
func force_draw() -> void:RenderingServer.force_draw(true)
func freeze_ready_garden(game) -> bool:
    var waited=0
    while not game.ready_for_play and waited<120:
        await physics_frame;waited+=1
    if not game.ready_for_play:
        push_error("Lighting capture: garden startup did not complete");return false
    # Await the load-time capsule repair and guard population before freezing.
    game.set_physics_process(false);game.player.set_physics_process(false);game.player.set_process_unhandled_input(false)
    game.player.process_mode=Node.PROCESS_MODE_DISABLED
    for guard in game.guards:
        guard.set_physics_process(false);guard.process_mode=Node.PROCESS_MODE_DISABLED
        frozen_guards.append({"actor":guard,"transform":guard.global_transform})
    var animations=game.find_children("*","AnimationPlayer",true,false)
    for animation in animations:animation.active=false
    capture_contract={"garden_ready":true,"waited_physics_frames":waited,"frozen_guard_count":frozen_guards.size(),"frozen_player":true,"frozen_animation_players":animations.size(),"actor_transforms_unchanged":true,"camera_transforms_unchanged":true}
    print("BOTANICAL LIGHTING FREEZE: ",capture_contract)
    return true
func frozen_actors_unchanged() -> bool:
    for frozen in frozen_guards:
        if not frozen.actor.global_transform.is_equal_approx(frozen.transform):return false
    return true
func run() -> void:
    DirAccess.make_dir_recursive_absolute(output)
    root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED;root.size=Vector2i(1600,1000)
    if small:root.size=Vector2i(640,400)
    root.get_node("GameState").start_new_run();root.get_node("GameState").music_muted=true;root.get_node("GameState").sfx_muted=true
    RenderingServer.set_render_loop_enabled(false)
    var game=load("res://game.tscn").instantiate();root.add_child(game);current_scene=game
    if not await freeze_ready_garden(game):quit(1);return
    assert(game.world.baked_lighting.enabled)
    var probe_data: Dictionary=game.world.baked_lighting.data.get("probe_data")
    assert(probe_data.points.size()>=748 and probe_data.sh.size()==probe_data.points.size()*9)
    game.hud.hide();game.weapon.hide()
    for label in game.find_children("*","Label3D",true,false):label.hide()
    game.world.set_meta("force_mobile_profile",true);game.world._mobile_profile()
    var results=[]
    for pose in POSES:
        if not only_view.is_empty() and pose[0]!=only_view:continue
        if not small:
            root.size=Vector2i(2582,1220) if pose[0].begins_with("p60-") else Vector2i(1600,1000)
            game.world._mobile_profile()
        game.player.position=pose[1];game.player.camera.look_at(pose[2])
        var fixed_camera: Transform3D=game.player.camera.global_transform
        var fixed_player: Transform3D=game.player.global_transform
        for baked in [false,true]:
            if baked_only and not baked:continue
            print("BOTANICAL LIGHTING DRAW BEGIN: ",pose[0]," baked=",baked)
            game.world.baked_lighting.set_enabled(baked)
            if hide_receivers:
                for receiver in game.world.baked_lighting.baked_root.get_children():
                    if receiver is MeshInstance3D:receiver.hide()
            for i in range(5):await draw()
            if not frozen_actors_unchanged() or not game.player.global_transform.is_equal_approx(fixed_player):
                push_error("Lighting capture: actor moved after freeze: "+pose[0]);quit(1);return
            if not game.player.camera.global_transform.is_equal_approx(fixed_camera):
                push_error("Lighting capture: camera drifted from authored pose: "+pose[0]);quit(1);return
            var file=pose[0]+("-baked.png" if baked else "-original.png")
            root.get_texture().get_image().save_png(output.path_join(file))
            results.append({"view":pose[0],"baked":baked,"calls":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),"triangles":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),"capture_contract":capture_contract,"camera_position":[game.player.camera.global_position.x,game.player.camera.global_position.y,game.player.camera.global_position.z],"camera_rotation_degrees":[game.player.camera.global_rotation_degrees.x,game.player.camera.global_rotation_degrees.y,game.player.camera.global_rotation_degrees.z]})
            print("BOTANICAL LIGHTING FRAME: ",results[-1])
            # Unique UV2 architecture adds bounded draws versus instanced
            # source geometry. Keep the previous triangle ceiling on all seven
            # views, including the actual wide P60 viewport and both squirrels.
            if results[-1].calls>550 or results[-1].triangles>260000:
                push_error("Baked-lighting render workload exceeded its budget")
                game.queue_free();current_scene=null;quit(1);return
    FileAccess.open(output.path_join("lighting.json"),FileAccess.WRITE).store_string(JSON.stringify(results,"  "))
    game.queue_free();current_scene=null
    for i in range(5):await process_frame
    await load("res://tools/level3_test_teardown.gd").drain_audio(self)
    RenderingServer.set_render_loop_enabled(true);quit()
