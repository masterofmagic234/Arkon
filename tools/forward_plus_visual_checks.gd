extends SceneTree
# Native renderer checks and staged migration captures, not gameplay replay.
const LevelData=preload("res://scripts/level_data.gd")
const RaceData=preload("res://scripts/race_level_data.gd")
const RaceMath=preload("res://scripts/race_math.gd")
const Teardown=preload("res://tools/level3_test_teardown.gd")
var output := "/tmp/forward-plus-visuals"
var expected := "gl_compatibility"
var failed := false
var skip_level1 := false
var report: Dictionary={}
func _init() -> void:
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
        elif arg.begins_with("--expect-renderer="): expected=arg.trim_prefix("--expect-renderer=")
        elif arg=="--skip-level1": skip_level1=true
    call_deferred("_run")
func check(ok: bool, message: String) -> void:
    if not ok: failed=true;push_error("FORWARD+ VISUAL: "+message)
func _run() -> void:
    if DisplayServer.get_name()=="headless": push_error("FORWARD+ VISUAL: native framebuffer required");quit(1);return
    var method:=RenderingServer.get_current_rendering_method()
    check(method==expected,"expected %s, actually running %s"%[expected,method])
    check(ProjectSettings.get_setting("rendering/renderer/rendering_method")=="gl_compatibility","desktop production profile is not Compatibility")
    check(ProjectSettings.get_setting("rendering/renderer/rendering_method.mobile")=="gl_compatibility","phone production profile is not Compatibility")
    check(not root.use_hdr_2d,"2D pixel palette unexpectedly uses HDR")
    if failed: quit(1);return
    DirAccess.make_dir_recursive_absolute(output)
    root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
    root.size=Vector2i(1280,720)
    root.get_node("GameState").music_muted=true;root.get_node("GameState").sfx_muted=true
    RenderingServer.set_render_loop_enabled(false)
    report={"renderer":method,"driver":RenderingServer.get_current_rendering_driver_name(),"adapter":RenderingServer.get_video_adapter_name(),"hdr_2d":root.use_hdr_2d,"legacy_level1_checked":not skip_level1,"views":[]}
    print("FORWARD+ VISUAL: renderer=",method," driver=",report.driver," adapter=",report.adapter)
    await _menu()
    if not skip_level1: await _park()
    await _race();await _diner()
    FileAccess.open(output+"/report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  ")+"\n")
    await Teardown.drain_audio(self)
    if failed: quit(1)
    else:
        print("FORWARD+ VISUAL: PASS — actual ",method,"; desktop/Android profiles; sRGB canvas/alpha; 3D race and pixel squirrels")
        quit(0)
func _menu() -> void:
    var menu:=load("res://menu.tscn").instantiate() as Control
    root.add_child(menu);current_scene=menu
    var status: String=menu.get_node("RendererStatus").text
    check(status.contains("Forward+" if expected=="forward_plus" else "Compatibility"),"menu reports requested rather than active renderer")
    # Isolated test swatches exercise real canvas color and alpha compositing.
    # They never enter the shipped UI or the saved presentation screenshots.
    var canvas:=CanvasLayer.new();root.add_child(canvas);canvas.layer=100
    var colors: Array[Color]=[Color(.2,.4,.6),Color(.8,.3,.1),Color(.2,.75,.35),Color(.8,.3,.1,.5)]
    var background:=Color(.15,.2,.25)
    for i in range(colors.size()):
        var base:=ColorRect.new();base.position=Vector2(8+i*52,8);base.size=Vector2(40,24);base.color=background;canvas.add_child(base)
        var tile:=ColorRect.new();tile.position=base.position;tile.size=base.size;tile.color=colors[i];canvas.add_child(tile)
    var image: Image=await _draw()
    var errors: Array=[]
    for i in range(colors.size()):
        var source: Color=colors[i]
        var wanted:=Color(source.r*source.a+background.r*(1-source.a),source.g*source.a+background.g*(1-source.a),source.b*source.a+background.b*(1-source.a))
        var actual:=image.get_pixel(24+i*52,20)
        var error:=maxf(absf(actual.r-wanted.r),maxf(absf(actual.g-wanted.g),absf(actual.b-wanted.b)))
        check(error<.012,"canvas color/alpha changed at swatch "+str(i));errors.append(error)
    report.canvas_color_errors=errors
    canvas.queue_free()
    await _capture("00-menu");await _discard(menu)
func _park() -> void:
    var game:=load("res://game.tscn").instantiate() as Node3D
    root.add_child(game);current_scene=game
    await _settle(24)
    var player:=game.get_node("Player") as Node3D
    player.set_physics_process(false)
    for enemy in get_nodes_in_group("level1_enemy"): enemy.set_physics_process(false)
    game.get_node("HUD").visible=false
    var camera:=game.get_node("Player/Camera3D") as Camera3D
    var poses: Array=[
        ["01-park-entry",Vector2i(10,54),Vector2i(24,46),2.6],
        ["02-park-pond",Vector2i(31,25),Vector2i(23,20),1.0],
        ["03-park-golden-oak",Vector2i(63,42),Vector2i(64,48),5.0],
    ]
    for pose in poses:
        player.position=LevelData.cell_center_world(pose[1])+Vector3.UP*.9
        player.rotation=Vector3.ZERO
        camera.look_at(LevelData.cell_center_world(pose[2])+Vector3.UP*float(pose[3]))
        await _capture(pose[0])
    await _discard(game)
func _race() -> void:
    var level=load("res://scenes/level2.tscn").instantiate()
    root.add_child(level);current_scene=level
    await _settle(24)
    level.set_process(false);level.set_physics_process(false)
    level.state.race_started=true;level.state.countdown=0
    level.hud_panel.hide_countdown()
    var car=level.controller.player
    var poses: Array=[["04-race-cars",90.0],["05-race-tunnel",RaceData.TUNNEL_START+220.0],["06-race-city",RaceData.CITY_START+480.0]]
    for pose in poses:
        _place(car,pose[1],level);car.speed=45
        car.heading_yaw=atan2(RaceMath.track_center_slope(float(pose[1])/40,level.controller.track_x),40)
        level.camera_state.reset(car)
        for i in range(3):
            var rival=level.controller.ais[i].car
            _place(rival,float(pose[1])+[18,33,48][i],level)
            rival.lateral_offset=[-1.9,1.8,0.0][i];rival.world_x+=rival.lateral_offset
            rival.heading_yaw=atan2(RaceMath.track_center_slope(rival.world_z/40,level.controller.track_x),40)
        for i in range(4): level._process(1.0/60)
        check(level.car_3d_overlay.ready_3d,"race models never became ready")
        check(not level.car_3d_overlay.viewport.use_hdr_2d,"race canvas changed its color space")
        await _capture(pose[0])
    await _discard(level)
func _diner() -> void:
    var game:=load("res://scenes/level3_store.tscn").instantiate() as Level3Store
    root.add_child(game);current_scene=game
    await _settle(24)
    game.set_process(false);game.set_physics_process(false)
    game.player.set_physics_process(false)
    for enemy in game._enemies: enemy.set_physics_process(false)
    game.hud.visible=false;game.camera.position_smoothing_enabled=false
    game.camera.global_position=Vector2(621,533);game.camera.zoom=Vector2.ONE*1.7
    game.camera.reset_smoothing()
    await _capture("07-level3-bar")
    game.player.visible=false;game.pickups_root.visible=false
    var kinds: Array[StringName]=[&"gunman",&"melee",&"butcher"]
    for enemy in game._enemies:
        if not kinds.has(enemy.enemy_kind): enemy.visible=false;continue
        var index: int=[&"gunman",&"melee",&"butcher"].find(enemy.enemy_kind)
        kinds.erase(enemy.enemy_kind)
        enemy.global_position=Vector2(176+index*75,686);enemy.rotation=0
        enemy._animator.configure(enemy._visual,enemy.enemy_kind,0)
        check(enemy._visual.texture_filter==CanvasItem.TEXTURE_FILTER_NEAREST,"squirrel pixel filter changed")
    check(kinds.is_empty(),"squirrel role missing")
    game.camera.global_position=Vector2(251,671);game.camera.zoom=Vector2.ONE*4
    game.camera.reset_smoothing()
    await _capture("08-level3-squirrels");await _discard(game)
func _place(car,z: float,level) -> void:
    var canonical: float=(z+float(car.grid_world_z_offset))/40
    var count: int=level.controller.track_pattern.size()
    car.lap=floori(canonical/count);car.segment_index=posmod(floori(canonical),count);car.segment_progress=canonical-floor(canonical)
    car.world_z=z;car.world_x=RaceMath.track_center_x(z/40,level.controller.track_x);car.lateral_offset=0
func _settle(count: int = 4) -> void:
    for i in range(count):
        root.get_node("PauseManager").set_paused(false)
        await process_frame
func _draw() -> Image:
    await _settle();RenderingServer.force_draw(true)
    return root.get_texture().get_image()
func _capture(name_: String) -> void:
    var image: Image=await _draw()
    check(image!=null and not image.is_empty(),"no framebuffer for "+name_)
    if image==null or image.is_empty(): return
    var low:=1.0;var high:=0.0;var total:=0.0;var count:=0
    var colors: Dictionary={}
    for y in range(24,image.get_height()-32,12):
        for x in range(24,image.get_width()-24,12):
            var color:=image.get_pixel(x,y)
            var luminance:=color.r*.2126+color.g*.7152+color.b*.0722
            low=minf(low,luminance);high=maxf(high,luminance);total+=luminance;count+=1
            colors[color.to_rgba32()]=true
    var mean:=total/maxi(1,count)
    check(high-low>.15 and colors.size()>24 and mean>.006 and mean<.9,"blank/clipped frame: "+name_)
    check(image.save_png(output+"/"+name_+".png")==OK,"cannot save "+name_)
    report.views.append({"name":name_,"mean_luminance":mean,"range":[low,high],"sampled_colors":colors.size()})
    print("FORWARD+ VISUAL: captured ",name_)
func _discard(scene: Node) -> void:
    current_scene=null;scene.queue_free();await _settle(4)
