extends Control

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
    var center := size*0.5
    var color := Color(1.0,0.92,0.74,0.85)
    draw_circle(center,1.5,color)
    for d in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
        draw_line(center+d*5.0,center+d*10.0,color,1.5,true)
