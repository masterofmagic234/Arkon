extends CanvasLayer
## On-device ablation under an opaque pause overlay. Always restore the exact
## production scene; never turn a diagnostic rendering change into a preset.
var director: Node3D
var heading: Label
var output: Label
var close_button: Button
var copy_button: Button
var panel: PanelContainer
var busy:=false
var cancelled:=false
var captured:=false
var original_3d:=false
var original_ssao:=false
var original_shadow:=false
var original_vsync: int
var original_msaa: int
var original_sorting:=true
var original_geometry:=true
var environment_node: WorldEnvironment
var original_compositor: Compositor
var normals_compositor: Compositor
var foliage: Array[GeometryInstance3D]=[]
var visibility: Array[bool]=[]
var canopy_nodes: Array[GeometryInstance3D]=[]
var mask_materials: Array[ShaderMaterial]=[]
var mask_shaders: Array[Shader]=[]
var atlas_shaders: Array[Shader]=[]
var report: Dictionary={}
var report_text:=""
var original_hud_input:=true
var input_captured:=false

func _ready() -> void:
    process_mode=Node.PROCESS_MODE_ALWAYS;layer=100
    var curtain=ColorRect.new();curtain.color=Color("101b16");curtain.mouse_filter=Control.MOUSE_FILTER_STOP;curtain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(curtain)
    panel=PanelContainer.new();add_child(panel)
    var margin=MarginContainer.new()
    for side in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+side,20)
    panel.add_child(margin)
    var column=VBoxContainer.new();column.add_theme_constant_override("separation",12);margin.add_child(column)
    heading=Label.new();heading.add_theme_font_size_override("font_size",24);heading.text="ПРОВЕРКА ПРОИЗВОДИТЕЛЬНОСТИ";column.add_child(heading)
    output=Label.new();output.add_theme_font_size_override("font_size",16);output.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;output.size_flags_vertical=Control.SIZE_EXPAND_FILL;column.add_child(output)
    var buttons=HBoxContainer.new();column.add_child(buttons)
    copy_button=Button.new();copy_button.text="СКОПИРОВАТЬ РЕЗУЛЬТАТ";copy_button.disabled=true;copy_button.size_flags_horizontal=Control.SIZE_EXPAND_FILL;buttons.add_child(copy_button)
    copy_button.pressed.connect(func():DisplayServer.clipboard_set(report_text);copy_button.text="СКОПИРОВАНО")
    close_button=Button.new();close_button.text="ОТМЕНА";close_button.size_flags_horizontal=Control.SIZE_EXPAND_FILL;buttons.add_child(close_button);close_button.pressed.connect(close)
    get_viewport().size_changed.connect(layout);layout();close_button.grab_focus()
func layout() -> void:
    var size_=get_viewport().get_visible_rect().size
    panel.size=Vector2(minf(1040,size_.x-32),minf(630,size_.y-24));panel.position=(size_-panel.size)*.5
func start(owner_: Node3D) -> void:
    director=owner_;busy=true;call_deferred("run")
func capture() -> void:
    original_hud_input=director.hud.is_processing_input();input_captured=true;director.hud.set_process_input(false)
    original_3d=get_viewport().disable_3d;original_ssao=director.world.environment.ssao_enabled;original_shadow=director.world.get_node("GardenSun").shadow_enabled
    original_vsync=DisplayServer.window_get_vsync_mode()
    original_msaa=get_viewport().msaa_3d
    if director.world.rendering_optimizer!=null:
        original_sorting=director.world.rendering_optimizer.foliage_sorting_enabled
        original_geometry=director.world.rendering_optimizer.foliage_geometry_enabled
        # Pausing immediately after scene creation can precede its first
        # _process. Settle the same visibility/order before BOTH A/B stages;
        # otherwise the first sample alone would include uncullled instances.
        director.world.rendering_optimizer.update(director.player.camera)
    for material in [director.world.mats.leaves,director.world.mats.get("canopy")]:
        if material is ShaderMaterial:
            mask_materials.append(material);mask_shaders.append(material.shader)
            atlas_shaders.append(preload("res://scripts/botanical_rendering.gd").atlas_alpha_shader(material.shader))
    for node in director.world.get_children():
        if node is GeometryInstance3D and (node.get_meta("botanical_foliage",false) or node.get_meta("foliage_shadow_proxy",false)):foliage.append(node);visibility.append(node.visible)
        if node is GeometryInstance3D and node.get_meta("tree_canopy",false):canopy_nodes.append(node)
        if node is WorldEnvironment:environment_node=node
    if environment_node!=null:
        original_compositor=environment_node.compositor
        normals_compositor=Compositor.new()
        if original_compositor!=null:normals_compositor.compositor_effects=original_compositor.compositor_effects.duplicate()
        var effects=normals_compositor.compositor_effects
        effects.append(preload("res://scripts/botanical_probe_normals.gd").new());normals_compositor.compositor_effects=effects
    captured=true
func restore() -> void:
    if not captured:return
    if is_instance_valid(get_viewport()):
        get_viewport().disable_3d=original_3d
        get_viewport().msaa_3d=original_msaa
        RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(),false)
    if DisplayServer.window_get_vsync_mode()!=original_vsync:DisplayServer.window_set_vsync_mode(original_vsync)
    if is_instance_valid(director) and is_instance_valid(director.world):
        director.world.environment.ssao_enabled=original_ssao;director.world.get_node("GardenSun").shadow_enabled=original_shadow
        if is_instance_valid(environment_node):environment_node.compositor=original_compositor
        var optimizer=director.world.rendering_optimizer
        if optimizer!=null and optimizer.foliage_geometry_enabled!=original_geometry:optimizer.set_foliage_geometry_enabled(original_geometry)
        if optimizer!=null and optimizer.foliage_sorting_enabled!=original_sorting:
            optimizer.set_foliage_sorting_enabled(original_sorting);optimizer.update(director.player.camera)
        for i in range(mask_materials.size()):mask_materials[i].shader=mask_shaders[i]
        for i in range(foliage.size()):
            if is_instance_valid(foliage[i]):foliage[i].visible=visibility[i]
func apply_stage(id: String) -> void:
    restore()
    if id=="legacy_geometry":
        var optimizer=director.world.rendering_optimizer
        if optimizer!=null:optimizer.set_foliage_geometry_enabled(false)
    elif id=="color_alpha":
        for i in range(mask_materials.size()):mask_materials[i].shader=atlas_shaders[i]
    elif id=="no_canopy":
        for node in canopy_nodes:node.hide()
    elif id=="no_ssao":director.world.environment.ssao_enabled=false
    elif id=="normals_only":
        director.world.environment.ssao_enabled=false
        if is_instance_valid(environment_node):environment_node.compositor=normals_compositor
    elif id=="no_msaa":get_viewport().msaa_3d=Viewport.MSAA_DISABLED
    elif id=="unsorted_foliage":
        var optimizer=director.world.rendering_optimizer
        if optimizer!=null:
            optimizer.set_foliage_sorting_enabled(false);optimizer.update(director.player.camera)
    elif id=="no_shadows":director.world.get_node("GardenSun").shadow_enabled=false
    elif id=="no_foliage":
        for node in foliage:node.hide()
    elif id=="ui_only" or id=="ui_no_vsync":get_viewport().disable_3d=true
    if id=="ui_no_vsync":DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
    RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(),true)
func compilations() -> int:
    var total=0
    for kind in [RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_SURFACE,RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_DRAW,RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_SPECIALIZATION]:total+=RenderingServer.get_rendering_info(kind)
    return total
func run() -> void:
    busy=true;capture()
    var window=get_viewport()
    report={"version":ProjectSettings.get_setting("application/config/version"),"renderer":RenderingServer.get_current_rendering_method(),"gpu":RenderingServer.get_video_adapter_name(),"window":str(window.size),"scale_3d":window.scaling_3d_scale,"msaa":original_msaa,"max_fps":Engine.max_fps,"vsync":original_vsync,"depth_prepass":ProjectSettings.get_setting_with_override("rendering/driver/depth_prepass/enable"),"active_fps":director.hud.frame_times.size()/maxf(.001,director.hud.sample_seconds),"stages":[]}
    var camera=director.player.camera
    report["camera_position"]=[camera.global_position.x,camera.global_position.y,camera.global_position.z]
    report["camera_rotation_degrees"]=[camera.global_rotation_degrees.x,camera.global_rotation_degrees.y,camera.global_rotation_degrees.z]
    report["camera_fov"]=camera.fov
    var stages=[["full","Обычный кадр на паузе"],["legacy_geometry","Исходные карточки (контроль)"],["no_ssao","Без контактных теней (SSAO)"],["normals_only","Проход нормалей без SSAO"],["no_foliage","Без растительности"],["ui_only","Только интерфейс"]]
    for stage in stages:
        if cancelled or not is_instance_valid(director):break
        apply_stage(stage[0]);output.text="%s\n\nТест займёт обычно 30–90 секунд.\nИгра остаётся на паузе. Результат появится здесь."%stage[1]
        # Discard initial pipeline changes. Wall-clock intervals are measured
        # directly; simulation delta is capped during very slow rendering.
        var warm=Time.get_ticks_usec()
        for i in range(8):
            await get_tree().process_frame
            if cancelled or Time.get_ticks_usec()-warm>12000000:break
        var start=Time.get_ticks_usec();var previous=start;var intervals: Array[float]=[];var gpu: Array[float]=[];var cpu: Array[float]=[]
        var compiled_before=compilations()
        while not cancelled and (Time.get_ticks_usec()-start<2500000 or intervals.size()<4):
            await get_tree().process_frame
            var now=Time.get_ticks_usec();intervals.append((now-previous)/1000.0);previous=now
            var rid=window.get_viewport_rid();gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(rid));cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(rid))
            if now-start>12000000:break
        if intervals.is_empty():continue
        var duration=(Time.get_ticks_usec()-start)/1000000.0;gpu.sort();cpu.sort();intervals.sort()
        report.stages.append({"id":stage[0],"label":stage[1],"fps":intervals.size()/maxf(.001,duration),"median_frame_ms":intervals[intervals.size()/2],"gpu_ms":gpu[gpu.size()/2],"render_cpu_ms":cpu[cpu.size()/2],"calls":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),"triangles":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),"warmup_ms":(start-warm)/1000.0,"pipeline_compilations":compilations()-compiled_before})
    restore();captured=false;busy=false
    report["cancelled"]=cancelled;report_text=format_report(report)
    var log=FileAccess.open("user://garden-performance.json",FileAccess.WRITE)
    if log!=null:log.store_string(JSON.stringify(report,"  "))
    output.text=report_text;heading.text="РЕЗУЛЬТАТ ПРОВЕРКИ";close_button.text="ЗАКРЫТЬ";close_button.disabled=false;copy_button.disabled=false
func format_report(data: Dictionary) -> String:
    var position_=data.camera_position;var rotation_=data.camera_rotation_degrees
    var lines=PackedStringArray(["Версия %s · %s\nGPU: %s\nЭкран %s · масштаб 3D %.3f · MSAA %dx\nFPS в игре: %.1f · лимит %d · VSync %d\nКамера: %.1f, %.1f, %.1f · углы %.1f, %.1f · FOV %.1f\n"%[data.version,data.renderer,data.gpu,data.window,data.scale_3d,[0,2,4,8][data.msaa],data.active_fps,data.max_fps,data.vsync,position_[0],position_[1],position_[2],rotation_[0],rotation_[1],data.camera_fov]])
    for stage in data.stages:lines.append("%s: %.1f FPS · GPU %s · CPU рендера %.1f мс%s"%[stage.label,stage.fps,("%.1f мс"%stage.gpu_ms) if stage.gpu_ms>0 else "н/д",stage.render_cpu_ms," · прогрев шейдеров" if stage.pipeline_compilations>0 else ""])
    return "\n".join(lines)
func close() -> void:
    if busy:cancelled=true;close_button.disabled=true;close_button.text="ЗАВЕРШАЮ…"
    else:queue_free()
func _input(event: InputEvent) -> void:
    if event.is_action_pressed("ui_cancel"):close();get_viewport().set_input_as_handled()
func _exit_tree() -> void:
    restore()
    if input_captured and is_instance_valid(director) and is_instance_valid(director.hud):director.hud.set_process_input(original_hud_input)
