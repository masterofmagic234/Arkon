extends Node3D
## CEDAR compact pneumatic carbine with an anatomical supporting left hand.
## The original opaque mesh is prepared offline; three atlas batches at runtime.
const MODEL = preload("res://assets/level1/weapons/cedar/cedar_runtime.glb")
const VIEW_LAYER := 1 << 19
const MODEL_SCALE := .78
var model: Node3D
var muzzle: Node3D
var support_palm: Node3D

func _ready() -> void:
    name = "PineConeLauncher"
    model = MODEL.instantiate()
    model.name = "CedarModel"
    model.scale = Vector3.ONE * MODEL_SCALE
    add_child(model)
    for node in model.find_children("*", "MeshInstance3D", true, false):
        node.layers = VIEW_LAYER
        node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        node.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
    muzzle = model.find_child("MuzzleSocket", true, false)
    support_palm = model.find_child("SupportPalmSocket", true, false)
    var key_light := OmniLight3D.new()
    key_light.name = "WeaponOnlyReadabilityLight"
    key_light.position = Vector3(-.18, .30, .12)
    key_light.light_color = Color("d9d4cb")
    key_light.light_energy = .80
    key_light.omni_range = 1.5
    key_light.shadow_enabled = false
    key_light.light_cull_mask = VIEW_LAYER
    add_child(key_light)
    set_meta("weapon_name", "КЕДР · ПНЕВМАТИЧЕСКИЙ ШИШКОМЁТ")
    set_meta("support_hand", "left anatomical hand; fingers around foregrip")

func muzzle_transform() -> Transform3D:
    return muzzle.global_transform if is_instance_valid(muzzle) else global_transform

func mesh_metrics() -> Dictionary:
    var result := {"meshes": 0, "surfaces": 0, "triangles": 0}
    if not is_instance_valid(model): return result
    for node in model.find_children("*", "MeshInstance3D", true, false):
        result.meshes += 1
        for surface in range(node.mesh.get_surface_count()):
            result.surfaces += 1
            var arrays: Array = node.mesh.surface_get_arrays(surface)
            result.triangles += (arrays[Mesh.ARRAY_INDEX].size() if arrays[Mesh.ARRAY_INDEX] != null and arrays[Mesh.ARRAY_INDEX].size() > 0 else arrays[Mesh.ARRAY_VERTEX].size()) / 3
    return result
