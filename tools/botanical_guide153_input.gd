extends RefCounted
## The Android touch plus its emulated GUI click, through the real viewport.
## Only acknowledges a modal which production actually presented.
static func acknowledge(tree: SceneTree,game: Node) -> bool:
    for i in range(3):await tree.process_frame
    if not is_instance_valid(game.guardian_guide):return false
    var button: Button=game.guardian_guide.continue_button
    var point: Vector2=button.get_global_rect().get_center()
    var touch:=InputEventScreenTouch.new();touch.index=16;touch.position=point;touch.pressed=true
    tree.root.push_input(touch,true)
    await tree.process_frame
    var mouse:=InputEventMouseButton.new();mouse.device=InputEvent.DEVICE_ID_EMULATION
    mouse.button_index=MOUSE_BUTTON_LEFT;mouse.position=point;mouse.global_position=point;mouse.pressed=true
    tree.root.push_input(mouse,true)
    await tree.process_frame
    touch.pressed=false;tree.root.push_input(touch,true)
    mouse.pressed=false;tree.root.push_input(mouse,true)
    for i in range(3):await tree.process_frame
    return not is_instance_valid(game.guardian_guide) and not tree.paused
