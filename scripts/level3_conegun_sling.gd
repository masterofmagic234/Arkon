extends Node2D
## Compact modern CEDAR carbine on a charcoal textile sling. The painted
## overhead asset shares the heroine's cone-pistol/scattergun material family.
func _ready() -> void:
    name = "PineConeLauncherSling"
    z_index = 4
    texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    var carbine := Sprite2D.new()
    carbine.name = "CarriedCedarCarbine"
    carbine.texture = preload("res://assets/level3/carolina147/cone_carbine.png")
    carbine.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    carbine.position = Vector2(-5,5)
    carbine.rotation = -.66
    add_child(carbine)
    queue_redraw()
func _draw() -> void:
    draw_line(Vector2(-8,-6),Vector2(5,7),Color("14191c"),2)
    draw_line(Vector2(-8,-6),Vector2(5,7),Color("3e4843"),1)
    draw_rect(Rect2(-4,-1,2,2),Color("b4a27b"))
