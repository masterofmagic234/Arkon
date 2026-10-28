extends Node2D
## A native-resolution top-down vehicle; no models or texture edits at runtime.
## +X is the vehicle nose; -Y is its left/driver side and the van's sliding door.
const Visual = preload("res://scripts/level3_asset_visual.gd")
const CAR_BODY := "res://assets/level3/vehicles/player_240_body.png"
const CAR_DOOR := "res://assets/level3/vehicles/player_240_door.png"
const VAN_DOOR_FRAMES := "res://assets/level3/source/Vehicles/sprVanOpenDoor_strip13.png"
const VAN_SEPARATE_DOOR := "res://assets/level3/source/Vehicles/sprVanDoor.png"

@export var kind: String = "240":
    set(value):
        kind = value
        if is_node_ready(): _build()
var door_open_amount: float = 0.0:
    set(value):
        door_open_amount = clampf(value,0.0,1.0)
        _sync_door()
var body: Sprite2D
var door_pivot: Node2D
var door_leaf: Sprite2D
var _van_frames: Array[Texture2D] = []

var exit_socket: Vector2:
    get: return Vector2(4,-29) if kind=="van" else Vector2(-9,-34)
var inside_socket: Vector2:
    get: return Vector2(4,-19) if kind=="van" else Vector2(-4,-13)
var outside_socket: Vector2:
    get: return Vector2(4,-46) if kind=="van" else Vector2(-9,-34)
var boarding_socket: Vector2:
    get: return Vector2(-9,-34) if kind!="van" else outside_socket

func _ready() -> void:
    texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    _build()

func configure(vehicle_kind: String) -> void:
    kind = vehicle_kind

func _build() -> void:
    for child in get_children():
        remove_child(child)
        child.queue_free()
    _van_frames.clear()
    door_leaf = null
    door_pivot = null
    body = Sprite2D.new()
    body.name = "VehicleBody"
    body.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    add_child(body)
    if kind=="van":
        # The separate66-frame strip contains an old human actor. It is never
        # used: these13 clean vehicle-only frames expose a real north doorway.
        for frame in range(13):
            _van_frames.append(Visual.frame_texture(VAN_DOOR_FRAMES,frame))
        body.texture = _van_frames[0]
    else:
        body.texture = Visual.first_frame_texture(CAR_BODY)
        door_pivot = Node2D.new()
        door_pivot.name = "DriverDoorHinge"
        door_pivot.position = Vector2(13,-16)
        door_pivot.z_index = 1
        add_child(door_pivot)
        door_leaf = Sprite2D.new()
        door_leaf.name = "DriverDoor"
        door_leaf.texture = Visual.first_frame_texture(CAR_DOOR)
        door_leaf.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
        door_leaf.centered = false
        door_leaf.position = Vector2(-32,-5)
        door_pivot.add_child(door_leaf)
    _sync_door()

func _sync_door() -> void:
    if not is_instance_valid(body): return
    if kind=="van":
        if _van_frames.size()==13:
            body.texture = _van_frames[roundi(door_open_amount*12.0)]
    elif is_instance_valid(door_pivot):
        # The rear tip swings toward the upper/outside side. Hinge stays fixed
        # at the front of the actual cut-away driver doorway.
        door_pivot.rotation = door_open_amount*deg_to_rad(68.0)

func get_body_size() -> Vector2:
    return Vector2(122,52) if kind=="van" else Vector2(107,70)
