extends SceneTree
# A real native framebuffer check: headless geometry checks cannot
# detect a mountain painted over a road or a rival visible through rock.
const Data=preload("res://scripts/race_level_data.gd")
const Math=preload("res://scripts/race_math.gd")
var level
func _init() -> void: call_deferred("_run")
func _run() -> void:
    if DisplayServer.get_name()=="headless": push_error("Native framebuffer required");quit(1);return
    var expected: String=ProjectSettings.get_setting("rendering/renderer/rendering_method")
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--expect-renderer="): expected=arg.trim_prefix("--expect-renderer=")
    if RenderingServer.get_current_rendering_method()!=expected:
        push_error("RACE VISUAL: renderer fallback; expected "+expected);quit(1);return
    print("RACE VISUAL: renderer=",RenderingServer.get_current_rendering_method()," driver=",RenderingServer.get_current_rendering_driver_name())
    # Pixel assertions need one submitted frame per comparison, not dozens of
    # background frames of the full vehicle viewport on a CPU-only CI GPU.
    RenderingServer.set_render_loop_enabled(false)
    root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
    root.size=Vector2i(640,360)
    root.get_node("GameState").music_muted=true;root.get_node("GameState").sfx_muted=true
    level=load("res://scenes/level2.tscn").instantiate();root.add_child(level);current_scene=level
    print("RACE VISUAL: scene loaded, waiting for model setup")
    for i in range(6):
        root.get_node("PauseManager").set_paused(false)
        await process_frame
        print("RACE VISUAL: setup frame ",i)
    # Exercise the live _physics_process -> _process -> model/camera path at
    # 120 display steps / 60 physics steps, rather than only testing lerp math.
    level.state.race_started=true;level.state.countdown=0
    level.controller.player.speed=30
    Input.action_press("race_accel",1);Input.action_press("race_right",.15)
    var moving_frames := 0
    var previous := -INF
    for i in range(150):
        root.get_node("PauseManager").set_paused(false)
        await process_frame
        var shown=level.renderer.player_car
        if i>25 and shown.world_z>previous+.03: moving_frames+=1
        previous=shown.world_z
        if shown!=level.render_player or absf(level.car_3d_overlay.model_root.rotation.y+float(shown.heading_yaw))>.0001:
            await _fail("RACE VISUAL: model does not consume the same interpolated pose as the world");return
    Input.action_release("race_accel");Input.action_release("race_right")
    if moving_frames<110:
        await _fail("RACE VISUAL: live model repeats fixed-step poses between display frames (%d)"%moving_frames);return
    print("RACE VISUAL: interpolated live motion advances on ",moving_frames," of 124 sampled display frames")
    level.set_process(false);level.set_physics_process(false)
    var player=level.controller.player
    var dimensions: Vector2=level.get_viewport_rect().size
    var traffic=level.car_3d_overlay.traffic
    # Compare the shortcut with the full depth shader using actual Camry pixels.
    for z: float in [90,Data.CITY_START+500]:
        _place(player,z);player.heading_yaw=0;level.camera_state.reset(player)
        for i in range(3):
            var rival=level.controller.ais[i].car
            _place(rival,z+18+i*12);rival.heading_yaw=0
            rival.world_x+=float(i-1)*1.8
        level._process(1)
        # Hidden pool cars intentionally retain their last uniforms. Compare
        # only materials actually submitted by this live visibility pass.
        for pivot: Node3D in traffic.models:
            if not pivot.visible:
                await _fail("RACE VISUAL: expected open-earth rival is not submitted: "+String(pivot.name));return
        var submitted_materials: Array[ShaderMaterial]=_visible_traffic_materials(traffic)
        if submitted_materials.is_empty() or submitted_materials.size()!=traffic.last_material_updates:
            await _fail("RACE VISUAL: submitted material count does not match live traffic uniform updates (%d vs %d)"%[submitted_materials.size(),traffic.last_material_updates]);return
        for material in submitted_materials:
            if material.get_shader_parameter("occlusion_sample_count")!=0:
                await _fail("RACE VISUAL: open-earth rivals still ray march every pixel");return
        var fast: Image=await _capture()
        var samples=traffic.ground_samples(level.renderer,z-level.renderer._behind())
        for material in submitted_materials:
            material.set_shader_parameter("occlusion_samples",samples)
            material.set_shader_parameter("occlusion_sample_count",samples.size())
        var full: Image=await _capture()
        var changed := 0
        for y in range(int(dimensions.y*level.renderer.PLAYFIELD_FRACTION)):
            for x in range(int(dimensions.x)):
                if _difference(fast.get_pixel(x,y),full.get_pixel(x,y))>.03: changed+=1
        if changed>2:
            await _fail("RACE VISUAL: flat traffic optimization changes visible pixels (%d)"%changed);return
        print("RACE VISUAL: zero-ray traffic equals full depth path at ",z," (",changed," changed pixels; ",submitted_materials.size()," submitted materials matched live updates)")
    level.car_3d_overlay.viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
    # Compare actual pixels on the forest descent, where billboard feet used
    # to show through the foreground asphalt between coarse terrain probes.
    for z: float in [Data.BRIDGE_END+90,Data.TUNNEL_START-210]:
        _place(player,z);player.heading_yaw=0;level.camera_state.reset(player);level._process(1)
        level.car_3d_overlay.visible=false
        var planted: Image=await _capture()
        var scenery=level.renderer.scenery
        var saved: Dictionary={}
        for key in scenery.groups:
            saved[key]=scenery.groups[key].sprites
            scenery.groups[key].sprites=[]
        scenery.begin(level.renderer,dimensions);scenery.draw(level.renderer,dimensions)
        var bare: Image=await _capture()
        level.renderer.road_mesh.road_node.visible=false
        level.renderer.road_mesh.far_road_node.visible=false
        var no_asphalt: Image=await _capture()
        level.renderer.road_mesh.road_node.visible=true
        level.renderer.road_mesh.far_road_node.visible=true
        for key in saved: scenery.groups[key].sprites=saved[key]
        var probes := 0
        for dz in range(2,160,3):
            var center := Math.track_center_x((z+dz)/40,level.controller.track_x)
            for offset: float in [-3,-1.5,0,1.5,3]:
                var point: Vector2=level.renderer.project_ground(center+offset,dz,dimensions)
                if point.x<2 or point.x>dimensions.x-2 or point.y<2 or point.y>dimensions.y*level.renderer.PLAYFIELD_FRACTION-2: continue
                # A projected road point can itself be behind a nearer crest.
                # Assert only pixels demonstrably belonging to visible asphalt.
                if _difference(bare.get_pixelv(Vector2i(point)),no_asphalt.get_pixelv(Vector2i(point)))<.03: continue
                if _difference(planted.get_pixelv(Vector2i(point)),bare.get_pixelv(Vector2i(point)))>.04:
                    await _fail("RACE VISUAL: forest vegetation shows through foreground asphalt at Z %.1f, depth %d, lane %.1f"%[z,dz,offset]);return
                probes+=1
        if probes<100: await _fail("RACE VISUAL: insufficient forest asphalt probes");return
        print("RACE VISUAL: forest terrain occludes foliage on ",probes," asphalt probes at ",z)
    for z: float in [Data.BRIDGE_START+80,Data.BRIDGE_START+360,Data.BRIDGE_END-100,Data.TUNNEL_START-170,Data.TUNNEL_START-40]:
        _place(player,z);player.heading_yaw=0;level.camera_state.reset(player);level._process(1)
        level.car_3d_overlay.visible=false
        var with_rock: Image=await _capture()
        var cover=level.renderer.scenery.underpass
        cover.batch.node.visible=false
        var without_rock: Image=await _capture()
        var samples := 0
        for dz: float in [12,30,60,120,240,400]:
            if z+dz>=Data.TUNNEL_START-2: continue
            var center := Math.track_center_x((z+dz)/40,level.controller.track_x)
            for side: float in [-1,0,1]:
                var point: Vector2=level.renderer.project_ground(center+side,dz,dimensions)
                if point.x<2 or point.x>dimensions.x-2 or point.y<2 or point.y>dimensions.y*level.renderer.PLAYFIELD_FRACTION-2: continue
                var pixel := Vector2i(point)
                if _difference(with_rock.get_pixelv(pixel),without_rock.get_pixelv(pixel))>.03:
                    await _fail("RACE VISUAL: foreground road is covered by the forest tunnel cover at Z %.1f"%z);return
                samples+=1
        if samples<6: await _fail("RACE VISUAL: insufficient foreground road probes");return
        print("RACE VISUAL: road Z=",z," viewport=",dimensions)
    level.car_3d_overlay.viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
    level.car_3d_overlay.model_root.visible=false
    # Place a real rival behind the CLOSED side of the mouth, then compare its
    # region against the same frame with only that mesh hidden.
    for blocked in [true,false]:
        var z := Data.TUNNEL_START-90 if blocked else Data.TUNNEL_START+20
        _place(player,z);player.heading_yaw=0;level.camera_state.reset(player)
        var rival=level.controller.ais[0].car
        _place(rival,Data.TUNNEL_START+90 if blocked else z+25)
        rival.world_x=Math.track_center_x(Data.TUNNEL_START/40,level.controller.track_x)+28 if blocked else rival.world_x
        rival.heading_yaw=0
        level._process(1)
        for i in range(1,3): traffic.models[i].visible=false
        var with_car: Image=await _capture()
        traffic.models[0].visible=false
        var without_car: Image=await _capture()
        var foot: Vector2=level.renderer.project_ground(rival.world_x,rival.world_z-player.world_z,dimensions)
        var radius := roundi((25 if blocked else 70)*dimensions.x/1280.0)
        var changed := 0
        for y in range(maxi(0,int(foot.y)-radius),mini(int(dimensions.y*level.renderer.PLAYFIELD_FRACTION),int(foot.y)+8)):
            for x in range(maxi(0,int(foot.x)-radius),mini(int(dimensions.x),int(foot.x)+radius)):
                if _difference(with_car.get_pixel(x,y),without_car.get_pixel(x,y))>.04: changed+=1
        if (blocked and changed>2) or (not blocked and changed<30):
            await _fail("RACE VISUAL: live rival portal occlusion failed (blocked=%s, pixels=%d)"%[blocked,changed]);return
    level.queue_free();for i in range(4): await process_frame
    await preload("res://tools/level3_test_teardown.gd").drain_audio(self)
    print("RACE VISUAL: PASS — foreground bridge/approach road remains opaque; live 3D rival is hidden behind the retaining portal and visible through the actual opening")
    quit(0)

func _capture() -> Image:
    for i in range(2): await process_frame
    # An unchanged/unfocused Xvfb window may stop producing post-draw signals.
    # Explicitly draw the submitted frame before synchronous texture readback.
    RenderingServer.force_draw(true)
    return root.get_texture().get_image()
func _visible_traffic_materials(traffic) -> Array[ShaderMaterial]:
    var submitted: Array[ShaderMaterial]=[]
    for collection in [traffic.models,traffic.civilian_models,traffic.block_models]:
        for pivot: Node3D in collection:
            if not pivot.visible: continue
            for material: ShaderMaterial in pivot.get_meta("instance_materials",[]):
                submitted.append(material)
    return submitted
func _place(car,z: float) -> void:
    var canonical: float=(z+car.grid_world_z_offset)/40
    car.segment_index=floori(canonical);car.segment_progress=canonical-car.segment_index
    car.world_z=z;car.world_x=Math.track_center_x(z/40,level.controller.track_x);car.lateral_offset=0
func _difference(a: Color,b: Color) -> float:
    return maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b)))
func _fail(message: String) -> void:
    push_error(message)
    level.queue_free()
    for i in range(4): await process_frame
    await preload("res://tools/level3_test_teardown.gd").drain_audio(self)
    quit(1)
