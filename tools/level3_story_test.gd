extends SceneTree
## Physical cinematic/lifecycle regression. The separate full playthrough drives
## every dialogue, fight, pickup and boarding through actual player input.
const Teardown = preload("res://tools/level3_test_teardown.gd")
var game: Level3Store
var failures: Array[String] = []
func _init() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
    if not value:
        failures.append(message)
        push_error("LEVEL3 STORY: " + message)
func tick(count := 1) -> void:
    for index in range(count): await physics_frame
func hit_at_window() -> bool:
    var query := PhysicsRayQueryParameters2D.create(Vector2(-30,432),Vector2(70,432),1)
    return not game.get_world_2d().direct_space_state.intersect_ray(query).is_empty()
func run() -> void:
    root.size = Vector2i(1280,720)
    game = load("res://scenes/level3_store.tscn").instantiate()
    root.add_child(game);current_scene = game
    await tick(8)
    var story = game.mission
    check(game._enemies_alive == 0 and game._enemies.is_empty(), "diner must start peacefully without guards")
    check(game.player.position.y > 768, "Carolina did not start outside")
    check(game._doors.size() == 10, "two physical street doors are missing")
    check(game.navigation.path(game.player.position,game._scaled_cell_world(Level3StoreData.ORDER_CELL)).size() > 0, "street/kitchen route unavailable")
    check(story.car.kind == "240" and story.van.kind == "van", "wrong mission vehicle")
    check(not story.van.visible and story.car.door_open_amount == 0, "van/car initial presentation incorrect")
    check(story.chef.find_children("*","HitboxComponent",true,false).is_empty(), "civilian NPC can be shot")
    check(hit_at_window(), "pre-raid window has no physical glass")
    var sling = game.player.get_node_or_null("PineConeLauncherSling")
    check(sling != null and sling.visible, "cone launcher mentioned by the NPC is not visible on Carolina")
    game.player.equip_weapon(&"bat")
    game.player.equip_weapon(&"pistol", 12)
    check(is_instance_valid(sling) and sling.visible, "weapon switches removed the carried cone launcher")
    game.player._play_fire_animation()
    await tick(3)
    check(sling.visible, "attack animation hid the carried cone launcher")
    game.hud.mobile_active = true
    game.hud._layout()
    story.begin_raid()
    check(not game.pickups_root.visible, "collectible markers obscure the cinematic framing")
    check(not game.hud._map.visible and not game.move_joystick.visible and not game.weapon_label.visible, "inactive gameplay HUD obscures the arrival")
    check(game.action_button.visible and game.hud._pause.visible, "cinematic lost explicit Skip/Pause")
    await tick(60)
    var van_before: Vector2 = story.van.position
    var clock_before: float = story.clock
    game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
    await tick(25)
    check(paused, "focus loss did not pause the arrival")
    check(story.van.position == van_before and story.clock == clock_before, "van/timeline advanced while paused")
    check(game._mobile_move == Vector2.ZERO and not game._fire_held, "focus retained player control")
    story.skip_raid()
    check(story.phase == &"arrival", "paused cinematic accepted a skip")
    root.get_node("PauseManager").resume()
    for index in range(2400):
        if story.phase == &"assault": break
        await tick()
    check(story.phase == &"assault", "real van deployment/breach did not reach the assault")
    check(not story.raid_skipped, "normal fixture used the skip shortcut")
    check(story.deployment_count == 10 and story.deployed_positions.size() == 10, "not all ten squirrels physically reached their stacks")
    check(story.deployed_facings.size() == 10, "door/window facing snapshots are missing")
    for index in range(story.deployed_positions.size()):
        check(story.deployed_positions[index].distance_to(story.STACKS[index]) < 5, "squirrel failed to stack outside its door/window")
        var expected: float = story.deployed_positions[index].direction_to(story.STACK_AIMS[index]).angle()
        check(absf(angle_difference(story.deployed_facings[index],expected)) < .04, "squirrel held the wrong opening")
    for enemy in game._enemies: enemy.set_physics_process(false)
    await tick(5)
    check(game._enemies_alive == 10, "raid roster is not ten live squirrels")
    check(story.van.door_open_amount == 1, "van door did not finish opening")
    check(story._skids.size() == 2 and story._skids[0].get_point_count() > 20, "drift did not leave real tyre marks")
    check(story.glass_broken and story.flashbang_detonated, "window/flashbang sequence incomplete")
    check(not hit_at_window(), "broken glass still blocks the real room")
    check(game.navigation.ready, "navigation did not rebuild after the breach/van arrival")
    check(game.navigation.path(Vector2(-31,432),Vector2(70,432)).size() > 0, "breached window is not physically navigable")
    check(game.player.controls_enabled and not story.controls_locked(), "assault never returned control to the player")
    check(game.pickups_root.visible, "cinematic did not restore pickup presentation")
    for viewport_size in [Vector2i(960,540), Vector2i(1600,720), Vector2i(1280,720)]:
        root.size = viewport_size
        await process_frame
        game.hud._layout()
        check(game.hud._map.visible and game.move_joystick.visible and game.weapon_label.visible, "cinematic did not restore gameplay HUD")
        for button in game.hud._game_buttons(): check(button.visible and game.get_viewport().get_visible_rect().encloses(button.get_global_rect()), "restored button leaves mobile viewport")
    check(game.camera.zoom.is_equal_approx(Vector2.ONE*1.7), "cinematic camera did not return to gameplay")
    check(game.camera.position_smoothing_enabled, "cinematic camera smoothing did not return to gameplay")
    check(story.shot_history.has(&"sliding_door") and story.shot_history.has(&"window_breach"), "raid did not use the close door/window direction")
    check(not story.shot_history.has(&"map_overview"), "raid exposes a distant whole-map deployment")
    check(not game.order_collected and not game.environment.order_marker.visible, "pizza unlocked before defeating the assault")
    # Skip must commit the same world state without duplicate actors or signals.
    current_scene.queue_free();current_scene=null
    await tick(3)
    game = load("res://scenes/level3_store.tscn").instantiate()
    root.add_child(game);current_scene=game
    await tick(8)
    story=game.mission
    story.begin_raid();await tick(12)
    var skip_at: Vector2 = game.action_button.get_global_rect().get_center()
    var touch := InputEventScreenTouch.new()
    touch.index=42;touch.position=skip_at;touch.pressed=true;root.push_input(touch,true)
    var mouse := InputEventMouseButton.new()
    mouse.position=skip_at;mouse.button_index=MOUSE_BUTTON_LEFT;mouse.pressed=true;root.push_input(mouse,true)
    mouse=InputEventMouseButton.new();mouse.position=skip_at;mouse.button_index=MOUSE_BUTTON_LEFT;mouse.pressed=false;root.push_input(mouse,true)
    touch=InputEventScreenTouch.new();touch.index=42;touch.position=skip_at;touch.pressed=false;root.push_input(touch,true)
    story.skip_raid()
    check(not game._pending_action and not game._fire_held, "touch Skip leaked its emulated mouse into gameplay")
    for enemy in game._enemies: enemy.set_physics_process(false)
    await tick(8)
    check(story.phase == &"assault" and story.raid_skipped, "skip did not commit the assault")
    check(game._enemies.size() == 10 and story.deployment_count == 10, "duplicate skip duplicated attackers")
    check(story.glass_broken and story.flashbang_detonated and not hit_at_window(), "skip lost the broken-window/flashbang state")
    check(story._arrival_sounds.is_empty(), "arrival sound leaked past skip")
    game.queue_free();current_scene=null
    await tick(4)
    await Teardown.drain_audio(self)
    if failures.is_empty(): print("LEVEL3 STORY: PASS — peaceful street entry, physical van drift/door/ten stacks/window/flashbang, pause/focus, real breach navigation, restored camera/control and idempotent skip")
    quit(0 if failures.is_empty() else 1)
