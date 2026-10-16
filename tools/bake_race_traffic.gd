extends SceneTree
# Offline rear views of the supplied compact. Runtime rivals use one atlas.
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
    env.environment.ambient_light_color=Color(.64,.73,.88);env.environment.ambient_light_energy=.85
    env.environment.tonemap_mode=Environment.TONE_MAPPER_FILMIC;scene.add_child(env)
    var light := DirectionalLight3D.new();light.rotation_degrees=Vector3(-40,-25,0);light.light_energy=1.4;light.shadow_enabled=false;scene.add_child(light)
    var pivot := Node3D.new();scene.add_child(pivot)
    var car: Node3D=load("res://compact+car+3d+model.glb").instantiate();pivot.add_child(car)
    var bounds := AABB();var first := true
    for node in car.find_children("*","MeshInstance3D",true,false):
        var box: AABB=node.global_transform*node.get_aabb()
        bounds=box if first else bounds.merge(box);first=false
    var scale_ := 4.1/maxf(bounds.size.x,bounds.size.z)
    car.scale=Vector3.ONE*scale_;car.position=Vector3(-bounds.get_center().x,-bounds.position.y,-bounds.get_center().z)*scale_
    if bounds.size.x>bounds.size.z:
        car.position=Basis(Vector3.UP,PI*.5)*car.position;car.rotation.y=PI*.5
    var camera := Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=5.0
    camera.position=Vector3(0,2.2,-8);scene.add_child(camera);camera.look_at(Vector3(0,.8,.8));camera.make_current()
    var atlas := Image.create(384*9,320,false,Image.FORMAT_RGBA8)
    var feet: Array=[]
    for i in range(9):
        pivot.rotation.y=deg_to_rad(float(i-4)*10.0)
        for j in range(3): await process_frame
        await RenderingServer.frame_post_draw
        var foot := camera.unproject_position(pivot.global_transform*Vector3(0,0,-1.394))
        feet.append([foot.x,foot.y])
        atlas.blit_rect(viewport.get_texture().get_image(),Rect2i(Vector2i.ZERO,viewport.size),Vector2i(384*i,0))
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/level2"))
    assert(atlas.save_png("res://assets/level2/traffic_compact.png")==OK)
    FileAccess.open("res://assets/level2/traffic_compact.json",FileAccess.WRITE).store_string(JSON.stringify({"frame_width":384,"frame_height":320,"width_metres":6.0,"height_metres":5.0,"angles":9,"step_degrees":10,"feet":feet},"  "))
    print("RACE TRAFFIC BAKE: PASS — supplied compact, 9 rear angles, numeric contact anchors")
    viewport.queue_free();await process_frame;quit(0)
