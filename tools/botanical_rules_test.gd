extends SceneTree
const Fixture=preload("res://tools/botanical_fixture149.gd")
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
    change_scene_to_file("res://game.tscn");await settle();game=current_scene;Fixture.freeze(game)
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
        var fast_mesh=game.world.performance_herb_meshes.get(kind) as ArrayMesh
        check(fast_mesh!=null,"production herb LOD asset is missing")
        if fast_mesh!=null:
            check(fast_mesh.get_surface_count()==1 and fast_mesh.get_aabb().size.z>.3 and fast_mesh.get_aabb().position.y>=-.001,"optimized nearby herb became a flat card or lost its ground support")
            check(fast_mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX].size()<mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX].size(),"optimized nearby herb did not reduce real triangle work")
    for material in [game.world.mats.plants,game.world.performance_herb_material]:
        var code=material.shader.code
        check(not "discard" in code and not "ALPHA" in code,"opaque herbs still run an alpha pass")
    at(game.DEPARTURE);check(not game.mission_complete,"fresh garden allowed car completion")
    at(Vector3(0,7,-20));check(game.stage!="cache","unrestored garden started the final fight")
    check(game.PART_POSITIONS.size()==1,"maintenance still requires a cross-garden fetch chain")
    at(game.PART_POSITIONS[0]);check(not game.progress.parts[0],"fuse bypassed the entry and repair defenders")
    at(game.PANEL);check(not game.progress.installed and not game.progress.water,"empty panel powered the pump")
    game.player.toggle_quiet();check(not game.player.quiet_mode and not game.hud.quiet_button.visible,"stealth is still exposed in the combat-only garden")
    check(game.weapon.name=="PineConeLauncher","the slingshot was not replaced by the cone launcher")
    check(game.world.get_node_or_null("GardenPerimeter/SolidPerimeter")!=null and game.world.get_node_or_null("ContinuousOuterLandscape")!=null,"night fog is hiding a missing physical boundary/landscape")
    check(game.world.environment.fog_density>=.01 and game.world.get_node("GardenSun").light_energy<.3,"garden is still lit as daytime")
    Fixture.complete(game,"entry");await settle(2)
    at(game.PART_POSITIONS[0]);check(not game.progress.parts[0],"entry victory bypassed the repair defenders")
    Fixture.complete(game,"pump_repair");await settle(2)
    # One Android gesture reaches both the raw touch and emulated GUI paths.
    # It must collect one fuse without accidentally performing the next action.
    game.hud.set_mobile_preview(true);Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
    game.player.position=game.PART_POSITIONS[0]+Vector3.UP*.65;await process_frame
    await mobile_action();check(game.progress.parts[0] and not game.progress.installed,"one physical Android tap did not collect exactly the one service fuse")
    await settle(5);check(game.progress.parts.count(true)==1 and not game.progress.installed,"fuse pickup duplicated or auto-installed after touch release")
    var ray=PhysicsRayQueryParameters3D.create(Vector3(0,8.4,-32),Vector3(0,8.4,-34),1)
    var blocked=game.get_world_3d().direct_space_state.intersect_ray(ray)
    check(not blocked.is_empty() and blocked.collider==game.water_flow.gate_body,"closed store gate lacks a physical leaf")
    game.player.health.current_health=35;game.player.ammo=2
    game.player.position=game.PANEL+Vector3.UP*.65;await process_frame;await mobile_action()
    check(game.progress.installed and game.progress.water and game.water_flow.moving_water.visible,"one deliberate panel action did not power the contained water channels")
    check(game.water_flow.installed_parts.visible and game.water_flow.installed_parts.get_child_count()==1,"the one fuse is not visibly fitted to the panel")
    check(game.player.get_hp()>=80 and game.player.ammo==38 and game.progress.checkpoint_id=="pump_start","starved first panel activation did not grant its safe counterattack checkpoint")
    game.player.health.current_health=31;game.player.ammo=4
    await mobile_action();check(game.progress.installed and not game.encounter_director.is_complete("pump"),"repeated panel tap bypassed the counterattack")
    check(game.player.get_hp()==31 and game.player.ammo==4,"repeated panel tap granted duplicate pump-start resources")
    game.progress.valves.assign([false,false,false]);game._apply_garden_state()
    check(game.progress.water,"obsolete valve flags disabled the repaired pump")
    await settle(165)
    check(not game._garden_ready() and game.water_flow.gate_open<.01,"pump action bypassed the gallery defenders")
    Fixture.complete(game,"pump");await settle(2)
    at(Vector3(0,7,-18));Fixture.complete(game,"gallery");await settle(170)
    check(game._garden_ready() and game.water_flow.gate_open>=.98 and game.water_flow.gate_body.position.y>3.5,"earned gallery key did not physically raise the hydraulic leaf")
    check(game.progress.gate_unlatched,"raised store was not latched for future checkpoints")
    var unblocked=game.get_world_3d().direct_space_state.intersect_ray(ray)
    check(unblocked.is_empty() or unblocked.collider!=game.water_flow.gate_body,"raised gate still blocks the open entrance")
    at(Vector3(0,7,-36));check(not game.progress.reward,"guarded reward was collected before the guardian")
    var checkpoint_id: String=game.progress.checkpoint_id
    var checkpoint_hp: int=game.progress.checkpoint_hp;var checkpoint_ammo: int=game.progress.checkpoint_ammo
    var checkpoint_position: Vector3=game.progress.checkpoint_position
    # Real supply pickup is consumed once in live play, while retry restores
    # ownership from the last chapter snapshot along with its exact resources.
    var checkpoint_supplies: Array=game.progress.checkpoint_supplies.duplicate()
    var supply=game.supplies[0]
    game.player.position=supply.position+Vector3.UP*.65;game.player.health.current_health=30;game.player.ammo=1
    await settle(2)
    check(supply.get_meta("used",false) and not supply.visible and game.progress.used_supplies.has(0) and game.player.get_hp()==60 and game.player.ammo==19,"real supply did not grant and persist its one-time 30HP/18-cone pickup")
    game.player.health.current_health=30;game.player.ammo=1;await settle(3)
    check(game.player.get_hp()==30 and game.player.ammo==1,"standing on a spent supply repeatedly refilled resources")
    game.player.position=Vector3(0,7.65,-36)
    game.player.health.current_health=17;game.player.ammo=3;game._save()
    check(game.progress.hp==17 and game.progress.ammo==3,"ordinary save silently refilled spent resources")
    var old_id=game.get_instance_id();game.restart();await settle(30);game=current_scene;Fixture.freeze(game)
    check(game.get_instance_id()!=old_id,"retry never replaced the old instance")
    check(game.progress.water and game.progress.parts[0] and game.progress.installed,"retry discarded the earned pump repair")
    check(game.progress.checkpoint_id==checkpoint_id and game.player.get_hp()==checkpoint_hp and game.player.ammo==checkpoint_ammo and game.player.position.distance_to(checkpoint_position)<.1,"retry did not restore the last earned encounter snapshot")
    check(game.progress.used_supplies==checkpoint_supplies and game.supplies[0].visible and not game.supplies[0].get_meta("used",false),"retry did not restore supply ownership from its checkpoint snapshot")
    game.player.health.current_health=17;game.player.ammo=3
    Fixture.complete(game,"gallery");await settle(2)
    check(game.player.get_hp()==17 and game.player.ammo==3,"revisiting an already completed chapter granted a duplicate resupply")
    game.player.health.current_health=checkpoint_hp;game.player.ammo=checkpoint_ammo
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
    check(game.progress.water and game.progress.parts[0] and game.progress.installed,"menu resume erased the partially completed garden")
    # A process can be killed during the new departure film. Preserve the
    # existing garden save until arrival in Level2; loading it must recover the
    # six earned acorns even when all volatile GameState fields were lost.
    Fixture.freeze(game)
    game.progress.guardian=true;game.progress.reward=true
    game.player.position=game.DEPARTURE+Vector3.UP*.65;game.interact()
    check(not game.mission_complete,"earned acorns bypassed the mandatory final escape")
    Fixture.complete(game,"escape");await settle(2)
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
    if not failed:print("BOTANICAL RULES: PASS — one earned pump fuse, required physical installation and counterattack/gallery/escape gates, real moving hydraulic leaf, combat-only controls and evening boundary, partial checkpoint retry, native touch map, menu resume, profile restoration and new run")
    quit(1 if failed else 0)
