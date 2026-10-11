extends SceneTree
const Teardown = preload("res://tools/level3_test_teardown.gd")
var game: Level3Store
var _failed := false
func _init() -> void: call_deferred("_run")
func check(ok: bool, message: String) -> bool:
    if not ok:
        _failed=true
        push_error("LEVEL 3 SMOKE TEST: "+message)
    return ok
func tick(count: int = 1) -> void:
    for i in range(count): await physics_frame
func touch(id: int, at: Vector2, pressed: bool, canceled: bool = false) -> void:
    var event := InputEventScreenTouch.new()
    event.index=id;event.position=at;event.pressed=pressed;event.canceled=canceled
    root.push_input(event,true)
func drag(id: int, at: Vector2) -> void:
    var event := InputEventScreenDrag.new()
    event.index=id;event.position=at
    root.push_input(event,true)
func action(id: String, pressed: bool) -> void:
    var event := InputEventKey.new()
    event.keycode=KEY_E if id=="l3_action" else KEY_Q
    event.physical_keycode=event.keycode
    event.pressed=pressed
    root.push_input(event,true)

func _run() -> void:
    root.size=Vector2i(1280,720)
    game=load("res://scenes/level3_store.tscn").instantiate()
    root.add_child(game);current_scene=game
    await tick(8)
    if not check(game.navigation.ready,"navigation did not synchronize"): quit(1);return
    for enemy in game._enemies: enemy.set_physics_process(false)
    check(game._enemies_alive==10,"guard roster incorrect")
    check(game._is_spawn_clear(game.player.global_position),"player spawn blocked")
    for enemy in game._enemies: check(game._is_spawn_clear(enemy.global_position),"guard spawn blocked: "+str(enemy.name))
    for pickup in game.pickups_root.get_children():
        check(game._is_spawn_clear(pickup.global_position),"pickup blocked: "+str(pickup.name))
        check(game.navigation.path(game.player.global_position,pickup.global_position).size()>0,"unreachable supply: "+str(pickup.name))
    check(game._doors.size()==8,"door count incorrect")
    check(not game.world_renderer.visible,"fallback hides the real floor")
    var shape := CircleShape2D.new();shape.radius=7.0
    var query := PhysicsShapeQueryParameters2D.new()
    query.shape=shape;query.collision_mask=1;query.collide_with_areas=false
    var excluded: Array[RID] = []
    for door in game._doors: excluded.append(door.pivot.get_rid())
    query.exclude=excluded
    var checked := 0
    var grid: AStarGrid2D = game.navigation.grid
    for y in range(grid.region.size.y):
        for x in range(grid.region.size.x):
            var id := Vector2i(x,y)
            if grid.is_point_solid(id): continue
            for adjacent in [id+Vector2i.RIGHT,id+Vector2i.DOWN]:
                if not grid.region.has_point(adjacent) or grid.is_point_solid(adjacent): continue
                query.transform=Transform2D(0,grid.get_point_position(id))
                query.motion=grid.get_point_position(adjacent)-grid.get_point_position(id)
                var cast := game.get_world_2d().direct_space_state.cast_motion(query)
                check(cast[0]>0.999,"navigation cuts a physical corner at "+str(id))
                checked+=1
    for enemy in game._enemies: check(game.navigation.path(game.player.global_position,enemy.global_position).size()>0,"unreachable guard: "+str(enemy.name))
    check(game.navigation.path(game.player.global_position,game._scaled_cell_world(Level3StoreData.ORDER_CELL)).size()>0,"unreachable order")
    # Door width, passage and occupancy are tested against the actual body.
    var door: Level3Door=game._doors[0]
    var center := door.global_position
    query.exclude=[];query.transform=Transform2D(0,center);query.motion=Vector2.ZERO
    check(not game.get_world_2d().direct_space_state.intersect_shape(query,1).is_empty(),"closed door has no physical leaf")
    door.interact(center+Vector2.DOWN.rotated(door.global_rotation)*24)
    await tick(16)
    check(door.is_open and door.body_shape.disabled,"door does not open")
    query.transform=Transform2D(0,center)
    check(game.get_world_2d().direct_space_state.intersect_shape(query,1).is_empty(),"open doorway remains obstructed")
    var original := game.player.global_position
    game.player.global_position=center
    game.player.set_physics_process(false)
    door._close_timer=0.02
    await tick(55)
    check(door.body_shape.disabled,"door became solid under player")
    game.player.global_position=original
    game.player.set_physics_process(true)
    # Landscape viewport sizes must keep every simultaneous touch role usable.
    for viewport_size in [Vector2i(960,540),Vector2i(1600,720),Vector2i(1280,720)]:
        root.size=viewport_size
        await process_frame
        game.hud.mobile_active=true
        game.hud._layout()
        var screen := game.get_viewport().get_visible_rect()
        for control in game.hud._game_buttons()+[game.move_joystick,game.aim_joystick]:
            check(screen.encloses(control.get_global_rect()),"touch control outside viewport: "+str(viewport_size))
        check(not game.fire_button.get_global_rect().intersects(game.aim_joystick.get_global_rect()),"FIRE overlaps aim at "+str(viewport_size))
        check(not game.action_button.get_global_rect().intersects(game.aim_joystick.get_global_rect()),"ACTION overlaps aim at "+str(viewport_size))
    # Real three-finger UI routing, global release, foreign-ID release, cancel,
    # focus pause and continuation without stored movement or fire.
    game.hud.mobile_active=true;game.hud._layout()
    var move := game.move_joystick.get_global_rect().get_center()
    var aim := game.aim_joystick.get_global_rect().get_center()
    var fire := game.fire_button.get_global_rect().get_center()
    var ammo := game.player.ammo
    touch(11,move+Vector2(45,0),true)
    touch(12,aim+Vector2(50,0),true)
    await tick(7)
    check(game.player.global_position.x>original.x+3,"touch movement did not reach player")
    check(game.player.ammo==ammo,"movement/aim touch fired through mouse emulation")
    touch(13,fire,true)
    await tick(20)
    check(game.player.ammo<ammo,"independent FIRE touch failed")
    touch(99,Vector2.ZERO,false)
    check(game._fire_held,"foreign touch released another finger")
    drag(13,Vector2(-40,-40))
    check(not game._fire_held,"FIRE remained latched outside the control")
    touch(11,Vector2(-60,-60),false,true)
    check(game._mobile_move==Vector2.ZERO,"canceled movement was retained")
    touch(13,fire,true)
    touch(11,move+Vector2(45,0),true)
    game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
    await process_frame
    check(paused,"focus loss did not pause")
    check(game.hud._touches.is_empty() and not game._fire_held and game._mobile_move==Vector2.ZERO,"focus loss retained touch state")
    root.get_node("PauseManager").resume()
    var resumed_ammo := game.player.ammo
    var resumed_position := game.player.global_position
    await tick(15)
    check(game.player.ammo==resumed_ammo and game.player.global_position.distance_to(resumed_position)<0.1,"phantom movement/fire after resume")
    # Fixed-tick edge acknowledgement must prevent repeated ACTION emissions.
    var count := [0]
    game.player.action_requested.connect(func(): count[0]+=1)
    action("l3_action",true);action("l3_action",false)
    await tick(12)
    check(count[0]==1,"ACTION was repeated or dropped between render and physics")
    # Swept enemy bullets: hit once, dodged shot continues, wall blocks it.
    game.clear_inputs();game.player.global_position=Vector2(200,688)
    game._spawn_enemy_projectile(Vector2(285,688),Vector2(80,688))
    await tick(32)
    check(game.player.health==92,"swept bullet did not apply exactly one hit")
    game.player.global_position=Vector2(200,688)
    game._spawn_enemy_projectile(Vector2(285,688),Vector2(80,688))
    game.player.global_position=Vector2(200,722)
    await tick(36)
    check(game.player.health==92,"snapshot shot followed a dodging player")
    game.player.global_position=Vector2(200,688)
    game._spawn_enemy_projectile(Vector2(200,540),Vector2(200,720))
    await tick(40)
    check(game.player.health==92,"bullet crossed a real wall")
    var children := game.get_child_count()
    for i in range(200): game.effects.trace(Vector2(180,680),Vector2(200,680),Color.WHITE)
    check(game.get_child_count()==children and game.effects.active_count()<=96,"combat effects allocate unbounded nodes")
    game.player.take_damage(200)
    await process_frame
    check(game._player_dead and game.hud._overlay.visible and not game.player.controls_enabled,"defeat UI/input contract failed")
    check(Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"defeat has no usable desktop cursor")
    root.get_node("PauseManager").resume()
    game.queue_free()
    await process_frame;await process_frame;await process_frame
    await Teardown.drain_audio(self)
    if _failed: quit(1)
    else:
        print("LEVEL 3 SMOKE TEST: PASS — ",checked," physical navigation edges; 8 doors; 3 landscape sizes; three-finger input/cancel/focus; single ACTION; swept hit/dodge/wall; bounded effects; defeat")
        quit(0)
