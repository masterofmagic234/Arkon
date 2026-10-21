extends SceneTree
# Spatial behavior, rather than a screenshot of a plausible floor plan:
# both branches reachable independently, two-key finale, usable shortcuts,
# and real capsule clearance on the published production navigation paths.
const Data=preload("res://scripts/level_data.gd")
const Teardown=preload("res://tools/level3_test_teardown.gd")
var game: Node3D
var failed:=false
func _init() -> void:call_deferred("run")
func check(value: bool,message: String) -> void:
    if not value:failed=true;push_error("LEVEL1 ESTATE: "+message)
func frames(n: int) -> void:
    for i in range(n):await physics_frame
func nav_ready() -> void:
    var deadline:=Time.get_ticks_msec()+15000
    while Time.get_ticks_msec()<deadline:
        if game.level1_navigation.navigation_ready:return
        OS.delay_msec(1);await physics_frame
    check(false,"navigation publication timed out")
func path(a: Vector2i,b: Vector2i) -> PackedVector3Array:
    return NavigationServer3D.map_get_path(game.get_world_3d().navigation_map,Data.cell_center_world(a),Data.cell_center_world(b),true)
func reaches(a: Vector2i,b: Vector2i) -> bool:
    var points:=path(a,b)
    return not points.is_empty() and points[-1].distance_to(Data.cell_center_world(b))<.15
func length_(points: PackedVector3Array) -> float:
    var total:=0.0
    for i in range(1,points.size()):total+=points[i].distance_to(points[i-1])
    return total
func clear_path(a: Vector2i,b: Vector2i) -> void:
    var points:=path(a,b)
    check(not points.is_empty() and points[-1].distance_to(Data.cell_center_world(b))<.15,"route ends on an unreachable partial path: %s -> %s"%[a,b])
    var capsule:=CapsuleShape3D.new();capsule.radius=.28;capsule.height=1.2
    var sweep:=PhysicsShapeQueryParameters3D.new();sweep.shape=capsule;sweep.collision_mask=1
    for i in range(1,points.size()):
        sweep.transform=Transform3D(Basis.IDENTITY,Vector3(points[i-1].x,.9,points[i-1].z))
        sweep.motion=points[i]-points[i-1]
        var hit:=game.get_world_3d().direct_space_state.cast_motion(sweep)
        if hit[0]<.999:
            check(false,"capsule strikes scenery on %s -> %s: %s -> %s"%[a,b,points[i-1],points[i]])
            return
func collect_key(id: String) -> void:
    game.player.position=game.get_node(id).position+Vector3.UP*.3
    await frames(5)
    check(not game.has_node(id),"physical key pickup failed: "+id)
func use_device(id: String) -> void:
    var device: Node3D=game.heist.get_node(id)
    game.player.position=device.position+Vector3(0,.9,1.8);game.player.rotation=Vector3.ZERO
    game.camera.look_at(game.heist.interaction_point(device))
    await frames(2)
    check(game.heist.request_interact(),"local command rejected: "+id)
func run() -> void:
    root.get_node("GameState").sfx_muted=true;root.get_node("GameState").music_muted=true
    game=load("res://game.tscn").instantiate();root.add_child(game);current_scene=game
    await frames(12)
    game.encounters.set_physics_process(false)
    for enemy in get_nodes_in_group("level1_enemy"):enemy.set_physics_process(false)
    await nav_ready()
    var start: Vector2i=Data.PARK_CELLS.Player
    clear_path(start,Data.PARK_CELLS.Key01)
    for approach in Data.GATE_APPROACH.slice(0,2):clear_path(start,approach)
    check(not reaches(start,Data.PARK_CELLS.Key02) and not reaches(start,Data.PARK_CELLS.Key03),"locked wings are bypassable")
    await collect_key("Key01")
    for i in range(2):
        game.player.position=Data.cell_center_world(Data.GATE_APPROACH[i])+Vector3.UP*.9
        await frames(45);await nav_ready()
        check(game.get_node("Level1Layout/Doors/Door%02d"%(i+1)).is_open,"gardener's key does not open either branch")
    clear_path(start,Data.PARK_CELLS.Key02);clear_path(start,Data.PARK_CELLS.Key03)
    check(not game.heist.moon_solved and not game.heist.gallery_disabled,"branch availability depends on completing the other branch")
    check(not reaches(start,Data.PARK_CELLS.Acorn06),"the finale can be entered before both branch keys")
    await collect_key("Key03")
    game.player.position=Data.cell_center_world(Data.GATE_APPROACH[2])+Vector3.UP*.9
    await frames(45)
    check(not game.get_node("Level1Layout/Doors/Door03").is_open,"gallery key alone opens the two-key finale")
    await collect_key("Key02")
    game.player.position=Data.cell_center_world(Data.GATE_APPROACH[2])+Vector3.UP*.9
    await frames(45);await nav_ready()
    check(game.get_node("Level1Layout/Doors/Door03").is_open,"second branch key does not release the final gate")
    var moon_a:=Vector2i(34,27);var moon_b:=Vector2i(27,42)
    var moon_before:=length_(path(moon_a,moon_b))
    var return_a:=Vector2i(60,45);var return_b:=Vector2i(30,47)
    var return_before:=length_(path(return_a,return_b))
    await use_device("GalleryRelay");await frames(130)
    check(game.heist.gallery_disabled,"actual gallery sabotage failed")
    for id in ["MoonDial1","MoonDial2","MoonDial2","MoonDial3"]:await use_device(id)
    await frames(45);await nav_ready()
    check(game.heist.moon_solved and game.get_node("Level1Layout/Doors/MoonWicket").is_open and game.get_node("Level1Layout/Doors/NorthWicket").is_open,"lenses do not physically open both looping connections")
    var moon_after:=length_(path(moon_a,moon_b))
    check(moon_after>0 and moon_after<moon_before*.75,"moon shortcut does not shorten actual navigation")
    clear_path(moon_a,moon_b)
    await use_device("OakSeal");await frames(235);await nav_ready()
    check(game.heist.oak_open and game.get_node("Level1Layout/Doors/ReturnGate").is_open,"oak seal does not release the actual return bridge")
    var return_after:=length_(path(return_a,return_b))
    check(return_after>0 and return_after<return_before*.70,"return bridge does not shorten the actual escape")
    clear_path(return_a,return_b)
    for route in [[Vector2i(13,24),Vector2i(14,15)],[Vector2i(31,26),Vector2i(30,15)],[Vector2i(54,18),Vector2i(74,23)],[Vector2i(81,17),Vector2i(81,24)],[Vector2i(60,44),Vector2i(72,50)]]:clear_path(route[0],route[1])
    check(get_nodes_in_group("level1_enemy").size()==14,"encounters create new guards")
    check(game.get_node("Level1Environment").find_children("*","OmniLight3D",true,false).size()<=18,"estate adds excessive local lights")
    check(game.find_children("*","SubViewport",true,false).is_empty(),"estate allocates another render target")
    print("ESTATE SPATIAL: two independent branches; final keys accepted in reverse order; moon shortcut %.1f -> %.1fm; return %.1f -> %.1fm; capsule-clear flanks"%[moon_before,moon_after,return_before,return_after])
    game.queue_free();current_scene=null;await frames(4);await Teardown.drain_audio(self)
    if failed:quit(1)
    else:print("LEVEL1 ESTATE: PASS");quit(0)
