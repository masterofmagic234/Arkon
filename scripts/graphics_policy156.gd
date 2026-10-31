extends RefCounted
## Hardware selection is a conservative starting point, not a measured benchmark.

static func classify_hardware(info: Dictionary) -> Dictionary:
    var gpu := str(info.get("gpu_name", "")).to_lower()
    for token in ["(tm)", "™", "-", "_", "(", ")"]: gpu = gpu.replace(token, " ")
    var compact := gpu.replace(" ", "")
    var memory := float(info.get("memory_bytes", 0))
    var known := memory > 0
    var gb := memory / 1073741824.0 if known else 0.0
    var mobile := str(info.get("platform", "")).to_lower() in ["android", "ios"]
    var software := bool(info.get("headless", false)) or bool(info.get("software_renderer", false)) or "llvmpipe" in gpu or "softpipe" in gpu or "swiftshader" in gpu
    var result := {"profile":"high", "reason":"Настройки для компьютера", "target_fps":60, "memory_known":known, "memory_gb":gb, "software":software}
    if not mobile:
        if bool(info.get("headless", false)) or software: result.reason = "Программный рендер: скорость телефона не измеряется"
        return result
    var weak := software
    for family in ["malig31", "malig51", "malig52", "malig57", "powervrge", "powervrroguege", "adreno505", "adreno506", "adreno508", "adreno509", "adreno510", "adreno512", "adreno530", "adreno540", "adreno610", "adreno612", "adreno613", "adreno615", "adreno616", "adreno618", "adreno619", "adreno620"]:
        if family in compact: weak = true
    var strong := false
    for family in ["adreno650", "adreno660", "adreno730", "adreno740", "adreno750", "adreno830", "adreno840", "malig710", "malig715", "malig720", "immortalis"]:
        if family in compact: strong = true
    var moderate := false
    for family in ["adreno630", "adreno640", "adreno642", "adreno644", "adreno710", "adreno720", "malig68", "malig76", "malig77", "malig78", "malig610"]:
        if family in compact: moderate = true
    if weak or (known and gb <= 4.5):
        result.profile = "low"
        result.reason = "Экономный профиль: мобильный GPU / объём памяти"
    elif strong and known and gb >= 5.0:
        result.reason = "Мощный мобильный GPU и достаточная память"
    elif strong:
        result.profile = "balanced"
        result.reason = "Мощный GPU; запас памяти не подтверждён"
    elif moderate and known and gb >= 5.0:
        result.profile = "balanced"
        result.reason = "Средний мобильный GPU и достаточная память"
    else:
        # Unknown Android hardware starts safely, including Redmi regional names.
        result.profile = "low"
        result.reason = "Безопасный профиль для неопознанного мобильного GPU"
    result.target_fps = 30 if result.profile == "low" else 60
    return result

static func level_settings(profile: String, level_id: StringName, dynamic_step: int = 0) -> Dictionary:
    var tier := ["low", "balanced", "high"].find(profile)
    if tier < 0: tier = 0
    var step := clampi(dynamic_step, 0, 2)
    var out := {"profile":["low","balanced","high"][tier], "base_profile":["low","balanced","high"][tier], "dynamic_step":step, "target_fps":30 if tier == 0 else 60, "msaa_3d":1 if tier == 2 else 0, "mesh_lod_threshold":[2.5,1.7,1.0][tier]}
    if level_id == &"level1":
        out.merge({"pixel_budget":[409920,655360,921600][tier], "moon_shadows":tier > 0, "shadow_distance":[0.0,30.0,55.0][tier], "material_normal_distance":[0.0,8.0,14.0][tier], "decorative_lights":tier > 0, "decorative_light_range_scale":[0.0,0.7,1.0][tier]})
        if tier == 0: out.pixel_budget = [409920,291600,230400][step]
    elif level_id == &"level2":
        out.merge({"car_pixel_budget":[230400,409920,0][tier], "road_rows":[96,112,128][tier], "scenery_range":[320.0,400.0,480.0][tier], "scenery_tunnel_range":[160.0,192.0,224.0][tier], "scenery_detail_cutoff":[64.0,96.0,130.0][tier], "rotor_blur":tier > 0})
        out.msaa_3d = 0
        if tier == 0:
            out.car_pixel_budget = [230400,172800,129600][step]
            out.road_rows = [96,88,80][step]
            out.scenery_range = [320.0,288.0,256.0][step]
    elif level_id == &"level3":
        out.merge({"l3_real_lights":[4,8,14][tier], "rain_enabled":tier > 0, "rain_quality":tier, "hit_particle_limit":[48,72,96][tier], "hit_drops":[6,10,15][tier], "stain_limit":[120,240,360][tier], "minimap_interval":[0.2,0.15,0.1][tier]})
        if tier == 0:
            out.l3_real_lights = [4,3,2][step]
            out.hit_drops = [6,5,4][step]
            out.stain_limit = [120,100,80][step]
    # Medium/high can also shed visual work without altering simulation.
    if tier > 0 and step > 0:
        var lower := level_settings(["low","balanced","high"][tier - 1], level_id, step - 1)
        lower.base_profile = out.base_profile
        lower.dynamic_step = step
        # Reaching the low tier also adopts its stable30FPS target. A capped
        #30FPS result can never upgrade this back to60 automatically.
        return lower
    return out
