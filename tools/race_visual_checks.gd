extends SceneTree
# A real Compatibility framebuffer check: headless geometry checks cannot
# detect a mountain painted over a road or a rival visible through rock.
const Data=preload("res://scripts/race_level_data.gd")
const Math=preload("res://scripts/race_math.gd")
var level
func _init() -> void: call_deferred("_run")
func _run() -> void:
    if DisplayServer.get_name()=="headless": push_error("Native framebuffer required");quit(1);return
    root.size=Vector2i(1280,720)
    root.get_node("GameState").music_muted=true;root.get_node("GameState").sfx_muted=true
    level=load("res://scenes/level2.tscn").instantiate();root.add_child(level);current_scene=level
    for i in range(6): await process_frame
    level.set_process(false);level.set_physics_process(false)
    var player=level.controller.player
    for z: float in [Data.BRIDGE_START+80,Data.BRIDGE_START+360,Data.BRIDGE_END-100,Data.TUNNEL_START-170,Data.TUNNEL_START-40]:
        _place(player,z);player.heading_yaw=0;level.camera_state.reset(player);level._process(1)
        level.car_3d_overlay.visible=false
        var with_rock: Image=await _capture()
        var mountain=level.renderer.scenery.mountain
        mountain.batch.node.visible=false;mountain.exit_batch.node.visible=false;mountain.cutting.node.visible=false
        var without_rock: Image=await _capture()
        var samples := 0
        for dz: float in [12,30,60,120,240,400]:
            if z+dz>=Data.TUNNEL_START-2: continue
            var center := Math.track_center_x((z+dz)/40,level.controller.track_x)
            for side: float in [-1,0,1]:
                var point: Vector2=level.renderer.project_ground(center+side,dz,Vector2(1280,720))
                if point.x<2 or point.x>1278 or point.y<2 or point.y>494: continue
                var pixel := Vector2i(point)
                if _difference(with_rock.get_pixelv(pixel),without_rock.get_pixelv(pixel))>.03:
                    push_error("RACE VISUAL: foreground road is covered by the distant mountain at Z %.1f"%z);quit(1);return
                samples+=1
        if samples<6: push_error("RACE VISUAL: insufficient foreground road probes");quit(1);return
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
        var traffic=level.car_3d_overlay.traffic
        for i in range(1,3): traffic.models[i].visible=false
        var with_car: Image=await _capture()
        traffic.models[0].visible=false
        var without_car: Image=await _capture()
        var foot: Vector2=level.renderer.project_ground(rival.world_x,rival.world_z-player.world_z,Vector2(1280,720))
        var radius := 25 if blocked else 70
        var changed := 0
        for y in range(maxi(0,int(foot.y)-radius),mini(495,int(foot.y)+8)):
            for x in range(maxi(0,int(foot.x)-radius),mini(1280,int(foot.x)+radius)):
                if _difference(with_car.get_pixel(x,y),without_car.get_pixel(x,y))>.04: changed+=1
        if (blocked and changed>2) or (not blocked and changed<30):
            push_error("RACE VISUAL: live rival portal occlusion failed (blocked=%s, pixels=%d)"%[blocked,changed]);quit(1);return
    level.queue_free();for i in range(4): await process_frame
    await preload("res://tools/level3_test_teardown.gd").drain_audio(self)
    print("RACE VISUAL: PASS — foreground bridge/approach road remains opaque; live 3D rival is hidden behind rock and visible through the actual opening")
    quit(0)

func _capture() -> Image:
    for i in range(2): await process_frame
    await RenderingServer.frame_post_draw
    return root.get_texture().get_image()
func _place(car,z: float) -> void:
    var canonical: float=(z+car.grid_world_z_offset)/40
    car.segment_index=floori(canonical);car.segment_progress=canonical-car.segment_index
    car.world_z=z;car.world_x=Math.track_center_x(z/40,level.controller.track_x);car.lateral_offset=0
func _difference(a: Color,b: Color) -> float:
    return maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b)))
