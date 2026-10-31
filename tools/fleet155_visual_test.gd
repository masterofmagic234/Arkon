extends SceneTree
## Static, staged production-asset inspection. This is not a driving replay,
## first-frame lifecycle proof, Android capture, or phone FPS measurement.
const Traffic=preload("res://scripts/race_traffic_3d.gd")
const RoadMath=preload("res://scripts/race_math.gd")
const VARIANTS: Array[String]=["patrol","interceptor","wagon"]
const TITLES={"patrol":"ЛЕСНОЙ ПАТРУЛЬ · CAMRY","interceptor":"ПЕРЕХВАТЧИК · FASTBACK","wagon":"ГРУППА ПОДДЕРЖКИ · WAGON"}
var output := "/tmp/fleet155-visual"
var showroom_only := false
var encounters_only := false
var failures: Array[String]=[]
var report: Dictionary={"scope":{"staged_production_assets":true,"manual_static_render_submission":true,"actual_level2_encounter_scene":true,"offline_comparison_cameras_only":true,"physical_android":false,"first_displayed_frame_proof":false,"phone_fps_measured":false},"assets":[],"civilian_materials":[],"captures":[],"camera_clearance":[]}
var world: Node3D
var camera: Camera3D
var lighting: Environment
var key: DirectionalLight3D
var fill: DirectionalLight3D
var heading: Label
var detail: Label
var traffic
var level

func _init() -> void:
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
        if arg=="--showroom-only":showroom_only=true
        if arg=="--encounters-only":encounters_only=true
    call_deferred("run")

func frames(count: int=3) -> void:
    for i in range(count):await process_frame

func check(ok: bool,message: String) -> void:
    if not ok:failures.append(message);push_error("FLEET155: "+message)

func run() -> void:
    DirAccess.make_dir_recursive_absolute(output)
    if DisplayServer.get_name()=="headless":
        push_error("FLEET155 VISUAL requires a native graphics context");quit(1);return
    report["renderer"]=RenderingServer.get_current_rendering_method()
    report["driver"]=RenderingServer.get_current_rendering_driver_name()
    report["engine"]=Engine.get_version_info()
    check(report.renderer=="gl_compatibility","Fixture must use the game's Compatibility renderer")
    root.size=Vector2i(1280,720)
    root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
    root.disable_3d=false
    root.scaling_3d_scale=1.0
    root.msaa_3d=Viewport.MSAA_2X
    root.get_node("GameState").music_muted=true
    root.get_node("GameState").sfx_muted=true
    RenderingServer.set_render_loop_enabled(false)
    if not encounters_only:
        build_showroom()
        await frames(4)
        await inspect_showroom()
        world.queue_free();world=null;traffic=null;camera=null
        await frames(5)
    if not showroom_only:await inspect_actual_level()
    var hashes: Dictionary={}
    for path in ["scripts/race_traffic_3d.gd","shaders/race_traffic.gdshader","shaders/race_fleet_livery.gdshaderinc","tools/fleet155_visual_test.gd","tools/fleet155_geometry_test.py","assets/level2/fleet155/manifest.json","assets/level2/fleet155/patrol_badge.png","assets/level2/fleet155/patrol_marks.svg"]:
        hashes[path]=FileAccess.get_sha256("res://"+path)
    for variant in VARIANTS:
        var path: String="assets/level2/fleet155/camry_"+variant+".glb"
        hashes[path]=FileAccess.get_sha256("res://"+path)
    report["source_sha256"]=hashes
    report["failures"]=failures
    report["result"]="PASS" if failures.is_empty() else "FAIL"
    FileAccess.open(output.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    await preload("res://tools/level3_test_teardown.gd").drain_audio(self)
    print("FLEET155 VISUAL: "+report.result)
    quit(0 if failures.is_empty() else 1)

func build_showroom() -> void:
    world=Node3D.new();world.name="Fleet155Showroom";root.add_child(world)
    var environment:=WorldEnvironment.new();lighting=Environment.new()
    lighting.background_mode=Environment.BG_COLOR
    lighting.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
    lighting.tonemap_mode=Environment.TONE_MAPPER_FILMIC
    environment.environment=lighting;world.add_child(environment)
    key=DirectionalLight3D.new();key.rotation_degrees=Vector3(-42,-32,0)
    key.shadow_enabled=true;world.add_child(key)
    fill=DirectionalLight3D.new();fill.rotation_degrees=Vector3(-22,145,0)
    fill.light_color=Color(.65,.79,1);world.add_child(fill)
    var floor_node:=MeshInstance3D.new();var floor_mesh:=PlaneMesh.new()
    floor_mesh.size=Vector2(120,120);floor_node.mesh=floor_mesh
    var floor_material:=StandardMaterial3D.new()
    floor_material.albedo_color=Color(.055,.071,.083);floor_material.roughness=.88
    floor_node.material_override=floor_material;world.add_child(floor_node)
    camera=Camera3D.new();camera.fov=29;camera.near=.05
    world.add_child(camera);camera.make_current()
    traffic=Traffic.new();traffic.setup(world)
    for pivot in all_cars():pivot.hide()
    var canvas:=CanvasLayer.new();canvas.layer=80;world.add_child(canvas)
    heading=Label.new();heading.position=Vector2(40,26)
    heading.add_theme_font_size_override("font_size",25)
    heading.add_theme_color_override("font_color",Color(.88,.95,.96))
    canvas.add_child(heading)
    detail=Label.new();detail.position=Vector2(42,64)
    detail.add_theme_font_size_override("font_size",15)
    detail.add_theme_color_override("font_color",Color(.44,.71,.72))
    canvas.add_child(detail)
    for material in traffic.materials:
        material.set_shader_parameter("vehicle_origin",Vector3.ZERO)
        material.set_shader_parameter("road_grade",0.0)
        material.set_shader_parameter("occlusion_sample_count",0)
        material.set_shader_parameter("camera_visibility",1.0)

func all_cars() -> Array:
    var cars: Array=[]
    for collection in [traffic.models,traffic.civilian_models,traffic.block_models]:
        for pivot in collection:cars.append(pivot)
    return cars

func choose_car(variant: String,role: String) -> Node3D:
    for pivot: Node3D in all_cars():
        if String(pivot.get_meta("fleet_variant",""))==variant and String(pivot.get_meta("fleet_role",""))==role:return pivot
    return null

func inspect_showroom() -> void:
    var selected: Array[Node3D]=[]
    var meshes: Array[Mesh]=[]
    for variant in VARIANTS:
        var pivot:=choose_car(variant,"police")
        check(pivot!=null,"Missing production police model "+variant)
        if pivot==null:continue
        var visual:=pivot.get_child(0) as MeshInstance3D
        check(visual!=null and visual.mesh!=null,"Missing actual MeshInstance3D for "+variant)
        if visual==null or visual.mesh==null:continue
        check(not meshes.has(visual.mesh),"Different variants reuse the same unchanged mesh: "+variant)
        meshes.append(visual.mesh);selected.append(pivot)
        inspect_asset(pivot,visual,variant)
    check(selected.size()==3,"Need all three distinct production variants")
    inspect_material_isolation(selected)
    for pivot: Node3D in selected:
        var variant:=String(pivot.get_meta("fleet_variant"))
        var visual:=pivot.get_child(0) as MeshInstance3D
        pivot.position=Vector3.ZERO;pivot.rotation=Vector3.ZERO;pivot.show()
        # Showroom shadow casting is for ground-contact inspection only; live
        # traffic retains its original no-shadow runtime setting.
        visual.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON
        inspect_clearance(pivot,visual,variant)
        var bounds: AABB=visual.transform*visual.get_aabb()
        var aim:=Vector3(0,bounds.size.y*.43,0)
        heading.text=TITLES[variant]
        for view in ["front-quarter","side","rear-quarter","night-rear"]:
            apply_lighting(view=="night-rear")
            match view:
                "front-quarter":camera.position=Vector3(5.2,2.55,6.25)
                "side":camera.position=Vector3(8.8,1.95,.05)
                _:camera.position=Vector3(-5.2,2.4,-6.25)
            camera.look_at(aim,Vector3.UP)
            detail.text="НОЧНОЙ РЕЖИМ · ИГРОВЫЕ МАТЕРИАЛЫ" if view=="night-rear" else "НЕЙТРАЛЬНЫЙ СВЕТ · ИМПОРТИРОВАННАЯ МОДЕЛЬ"
            for material in traffic.materials:
                material.set_shader_parameter("camera_world",Vector3(-camera.position.x,camera.position.y,camera.position.z))
            var shown: Image=await snapshot()
            pivot.hide();var bare: Image=await snapshot();pivot.show()
            var samples:=difference_samples(shown,bare,6)
            check(samples>100,variant+" absent or unreadable in "+view)
            var filename: String=variant+"-"+String(view)+".png"
            shown.save_png(output.path_join(filename))
            report.captures.append({"file":filename,"variant":variant,"role":"police","view":view,"different_samples_from_hidden_model":samples,"sample_stride":6,"camera":str(camera.global_transform),"fov":camera.fov,"source":"production traffic.setup model and material instances","showroom_only_shadow_casting":true})
        pivot.hide()
    await capture_civilian_variants()
    await capture_comparison(selected)

func capture_civilian_variants() -> void:
    var tints: Array[Color]=[]
    for variant in VARIANTS:
        var pivot:=choose_car(variant,"civilian")
        check(pivot!=null,"Missing actual civilian version "+variant)
        if pivot==null:continue
        var visual:=pivot.get_child(0) as MeshInstance3D
        var body:=visual.get_active_material(0) as ShaderMaterial
        check(body!=null and not bool(body.get_shader_parameter("fleet_police")),variant+" civilian uses police lightbar/livery role")
        if body==null:continue
        var tint: Color=body.get_shader_parameter("fleet_tint")
        check(maxf(tint.r,maxf(tint.g,tint.b))<.85,variant+" civilian base coat is not muted")
        for previous: Color in tints:check(not tint.is_equal_approx(previous),"Civilian variants all received the same coat")
        tints.append(tint)
        pivot.position=Vector3.ZERO;pivot.rotation=Vector3.ZERO;pivot.show()
        visual.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON
        var bounds: AABB=visual.transform*visual.get_aabb()
        camera.position=Vector3(5.2,2.55,6.25)
        camera.look_at(Vector3(0,bounds.size.y*.43,0),Vector3.UP)
        apply_lighting(false)
        heading.text="ГРАЖДАНСКАЯ ВЕРСИЯ · "+variant.to_upper()
        detail.text="ОБЫЧНЫЙ ТРАФИК · НЕЙТРАЛЬНЫЙ СВЕТ"
        for material in traffic.materials:
            material.set_shader_parameter("camera_world",Vector3(-camera.position.x,camera.position.y,camera.position.z))
        var shown: Image=await snapshot()
        pivot.hide();var bare: Image=await snapshot()
        var samples:=difference_samples(shown,bare,6)
        check(samples>100,variant+" civilian is absent from its actual-material picture")
        var filename: String=variant+"-civilian-front-quarter.png"
        shown.save_png(output.path_join(filename))
        report.civilian_materials.append({"variant":variant,"fleet_police":false,"fleet_tint":str(tint),"bar_visibility":"Civilian role disables the baked beacon in the production shader; inspect actual screenshot.","actual_material_picture":filename})
        report.captures.append({"file":filename,"variant":variant,"role":"civilian","view":"front-quarter","different_samples_from_hidden_model":samples,"sample_stride":6,"camera":str(camera.global_transform),"fov":camera.fov,"source":"actual production civilian model, coat and role uniforms"})

func capture_comparison(selected: Array[Node3D]) -> void:
    if selected.size()!=3:return
    apply_lighting(false)
    # An offline 2D composition of three actual 3D render targets. These
    # cameras exist only for this authoring preview, never in Level2 gameplay.
    var composition:=SubViewport.new()
    composition.name="OfflineFleetComparison"
    composition.size=Vector2i(1280,1160)
    composition.disable_3d=true
    composition.render_target_update_mode=SubViewport.UPDATE_ALWAYS
    root.add_child(composition)
    var background:=ColorRect.new();background.size=Vector2(1280,1160)
    background.color=Color(.022,.035,.044);composition.add_child(background)
    var title:=Label.new();title.text="БЕЛИЧИЙ АВТОПАРК"
    title.position=Vector2(40,16);title.add_theme_font_size_override("font_size",28)
    title.add_theme_color_override("font_color",Color(.88,.95,.96));composition.add_child(title)
    var subtitle:=Label.new();subtitle.text="ОДИН РАКУРС · ОДИН МАСШТАБ · ИГРОВЫЕ МОДЕЛИ"
    subtitle.position=Vector2(42,51);subtitle.add_theme_font_size_override("font_size",15)
    subtitle.add_theme_color_override("font_color",Color(.42,.70,.71));composition.add_child(subtitle)
    var rows: Array=[]
    for i in range(selected.size()):
        var source: Node3D=selected[i]
        var variant:=String(source.get_meta("fleet_variant"))
        var panel:=SubViewport.new();panel.size=Vector2i(1280,360)
        panel.world_3d=World3D.new();panel.msaa_3d=Viewport.MSAA_2X
        panel.render_target_update_mode=SubViewport.UPDATE_ALWAYS
        composition.add_child(panel)
        var stage:=Node3D.new();panel.add_child(stage)
        var environment:=WorldEnvironment.new();environment.environment=lighting.duplicate() as Environment
        stage.add_child(environment)
        stage.add_child(key.duplicate());stage.add_child(fill.duplicate())
        var floor_node:=MeshInstance3D.new();var shape:=PlaneMesh.new();shape.size=Vector2(120,120)
        floor_node.mesh=shape
        var floor_material:=StandardMaterial3D.new();floor_material.albedo_color=Color(.055,.071,.083);floor_material.roughness=.88
        floor_node.material_override=floor_material;stage.add_child(floor_node)
        var model:=source.duplicate() as Node3D
        model.position=Vector3.ZERO;model.rotation=Vector3.ZERO;model.show();stage.add_child(model)
        var visual:=model.get_child(0) as MeshInstance3D
        var bounds: AABB=visual.transform*visual.get_aabb()
        var side_camera:=Camera3D.new();side_camera.fov=15;side_camera.near=.05
        stage.add_child(side_camera);side_camera.position=Vector3(8.8,1.95,.05)
        side_camera.look_at(Vector3(0,bounds.size.y*.43,0),Vector3.UP);side_camera.make_current()
        for surface in range(visual.mesh.get_surface_count()):
            var original:=visual.get_active_material(surface) as ShaderMaterial
            var material:=original.duplicate() as ShaderMaterial
            material.set_shader_parameter("camera_world",Vector3(-side_camera.position.x,side_camera.position.y,side_camera.position.z))
            material.set_shader_parameter("camera_visibility",1.0)
            material.set_shader_parameter("occlusion_sample_count",0)
            visual.set_surface_override_material(surface,material)
        var picture:=TextureRect.new();picture.texture=panel.get_texture()
        picture.position=Vector2(0,80+i*360);picture.size=Vector2(1280,360)
        picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;picture.stretch_mode=TextureRect.STRETCH_SCALE
        composition.add_child(picture)
        var label:=Label.new();label.text=TITLES[variant]
        label.position=Vector2(40,93+i*360);label.add_theme_font_size_override("font_size",21)
        label.add_theme_color_override("font_color",Color(.86,.95,.95));composition.add_child(label)
        var dimension:=Label.new();dimension.text="%.2f М"%float(source.get_meta("fitted_length"))
        dimension.position=Vector2(1120,96+i*360);dimension.add_theme_font_size_override("font_size",18)
        dimension.add_theme_color_override("font_color",Color(.47,.75,.75));composition.add_child(dimension)
        rows.append({"variant":variant,"fitted_length":source.get_meta("fitted_length"),"camera":str(side_camera.global_transform),"fov":side_camera.fov,"panel_size":str(panel.size)})
    await frames(3);RenderingServer.force_draw(true)
    await frames(2);RenderingServer.force_draw(true)
    var image:=composition.get_texture().get_image()
    check(image.get_size()==Vector2i(1280,1160),"Native fleet comparison has incorrect dimensions")
    image.save_png(output.path_join("models-comparison.png"))
    report.captures.append({"file":"models-comparison.png","source":"Native 2D layout of actual production-mesh 3D render targets; no image compositing outside Godot","offline_comparison_cameras":3,"gameplay_cameras_added":0,"matched_side_profiles":rows})
    composition.queue_free();await frames(3)

func inspect_asset(pivot: Node3D,visual: MeshInstance3D,variant: String) -> void:
    var bounds: AABB=visual.transform*visual.get_aabb()
    check(visual.mesh.get_surface_count()==3,variant+" must keep three body/lens surfaces")
    check(absf(bounds.position.y)<.035,variant+" does not sit on the ground")
    check(bounds.size.x>1.65 and bounds.size.x<2.6,variant+" has implausible fitted width")
    check(bounds.size.z>4.2 and bounds.size.z<5.3,variant+" lost its distinct actual fitted length")
    check(absf(float(pivot.get_meta("fitted_length",0))-bounds.size.z)<.035,variant+" fitted length metadata differs from actual mesh")
    check(float(visual.get_meta("fitted_scale",0))>4.7 and float(visual.get_meta("fitted_scale",0))<5.0,variant+" is not using the common donor unit scale")
    var triangles:=0
    var paint_vertices:=0
    var nonpaint_vertices:=0
    var glass_vertices:=0
    var glass_paint_vertices:=0
    var positions_finite:=true
    var uvs_finite:=true
    var normals_valid:=true
    for surface in range(visual.mesh.get_surface_count()):
        var arrays:=visual.mesh.surface_get_arrays(surface)
        var positions: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
        var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
        var uv: PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
        var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
        triangles+=floori(float(indices.size())/3.0)
        for point in positions:
            if not point.is_finite():positions_finite=false
        for point in uv:
            if not point.is_finite():uvs_finite=false
        for normal in normals:
            if not normal.is_finite() or normal.length()<.9 or normal.length()>1.1:normals_valid=false
        if surface==0:
            var colors: PackedColorArray=arrays[Mesh.ARRAY_COLOR]
            check(colors.size()==positions.size(),variant+" lacks explicit per-vertex paint semantics")
            for color in colors:
                if color.r>.5:paint_vertices+=1
                else:nonpaint_vertices+=1
                if color.b>.5:
                    glass_vertices+=1
                    if color.r>=.01:glass_paint_vertices+=1
        var material:=visual.get_active_material(surface) as ShaderMaterial
        check(material!=null,variant+" lost its production shader")
        if material!=null:
            check(bool(material.get_shader_parameter("fleet_livery"))==(surface==0),variant+" livery must affect Body only")
    check(positions_finite and uvs_finite,variant+" has nonfinite imported geometry or UVs")
    check(normals_valid,variant+" has nonfinite or unnormalized imported normals")
    check(paint_vertices>500 and nonpaint_vertices>500,variant+" paint gate does not separate body panels from trim/glass")
    check(glass_vertices>100,variant+" lacks the explicit glass/mirror exclusion mask")
    check(glass_paint_vertices==0,variant+" glass/mirror received a painted-body gate")
    check(triangles>=30000 and triangles<=67000,variant+" changed the mobile geometry budget unexpectedly")
    report.assets.append({"variant":variant,"role":pivot.get_meta("fleet_role"),"fitted_bounds":str(bounds),"fitted_length_meta":pivot.get_meta("fitted_length"),"fitted_scale":visual.get_meta("fitted_scale"),"mesh_surfaces":visual.mesh.get_surface_count(),"mesh_triangles":triangles,"body_paint_vertices":paint_vertices,"body_nonpaint_vertices":nonpaint_vertices,"glass_excluded_vertices":glass_vertices,"finite_positions":positions_finite,"finite_uvs":uvs_finite,"finite_unit_normals":normals_valid,"wheel_roundness":"Review matched side-profile capture; numerical wheel subsets are separate geometry-authoring evidence."})

func inspect_material_isolation(selected: Array[Node3D]) -> void:
    var seen: Array[Material]=[]
    for pivot: Node3D in selected:
        var visual:=pivot.get_child(0) as MeshInstance3D
        for surface in range(visual.mesh.get_surface_count()):
            var material:=visual.get_active_material(surface)
            check(material is ShaderMaterial,"Fleet does not use production traffic shader")
            check(not seen.has(material),"Different fleet cars share mutable material state")
            seen.append(material)

func inspect_clearance(pivot: Node3D,visual: MeshInstance3D,variant: String) -> void:
    var bounds: AABB=visual.transform*visual.get_aabb()
    var centre:=bounds.get_center()
    var before:=pivot.transform
    traffic._clear_chase_camera(pivot,centre,centre+Vector3(0,0,8),1.0)
    check(is_zero_approx(float(pivot.get_meta("camera_visibility",1.0))),variant+" body surrounding camera is not cleared")
    var outside:=Vector3(bounds.size.x+3,centre.y,-bounds.size.z)
    traffic._clear_chase_camera(pivot,outside,outside+Vector3(0,0,bounds.size.z*2),1.0)
    check(is_equal_approx(float(pivot.get_meta("camera_visibility",0.0)),1.0),variant+" legitimate adjacent view is hidden")
    traffic._clear_chase_camera(pivot,Vector3(0,centre.y,-bounds.size.z),Vector3(0,centre.y,bounds.size.z),1.0)
    var corridor: float=pivot.get_meta("camera_visibility",1.0)
    check(corridor<=.101,variant+" blocks camera-to-player corridor")
    check(pivot.transform==before,variant+" camera clearance moved the vehicle")
    traffic._clear_chase_camera(pivot,outside,outside+Vector3(0,0,bounds.size.z*2),1.0)
    for child in pivot.get_children():
        if not child is MeshInstance3D:continue
        var mesh:=child as MeshInstance3D
        for surface in range(mesh.mesh.get_surface_count()):
            var material:=mesh.get_active_material(surface) as ShaderMaterial
            check(material!=null and is_equal_approx(float(material.get_shader_parameter("camera_visibility")),1.0),variant+" did not restore body/lamp/beacon coverage")
    report.camera_clearance.append({"variant":variant,"camera_inside":"cleared","adjacent_view":"opaque","intervening_coverage":corridor,"vehicle_pose_unchanged":pivot.transform==before})

func apply_lighting(night: bool) -> void:
    lighting.background_color=Color(.012,.024,.041) if night else Color(.085,.109,.135)
    lighting.ambient_light_color=Color(.39,.56,.76) if night else Color(.71,.79,.86)
    lighting.ambient_light_energy=.26 if night else .72
    key.light_color=Color(.57,.73,1) if night else Color(1,.94,.84)
    key.light_energy=.7 if night else 1.6
    fill.light_energy=.22 if night else .42

func snapshot() -> Image:
    await frames(2)
    RenderingServer.force_draw(true)
    return root.get_texture().get_image()

func difference_samples(a: Image,b: Image,stride: int=6) -> int:
    if a.get_size()!=b.get_size():return -1
    var count:=0
    for y in range(0,a.get_height(),stride):
        for x in range(0,a.get_width(),stride):
            var ca:=a.get_pixel(x,y);var cb:=b.get_pixel(x,y)
            if maxf(absf(ca.r-cb.r),maxf(absf(ca.g-cb.g),absf(ca.b-cb.b)))>.04:count+=1
    return count

func place(car,z: float,lane: float,yaw: float=0.0) -> void:
    var phase: float=(z+car.grid_world_z_offset)/40.0
    var n: int=level.controller.track_pattern.size()
    car.lap=floori(phase/n);car.segment_index=posmod(floori(phase),n)
    car.segment_progress=phase-floor(phase);car.world_z=z
    car.world_x=RoadMath.track_center_x(z/40.0,level.controller.track_x)+lane
    car.lateral_offset=lane;car.heading_yaw=yaw

func inspect_actual_level() -> void:
    level=load("res://scenes/level2.tscn").instantiate();root.add_child(level);current_scene=level
    await frames(10)
    level.set_physics_process(false);level.set_process(false)
    level.state.race_started=true;level.state.countdown=0;level.state.race_time=30
    level.hud_panel.hide_countdown()
    var player=level.controller.player
    var director=level.controller.pursuit.encounters
    level.controller.pursuit.cooldown=10000
    var live_traffic=level.car_3d_overlay.traffic
    check(level.car_3d_overlay.world_root.find_children("*","Camera3D",true,false).size()==1,"Live fleet created additional gameplay cameras")
    place(player,900,1.35);player.speed=45
    for i in range(level.controller.ais.size()):
        place(level.controller.ais[i].car,900+17+i*13,[-1.7,1.5,-.2][i])
        level.controller.ais[i].car.brake_in=0
    for i in range(director.traffic.size()):director.traffic[i].place(930+i*85,-2.45,level.controller.track_x)
    level.camera_state.reset(player);level._process(1.0)
    for i in range(live_traffic.rear_materials.size()):
        check(absf(float(live_traffic.rear_materials[i].get_shader_parameter("lamp_energy"))-1.2)<.02,"Rival running lamps changed unexpectedly")
    level.controller.ais[1].car.brake_in=1;level._process(1.0)
    for i in range(live_traffic.rear_materials.size()):
        var energy: float=live_traffic.rear_materials[i].get_shader_parameter("lamp_energy")
        check(energy>6.9 if i==1 else energy<1.3,"Braking light leaked between fleet cars")
    await capture_level("live-level2-mixed-fleet")
    var observed: Array=[]
    for collection in [live_traffic.models,live_traffic.civilian_models,live_traffic.block_models]:
        for pivot in collection:
            observed.append({"name":String(pivot.name),"variant":pivot.get_meta("fleet_variant",""),"role":pivot.get_meta("fleet_role",""),"visible":pivot.visible,"fitted_length":pivot.get_meta("fitted_length",0.0)})
    var block: Dictionary=director.roadblocks[0];director._build_block(block)
    place(player,block.z-28,0);player.speed=35
    for i in range(level.controller.ais.size()):place(level.controller.ais[i].car,player.world_z-65-i*12,[-2.5,2.5,0][i])
    for car in director.traffic:car.place(player.world_z-600,-2.45,level.controller.track_x)
    director.clock=2
    await capture_level("live-level2-patrol-roadblock")
    check(live_traffic.block_models[0].visible and live_traffic.block_models[1].visible,"Actual roadblock fleet does not render")
    report["actual_level2"]={"shared_vehicle_cameras":1,"staged_pose_not_driving_replay":true,"independent_braking_lamps":"PASS" if failures.is_empty() else "see failures","fleet":observed}
    current_scene=null;level.queue_free();level=null
    await frames(6)

func capture_level(label: String) -> void:
    level.state.player_progress=level.controller.player.physical_progress(level.controller.track_pattern.size())
    level.controller._sync_hud();level.camera_state.reset(level.controller.player)
    level._process(1.0)
    level.presentation._timer=0;level.presentation._process(.1)
    var image: Image=await snapshot()
    var filename:=label+".png";image.save_png(output.path_join(filename))
    report.captures.append({"file":filename,"source":"actual Level2 scene, production model selection, materials, lights and shared vehicle viewport","staged_pose_not_driving_replay":true,"render_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)})
