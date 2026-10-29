extends SceneTree
## Runtime story, canonical-room identity, playback controls and native review.
const ENDING := "res://scenes/ending_cutscene.tscn"
const ROOM := "res://assets/cinematics/ending151/room.png"
const ORIGINAL := "res://art/intro/runway144/keyframes/01-sleep.png"
const EXPECTED_SHA := "6baa5984fb110c6bfab3a992d8157d129c3b52a01a7ed5721cb2149e6a25344f"
var visual := false
var output := "user://ending151"
var report := {"passed":false,"captures":[],"checks":[],"staged_captures":true}
var flow: Node
var state: Node
var pause: Node

func _init() -> void:
    for arg in OS.get_cmdline_user_args():
        if arg == "--visual": visual=true
        elif arg.begins_with("--output="): output=arg.trim_prefix("--output=")
    call_deferred("_run")

func _save() -> void:
    DirAccess.make_dir_recursive_absolute(output)
    var f := FileAccess.open(output.path_join("ending151-report.json"),FileAccess.WRITE)
    f.store_string(JSON.stringify(report,"  "))

func _check(ok: bool, message: String) -> bool:
    report.checks.append({"check":message,"passed":ok})
    if not ok:
        report["failure"]=message
        _save()
        push_error("ENDING151: "+message)
        quit(1)
    return ok

func _draw() -> void:
    await process_frame
    if visual:
        RenderingServer.call_deferred("force_draw",false)
        await RenderingServer.frame_post_draw

func _wait(path: String) -> bool:
    var deadline := Time.get_ticks_msec()+20000
    while Time.get_ticks_msec()<deadline:
        await _draw()
        if current_scene!=null and current_scene.scene_file_path==path and not bool(flow.get("_transitioning")):
            return true
    return false

func _capture(scene: Node, time: float, name: String) -> bool:
    scene.seek_for_capture(time)
    scene.set_process(false)
    await _draw()
    if not visual:return true
    var picture := root.get_texture().get_image()
    if not _check(picture!=null and not picture.is_empty(),"nonempty framebuffer "+name):return false
    var file := output.path_join(name+".png")
    if not _check(picture.save_png(file)==OK,"save native "+name):return false
    report.captures.append(file)
    return true

func _run() -> void:
    DirAccess.make_dir_recursive_absolute(output)
    root.size=Vector2i(1280,720)
    flow=root.get_node("SceneFlow");state=root.get_node("GameState");pause=root.get_node("PauseManager")
    pause.resume()
    var hash := FileAccess.get_sha256(ROOM)
    report["canonical_room_sha256"]=hash
    report["original_sha256"]=FileAccess.get_sha256(ORIGINAL)
    if not _check(hash==EXPECTED_SHA and hash==FileAccess.get_sha256(ORIGINAL),"same original room PNG bytes"):return
    flow.go_to(&"ending")
    if not _check(await _wait(ENDING),"ending entered through SceneFlow and became ready"):return
    var scene := current_scene
    if not _check(scene.ready_for_playback and scene.ready_for_play,"ready signals after layers and controls built"):return
    if not _check(scene.get("_room").texture.resource_path==ROOM,"canonical plate is actual room layer"):return
    var size: Vector2=scene.SOURCE_SIZE
    var room_size: Vector2=scene.get("_room").size
    if not _check(size==Vector2(1672,941) and room_size==size,"original room proportions and full plate bounds"):return
    if not _check(scene.get("_craft").size==Vector2(74,78) and scene.get("_squirrel").size==Vector2(182,155),"transparent prop sizes match desk and window, not full source image minimum"):return
    var polygon: PackedVector2Array=scene.get("_wake").polygon
    var minimum:=Vector2(INF,INF);var maximum:=Vector2(-INF,-INF)
    for p in polygon:minimum=minimum.min(p);maximum=maximum.max(p)
    report["acting_patch_bounds"]={"min":[minimum.x,minimum.y],"max":[maximum.x,maximum.y]}
    if not _check(minimum.x>=80 and minimum.y>=220 and maximum.x<=520 and maximum.y<=610,"new acting remains within authored bed/person patch"):return
    if not _check(scene.HER_MESSAGE=="Ты не поверишь что мне только что приснилось......" and scene.HIS_MESSAGE=="вещай, любимая","exact phone exchange"):return
    for cue in ["gasp","narration","twist","squirrel"]:
        var player: AudioStreamPlayer=scene.get("_audio")[cue]
        if not _check(player.stream!=null and player.stream.get_length()>.1,"decoded audio cue "+cue):return
    var narration: AudioStreamPlayer=scene.get("_audio").narration
    if not _check(narration.stream.get_length()>11 and narration.stream.get_length()<16,"Russian narration complete at measured duration"):return
    # Ordinary processing, actual pause state and sound controls, before staged
    # frame inspection. Staging below makes every visual moment reviewable.
    var started: float=scene.elapsed
    for frame in range(5):await _draw()
    if not _check(scene.elapsed>started,"ordinary timeline advances"):return
    pause.set_paused(true)
    var paused_at: float=scene.elapsed
    for frame in range(4):await _draw()
    if not _check(is_equal_approx(scene.elapsed,paused_at),"pause freezes cinematic timeline"):return
    pause.resume()
    var previous_muted: bool=state.sfx_muted
    scene._toggle_sound()
    if not _check(state.sfx_muted!=previous_muted,"sound button uses saved game sound settings"):return
    scene._toggle_sound()
    var phases := [[.6,"sleep","01-same-room"],[3.2,"wake","02-nightmare"],[8.8,"take_phone","03-phone-in-hands"],[14.5,"phone_chat","04-message"],[21.5,"phone_chat","05-danil-reply"],[25.2,"typing_room","06-return-room"],[38.2,"window","07-slow-window-push"],[48.5,"window","08-window-silence"],[50.2,"twist","09-or-not"],[53.0,"squirrel","10-squirrel"],[60.0,"credits","11-credits"]]
    for phase in phases:
        if not await _capture(scene,float(phase[0]),String(phase[2])):return
        if not _check(scene.stage_at(float(phase[0]))==phase[1],"chronological stage "+String(phase[2])):return
        if phase[1]=="wake" and not _check(scene.get("_wake").modulate.a>.99 and scene.get("_phone").modulate.a==0,"wake pose precedes taking phone"):return
        if phase[2]=="05-danil-reply" and not _check(scene.get("_his_bubble").visible and scene.get("_her_bubble").visible,"chat shows both exact messages"):return
        if phase[2]=="06-return-room" and not _check(not scene.get("_phone_screen").visible and scene.get("_phone").modulate.a>.99,"return to same room while holding phone"):return
        if phase[2]=="08-window-silence" and not _check(scene.get("_subtitle").text=="......" and not scene.get("_squirrel").visible,"silence before squirrel reveal"):return
        if phase[2]=="09-or-not" and not _check(scene.get("_subtitle").text=="......Или нет??" and not scene.get("_squirrel").visible,"exact twist before reveal"):return
        if phase[2]=="10-squirrel" and not _check(scene.get("_squirrel").visible and scene.get("_squirrel").modulate.a>.99,"squirrel appears outside window before credits"):return
    if visual:
        if not await _capture(scene,8.92,"03b-subtle-typing-motion"):return
        var waking := Image.load_from_file(output.path_join("02-nightmare.png"))
        var phone := Image.load_from_file(output.path_join("03-phone-in-hands.png"))
        var typing := Image.load_from_file(output.path_join("03b-subtle-typing-motion.png"))
        var room_changes:=0;var hand_changes:=0
        var person_rect:=Rect2i(64,168,332,292)
        var old_phone_rect:=Rect2i(284,479,164,81)
        for y in range(0,720,3):
            for x in range(0,1280,3):
                var point:=Vector2i(x,y)
                if not person_rect.has_point(point) and not old_phone_rect.has_point(point):
                    var before:=waking.get_pixel(x,y);var after:=phone.get_pixel(x,y)
                    if maxf(absf(before.r-after.r),maxf(absf(before.g-after.g),absf(before.b-after.b)))>.01:room_changes+=1
                if Rect2i(205,338,123,110).has_point(point):
                    var before:=phone.get_pixel(x,y);var after:=typing.get_pixel(x,y)
                    if maxf(absf(before.r-after.r),maxf(absf(before.g-after.g),absf(before.b-after.b)))>.008:hand_changes+=1
        report["room_pixel_comparison"]={"before":"02-nightmare.png","after":"03-phone-in-hands.png","sampled_step":3,"outside_authorized_person_phone_changes":room_changes,"threshold":.01}
        report["typing_motion"]={"before":"03-phone-in-hands.png","after":"03b-subtle-typing-motion.png","sampled_step":3,"hand_changed_samples":hand_changes,"threshold":.008}
        if not _check(room_changes==0,"actual room pixels outside local person/removed-phone patches stay identical"):return
        if not _check(hand_changes>=3,"local phone-hand typing produces visible subpixel motion"):return
    if not await _capture(scene,81.0,"12-closing-credits"):return
    report["credits_height"]=scene.get("_credits_height")
    if not _check(scene.get("_credits_body").position.y+float(scene.get("_credits_height"))<=566,"complete credits including final line reach visible screen before finish"):return
    for screen in [Vector2i(854,480),Vector2i(1600,720)]:
        root.size=screen;await _draw();await _draw()
        var frame: Control=scene.get("_frame")
        var bounds:=Rect2(frame.position,frame.size*frame.scale)
        if not _check(bounds.position.x>=-.5 and bounds.position.y>=-.5 and bounds.end.x<=scene.size.x+.5 and bounds.end.y<=scene.size.y+.5,"cinematic composition fits "+str(screen)):return
    root.size=Vector2i(1280,720)
    scene.seek_for_capture(30)
    pause.set_paused(true)
    scene.skip_to_credits()
    if not _check(scene.stage_at(scene.elapsed)=="credits" and not pause.is_paused and not scene.finishing,"skip reaches credits, resumes, does not finish early"):return
    var generation: int=int(flow.get("_generation"))
    scene.finish_to_menu();scene.finish_to_menu()
    if not _check(await _wait("res://menu.tscn"),"credits finish into actual menu"):return
    if not _check(int(flow.get("_generation"))==generation+1,"repeated finish issues exactly one transition"):return
    scene=null
    report["passed"]=true
    _save()
    call_deferred("_cleanup")

func _cleanup() -> void:
    root.get_node("AudioManager").shutdown()
    if is_instance_valid(current_scene):current_scene.queue_free()
    for frame in range(6):await _draw()
    OS.delay_msec(200)
    for frame in range(3):await _draw()
    call_deferred("_finish")

func _finish() -> void:
    print("ENDING151: PASS")
    quit(0)
