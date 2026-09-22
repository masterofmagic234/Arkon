extends GPUParticles2D
class_name Level3BloodParticles

const AssetVisual = preload("res://scripts/level3_asset_visual.gd")

const DROP_TEXTURE_PATH := "res://assets/level3/source/Gore/sprBloodDrop_strip6.png"
const DROP_TEXTURE_2_PATH := "res://assets/level3/source/Gore/sprBloodDrop2_strip10.png"
const POOL_TEXTURE_PATH := "res://assets/level3/source/Gore/sprBloodPool_strip66.png"
const SPLAT_TEXTURE_PATH := "res://assets/level3/source/Gore/sprBloodSplat_strip8.png"

var impact_direction: Vector2 = Vector2.RIGHT
var intensity: float = 1.0
var leave_puddle: bool = true

func setup(direction: Vector2, strength: float = 1.0, keep_puddle: bool = true) -> void:
    impact_direction = direction.normalized() if direction.length_squared() > 0.001 else Vector2.RIGHT
    intensity = clampf(strength, 0.45, 1.6)
    leave_puddle = keep_puddle

func _ready() -> void:
    texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    z_index = 6
    one_shot = true
    explosiveness = 1.0
    lifetime = 0.62
    amount = 28 if intensity < 1.0 else 46
    process_material = _build_material()

    var drop_texture := AssetVisual.first_frame_texture(
        DROP_TEXTURE_PATH if randf() > 0.30 else DROP_TEXTURE_2_PATH
    )
    if drop_texture != null:
        texture = drop_texture

    modulate = Color(0.78, 0.025, 0.018, 1.0)
    emitting = true

    await get_tree().create_timer(0.26).timeout
    if leave_puddle:
        _spawn_permanent_puddle()

    await get_tree().create_timer(maxf(0.05, lifetime - 0.26)).timeout
    queue_free()

func _build_material() -> ParticleProcessMaterial:
    var blood_material := ParticleProcessMaterial.new()
    blood_material.direction = Vector3(impact_direction.x, impact_direction.y, 0.0)
    blood_material.spread = 48.0 if intensity >= 1.0 else 72.0
    blood_material.initial_velocity_min = 125.0 * intensity
    blood_material.initial_velocity_max = 290.0 * intensity
    blood_material.gravity = Vector3(0.0, 420.0, 0.0)
    blood_material.damping_min = 260.0
    blood_material.damping_max = 440.0
    blood_material.scale_min = 0.65
    blood_material.scale_max = 1.30
    blood_material.angular_velocity_min = -240.0
    blood_material.angular_velocity_max = 240.0
    return blood_material

func _spawn_permanent_puddle() -> void:
    var puddle := Sprite2D.new()
    puddle.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

    if randf() < 0.62:
        var pool_frame := randi_range(42, 65)
        puddle.texture = _strip_frame_texture(POOL_TEXTURE_PATH, pool_frame)
    else:
        var splat_frame := randi_range(4, 7)
        puddle.texture = _strip_frame_texture(SPLAT_TEXTURE_PATH, splat_frame)

    if puddle.texture == null:
        return

    puddle.global_position = global_position + Vector2(
        randf_range(-7.0, 7.0),
        randf_range(-7.0, 7.0)
    )
    var random_scale := randf_range(0.72, 1.18) * intensity
    puddle.scale = Vector2(random_scale, random_scale)
    puddle.rotation = randf_range(0.0, TAU)
    puddle.modulate = Color(
        randf_range(0.44, 0.72),
        randf_range(0.012, 0.045),
        randf_range(0.008, 0.025),
        randf_range(0.80, 0.96)
    )
    puddle.z_index = -4

    var stain_parent := get_parent()
    if stain_parent != null:
        stain_parent.add_child(puddle)

    _trim_old_stains(stain_parent)

func _trim_old_stains(stain_parent: Node) -> void:
    if stain_parent == null:
        return

    var stains: Array[Node] = []
    for child in stain_parent.get_children():
        if child is Sprite2D and child.z_index == -4:
            stains.append(child)

    const MAX_STAINS := 360
    if stains.size() <= MAX_STAINS:
        return

    var remove_count := stains.size() - MAX_STAINS
    for index in range(remove_count):
        if is_instance_valid(stains[index]):
            stains[index].queue_free()

func _strip_frame_texture(path: String, frame_index: int) -> Texture2D:
    var source_texture := load(path) as Texture2D
    if source_texture == null:
        return null

    var frames := AssetVisual.strip_frame_count(path)
    var index := clampi(frame_index, 0, frames - 1)
    var frame_width := float(source_texture.get_width()) / float(frames)

    var atlas := AtlasTexture.new()
    atlas.atlas = source_texture
    atlas.region = Rect2(
        float(index) * frame_width,
        0.0,
        frame_width,
        float(texture.get_height())
    )
    return atlas
