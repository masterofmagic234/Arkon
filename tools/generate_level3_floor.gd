extends SceneTree
# Offline native authoring: retain the supplied wall/grain pixels and cache
# thousands of immutable floor drawing commands into one lit texture.
func _init() -> void: call_deferred("_run")
func _run() -> void:
    # An isolated viewport has an identity canvas transform. The project window
    # uses canvas_items stretch, which must never rescale an authored map bake.
    var viewport := SubViewport.new()
    viewport.size=Vector2i(1088,782)
    viewport.world_2d=World2D.new()
    viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
    viewport.canvas_item_default_texture_filter=Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
    root.add_child(viewport)
    var floor_ := preload("res://scripts/level3_layout_floor.gd").new()
    floor_.authoring_bake=true
    floor_.position=Vector2(160,100)
    viewport.add_child(floor_)
    for i in range(4): await process_frame
    await RenderingServer.frame_post_draw
    var image := viewport.get_texture().get_image()
    # Check real pixels at authored world coordinates: a scaled window bake
    # puts the street under the entrance and fails these facade/sidewalk probes.
    if image.get_size()!=viewport.size or not image.get_pixel(360,626).is_equal_approx(Color("4e5a61")) or not image.get_pixel(296,598).is_equal_approx(Color("272933")):
        push_error("LEVEL 3 FLOOR BAKE: authored wall/sidewalk coordinates do not match rendered pixels")
        quit(1)
        return
    var output := "res://assets/level3/materials/diner_floor.png"
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output.get_base_dir()))
    var result := image.save_png(output)
    if result!=OK:
        push_error("LEVEL 3 FLOOR BAKE: save failed")
        quit(1)
        return
    print("LEVEL 3 FLOOR BAKE: PASS — 1088 × 782; supplied wall/grain assets; one runtime texture")
    viewport.queue_free()
    await process_frame
    root.get_node("AudioManager").shutdown()
    OS.delay_msec(80)
    quit(0)
