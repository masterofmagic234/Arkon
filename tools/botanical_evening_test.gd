extends SceneTree
## Evening-specific authored changes, independent of the unchanged foliage gates.
const Fixture=preload("res://tools/botanical_fixture149.gd")
var game: Node3D
var failures: Array[String]=[]
var visual:=false
var output="user://botanical-evening"
var captures: Array[String]=[]
var legacy_migration: Dictionary={}
func _init() -> void:
    for arg in OS.get_cmdline_user_args():
        if arg=="--visual":visual=true
        elif arg.begins_with("--output="):output=arg.trim_prefix("--output=")
    call_deferred("run")
func check(ok: bool,why: String) -> void:
    if not ok:failures.append(why);push_error("BOTANICAL EVENING: "+why)
func settle(n:=12) -> void:
    for i in range(n):await physics_frame
func at(point: Vector3) -> void:game.player.position=point+Vector3.UP*.65;game.interact()
func capture(title: String,camera: Vector3,look: Vector3) -> void:
    if not visual:return
    game.player.camera.global_position=camera;game.player.camera.look_at(look)
    await process_frame;RenderingServer.force_draw(true);await process_frame;RenderingServer.force_draw(true)
    var path=output.path_join(title+".png");root.get_texture().get_image().save_png(path);captures.append(path);print("EVENING FRAME: ",title)
func run() -> void:
    root.get_node("GameState").start_new_run();root.get_node("GameState").music_muted=true;root.get_node("GameState").sfx_muted=true
    if visual:
        check(DisplayServer.get_name()!="headless","native frames require a real renderer")
        DirAccess.make_dir_recursive_absolute(output);root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED;root.size=Vector2i(1600,1000);RenderingServer.set_render_loop_enabled(false)
    change_scene_to_file("res://game.tscn");await settle(18);game=current_scene;await await_garden_ready(game)
    game.player.set_physics_process(false)
    for guard in game.guards:guard.set_physics_process(false)
    check(game.get_node_or_null("GardenScout")==null,"friendly scout/peaceful route survived")
    check(game.world.baked_lighting.data.resource_path.ends_with("garden_evening.lmbake"),"production kept daytime irradiance")
    check(game.world.environment.fog_enabled and game.world.environment.fog_density>=.01,"evening depth fog missing")
    check(game.world.get_node("GardenSun").light_energy<.3,"daylight direct intensity remains")
    check(game.world.get_node("ContinuousOuterLandscape").get_aabb().size.x>=4000,"outer ground still ends at the playable garden")
    var outer_arrays=game.world.get_node("ContinuousOuterLandscape").mesh.surface_get_arrays(0)
    check(outer_arrays[Mesh.ARRAY_NORMAL][0].y>.2,"outer landscape faces away from an above-ground camera")
    check(game.world.get_node("GardenPerimeter/SolidPerimeter").get_child_count()>100,"perimeter only has a visual fog wall")
    check(not game.player.quiet_enabled and not game.hud.quiet_button.visible,"stealth still accessible")
    check(game.weapon.name=="PineConeLauncher","held model remains a slingshot")
    if visual:
        game.world.set_meta("force_mobile_profile",true);game.world._mobile_profile();game.hud.set_mobile_preview(true);game.hud.message_remaining=0
    await capture("entry-weapon",Vector3(0,1.6,65),Vector3(0,5,35))
    game.hud.hide();game.weapon.hide()
    await capture("closed-store",Vector3(0,9,-29),Vector3(0,9,-36))
    await capture("dry-channel",Vector3(40,9,-20),Vector3(44,5,-14))
    # Explicit staged battle outcomes; actual pickup/install handlers follow.
    # The complete fresh normal-input route is botanical_playthrough.gd.
    Fixture.complete(game,"entry");Fixture.complete(game,"pump_repair");await settle(2)
    check(game.PART_POSITIONS.size()==1,"maintenance still sends the player after three distant parts")
    for position in game.PART_POSITIONS:at(position)
    check(game.progress.parts.count(true)==1 and not game.progress.installed,"collecting the fuse bypassed physical installation")
    at(game.PANEL)
    check(game.progress.installed and game.water_flow.installed_parts.get_child_count()==1,"the pump fuse is not fitted in the panel")
    await settle(165)
    check(game.progress.water and game.water_flow.moving_water.visible,"one pump action failed to produce water")
    check(game.water_flow.gate_open<.01,"water power bypassed the gallery encounter")
    await capture("flowing-channel",Vector3(40,9,-20),Vector3(44,5,-14))
    await capture("installed-hardware",Vector3(23,4.9,21.2),Vector3(23,3.9,19))
    Fixture.complete(game,"pump");Fixture.complete(game,"gallery");await settle(165)
    check(game.progress.service_key and game.water_flow.gate_open<.01,"gallery key bypassed the front lever")
    at(game.GATE_LEVER+Vector3(-1.4,0,1));await settle(165)
    check(game.water_flow.gate_open>=.98 and game.water_flow.gate_body.position.y>3.5,"gallery key and lever never physically opened the hydraulic gate")
    check(game.water_flow.piston_rod.scale.y>3.5 and game.water_flow.piston_rod.position.y>11,"pressure-driven ram did not visibly extend with the gate")
    check(game.water_flow.moving_water.get_child_count()==1,"water is fragmented into per-segment draw calls")
    for node in game.water_flow.moving_water.get_children():check(node.mesh is ArrayMesh,"flow remains floating box geometry")
    await capture("open-store",Vector3(0,9,-29),Vector3(0,9,-36))
    var height: float=game.world.surface_height_at(-85,-94)
    await capture("boundary-upper-outward",Vector3(-85,height+2.3,-94),Vector3(-135,8,-145))
    await capture("boundary-upper-look-down",Vector3(-85,height+3.5,-94),Vector3(-94,height-3,-104))
    await capture("boundary-entrance-look-down",Vector3(0,3.5,74),Vector3(0,-4,94))
    await capture("outer-landscape-look-down",Vector3(-210,65,-210),Vector3(-220,20,-210))
    # A legacy escort count is inert: every new completion must fight.
    game.progress.guide_step=5;at(Vector3(0,7,-24));await settle(2)
    check(game.stage=="cache" and not game.tank.defeated and not game.progress.guardian,"legacy peaceful escort bypassed the guardian")
    at(Vector3(0,7,-36));check(not game.progress.reward,"reward available before defeating guardian")
    game.queue_free();current_scene=null;await settle(8)
    if visual:RenderingServer.force_draw(true)
    await check_legacy_migration(true)
    await check_legacy_migration(false)
    await load("res://tools/level3_test_teardown.gd").drain_audio(self)
    if visual:RenderingServer.set_render_loop_enabled(true)
    if visual:FileAccess.open(output.path_join("evening-report.json"),FileAccess.WRITE).store_string(JSON.stringify({"failures":failures,"captures":captures,"legacy_migration":legacy_migration,"parts_installed":1,"guardian":"mandatory combat","irradiance":"offline evening data","outer_landscape":4096,"note":"Authored native scene fixtures; physical full playthrough is a separate test. No phone FPS claim."},"  "))
    if failures.is_empty():print("BOTANICAL EVENING: PASS — real evening irradiance, physical horizon/perimeter, cone launcher, fitted hardware, contained flow/hydraulic gate and mandatory guardian")
    quit(0 if failures.is_empty() else 1)

func check_legacy_migration(earned_reward: bool) -> void:
    root.get_node("GameState").start_new_run()
    var raw={"version":1,"journal":true,"water":true,"valves":[true,false,true],"seeds":[true,true,true],"mirrors":[1,2],"guide_step":5,"guardian":true,"reward":earned_reward,"position":[0,7.65,-36],"hp":100,"ammo":38,"defeated":[]}
    var path=preload("res://scripts/botanical_state.gd").PATH
    FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(raw))
    change_scene_to_file("res://game.tscn");await settle(20);game=current_scene;await await_garden_ready(game)
    # The fixture disables automatic rendering. Complete the new world's sky
    # buffers before freeing it, just as a real gameplay frame would do.
    if visual:
        for i in range(4):
            await process_frame;RenderingServer.force_draw(true)
    for guard in game.guards:guard.set_physics_process(false)
    if earned_reward:
        check(game.progress.parts[0] and game.progress.installed and game.progress.water,"earned legacy escape lost its prior pump repair")
        check(game.encounter_director.can_depart(),"earned v1 reward was relocked behind new escape encounters")
    else:
        check(game.progress.parts.count(true)==0 and not game.progress.installed,"legacy specimens were converted into unearned repair hardware")
    if earned_reward:
        check(game.progress.reward and game.progress.gate_unlatched and game.water_flow.gate_open>=.98,"earned legacy acorns spawned inside a newly locked store")
        Input.action_press("l1_move_backward")
        await settle(125);Input.action_release("l1_move_backward")
        check(game.player.position.z> -32.4,"earned v1 player could not physically walk out through the raised gate")
        check(root.get_node("GameState").acorns_collected==6,"v1 migration lost earned acorns")
        legacy_migration.completed_escape=game.player.position.z> -32.4
    else:
        check(not game.progress.guardian and not game.progress.gate_unlatched and game.water_flow.gate_open<.01,"legacy peaceful outcome unlocked the new combat route")
        check(game.player.position.z> -33.0,"unfinished legacy player remained trapped inside the new cage")
        var before=game.player.position
        Input.action_press("l1_move_backward");Input.action_press("l1_move_right")
        await settle(90);Input.action_release("l1_move_backward");Input.action_release("l1_move_right")
        check(game.player.position.distance_to(before)>2.0,"relocated unfinished player could not physically leave the store entrance")
        check(not game.progress.reward,"unfinished v1 migration granted acorns")
        legacy_migration.unfinished_safe_spawn=game.player.position.distance_to(before)>2.0
    game.queue_free();current_scene=null;await settle(8)
    if visual:RenderingServer.force_draw(true)
    root.get_node("GameState").start_new_run()

func await_garden_ready(scene: Node3D) -> void:
    for frame in range(300):
        if scene.ready_for_play:return
        await physics_frame
    check(false,"production garden did not finish its collision-safe startup")
