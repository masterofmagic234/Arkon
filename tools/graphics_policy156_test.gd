extends SceneTree
## Deterministic policy, persistence and adaptive-window checks. Synthetic frame
## samples exercise decisions; they are not measurements of an Android device.
const Policy = preload("res://scripts/graphics_policy156.gd")
const Store = preload("res://scripts/graphics_store156.gd")
const Monitor = preload("res://scripts/graphics_monitor156.gd")
const Settings = preload("res://scripts/graphics_settings.gd")
const GB := 1024 * 1024 * 1024
var failures: Array[String] = []
var cases: Array = []
var output := "/tmp/graphics-policy156"
var scratch_path := "user://graphics156-qa"

func _init() -> void:
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
    call_deferred("run")

func check(ok: bool, message: String) -> void:
    if not ok:
        failures.append(message)
        push_error("GRAPHICS POLICY156: " + message)

func device(gpu: String, ram_gb: int = 4, model: String = "Unknown Android") -> Dictionary:
    return {"platform":"Android", "gpu_name":gpu, "gpu_vendor":"", "memory_bytes":ram_gb*GB, "model":model, "cpu_cores":8, "headless":false, "software_renderer":false}

func record_hardware(label: String, info: Dictionary, expected: String = "") -> Dictionary:
    var result: Dictionary = Policy.classify_hardware(info)
    check(result.has_all(["profile", "reason", "target_fps", "memory_known", "memory_gb", "software"]), label+" omitted detection evidence")
    check(result.get("profile", "") in ["low", "balanced", "high"], label+" selected invalid profile")
    if expected != "": check(result.get("profile", "") == expected, label+" selected "+str(result.get("profile"))+" instead of "+expected)
    check(not str(result.get("reason", "")).is_empty(), label+" has no explanation")
    cases.append({"case":label, "hardware":info, "result":result})
    return result

func test_hardware() -> void:
    for gpu: String in ["Mali-G52 MC2", "mali g52 mc2", "Adreno (TM) 610", "ADRENO 610"]:
        var result := record_hardware("Redmi10 weak GPU: "+gpu, device(gpu), "low")
        check(int(result.get("target_fps", 0)) == 30, gpu+" did not select a stable 30 FPS target")
    record_hardware("Weak GPU with misleading model", device("Mali-G52 MC2", 8, "Galaxy S23 Ultra"), "low")
    record_hardware("Strong GPU with misleading model", device("Adreno (TM) 740", 8, "Redmi 10"), "high")
    record_hardware("Known middle GPU with confirmed memory", device("Adreno (TM) 640", 6), "balanced")
    record_hardware("Memory pressure despite strong GPU", device("Adreno (TM) 740", 2), "low")
    var unknown_gpu := device("unidentified GPU", 12)
    unknown_gpu.cpu_cores = 64
    var unknown_result := record_hardware("Unknown GPU, many cores", unknown_gpu)
    check(unknown_result.profile != "high", "CPU count or RAM falsely proved an unknown Android GPU fast")
    for value: int in [0, -1]:
        var info := device("Mali-G52 MC2")
        info.memory_bytes = value
        check(not bool(record_hardware("Unknown physical RAM "+str(value), info, "low").get("memory_known", true)), "Unknown physical RAM was treated as measured capacity")
    var missing := device("Mali-G52 MC2")
    missing.erase("memory_bytes")
    check(not bool(record_hardware("Missing physical RAM", missing, "low").get("memory_known", true)), "Missing physical RAM was treated as measured capacity")
    var desktop := device("llvmpipe (LLVM 15.0.6, 256 bits)", 16)
    desktop.platform = "Linux"
    desktop.software_renderer = true
    check(bool(record_hardware("Software renderer is not phone calibration", desktop, "high").get("software", false)), "llvmpipe was not identified as a software renderer")
    var headless := {"platform":"Linux", "headless":true}
    record_hardware("Headless preserves legacy baseline", headless, "high")

func test_profiles() -> void:
    for level_id: StringName in [&"level1", &"level2", &"level3"]:
        var low: Dictionary = Policy.level_settings("low", level_id)
        var high: Dictionary = Policy.level_settings("high", level_id)
        check(not low.is_empty() and not high.is_empty(), str(level_id)+" has no profile settings")
        check(low.get("profile", "") == "low" and high.get("profile", "") == "high", str(level_id)+" profile has wrong identity")
        cases.append({"case":"profile", "level":level_id, "low":low, "high":high, "low_step2":Policy.level_settings("low",level_id,2)})
    var low1: Dictionary = Policy.level_settings("low", &"level1")
    var high1: Dictionary = Policy.level_settings("high", &"level1")
    check(int(low1.get("pixel_budget", 0)) > 0 and int(low1.get("pixel_budget", 0)) < int(high1.get("pixel_budget", 0)), "Level1 low preset did not reduce real 3D pixel budget")
    check(int(low1.get("msaa_3d", -1)) == Viewport.MSAA_DISABLED, "Level1 low retained multisampling")
    var low2: Dictionary = Policy.level_settings("low", &"level2")
    var high2: Dictionary = Policy.level_settings("high", &"level2")
    check(int(low2.get("car_pixel_budget", 0)) > 0 and int(high2.get("car_pixel_budget", -1)) == 0, "Level2 child viewport budget failed to preserve high baseline or reduce low")
    check(int(low2.get("road_rows", 0)) > 0 and int(low2.get("road_rows", 0)) < int(high2.get("road_rows", 0)), "Level2 low did not reduce road construction work")
    var low3: Dictionary = Policy.level_settings("low", &"level3")
    var high3: Dictionary = Policy.level_settings("high", &"level3")
    check(int(low3.get("l3_real_lights", -1)) >= 0 and int(low3.get("l3_real_lights", -1)) < int(high3.get("l3_real_lights", -1)), "Level3 low did not reduce cosmetic light budget")
    var lower1: Dictionary = Policy.level_settings("low", &"level1", 2)
    var lower2: Dictionary = Policy.level_settings("low", &"level2", 2)
    var lower3: Dictionary = Policy.level_settings("low", &"level3", 2)
    check(lower1.pixel_budget<low1.pixel_budget and lower2.car_pixel_budget<low2.car_pixel_budget and lower2.road_rows<low2.road_rows and lower3.l3_real_lights<low3.l3_real_lights, "Adaptive fallback did not reduce per-level cosmetic work")
    check(lower1.target_fps==30 and lower2.target_fps==30 and lower3.target_fps==30, "A capped30 observation promoted the target to60")
    for level_id: StringName in [&"level1",&"level2",&"level3"]:
        var high_fallback: Dictionary=Policy.level_settings("high",level_id,2)
        var middle_fallback: Dictionary=Policy.level_settings("balanced",level_id,1)
        check(high_fallback.profile=="low" and high_fallback.target_fps==30 and high_fallback.base_profile=="high", "High recommendation did not expose its effective low30 fallback")
        check(middle_fallback.profile=="low" and middle_fallback.target_fps==30 and middle_fallback.base_profile=="balanced", "Balanced recommendation did not expose its effective low30 fallback")

func write_text(path: String, contents: String) -> void:
    var file := FileAccess.open(path, FileAccess.WRITE)
    check(file != null, "Cannot create isolated test file "+path)
    if file != null: file.store_string(contents)

func test_store() -> void:
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(scratch_path))
    var path := scratch_path.path_join("graphics.cfg")
    DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
    var fresh: Dictionary = Store.load_config(path)
    check(fresh.get("mode", "") == "auto" and int(fresh.get("schema", 0)) == 1, "Missing config did not start with valid automatic selection")
    var unrelated := scratch_path.path_join("settings.cfg")
    const SENTINEL := "[audio]\nmuted=true\n[player]\ncheckpoint=17\n"
    write_text(unrelated, SENTINEL)
    for mode: String in ["low", "balanced", "high", "auto"]:
        var saved := {"schema":1, "mode":mode, "hardware_fingerprint":"qa156-device-a", "adaptive_steps":{"level1":2, "level2":1, "level3":0}}
        check(Store.save_config(path, saved) == OK, "Atomic config save failed for "+mode)
        var reloaded: Dictionary = Store.load_config(path)
        check(reloaded.get("mode", "") == mode and reloaded.get("hardware_fingerprint", "") == saved.hardware_fingerprint, "Config round trip lost manual selection/fingerprint")
        check(reloaded.get("adaptive_steps", {}) == saved.adaptive_steps, "Config round trip lost per-level adaptation")
    check(FileAccess.get_file_as_string(unrelated) == SENTINEL, "Graphics persistence overwrote unrelated settings")
    write_text(path, "not a valid config [=\n@@broken")
    # ConfigFile logs its deliberately induced syntax failure before returning
    # ERR_PARSE_ERROR. Suppress only this expected negative-case diagnostic;
    # all production parser/shader/runtime errors remain enabled throughout QA.
    var errors_were_enabled := Engine.print_error_messages
    Engine.print_error_messages=false
    var corrupt: Dictionary = Store.load_config(path)
    Engine.print_error_messages=errors_were_enabled
    check(corrupt.get("mode", "") == "auto" and corrupt.get("adaptive_steps", {}) is Dictionary, "Corrupt config prevented sane first launch")
    var invalid := {"schema":1,"mode":"ultra-invalid","hardware_fingerprint":"x","adaptive_steps":{"level1":-8,"level2":999,"unknown":100}}
    check(Store.save_config(path, invalid) == OK, "Malformed values could not be safely sanitized")
    var sanitized: Dictionary = Store.load_config(path)
    check(sanitized.get("mode", "") == "auto", "Invalid stored mode was not sanitized")
    for step in sanitized.get("adaptive_steps", {}).values():
        check(step is int and int(step) >= 0 and int(step) <= 2, "Stored adaptive step escaped supported bounds")
    for bad_schema in [2, "not-an-integer", {}]:
        check(Store.save_config(path,{"schema":bad_schema,"mode":"high"})==OK, "Could not prepare invalid-schema case")
        var migration: Dictionary=Store.load_config(path)
        check(migration.get("mode", "") == "auto" and migration.get("adaptive_steps", {}) is Dictionary, "Unsupported/corrupt schema did not recover automatic selection")
    cases.append({"case":"store","fresh":fresh,"corrupt":corrupt,"sanitized":sanitized})

func monitor_segment(monitor: RefCounted, start_usec: int, count: int, frame_ms: float, active: bool = true, target: int = 30) -> Dictionary:
    var now := start_usec
    var degraded := 0
    for i in range(count):
        now += roundi(frame_ms*1000.0)
        if monitor.observe(now, frame_ms, active, target): degraded += 1
    return {"now":now,"degraded":degraded,"diagnostics":monitor.diagnostics()}

func test_monitor() -> void:
    var monitor := Monitor.new()
    monitor.reset(0, 3.0)
    var warmup := monitor_segment(monitor, 0, 25, 80.0)
    check(warmup.degraded == 0, "Loading/warmup frames triggered a downgrade")
    monitor.reset(0, 0.0)
    var capped := monitor_segment(monitor, 0, 1500, 1000.0/30.0)
    check(capped.degraded == 0, "Stable capped 30 FPS was treated as failed performance")
    monitor.reset(0, 0.0)
    var fast := monitor_segment(monitor, 0, 2400, 1000.0/60.0, true, 60)
    check(fast.degraded == 0, "Stable 60 FPS triggered degradation")
    monitor.reset(0, 0.0)
    var stable := monitor_segment(monitor, 0, 300, 1000.0/30.0)
    var spike := monitor_segment(monitor, stable.now, 1, 1000.0)
    var after_spike := monitor_segment(monitor, spike.now, 900, 1000.0/30.0)
    check(stable.degraded+spike.degraded+after_spike.degraded == 0, "A temporary isolated one-second stall lowered quality")
    monitor.reset(0, 0.0)
    var paused := monitor_segment(monitor, 0, 300, 100.0, false)
    monitor.note_invalid(paused.now)
    var after_pause := monitor_segment(monitor, paused.now, 300, 1000.0/30.0)
    check(paused.degraded+after_pause.degraded == 0, "Paused/background invalid frames contaminated gameplay adaptation")
    monitor.reset(0, 0.0)
    var sustained := monitor_segment(monitor, 0, 1000, 66.667)
    check(sustained.degraded > 0, "Sustained active overload never requested reduced cosmetic work")
    var near_target_cases: Array=[]
    for frame_ms: float in [38.0,40.0]:
        var near_monitor:=Monitor.new()
        near_monitor.reset(0,0.0)
        var near_result:=monitor_segment(near_monitor,0,800,frame_ms)
        check(near_result.degraded>0,"Steady "+str(frame_ms)+"ms gameplay never triggered fallback below30FPS")
        near_target_cases.append({"frame_ms":frame_ms,"sustained":near_result})
    var jitter_monitor:=Monitor.new()
    jitter_monitor.reset(0,0.0)
    var jitter_now:=0
    var jitter_degraded:=0
    for frame in range(2000):
        var frame_ms:=50.0 if frame%4==0 else 1000.0/30.0
        jitter_now+=roundi(frame_ms*1000.0)
        if jitter_monitor.observe(jitter_now,frame_ms,true,30):jitter_degraded+=1
    check(jitter_degraded>0,"Recurring25percent50ms jitter was hidden by a capped30 median")
    var jitter_case:={"degraded":jitter_degraded,"diagnostics":jitter_monitor.diagnostics(),"slow_frame_fraction":0.25,"slow_frame_ms":50.0,"other_frame_ms":1000.0/30.0}
    var sparse_cases: Array=[]
    for frame_ms: float in [333.333,600.0]:
        var sparse_monitor := Monitor.new()
        sparse_monitor.reset(0,0.0)
        var gathering := monitor_segment(sparse_monitor,0,23,frame_ms)
        check(gathering.degraded==0 and gathering.diagnostics.windows==0 and gathering.diagnostics.samples==23,"Slow gameplay discarded its incomplete evidence window at "+str(frame_ms)+"ms/frame")
        var overloaded := monitor_segment(sparse_monitor,gathering.now,100,frame_ms)
        check(overloaded.degraded>0,"Sustained "+str(frame_ms)+"ms frames could never trigger adaptive fallback")
        sparse_cases.append({"frame_ms":frame_ms,"gathering":gathering,"sustained":overloaded})
    monitor.reset(0, 0.0)
    var invalids := 0
    for value: float in [0.0, -1.0, NAN, INF]:
        if monitor.observe(1000, value, true, 30): invalids += 1
    check(invalids == 0, "Invalid frame durations were accepted as performance evidence")
    cases.append({"case":"synthetic_monitor","warmup":warmup,"capped30":capped,"stable60":fast,"isolated_one_second_spike":after_spike,"paused":after_pause,"sustained_overload":sustained,"near_target_overload":near_target_cases,"recurring_jitter":jitter_case,"very_slow_active_gameplay":sparse_cases,"physical_phone_benchmark":false})

func ticks(count: int = 2) -> void:
    for index in range(count): await process_frame

func test_settings() -> void:
    var path := scratch_path.path_join("lifecycle.cfg")
    DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
    var original_size := root.size
    var original_scale := root.scaling_3d_scale
    var original_cap := Engine.max_fps
    var original_msaa := root.msaa_3d
    var original_lod := root.mesh_lod_threshold
    var original_occlusion := root.use_occlusion_culling
    var original_canvas := [root.content_scale_mode,root.content_scale_size,root.content_scale_factor,root.canvas_transform,root.msaa_2d]
    var weak := device("Mali-G52 MC2",4,"Redmi 10")
    var settings := Settings.new()
    settings.initialize_for_device(weak,path)
    root.add_child(settings)
    check(settings.get_summary().first_run and settings.get_summary().profile=="low", "Fresh boot did not select the Redmi10 hardware profile")
    check(FileAccess.file_exists(path), "First hardware selection was not persisted")
    var owner1 := Node.new()
    var owner3 := Node.new()
    root.add_child(owner1)
    root.add_child(owner3)
    root.size=Vector2i(2400,1080)
    settings.enter_level(&"level1",owner1)
    settings.apply_root_viewport()
    var low: Dictionary=settings.get_level_settings(&"level1")
    check(root.scaling_3d_scale>0 and root.scaling_3d_scale<1.0, "Low Level1 did not reduce the root internal3D scale")
    check(float(root.size.x)*float(root.size.y)*pow(root.scaling_3d_scale,2)<=float(low.pixel_budget)+2.0, "Root actual3D pixel budget exceeded the selected policy")
    check(root.msaa_3d==Viewport.MSAA_DISABLED and Engine.max_fps==30, "Low Level1 cap/multisampling was not applied")
    check([root.content_scale_mode,root.content_scale_size,root.content_scale_factor,root.canvas_transform,root.msaa_2d]==original_canvas, "Root3D quality changed native2D canvas settings")
    var token: int=settings.suspend_adaptation(owner1)
    check(token>0 and settings.get_summary().suspensions==1 and not settings.get_summary().adaptation_enabled, "Diagnostic suspension did not exclude adaptation")
    var second_token: int=settings.suspend_adaptation(owner3)
    check(second_token>token and settings.get_summary().suspensions==2,"Concurrent diagnostics did not receive independent tokens")
    check(settings.set_mode("high"), "Manual high selection was rejected")
    root.scaling_3d_scale=.8125
    Engine.max_fps=17
    settings.resume_adaptation(token)
    check(settings.get_summary().suspensions==1 and is_equal_approx(root.scaling_3d_scale,.8125) and Engine.max_fps==17,"Resuming one diagnostic overwrote another diagnostic's active viewport")
    settings.resume_adaptation(second_token)
    check(settings.get_summary().suspensions==0 and settings.get_summary().mode=="high" and Engine.max_fps==60, "Diagnostic completion restored an obsolete frame cap or mode")
    check(not settings.set_mode("bad-mode") and settings.get_summary().mode=="high", "Invalid manual selection corrupted the current mode")
    settings.enter_level(&"level3",owner3)
    check(is_equal_approx(root.scaling_3d_scale,1.0), "Entering2D Level3 retained Level1 internal downscaling")
    var replacement_state := [root.scaling_3d_scale,root.msaa_3d,Engine.max_fps]
    settings.leave_level(owner1)
    check(settings.get_summary().active_level=="level3" and [root.scaling_3d_scale,root.msaa_3d,Engine.max_fps]==replacement_state, "An old owner's leave restored settings over the replacement scene")
    settings.leave_level(owner3)
    check(settings.get_summary().active_level=="" and is_equal_approx(root.scaling_3d_scale,1.0), "Leaving a level retained3D downscaling on menu/cinematic")
    settings.queue_free()
    owner1.queue_free()
    owner3.queue_free()
    await ticks()
    var restarted := Settings.new()
    restarted.initialize_for_device(device("Adreno (TM) 610",4,"New phone model"),path)
    root.add_child(restarted)
    check(not restarted.get_summary().first_run and restarted.get_summary().mode=="high" and restarted.get_summary().profile=="high", "Saved manual override was lost after restart or hardware change")
    restarted.set_mode("auto")
    check(restarted.get_summary().profile=="low", "Returning to auto did not recover hardware selection")
    # Restart on the same device preserves independent per-level fallbacks;
    # a hardware fingerprint change discards that learning without losing mode.
    var learned: Dictionary=Store.load_config(path)
    learned.adaptive_steps={"level1":2,"level2":1,"level3":0}
    check(Store.save_config(path,learned)==OK,"Could not prepare persisted per-level fallback")
    restarted.initialize_for_device(device("Adreno (TM) 610",4,"New phone model"),path)
    check(restarted.get_level_settings(&"level1").dynamic_step==2 and restarted.get_level_settings(&"level2").dynamic_step==1 and restarted.get_level_settings(&"level3").dynamic_step==0,"Restart lost independent per-level adaptation")
    restarted.initialize_for_device(weak,path)
    check(restarted.get_level_settings(&"level1").dynamic_step==0 and restarted.get_summary().mode=="auto","New device inherited stale performance calibration")
    # Both the explicit hardware metadata and the actual renderer environment
    # must exclude software/headless runs from performance learning.
    var observer := Node.new()
    root.add_child(observer)
    var software := device("llvmpipe",16)
    software.software_renderer=true
    software.platform="Linux"
    restarted.initialize_for_device(software,path)
    restarted.enter_level(&"level2",observer)
    check(not restarted.get_summary().adaptation_enabled, "Software renderer entered phone calibration")
    var desktop := device("NVIDIA GeForce",16)
    desktop.platform="Linux"
    restarted.initialize_for_device(desktop,path)
    check(not restarted.get_summary().adaptation_enabled, "Desktop rendering entered Android calibration")
    if DisplayServer.get_name()=="headless":
        restarted.initialize_for_device(weak,path)
        check(not restarted.get_summary().adaptation_enabled, "Injected phone metadata enabled actual headless calibration")
    restarted.initialize_for_device({"platform":"Linux","headless":true},path)
    var samples_before: Dictionary=restarted.get_summary().adaptive_steps.duplicate(true)
    for frame in range(120): restarted.observe_frame(observer,&"level2",true)
    check(samples_before==restarted.get_summary().adaptive_steps, "Headless fast loops learned a phone performance result")
    restarted.leave_level(observer)
    cases.append({"case":"lifecycle_and_restart","manual_override_preserved":true,"headless_not_benchmarked":true,"final_summary":restarted.get_summary()})
    restarted.queue_free()
    observer.queue_free()
    await ticks()
    root.size=original_size
    root.scaling_3d_scale=original_scale
    root.msaa_3d=original_msaa
    root.mesh_lod_threshold=original_lod
    root.use_occlusion_culling=original_occlusion
    Engine.max_fps=original_cap

func run() -> void:
    DirAccess.make_dir_recursive_absolute(output)
    var physics_before := Engine.physics_ticks_per_second
    var time_before := Engine.time_scale
    test_hardware()
    test_profiles()
    test_store()
    test_monitor()
    await test_settings()
    check(Engine.physics_ticks_per_second == physics_before and Engine.physics_ticks_per_second == 60, "Graphics policy changed the 60 Hz physics clock")
    check(is_equal_approx(Engine.time_scale, time_before) and is_equal_approx(Engine.time_scale, 1.0), "Graphics policy changed simulation time")
    var report := {"result":"PASS" if failures.is_empty() else "FAIL", "failures":failures, "cases":cases, "scope":"Pure hardware/config decisions and synthetic adaptation windows, not physical Redmi FPS", "engine":Engine.get_version_info()}
    var file := FileAccess.open(output.path_join("report.json"),FileAccess.WRITE)
    check(file != null, "Could not save QA report")
    if file != null: file.store_string(JSON.stringify(report,"  "))
    if failures.is_empty(): print("GRAPHICS POLICY156: PASS")
    quit(0 if failures.is_empty() else 1)
