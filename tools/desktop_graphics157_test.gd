extends SceneTree
## Metadata and persisted-policy regression. No desktop GPU/FPS benchmark.
const Policy = preload("res://scripts/graphics_policy156.gd")
const Store = preload("res://scripts/graphics_store156.gd")
const Settings = preload("res://scripts/graphics_settings.gd")
const GB := 1073741824
var failures: Array[String] = []
var cases: Array[Dictionary] = []
var checks := 0
var output := "user://desktop-graphics157-proof"

func _init() -> void:
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
    call_deferred("run")

func check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures.append(message)
        push_error("DESKTOP GRAPHICS157: " + message)

func device(gpu: String, ram_gb: int = 8) -> Dictionary:
    return {"platform":"Windows", "gpu_name":gpu, "gpu_vendor":"", "memory_bytes":ram_gb * GB, "model":"Unknown PC", "cpu_cores":4, "headless":false, "software_renderer":false}

func hardware_cases() -> void:
    var rows := [
        ["Intel(R) HD Graphics 4000", "low"],
        ["Intel HD5500", "low"],
        ["Intel(R) UHD Graphics 620", "low"],
        ["Intel UHD630", "low"],
        ["Intel(R) Graphics", "low"],
        ["Intel Iris Pro Graphics 5200", "low"],
        ["Intel(R) Iris(R) Xe Graphics", "balanced"],
        ["Intel Iris Plus Graphics 655", "balanced"],
        ["Intel(R) Arc(TM) A380 Graphics", "balanced"],
        ["IntelArcA770", "high"],
        ["Intel Arc B580 Graphics", "high"],
        ["Intel Arc 140V Graphics", "balanced"],
        ["NVIDIA GeForce GT1030", "low"],
        ["NVIDIA GeForce MX150", "low"],
        ["NVIDIA GeForce GTX650", "low"],
        ["NVIDIA GeForce GTX750 Ti", "balanced"],
        ["NVIDIA GeForce GTX950", "balanced"],
        ["NVIDIA GeForce GTX 1050 Ti", "balanced"],
        ["NVIDIAGeForceGTX1060", "high"],
        ["NVIDIA GeForce GTX1650", "high"],
        ["NVIDIA GeForce RTX2050 Laptop GPU", "balanced"],
        ["NVIDIA GeForce RTX 3060", "high"],
        ["NVIDIA GeForce RTX5070 Ti", "high"],
        ["AMD Radeon(TM) Vega 3 Graphics", "low"],
        ["AMD Radeon610M", "low"],
        ["AMD Radeon(TM) Vega 8 Graphics", "balanced"],
        ["AMD Radeon(TM)780M Graphics", "balanced"],
        ["AMD Radeon RX460", "balanced"],
        ["AMD Radeon RX550", "balanced"],
        ["AMD RadeonRX580", "high"],
        ["AMD Radeon RX Vega56", "high"],
        ["AMD Radeon RX6600 XT", "high"],
        ["AMD Radeon RX9070 XT", "high"],
        ["AMD Radeon R9 390", "balanced"],
        ["Unknown GPU 9999", "balanced"],
    ]
    for row in rows:
        var info := device(row[0])
        var result: Dictionary = Policy.classify_hardware(info)
        check(result.profile == row[1], str(row[0]) + " selected " + str(result.profile) + " instead of " + str(row[1]))
        check(result.target_fps == (30 if row[1] == "low" else 60), str(row[0]) + " has the wrong target")
        check(result.memory_known and not result.software and not str(result.reason).is_empty(), "Missing hardware evidence for " + str(row[0]))
        cases.append({"case":"hardware", "info":info, "result":result})
    var unknown := device("Unknown GPU", 64)
    unknown.cpu_cores = 128
    check(Policy.classify_hardware(unknown).profile == "balanced", "RAM/CPU count falsely proved an unknown GPU powerful")
    check(Policy.classify_hardware(device("NVIDIA GeForce RTX4090", 4)).profile == "low", "Small physical RAM was ignored")
    var missing := device("NVIDIA GeForce RTX4090")
    missing.erase("memory_bytes")
    var missing_result: Dictionary = Policy.classify_hardware(missing)
    check(not missing_result.memory_known and missing_result.profile == "balanced", "Unknown RAM was reported as measured capacity or high-quality evidence")
    missing.memory_bytes = -1
    check(not Policy.classify_hardware(missing).memory_known, "Negative physical RAM was reported as known")
    for name_: String in ["llvmpipe (LLVM 20)", "softpipe", "SwiftShader", "Microsoft Basic Render Driver", "GDI Generic", "ANGLE (Microsoft, Microsoft Basic Render Driver Direct3D11)"]:
        var info := device(name_, 16)
        var result: Dictionary = Policy.classify_hardware(info)
        check(result.software and result.profile == "low", "Software Windows renderer entered a hardware quality tier: " + name_)
        check(Policy.is_software_renderer(name_, "Windows"), "Actual Windows software renderer cannot be excluded from learning: " + name_)
        cases.append({"case":"software", "info":info, "result":result})
    var headless := device("", 16)
    headless.headless = true
    var headless_result: Dictionary = Policy.classify_hardware(headless)
    check(headless_result.profile == "high" and headless_result.software, "Headless baseline became a supposed measured Windows GPU")
    var linux := device("llvmpipe", 16)
    linux.platform = "Linux"
    linux.software_renderer = true
    check(Policy.classify_hardware(linux).profile == "high", "Windows support changed the legacy software-render regression baseline")
    var android := device("Mali-G52 MC2", 4)
    android.platform = "Android"
    check(Policy.classify_hardware(android).profile == "low", "Windows support changed Redmi hardware selection")
    android.gpu_name = "Adreno (TM) 740"
    android.memory_bytes = 8 * GB
    check(Policy.classify_hardware(android).profile == "high", "Windows support changed strong Android hardware selection")
    for level in [&"level1", &"level2", &"level3"]:
        var fallback: Dictionary = Policy.level_settings("high", level, 2, "Windows")
        check(fallback.profile == "low" and fallback.target_fps == 30, "Windows hardware recommendation lost its per-level30FPS fallback")
    for platform in ["", "Android", "Linux"]:
        check(Policy.level_settings("high", &"level1", 0, platform).pixel_budget == 921600, "Windows support changed the mobile/legacy high pixel budget")
        check(Policy.level_settings("balanced", &"level1", 0, platform).pixel_budget == 655360, "Windows support changed the mobile/legacy balanced pixel budget")
    check(Policy.level_settings("high", &"level1", 0, "Windows").pixel_budget == 2073600, "Windows quality remained capped at phone720p")
    check(Policy.level_settings("balanced", &"level1", 0, "Windows").pixel_budget == 921600, "Windows balanced is not720p")
    check(Policy.level_settings("low", &"level1", 0, "Windows").pixel_budget == 409920, "Windows low lost its conservative first budget")
    check(Policy.level_settings("low", &"level1", 1, "Windows").pixel_budget == 291600 and Policy.level_settings("low", &"level1", 2, "Windows").pixel_budget == 230400, "Windows low dynamic floor changed")
    check(Policy.level_settings("high", &"level1", 1, "Windows").pixel_budget == 921600, "Windows quality fallback lost its platform budget")
    check(Policy.level_settings("high", &"level1", 2, "Windows").pixel_budget == 409920, "Windows quality floor still uses an upper-tier budget")

func old_fingerprint(info: Dictionary) -> String:
    var memory := float(info.get("memory_bytes", 0))
    var fields := ["policy156.2",str(info.get("platform","")),str(info.get("gpu_name","")),str(info.get("gpu_vendor","")),str(info.get("model","")),str(info.get("cpu_cores",0)),str(roundi(memory / 268435456.0)) if memory > 0 else "unknown",str(info.get("software_renderer",false))]
    return "|".join(fields).sha256_text()

func persistence_cases() -> void:
    var path := output.path_join("isolated-graphics.cfg")
    var android := device("Mali-G52 MC2", 4)
    android.platform = "Android"
    var stored := {"schema":1,"mode":"auto","hardware_fingerprint":old_fingerprint(android),"adaptive_steps":{"level1":2,"level2":1,"level3":0}}
    check(Store.save_config(path, stored) == OK, "Cannot seed isolated Android preference")
    var settings := Settings.new()
    settings.initialize_for_device(android, path)
    check(settings.get_summary().adaptive_steps == stored.adaptive_steps, "Windows policy update erased existing Android learning")
    check(Store.load_config(path).hardware_fingerprint == stored.hardware_fingerprint, "Android fingerprint changed without an Android policy change")
    var windows := device("Intel(R) UHD Graphics620", 8)
    stored.hardware_fingerprint = old_fingerprint(windows)
    check(Store.save_config(path, stored) == OK, "Cannot seed isolated old Windows preference")
    settings.initialize_for_device(windows, path)
    check(settings.get_summary().profile == "low" and settings.get_summary().adaptive_steps.is_empty(), "Old Windows high-default learning survived the desktop policy change")
    check(settings.get_level_settings(&"level1").pixel_budget == 409920, "Live settings did not propagate the Windows low budget")
    check(Store.load_config(path).hardware_fingerprint != stored.hardware_fingerprint, "Windows policy version was not migrated")
    check(settings.set_mode("high"), "Windows manual override was rejected")
    check(settings.get_level_settings(&"level1").pixel_budget == 2073600, "Live settings did not propagate Windows native1080p quality")
    settings.free()
    var restarted := Settings.new()
    restarted.initialize_for_device(windows, path)
    check(restarted.get_summary().mode == "high" and restarted.get_summary().profile == "high", "Manual choice was lost after restart")
    check(not restarted.get_summary().adaptation_enabled, "Metadata-only test was mistaken for real hardware sampling")
    restarted.free()
    DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func run() -> void:
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
    var before := [Engine.physics_ticks_per_second, Engine.time_scale, Engine.max_fps]
    hardware_cases()
    persistence_cases()
    check([Engine.physics_ticks_per_second, Engine.time_scale, Engine.max_fps] == before, "Metadata selection changed live simulation or the test frame cap")
    var report := {"result":"PASS" if failures.is_empty() else "FAIL", "checks":checks, "cases":cases, "failures":failures, "actual_os":OS.get_name(), "actual_display":DisplayServer.get_name(), "scope":"Hardware metadata, software-render exclusion and persistent policy migration. Not measured desktop performance or a minimum-spec certification."}
    var file := FileAccess.open(output.path_join("report.json"),FileAccess.WRITE)
    check(file != null, "Cannot save desktop policy evidence")
    if file != null: file.store_string(JSON.stringify(report,"  "))
    if failures.is_empty(): print("DESKTOP GRAPHICS157: PASS")
    quit(0 if failures.is_empty() else 1)
