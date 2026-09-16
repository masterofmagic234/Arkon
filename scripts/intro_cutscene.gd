extends Control

var elapsed := 0.0
var finished := false

func _ready() -> void:
    $Dialogue.visible = false
    $Darina.visible = false
    $Carolina.position = Vector2(390, 410)

func _process(delta: float) -> void:
    if finished:
        return
    elapsed += delta
    if elapsed >= 3.0 and elapsed < 4.0:
        $Darina.visible = true
    if elapsed >= 5.0 and elapsed < 6.0:
        $Dialogue.visible = true
        $Dialogue/Speaker.text = "ДАРИНА"
        $Dialogue/Text.text = "Оййй... а нам, кстати, поделку на завтра задали.........."
    if elapsed >= 9.0 and elapsed < 10.0:
        $Dialogue/Speaker.text = "КАРОЛИНА"
        $Dialogue/Text.text = "...Ладно. Где эти жёлуди?"
        $Carolina.position = Vector2(425, 365)
    if elapsed >= 12.0:
        _start_game()

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventScreenTouch and event.pressed and elapsed > 1.0:
        _start_game()
    elif event is InputEventMouseButton and event.pressed and elapsed > 1.0:
        _start_game()
    elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
        _start_game()

func _start_game() -> void:
    if finished:
        return
    finished = true
    var tween := create_tween()
    tween.tween_property($Fade, "color:a", 1.0, 0.7)
    tween.tween_callback(func(): get_tree().change_scene_to_file("res://game.tscn"))
