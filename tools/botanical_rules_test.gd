extends SceneTree
var game: Node3D
var failed:=false
func _init() -> void:call_deferred("run")
func check(ok: bool,why: String) -> void:
    if not ok:failed=true;push_error("BOTANICAL RULES: "+why)
func settle(n:=12) -> void:
    for i in range(n):await physics_frame
func at(point: Vector3) -> void:
    game.player.position=point+Vector3.UP*.65;game.interact()
func emulated_mouse(point: Vector2,pressed: bool) -> void:
    var event:=InputEventMouseButton.new();event.device=InputEvent.DEVICE_ID_EMULATION;event.button_index=MOUSE_BUTTON_LEFT
    event.position=point;event.global_position=point;event.pressed=pressed
    root.push_input(event,true)
func mobile_action() -> void:
    var point=game.hud.interact_button.get_global_rect().get_center()
    var touch=InputEventScreenTouch.new();touch.index=9;touch.position=point;touch.pressed=true
    game.hud._input(touch)
    await process_frame;emulated_mouse(point,true)
    await process_frame;touch.pressed=false;game.hud._input(touch);emulated_mouse(point,false)
    await process_frame
func run() -> void:
    root.get_node("GameState").start_new_run();root.get_node("GameState").sfx_muted=true;root.get_node("GameState").music_muted=true
    var scale_before=root.scaling_3d_scale;var msaa_before=root.msaa_3d;var occlusion_before=root.use_occlusion_culling;var fps_before=Engine.max_fps
    change_scene_to_file("res://game.tscn");await settle();game=current_scene;game.player.set_physics_process(false)
    var benches=0;var plants=0
    for record in game.world.placement_records:
        var p: Vector3=record.root
        check(is_equal_approx(p.y,record.support_y),"decoration root detached from its support")
        if record.kind=="ground_plant":
            plants+=1
            check(absf(p.y-game.world.surface_height_at(p.x,p.z))<.001,"ground plant floats above terrain triangles")
            check(not (p.z>24 and p.z<46 and absf(p.x)>17 and absf(p.x)<31),"ground plant occupies a lower stair flight")
            check(not (p.z> -73 and p.z< -51 and absf(p.x)>38 and absf(p.x)<59),"ground plant occupies an upper side ramp")
        elif record.kind=="bench":
            benches+=1
            var basis=Basis(Vector3.UP,record.yaw)
            for dx in [-1.1,1.1]:
                for dz in [-.35,.35]:
                    var foot=p+basis*Vector3(dx,0,dz)
                    check(absf(foot.y-game.world.surface_height_at(foot.x,foot.z))<.02,"bench leg lacks ground support")
            check(Vector2(p.x/22,(p.z-23)/12).length()>1,"bench placed in pool")
            check(p.distance_to(Vector3(28,3,19))>4 and p.distance_to(Vector3(38,3,19))>4,"bench obstructs valve access")
    check(benches==7 and plants>500,"curated furnishings or volumetric planting is missing")
    for kind in [3,4,5]:
        var mesh=game.world.meshes["herb%d"%kind]
        check(mesh.get_surface_count()==1 and mesh.get_aabb().size.z>.3 and mesh.get_aabb().position.y>=-.001,"herb is a flat card or has a floating root")
    var code=game.world.mats.plants.shader.code
    check(not "discard" in code and not "ALPHA" in code,"opaque herbs still run an alpha pass")
    at(game.DEPARTURE);check(not game.mission_complete,"fresh garden allowed car completion")
    at(Vector3(0,7,-20));check(game.stage!="cache","unrestored garden started the final fight")
    at(game.PART_POSITIONS[1]);check(game.progress.parts==[false,true,false],"service parts are incorrectly gated by an unrelated location")
    check(not game.progress.installed,"collecting a part magically installed the pump hardware")
    game.player.toggle_quiet();check(not game.player.quiet_mode and not game.hud.quiet_button.visible,"stealth is still exposed in the combat-only garden")
    check(game.weapon.name=="PineConeLauncher","the slingshot was not replaced by the cone launcher")
    check(game.world.get_node_or_null("GardenPerimeter/SolidPerimeter")!=null and game.world.get_node_or_null("ContinuousOuterLandscape")!=null,"night fog is hiding a missing physical boundary/landscape")
    check(game.world.environment.fog_density>=.01 and game.world.get_node("GardenSun").light_energy<.3,"garden is still lit as daytime")
    game.hud.set_mobile_preview(true);Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
    game.player.position=Vector3(28,3.65,19);await process_frame
    await mobile_action();check(game.progress.valves[0],"one physical Android tap reopened then closed the valve")
    for i in range(5):await process_frame
    check(game.progress.valves[0],"valve reverted on the following frames")
    await mobile_action();check(not game.progress.valves[0],"a second intentional tap could not close the valve")
    at(Vector3(33,3,19));check(not game.progress.water,"wrong valve pattern was accepted")
    at(Vector3(33,3,19));at(Vector3(28,3,19));at(Vector3(38,3,19))
    check(not game.progress.water and not game.water_flow.moving_water.visible,"unrepaired pump accepted the valve pattern")
    at(game.PANEL);check(not game.progress.installed,"panel accepted incomplete repair hardware")
    var ray=PhysicsRayQueryParameters3D.create(Vector3(0,8.4,-32),Vector3(0,8.4,-34),1)
    var blocked=game.get_world_3d().direct_space_state.intersect_ray(ray)
    check(not blocked.is_empty() and blocked.collider==game.water_flow.gate_body,"closed store gate lacks a physical leaf")
    at(game.PART_POSITIONS[0]);at(game.PART_POSITIONS[2])
    check(game.progress.parts==[true,true,true] and not game.progress.installed,"finding all hardware bypassed the installation step")
    at(game.PANEL)
    check(game.progress.installed and game.progress.water and game.water_flow.moving_water.visible,"panel repair did not power the contained water channels")
    check(game.water_flow.installed_parts.visible and game.water_flow.installed_parts.get_child_count()==3,"installed fuse, gear and key are not visibly fitted to the panel")
    await settle(160)
    check(game._garden_ready() and game.water_flow.gate_open>=.98 and game.water_flow.gate_body.position.y>3.5,"hydraulic leaf did not physically rise")
    at(Vector3(28,3,19));await settle(3)
    check(not game.progress.water and game._garden_ready() and game.progress.gate_unlatched,"closing a valve magically re-locked the raised store")
    at(Vector3(28,3,19))
    var unblocked=game.get_world_3d().direct_space_state.intersect_ray(ray)
    check(unblocked.is_empty() or unblocked.collider!=game.water_flow.gate_body,"raised gate still blocks the open entrance")
    at(Vector3(0,7,-36));check(not game.progress.reward,"guarded reward was collected before the guardian")
    game._save();var old_id=game.get_instance_id();game.restart();await settle(30);game=current_scene
    check(game.get_instance_id()!=old_id,"retry never replaced the old instance")
    check(game.progress.water and game.progress.parts==[true,true,true] and game.progress.installed,"retry discarded partial quest progress")
    check(game.player.get_hp()==100 and game.player.ammo==38 and game.player.position.z>60,"retry did not restore safe entry resources")
    game.world.set_meta("force_mobile_profile",true);root.size=Vector2i(2400,1080);game.world._mobile_profile()
    check(root.scaling_3d_scale<.61,"Android 3D pixel cap missing")
    check(Engine.max_fps>0 and Engine.max_fps<=60,"high-refresh Android frame cap missing")
    game.hud.set_mobile_preview(true)
    var touch=InputEventScreenTouch.new();touch.index=8;touch.pressed=true;touch.position=game.hud.map_button.get_global_rect().get_center();game.hud._input(touch)
    check(root.get_node("PauseManager").is_paused and game.hud.map_panel.visible,"touch map did not pause the game")
    game.hud._input(touch);check(not root.get_node("PauseManager").is_paused,"touch map could not close while paused")
    # Use both input paths of one Android tap across separate frames. The
    # second, GUI activation used to close the pause opened by the raw touch.
    Input.mouse_mode=Input.MOUSE_MODE_VISIBLE;await process_frame
    var pause_point=game.hud.pause_button.get_global_rect().get_center()
    touch.position=pause_point;game.hud._input(touch)
    await process_frame;emulated_mouse(pause_point,true)
    await process_frame;touch.pressed=false;game.hud._input(touch);emulated_mouse(pause_point,false)
    await process_frame
    check(root.get_node("PauseManager").is_paused and game.hud.modal.visible,"emulated release of a pause tap resumed the game")
    var diagnostics_point=game.hud.diagnostics_button.get_global_rect().get_center()
    emulated_mouse(diagnostics_point,true);emulated_mouse(diagnostics_point,false)
    var opened_probe: CanvasLayer
    for child in root.get_children():
        if child.get_script()==load("res://scripts/botanical_performance_probe.gd"):opened_probe=child
    check(opened_probe!=null,"paused touch could not open FPS diagnostics")
    if opened_probe!=null:
        # The native timed sampling is covered by botanical_probe_test; here
        # cancel immediately after the real GUI button opened it.
        opened_probe.cancelled=true
        for i in range(3):await process_frame
        opened_probe.queue_free();await process_frame
    check(root.get_node("PauseManager").is_paused,"diagnostics opening/cancel resumed gameplay")
    var continue_point=game.hud.resume_button.get_global_rect().get_center()
    emulated_mouse(continue_point,true);emulated_mouse(continue_point,false)
    await process_frame
    check(not root.get_node("PauseManager").is_paused,"explicit Continue did not resume after diagnostics")
    root.get_node("SceneFlow").go_to(&"menu");await settle(30)
    check(is_equal_approx(root.scaling_3d_scale,scale_before) and root.msaa_3d==msaa_before and root.use_occlusion_culling==occlusion_before and Engine.max_fps==fps_before,"garden rendering profile leaked to the menu")
    check(current_scene.get_node("LevelButtons/Level1Button").text.begins_with("ПРОДОЛЖИТЬ"),"menu lost saved garden continuation")
    current_scene.get_node("LevelButtons/Level1Button").pressed.emit();await settle(30);game=current_scene
    check(game.progress.water and game.progress.parts[1] and game.progress.installed,"menu resume erased the partially completed garden")
    # A process can be killed during the new departure film. Preserve the
    # existing garden save until arrival in Level2; loading it must recover the
    # six earned acorns even when all volatile GameState fields were lost.
    game.progress.guardian=true;game.progress.reward=true
    game.player.position=game.DEPARTURE+Vector3.UP*.65;game._save()
    root.get_node("GameState").acorns_collected=6;game.interact();await settle(30)
    check(current_scene.scene_file_path=="res://scenes/park_escape_cutscene.tscn","rewarded boarding bypassed the departure film")
    check(FileAccess.file_exists("user://botanical_garden.json"),"departure film deleted the completed garden save")
    root.get_node("GameState").completed_levels.clear();root.get_node("GameState").acorns_collected=0
    root.get_node("SceneFlow").go_to(&"menu");await settle(30)
    check(current_scene.get_node("LevelButtons/Level1Button").text.begins_with("ПРОДОЛЖИТЬ"),"interrupted film lost the saved continuation")
    current_scene.get_node("LevelButtons/Level1Button").pressed.emit();await settle(30);game=current_scene
    check(game.progress.reward and root.get_node("GameState").acorns_collected==6,"resuming after a cold process lost the acorns")
    game.player.set_physics_process(false);game.interact();await settle(30)
    check(current_scene.scene_file_path=="res://scenes/park_escape_cutscene.tscn","resumed reward could not reboard the departure")
    check(root.get_node("GameState").is_completed(&"level1"),"reboarding did not restore campaign completion")
    current_scene.get_node("Frame/SkipButton").pressed.emit();await settle(30)
    check(current_scene.scene_file_path=="res://scenes/level2.tscn" and root.get_node("GameState").acorns_collected==6,"film skip lost the completed garden reward")
    check(not FileAccess.file_exists("user://botanical_garden.json"),"Level2 arrival retained the finished garden checkpoint")
    root.get_node("GameState").start_new_run();check(not FileAccess.file_exists("user://botanical_garden.json"),"new adventure kept the garden checkpoint")
    current_scene.queue_free();current_scene=null;await settle();await load("res://tools/level3_test_teardown.gd").drain_audio(self)
    if not failed:print("BOTANICAL RULES: PASS — independent service-part collection, required physical installation, negative pump/valve/reward gates, real moving hydraulic leaf, combat-only controls and evening boundary, partial checkpoint retry, native touch map, menu resume, profile restoration and new run")
    quit(1 if failed else 0)
