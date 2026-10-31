extends SceneTree
const Data=preload("res://scripts/race_level_data.gd")
const Math=preload("res://scripts/race_math.gd")
const Car=preload("res://scripts/race_car_controller.gd")
const Body=preload("res://scripts/race_encounter_body.gd")
const Director=preload("res://scripts/race_encounters.gd")
const Contacts=preload("res://scripts/race_vehicle_contacts.gd")
const Controller=preload("res://scripts/race_controller.gd")
const State=preload("res://scripts/race_state.gd")
var failed:=false
var flat:=PackedFloat32Array()
var straight: Array=[]
func _init() -> void:call_deferred("run")
func check(ok: bool,why: String) -> void:
    if not ok:failed=true;push_error("LEVEL2 ENCOUNTERS: "+why)
func player(z: float,x: float,speed_: float):
    var car:=Car.new();car.setup(true);car.place_on_grid(0,x,flat)
    car.segment_index=floori(z/40);car.segment_progress=z/40-floor(z/40)
    car.world_z=z;car.world_x=x;car.lateral_offset=x;car.speed=speed_
    return car
func run() -> void:
    flat.resize(222);flat.fill(0);straight.resize(222);straight.fill(0)
    var director:=Director.new();director.setup(straight,flat)
    check(director.traffic.size()==6,"civilian pool is missing")
    var traffic=director.traffic[0]
    var before: float=traffic.world_z
    traffic.tick(.1,straight,flat)
    check(traffic.world_z<before and traffic.contact_velocity().y<0 and absf(wrapf(traffic.heading_yaw-PI,-PI,PI))<.01,"oncoming car is moving toward the city instead of toward Carolina")
    check(traffic.lateral_offset<-1.5 and traffic.lateral_offset> -3.4,"oncoming car does not stay in its opposing lane")
    # At this step the player and an oncoming car cross completely. Swept SAT
    # must stop them on their original sides, with signed closing momentum.
    var p=player(114,-2.5,65);var opposite:=Body.new();opposite.place(96,-2.5,flat);opposite.velocity=Vector2(0,-30)
    var pairs:=Contacts.solve([p,opposite],[Vector2(-2.5,100),Vector2(-2.5,110)],straight,flat)
    check(not pairs.is_empty() and p.world_z<opposite.world_z,"head-on crossing tunnels through")
    check(p.speed<40,"head-on contact ignores opposing velocity")
    check(Contacts.contact(p,opposite,Vector2(p.world_x,p.world_z),Vector2(opposite.world_x,opposite.world_z),false).length()<.002,"head-on contact leaves intersecting cars")
    # A neighboring real lane remains traversable.
    p=player(114,2.5,65);opposite.place(96,-2.5,flat)
    pairs=Contacts.solve([p,opposite],[Vector2(2.5,100),Vector2(-2.5,110)],straight,flat)
    check(pairs.is_empty() and p.world_z==114,"collision extends across the clear lane")
    var actual_track:=Math.accumulate_track_x(Data.get_track_pattern())
    director.setup(Data.get_track_pattern(),actual_track)
    check(director.roadblocks.size()>=3,"fewer than three authored safe roadblocks")
    for block in director.roadblocks:
        check(Director.safe_roadblock(block.z,actual_track),"roadblock is hidden in tunnel/bridge/tight corner")
        director._build_block(block)
        check(block.cars.size()==2 and block.gap_width>=3.1,"roadblock lost its readable drive-through gap")
        check(not director.air_attack_clear(player(block.z-600,0,60),block.z),"helicopter can cover the roadblock's only gap with spikes")
    # Full swept passage through both gap positions; full contact against a
    # parked car. This uses the same production body footprints/masses.
    director.setup(straight,flat)
    for block in director.roadblocks:
        director._build_block(block)
        var z: float=block.z
        p=player(z+14,block.gap_center,65)
        var bodies: Array=[p];var previous: Array[Vector2]=[Vector2(block.gap_center,z-14)]
        for car in block.cars:bodies.append(car);previous.append(Vector2(car.world_x,car.world_z))
        pairs=Contacts.solve(bodies,previous,straight,flat)
        check(pairs.is_empty(),"body-width roadblock escape gap collides")
        var blocker=block.cars[0]
        p=player(z+14,blocker.world_x,65)
        pairs=Contacts.solve([p,blocker],[Vector2(p.world_x,z-14),Vector2(blocker.world_x,z)],straight,flat)
        check(not pairs.is_empty() and p.world_z<blocker.world_z,"solid parked roadblock is pass-through")
        check(p.speed<30,"roadblock contact has no physical speed consequence")
    # Civilian drivers must not meet the player head-on in the roadblock's
    # sole advertised opening. They physically slow onto the outer shoulder.
    director.setup(straight,flat)
    var queue_state:=State.new();queue_state.race_started=true;queue_state.race_time=30
    var radio=preload("res://scripts/race_radio.gd").new()
    var queued_block: Dictionary=director.roadblocks[1]
    p=player(queued_block.z-150,queued_block.gap_center,55)
    var civilian=director.traffic[0];civilian.place(queued_block.z+150,-2.45,flat)
    for step in range(40):director.prepare(.1,queue_state,p,[],radio)
    check(civilian.lateral_offset< -4.8 and civilian.world_z>queued_block.z+29,"civilian traffic blocks the required roadblock opening")
    check(civilian.desired_speed<civilian.cruise_speed,"civilian never brakes for the parked police line")
    # Countdown/pause/finished state do not advance ambient traffic.
    var state:=State.new();var controller:=Controller.new()
    controller.setup(root,null,[],null,null,null,null,null,state,Callable());controller.start()
    traffic=controller.pursuit.encounters.traffic[0];before=traffic.world_z
    controller.update(.25)
    check(traffic.world_z==before,"countdown consumes oncoming traffic")
    state.race_started=true
    controller.update(.016)
    check(traffic.world_z<before,"active race never advances traffic")
    controller.fail()
    check(controller.pursuit.encounters.active_bodies().is_empty(),"failure leaves encounter bodies running")
    controller.teardown()
    if failed:quit(1)
    else:print("LEVEL2 ENCOUNTERS: PASS — signed oncoming traffic, swept head-on/clear-lane contacts, safe physical roadblocks/open gaps, air-attack separation and lifecycle");quit(0)
