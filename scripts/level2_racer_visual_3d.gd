extends Node3D
class_name Level2RacerVisual3D

const CAR_MODEL_PATH := "res://240_sx_nfs_pro_street.glb"
const DESIRED_LENGTH := 3.85
const MODEL_AUTHORED_FORWARD_YAW := PI

var movement: RaceMovementComponent = null
var model_pivot: Node3D
var model_instance: Node3D
var model_ready := false

func _ready() -> void:
    movement = get_parent().get_node_or_null(
        "RaceMovementComponent"
    ) as RaceMovementComponent
    call_deferred("_build_model")

func _build_model() -> void:
    var packed := load(CAR_MODEL_PATH) as PackedScene
    if packed == null:
        push_error("[Level2 Visual] Failed to load %s" % CAR_MODEL_PATH)
        _build_fallback()
        return

    model_pivot = Node3D.new()
    model_pivot.name = "ModelPivot"
    add_child(model_pivot)

    model_instance = packed.instantiate() as Node3D
    if model_instance == null:
        push_error("[Level2 Visual] GLB root is not Node3D")
        _build_fallback()
        return

    model_instance.name = "240SXModel"
    model_pivot.add_child(model_instance)
    model_pivot.rotation.y = MODEL_AUTHORED_FORWARD_YAW
    _prepare_materials()
    _fit_model()

    model_ready = true

func _prepare_materials() -> void:
    if model_instance == null:
        return

    for node in model_instance.find_children(
        "*",
        "MeshInstance3D",
        true,
        false
    ):
        var mesh_node := node as MeshInstance3D
        if mesh_node == null or mesh_node.mesh == null:
            continue

        for surface in range(mesh_node.mesh.get_surface_count()):
            var source := mesh_node.get_active_material(surface)
            if source is StandardMaterial3D:
                var material := (
                    source as StandardMaterial3D
                ).duplicate() as StandardMaterial3D
                material.metallic = minf(material.metallic, 0.15)
                material.roughness = maxf(material.roughness, 0.72)
                material.cull_mode = BaseMaterial3D.CULL_BACK
                material.texture_filter = (
                    BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
                )
                mesh_node.set_surface_override_material(
                    surface,
                    material
                )

func _fit_model() -> void:
    if model_instance == null:
        return

    var meshes := model_instance.find_children(
        "*",
        "MeshInstance3D",
        true,
        false
    )
    var bounds := AABB()
    var has_bounds := false
    var inv_root := model_instance.global_transform.affine_inverse()

    for node in meshes:
        var mesh_node := node as MeshInstance3D
        if mesh_node == null or mesh_node.mesh == null:
            continue

        var aabb := mesh_node.get_aabb()
        var mesh_to_root := (
            inv_root
            * mesh_node.global_transform
        )

        for corner in [
            Vector3(aabb.position.x, aabb.position.y, aabb.position.z),
            Vector3(aabb.end.x, aabb.position.y, aabb.position.z),
            Vector3(aabb.position.x, aabb.end.y, aabb.position.z),
            Vector3(aabb.position.x, aabb.end.y, aabb.end.z),
            Vector3(aabb.end.x, aabb.end.y, aabb.position.z),
            Vector3(aabb.end.x, aabb.position.y, aabb.end.z),
            Vector3(aabb.position.x, aabb.end.y, aabb.end.z),
            Vector3(aabb.end.x, aabb.end.y, aabb.end.z)
        ]:
            var point: Vector3 = mesh_to_root * corner
            if not has_bounds:
                bounds = AABB(point, Vector3.ZERO)
                has_bounds = true
            else:
                bounds = bounds.expand(point)

    if not has_bounds:
        _build_fallback()
        return

    var longitudinal := maxf(
        bounds.size.x,
        bounds.size.z
    )
    longitudinal = maxf(longitudinal, 0.001)

    var scale_factor := DESIRED_LENGTH / longitudinal
    model_instance.scale = Vector3.ONE * scale_factor

    var scaled_center := bounds.get_center() * scale_factor
    model_instance.position = Vector3(
        -scaled_center.x,
        -scaled_center.y + 0.42,
        -scaled_center.z
    )

func _build_fallback() -> void:
    if model_pivot == null:
        model_pivot = Node3D.new()
        model_pivot.name = "ModelPivot"
        add_child(model_pivot)

    var mesh_node := MeshInstance3D.new()
    mesh_node.name = "FallbackCar"
    var box := BoxMesh.new()
    box.size = Vector3(1.55, 0.7, 3.1)
    mesh_node.mesh = box
    mesh_node.position.y = 0.42

    var material := StandardMaterial3D.new()
    material.albedo_color = (
        Color(0.82, 0.12, 0.10)
        if movement == null or bool(movement.get("is_player"))
        else Color(0.20, 0.28, 0.72)
    )
    material.roughness = 0.7
    mesh_node.material_override = material
    model_pivot.add_child(mesh_node)
    model_ready = true

func sync_from_movement() -> void:
    if movement == null:
        movement = get_parent().get_node_or_null(
            "RaceMovementComponent"
        ) as RaceMovementComponent

    # The VehicleBody3D parent is the authoritative pose. Do not add screen
    # rotation, lateral shoves, or an artificial steering yaw here.
    if model_pivot != null:
        model_pivot.rotation = Vector3(0.0, MODEL_AUTHORED_FORWARD_YAW, 0.0)


func is_model_ready() -> bool:
    return model_ready
