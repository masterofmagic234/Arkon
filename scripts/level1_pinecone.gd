extends Area3D
class_name Level1PineCone

const LevelData = preload("res://scripts/level_data.gd")
@export var damage: int = 12
var triggered := false

func _ready() -> void:
    add_to_group("level1_trap")
    monitoring = true
    monitorable = false
    body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
    if triggered or not body.has_method("is_level1_player"):
        return

    triggered = true
    if body.take_damage(damage, self):
        SignalBus.emit_audio_event(
            &"damage",
            Vector3(global_position.x, global_position.y, global_position.z)
        )
        SignalBus.show_message.emit(
            LevelData.CONE_LINES.pick_random(),
            2.4
        )
