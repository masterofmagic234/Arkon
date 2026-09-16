extends Control

const INTRO_DURATION := 14.0

var elapsed := 0.0
var finished := false
var fade := 0.0

func _ready() -> void:
    queue_redraw()

func _process(delta: float) -> void:
    if finished:
        return
    elapsed += delta
    if elapsed >= INTRO_DURATION:
        _start_game()
        return
    queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventScreenTouch and event.pressed:
        if elapsed > 2.0:
            _start_game()
    elif event is InputEventMouseButton and event.pressed:
        if elapsed > 2.0:
            _start_game()
    elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
        _start_game()

func _start_game() -> void:
    if finished:
        return
    finished = true
    fade = 0.0
    var tween := create_tween()
    tween.tween_property(self, "fade", 1.0, 0.8)
    tween.tween_callback(func(): get_tree().change_scene_to_file("res://game.tscn"))

func _draw() -> void:
    var w := size.x
    var h := size.y

    # Dark, deliberately simple pixel-art-like bedroom blockout.
    draw_rect(Rect2(0, 0, w, h), Color("10121c"))
    draw_rect(Rect2(0, h * 0.68, w, h * 0.32), Color("2a2024"))
    draw_rect(Rect2(0, h * 0.66, w, 5), Color("513b3e"))

    _draw_window(Vector2(w * 0.72, h * 0.12), Vector2(w * 0.22, h * 0.43))
    _draw_bed(Vector2(w * 0.10, h * 0.60), Vector2(w * 0.48, h * 0.25))
    _draw_desk(Vector2(w * 0.03, h * 0.48))
    _draw_lamp(Vector2(w * 0.16, h * 0.43))
    _draw_carolina()

    var darina_t := clamp((elapsed - 4.0) / 1.5, 0.0, 1.0)
    if darina_t > 0.0:
        _draw_darina(lerp(w + 80.0, w * 0.68, darina_t))

    _draw_dialogue()
    _draw_title()

    if fade > 0.0:
        draw_rect(Rect2(0, 0, w, h), Color(0, 0, 0, fade))

func _draw_window(pos: Vector2, window_size: Vector2) -> void:
    draw_rect(Rect2(pos, window_size), Color("342b3f"))
    draw_rect(Rect2(pos + Vector2(10, 10), window_size - Vector2(20, 20)), Color("111d3c"))
    draw_line(pos + Vector2(window_size.x * 0.5, 10), pos + Vector2(window_size.x * 0.5, window_size.y - 10), Color("6d6072"), 4)
    draw_line(pos + Vector2(10, window_size.y * 0.56), pos + Vector2(window_size.x - 10, window_size.y * 0.56), Color("6d6072"), 4)
    draw_circle(pos + Vector2(window_size.x * 0.70, window_size.y * 0.25), 22, Color("f0dfb0"))
    for p in [Vector2(35, 48), Vector2(88, 30), Vector2(145, 72), Vector2(180, 42)]:
        if p.x < window_size.x - 20 and p.y < window_size.y - 20:
            draw_rect(Rect2(pos + p, Vector2(3, 3)), Color("f5edcf"))

func _draw_bed(pos: Vector2, bed_size: Vector2) -> void:
    draw_rect(Rect2(pos + Vector2(0, 55), Vector2(bed_size.x, bed_size.y - 55)), Color("4a3040"))
    draw_rect(Rect2(pos + Vector2(0, 35), Vector2(bed_size.x, 75)), Color("a96f83"))
    draw_rect(Rect2(pos + Vector2(15, 20), Vector2(120, 75)), Color("d2a0b0"))
    draw_rect(Rect2(pos + Vector2(155, 35), Vector2(bed_size.x - 170, 60)), Color("6b536a"))
    draw_rect(Rect2(pos + Vector2(0, 108), Vector2(bed_size.x, 10)), Color("211a24"))

func _draw_desk(pos: Vector2) -> void:
    draw_rect(Rect2(pos, Vector2(210, 18)), Color("684b42"))
    draw_rect(Rect2(pos + Vector2(12, 18), Vector2(14, 115)), Color("4a3634"))
    draw_rect(Rect2(pos + Vector2(184, 18), Vector2(14, 115)), Color("4a3634"))
    draw_rect(Rect2(pos + Vector2(48, -34), Vector2(110, 30)), Color("252936"))

func _draw_lamp(pos: Vector2) -> void:
    draw_rect(Rect2(pos + Vector2(0, 0), Vector2(7, 55)), Color("bda98a"))
    draw_colored_polygon(PackedVector2Array([pos + Vector2(-28, 0), pos + Vector2(35, 0), pos + Vector2(23, -34), pos + Vector2(-16, -34)]), Color("d8a86c"))
    draw_circle(pos + Vector2(4, 7), 7, Color("ffe5a6"))

func _draw_carolina() -> void:
    var sitting := clamp((elapsed - 7.0) / 2.0, 0.0, 1.0)
    var base := Vector2(size.x * 0.31, size.y * 0.58)
    var shift := Vector2(35, -45) * sitting
    base += shift
    draw_rect(Rect2(base + Vector2(-8, 0), Vector2(120, 65)), Color("493b58"))
    draw_circle(base + Vector2(35, -4), 27, Color("f0c1b2"))
    draw_circle(base + Vector2(35, -15), 31, Color("49313b"))
    draw_rect(Rect2(base + Vector2(12, 7), Vector2(46, 42)), Color("e3b3aa"))
    draw_rect(Rect2(base + Vector2(4, 18), Vector2(60, 7)), Color("342735"))
    draw_rect(Rect2(base + Vector2(15, 54), Vector2(58, 48)), Color("72506c"))

func _draw_darina(x: float) -> void:
    var y := size.y * 0.59
    draw_circle(Vector2(x, y - 45), 23, Color("edb7a8"))
    draw_circle(Vector2(x, y - 57), 27, Color("6d3f42"))
    draw_rect(Rect2(x - 25, y - 22, 50, 70), Color("607d9b"))
    draw_rect(Rect2(x - 22, y + 48, 15, 70), Color("303846"))
    draw_rect(Rect2(x + 7, y + 48, 15, 70), Color("303846"))
    draw_rect(Rect2(x - 43, y - 12, 18, 45), Color("edb7a8"))
    draw_rect(Rect2(x + 25, y - 12, 18, 45), Color("edb7a8"))

func _draw_dialogue() -> void:
    var show_darina := elapsed >= 5.5 and elapsed < 11.5
    var show_carolina := elapsed >= 11.5
    if not show_darina and not show_carolina:
        return

    var box := Rect2(80, size.y - 155, size.x - 160, 105)
    draw_rect(box, Color(0.035, 0.035, 0.055, 0.94))
    draw_rect(box, Color("bfa0aa"), false, 2)

    var speaker := "ДАРИНА" if show_darina else "КАРОЛИНА"
    var text := "Оййй... а нам, кстати, поделку на завтра задали.........." if show_darina else "...Ладно. Где эти жёлуди?"
    draw_string(ThemeDB.fallback_font, box.position + Vector2(25, 32), speaker, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("e8b8c5"))
    draw_string(ThemeDB.fallback_font, box.position + Vector2(25, 70), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 23, Color("f2eee9"))

func _draw_title() -> void:
    draw_string(ThemeDB.fallback_font, Vector2(42, 55), "ACORN HUNTER", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color("e3a8b7"))
    if elapsed >= 12.0:
        draw_string(ThemeDB.fallback_font, Vector2(42, 88), "ОПЕРАЦИЯ «ЖЁЛУДЬ»", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("d8c6c8"))
