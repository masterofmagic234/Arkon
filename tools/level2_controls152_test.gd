extends SceneTree
## Real pointer ownership and signed emergency-crawl regressions. --scene also
## exercises the production HUD; --visual captures its actual native viewport.
const Car = preload("res://scripts/race_car_controller.gd")
const Data = preload("res://scripts/race_level_data.gd")
const Driver = preload("res://scripts/race_input.gd")
const Contacts = preload("res://scripts/race_vehicle_contacts.gd")
var failures: Array[String]=[]
var cases: Array[Dictionary]=[]
var captures: Array[String]=[]
var ground_cases: Array[Dictionary]=[]
var output := ""
var visual := false

class TouchHost extends Node:
    var driver
    func _input(event: InputEvent) -> void:
        if driver!=null and driver.handle_event(event):get_viewport().set_input_as_handled()

func _init() -> void:
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
    visual=OS.get_cmdline_user_args().has("--visual")
    call_deferred("_run")

func check(ok: bool,why: String) -> void:
    if not ok:failures.append(why);push_error("LEVEL2 CONTROLS152: "+why)

func touch(id: int,at: Vector2,pressed: bool,canceled := false) -> void:
    var event:=InputEventScreenTouch.new();event.index=id;event.position=at;event.pressed=pressed;event.canceled=canceled
    root.push_input(event,true)

func drag(id: int,at: Vector2) -> void:
    var event:=InputEventScreenDrag.new();event.index=id;event.position=at
    root.push_input(event,true)

func car_at(z: float,track: PackedFloat32Array,pattern: Array=[0,0,0,0]):
    var car=Car.new();car.setup(true);car.place_on_grid(0,0.0,track)
    # Explicit initial placement for an isolated vehicle case, not a claimed
    # drive through every intervening scene barrier.
    var at:=z/Data.SEGMENT_HEIGHT
    car.lap=floori(at/pattern.size());car.segment_index=posmod(floori(at),pattern.size());car.segment_progress=at-floor(at)
    car.tick(0.0,false,pattern,track)
    return car

func simulate(car,frames: int,pattern: Array,track: PackedFloat32Array) -> float:
    var maximum:=0.0
    for i in range(frames):
        var z: float=car.world_z
        car.tick(1.0/60.0,true,pattern,track)
        maximum=maxf(maximum,absf(car.world_z-z))
    return maximum

func pure_vehicle_cases() -> void:
    var pattern: Array=[0,0,0,0]
    var track:=PackedFloat32Array([0,0,0,0])
    var car=car_at(30.0,track)
    car.speed=32.0;car.set_inputs(0.0,1.0,1.0)
    simulate(car,600,pattern,track)
    check(is_zero_approx(car.speed) and car.gear==1,"brake/gas conflict must stop, never select reverse")
    car.set_inputs(0.0,0.0,1.0)
    simulate(car,30,pattern,track)
    check(car.speed>=0.0 and car.gear==1,"reverse engaged before stopped brake-hold interval")
    var start: float=car.world_z
    var largest:=simulate(car,180,pattern,track)
    check(car.speed<0 and absf(car.speed/Data.SPEED_UNITS_PER_KMH+1.0)<.001 and car.gear==-1,"held stopped brake did not reach bounded1km/h reverse/R")
    check(car.world_z<start-.5 and largest<=Data.SPEED_UNITS_PER_KMH/60.0+.00001,"reverse jumped rather than traversing swept sub-centimetre steps")
    check(car.contact_velocity().y<0,"contact solver lost reverse velocity sign")
    var reversed: float=car.world_z
    car.set_inputs(0,0,0);simulate(car,120,pattern,track)
    check(is_zero_approx(car.speed) and car.gear==1 and reversed-car.world_z<.08,"pedal release did not stop the emergency crawl")
    var rest: float=car.world_z;simulate(car,60,pattern,track)
    check(absf(car.world_z-rest)<.00001,"released reverse keeps creeping")
    car.set_inputs(0,1,0);simulate(car,120,pattern,track)
    check(car.speed>3 and car.world_z>rest,"gas did not return smoothly to normal forward drive")
    cases.append({"id":"stop-delay-crawl-release-forward","max_reverse_frame_metres":largest,"reverse_cap_kmh":1.0})

    for z in [.02,40.02]:
        car=car_at(z,track);car.set_inputs(0,0,1)
        largest=simulate(car,240,pattern,track)
        check(car.world_z<z-.9 and absf(car.world_z-(car.progress(pattern.size())*Data.SEGMENT_HEIGHT-car.grid_world_z_offset))<.00001,"reverse canonical state failed across segment/origin boundary")
        check(car.segment_progress>=0 and car.segment_progress<1 and largest<=Data.SPEED_UNITS_PER_KMH/60.0+.00001,"reverse boundary wrapped or produced a progress discontinuity")
        var corrected: float=car.world_z-.06;car.resolve_contact(Vector2(0,-.06),pattern,track)
        car.set_inputs(0,0,0);car.speed=0;car.tick(1.0/60,false,pattern,track)
        check(absf(car.world_z-corrected)<.00001,"contact correction behind origin snapped forward on next tick")
        cases.append({"id":"signed-route-boundary","start_z":z,"end_z":car.world_z,"lap":car.lap,"segment":car.segment_index})

    # A real SAT contact ahead may separate when backing, but cannot erase the
    # negative velocity or substitute a positional escape.
    car=car_at(50.0,track)
    var rival=Car.new();rival.setup(false);rival.place_on_grid(0,0,track);rival.resolve_contact(Vector2(0,54.43),pattern,track)
    car.set_inputs(0,0,1);var initial_gap: float=rival.world_z-car.world_z
    largest=0
    for frame in range(240):
        var old:=Vector2(car.world_x,car.world_z)
        var previous: Array[Vector2]=[old,Vector2(rival.world_x,rival.world_z)]
        car.tick(1.0/60,true,pattern,track)
        Contacts.solve([car,rival],previous,pattern,track)
        largest=maxf(largest,absf(car.world_z-old.y))
    check(rival.world_z-car.world_z>initial_gap+.9 and largest<.006,"front-contact escape bypassed physical signed crawl")
    cases.append({"id":"front-car-contact-retreat","initial_gap":initial_gap,"final_gap":rival.world_z-car.world_z,"max_frame_metres":largest})

    car=car_at(100.0,track)
    rival=Car.new();rival.setup(false);rival.place_on_grid(0,0,track);rival.resolve_contact(Vector2(0,95.57),pattern,track)
    car.set_inputs(0,0,1)
    var rear_contacts:=0;var minimum_gap:=INF
    for frame in range(240):
        var previous: Array[Vector2]=[Vector2(car.world_x,car.world_z),Vector2(rival.world_x,rival.world_z)]
        car.tick(1.0/60,true,pattern,track);rival.tick(1.0/60,false,pattern,track)
        var pairs: Array[Vector2i]=Contacts.solve([car,rival],previous,pattern,track)
        if not pairs.is_empty():
            rear_contacts+=1
            check(car.speed<=.00001,"rear collision converted selected reverse into positive forward speed")
        minimum_gap=minf(minimum_gap,car.world_z-rival.world_z)
    check(rear_contacts>20 and minimum_gap>4.42,"backing phased through the actual rear car contact body")
    cases.append({"id":"rear-car-signed-contact","contact_frames":rear_contacts,"minimum_gap":minimum_gap,"final_speed":car.speed})

    # Backing toward the outside edge of the actual tunnel portal remains
    # blocked by the same swept scenery barrier used for forward travel.
    var production: Array=Data.get_track_pattern()
    var road:=preload("res://scripts/race_math.gd").accumulate_track_x(production)
    car=car_at(Data.TUNNEL_END+.10,road,production)
    car.resolve_contact(Vector2(6.0,0.0),production,road)
    car.set_inputs(0,0,1);largest=simulate(car,240,production,road)
    check(car.world_z>=Data.TUNNEL_END-.001 and car.wall_contact>0,"reverse passed through the actual tunnel portal wall")
    check(largest<=Data.SPEED_UNITS_PER_KMH/60.0+.00001,"reverse portal contact teleported the vehicle")
    cases.append({"id":"reverse-tunnel-portal","end_z":car.world_z,"wall_contact":car.wall_contact})

    # Verify the already tuned forward model using its independent retained
    # acceleration/gearbox/skid assertions, not a second copy of its equations.
    var retained: String=preload("res://tools/level2_vehicle_checks.gd").run_dynamics()
    check(retained.is_empty(),"retained forward dynamics: "+retained)
    cases.append({"id":"retained-forward-dynamics","result":"PASS" if retained.is_empty() else "FAIL"})

func pointer_cases() -> void:
    var host:=TouchHost.new();root.add_child(host)
    var stick:=Panel.new();stick.position=Vector2(20,420);stick.size=Vector2(150,150);host.add_child(stick)
    var knob:=Panel.new();knob.size=Vector2(58,58);stick.add_child(knob)
    var gas:=Button.new();gas.position=Vector2(980,550);gas.size=Vector2(270,100);host.add_child(gas)
    var brake:=Button.new();brake.position=Vector2(980,450);brake.size=Vector2(270,80);host.add_child(brake)
    var driver=Driver.new();host.driver=driver;driver.setup(stick,knob,gas,brake)
    await process_frame
    touch(21,stick.get_global_rect().get_center()+Vector2(35,0),true)
    touch(22,gas.get_global_rect().get_center(),true)
    touch(23,brake.get_global_rect().get_center(),true)
    check(driver.steer>.2 and driver.throttle==1 and driver.brake==1,"independent steering/gas/brake touches failed")
    var rect:=gas.get_global_rect()
    for point in [rect.position+Vector2.ONE,rect.end-Vector2.ONE,Vector2(rect.position.x+1,rect.end.y-1),Vector2(rect.end.x-1,rect.position.y+1),rect.get_center()]:
        drag(22,point);check(driver.throttle==1,"finger drift inside actual gas rectangle stopped throttle")
    drag(22,Vector2(rect.end.x+4,rect.get_center().y));check(driver.throttle==1,"small edge slip lost pedal despite hysteresis")
    drag(22,Vector2(-100,-100));check(driver.throttle==0 and driver.pointers.has(22),"far drag did not deactivate while retaining ownership")
    drag(22,rect.get_center());check(driver.throttle==1,"returning held finger failed to reactivate gas")
    touch(24,Vector2.ZERO,false);check(driver.throttle==1 and driver.brake==1,"foreign finger release canceled a pedal")
    var mouse:=InputEventMouseButton.new();mouse.device=-1;mouse.button_index=MOUSE_BUTTON_LEFT;mouse.pressed=false
    root.push_input(mouse,true);check(driver.throttle==1,"emulated mouse release stole real touch")
    touch(21,Vector2.ZERO,false,true);check(driver.steer==0 and driver.throttle==1,"steering cancel released another finger's pedal")
    driver.stop();check(driver.pointers.is_empty() and driver.pedal_active.is_empty() and driver.read().throttle==0 and driver.read().brake==0,"focus/pause stop retained stale touch state")
    host.driver=null;host.queue_free();await process_frame
    cases.append({"id":"real-pointer-edge-hold-reentry-multitouch","inside_drags":5,"hysteresis_drag":true,"release_and_stop":true})

func capture(level,name: String) -> void:
    if not visual or output.is_empty():return
    level._process(1.0/60)
    await process_frame;await RenderingServer.frame_post_draw
    var file:=name+".png";root.get_texture().get_image().save_png(output.path_join(file));captures.append(file)

func ground_signature(frame) -> Array:
    return [frame.transform,frame.inverse,frame.lens,frame.focal,frame.vertical,frame.pivot]

func ground_camera_signature(level) -> Array:
    var target=level.car_3d_overlay
    return [target.camera.global_transform,target.camera.fov,target.camera_rig.global_transform,target.viewport.size,target.position,target.size,target.model_instance.global_transform]

func pixel_difference(a: Image,b: Image,rect: Rect2i) -> Dictionary:
    var first:=a.get_region(rect).get_data();var second:=b.get_region(rect).get_data()
    if first==second:return {"changed_pixels":0,"maximum_channel_delta":0,"sampled_pixels":rect.size.x*rect.size.y}
    var changed:=0;var maximum:=0
    for i in range(0,first.size(),4):
        var delta:=maxi(abs(int(first[i])-int(second[i])),maxi(abs(int(first[i+1])-int(second[i+1])),abs(int(first[i+2])-int(second[i+2]))))
        maximum=maxi(maximum,delta)
        if delta>3:changed+=1
    return {"changed_pixels":changed,"maximum_channel_delta":maximum,"sampled_pixels":rect.size.x*rect.size.y}

func ground_statistics(level) -> Dictionary:
    var road=level.renderer.road_mesh
    var maximum_y: float=-INF
    for vertices in [road._road_vertices,road._verge_vertices]:
        for point in vertices:maximum_y=maxf(maximum_y,point.y)
    var triangles: int=(road._road_indices.size()+road._verge_indices.size()+road._far_road_indices.size()+road._far_verge_indices.size())/3
    return {"triangles":triangles,"maximum_ground_y":maximum_y,"clip_bottom":road.frame.viewport.size.y,"ground_nodes":[road.road_node.get_instance_id(),road.verge_node.get_instance_id(),road.far_road_node.get_instance_id(),road.far_verge_node.get_instance_id()]}

func ground_image(level,name: String) -> Image:
    level._process(0.0)
    level.renderer.road_mesh.update(level.renderer,root.get_visible_rect().size)
    level.renderer.queue_redraw()
    for i in range(2):await process_frame;await RenderingServer.frame_post_draw
    var image:=root.get_texture().get_image();image.convert(Image.FORMAT_RGBA8)
    if not output.is_empty():
        var file:=name+".png";image.save_png(output.path_join(file));captures.append(file)
    return image

func ground_under_dashboard_cases(level) -> void:
    var old_scale:=Engine.time_scale
    var target=level.car_3d_overlay
    var old_target_mode: int=target.viewport.render_target_update_mode
    var road=level.renderer.road_mesh
    var dimensions:=root.get_visible_rect().size
    var old_clip: float=dimensions.y*level.renderer.PLAYFIELD_FRACTION
    var hud_top: int=floori(dimensions.y*level.HUD_TOP_FRACTION)
    level.presentation.set_process(false);level.hud_panel.set_process(false)
    # Shader TIME and actor animation must not be mistaken for a changed lens.
    # The original target is drawn at each staged pose, then held for its A/B.
    Engine.time_scale=0.0
    var Frame=load("res://scripts/race_projection_frame.gd")
    for pose in [{"id":"forest","z":200.0,"yaw":0.0},{"id":"bridge","z":3520.0,"yaw":0.0},{"id":"tunnel","z":5520.0,"yaw":0.0},{"id":"city","z":7800.0,"yaw":0.0},{"id":"wide-orbit","z":200.0,"yaw":1.35}]:
        var car=level.controller.player
        var at: float=(float(pose.z)+car.grid_world_z_offset)/Data.SEGMENT_HEIGHT
        car.lap=floori(at/level.controller.track_pattern.size());car.segment_index=posmod(floori(at),level.controller.track_pattern.size());car.segment_progress=at-floor(at)
        car.set_inputs(0,0,0);car.speed=0;car.lateral_offset=0;car.lateral_velocity=0;car.impact_velocity=0;car._heading=float(pose.yaw)
        car.tick(0.0,false,level.controller.track_pattern,level.controller.track_x)
        level.camera_state.reset(car);level._process(0.0);level.presentation._process(.1)
        level.hud_panel._process(0.0);level.hud_panel.set_route(0.0,maxf(0,Data.route_length()-car.world_z))
        var reference=Frame.new();reference.configure(level.renderer,dimensions)
        var extended=Frame.new();extended.configure(level.renderer,dimensions,dimensions.y)
        check(ground_signature(reference)==ground_signature(extended),"ground extension changed lens/world transform: "+pose.id)
        check(is_equal_approx(reference.viewport.size.y,old_clip),"non-road default clip changed")
        var projection_error:=0.0
        for x in [-3.0,0.0,3.0]:
            for z in [4.0,6.0,20.0,100.0]:
                projection_error=maxf(projection_error,reference.project(Vector3(x,0,z)).distance_to(extended.project(Vector3(x,0,z))))
        check(projection_error<.00001,"ground extension moved projected points: "+pose.id)
        target.viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
        if visual:
            for i in range(3):await process_frame;await RenderingServer.frame_post_draw
            target.viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
        var camera_before: Array=ground_camera_signature(level)
        road.extend_under_hud=false
        var cpu_before: Array[int]=[]
        for i in range(7):
            var began:=Time.get_ticks_usec();road.update(level.renderer,dimensions);cpu_before.append(Time.get_ticks_usec()-began)
        var before_stats:=ground_statistics(level)
        var before_image: Image
        if visual:before_image=await ground_image(level,"ground-"+pose.id+"-before")
        road.extend_under_hud=true
        var cpu_after: Array[int]=[]
        for i in range(7):
            var began:=Time.get_ticks_usec();road.update(level.renderer,dimensions);cpu_after.append(Time.get_ticks_usec()-began)
        var after_stats:=ground_statistics(level)
        var after_image: Image
        if visual:after_image=await ground_image(level,"ground-"+pose.id+"-after")
        var camera_unchanged: bool=camera_before==ground_camera_signature(level)
        check(camera_unchanged,"ground-only extension changed the3D camera/model/viewport: "+pose.id)
        check(before_stats.ground_nodes==after_stats.ground_nodes,"ground extension created another render pass/node")
        check(before_stats.maximum_ground_y<=old_clip+.1 and after_stats.maximum_ground_y>=dimensions.y-.1,"real ground does not extend behind dashboard: "+pose.id)
        cpu_before.sort();cpu_after.sort()
        var record: Dictionary={"id":pose.id,"staged_pose":true,"world_z":car.world_z,"camera_yaw":float(pose.yaw),"projection_max_error_px":projection_error,"camera_model_viewport_unchanged":camera_unchanged,"before":before_stats,"after":after_stats,"maximum_extra_ground_fill_pixels":ceili(dimensions.x*(dimensions.y-old_clip)),"cpu_before_median_us":cpu_before[3],"cpu_after_median_us":cpu_after[3],"timing_scope":"Seven CPU mesh-generation samples per mode; diagnostic software timing, not GPU/deviceFPS."}
        if visual:
            var above:=pixel_difference(before_image,after_image,Rect2i(0,0,int(dimensions.x),floori(old_clip)-2))
            var footer:=pixel_difference(before_image,after_image,Rect2i(0,hud_top,int(dimensions.x),int(dimensions.y)-hud_top))
            record.above_playfield_pixels=above;record.dashboard_pixels=footer
            record.before_png="ground-"+pose.id+"-before.png";record.after_png="ground-"+pose.id+"-after.png"
            check(above.changed_pixels<=maxi(8,ceili(float(above.sampled_pixels)*.00002)),"ground extension altered the old visible playfield: "+pose.id)
            check(footer.changed_pixels>int(footer.sampled_pixels)*.15,"translucent dashboard still has only an empty solid band: "+pose.id)
        ground_cases.append(record)
    road.extend_under_hud=true
    target.viewport.render_target_update_mode=old_target_mode
    Engine.time_scale=old_scale

func scene_cases() -> void:
    var level=load("res://scenes/level2.tscn").instantiate();root.add_child(level);current_scene=level
    level.set_physics_process(false)
    for i in range(8):await process_frame
    level.set_process(false)
    for dimensions in [Vector2i(1280,720),Vector2i(2582,1220),Vector2i(3088,1440),Vector2i(960,540)]:
        root.size=dimensions;await process_frame;level.presentation.layout()
        check(root.get_visible_rect().size.is_equal_approx(Vector2(dimensions)),"requested native HUD viewport was not applied")
        var scale_: float=minf(dimensions.x/1280.0,dimensions.y/720.0)
        var rect: Rect2=level.gas_button.get_global_rect()
        check(rect.size.x/scale_>=240 and rect.size.y/scale_>=90,"actual gas hit rectangle remains too small")
        check(root.get_visible_rect().encloses(rect) and not rect.intersects(level.brake_button.get_global_rect()),"pedals clipped or overlap")
        check(not level.minimap.visible and not level.minimap.is_processing(),"unwanted navigation map still visible/processing")
        for id in ["LapLabel","Lap","PosLabel","Pos","TimeLabel","Time"]:check(not level.hud_background.get_node(id).visible,"unwanted dashboard telemetry visible: "+id)
        var style: StyleBoxFlat=level.hud_background.get_theme_stylebox("panel")
        check(style.bg_color.a<=.35 and style.border_color.a<=.4,"bottom dashboard is opaque or brightly bordered")
        check(not level.message_label.visible and level.message_label.text.is_empty(),"tactical warning strip remains visible")
        check(level.controller.pursuit.encounters.traffic.size()==6 and not level.controller.pursuit.encounters.roadblocks.is_empty(),"HUD simplification removed physical traffic/roadblocks")
        touch(80,rect.get_center(),true);drag(80,rect.end-Vector2.ONE);check(level.race_input.throttle==1,"actual scene pedal lost finger at its visible corner")
        drag(80,Vector2(-100,-100));drag(80,rect.get_center());check(level.race_input.throttle==1,"actual scene pedal cannot recover held finger")
        touch(80,Vector2.ZERO,false)
        await capture(level,"dashboard-%dx%d"%[dimensions.x,dimensions.y])
        cases.append({"id":"production-dashboard","viewport":[dimensions.x,dimensions.y],"gas_rect":[rect.position.x,rect.position.y,rect.size.x,rect.size.y],"background_alpha":style.bg_color.a})
    root.size=Vector2i(1280,720);await process_frame;level.presentation.layout()
    touch(82,level.gas_button.get_global_rect().get_center(),true)
    root.size=Vector2i(1600,720);await process_frame
    check(level.race_input.pointers.is_empty() and level.race_input.throttle==0,"resize kept a pedal owned at its old screen position")
    root.size=Vector2i(1280,720);await process_frame;level.presentation.layout()
    level.state.race_started=true
    var origin_start: float=level.controller.player.world_z
    touch(81,level.brake_button.get_global_rect().get_center(),true)
    for i in range(120):level._physics_process(1.0/60)
    level.hud_panel._process(.01);level.presentation._process(.1)
    var reverse_z: float=level.controller.player.world_z
    check(level.controller.player.speed<0 and level.hud_background.get_node("Gear").text=="R" and level.hud_background.get_node("Speed").text=="1","production reverse/HUD R and1km/h disagree")
    check(level.controller.player.progress(level.controller.track_pattern.size())<0 and reverse_z<origin_start and reverse_z>origin_start-1.0 and absf(level.controller.player.world_x)<.01,"production reverse crossed the grid origin by wrapping to a different road position")
    await capture(level,"reverse-gear-R")
    touch(81,Vector2.ZERO,false)
    var gas_rect: Rect2=level.gas_button.get_global_rect()
    touch(83,gas_rect.get_center(),true)
    for i in range(60):
        drag(83,gas_rect.position+Vector2(1,1) if i%2==0 else gas_rect.end-Vector2.ONE)
        check(level.race_input.throttle==1,"production held-edge drag interrupted acceleration")
        level._physics_process(1.0/60)
    check(level.controller.player.speed/Data.SPEED_UNITS_PER_KMH>5,"real held gas did not physically accelerate the production car")
    touch(81,level.brake_button.get_global_rect().get_center(),true)
    level.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
    check(paused and level.race_input.pointers.is_empty(),"production focus loss retained pedal ownership")
    root.get_node("PauseManager").resume()
    check(level.race_input.read().brake==0 and level.race_input.read().throttle==0,"pedals remained held after focus resume")
    cases.append({"id":"production-held-gas-resize-reverse-focus","held_edge_physics_steps":60,"brake_physics_steps":120,"reverse_gear":"R","display_kmh":1,"start_z":origin_start,"reverse_z":reverse_z,"negative_origin_crossing":true,"resize_and_focus_released":true})
    # A real1km/h diagonal fixed step crosses the very edge of a full-width
    # stinger. Signed interpolation must use the crossing point, not old X.
    var stinger=level.controller.pursuit.get_script().new()
    var crossing=car_at(-.002,PackedFloat32Array([0,0,0,0]))
    crossing.world_x=1.343;crossing.speed=-Data.SPEED_UNITS_PER_KMH
    var old_crossing: Array[Vector2]=[Vector2(1.346,.002)]
    stinger._previous=old_crossing
    stinger.strips.append({"age":0.0,"armed":true,"z":0.0,"width":1.25,"offset":0.0})
    stinger._advance_strips(1.0/60,crossing,[])
    check(crossing.puncture_remaining>0 and stinger.spike_hits==1,"reverse tire crossing missed actual stinger edge")
    cases.append({"id":"signed-reverse-stinger-crossing","fixed_step_metres":.005,"puncture":crossing.puncture_remaining>0})
    await ground_under_dashboard_cases(level)
    current_scene=null;level.queue_free();await process_frame;await process_frame
    await load("res://tools/level3_test_teardown.gd").drain_audio(self)

func _run() -> void:
    root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
    root.size=Vector2i(1280,720)
    for action in ["race_left","race_right","race_accel","race_brake"]:
        if not InputMap.has_action(action):InputMap.add_action(action)
    if not output.is_empty():DirAccess.make_dir_recursive_absolute(output)
    pure_vehicle_cases()
    await pointer_cases()
    if OS.get_cmdline_user_args().has("--scene") or visual:await scene_cases()
    var sources: Dictionary={}
    for path in ["scripts/race_input.gd","scripts/race_car_controller.gd","scripts/race_powertrain.gd","scripts/race_presentation.gd","scripts/race_hud_panel_pseudo3d.gd","scripts/race_controller.gd","scripts/game_level2_pseudo3d.gd","scripts/race_pursuit.gd","scripts/race_projection_frame.gd","scripts/race_road_mesh.gd","tools/level2_controls152_test.gd"]:
        if FileAccess.file_exists("res://"+path):sources[path]=FileAccess.get_sha256("res://"+path)
    var report: Dictionary={"result":"PASS" if failures.is_empty() else "FAIL","engine":Engine.get_version_info().string,"native":DisplayServer.get_name()!="headless","cases":cases,"ground_under_dashboard":ground_cases,"captures":captures,"source_hashes":sources,"failures":failures,"scope":"Isolated real vehicle/input regressions and optional production HUD viewport checks. Ground pairs use staged poses/frozen time and a held native3D target, preserving actual camera/lens while changing only the road bottom clip. Not a claimed continuous campaign playthrough."}
    if not output.is_empty():FileAccess.open(output.path_join("controls152-report.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    if failures.is_empty():print("LEVEL2 CONTROLS152: PASS — held-pointer re-entry, quiet dashboard, physical1km/h reverse, signed contacts and route boundaries; ",cases.size()," cases")
    quit(0 if failures.is_empty() else 1)
