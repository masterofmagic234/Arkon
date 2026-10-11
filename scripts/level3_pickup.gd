extends Area2D
class_name Level3Pickup
const Visual = preload("res://scripts/level3_asset_visual.gd")
@export var kind: StringName = &""
var consumed := false
@onready var _visual: Sprite2D = %Visual
func is_automatic() -> bool: return kind==&"ammo" or kind==&"medkit"
func _ready() -> void:
    collision_layer=0
    collision_mask=2
    monitoring=true
    body_entered.connect(_on_body_entered)
    _visual.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
    _visual.position=Vector2.ZERO
    _visual.scale=Vector2.ONE*0.88
    match kind:
        &"pistol": _visual.texture=Visual.frame_texture("res://assets/level3/source/Weapons/sprWeapons_strip35.png",7)
        &"shotgun": _visual.texture=Visual.frame_texture("res://assets/level3/source/Weapons/sprWeapons_strip35.png",14)
        &"bat": _visual.texture=Visual.frame_texture("res://assets/level3/source/Weapons/sprWeapons_strip35.png",1)
        &"bottle": _visual.texture=Visual.frame_texture("res://assets/level3/source/Weapons/sprMolotov_strip4.png")
        &"medkit",&"ammo": _visual.visible=false
    queue_redraw()
func _on_body_entered(body: Node) -> void:
    if body is Level3Player and is_automatic(): collect(body)
func collect(player: Level3Player) -> bool:
    if consumed or player.is_dead: return false
    if kind==&"medkit" and player.health>=player.max_health: return false
    consumed=true
    var bus := get_node_or_null("/root/SignalBus")
    if bus!=null: bus.item_collected.emit(kind,StringName(name),1,player)
    queue_free()
    return true
func _draw() -> void:
    draw_circle(Vector2(1,2),9,Color(0.01,0.02,0.03,0.4))
    draw_arc(Vector2.ZERO,12,0,TAU,24,Color(0.55,0.89,0.81,0.67),1,true)
    if kind==&"medkit":
        draw_rect(Rect2(-7,-6,14,12),Color("a3cbc0"))
        draw_rect(Rect2(-2,-4,4,8),Color("d76266"))
        draw_rect(Rect2(-4,-2,8,4),Color("d76266"))
    elif kind==&"ammo":
        draw_rect(Rect2(-7,-5,14,10),Color("937a4c"))
        for x in [-4,0,4]: draw_rect(Rect2(x-1,-4,2,8),Color("ead6a1"))
