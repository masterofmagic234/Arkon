extends Control
## Scene-owned garden hit presentation. Only accepted health events start it.
## Camera translation is temporary: look rotation and centre-ray direction stay intact.
const HIT_SECONDS := .78
const DIRECTION_SECONDS := 1.35
const KICK_SECONDS := .20
const MAX_CAMERA_SHIFT := Vector2(.009, .013)
const EDGE_SHADER = preload("res://shaders/woodland/garden_damage_edges.gdshader")

var actor: Node3D
var director: Node
var camera: Camera3D
var health_label: Label
var edges: ColorRect
var edge_material: ShaderMaterial
var hit_remaining := 0.0
var direction_remaining := 0.0
var kick_remaining := 0.0
var hit_peak := 0.0
var hit_strength := 0.0
var source_position: Variant
var accepted_hits := 0
var last_amount := 0
var _hp := 100
var _maximum := 100
var _trail_hp := 100.0
var _trail_delay := 0.0
var _clock := 0.0
var _kick_side := 0.0
var _applied_camera_shift := Vector2.ZERO
var _bus: Node
var _was_visible := false
var _health_label_base_color := Color("eee8d8")

func bind(player: Node3D, owner_: Node, health_text: Label) -> void:
    clear()
    _disconnect_events()
    actor = player
    director = owner_
    camera = actor.get("camera") as Camera3D
    health_label = health_text
    _health_label_base_color = health_text.get_theme_color("font_color")
    _hp = actor.get_hp()
    _maximum = maxi(1, actor.get_max_hp())
    _trail_hp = _hp
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    process_mode = Node.PROCESS_MODE_ALWAYS
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    if edges == null:
        edges = ColorRect.new()
        edges.name = "SoftDamageEdges"
        edges.mouse_filter = Control.MOUSE_FILTER_IGNORE
        edges.z_index = -1
        edge_material = ShaderMaterial.new()
        edge_material.shader = EDGE_SHADER
        edges.material = edge_material
        add_child(edges)
        edges.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        edges.hide()
    _bus = get_node("/root/SignalBus")
    _bus.entity_damaged.connect(_on_damage)
    _bus.health_changed.connect(_on_health)
    PauseManager.pause_state_changed.connect(_on_pause)
    queue_redraw()

func _on_damage(entity: Node, amount: int, source: Node) -> void:
    if entity != actor or amount <= 0 or not _active(): return
    accepted_hits += 1
    last_amount = amount
    hit_peak = clampf(.62 + float(amount) / _maximum * 1.6, .70, 1.0)
    hit_remaining = HIT_SECONDS
    kick_remaining = KICK_SECONDS
    source_position = source.global_position if is_instance_valid(source) and source is Node3D else null
    direction_remaining = DIRECTION_SECONDS if source_position != null else 0.0
    _kick_side = signf(bearing().x) if source_position != null else 0.0
    _trail_delay = .28
    hit_strength = hit_peak
    queue_redraw()

func _on_health(entity: Node, current: int, maximum: int) -> void:
    if entity != actor: return
    if current >= _hp:
        _trail_hp = current
        _trail_delay = 0.0
    else:
        _trail_hp = maxf(_trail_hp, _hp)
    _hp = current
    _maximum = maxi(1, maximum)
    queue_redraw()

func _active() -> bool:
    return is_instance_valid(actor) and is_instance_valid(director) and actor.input_enabled and not PauseManager.is_paused and not actor.health.is_dead and not director.mission_failed and not director.mission_complete

func bearing() -> Vector2:
    if source_position == null or not is_instance_valid(actor): return Vector2.ZERO
    var local: Vector3 = actor.global_basis.inverse() * (source_position - actor.global_position)
    return Vector2(local.x, local.z).normalized()

func _process(delta: float) -> void:
    if not is_instance_valid(actor):
        clear()
        hide()
        return
    if PauseManager.is_paused:
        _remove_camera_shift()
        visible = false
        return
    if not _active():
        clear()
        visible = false
        return
    visible = true
    var was_animating := hit_remaining > 0 or direction_remaining > 0 or _trail_hp > _hp
    _clock += delta
    hit_remaining = maxf(0.0, hit_remaining - delta)
    direction_remaining = maxf(0.0, direction_remaining - delta)
    kick_remaining = maxf(0.0, kick_remaining - delta)
    hit_strength = hit_peak * pow(hit_remaining / HIT_SECONDS, .72)
    _trail_delay = maxf(0.0, _trail_delay - delta)
    if _trail_delay == 0:
        _trail_hp = move_toward(_trail_hp, _hp, _maximum * delta * .8)
    # Direct resource restoration is not damage and must not manufacture a hit.
    var actual_hp: int = actor.get_hp()
    if actual_hp != _hp:
        _hp = actual_hp
        _trail_hp = _hp
        queue_redraw()
    var danger := _hp > 0 and _hp <= _maximum * .30
    if edges != null:
        edges.visible = hit_remaining > 0 or danger
        if edges.visible:
            edge_material.set_shader_parameter("hit_strength", hit_strength)
            edge_material.set_shader_parameter("danger_strength", .65 + .35 * sin(_clock * 6.0) if danger else 0.0)
    _update_camera_shift()
    if health_label != null:
        var text_color := _health_label_base_color.lerp(Color("ff7061"), hit_strength)
        if health_label.get_theme_color("font_color") != text_color:
            health_label.add_theme_color_override("font_color", text_color)
    if was_animating or danger or not _was_visible:
        queue_redraw()
    _was_visible = true

func _update_camera_shift() -> void:
    _remove_camera_shift()
    if not is_instance_valid(camera) or kick_remaining <= 0: return
    var phase := 1.0 - kick_remaining / KICK_SECONDS
    var envelope := sin(phase * PI) * (1.0 - phase) * hit_peak
    _applied_camera_shift = MAX_CAMERA_SHIFT * Vector2(_kick_side, 1.0) * envelope
    camera.h_offset += _applied_camera_shift.x
    camera.v_offset += _applied_camera_shift.y

func _remove_camera_shift() -> void:
    if is_instance_valid(camera):
        camera.h_offset -= _applied_camera_shift.x
        camera.v_offset -= _applied_camera_shift.y
    _applied_camera_shift = Vector2.ZERO

func _on_pause(paused: bool) -> void:
    if paused:
        _remove_camera_shift()
        hide()
    else:
        _was_visible = false

func clear() -> void:
    _remove_camera_shift()
    hit_remaining = 0.0
    direction_remaining = 0.0
    kick_remaining = 0.0
    hit_strength = 0.0
    source_position = null
    _was_visible = false
    if edges != null: edges.hide()
    if is_instance_valid(health_label): health_label.add_theme_color_override("font_color", _health_label_base_color)
    queue_redraw()

func _draw() -> void:
    if not _active(): return
    var viewport_size := get_viewport_rect().size
    var scale_ := clampf(minf(viewport_size.x / 1280.0, viewport_size.y / 720.0), .5, 1.55)
    var bar := Rect2(Vector2(30, 189) * scale_, Vector2(142, 4) * scale_)
    draw_rect(bar.grow(1.0 * scale_), Color(.02, .035, .025, .85))
    draw_rect(bar, Color("3c4840"))
    var trail := bar
    trail.size.x *= clampf(_trail_hp / _maximum, 0.0, 1.0)
    draw_rect(trail, Color("f7bd78"))
    var fill := bar
    fill.size.x *= clampf(float(_hp) / _maximum, 0.0, 1.0)
    var fill_color := Color("dc574b") if _hp <= _maximum * .30 else Color("b0c7a1")
    draw_rect(fill, fill_color.lerp(Color("fff2df"), hit_strength * .6))
    if direction_remaining <= 0 or source_position == null: return
    var direction := bearing()
    if direction.length_squared() < .001: return
    var alpha := minf(1.0, direction_remaining / .30)
    var center := viewport_size * .5
    var radius := 98.0 * scale_
    var angle := direction.angle()
    draw_arc(center, radius, angle - .29, angle + .29, 18, Color(.08, .01, .015, alpha * .9), 9.0 * scale_, true)
    draw_arc(center, radius, angle - .27, angle + .27, 18, Color(1.0, .26, .18, alpha), 5.0 * scale_, true)
    var tangent := direction.orthogonal()
    var tip := center + direction * (radius - 10.0 * scale_)
    var base := center + direction * (radius - 2.0 * scale_)
    draw_colored_polygon(PackedVector2Array([tip, base + tangent * 4.5 * scale_, base - tangent * 4.5 * scale_]), Color(1.0, .72, .57, alpha))

func _disconnect_events() -> void:
    if is_instance_valid(_bus):
        if _bus.entity_damaged.is_connected(_on_damage): _bus.entity_damaged.disconnect(_on_damage)
        if _bus.health_changed.is_connected(_on_health): _bus.health_changed.disconnect(_on_health)
    if PauseManager.pause_state_changed.is_connected(_on_pause): PauseManager.pause_state_changed.disconnect(_on_pause)

func _exit_tree() -> void:
    _remove_camera_shift()
    _disconnect_events()
