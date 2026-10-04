extends SceneTree

const MODEL_PATH := "res://compact+car+3d+model.glb"

func _init() -> void:
    var packed := load(MODEL_PATH) as PackedScene
    if packed == null:
        push_error("OKA MODEL LOAD FAILED")
        quit(1)
        return
    var root := packed.instantiate() as Node3D
    if root == null:
        push_error("OKA MODEL ROOT IS NOT NODE3D")
        quit(1)
        return
    get_root().add_child(root)
    await process_frame
    print("=== OKA MODEL INSPECTION ===")
    _dump(root, 0)
    quit(0)

func _dump(node: Node, depth: int) -> void:
    var indent := "  ".repeat(depth)
    var extra := ""
    if node is MeshInstance3D:
        var mesh_node := node as MeshInstance3D
        var aabb := mesh_node.get_aabb()
        var mat_info := []
        if mesh_node.mesh != null:
            for i in range(mesh_node.mesh.get_surface_count()):
                var mat := mesh_node.get_active_material(i)
                var mat_data := {
                    "surface": i,
                    "material": mat.get_class() if mat != null else "NULL",
                    "material_name": mat.resource_name if mat != null else "",
                }
                if mat is BaseMaterial3D:
                    var bm := mat as BaseMaterial3D
                    mat_data["transparency"] = bm.transparency
                    mat_data["cull_mode"] = bm.cull_mode
                    mat_data["albedo_color"] = bm.albedo_color
                    mat_data["albedo_texture"] = str(bm.albedo_texture)
                    if bm.albedo_texture != null:
                        mat_data["texture_size"] = bm.albedo_texture.get_size()
                mat_info.append(mat_data)
        extra = " MESH aabb=%s size=%s surfaces=%s" % [aabb, aabb.size, mat_info]
    elif node is Node3D:
        extra = " transform=%s scale=%s" % [node.transform, node.scale]
    print("%s%s [%s]%s" % [indent, node.name, node.get_class(), extra])
    for child in node.get_children():
        _dump(child, depth + 1)
