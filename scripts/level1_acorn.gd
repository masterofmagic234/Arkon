extends Area3D
class_name Level1Acorn

@export var item_id: StringName = &""

func _ready() -> void:
    add_to_group("level1_acorn")
    if item_id == &"":
        item_id = StringName(name)
    monitoring = true
    monitorable = false
    body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
    if not body.has_method("is_level1_player"):
        return
    monitoring = false
    SignalBus.item_collected.emit(&"acorn", item_id, 1, body)
    queue_free()
