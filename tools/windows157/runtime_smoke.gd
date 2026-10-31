extends SceneTree
## Runs in the stock Windows release with its byte-identical shipping PCK through
## a disposable CI-only external bootstrap. Neither fixture nor override ships.
var failures: Array[String] = []
var output := "user://windows157-smoke"
var native := false
var report: Dictionary = {"scenes":[],"videos":[],"captures":[]}
const SCENES := [&"menu",&"intro",&"level1",&"park_escape",&"level2",&"level3",&"ending",&"menu"]

func _init() -> void:
    for argument in OS.get_cmdline_user_args():
        if argument=="--native": native=true
        elif argument.begins_with("--output="): output=argument.trim_prefix("--output=")
    call_deferred("run")

func check(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)
        push_error("WINDOWS157 EXPORTED: "+message)

func wait_for_scene(id: StringName) -> bool:
    var flow := root.get_node("SceneFlow")
    var wanted: String=flow.SCENES[id]
    flow.go_to(id)
    var deadline := Time.get_ticks_msec()+60000
    while Time.get_ticks_msec()<deadline:
        await process_frame
        # A hosted Windows desktop may move foreground focus between CI tools.
        # These are staged scene/resource captures, not an input/focus replay.
        root.get_node("PauseManager").resume()
        if current_scene!=null and current_scene.scene_file_path==wanted and not bool(flow.get("_transitioning")):
            return true
        if is_instance_valid(flow.loading_screen) and bool(flow.loading_screen.failed):
            return false
    return false

func capture(id: StringName, tier: String) -> void:
    root.get_node("GraphicsSettings").set_mode(tier)
    await process_frame
    await process_frame
    RenderingServer.force_draw(true)
    var picture := root.get_texture().get_image()
    check(picture!=null and not picture.is_empty(),"No native framebuffer for "+str(id)+"/"+tier)
    if picture==null or picture.is_empty(): return
    var colours: Dictionary={}
    var minimum := 1.0
    var maximum := 0.0
    for y in range(16,picture.get_height()-16,8):
        for x in range(16,picture.get_width()-16,8):
            var colour := picture.get_pixel(x,y)
            colours[colour.to_rgba32()]=true
            var luminance := colour.r*.2126+colour.g*.7152+colour.b*.0722
            minimum=minf(minimum,luminance);maximum=maxf(maximum,luminance)
    check(colours.size()>24 and maximum-minimum>.08,"Blank native scene: "+str(id)+"/"+tier)
    var file := str(id)+"-"+tier+".png"
    check(picture.save_png(output.path_join(file))==OK,"Could not save actual Windows capture")
    var settings: Dictionary=root.get_node("GraphicsSettings").get_level_settings(id)
    var item := {"scene":String(id),"profile":tier,"file":file,"width":picture.get_width(),"height":picture.get_height(),"colours":colours.size(),"luminance_range":[minimum,maximum],"settings":settings,"root_3d_scale":root.scaling_3d_scale,"draw_calls":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),"triangles":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)}
    if id==&"level1":
        check(current_scene.world!=null and root.get_camera_3d()!=null,"Garden has no actual 3D world/camera")
        check(int(item.triangles)>1000,"Garden native render submitted no world geometry")
    if id==&"level2":
        var target=current_scene.car_3d_overlay
        check(target.ready_3d and target.initial_transforms_flushed,"Windows car target never reached first-frame readiness")
        var car_pixels: Image=target.viewport.get_texture().get_image()
        var nontransparent := 0
        if car_pixels!=null:
            for y in range(0,car_pixels.get_height(),3):
                for x in range(0,car_pixels.get_width(),3):
                    if car_pixels.get_pixel(x,y).a>.1: nontransparent+=1
        check(nontransparent>20,"Actual Windows car viewport is transparent/empty")
        item["car_pixels_sampled"]=nontransparent
        item["car_3d_scale"]=target.viewport.scaling_3d_scale
    report.captures.append(item)
    print("WINDOWS157 CAPTURE: ",id," ",tier," ",file)

func run() -> void:
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
    report["rendering_driver"]=RenderingServer.get_current_rendering_driver_name()
    report["rendering_method"]=RenderingServer.get_current_rendering_method()
    report["gpu_vendor"]=RenderingServer.get_video_adapter_vendor()
    report["gpu_api_version"]=RenderingServer.get_video_adapter_api_version()
    report["gpu"]=RenderingServer.get_video_adapter_name()
    check(OS.get_name()=="Windows","This acceptance must run the Windows executable on Windows")
    check(not OS.has_feature("editor") and not OS.is_debug_build(),"Expected actual release template, not an editor/debug run")
    check(not FileAccess.file_exists("res://tools/windows157/runtime_smoke.gd"),"Acceptance accidentally loaded the source tree instead of the shipping pack")
    check(not FileAccess.file_exists("res://scripts/graphics_settings.gd") and ResourceLoader.exists("res://scripts/graphics_settings.gd"),"Compiled script remap is missing or loose source was loaded")
    check(ProjectSettings.get_setting("application/config/version","")=="1.58","Packaged game version differs")
    check(ProjectSettings.get_setting("rendering/renderer/rendering_method","")=="gl_compatibility","Packaged desktop renderer is not Compatibility")
    check(Engine.physics_ticks_per_second==60 and Engine.time_scale==1.0,"Default physics/game clock changed")
    for singleton in ["GameState","SceneFlow","SignalBus","PauseManager","AudioManager","GraphicsSettings"]:
        check(root.get_node_or_null(singleton)!=null,"Export omitted autoload "+singleton)
    if not failures.is_empty(): finish();return
    root.get_node("GameState").start_new_run()
    root.get_node("GameState").music_muted=true
    root.get_node("GameState").sfx_muted=true
    root.get_node("GraphicsSettings").set_mode("high")
    if native:
        check(DisplayServer.get_name()!="headless","Native acceptance needs a real Windows graphics context")
        check(RenderingServer.get_current_rendering_method()=="gl_compatibility","Windows renderer silently fell back")
        check(report.rendering_driver=="opengl3_angle","Native CI must use the shipped official ANGLE driver")
        var adapter_evidence := (str(report.gpu)+" "+str(report.gpu_api_version)).to_lower()
        check("angle" in adapter_evidence and ("direct3d11" in adapter_evidence or "d3d11" in adapter_evidence),"Native CI must confirm actual ANGLE/Direct3D11 rendering")
        var gpu_name := str(report.gpu).to_lower()
        check("microsoft basic render driver" in gpu_name or "warp" in gpu_name,"Native CI must identify the Microsoft Basic Render Driver/WARP software adapter")
        root.size=Vector2i(1280,720)
        root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
        RenderingServer.set_render_loop_enabled(false)
    else: check(DisplayServer.get_name()=="headless","Headless acceptance invoked with a window")
    var movie_paths: Array[String]=[]
    var intro_manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/intro_video/compiled.json"))
    check(intro_manifest.get("clips",[]).size()==4,"Export lacks four opening videos")
    for clip: Dictionary in intro_manifest.get("clips",[]): movie_paths.append("res://assets/intro_video/"+str(clip.file))
    movie_paths.append("res://assets/cinematics/park_escape/film.ogv")
    for path in movie_paths:
        var stream := load(path) as VideoStreamTheora
        check(stream!=null,"Packaged Windows Theora video cannot load: "+path)
        report.videos.append({"path":path,"type":stream.get_class() if stream!=null else "missing"})
    for id in SCENES:
        if not await wait_for_scene(id):
            check(false,"Exported scene failed to become ready: "+String(id));break
        if id==&"level1":
            check(bool(current_scene.ready_for_play) and current_scene.guard_navigation.is_ready,"Garden navigation never became ready")
            check(current_scene.guards.size()>20,"Garden actor roster missing")
        elif id==&"level2":
            check(bool(current_scene.ready_for_play),"Pursuit never became ready")
            check(current_scene.controller.ais.size()==3,"Pursuit opponent roster missing")
        elif id==&"level3":
            check(bool(current_scene.ready_for_play) and current_scene.navigation.ready,"Diner collision navigation never became ready")
        report.scenes.append({"id":String(id),"actual_path":current_scene.scene_file_path,"ready":true})
        print("WINDOWS157 EXPORTED SCENE: ",id," READY")
        if native and id in [&"level1",&"level2",&"level3"]:
            var previous_mode: int=current_scene.process_mode
            current_scene.process_mode=Node.PROCESS_MODE_DISABLED
            for tier in ["high","low"]: await capture(id,tier)
            current_scene.process_mode=previous_mode
    root.get_node("GraphicsSettings").set_mode("auto")
    if current_scene!=null:
        current_scene.queue_free();current_scene=null
    for frame in range(6): await process_frame
    root.get_node("AudioManager").shutdown()
    var deadline := Time.get_ticks_msec()+350
    while Time.get_ticks_msec()<deadline:
        OS.delay_msec(10)
        await process_frame
    report["scope"]="Stock Windows release executable and byte-identical shipping PCK, using a CI-only external main-scene override/fixture. Native Compatibility captures use shipped ANGLE/Direct3D11 on the Microsoft software adapter where requested. Separate canonical-startup/menu evidence covers the untouched default entry. Not consumer GPU performance, certified minimum specs or a complete gameplay replay."
    report["actual_os"]=OS.get_name()
    report["display"]=DisplayServer.get_name()
    report["gpu"]=RenderingServer.get_video_adapter_name()
    report["native"]=native
    finish()

func finish() -> void:
    report["result"]="PASS" if failures.is_empty() else "FAIL"
    report["failures"]=failures
    var file := FileAccess.open(output.path_join("report.json"),FileAccess.WRITE)
    if file!=null: file.store_string(JSON.stringify(report,"  "))
    else: failures.append("Could not save runtime proof")
    if failures.is_empty(): print("WINDOWS157 EXPORTED: PASS")
    quit(0 if failures.is_empty() else 1)
