extends SceneTree
# Preserve the supplied high-detail GLB; bake its actual lighting for mobile.
func _init() -> void: call_deferred("_run")
func _run() -> void:
    if DisplayServer.get_name()=="headless": quit(1);return
    var viewport := SubViewport.new()
    viewport.size=Vector2i(384,320);viewport.world_3d=World3D.new();viewport.transparent_bg=true
    viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;viewport.msaa_3d=Viewport.MSAA_2X
    root.add_child(viewport)
    var scene := Node3D.new();viewport.add_child(scene)
    var env := WorldEnvironment.new();env.environment=Environment.new()
    env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color(0,0,0,0)
    env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
    env.environment.ambient_light_color=Color(.53,.66,.84);env.environment.ambient_light_energy=.68
    var sky := Sky.new();var sky_material := ProceduralSkyMaterial.new()
    sky_material.sky_top_color=Color(.05,.10,.19);sky_material.sky_horizon_color=Color(.37,.46,.61)
    sky_material.ground_horizon_color=Color(.18,.23,.29);sky_material.ground_bottom_color=Color(.015,.024,.03)
    sky.sky_material=sky_material;env.environment.sky=sky
    env.environment.reflected_light_source=Environment.REFLECTION_SOURCE_SKY
    env.environment.tonemap_mode=Environment.TONE_MAPPER_FILMIC;scene.add_child(env)
    var light := DirectionalLight3D.new();light.rotation_degrees=Vector3(-40,-25,0);light.light_energy=1.65;light.shadow_enabled=false;scene.add_child(light)
    var fill := DirectionalLight3D.new();fill.rotation_degrees=Vector3(15,130,0);fill.light_energy=.35;scene.add_child(fill)
    var pivot := Node3D.new();scene.add_child(pivot)
    var archive := ZIPReader.new()
    assert(archive.open("res://assets/level2/source/camry-source.zip")==OK)
    var bytes := archive.read_file("toyota_camry_2018_glass_wipers_corrected.glb");archive.close()
    var document := GLTFDocument.new();var state := GLTFState.new()
    assert(document.append_from_buffer(bytes,"res://assets/level2/source",state)==OK)
    var car: Node3D=document.generate_scene(state);pivot.add_child(car)
    var bounds := AABB();var first := true
    var tail_materials: Array[StandardMaterial3D]=[]
    for node in car.find_children("*","MeshInstance3D",true,false):
        var box: AABB=node.global_transform*node.get_aabb()
        bounds=box if first else bounds.merge(box);first=false
        for surface in range(node.mesh.get_surface_count()):
            var source: Material=node.get_active_material(surface)
            if source is not StandardMaterial3D: continue
            var mat: StandardMaterial3D=source.duplicate()
            if String(source.resource_name).contains("Camry_tail"):
                mat.emission_enabled=true;mat.albedo_color=Color(.45,.006,.002)
                mat.emission=Color(1,.03,.006);mat.emission_energy_multiplier=.75
                tail_materials.append(mat)
            elif String(source.resource_name).contains("Camry_lamp"):
                mat.emission_enabled=true;mat.emission=Color(.9,.96,1);mat.emission_energy_multiplier=2.8
            if String(source.resource_name)=="Camry_paint":
                mat.metallic=.35;mat.roughness=.36;mat.metallic_specular=.7
            # Keep imported face winding and glass transparency intact.
            node.set_surface_override_material(surface,mat)
    assert(not tail_materials.is_empty(),"Camry rear lamp material missing")
    var scale_ := 4.86/maxf(bounds.size.x,bounds.size.z)
    car.scale=Vector3.ONE*scale_;car.position=Vector3(-bounds.get_center().x,-bounds.position.y,-bounds.get_center().z)*scale_
    if bounds.size.x>bounds.size.z:
        car.position=Basis(Vector3.UP,PI*.5)*car.position;car.rotation.y=PI*.5
    var camera := Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=5.4
    camera.position=Vector3(0,2.2,-8);scene.add_child(camera);camera.look_at(Vector3(0,.8,.8));camera.make_current()
    var atlas := Image.create(384*9,320*2,false,Image.FORMAT_RGBA8)
    var feet: Array=[]
    for state_ in range(2):
        for mat in tail_materials: mat.emission_energy_multiplier=.75 if state_==0 else 3.6
        for i in range(9):
            pivot.rotation.y=deg_to_rad(float(i-4)*10.0)
            for j in range(3): await process_frame
            await RenderingServer.frame_post_draw
            var foot := camera.unproject_position(pivot.global_transform*Vector3(0,0,-1.65))
            if state_==0: feet.append([foot.x,foot.y])
            atlas.blit_rect(viewport.get_texture().get_image(),Rect2i(Vector2i.ZERO,viewport.size),Vector2i(384*i,320*state_))
    assert(atlas.save_png("res://assets/level2/traffic_camry.png")==OK)
    FileAccess.open("res://assets/level2/traffic_camry.json",FileAccess.WRITE).store_string(JSON.stringify({"source":"toyota_camry_2018_glass_wipers_corrected.glb","length_metres":4.86,"frame_width":384,"frame_height":320,"height_metres":5.4,"angles":9,"states":["running","braking"],"step_degrees":10,"feet":feet},"  "))
    print("CAMRY BAKE: PASS — user's original model, 9 angles, position lamps and bright brake lamps")
    viewport.queue_free();await process_frame;quit(0)
