extends SceneTree
## Isolated production-body regressions: real input dodge, world sweeps and
## weapon hits. Fixture placement is explicit; no live actor health/progress
## overrides are used. Full garden mission input is tested separately.
const Teardown=preload("res://tools/level3_test_teardown.gd")
var Guard:Script
var Player:PackedScene
var failures:Array[String]=[]
var report:Dictionary={"scope":"Isolated real CharacterBody3D/controller fixtures; quest-order unit fixture is explicitly separate from combat."}
var output:="user://ai152"
var visual:=false
var fixture:Fixture

class Fixture extends Node3D:
    var player:Node3D
    var stage:="cache"

class QuestProgress extends RefCounted:
    var installed:=false
    var reward:=false
    var encounters_completed:Array[String]=[]

class QuestGuard extends RefCounted:
    var defeated:=true
    var encounter_active:=false
    func activate_encounter(_point:Vector3) -> void:encounter_active=true

class QuestFixture extends Node3D:
    var progress:=QuestProgress.new()
    var player:=Node3D.new()
    var guards:Array=[]
    var completed:Array[String]=[]
    func gallery_approach_reached() -> bool:return false
    func on_encounter_completed(id:String) -> void:completed.append(id)

func _init() -> void:
    for arg in OS.get_cmdline_user_args():
        if arg=="--visual":visual=true
        elif arg.begins_with("--output="):output=arg.trim_prefix("--output=")
    call_deferred("run")

func check(ok:bool,why:String) -> void:
    if not ok:failures.append(why);push_error("BOTANICAL AI152: "+why)

func frames(count:int) -> void:
    for i in range(count):await physics_frame

func run() -> void:
    Guard=load("res://scripts/woodland_guard.gd")
    Player=load("res://scenes/level1_player.tscn")
    root.get_node("GameState").sfx_muted=true
    root.get_node("GameState").music_muted=true
    root.size=Vector2i(1280,720)
    DirAccess.make_dir_recursive_absolute(output)
    await reserve_patrol_and_contact()
    quest_completion_order()
    var cases:Array=[]
    for item in [
        ["straight-thin-wall",Vector3(0,0,1),"square"],
        ["oblique-wall",Vector3(.33,0,1).normalized(),"square"],
        ["inner-corner",Vector3(1,0,1).normalized(),"square"],
        ["glancing-side-wall",Vector3(1,0,.25).normalized(),"square"],
        ["side-wall",Vector3(1,0,0),"square"],
        ["opposite-oblique",Vector3(-.6,0,1).normalized(),"square"],
        ["round-pillar",Vector3(0,0,1),"pillar"],
        ["window-sill-and-glass",Vector3(0,0,1),"window"],
        ["initial-thin-window-overlap",Vector3(0,0,1),"overlap-window"],
        ["initial-round-pillar-overlap",Vector3(0,0,1),"overlap-pillar"],
    ]:
        cases.append(await charge_case(item[0],item[1],item[2]))
    report.charge_cases=cases
    report.failures=failures
    report.source_hashes={}
    for p in ["res://scripts/woodland_guard.gd","res://scripts/botanical_encounter_director.gd","res://tools/botanical_ai152_test.gd"]:
        report.source_hashes[p.trim_prefix("res://")]=FileAccess.get_sha256(p)
    await Teardown.drain_audio(self)
    FileAccess.open(output.path_join("ai152-report.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    if failures.is_empty():print("BOTANICAL AI152: PASS — passive reserve patrol/contact, earned objective order, ten swept guardian wall/corner/pillar contacts including staged initial overlaps, supported physical disengagement and real recovery hits")
    quit(0 if failures.is_empty() else 1)

func make_fixture(player_at:Vector3) -> void:
    root.get_node("GameState").start_new_run()
    fixture=Fixture.new();root.add_child(fixture);current_scene=fixture
    solid(Vector3(0,-.1,0),Vector3(80,.2,80),"Floor")
    fixture.player=Player.instantiate();fixture.player.position=player_at
    fixture.add_child(fixture.player)

func solid(at:Vector3,size_:Vector3,name_:String) -> StaticBody3D:
    var body:=StaticBody3D.new();body.name=name_;body.position=at;body.collision_layer=1;body.collision_mask=0
    var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=size_;shape.shape=box
    body.add_child(shape);fixture.add_child(body);return body

func dispose_fixture() -> void:
    for action in ["l1_move_forward","l1_move_right","l1_move_left","l1_move_backward"]:Input.action_release(action)
    fixture.player.stop();current_scene=null;fixture.queue_free();await frames(4)

func reserve_patrol_and_contact() -> void:
    make_fixture(Vector3(0,.875,25));fixture.stage="garden"
    var actor=Guard.new();actor.director=fixture;actor.encounter_active=false
    actor.patrol_points.assign([Vector3(-2,.05,0),Vector3(2,.05,0),Vector3(2,.05,2)])
    fixture.add_child(actor)
    fixture.player.camera.look_at(Vector3(0,1,0))
    await frames(180)
    check(not actor.encounter_active and actor.state=="patrol","uncontacted reserve must patrol without activating the mission encounter")
    check(actor._distance_walked>2 and Vector2(actor.position.x,actor.position.z).length()<4,"uncontacted visible reserve stood AFK or left its local post")
    var before:Vector3=actor.position
    var walked:float=actor._distance_walked
    Input.action_press("l1_move_forward")
    for i in range(300):
        await physics_frame
        if actor.encounter_active:break
    Input.action_release("l1_move_forward")
    check(actor.encounter_active and actor._memory>0,"reserve ignored actual player approach and unobstructed sight")
    report.reserve={"walked_before_contact":walked,"position_before_contact":before,"player_contact_position":fixture.player.position,"active_after_real_input_approach":actor.encounter_active,"state_after_contact":actor.state}
    await dispose_fixture()

func quest_completion_order() -> void:
    var q:=QuestFixture.new();q.player.position=Vector3(80,0,70)
    for i in range(25):q.guards.append(QuestGuard.new())
    root.add_child(q);q.add_child(q.player)
    var encounters=load("res://scripts/botanical_encounter_director.gd").new()
    q.add_child(encounters);encounters.director=q
    encounters.trigger("pump");encounters.trigger("gallery");encounters.trigger("escape")
    encounters.update(.2);encounters.update(.2)
    check(not encounters.is_complete("pump") and not encounters.is_complete("gallery") and not encounters.is_complete("escape"),"early contact/clear awarded unearned pump, key or escape step")
    check(not q.completed.has("pump") and not q.completed.has("gallery"),"early reserve defeat invoked mission checkpoint/key callback")
    q.progress.installed=true;encounters.update(.2)
    check(encounters.is_complete("pump") and encounters.is_complete("gallery") and not encounters.is_complete("escape"),"physical installation did not release legitimately cleared pump/gallery or bypassed reward")
    q.progress.reward=true;encounters.update(.2)
    check(encounters.is_complete("escape"),"earned reward did not release cleared departure encounter")
    report.quest_order={"scope":"Explicit cleared-group unit setup, not claimed combat.","completed_callbacks":q.completed,"installation_required":true,"reward_required":true}
    q.queue_free()

func wait_state(actor:Node,name_:String,limit:int) -> bool:
    for i in range(limit):
        if actor.state==name_:return true
        await physics_frame
    check(false,"guardian did not enter "+name_+" (actual "+str(actor.state)+")")
    return false

func charge_case(name_:String,direction:Vector3,kind:String) -> Dictionary:
    make_fixture(direction*3+Vector3.UP*.875)
    fixture.player.look_at(Vector3(0,fixture.player.position.y,0))
    fixture.player.camera.look_at(Vector3.UP)
    if kind=="square":
        solid(Vector3(0,1.5,5),Vector3(12,3,.08),"FrontWall")
        solid(Vector3(5,1.5,0),Vector3(.08,3,12),"RightWall")
        solid(Vector3(-5,1.5,0),Vector3(.08,3,12),"LeftWall")
        solid(Vector3(0,1.5,-5),Vector3(12,3,.08),"RearWall")
    elif kind=="pillar":
        var pillar:=StaticBody3D.new();pillar.name="RoundPillar";pillar.position=direction*5+Vector3(.25,1.5,0)
        var cs:=CollisionShape3D.new();var cylinder:=CylinderShape3D.new();cylinder.radius=.45;cylinder.height=3;cs.shape=cylinder;pillar.add_child(cs);fixture.add_child(pillar)
    elif kind=="window":
        solid(Vector3(0,.09,4.3),Vector3(7,.18,.6),"WindowSill")
        solid(Vector3(0,1.65,4.55),Vector3(7,3,.025),"ThinWindowGlass")
    var actor=Guard.new();actor.director=fixture;actor.is_tank=true;actor.final_boss=true;fixture.add_child(actor)
    await frames(4)
    var ready:=await wait_state(actor,"windup",150)
    if not ready:await dispose_fixture();return {"case":name_,"failed_to_start":true}
    var locked:Vector3=actor._charge_direction
    var first_attack:int=actor._attack_count
    Input.action_press("l1_move_right");await frames(52);Input.action_release("l1_move_right")
    check(actor._charge_direction.is_equal_approx(locked),name_+": charge retargeted after tell")
    var staged_overlap:=false
    var staged_start:=Vector3.ZERO
    var staged_depth:=0.0
    if kind.begins_with("overlap-"):
        # Register a shallow existing overlap after the tell, while this
        # isolated actor is paused. This explicitly tests collision recovery;
        # ordinary movement cannot otherwise create the forbidden start pose.
        await wait_state(actor,"charge",10)
        actor.set_physics_process(false)
        staged_start=actor.position
        var blocker:=StaticBody3D.new();blocker.name="StagedInitialOverlap";var cs:=CollisionShape3D.new()
        blocker.position=staged_start
        if kind=="overlap-window":
            staged_depth=actor.body_shape.shape.radius-.56
            var plane:=ConcavePolygonShape3D.new();plane.backface_collision=true
            plane.set_faces(PackedVector3Array([Vector3(-.5,0,.56),Vector3(.5,0,.56),Vector3(-.5,3,.56),Vector3(.5,0,.56),Vector3(.5,3,.56),Vector3(-.5,3,.56)]));cs.shape=plane
        else:
            staged_depth=actor.body_shape.shape.radius+.45-1.01
            var cylinder:=CylinderShape3D.new();cylinder.radius=.45;cylinder.height=3;cs.shape=cylinder;cs.position=Vector3(0,1.5,1.01)
        blocker.add_child(cs);fixture.add_child(blocker);await frames(2)
        var q:=PhysicsShapeQueryParameters3D.new();q.shape=actor.body_shape.shape;q.transform=actor.body_shape.global_transform;q.collision_mask=1;q.exclude=[actor.get_rid()]
        for hit:Dictionary in fixture.get_world_3d().direct_space_state.intersect_shape(q,8):
            if hit.collider==blocker:staged_overlap=true
        check(staged_overlap,name_+": intentional existing overlap was not actually present")
        check(absf(staged_depth-.02)<.00001,name_+": staged overlap was not the declared shallow depth")
        var sweep:Dictionary=actor._charge_wall_sweep(locked/6.0)
        check(sweep.blocked,name_+": initial recovery contact was omitted from charge sweep")
        actor.set_physics_process(true)
    var recovered:=await wait_state(actor,"recover",160)
    var contact:Vector3=actor.position
    check(recovered and actor._charge_wall_stops>0,name_+": announced charge did not stop on actual solid geometry")
    check(fixture.player.get_hp()==100,name_+": input dodge did not clear the locked charge line")
    if staged_overlap:check((contact-staged_start).dot(locked)<.08,name_+": initial overlap was resolved through to the opposite side of its obstacle")
    if kind=="square":check(minf(4.96-absf(contact.x),4.96-absf(contact.z))<.8,name_+": charge stopped on another actor rather than its wall fixture")
    await frames(22)
    var after:Vector3=actor.position
    check(actor._charge_backoff_metres>.12,name_+": blocked guardian never physically disengaged")
    var query:=PhysicsShapeQueryParameters3D.new();query.shape=actor.body_shape.shape
    query.transform=actor.body_shape.global_transform;query.transform.origin+=Vector3.UP*.21
    query.margin=.025;query.collision_mask=1;query.exclude=[actor.get_rid()]
    var overlaps:=fixture.get_world_3d().direct_space_state.intersect_shape(query,8)
    check(overlaps.is_empty(),name_+": guardian remained inside world/query clearance after backoff")
    check(absf(actor.position.y)<.25,name_+": charge climbed or fell through the arena floor")
    var hp_before:int=actor.hp
    fixture.player.camera.look_at(actor.global_position+Vector3.UP*1.1)
    fixture.player.request_fire();await frames(3)
    check(actor.hp==hp_before-1,name_+": real weapon could not hit the recovery opening")
    await wait_state(actor,"windup",300)
    check(actor._attack_count>first_attack,name_+": guardian stalled instead of starting another playable attack")
    var row={"case":name_,"charge_direction":locked,"contact":contact,"after_backoff":after,"backoff_metres":actor._charge_backoff_metres,"wall_stops":actor._charge_wall_stops,"world_overlaps_after_backoff":overlaps.size(),"recovery_real_hit":actor.hp==hp_before-1,"next_attack_count":actor._attack_count,"player_hp":fixture.player.get_hp(),"staged_initial_overlap":staged_overlap,"overlap_initial_position":staged_start,"staged_depth_metres":staged_depth,"original_side_preserved":not staged_overlap or (contact-staged_start).dot(locked)<.08}
    if visual:
        var camera:=Camera3D.new();fixture.add_child(camera);camera.position=Vector3(-8,6,10);camera.look_at(actor.position+Vector3.UP);camera.current=true
        for i in range(3):await process_frame;RenderingServer.force_draw(true)
        root.get_texture().get_image().save_png(output.path_join(name_+".png"))
    await dispose_fixture()
    return row
