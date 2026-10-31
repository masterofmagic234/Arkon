extends Control
const Data = preload("res://scripts/level3_store_data.gd")
var world: Node2D
var explored: Dictionary = {}
var _timer := 0.0
var _background: StyleBoxFlat
var refresh_interval := 0.1
var _static_layer: Control
var background_draws := 0
func _ready() -> void:
    mouse_filter = MOUSE_FILTER_IGNORE
    _background = _style()
    _static_layer = Control.new()
    _static_layer.name = "MapBackground"
    _static_layer.mouse_filter = MOUSE_FILTER_IGNORE
    _static_layer.show_behind_parent = true
    _static_layer.draw.connect(_draw_background)
    add_child(_static_layer)
    resized.connect(_invalidate_background)
    _invalidate_background()
func apply_graphics_settings(settings: Dictionary) -> void:
    refresh_interval = clampf(float(settings.get("minimap_interval",0.1)),0.1,0.5)
    _timer = minf(_timer,refresh_interval)
func _invalidate_background() -> void:
    if is_instance_valid(_static_layer): _static_layer.queue_redraw()
    queue_redraw()
func _process(delta: float) -> void:
    if world==null or not is_instance_valid(world.player): return
    if get_tree().paused: return
    _timer-=delta
    if _timer>0: return
    _timer=refresh_interval
    var room := Data.room_at(world.player.global_position/1.5)
    if not explored.has(room["id"]):
        explored[room["id"]]=true
        _invalidate_background()
    queue_redraw()
func _point(local: Vector2) -> Vector2: return Vector2(8,17)+local/(Vector2(Data.map_size())*16)*(size-Vector2(16,25))
func _draw_background() -> void:
    if world==null: return
    background_draws += 1
    _static_layer.draw_style_box(_background,Rect2(Vector2.ZERO,size))
    var font := ThemeDB.fallback_font
    _static_layer.draw_string(font,Vector2(10,12),"ACORN DINER",HORIZONTAL_ALIGNMENT_LEFT,-1,9,Color("879ba7"))
    var cell_size := (size-Vector2(16,25))/Vector2(Data.map_size())
    for room in Data.get_room_floor_regions():
        var rect_: Rect2 = room["rect"]
        var col := Color("4f6067") if explored.has(room["id"]) else Color("25343d")
        _static_layer.draw_rect(Rect2(_point(rect_.position*16),rect_.size*cell_size),col)
    for y in range(Data.map_size().y):
        for x in range(Data.map_size().x):
            var tile := Data.tile_at(Vector2i(x,y))
            if tile=="#": _static_layer.draw_rect(Rect2(_point(Vector2(x,y)*16),cell_size),Color("83928d"))
func _draw() -> void:
    if world==null or not is_instance_valid(world.player): return
    for door in world._doors:
        var p := _point(door.global_position/1.5)
        draw_circle(p,1.4,Color("aad0c6") if door.is_open else Color("b98862"))
    if world._enemies_alive==0:
        var goal: Vector2 = Data.cell_to_world(Data.EXIT_CELL if world.order_collected else Data.ORDER_CELL)
        draw_circle(_point(goal),3,Color("f9c484"))
    for enemy in world._enemies:
        if enemy._sees_target and enemy.global_position.distance_to(world.player.global_position)<340: draw_circle(_point(enemy.global_position/1.5),2.1,Color("ed7e7e"))
    var position_ := _point(world.player.global_position/1.5)
    var forward: Vector2 = world.player.get_aim_direction()
    draw_colored_polygon(PackedVector2Array([position_+forward*5,position_+forward.rotated(2.5)*4,position_+forward.rotated(-2.5)*4]),Color("d0f9df"))
func _style() -> StyleBoxFlat:
    var box := StyleBoxFlat.new()
    box.bg_color=Color(0.028,0.055,0.075,0.88)
    box.border_color=Color(0.31,0.46,0.51,0.48)
    box.set_border_width_all(1)
    box.set_corner_radius_all(5)
    return box
