from pathlib import Path

path = Path("scripts/level3_store.gd")
text = path.read_text(encoding="utf-8")

old = '''    var mouse_pressed := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
    if dialogue_active:
        if mouse_pressed:
            # The same physical click that advances the final dialogue line
            # must not become a gameplay shot on the next frame.
            _mouse_fire_suppressed = true
        _mouse_fire_held = false
    else:
        if not mouse_pressed:
            _mouse_fire_suppressed = false
        _mouse_fire_held = mouse_pressed and not _mouse_fire_suppressed

    var action_down := Input.is_key_pressed(KEY_E)
    if action_down and not _keyboard_action_down:
        _pending_action = true
    _keyboard_action_down = action_down

    var throw_down := Input.is_key_pressed(KEY_Q)
    if throw_down and not _keyboard_throw_down:
        _pending_throw = true
    _keyboard_throw_down = throw_down

    _sprint_held = _sprint_held or Input.is_key_pressed(KEY_SHIFT)
'''

new = '''    var fire_pressed := Input.is_action_pressed("l3_fire")
    if dialogue_active:
        if fire_pressed:
            # The same physical click that advances the final dialogue line
            # must not become a gameplay shot on the next frame.
            _mouse_fire_suppressed = true
        _mouse_fire_held = false
    else:
        if not fire_pressed:
            _mouse_fire_suppressed = false
        _mouse_fire_held = fire_pressed and not _mouse_fire_suppressed

    if Input.is_action_just_pressed("l3_action"):
        _pending_action = true

    if Input.is_action_just_pressed("l3_throw"):
        _pending_throw = true

    var sprint_input := Input.is_action_pressed("l3_sprint")
    var sprint_held := _sprint_held or sprint_input
'''

if old not in text:
    raise SystemExit("Expected legacy L3 direct-input block was not found; refusing to modify the file.")

text = text.replace(old, new, 1)
text = text.replace('''        _sprint_held\n    )''', '''        sprint_held\n    )''', 1)
path.write_text(text, encoding="utf-8")
