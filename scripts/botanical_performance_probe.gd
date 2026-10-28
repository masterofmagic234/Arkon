extends CanvasLayer
## Reversible paused throughput measurements. Every control is bracketed by
## production frames and repeated in reverse order to detect clock/thermal drift.
const WARM_SECONDS := .30
const MIN_WARM_FRAMES := 4
const MAX_WARM_SECONDS := 1.50
const SAMPLE_SECONDS := .70
const MIN_SAMPLE_FRAMES := 12
const MAX_SAMPLE_SECONDS := 3.0
const MAX_PROBE_SECONDS := 120.0
const MAX_BASELINE_DRIFT := .18
const MAX_REPEAT_SPREAD := .18

var director: Node3D
var heading: Label
var output: Label
var close_button: Button
var copy_button: Button
var panel: PanelContainer
var busy := false
var cancelled := false
var cancel_reason := ""
var captured := false
var original_3d := false
var original_ssao := false
var original_shadow := false
var original_vsync: int
var original_msaa: int
var original_max_fps := 0
var owner_exit_max_fps := 0
var owner_exit_msaa := 0
var original_sorting := true
var original_geometry := true
var original_baked := false
var original_reference_147 := false
var reference_147_available := false
# Extra ablations are for targeted investigation. The normal phone check keeps
# the useful production/1.47 comparison short and avoids needless cold variants.
var extended_controls := false
var environment_node: WorldEnvironment
var original_compositor: Compositor
var normals_compositor: Compositor
var foliage: Array[GeometryInstance3D] = []
var visibility: Array[bool] = []
var canopy_nodes: Array[GeometryInstance3D] = []
var mask_materials: Array[ShaderMaterial] = []
var mask_shaders: Array[Shader] = []
var atlas_shaders: Array[Shader] = []
var report: Dictionary = {}
var report_text := ""
var original_hud_input := true
var input_captured := false
var _started_usec := 0
var _deadline_usec := 0
var _sample_interrupted := false
var _captured_size := Vector2i.ZERO
var _captured_camera: Transform3D
var _captured_fov := 0.0

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    layer = 100
    var curtain := ColorRect.new()
    curtain.color = Color("101b16")
    curtain.mouse_filter = Control.MOUSE_FILTER_STOP
    curtain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(curtain)
    panel = PanelContainer.new()
    add_child(panel)
    var margin := MarginContainer.new()
    for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 20)
    panel.add_child(margin)
    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", 10)
    margin.add_child(column)
    heading = Label.new()
    heading.add_theme_font_size_override("font_size", 24)
    heading.text = "ПРОВЕРКА ПРОИЗВОДИТЕЛЬНОСТИ"
    column.add_child(heading)
    var scroll := ScrollContainer.new()
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    scroll.custom_minimum_size = Vector2(0, 180)
    column.add_child(scroll)
    output = Label.new()
    output.add_theme_font_size_override("font_size", 16)
    output.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    output.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.add_child(output)
    var buttons := HBoxContainer.new()
    column.add_child(buttons)
    copy_button = Button.new()
    copy_button.text = "СКОПИРОВАТЬ РЕЗУЛЬТАТ"
    copy_button.disabled = true
    copy_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    buttons.add_child(copy_button)
    copy_button.pressed.connect(func(): DisplayServer.clipboard_set(report_text); copy_button.text = "СКОПИРОВАНО")
    close_button = Button.new()
    close_button.text = "ОТМЕНА"
    close_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    buttons.add_child(close_button)
    close_button.pressed.connect(close)
    get_viewport().size_changed.connect(layout)
    layout()
    close_button.grab_focus()

func layout() -> void:
    var size_ := get_viewport().get_visible_rect().size
    panel.size = Vector2(minf(1120, size_.x - 32), minf(690, size_.y - 24))
    panel.position = (size_ - panel.size) * .5
    if busy and captured and get_viewport().size != _captured_size: _cancel("viewport_changed")

func _notification(what: int) -> void:
    if busy and captured and what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT]:
        _sample_interrupted = true
        _cancel("application_background")

func start(owner_: Node3D) -> void:
    director = owner_
    busy = true
    call_deferred("run")

func _reference_enabled() -> bool:
    if not is_instance_valid(director) or not is_instance_valid(director.world): return original_reference_147
    var world = director.world
    if world.has_method("is_reference_147_enabled"): return bool(world.call("is_reference_147_enabled"))
    var optimizer = world.rendering_optimizer
    if optimizer != null and optimizer.has_method("is_reference_147_enabled"): return bool(optimizer.call("is_reference_147_enabled"))
    return bool(world.get_meta("reference_147", false))

func _set_reference(value: bool) -> void:
    if not reference_147_available or _reference_enabled() == value: return
    if director.world.has_method("set_reference_147_enabled"): director.world.call("set_reference_147_enabled", value)
    else: director.world.rendering_optimizer.call("set_reference_147_enabled", value)

func capture() -> void:
    original_baked = director.world.baked_lighting != null and director.world.baked_lighting.enabled
    original_hud_input = director.hud.is_processing_input()
    input_captured = true
    director.hud.set_process_input(false)
    original_3d = get_viewport().disable_3d
    original_ssao = director.world.environment.ssao_enabled
    original_shadow = director.world.get_node("GardenSun").shadow_enabled
    original_vsync = DisplayServer.window_get_vsync_mode()
    original_msaa = get_viewport().msaa_3d
    original_max_fps = Engine.max_fps
    owner_exit_max_fps = director.world.original_max_fps if director.world.original_max_fps >= 0 else original_max_fps
    owner_exit_msaa = director.world.original_msaa if director.world.original_msaa >= 0 else original_msaa
    _captured_size = get_viewport().size
    _captured_camera = director.player.camera.global_transform
    _captured_fov = director.player.camera.fov
    var optimizer = director.world.rendering_optimizer
    reference_147_available = director.world.has_method("set_reference_147_enabled") or (optimizer != null and optimizer.has_method("set_reference_147_enabled"))
    original_reference_147 = _reference_enabled()
    if optimizer != null:
        original_sorting = optimizer.foliage_sorting_enabled
        original_geometry = optimizer.foliage_geometry_enabled
        optimizer.update(director.player.camera)
    for material in [director.world.mats.leaves, director.world.mats.get("canopy")]:
        if material is ShaderMaterial:
            mask_materials.append(material)
            mask_shaders.append(material.shader)
            atlas_shaders.append(preload("res://scripts/botanical_rendering.gd").atlas_alpha_shader(material.shader))
    # Spatial chunks are nested: include both hidden old and current geometry.
    for node in director.world.find_children("*", "GeometryInstance3D", true, false):
        if node.get_meta("botanical_foliage", false) or node.get_meta("foliage_shadow_proxy", false):
            foliage.append(node)
            visibility.append(node.visible)
        if node.get_meta("tree_canopy", false): canopy_nodes.append(node)
    for node in director.world.get_children():
        if node is WorldEnvironment: environment_node = node
    if environment_node != null: original_compositor = environment_node.compositor
    if environment_node != null and RenderingServer.get_current_rendering_method() == "forward_plus":
        normals_compositor = Compositor.new()
        if original_compositor != null: normals_compositor.compositor_effects = original_compositor.compositor_effects.duplicate()
        var effects = normals_compositor.compositor_effects
        effects.append(preload("res://scripts/botanical_probe_normals.gd").new())
        normals_compositor.compositor_effects = effects
    captured = true
    director.tree_exiting.connect(_owner_exiting, CONNECT_ONE_SHOT)

func _owner_exiting() -> void:
    if not captured: return
    # Restore while the old scene is leaving. Its replacement may choose new
    # global settings before the awaiting sample resumes on the next frame.
    _cancel("scene_unloaded")
    restore()
    captured = false

func _restore_scene_state() -> void:
    if not captured: return
    if is_instance_valid(get_viewport()):
        get_viewport().disable_3d = original_3d
        get_viewport().msaa_3d = original_msaa if _owner_present() else owner_exit_msaa
    if not _owner_present(): return
    _set_reference(original_reference_147)
    if director.world.baked_lighting != null: director.world.baked_lighting.set_enabled(original_baked)
    director.world.environment.ssao_enabled = original_ssao
    director.world.get_node("GardenSun").shadow_enabled = original_shadow
    if is_instance_valid(environment_node): environment_node.compositor = original_compositor
    var optimizer = director.world.rendering_optimizer
    var changed := false
    if optimizer != null and optimizer.foliage_geometry_enabled != original_geometry:
        optimizer.set_foliage_geometry_enabled(original_geometry)
        changed = true
    if optimizer != null and optimizer.foliage_sorting_enabled != original_sorting:
        optimizer.set_foliage_sorting_enabled(original_sorting)
        changed = true
    if changed: optimizer.update(director.player.camera)
    for i in range(mask_materials.size()): mask_materials[i].shader = mask_shaders[i]
    for i in range(foliage.size()):
        if is_instance_valid(foliage[i]): foliage[i].visible = visibility[i]

func restore() -> void:
    if not captured: return
    _restore_scene_state()
    # The garden itself restores its entry settings when it exits. Do not
    # reapply its temporary mobile cap/MSAA to the scene that replaces it.
    Engine.max_fps = original_max_fps if _owner_present() else owner_exit_max_fps
    if DisplayServer.window_get_vsync_mode() != original_vsync: DisplayServer.window_set_vsync_mode(original_vsync)
    if is_instance_valid(get_viewport()): RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), false)

func _owner_present() -> bool:
    return is_instance_valid(director) and director.is_inside_tree() and is_instance_valid(director.world) and director.world.is_inside_tree()

func apply_stage(id: String) -> void:
    # Keep one present mode throughout the session; restore() returns the game cap.
    _restore_scene_state()
    match id:
        "reference_147": _set_reference(true)
        "original_lighting":
            if director.world.baked_lighting != null: director.world.baked_lighting.set_enabled(false)
        "baked_with_ssao": director.world.environment.ssao_enabled = true
        "legacy_geometry":
            if director.world.rendering_optimizer != null: director.world.rendering_optimizer.set_foliage_geometry_enabled(false)
        "color_alpha":
            for i in range(mask_materials.size()): mask_materials[i].shader = atlas_shaders[i]
        "no_canopy":
            for node in canopy_nodes: node.hide()
        "no_ssao": director.world.environment.ssao_enabled = false
        "normals_only":
            director.world.environment.ssao_enabled = false
            if is_instance_valid(environment_node) and normals_compositor != null: environment_node.compositor = normals_compositor
        "no_msaa": get_viewport().msaa_3d = Viewport.MSAA_DISABLED
        "unsorted_foliage":
            if director.world.rendering_optimizer != null:
                director.world.rendering_optimizer.set_foliage_sorting_enabled(false)
                director.world.rendering_optimizer.update(director.player.camera)
        "no_shadows": director.world.get_node("GardenSun").shadow_enabled = false
        "no_foliage":
            for node in foliage: node.hide()
        "ui_only", "ui_no_vsync": get_viewport().disable_3d = true
    if id == "ui_no_vsync": DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
    RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)

func compilations() -> int:
    var total := 0
    for kind in [RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_SURFACE, RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_DRAW, RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_SPECIALIZATION]:
        total += RenderingServer.get_rendering_info(kind)
    return total

func _cancel(reason: String) -> void:
    if not cancelled:
        cancelled = true
        cancel_reason = reason

func _can_continue() -> bool:
    if cancelled: return false
    if not _owner_present() or not is_instance_valid(director.player): _cancel("scene_unloaded")
    elif get_viewport().size != _captured_size: _cancel("viewport_changed")
    elif not director.player.camera.global_transform.is_equal_approx(_captured_camera) or not is_equal_approx(director.player.camera.fov, _captured_fov): _cancel("camera_changed")
    elif _deadline_usec > 0 and Time.get_ticks_usec() >= _deadline_usec: _cancel("time_budget")
    return not cancelled

static func _median(values: Array) -> float:
    if values.is_empty(): return 0.0
    var sorted := values.duplicate()
    sorted.sort()
    var middle := sorted.size() / 2
    return float(sorted[middle]) if sorted.size() % 2 == 1 else (float(sorted[middle - 1]) + float(sorted[middle])) * .5

static func frame_statistics(intervals: Array) -> Dictionary:
    var sorted := intervals.duplicate()
    sorted.sort()
    var total := 0.0
    for value in intervals: total += float(value)
    return {"frame_count": intervals.size(), "duration_ms": total, "fps": intervals.size() * 1000.0 / maxf(.001, total), "median_frame_ms": _median(intervals), "p95_frame_ms": float(sorted[maxi(0, ceili(sorted.size() * .95) - 1)]) if not sorted.is_empty() else 0.0}

static func compare_bracket(before: Dictionary, control: Dictionary, after: Dictionary) -> Dictionary:
    var span := maxf(1.0, float(after.midpoint_usec) - float(before.midpoint_usec))
    var position := clampf((float(control.midpoint_usec) - float(before.midpoint_usec)) / span, 0.0, 1.0)
    var reference := lerpf(float(before.median_frame_ms), float(after.median_frame_ms), position)
    var drift := absf(float(after.median_frame_ms) - float(before.median_frame_ms)) / maxf(.001, (float(after.median_frame_ms) + float(before.median_frame_ms)) * .5)
    var reasons: Array[String] = []
    if not bool(before.stable) or not bool(control.stable) or not bool(after.stable): reasons.append("sample_unstable")
    if drift > MAX_BASELINE_DRIFT: reasons.append("baseline_drift")
    if before.has("render_settings") and control.has("render_settings") and after.has("render_settings"):
        var control_settings: Dictionary = control.render_settings.duplicate(true)
        if control.id == "no_msaa": control_settings.msaa = before.render_settings.msaa
        if before.render_settings != after.render_settings or before.render_settings != control_settings:
            reasons.append("render_settings_changed")
    return {"id": control.id, "round": control.round, "baseline_before_usec": before.midpoint_usec, "control_midpoint_usec": control.midpoint_usec, "baseline_after_usec": after.midpoint_usec, "reference_frame_ms": reference, "control_frame_ms": control.median_frame_ms, "speedup": reference / maxf(.001, float(control.median_frame_ms)), "baseline_drift_fraction": drift, "reliable": reasons.is_empty(), "reasons": reasons}

func _sample(id: String, round_: int, label: String) -> Dictionary:
    apply_stage(id)
    output.text = "%s\nПовтор %d из 2. Сравниваем с тем же исходным кадром.\n\nОбычно 20–40 секунд. Игра остаётся на паузе.\nНе сворачивай приложение до окончания проверки." % [label, round_ + 1]
    # Drain old-profile GL work once, outside warmup and measurement. A normal
    # frame signal only guarantees submission, not GPU completion. Never insert
    # a readback into the per-frame sample loop or report it as GPU timing.
    var needs_drain := DisplayServer.get_name() != "headless"
    var drained := false
    var drain_start := Time.get_ticks_usec()
    if needs_drain:
        await get_tree().process_frame
        if _can_continue():
            var previous_image := get_viewport().get_texture().get_image()
            drained = previous_image != null and not previous_image.is_empty()
            previous_image = null
    var drain_ms := (Time.get_ticks_usec() - drain_start) / 1000.0
    var warm_start := Time.get_ticks_usec()
    var warm_frames := 0
    var quiet_frames := 0
    var previous_compiles := compilations()
    while _can_continue():
        await get_tree().process_frame
        if not _can_continue(): break
        warm_frames += 1
        var current_compiles := compilations()
        quiet_frames = quiet_frames + 1 if current_compiles == previous_compiles else 0
        previous_compiles = current_compiles
        var elapsed := (Time.get_ticks_usec() - warm_start) / 1000000.0
        if elapsed >= WARM_SECONDS and quiet_frames >= MIN_WARM_FRAMES: break
        # One blocking driver compile may itself exceed the wall budget. Still
        # observe a few subsequent real frames before declaring it unsteady.
        if elapsed >= MAX_WARM_SECONDS and warm_frames >= MIN_WARM_FRAMES + 1: break
    var warm_ms := (Time.get_ticks_usec() - warm_start) / 1000.0
    var warm_stable := quiet_frames >= MIN_WARM_FRAMES
    var started := Time.get_ticks_usec()
    var previous := started
    var intervals: Array[float] = []
    var gpu: Array[float] = []
    var cpu: Array[float] = []
    var compiled_before := compilations()
    while _can_continue():
        await get_tree().process_frame
        if not _can_continue(): break
        var now := Time.get_ticks_usec()
        intervals.append((now - previous) / 1000.0)
        previous = now
        var rid := get_viewport().get_viewport_rid()
        if RenderingServer.get_current_rendering_method() != "gl_compatibility":
            gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(rid))
        cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(rid))
        var elapsed := (now - started) / 1000000.0
        if elapsed >= SAMPLE_SECONDS and intervals.size() >= MIN_SAMPLE_FRAMES: break
        if elapsed >= MAX_SAMPLE_SECONDS: break
    var finished := Time.get_ticks_usec()
    var result := frame_statistics(intervals)
    var compiled := compilations() - compiled_before
    result.merge({"id": id, "round": round_, "started_usec": started, "finished_usec": finished, "midpoint_usec": (started + finished) / 2, "warmup_ms": warm_ms, "warmup_frames": warm_frames, "warmup_stable": warm_stable, "pipeline_compilations": compiled, "stable": not cancelled and not _sample_interrupted and warm_stable and compiled == 0 and intervals.size() >= MIN_SAMPLE_FRAMES, "gpu_ms": _median(gpu), "gpu_available": not gpu.is_empty() and _median(gpu) > 0, "render_cpu_ms": _median(cpu), "intervals_ms": intervals, "calls": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME), "triangles": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)})
    result["render_settings"] = {"window": [get_viewport().size.x, get_viewport().size.y], "scale_3d": get_viewport().scaling_3d_scale, "msaa": get_viewport().msaa_3d, "max_fps": Engine.max_fps, "vsync": DisplayServer.window_get_vsync_mode()}
    result["gpu_boundary_drain"] = "readback_before_warmup" if drained else ("not_rendered" if not needs_drain else "unavailable")
    result["gpu_boundary_drain_ms"] = drain_ms
    result["reference_147_enabled"] = _reference_enabled()
    if needs_drain and not drained: result.stable = false
    if Engine.max_fps != 0 or int(result.render_settings.vsync) != int(report.probe_vsync): result.stable = false
    return result

func stage_definitions() -> Array:
    var stages := [["no_foliage", "Без растительности"]]
    if extended_controls:
        stages = [["original_lighting", "Без запечённого света"], ["no_msaa", "Без MSAA"], ["no_shadows", "Без лунных теней"], ["no_foliage", "Без растительности"]]
    if extended_controls and RenderingServer.get_current_rendering_method() == "forward_plus":
        stages = [["original_lighting", "Без запечённого света"], ["baked_with_ssao", "Запечённый свет + SSAO"], ["normals_only", "Проход нормалей"], ["no_foliage", "Без растительности"]]
    if reference_147_available and not original_reference_147: stages.push_front(["reference_147", "Версия 1.47 · тот же кадр"])
    return stages

func _aggregate(definitions: Array) -> void:
    var groups: Array = [["full", "Текущий кадр · " + str(report.renderer)]] + definitions + [["ui_only", "Только интерфейс"]]
    for definition in groups:
        var id: String = definition[0]
        var samples: Array = report.samples.filter(func(value): return value.id == id and value.frame_count > 0)
        if samples.is_empty(): continue
        var fps: Array = []
        var medians: Array = []
        var tails: Array = []
        var cpus: Array = []
        var gpus: Array = []
        var count := 0
        var stable := true
        for sample in samples:
            fps.append(sample.fps); medians.append(sample.median_frame_ms); tails.append(sample.p95_frame_ms)
            cpus.append(sample.render_cpu_ms); count += int(sample.frame_count)
            if sample.gpu_available: gpus.append(sample.gpu_ms)
            stable = stable and bool(sample.stable)
        var pairs: Array = report.comparisons.filter(func(value): return value.id == id)
        var ratios: Array = []
        for pair in pairs:
            ratios.append(pair.speedup)
            stable = stable and bool(pair.reliable)
        var repeat_spread := 0.0
        if ratios.size() > 1:
            var bounds := ratios.duplicate(); bounds.sort()
            repeat_spread = (float(bounds[-1]) - float(bounds[0])) / maxf(.001, _median(ratios))
            stable = stable and repeat_spread <= MAX_REPEAT_SPREAD
        report.stages.append({"id": id, "label": definition[1], "fps": _median(fps), "median_frame_ms": _median(medians), "p95_frame_ms": _median(tails), "render_cpu_ms": _median(cpus), "gpu_ms": _median(gpus), "gpu_available": not gpus.is_empty(), "frame_count": count, "repeats": samples.size(), "speedup": _median(ratios) if not ratios.is_empty() else 1.0, "repeat_spread_fraction": repeat_spread, "reliable": stable, "calls": samples[-1].calls, "triangles": samples[-1].triangles})
    var baselines: Array = report.samples.filter(func(value): return value.id == "full" and value.frame_count > 0)
    var baseline_times: Array = []
    for sample in baselines: baseline_times.append(sample.median_frame_ms)
    baseline_times.sort()
    report["baseline_drift_fraction"] = (float(baseline_times[-1]) - float(baseline_times[0])) / maxf(.001, _median(baseline_times)) if not baseline_times.is_empty() else 0.0
    report["reliable"] = not cancelled and report.comparisons.size() == definitions.size() * 2 and float(report.baseline_drift_fraction) <= MAX_BASELINE_DRIFT
    for stage in report.stages:
        if stage.id != "ui_only" and float(report.baseline_drift_fraction) > MAX_BASELINE_DRIFT: stage.reliable = false
        if stage.id != "ui_only" and not stage.reliable: report.reliable = false
    var ui: Array = report.stages.filter(func(value): return value.id == "ui_only")
    var ceiling := float(ui[0].fps) if not ui.is_empty() else 0.0
    for stage in report.stages:
        stage["present_ceiling_limited"] = stage.id != "ui_only" and ceiling > 0 and float(stage.fps) >= ceiling * .95
        if stage.id == "reference_147": report["current_vs_147_speedup"] = 1.0 / maxf(.001, float(stage.speedup))

func run() -> void:
    busy = true
    capture()
    _started_usec = Time.get_ticks_usec()
    _deadline_usec = _started_usec + int(MAX_PROBE_SECONDS * 1000000)
    var window := get_viewport()
    var camera = director.player.camera
    report = {"schema": 2, "protocol": "bracketed_reverse_order", "version": ProjectSettings.get_setting("application/config/version"), "renderer": RenderingServer.get_current_rendering_method(), "gpu": RenderingServer.get_video_adapter_name(), "window": str(window.size), "scale_3d": window.scaling_3d_scale, "msaa": original_msaa, "max_fps": original_max_fps, "vsync": original_vsync, "depth_prepass": ProjectSettings.get_setting_with_override("rendering/driver/depth_prepass/enable"), "active_fps": director.hud.frame_times.size() / maxf(.001, director.hud.sample_seconds), "camera_position": [camera.global_position.x, camera.global_position.y, camera.global_position.z], "camera_rotation_degrees": [camera.global_rotation_degrees.x, camera.global_rotation_degrees.y, camera.global_rotation_degrees.z], "camera_fov": camera.fov, "baked_lighting": original_baked, "reference_147_available": reference_147_available, "original_reference_147": original_reference_147, "minimum_sample_frames": MIN_SAMPLE_FRAMES, "samples": [], "comparisons": [], "stages": []}
    report["ssao_enabled"] = original_ssao
    report["extended_controls"] = extended_controls
    report["stability_method"] = "At least12 real frames, stable warmup without observed compilation, adjacent/global baseline and repeat drift<=18%. Heuristic stability; not a statistical confidence interval."
    report["depth_prepass_setting_only"] = true
    # Uncap only this paused diagnostic, not the separately reported gameplay FPS.
    Engine.max_fps = 0
    DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
    report["probe_max_fps"] = Engine.max_fps
    report["probe_vsync"] = DisplayServer.window_get_vsync_mode()
    var definitions := stage_definitions()
    var baseline := await _sample("full", 0, "Исходный кадр")
    report.samples.append(baseline)
    for round_ in range(2):
        var order := definitions.duplicate()
        if round_ == 1: order.reverse()
        for stage in order:
            if not _can_continue(): break
            var control := await _sample(stage[0], round_, stage[1])
            report.samples.append(control)
            if not _can_continue(): break
            var following := await _sample("full", round_, "Повтор исходного кадра")
            report.samples.append(following)
            report.comparisons.append(compare_bracket(baseline, control, following))
            baseline = following
        if not _can_continue(): break
    if _can_continue(): report.samples.append(await _sample("ui_only", 0, "Проверка ограничения частоты вывода"))
    _aggregate(definitions)
    report["cancelled"] = cancelled
    report["cancel_reason"] = cancel_reason
    report["duration_seconds"] = (Time.get_ticks_usec() - _started_usec) / 1000000.0
    restore()
    captured = false
    busy = false
    report["restored_max_fps"] = Engine.max_fps
    report["restored_vsync"] = DisplayServer.window_get_vsync_mode()
    report_text = format_report(report)
    var log := FileAccess.open("user://garden-performance.json", FileAccess.WRITE)
    if log != null: log.store_string(JSON.stringify(report, "  "))
    output.text = report_text
    heading.text = "ПРОВЕРКА ПРЕРВАНА" if cancelled else "РЕЗУЛЬТАТ ПРОВЕРКИ"
    close_button.text = "ЗАКРЫТЬ"
    close_button.disabled = false
    copy_button.disabled = false

func format_report(data: Dictionary) -> String:
    var p = data.camera_position
    var r = data.camera_rotation_degrees
    var lines := PackedStringArray(["Версия %s · %s\nGPU: %s\nЭкран %s · масштаб 3D %.3f · MSAA %dx\nFPS в игре: %.1f · лимит %d · VSync %d\nКамера: %.1f, %.1f, %.1f · углы %.1f, %.1f · FOV %.1f\n" % [data.version, data.renderer, data.gpu, data.window, data.scale_3d, [0, 2, 4, 8][data.msaa], data.active_fps, data.max_fps, data.vsync, p[0], p[1], p[2], r[0], r[1], data.camera_fov]])
    lines.append("Тест на паузе: лимит %d · VSync %d · два повтора с возвратом к исходному кадру" % [data.probe_max_fps, data.probe_vsync])
    if data.get("baked_lighting", false): lines.append("Освещение запечено · SSAO %s в игре" % ("включён" if data.get("ssao_enabled", false) else "выключен"))
    for stage in data.stages:
        var change := " · ×%.2f к соседнему исходному кадру" % stage.speedup if stage.id not in ["full", "ui_only"] else ""
        if stage.id == "reference_147": change = " · текущая / 1.47: ×%.2f" % float(data.current_vs_147_speedup)
        var validity := " · нестабильно" if not stage.reliable else ""
        if stage.get("present_ceiling_limited", false): validity += " · близко к пределу вывода"
        var gpu_text := "%.1f мс" % stage.gpu_ms if stage.get("gpu_available", false) else "н/д"
        lines.append("%s: %.1f FPS · кадр %.1f мс / p95 %.1f · CPU %.1f мс · GPU %s · %d кадров%s%s" % [stage.label, stage.fps, stage.median_frame_ms, stage.p95_frame_ms, stage.render_cpu_ms, gpu_text, stage.frame_count, change, validity])
    if data.cancelled: lines.append("Замер прерван (%s). Неполные сравнения не считаются надёжными." % data.cancel_reason)
    elif not data.reliable: lines.append("Результат нестабилен: прогрев, разброс повторов или изменение исходного кадра. Не делай вывод по одному FPS.")
    lines.append("Дрейф исходного кадра %.0f%% · время %.1f с. Настройки игры восстановлены." % [float(data.baseline_drift_fraction) * 100, data.duration_seconds])
    return "\n".join(lines)

func close() -> void:
    if busy:
        _cancel("user_cancelled")
        close_button.disabled = true
        close_button.text = "ЗАВЕРШАЮ…"
    else: queue_free()

func _input(event: InputEvent) -> void:
    if event.is_action_pressed("ui_cancel"):
        close()
        get_viewport().set_input_as_handled()

func _exit_tree() -> void:
    restore()
    if input_captured and is_instance_valid(director) and is_instance_valid(director.hud): director.hud.set_process_input(original_hud_input)
