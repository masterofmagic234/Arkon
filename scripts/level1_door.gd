extends Node3D
class_name Level1Door

@export var required_key: int = 1
@export var extra_required_key: int = 0
@export var open_angle_degrees: float = -92.0
@export var open_duration: float = 0.45

var is_open := false
var _opening := false
var has_key := false
var has_extra_key := false

@onready var pivot: Node3D = $Pivot
@onready var collision: CollisionShape3D = $Pivot/Leaf/Collision
@onready var proximity: Area3D = $Proximity

func _ready() -> void:
    add_to_group("level1_door")

    if not SignalBus.item_collected.is_connected(_on_item_collected):
        SignalBus.item_collected.connect(_on_item_collected)

    if proximity != null and not proximity.body_entered.is_connected(_on_proximity_body_entered):
        proximity.body_entered.connect(_on_proximity_body_entered)

func _exit_tree() -> void:
    if SignalBus.item_collected.is_connected(_on_item_collected):
        SignalBus.item_collected.disconnect(_on_item_collected)

func _on_item_collected(
        item_kind: StringName,
        item_id: StringName,
        _amount: int,
        _collector: Node
) -> void:
    if item_kind != &"key":
        return

    var id := String(item_id)
    if id.ends_with("%02d" % required_key): has_key=true
    if extra_required_key>0 and id.ends_with("%02d" % extra_required_key): has_extra_key=true
    if has_key and (extra_required_key==0 or has_extra_key) and proximity!=null:
        for body in proximity.get_overlapping_bodies():
            if body.has_method("is_level1_player"):
                open()
                return

func _on_proximity_body_entered(body: Node3D) -> void:
    if is_open or _opening or not body.has_method("is_level1_player"):
        return

    if has_key and (extra_required_key==0 or has_extra_key):
        open()
        return

    var message := "НУЖЕН КЛЮЧ САДОВНИКА · он в домике на западной аллее."
    if extra_required_key>0: message="В РОЩУ НУЖНЫ ОБА КЛЮЧА · из обсерватории и оранжереи."
    elif required_key==0: message="ПРИВОД МОСТА СВЯЗАН С ПЕЧАТЬЮ ДУБА." if name=="ReturnGate" else "ПРОХОД ОТКРОЕТСЯ, КОГДА ЗАРАБОТАЕТ ОБСЕРВАТОРИЯ."
    SignalBus.show_message.emit(message,2.0)

func open() -> void:
    if is_open or _opening:
        return

    _opening = true
    SignalBus.emit_audio_event(&"gate_open",global_position)

    var tween := create_tween()
    tween.tween_property(
        pivot,
        "rotation:y",
        deg_to_rad(open_angle_degrees),
        open_duration
    ).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    tween.tween_callback(_finish_open)

func _finish_open() -> void:
    is_open = true
    _opening = false
    if collision:
        collision.set_deferred("disabled", true)
    SignalBus.object_interacted.emit(StringName(name), &"opened")
