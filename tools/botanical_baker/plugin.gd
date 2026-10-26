@tool
extends EditorPlugin
func _enter_tree() -> void:
    if not OS.get_environment("BOTANICAL_BAKE_SCENE").is_empty():call_deferred("run")
func run() -> void:
    var fs=EditorInterface.get_resource_filesystem()
    while fs.is_scanning():await get_tree().process_frame
    ProjectSettings.set_setting("rendering/lightmapping/denoising/denoiser",0)
    ProjectSettings.set_setting("rendering/lightmapping/bake_quality/low_quality_ray_count",32)
    ProjectSettings.set_setting("rendering/lightmapping/bake_quality/low_quality_probe_ray_count",128)
    var target=OS.get_environment("BOTANICAL_BAKE_SCENE")
    # Opening a 3D viewport can auto-reimport textures from inside an editor
    # progress loop. Baking from that nested loop cannot save/reimport atlases.
    EditorInterface.set_main_screen_editor("Script")
    await get_tree().create_timer(10.0).timeout
    var scene: Node
    for attempt in range(40):
        if not fs.is_scanning():EditorInterface.open_scene_from_path(target)
        await get_tree().create_timer(.25).timeout
        scene=EditorInterface.get_edited_scene_root()
        if scene!=null and scene.scene_file_path==target:break
    EditorInterface.set_main_screen_editor("Script")
    if scene==null or scene.scene_file_path!=target:push_error("BAKE: target scene did not open");get_tree().quit(1);return
    var gi=scene.get_node_or_null("BakedGI")
    if gi==null:push_error("BAKE: missing GI node");get_tree().quit(1);return
    EditorInterface.edit_node(gi)
    await get_tree().create_timer(5.0).timeout
    while fs.is_scanning():await get_tree().process_frame
    for i in range(10):await get_tree().process_frame
    var button: Button
    for node in EditorInterface.get_base_control().find_children("*","Button",true,false):
        if node.text=="Bake Lightmaps":button=node;break
    if button==null or button.disabled:push_error("BAKE: native lightmap button unavailable");get_tree().quit(1);return
    print("BOTANICAL BAKE BEGIN ",scene.scene_file_path," DATA ",gi.light_data.resource_path)
    button.pressed.emit()
    print("BOTANICAL BAKE RETURN users=",gi.light_data.get_user_count())
    if gi.light_data.get_user_count()==0:push_error("BAKE: empty result");get_tree().quit(1);return
    EditorInterface.save_scene()
    print("BOTANICAL BAKE SUCCESS ",gi.light_data.resource_path)
    get_tree().quit()
