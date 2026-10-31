extends SceneTree
## Integration check for the optional graphics chooser, real mouse input,
## keyboard focus and save/progress isolation. Run with a fresh user directory.
var failures:=0
var output_dir:=""
var _entry_count:=0

func _init() -> void:
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--output="):output_dir=arg.trim_prefix("--output=")
    call_deferred("_run")

func _check(condition: bool,message: String) -> bool:
    if not condition:
        failures+=1;push_error("GRAPHICS MENU156: "+message)
    return condition

func _settle(frames: int=3) -> void:
    for frame in range(frames):await process_frame

func _click(button: Control) -> void:
    var at:=button.get_global_rect().get_center()
    for pressed in [true,false]:
        var event:=InputEventMouseButton.new()
        event.position=at;event.global_position=at
        event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed
        Input.parse_input_event(event)
        await process_frame
    await _settle()

func _key(code: Key) -> void:
    for pressed in [true,false]:
        var event:=InputEventKey.new()
        event.keycode=code;event.physical_keycode=code;event.pressed=pressed
        Input.parse_input_event(event)
        await process_frame

func _count_entry() -> void:
    _entry_count+=1

func _capture(name: String) -> void:
    if output_dir.is_empty():return
    await RenderingServer.frame_post_draw
    var picture:=root.get_texture().get_image()
    if not _check(picture!=null and not picture.is_empty(),"empty native capture"):return
    DirAccess.make_dir_recursive_absolute(output_dir)
    _check(picture.save_png(output_dir.path_join(name+".png"))==OK,"could not save capture")

func _run() -> void:
    var service:=root.get_node_or_null("GraphicsSettings")
    if not _check(service!=null,"GraphicsSettings autoload missing"):quit(1);return
    var flow:=root.get_node("SceneFlow")
    flow.call("go_to",&"menu")
    var deadline:=Time.get_ticks_msec()+10000
    while Time.get_ticks_msec()<deadline:
        await process_frame
        if current_scene!=null and current_scene.scene_file_path=="res://menu.tscn" and not bool(flow.get("_transitioning")):break
    if not _check(current_scene!=null and current_scene.scene_file_path=="res://menu.tscn","menu did not load"):quit(1);return
    await _settle()
    var menu: Control=current_scene
    var chooser: Control=menu.get_node("GraphicsPanel156")
    var launch: Button=menu.get_node("LevelButtons/IntroButton")
    var entry: Button=menu.get_node("GraphicsButton")
    for path in ["LevelButtons/IntroButton","LevelButtons/Level1Button","LevelButtons/Level2Button","LevelButtons/Level3Button"]:
        _check(menu.get_node(path) is Button,"existing launch button path changed: "+path)
    _check(launch.has_focus(),"first launch lost intro keyboard focus")
    _check(not chooser.visible,"graphics chooser gates first launch")
    _check(entry.size.y>=64,"graphics entry is too small for touch")
    var bounds:=Rect2(Vector2.ZERO,menu.size)
    _check(bounds.encloses(entry.get_global_rect()),"graphics button is outside menu")
    for item in [menu.get_node("LevelButtons"),menu.get_node("RendererStatus"),menu.get_node("Footer"),menu.get_node("Hint")]:
        _check(not entry.get_global_rect().intersects(item.get_global_rect()),"graphics entry overlaps "+str(item.name))
    var canvas_before:=root.content_scale_size
    var window_before:=root.size
    var mode_before: String=str(service.call("get_summary").get("mode","auto"))
    var state:=root.get_node("GameState")
    state.set("player_hp",73);state.set("player_ammo",17)
    state.call("mark_completed",&"level2")
    state.call("save_settings")
    var audio_before:=FileAccess.get_file_as_bytes("user://settings.cfg")
    var checkpoint=preload("res://scripts/botanical_state.gd").new()
    checkpoint.journal=true;checkpoint.save()
    var checkpoint_before:=FileAccess.get_file_as_bytes(checkpoint.PATH)
    entry.pressed.connect(_count_entry)
    await _capture("01-menu")
    await _click(entry)
    _check(chooser.visible,"mouse click did not open chooser")
    var panel: PanelContainer=chooser.get("panel")
    _check(bounds.encloses(panel.get_global_rect()),"modal extends outside mobile landscape menu")
    var buttons: Dictionary=chooser.get("mode_buttons")
    for mode in ["auto","low","balanced","high"]:
        var button: Button=buttons[mode]
        _check(button.size.y>=64,"small graphics option: "+mode)
        _check(panel.get_global_rect().encloses(button.get_global_rect()),"graphics option is clipped: "+mode)
        await _click(button)
        var summary: Dictionary=service.call("get_summary")
        _check(str(summary.get("mode"))==mode,"click did not select graphics mode: "+mode)
        _check(button.button_pressed,"selected option has no selected state: "+mode)
        for other in buttons:
            if other!=mode:_check(not buttons[other].button_pressed,"multiple selected graphics modes")
    _check(root.content_scale_size==canvas_before and root.size==window_before,"preset changed full UI/window resolution")
    await _capture("02-graphics-quality")
    # The menu entry remains physically underneath the shade, outside the panel.
    await _click(entry)
    _check(_entry_count==1 and chooser.visible,"modal allowed mouse input through to underlying menu")
    # Modal focus stays within its own controls, including after a full Tab loop.
    for step in range(8):
        await _key(KEY_TAB)
        var focused:=root.gui_get_focus_owner()
        _check(focused!=null and chooser.is_ancestor_of(focused),"Tab escaped modal into level launch buttons")
    await _click(chooser.get("reset_button"))
    _check(str(service.call("get_summary").get("mode"))=="auto","repeat selection did not return to auto")
    var line: Label=chooser.get("current_line")
    _check(line.text.begins_with("Авто · ") and line.text.contains("кадр"),"auto summary omits selected profile/frame target")
    _check(int(state.get("player_hp"))==73 and int(state.get("player_ammo"))==17 and state.call("is_completed",&"level2"),"graphics selection reset active run")
    _check(FileAccess.get_file_as_bytes("user://settings.cfg")==audio_before,"graphics selection changed audio/settings save")
    _check(FileAccess.get_file_as_bytes(checkpoint.PATH)==checkpoint_before,"graphics selection changed gameplay checkpoint")
    await _capture("03-graphics-auto")
    root.size=Vector2i(1600,720)
    await _settle(5)
    var wide_bounds:=Rect2(Vector2.ZERO,menu.size)
    _check(wide_bounds.encloses(panel.get_global_rect()),"modal is outside a wide phone viewport")
    for button in buttons.values():
        _check(panel.get_global_rect().encloses(button.get_global_rect()),"wide phone clips graphics option")
    await _capture("04-graphics-wide-phone")
    await _key(KEY_ESCAPE)
    _check(not chooser.visible and entry.has_focus(),"Escape did not close modal and restore focus")
    _check(not paused and not bool(root.get_node("PauseManager").get("is_paused")),"Escape leaked through to pause manager")
    await _click(entry)
    await _click(chooser.get("close_button"))
    _check(not chooser.visible and entry.has_focus(),"close button failed")
    root.size=window_before
    service.call("set_mode",mode_before)
    await _settle()
    checkpoint=null
    if failures==0:print("GRAPHICS MENU156 PASS: optional four presets, mouse, modal focus, Escape, UI resolution and save isolation")
    quit(0 if failures==0 else 1)
