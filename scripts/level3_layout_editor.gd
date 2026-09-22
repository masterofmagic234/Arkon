@tool
extends Node2D

const CHUNK_SIZE := Vector2(512, 384)

func _ready() -> void:
    queue_redraw()

func _process(_delta: float) -> void:
    if Engine.is_editor_hint():
        queue_redraw()

func _draw() -> void:
    if not Engine.is_editor_hint():
        return

    draw_rect(
        Rect2(Vector2.ZERO, CHUNK_SIZE),
        Color(1.0, 1.0, 1.0, 0.10),
        false,
        1.0
    )
