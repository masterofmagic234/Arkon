extends SceneTree
## Compare actual decoded frames through the garment shader with the identical
## paused frame without it. No colour-altered media or generated mask snapshots.
const CLIPS: Array[String] = ["1789650644963","1789649201942","1789650878847","1789649329293"]
const HASHES: Array[String] = ["810c16f536a570d948bdac2d03bbffb73939fd1c73bdeb2e2880997e39cda624","26ce479cb0e4d75ae755c574c1d7e88f44683b97298cf1821ea0688e98d02e9b","602e1aad77942afe00fb8c1a2fee8b837b22d4adf70abbdacfa9af12ca835dd8","bfae1c4aea8301f0329406f604e2ea8af71ccafa33cd701001f0e63566b165c5"]
var output := "user://pajamas151"
var visual := false
var player: VideoStreamPlayer
var garment: ShaderMaterial
var report := {"passed":false,"frames":[],"captures":[],"original_videos_unchanged":true,"sampled_step":2,"difference_threshold":.02,"adult_envelope":[69,205,444,510],"comparison":"identical paused decoded texture; GPU shader enabled versus removed"}

func _init() -> void:
    for arg in OS.get_cmdline_user_args():
        if arg=="--visual":visual=true
        elif arg.begins_with("--output="):output=arg.trim_prefix("--output=")
    call_deferred("_run")

func _write() -> void:
    DirAccess.make_dir_recursive_absolute(output)
    var file := FileAccess.open(output.path_join("pajamas151-report.json"),FileAccess.WRITE)
    file.store_string(JSON.stringify(report,"  "))

func _fail(message: String) -> void:
    report["failure"]=message;_write();push_error("PAJAMAS151: "+message);quit(1)

func _draw() -> void:
    await process_frame
    if visual:
        RenderingServer.call_deferred("force_draw",false)
        await RenderingServer.frame_post_draw

func _sample(clip_index: int, at: float) -> bool:
    player.paused=true
    garment.set_shader_parameter("seated",1.0 if clip_index==3 else smoothstep(.3,3.4,at) if clip_index==2 else 0.0)
    preload("res://scripts/cinematic_garment151.gd").apply(garment,clip_index,player.stream_position)
    player.material=garment
    await _draw();await _draw()
    var changed := root.get_texture().get_image()
    player.material=null
    await _draw();await _draw()
    var original := root.get_texture().get_image()
    player.material=garment
    var changed_count:=0;var outside_count:=0;var child_count:=0;var protected_count:=0
    var residual_pink:=0;var original_pink:=0;var probe_pink:=0;var probe_remaining:=0
    var cuff_pink:=0;var cuff_remaining:=0;var face_changes:=0;var arm_changes:=0
    var cuff_probe:=Vector2(355,309);var face_probe:=Vector2(286,214);var arm_probe:=Vector2(346,372)
    if clip_index==0:
        cuff_probe=Vector2(321,353) if at<2 else Vector2(339,347)
        face_probe=Vector2(174,351) if at<1 else Vector2(192,330) if at<2 else Vector2(224,309)
        arm_probe=Vector2(320,370) if at<2 else Vector2(330,374)
    elif clip_index==1:
        cuff_probe=Vector2(339,347);face_probe=Vector2(226,311);arm_probe=Vector2(332,370)
    elif clip_index==2:
        if at<1:cuff_probe=Vector2(339,347);face_probe=Vector2(226,311);arm_probe=Vector2(330,373)
        elif at<2:cuff_probe=Vector2(315,267);face_probe=Vector2(205,204);arm_probe=Vector2(345,342)
    var probe:=Vector2(300,350)
    if clip_index==0:probe=Vector2(283,351) if at<2 else Vector2(297,346)
    if clip_index==2 and at>1 and at<2:probe=Vector2(205,317)
    for y in range(0,720,2):
        for x in range(0,1280,2):
            var before:=original.get_pixel(x,y)
            var after:=changed.get_pixel(x,y)
            var delta:=maxf(absf(before.r-after.r),maxf(absf(before.g-after.g),absf(before.b-after.b)))
            if delta>.02:
                if Vector2(x,y).distance_to(face_probe)<7:face_changes+=1
                if Vector2(x,y).distance_to(arm_probe)<6:arm_changes+=1
                changed_count+=1
                if x<69 or x>443 or y<205 or y>509:outside_count+=1
                if x>=720:child_count+=1
                if (x>=380 and x<=440 and y>=226 and y<=308) or (x>=380 and x<=440 and y>=350 and y<=420):protected_count+=1
            if Vector2(x,y).distance_to(cuff_probe)<4 and before.r-before.g>.16 and before.b-before.g>-.03:
                cuff_pink+=1
                if after.r-after.g>.13 and after.b-after.g>-.03:cuff_remaining+=1
            # Highly saturated warm-pink cloth, excluding red hair (b/r<.5).
            if x>=70 and x<=440 and y>=226 and y<=507 and before.b-before.g>.11 and before.r-before.g>.16 and before.b/maxf(before.r,.001)>.55:
                original_pink+=1
                if after.b-after.g>.09 and after.r-after.g>.13:residual_pink+=1
                if Vector2(x,y).distance_to(probe)<12:
                    probe_pink+=1
                    if after.b-after.g>.09 and after.r-after.g>.13:probe_remaining+=1
    var name:="clip-%d-%03d"%[clip_index,int(at*100)]
    var path:=output.path_join(name+".png")
    var original_path:=output.path_join(name+"-original.png")
    changed.save_png(path);original.save_png(original_path)
    report.captures.append(path);report.captures.append(original_path)
    var data:={"clip":clip_index,"position":player.stream_position,"original_png":original_path,"changed_png":path,"changed_pixels":changed_count,"outside_adult_changes":outside_count,"child_changes":child_count,"original_saturated_pink":original_pink,"remaining_saturated_pink_including_room":residual_pink,"protected_room_changes":protected_count,"cloth_probe_position":[probe.x,probe.y],"cuff_probe_position":[cuff_probe.x,cuff_probe.y],"face_probe_position":[face_probe.x,face_probe.y],"arm_probe_position":[arm_probe.x,arm_probe.y],"cloth_probe_original":probe_pink,"cloth_probe_remaining":probe_remaining,"cuff_probe_original":cuff_pink,"cuff_probe_remaining":cuff_remaining,"face_changes":face_changes,"bare_arm_changes":arm_changes}
    report.frames.append(data)
    if outside_count>0 or child_count>0 or protected_count>0:
        _fail("garment changes pixels outside adult envelope at "+name);return false
    if face_changes>0 or arm_changes>0:
        _fail("face/bare-arm protected probe changed at "+name);return false
    if cuff_pink<3 or cuff_remaining>0:
        _fail("warm cuff cloth remains at "+name);return false
    if probe_pink<10 or probe_remaining>probe_pink*.03:
        _fail("saturated pink cloth remains at "+name);return false
    player.paused=false
    return true

func _run() -> void:
    for index in range(4):
        var path:="res://"+CLIPS[index]+".mp4"
        if FileAccess.get_sha256(path)!=HASHES[index]:_fail("approved source clip hash changed");return
    if not visual:
        report.passed=true;_write();print("PAJAMAS151: PASS / four original videos retain exact bytes; native frame checks require --visual");quit(0);return
    root.size=Vector2i(1280,720);root.content_scale_size=Vector2i(1280,720)
    DirAccess.make_dir_recursive_absolute(output)
    player=VideoStreamPlayer.new();player.expand=true;player.size=Vector2(1280,720);player.volume_db=-80
    garment=ShaderMaterial.new();garment.shader=load("res://shaders/cinematics/intro_pajamas151.gdshader")
    player.material=garment;root.add_child(player)
    for index in range(4):
        var stream:=VideoStreamTheora.new();stream.file="res://assets/intro_video/"+CLIPS[index]+".ogv"
        player.stream=stream;player.play()
        for at in [.2,1.5,3.3]:
            var deadline:=Time.get_ticks_msec()+12000
            while player.stream_position<float(at) and Time.get_ticks_msec()<deadline:await _draw()
            if player.stream_position<float(at):_fail("decoder did not reach sample");return
            if not await _sample(index,float(at)):return
        player.stop();player.stream=null
        await _draw()
    player.queue_free();player=null;garment=null
    for frame in range(5):await _draw()
    report.passed=true;_write();call_deferred("_finish")

func _finish() -> void:
    print("PAJAMAS151: PASS / 12 actual decoded frames, isolated adult garment recolour, original media retained")
    quit(0)
