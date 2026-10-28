extends Node2D
## The same oak/steel/brass pneumatic launcher as the garden, carried on a
## leather sling. Kept separate from the active pistol/bat animation frames.
func _ready() -> void:
    name = "PineConeLauncherSling"
    z_index = 2
    texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    queue_redraw()
func _draw() -> void:
    var leather := Color("4e3b31")
    var wood := Color("8e6846")
    var steel := Color("3c4953")
    var brass := Color("b8985a")
    draw_line(Vector2(-8,-7),Vector2(8,7),Color("201c20"),4)
    draw_line(Vector2(-8,-7),Vector2(8,7),leather,2)
    draw_set_transform(Vector2(-4,-6),-.65)
    draw_rect(Rect2(-12,-3,30,7),Color("172029"))
    draw_rect(Rect2(-11,-2,14,5),wood)
    draw_rect(Rect2(-14,0,5,6),wood)
    draw_rect(Rect2(3,-1,14,3),steel)
    draw_rect(Rect2(15,-2,2,5),brass)
    draw_rect(Rect2(3,-2,2,5),brass)
    draw_rect(Rect2(-4,2,3,5),wood.darkened(.18))
    for x in [-7,-2,3]:
        draw_rect(Rect2(x,-6,3,5),Color("634930"))
        draw_rect(Rect2(x,-5,3,1),brass)
        draw_rect(Rect2(x+1,-3,2,1),brass.darkened(.15))
    draw_set_transform(Vector2.ZERO)
