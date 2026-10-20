extends Area3D
class_name Level1Acorn

@export var item_id: StringName = &""
var collected := false

func _ready() -> void:
    add_to_group("level1_acorn")
    if item_id == &"":
        item_id = StringName(name)
    monitoring = true
    monitorable = false
    body_entered.connect(_on_body_entered)

func collect_if_overlapping() -> void:
    # Releasing a seal while standing inside its Area3D does not emit another
    # body_entered event. Use the physics server's real overlap list instead.
    for body in get_overlapping_bodies():
        _on_body_entered(body)
        if collected: return

func _on_body_entered(body: Node3D) -> void:
    if collected or has_meta("carried") or has_meta("heist_locked") or not body.has_method("is_level1_player"):
        return
    collected = true
    set_deferred("monitoring", false)
    SignalBus.item_collected.emit(&"acorn", item_id, 1, body)
    queue_free()
