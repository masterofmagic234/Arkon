extends SceneTree
# Real production mesh/atlas rasterization, with the aircraft on each side of
# an opaque wall and alpha-cut foliage. Deliberately checks transparent holes.
const Data=preload("res://scripts/race_level_data.gd")
const Math=preload("res://scripts/race_math.gd")
var level
var output := "/tmp/airframe-depth"

func _init() -> void:
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
    call_deferred("_run")

func _image() -> Image:
    for i in range(3): await process_frame
    RenderingServer.force_draw(true)
    return root.get_texture().get_image()

func _run() -> void:
    if DisplayServer.get_name()=="headless" or RenderingServer.get_current_rendering_method()!="forward_plus":
        push_error("AIRFRAME DEPTH: native Forward+ required");quit(1);return
    root.size=Vector2i(1280,720);root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
    root.get_node("GameState").music_muted=true;root.get_node("GameState").sfx_muted=true
    RenderingServer.set_render_loop_enabled(false)
    level=load("res://scenes/level2.tscn").instantiate();root.add_child(level);current_scene=level
    for i in range(12): root.get_node("PauseManager").set_paused(false);await process_frame
    level.set_process(false);level.set_physics_process(false)
    level.state.race_started=true;level.state.race_time=20;level.state.countdown=0;level.hud_panel.hide_countdown()
    var p=level.controller.player
    var canonical: float=(900+p.grid_world_z_offset)/40
    p.segment_index=floori(canonical);p.segment_progress=canonical-p.segment_index;p.world_z=900
    p.world_x=Math.track_center_x(p.world_z/40,level.controller.track_x);p.lateral_offset=0;p.heading_yaw=0
    level.camera_state.reset(p)
    level.renderer.player_car=p;level.renderer.ai_cars=level.controller.ais
    level.renderer.pursuit=null # Isolate airframe pixels from its ground light.
    for model in level.car_3d_overlay.traffic.models: model.hide()
    level.car_3d_overlay.model_root.hide()
    DirAccess.make_dir_recursive_absolute(output)
    for size_: Vector2i in [Vector2i(1280,720),Vector2i(1920,864)]:
        root.size=size_
        for i in range(4): await process_frame
        for roll: float in [0.0,0.07]:
            for wall in [false,true]:
                for front in [false,true]:
                    if wall and front: continue
                    if not await _case(wall,front,roll):
                        level.queue_free();current_scene=null
                        for i in range(4): await process_frame
                        await preload("res://tools/level3_test_teardown.gd").drain_audio(self)
                        quit(1);return
    level.controller.pursuit.stop();level._process(.016)
    if level.car_3d_overlay.helicopter.scenery_depth.root.visible:
        push_error("AIRFRAME DEPTH: idle aircraft keeps submitting scenery proxies");quit(1);return
    if level.find_children("*","SubViewport",true,false).size()!=1:
        push_error("AIRFRAME DEPTH: aircraft allocated another render target");quit(1);return
    if level.car_3d_overlay.helicopter.mesh_count>24:
        push_error("AIRFRAME DEPTH: static airframe batching regressed");quit(1);return
    if level.car_3d_overlay.helicopter.scenery_depth.materials.size()>2:
        push_error("AIRFRAME DEPTH: shared atlas materials regressed");quit(1);return
    print("AIRFRAME BUDGET: aircraft meshes=",level.car_3d_overlay.helicopter.mesh_count,"; extra viewports=0; shared depth materials=",level.car_3d_overlay.helicopter.scenery_depth.materials.size())
    level.queue_free();current_scene=null
    for i in range(4): await process_frame
    await preload("res://tools/level3_test_teardown.gd").drain_audio(self)
    print("AIRFRAME DEPTH: PASS — actual opaque/foliage depth, transparent holes, front/back, shared-camera roll and idle budget")
    quit(0)

func _case(wall: bool,front: bool,roll: float) -> bool:
    var r=level.renderer;var p=level.controller.player;var d=level.controller.pursuit
    var vp:=Vector2(root.size);var world_z: float=p.world_z+50
    var ground:=Data.road_height(world_z)
    var plane:=Vector3(p.world_x+5,ground,world_z)
    var group={"z":world_z,"points":PackedVector3Array([plane]),"detail":PackedByteArray([0]),"faces":[],"lines":[],"sprites":[],"boards":[],"bounds":AABB(plane-Vector3(4,0,0),Vector3(8,10,.1))}
    if wall:
        group.points=PackedVector3Array([plane+Vector3(-14,0,0),plane+Vector3(14,0,0),plane+Vector3(14,12,0),plane+Vector3(-14,12,0)])
        group.detail=PackedByteArray([0,0,0,0]);group.bounds=AABB(plane-Vector3(14,0,0),Vector3(28,12,.1))
        for ids in [PackedInt32Array([0,1,2]),PackedInt32Array([0,2,3])]:
            group.faces.append({"indices":ids,"color":Color("685762"),"normal":Vector3.ZERO,"detail":false,"ground_clip":false})
    else: group.sprites=[{"point":0,"texture":r.pine_texture,"width":8.0,"height":10.0,"tint":Color("80998c")}]
    r.scenery.groups={floori(world_z/16):group}
    level.camera_state.roll=roll;level.camera_state.yaw_offset=.06 if roll!=0 else 0.0
    r.scenery.frame.configure(r,vp)
    var frame=r.scenery.frame
    var eye: Vector3=frame.inverse*Vector3(0,frame.vertical/frame.focal,0)
    var target_z: float=p.world_z+(25 if front else 90)
    var ratio: float=(target_z-eye.z)/(world_z-eye.z)
    var target:=eye+(plane+Vector3(1.5,6,0)-eye)*ratio
    d.phase=&"drop";d.phase_time=0
    d.helicopter_x=target.x;d.helicopter_z=target.z;d.helicopter_height=target.y-Data.road_height(target.z)
    d.helicopter_yaw=-.5
    level.car_3d_overlay.sync_from_race_car(p,level.controller.track_x,vp,level.camera_state,0,.016)
    r.queue_redraw()
    var heli=level.car_3d_overlay.helicopter
    var masked: Image=await _image()
    # Actual submitted vertices must already be clipped on the CPU. A fragment
    # shader discard with a full road mesh passed the old visual-only gate.
    var mask=heli.scenery_depth
    if mask.entries.size()!=2:
        return _fail("depth mask duplicated source submissions",wall,front,roll,masked,masked,masked)
    for entry in mask.entries:
        for vertex: Vector3 in entry.v:
            if not mask.bounds.grow(.02).has_point(Vector2(vertex.x,vertex.y)):
                return _fail("unclipped full-screen scenery submitted",wall,front,roll,masked,masked,masked)
    print("AIRFRAME MASK: source/submitted=",mask.source_triangles,"/",mask.submitted_triangles," CPU us=",mask.build_usec," rectangle=",mask.bounds)
    heli.scenery_depth.set_enabled(false)
    var unmasked: Image=await _image()
    heli.root.hide()
    var bare: Image=await _image()
    var right:=Vector3(cos(level.camera_state.yaw_offset),0,-sin(level.camera_state.yaw_offset))*4
    var bl: Vector2=frame.project(frame.transform*(plane-right))
    var br: Vector2=frame.project(frame.transform*(plane+right))
    var tl: Vector2=frame.project(frame.transform*(plane-right+Vector3.UP*10))
    var to_uv:=Transform2D(br-bl,tl-bl,bl).affine_inverse()
    var texture: Image=r.scenery.atlas.get_image()
    var region: Rect2=r.scenery.sprite_regions[r.pine_texture]
    if texture.is_compressed(): texture.decompress()
    var hidden:=0;var clear:=0;var visible:=0
    for y in range(12,int(vp.y*r.PLAYFIELD_FRACTION)-16,2):
        for x in range(4,int(vp.x)-4,2):
            var point:=Vector2i(x,y)
            if _difference(unmasked.get_pixelv(point),bare.get_pixelv(point))<.09: continue
            visible+=1
            var uv: Vector2=to_uv*(Vector2(point)+Vector2(.5,.5))
            var alpha:=0.0
            var minimum:=0.0;var maximum:=0.0
            if uv.x>.02 and uv.x<.98 and uv.y>.02 and uv.y<.98:
                var atlas_uv: Vector2=region.position+Vector2(uv.x,1-uv.y)*region.size
                var pixel:=atlas_uv*Vector2(texture.get_size())-Vector2(.5,.5)
                var first:=Vector2i(pixel.floor());minimum=1.0
                for oy in range(2):
                    for ox in range(2):
                        var sample_: float=texture.get_pixel(first.x+ox,first.y+oy).a
                        minimum=minf(minimum,sample_);maximum=maxf(maximum,sample_)
                alpha=(minimum+maximum)*.5
            var difference:=_difference(masked.get_pixelv(point),bare.get_pixelv(point))
            if wall and not front:
                if difference>.035: return _fail("opaque wall leaks aircraft",wall,front,roll,masked,unmasked,bare)
                hidden+=1
            elif not front and minimum>.98:
                if difference>.055:
                    print("OPAQUE PROBE: pixel=",point," uv=",uv," alpha=",alpha," transform=",level.car_3d_overlay.get_transform())
                    return _fail("opaque tree pixels leak aircraft",wall,front,roll,masked,unmasked,bare)
                hidden+=1
            elif front or maximum<.01:
                if _difference(masked.get_pixelv(point),unmasked.get_pixelv(point))>.07:
                    print("AIRFRAME PROBE: pixel=",point," uv=",uv," alpha=",alpha," screen corners=",[bl,br,tl])
                    return _fail("near craft or foliage hole incorrectly clipped",wall,front,roll,masked,unmasked,bare)
                clear+=1
    if visible<40 or (not front and hidden<15) or (not wall and clear<15):
        return _fail("insufficient silhouette/occlusion probes: %s"%[str([visible,hidden,clear])],wall,front,roll,masked,unmasked,bare)
    masked.save_png(output+"/"+str(root.size.x)+"-"+("wall" if wall else "tree")+("-front" if front else "-behind")+str(roll)+".png")
    print("AIRFRAME DEPTH: size/wall/front/roll=",root.size,"/",wall,"/",front,"/",roll," visible/hidden/clear=",[visible,hidden,clear])
    return true

func _difference(a: Color,b: Color) -> float:
    return maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b)))

func _fail(message: String,wall: bool,front: bool,roll: float,a: Image,b: Image,c: Image) -> bool:
    print("AIRFRAME DEPTH: proxies/materials=",level.car_3d_overlay.helicopter.scenery_depth.entries.size(),"/",level.car_3d_overlay.helicopter.scenery_depth.materials.size())
    a.save_png(output+"/failed-masked.png");b.save_png(output+"/failed-unmasked.png");c.save_png(output+"/failed-bare.png")
    push_error("AIRFRAME DEPTH: "+message+" wall/front/roll="+str([wall,front,roll]))
    return false
