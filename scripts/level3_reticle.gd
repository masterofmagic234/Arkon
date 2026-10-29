extends Node2D
var world: Level3Store
var _target := Vector2.ZERO
var _hit := false
func _ready() -> void:
    z_index=60
    var mat := CanvasItemMaterial.new()
    mat.light_mode=CanvasItemMaterial.LIGHT_MODE_UNSHADED
    material=mat
func _physics_process(_delta: float) -> void:
    visible=world.player.combat_enabled and not world._player_dead and not world._level_complete_started
    if not visible: return
    var origin := world.safe_muzzle(world.player.global_position,world.player.get_aim_direction(),17)
    var distance_ := 150.0 if world.hud.mobile_active else clampf(origin.distance_to(world.get_global_mouse_position()),32.0,340.0)
    var end := origin+world.player.get_aim_direction()*distance_
    var query := PhysicsRayQueryParameters2D.create(origin,end,1|2)
    query.exclude=[world.player.get_rid()]
    var collision := get_world_2d().direct_space_state.intersect_ray(query)
    _hit=not collision.is_empty() and collision.get("collider") is Level3Enemy
    _target=collision.get("position",end)
    global_position=_target
    queue_redraw()
func _draw() -> void:
    var color := Color("f5c88a") if _hit else Color(0.78,0.88,0.86,0.75)
    if world.feedback!=null and world.feedback.hit_strength>0: color=Color("fff0b0")
    for direction in [Vector2.RIGHT,Vector2.LEFT,Vector2.DOWN,Vector2.UP]: draw_line(direction*4,direction*8,color,1.2,true)
    draw_circle(Vector2.ZERO,1.2,color)
