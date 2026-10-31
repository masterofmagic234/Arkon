extends Node2D
func _draw() -> void:
    draw_circle(Vector2(1,2),4,Color(0,0,0,.45))
    draw_rect(Rect2(-3,-4,6,8),Color("7b8566"))
    draw_rect(Rect2(-3,-4,6,2),Color("c6c59d"))
    draw_arc(Vector2(0,-5),2,0,TAU,8,Color("cbd2bd"),1)
