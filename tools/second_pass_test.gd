extends SceneTree
const AssaultFixture = preload("res://tools/level3_assault_fixture.gd")
const Teardown=preload("res://tools/level3_test_teardown.gd")
var failed := false
func _init() -> void: call_deferred("_run")
func check(value: bool, message: String) -> void:
    if not value:
        failed=true
        push_error("SECOND PASS: "+message)
func tick(count: int) -> void:
    for i in range(count): await physics_frame
func wait_for_scene(path: String, timeout_msec: int = 30000) -> bool:
    var flow := root.get_node("SceneFlow")
    var deadline := Time.get_ticks_msec() + timeout_msec
    while Time.get_ticks_msec() < deadline:
        var loader: Variant = flow.get("loading_screen")
        if is_instance_valid(loader) and bool(loader.get("failed")):
            check(false,"loading failure while waiting for " + path)
            return false
        if current_scene != null and current_scene.scene_file_path == path and not bool(flow.get("_transitioning")) and bool(flow.call("_scene_ready",current_scene)):
            return true
        await process_frame
        if DisplayServer.get_name() != "headless":
            call_deferred("force_transition_draw")
            await RenderingServer.frame_post_draw
    check(false,"timed out waiting for ready scene " + path)
    return false
func force_transition_draw() -> void:
    RenderingServer.force_draw(true)
func touch(id: int, at: Vector2, pressed: bool, canceled: bool=false) -> void:
    var event := InputEventScreenTouch.new()
    event.index=id;event.position=at;event.pressed=pressed;event.canceled=canceled
    root.push_input(event,true)
func drag(id: int, at: Vector2) -> void:
    var event := InputEventScreenDrag.new()
    event.index=id;event.position=at
    root.push_input(event,true)
func _run() -> void:
    root.size=Vector2i(1280,720)
    var race=load("res://scenes/level2.tscn").instantiate()
    root.add_child(race);current_scene=race
    await tick(4)
    for dimensions in [Vector2i(960,540),Vector2i(1280,720),Vector2i(1600,720)]:
        root.size=dimensions
        await process_frame
        race.presentation.layout()
        var screen := root.get_visible_rect()
        for control in [race.joystick,race.gas_button,race.brake_button,race.presentation.pause_button]:
            check(control.is_visible_in_tree(),"required driving control hidden")
            check(screen.encloses(control.get_global_rect()),"race control outside "+str(dimensions))
        check(not race.minimap.is_visible_in_tree() and not race.minimap.is_processing(),"removed race map is visible or still processing")
        for id in ["Speed","Gear","Best"]:
            var readout: Control=race.hud_background.get_node(id)
            check(readout.is_visible_in_tree() and screen.encloses(readout.get_global_rect()),"required driving readout hidden/outside: "+id)
            for pedal in [race.gas_button,race.brake_button]:
                check(not pedal.get_global_rect().intersects(readout.get_global_rect()),"pedal hides visible driving readout: "+id)
        for id in ["LapLabel","Lap","PosLabel","Pos","TimeLabel","Time"]:
            check(not race.hud_background.get_node(id).is_visible_in_tree(),"removed race telemetry is visible: "+id)
    var stick: Vector2=race.joystick.get_global_rect().get_center()
    var gas: Vector2=race.gas_button.get_global_rect().get_center()
    var brake: Vector2=race.brake_button.get_global_rect().get_center()
    touch(31,stick+Vector2(35,0),true)
    touch(32,gas,true)
    touch(33,brake,true)
    check(race.race_input.steer>.2 and race.race_input.throttle==1 and race.race_input.brake==1,"three independent driving touches")
    touch(34,Vector2.ZERO,false)
    check(race.race_input.pointers.size()==3,"foreign release stole a control")
    touch(31,Vector2.ZERO,false,true)
    check(race.race_input.steer==0 and race.race_input.throttle==1 and race.race_input.brake==1,"steering cancel released pedals")
    drag(32,Vector2(-30,-30))
    check(race.race_input.throttle==0 and race.race_input.brake==1,"off-button pedal drag")
    race.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
    check(paused and race.presentation.overlay.visible and race.race_input.pointers.is_empty(),"focus loss failed to clear/pause race")
    root.get_node("PauseManager").resume()
    check(race.race_input.read().throttle==0 and race.race_input.read().brake==0,"phantom pedals after resume")
    # Drive the final real boundary through RaceController, then inspect the
    # result screen and frozen clock before accepting the user's Continue.
    race.state.race_started=true
    race.state.lap=0
    race.state.lap_time=60
    race.controller.player.lap=1
    race.controller.player.segment_index=0
    race.controller.player.segment_progress=race.controller.player.grid_world_z_offset/40.0-.0001
    race.controller.player.speed=30
    # Staging changes canonical route state. Synchronize its world coordinates
    # before the real fixed step so swept contacts observe the final half metre,
    # rather than interpreting the fixture placement as a drive across 8.88 km.
    race.controller.player.tick(0.0,false,race.controller.track_pattern,race.controller.track_x)
    race.controller.update(1.0/60)
    var time_: float=race.state.race_time
    check(race.presentation.finished and race.presentation.overlay.visible,"missing finish result")
    await tick(20)
    check(current_scene==race and is_equal_approx(race.state.race_time,time_),"finish timer/transition runs before Continue")
    race.presentation.continue_button.pressed.emit()
    # Continue starts a resource thread. Process-frame counts do not measure
    # its completion, and the test must not quit while that handoff is pending.
    if not await wait_for_scene("res://scenes/level3_store.tscn"):quit(1);return
    check(current_scene!=null and current_scene.scene_file_path=="res://scenes/level3_store.tscn","race Continue did not reach diner")
    if current_scene==null or current_scene.scene_file_path!="res://scenes/level3_store.tscn": quit(1);return
    var diner: Level3Store=current_scene
    await tick(8)
    if not await AssaultFixture.prepare(self, diner): quit(1);return
    for enemy in diner._enemies: enemy.set_physics_process(false)
    diner.set_process(false);diner.set_physics_process(false)
    diner.player.set_physics_process(false)
    diner.player.global_position=Vector2(200,688)
    # A thin real collision object reproduces the extended-muzzle wall exploit.
    var barrier := StaticBody2D.new()
    barrier.position=Vector2(214,688)
    barrier.collision_layer=1
    var collider := CollisionShape2D.new()
    var box := RectangleShape2D.new();box.size=Vector2(4,80);collider.shape=box
    barrier.add_child(collider);diner.add_child(barrier)
    await tick(2)
    var muzzle := diner.safe_muzzle(diner.player.global_position,Vector2.RIGHT,18)
    check(muzzle.x<212 and muzzle.x>200,"muzzle spawned past a nearby wall")
    var enemy: Level3Enemy=diner._enemies[0]
    enemy.global_position=Vector2(260,688)
    var before: int=enemy._health_component.current_health
    diner._on_player_fire_requested(Vector2(218,688),Vector2.RIGHT,&"pistol")
    await tick(40)
    check(enemy._health_component.current_health==before,"player shot crossed a wall behind the muzzle")
    barrier.queue_free()
    await tick(2)
    # A full-health player standing on a medkit must receive it after damage.
    var medkit: Level3Pickup=load("res://scenes/level3_pickup.tscn").instantiate()
    medkit.kind=&"medkit";medkit.position=diner.player.global_position
    diner.pickups_root.add_child(medkit)
    await tick(12)
    check(is_instance_valid(medkit) and not medkit.consumed,"full-health player wasted medkit")
    diner.player.take_damage(20)
    await tick(15)
    check(diner.player.health==100 and not is_instance_valid(medkit),"medkit stayed inert under wounded player")
    # Feedback is bounded and decays, including the world effect draw list.
    for i in range(200):
        diner.effects.muzzle(Vector2(30,40),0)
        diner.effects.trace(Vector2(180,120),Vector2(280,120),Color.WHITE)
    check(diner.effects.active_count()<=96,"effects exceeded the fixed pool")
    await tick(60)
    check(diner.effects.active_count()==0 and diner.feedback.damage_strength==0,"expired feedback persisted")
    current_scene=null;diner.queue_free()
    await tick(3)
    await Teardown.drain_audio(self)
    if failed: quit(1)
    else:
        print("SECOND PASS: PASS — 3 race viewports; owned multi-touch; focus/pause; finish/Continue; thin-wall muzzle; stationary medkit; bounded feedback")
        quit(0)
