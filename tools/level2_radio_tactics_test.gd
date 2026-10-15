extends SceneTree
const Data=preload("res://scripts/race_level_data.gd")
const Math=preload("res://scripts/race_math.gd")
const Contacts=preload("res://scripts/race_vehicle_contacts.gd")
const Car=preload("res://scripts/race_car_controller.gd")
const AI=preload("res://scripts/race_ai_controller.gd")
const State=preload("res://scripts/race_state.gd")
const Controller=preload("res://scripts/race_controller.gd")
const Radio=preload("res://scripts/race_radio.gd")
var failed := false
var flat := PackedFloat32Array()
var straight: Array=[]
func _init() -> void: call_deferred("_run")
func check(ok: bool,message: String) -> void:
    if not ok: failed=true;push_error("RADIO/TACTICS: "+message)
func _run() -> void:
    flat.resize(222);flat.fill(0);straight.resize(222);straight.fill(0)
    _contacts()
    _radio()
    _maneuvers()
    await _audio_lifecycle()
    if failed: quit(1)
    else: print("RADIO/TACTICS: PASS — continuous solid bodies at rest/speed/cooldown/rails; genuine overtake, warning and braking with an escape lane; bounded relevant radio/pilot replies; matching subtitles/audio, mute/volume/pause/exit");quit(0)
func _car(z: float,x: float,speed_: float):
    var car:=Car.new();car.setup(true);car.place_on_grid(0,x,flat)
    _put(car,z,x,flat);car.speed=speed_;return car
func _put(car,z: float,x: float,track: PackedFloat32Array) -> void:
    var phase: float=(z+car.grid_world_z_offset)/40
    car.lap=floori(phase/track.size());car.segment_index=posmod(floori(phase),track.size());car.segment_progress=phase-floor(phase)
    car.world_x=Math.track_center_x(z/40,track)+x;car.world_z=z;car.lateral_offset=x
func _clear(a,b,message: String) -> void:
    var depth := Contacts.contact(a,b,Vector2(a.world_x,a.world_z),Vector2(b.world_x,b.world_z),false).length()
    check(depth<.002,message+" depth=%.4f"%depth)
    check(absf(a.track_phase()*40-a.world_z)<.001 and absf(b.track_phase()*40-b.world_z)<.001,"contact correction disappears from canonical route state")
func _contacts() -> void:
    for speed_ in [0.0,2.0,40.0]:
        var a=_car(100,0,speed_);var b=_car(100,1.4,speed_)
        Contacts.solve([a,b],[Vector2(0,100),Vector2(1.4,100)],straight,flat)
        _clear(a,b,"bodies overlap at speed %.0f"%speed_)
    var a=_car(125,0,70);var b=_car(113,0,0)
    Contacts.solve([a,b],[Vector2(0,100),Vector2(0,112)],straight,flat)
    check(a.world_z<b.world_z and a.speed<69,"fast rear impact tunnels through a stopped car")
    _clear(a,b,"swept rear impact leaves intersecting bodies")
    a=_car(100,0,30);b=_car(100,2.5,30)
    var untouched := Contacts.solve([a,b],[Vector2(0,90),Vector2(2.5,90)],straight,flat)
    check(untouched.is_empty() and a.world_x==0 and b.world_x==2.5,"a real open passing lane collides")
    a=_car(100,1.0,40);b=_car(101,.0,35);a.heading_yaw=.22;b.heading_yaw=-.13
    Contacts.solve([a,b],[Vector2(.8,99),Vector2(.2,100)],straight,flat)
    _clear(a,b,"rotated bodies overlap")
    a=_car(Data.BRIDGE_START+200,-4.5,40);b=_car(a.world_z,-3.2,40)
    Contacts.solve([a,b],[Vector2(a.world_x,a.world_z),Vector2(b.world_x,b.world_z)],straight,flat)
    _clear(a,b,"rail pin leaves bodies overlapping")
    check(a.world_x>=-Data.BRIDGE_RAIL_X+.85-.001,"car contact pushes the player through bridge rail")
    # A sound cooldown is deliberately live during a second crossing.
    var state:=State.new();var c:=Controller.new();c.setup(root,null,[],null,null,null,null,null,state,Callable());c.start()
    state.race_started=true;state.race_time=20
    var p=c.player;var other=c.ais[0].car;var d=c.pursuit
    _put(p,1200,0,c.track_x);_put(other,1210,0,c.track_x);p.speed=60;other.speed=20
    d.prepare(.016,state,p,[c.ais[0]]);_put(p,1220,0,c.track_x);d.tick(.016,state,p,[c.ais[0]],c.track_x)
    var hits: int=d.ram_hits
    _put(p,other.world_z-6,0,c.track_x);d.prepare(.016,state,p,[c.ais[0]])
    _put(p,other.world_z+8,0,c.track_x);d.tick(.016,state,p,[c.ais[0]],c.track_x)
    check(p.world_z<other.world_z and d.ram_hits==hits,"impact cooldown disables the solid body")
    c.teardown()
func _radio() -> void:
    var r:=Radio.new()
    r.say("ambient","БЕЛКА-1","Где мои жёлуди?",0);r.advance(.1)
    r.say("request","БЕЛКА-1","Нужен вертолёт!",0,2)
    r.say("reply","ОРЕХ-1 · ПИЛОТ","Вижу его. Захожу!",2,2)
    r.advance(.2)
    check(r.current.get("key")=="request","tactical radio cannot interrupt idle banter")
    r.advance(6);r.advance(.5)
    check(r.current.get("key")=="reply" and r.current.get("voice")==2,"pilot answer loses exchange order or voice")
    r.stop();r.say("old-ram","БЕЛКА-2","Иду на таран",0,2,.1);r.advance(2)
    check(r.current.is_empty(),"stale ram call plays after the event")
    r.say("orphan","ДУПЛО","Принято",1,1,4,"missing-request");r.advance(.1)
    check(r.current.is_empty(),"a reply plays after its request was discarded")
    for i in range(30): r.say("q%d"%i,"БЕЛКА-2","Проверка",0)
    check(r.queue.size()<=Radio.MAX_QUEUE,"radio has an unbounded queue")
    r.stop();check(r.queue.is_empty() and r.current.is_empty(),"finish retains radio messages")
    var stream=load("res://assets/level2/pursuit/chatter.ogg") as AudioStreamOggVorbis
    check(stream!=null and absf(stream.get_length()-Radio.CLIP_SECONDS*9)<.03,"voice atlas clips do not match subtitle timing")
func _maneuvers() -> void:
    # Straight physical ribbon, normal car ticks. No passing teleports, speed
    # multipliers, rail immunity or special controller inputs.
    var p=_car(700,0,36);var car=_car(690,2.8,40)
    car.setup(false);car.speed_limit_multiplier=1
    var ai:=AI.new();ai.setup(car,straight,flat,.9,.5)
    ai.pursuit_target=p;ai.pursuit_allowed=true;ai.attack_kind=&"brake_check";ai.attack_cooldown=0
    var seen: Dictionary={};var peak_lead := -INF;var brake_start := 0.0;var brake_end := 0.0
    var warning_frames := 0
    for i in range(720):
        p.set_inputs(0,.0,0);p.speed=36;p.tick(1.0/60,true,straight,flat)
        ai.tick(1.0/60);car.tick(1.0/60,true,straight,flat)
        seen[ai.attack_phase]=true
        peak_lead=maxf(peak_lead,car.world_z-p.world_z)
        if ai.attack_phase==&"brake_warn": warning_frames+=1
        if ai.attack_phase==&"brake":
            if brake_start==0: brake_start=car.speed
            brake_end=car.speed
            check(car.brake_in>.7 and car.throttle==0,"brake check does not use actual brakes")
            check(absf(car.lateral_offset)<=1.9,"brake checker moves across the escape lane")
            check(4.5+absf(ai.brake_lane)>.9*2+1.7,"no body-width escape corridor")
        if ai.brake_checks>0 and ai.attack_phase==&"recover": break
    check(seen.has(&"pass") and seen.has(&"merge") and seen.has(&"brake_warn") and seen.has(&"brake") and peak_lead>12,"AI never physically overtakes and brake-checks")
    check(warning_frames>=60 and brake_end<brake_start-5,"braking has no readable warning or speed reduction")
    ai.attack_phase=&"follow";ai.attack_cooldown=0;ai.attack_kind=&"brake_check"
    _put(p,Data.TUNNEL_START+100,0,flat);_put(car,p.world_z-5,2.8,flat)
    ai.tick(.016);check(not ai.brake_maneuver(),"AI brake-checks under the tunnel roof")
func _audio_lifecycle() -> void:
    root.get_node("GameState").music_muted=true;root.get_node("GameState").sfx_muted=false
    var level=load("res://scenes/level2.tscn").instantiate();root.add_child(level);current_scene=level
    for i in range(5): root.get_node("PauseManager").set_paused(false);await process_frame
    level.set_physics_process(false);level.state.race_started=true;level.state.race_time=20
    var r=level.controller.pursuit.radio
    r.say("test","ОРЕХ-1 · ПИЛОТ","Вижу беглеца. Захожу сзади!",2,2);r.advance(.1)
    var audio=level.get_node("PursuitAudio");audio._process(.01)
    level.presentation._timer=0;level.presentation._process(.1)
    check(audio.chatter.playing and level.presentation.radio_text.text==r.current.text and level.presentation.radio_panel.visible,"spoken message and subtitles do not match")
    for dimensions in [Vector2i(960,540),Vector2i(1280,720),Vector2i(1600,720)]:
        root.size=dimensions;await process_frame;level.presentation.layout()
        var rect: Rect2=level.presentation.radio_panel.get_global_rect()
        check(root.get_visible_rect().encloses(rect),"radio subtitles leave the mobile screen")
        for control in [level.joystick,level.gas_button,level.brake_button,level.message_label,level.presentation.sign_notice_panel]:
            check(not rect.intersects(control.get_global_rect()),"radio subtitles cover controls or driving warnings")
    root.get_node("GameState").sfx_volume_db=-12;audio._process(.01)
    check(audio.chatter.volume_db==-22,"radio ignores SFX volume")
    var before: float=r.remaining
    root.get_node("PauseManager").set_paused(true)
    for i in range(6): await process_frame
    check(r.remaining==before,"pause consumes subtitle duration")
    root.get_node("PauseManager").set_paused(false)
    root.get_node("GameState").sfx_muted=true;audio._process(.01)
    check(not audio.chatter.playing and not r.current.is_empty(),"SFX mute leaves voice playing or removes accessible subtitles")
    level.controller.fail();audio._process(.01)
    check(r.current.is_empty() and not audio.chatter.playing and not level.presentation.radio_panel.visible,"finish keeps radio/subtitles running")
    level.queue_free();current_scene=null
    for i in range(5): await process_frame
    root.get_node("GameState").sfx_volume_db=0
    await preload("res://tools/level3_test_teardown.gd").drain_audio(self)
