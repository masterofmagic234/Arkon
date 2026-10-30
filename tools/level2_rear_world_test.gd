extends SceneTree
## Staged real-world camera regression, not a driving/FPS benchmark.
## Coverage probes are independent of the renderer's sample layout: the flat
## road/earth must fill the lower viewing frustum at every camera heading.
const Data=preload("res://scripts/race_level_data.gd")
const Math=preload("res://scripts/race_math.gd")
const Teardown=preload("res://tools/level3_test_teardown.gd")
var level
var visual := false
var output := ""
var failed := false
var reports: Array[Dictionary]=[]
var captures: Array[String]=[]
func _init() -> void:
    for arg in OS.get_cmdline_user_args():
        if arg=="--visual":visual=true
        elif arg.begins_with("--output="):output=arg.trim_prefix("--output=")
    call_deferred("run")
func check(ok: bool,message: String) -> bool:
    if not ok:push_error("REAR WORLD: "+message);failed=true
    return ok
func run() -> void:
    if visual and not check(DisplayServer.get_name()!="headless","native framebuffer is required"):
        quit(1);return
    RenderingServer.set_render_loop_enabled(false)
    root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED;root.size=Vector2i(960,540)
    root.get_node("GameState").music_muted=true;root.get_node("GameState").sfx_muted=true
    level=load("res://scenes/level2.tscn").instantiate();root.add_child(level);current_scene=level
    for i in range(8):
        root.get_node("PauseManager").resume();await process_frame
    level.set_process(false);level.set_physics_process(false)
    if visual: await _canvas_sampler_check()
    var group_count: int=level.renderer.scenery.groups.size()
    var positions: Array[float]=[0,420,Data.BRIDGE_START-20,Data.BRIDGE_START+220,Data.BRIDGE_END+20,Data.TUNNEL_START-20,Data.TUNNEL_START+100,Data.TUNNEL_END-100,Data.TUNNEL_END+20,Data.CITY_START+160,Data.route_length()-8,Data.route_length()+8]
    var headings: Array[float]=[-PI,-PI*.5,-Data.NFS_MAX_HEADING_YAW,0,Data.NFS_MAX_HEADING_YAW,PI*.5,deg_to_rad(165),PI]
    for dimensions: Vector2 in [Vector2(960,540),Vector2(1280,720),Vector2(1600,720)]:
        root.size=Vector2i(dimensions)
        await process_frame
        for z in positions:
            for yaw in headings:
                _place(z,yaw)
                var renderer=level.renderer
                renderer.road_mesh.update(renderer,dimensions)
                renderer.scenery.begin(renderer,dimensions);renderer.scenery.draw(renderer,dimensions)
                var triangles := _ground_triangles(renderer)
                check(not triangles.is_empty(),"ground disappeared at Z %.1f yaw %.1f"%[z,rad_to_deg(yaw)])
                check(renderer.scenery.groups.size()==group_count,"camera movement rebuilt/appended scenery groups")
                check(renderer.scenery.transformed_vertices<=4000 and renderer.scenery.triangles<=2400,"unbounded scenic submission at Z %.1f yaw %.1f (%d points/%d triangles)"%[z,rad_to_deg(yaw),renderer.scenery.transformed_vertices,renderer.scenery.triangles])
                check(renderer.scenery.terrain_lookups<=48,"rear terrain cache exceeds48 shared lookups")
                check(renderer.scenery.selected_groups>0,"rear camera culled every roadside group")
                var coverage := 0
                var footer_coverage := 0
                if z in [0.0,420.0,Data.CITY_START+160]:
                    for column in range(10):
                        var x: float=dimensions.x*(.05+.90*column/9.0)
                        for fraction: float in [.72,.84,.97]:
                            var point := Vector2(x,dimensions.y*renderer.PLAYFIELD_FRACTION*fraction)
                            if _covered(point,triangles):coverage+=1
                    check(coverage==30,"flat ground has a void: %d/30 probes at Z %.1f yaw %.1f"%[coverage,z,rad_to_deg(yaw)])
                    # Ground alone now continues behind the translucent HUD.
                    # Keep the original 30 above-field probes intact and sample
                    # three separate footer depths across the same flat stages.
                    for column in range(10):
                        var x: float=dimensions.x*(.05+.90*column/9.0)
                        for fraction: float in [.76,.88,.98]:
                            if _covered(Vector2(x,dimensions.y*fraction),triangles):footer_coverage+=1
                    check(footer_coverage==30,"real ground missing beneath HUD: %d/30 probes at Z %.1f yaw %.1f"%[footer_coverage,z,rad_to_deg(yaw)])
                reports.append({"viewport":dimensions,"z":z,"yaw_degrees":rad_to_deg(yaw),"ground_triangles":triangles.size(),"flat_ground_probes":coverage,"footer_ground_probes":footer_coverage,"scenic_groups":renderer.scenery.selected_groups,"scenic_points":renderer.scenery.transformed_vertices,"scenic_triangles":renderer.scenery.triangles,"terrain_lookups":renderer.scenery.terrain_lookups})
                if visual and dimensions==Vector2(1280,720) and yaw in [0.0,PI*.5,deg_to_rad(165),PI] and z in [420.0,Data.BRIDGE_START+220,Data.TUNNEL_START+100,Data.TUNNEL_END+20,Data.CITY_START+160,Data.route_length()-8,Data.route_length()+8]:
                    await _capture("z-%04d-yaw-%03d"%[z,roundi(rad_to_deg(yaw))])
                if failed:break
            if failed:break
        if failed:break
    if not output.is_empty():
        DirAccess.make_dir_recursive_absolute(output)
        FileAccess.open(output.path_join("rear-world-report.json"),FileAccess.WRITE).store_string(JSON.stringify({"renderer":RenderingServer.get_current_rendering_method(),"cases":reports,"captures":captures,"failures":failed,"note":"Real production world/camera at staged headings and boundaries. Not a device FPS result."},"  "))
    level.queue_free();current_scene=null
    for i in range(4):await process_frame
    await Teardown.drain_audio(self)
    RenderingServer.set_render_loop_enabled(true)
    if not failed:print("REAR WORLD: PASS — ",reports.size()," real-world headings/boundaries, complete flat-ground coverage, retained rear scenery, bounded clipped geometry")
    quit(1 if failed else 0)
func _place(z: float,yaw: float) -> void:
    var player=level.controller.player
    var canonical: float=(z+player.grid_world_z_offset)/40
    player.segment_index=floori(canonical);player.segment_progress=canonical-player.segment_index
    player.world_z=z;player.world_x=Math.track_center_x(z/40,level.controller.track_x);player.lateral_offset=0;player.heading_yaw=yaw
    level.camera_state.reset(player);level._process(0)
func _ground_triangles(renderer) -> Array[PackedVector2Array]:
    var result: Array[PackedVector2Array]=[]
    # Only road/verge meshes use this full-window clip. The scenery and lens
    # retain their established playfield framing and submission checks above.
    var bounds := Rect2(Vector2(-.03,-.03),Vector2(root.size.x+.06,root.size.y+.06))
    for mesh in [renderer.road_mesh.road,renderer.road_mesh.far_road,renderer.road_mesh.verge,renderer.road_mesh.far_verge]:
        if mesh.get_surface_count()==0:continue
        var arrays: Array=mesh.surface_get_arrays(0)
        var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
        for vertex in vertices:
            check(vertex.is_finite() and bounds.has_point(Vector2(vertex.x,vertex.y)),"a road/verge vertex escaped camera-space clipping")
        var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
        for i in range(0,indices.size(),3):
            var polygon := PackedVector2Array()
            for j in range(3):
                var v := vertices[indices[i+j]];polygon.append(Vector2(v.x,v.y))
            result.append(polygon)
    return result
func _covered(point: Vector2,triangles: Array[PackedVector2Array]) -> bool:
    for triangle in triangles:
        if Geometry2D.is_point_in_polygon(point,triangle):return true
    return false
func _capture(name_: String) -> void:
    for i in range(2):await process_frame
    RenderingServer.force_draw(true)
    await process_frame
    RenderingServer.force_draw(true)
    var picture := root.get_texture().get_image()
    check(picture!=null and not picture.is_empty(),"empty native image")
    if not output.is_empty():
        DirAccess.make_dir_recursive_absolute(output)
        var path := output.path_join(name_+".png")
        check(picture.save_png(path)==OK,"cannot save native image")
        captures.append(path)

func _canvas_sampler_check() -> void:
    # Exercise a real child primitive: ANISO inherited from Renderer formerly
    # made bridge rails/facades invisible even though geometry tests passed.
    var marker := Polygon2D.new()
    marker.color=Color(1,.05,.25,1)
    marker.polygon=PackedVector2Array([Vector2(360,75),Vector2(430,75),Vector2(430,135),Vector2(360,135)])
    marker.z_index=10
    level.renderer.add_child(marker)
    for i in range(3):await process_frame
    RenderingServer.force_draw(true)
    await process_frame
    RenderingServer.force_draw(true)
    var image := root.get_texture().get_image()
    var pixel := image.get_pixel(395,105)
    check(pixel.r>.9 and pixel.g<.12 and pixel.b>.17 and pixel.b<.34,"solid projected Canvas primitive is missing; inherited sampler regression")
    marker.queue_free()
    await process_frame
