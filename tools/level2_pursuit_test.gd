extends SceneTree
const Data=preload("res://scripts/race_level_data.gd")
const Math=preload("res://scripts/race_math.gd")
const State=preload("res://scripts/race_state.gd")
const Controller=preload("res://scripts/race_controller.gd")
const Pursuit=preload("res://scripts/race_pursuit.gd")
const Car=preload("res://scripts/race_car_controller.gd")
var failed := false
func _init() -> void: call_deferred("_run")
func check(ok: bool,message: String) -> void:
    if not ok: failed=true;push_error("LEVEL2 PURSUIT: "+message)
func _run() -> void:
    _batching_geometry()
    var state:=State.new();var c:=Controller.new()
    c.setup(root,null,[],null,null,null,null,null,state,Callable());c.start()
    var p=c.player;var d=c.pursuit
    for i in range(120): c.update(1.0/60)
    check(d.clock==0 and d.strips.is_empty(),"air unit attacks during countdown")
    check(not Pursuit.safe_drop_zone(Data.TUNNEL_START+200,c.track_x),"spikes allowed inside the tunnel")
    check(not Pursuit.safe_drop_zone(Data.route_length()-50,c.track_x),"spikes allowed beyond escape point")
    var z := 0.0
    for at in range(600,2400,20):
        if Pursuit.safe_drop_zone(at,c.track_x): z=at;break
    check(z>0,"no open attack sector")
    state.race_started=true;state.race_time=20
    _put(p,z-230,0,c);p.speed=50
    d._begin(p,z,c.track_x)
    var locked: Dictionary=d.strips[0].duplicate()
    var gap: float=-signf(float(locked.offset))*2.8
    check(float(locked.width)<=5.2 and Data.ROAD_WIDTH-float(locked.width)>3.5,"no full-width escape corridor")
    check(not d.warning_text(p).is_empty(),"attack is not announced")
    _put(p,z-230,gap,c)
    for i in range(ceili(d.flight.duration*60)-1): d.prepare(1.0/60,state,p,[]);d.tick(1.0/60,state,p,[],c.track_x)
    check(not d.strips[0].armed and d.spike_hits==0,"warning punctures tires before deployment")
    check(d.strips[0].offset==locked.offset,"helicopter retargets after the warning")
    for i in range(48): d.prepare(1.0/60,state,p,[]);d.tick(1.0/60,state,p,[],c.track_x)
    check(d.drops==1 and d.strips[0].armed,"falling strip did not land")
    # Both tires clear the live rack using the announced road corridor.
    _put(p,z-6,gap,c);d.prepare(.016,state,p,[]);_put(p,z+6,gap,c)
    d.tick(.016,state,p,[],c.track_x)
    check(p.puncture_remaining==0 and d.spike_hits==0,"safe corridor still punctures tires")
    # A fast crossing cannot tunnel through the deployed spikes.
    _put(p,z-6,float(locked.offset),c);p.speed=55
    d.prepare(.016,state,p,[]);_put(p,z+6,float(locked.offset),c)
    d.tick(.016,state,p,[],c.track_x)
    check(d.spike_hits==1 and p.puncture_remaining>3 and p.speed>10 and p.speed<40,"swept spike hit is missing or stops the car")
    d.tick(.016,state,p,[],c.track_x)
    check(d.spike_hits==1,"one strip repeatedly damages the same wheels")
    # The same armed rack affects a pursuer, rather than granting immunity.
    var other=c.ais[0].car
    _put(other,z-6,float(locked.offset),c);other.speed=50
    d.prepare(.016,state,p,[c.ais[0]]);_put(other,z+6,float(locked.offset),c)
    d.tick(.016,state,p,[c.ais[0]],c.track_x)
    check(other.puncture_remaining>3,"enemy cars are immune to their own spikes")
    # A real contact produces one bounded shove; distance alone never does.
    d=Pursuit.new();_put(p,1200,0,c);p.speed=40;p.impact_velocity=0
    _put(other,1200,1.6,c);other.speed=40;other.impact_velocity=0
    d.prepare(.016,state,p,[c.ais[0]]);d.tick(.016,state,p,[c.ais[0]],c.track_x)
    check(d.ram_hits==1 and p.impact_velocity<0 and other.impact_velocity>0,"side contact does not push the two cars apart")
    check(p.speed>35,"one side hit removes excessive speed")
    for i in range(30): d.prepare(.016,state,p,[c.ais[0]]);d.tick(.016,state,p,[c.ais[0]],c.track_x)
    check(d.ram_hits==1,"resting contact inflicts a new impulse each frame")
    state.race_finished=true
    var stopped: float=d.clock
    d.tick(20,state,p,c.ais,c.track_x)
    check(d.clock==stopped,"finished pursuit continues simulating")
    # Transient tire damage leaves normal input usable and fully recovers.
    var sample:=Car.new();sample.setup(true)
    var flat:=PackedFloat32Array([0,0,0,0]);var pattern: Array=[0,0,0,0]
    sample.place_on_grid(0,0,flat);sample.speed=50;sample.hit_spikes();sample.set_inputs(.055,1,0)
    for i in range(240): sample.tick(1.0/60,true,pattern,flat)
    check(sample.puncture_remaining==0 and sample.world_z>80 and sample.lateral_offset>.1,"puncture locks input or fails to recover")
    c.teardown()
    await _scene_lifecycle()
    if failed: quit(1)
    else: print("LEVEL2 PURSUIT: PASS — telegraph/locked lane; real fall/deployment; swept tire hits/escape corridor; enemy tires; bounded ram; recovery; pause/retry/finish lifecycle; one shared 3D camera");quit(0)
func _put(car,z: float,lane: float,c) -> void:
    var canonical: float=(z+car.grid_world_z_offset)/40
    car.lap=floori(canonical/c.track_pattern.size());car.segment_index=posmod(floori(canonical),c.track_pattern.size());car.segment_progress=canonical-floor(canonical)
    car.world_z=z;car.world_x=Math.track_center_x(z/40,c.track_x)+lane;car.lateral_offset=lane
func _batching_geometry() -> void:
    # Regression: append_from silently omitted the unindexed two-sided fins.
    # Batching must retain their triangles, transformed tips and paint.
    var holder:=Node3D.new();root.add_child(holder)
    var material:=StandardMaterial3D.new();material.albedo_color=Color("ddca8e")
    var tool:=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
    for point: Vector3 in [Vector3.ZERO,Vector3.UP,Vector3.RIGHT,Vector3.RIGHT,Vector3.UP,Vector3.ZERO]: tool.add_vertex(point)
    tool.generate_normals()
    var fin:=MeshInstance3D.new();fin.mesh=tool.commit();fin.material_override=material;fin.position=Vector3(-2,3,4);holder.add_child(fin)
    var box:=MeshInstance3D.new();box.mesh=BoxMesh.new();box.material_override=material;holder.add_child(box)
    var air=preload("res://scripts/race_squirrel_helicopter.gd").new()
    air._batch_static(holder)
    check(holder.get_child_count()==1,"same-paint static parts were not batched")
    var merged: MeshInstance3D=holder.get_child(0)
    var arrays: Array=merged.mesh.surface_get_arrays(0)
    check(arrays[Mesh.ARRAY_INDEX].size()==42,"batching loses unindexed fin triangles")
    check(arrays[Mesh.ARRAY_VERTEX].has(Vector3(-2,4,4)),"batching loses transformed fin tip")
    check(merged.material_override==material,"batching changes the original paint")
    holder.free()
func _scene_lifecycle() -> void:
    root.get_node("GameState").music_muted=true;root.get_node("GameState").sfx_muted=true
    var level=load("res://scenes/level2.tscn").instantiate()
    root.add_child(level);current_scene=level
    for i in range(8): root.get_node("PauseManager").set_paused(false);await process_frame
    level.state.race_started=true;level.state.race_time=20
    var d=level.controller.pursuit
    check(level.car_3d_overlay.helicopter.root!=null,"helicopter did not join the production vehicle world")
    check(level.car_3d_overlay.world_root.find_children("*","Camera3D",true,false).size()==1,"air unit added its own camera")
    check(level.car_3d_overlay.helicopter.mesh_count<=24,"aircraft exceeds its batched geometry submission budget")
    check(level.hud_background.get_node("PosLabel").text=="ПРЕСЛЕДУЮТ","HUD still presents a race ranking")
    level.state.player_progress=level.controller.track_pattern.size()*.5
    level.controller._sync_hud()
    check(level.hud_background.get_node("Lap").text=="50%","escape progress does not reach the HUD")
    var before: float=d.clock
    root.get_node("PauseManager").set_paused(true)
    for i in range(12): await process_frame
    check(d.clock==before,"pause advances the helicopter clock")
    root.get_node("PauseManager").set_paused(false)
    level.set_physics_process(false)
    level.controller.pursuit._begin(level.controller.player,800,level.controller.track_x)
    level.controller.fail()
    check(d.strips.is_empty() and d.phase==&"idle","failure leaves active hazards")
    level.queue_free();current_scene=null
    for i in range(5): await process_frame
    var again=load("res://scenes/level2.tscn").instantiate()
    root.add_child(again);current_scene=again
    check(again.controller.pursuit.drops==0 and again.controller.pursuit.phase==&"idle" and again.controller.player.puncture_remaining==0,"retry inherits air unit or punctured tires")
    again.queue_free();current_scene=null
    for i in range(5): await process_frame
    await preload("res://tools/level3_test_teardown.gd").drain_audio(self)
