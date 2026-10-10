extends RefCounted

# The source GLB stores each axle as a joined left/right mesh. Split it once,
# retaining source vertices/UVs/materials; rotate around real wheel centres.
static var _geometry_cache: Dictionary = {}
var wheels: Array = []
var brake_materials: Array[StandardMaterial3D] = []
var front_materials: Array[StandardMaterial3D] = []
var wheel_phase: float = 0.0
var _last_distance: float = 0.0
var brake_strength: float = 0.0

func build(model: Node3D) -> bool:
    var inverse := model.global_transform.affine_inverse()
    var axle_parts := {"front": [], "rear": []}
    var brake_parts := {"front": [], "rear": []}
    for node in model.find_children("*", "MeshInstance3D", true, false):
        var mesh_node := node as MeshInstance3D
        var label := str(mesh_node.name)
        if label.begins_with("brake_disk_1_metal_1_brake_disk_0_003") or label.begins_with("brake_disk_1_metal_1_brake_disk_0.003"):
            axle_parts.front.append(mesh_node)
        elif label.begins_with("brake_disk_1_metal_1_brake_disk_0_005") or label.begins_with("brake_disk_1_metal_1_brake_disk_0.005"):
            axle_parts.rear.append(mesh_node)
        elif label.begins_with("brake_disk_1_metal_1_brake_disk_0_004") or label.begins_with("brake_disk_1_metal_1_brake_disk_0.004"):
            brake_parts.rear.append(mesh_node)
        elif label.begins_with("brake_disk_1_metal_1_brake_disk_0_") or label.begins_with("brake_disk_1_metal_1_brake_disk_0."):
            brake_parts.front.append(mesh_node)
        for surface in range(mesh_node.mesh.get_surface_count()):
            var material := mesh_node.get_active_material(surface) as StandardMaterial3D
            if material == null:
                continue
            if label.contains("BRAKELIGHT"):
                material.albedo_color = Color(1.0, 0.18, 0.10)
                material.emission_enabled = true
                material.emission = Color(1.0, 0.005, 0.002)
                material.emission_texture = material.albedo_texture
                material.emission_energy_multiplier = 0.3
                brake_materials.append(material)
            elif label.contains("DARO") or label.contains("FARO"):
                material.albedo_color = Color(0.96, 0.94, 0.84)
                material.albedo_texture = null
                material.emission_enabled = true
                material.emission = Color(1.0, 0.93, 0.76)
                material.emission_energy_multiplier = 2.0
                front_materials.append(material)
    for axle in ["front", "rear"]:
        var parts: Array = axle_parts[axle]
        # Both source front wheels have 25 degrees of steering baked into
        # their vertices. Remove it BEFORE rolling about the neutral axle.
        var neutral_basis := Basis(Vector3.UP, deg_to_rad(-25.0)) if axle == "front" else Basis.IDENTITY
        if parts.size() != 2:
            push_error("[240SX rig] Expected tire/rim pair for %s, got %d" % [axle, parts.size()])
            return false
        for side in [-1.0, 1.0]:
            var tire: MeshInstance3D = parts[0]
            if not str(tire.name).contains("022"):
                tire = parts[1]
            var tire_transform: Transform3D = inverse * tire.global_transform
            var centre := _wheel_centre(tire, tire_transform, side)
            var steer_pivot := Node3D.new()
            steer_pivot.name = "%s_%s_Steer" % [axle, "left" if side < 0.0 else "right"]
            model.add_child(steer_pivot)
            steer_pivot.position = centre
            var roll_pivot := Node3D.new()
            roll_pivot.name = "Roll"
            steer_pivot.add_child(roll_pivot)
            var radius := 0.0
            for part in parts + brake_parts[axle]:
                var to_model: Transform3D = inverse * part.global_transform
                for surface in range(part.mesh.get_surface_count()):
                    var cache_key := "%s:%d:%s:neutral25" % [part.mesh.resource_path, surface, str(side)]
                    if not _geometry_cache.has(cache_key):
                        _geometry_cache[cache_key] = _split_surface(part, surface, to_model, centre, side, neutral_basis)
                    var split_mesh := _geometry_cache[cache_key] as ArrayMesh
                    if split_mesh == null:
                        return false
                    var visual := MeshInstance3D.new()
                    visual.mesh = split_mesh
                    visual.material_override = part.get_active_material(surface)
                    if part in parts:
                        roll_pivot.add_child(visual)
                    else:
                        # Calipers follow steering, but do not rotate with tires.
                        steer_pivot.add_child(visual)
                    if str(part.name).contains("022"):
                        radius = maxf(split_mesh.get_aabb().size.y, split_mesh.get_aabb().size.z) * 0.5
            wheels.append({"steer": steer_pivot, "roll": roll_pivot, "front": axle == "front", "radius": radius})
        for part in parts + brake_parts[axle]:
            part.visible = false
    # The source front tire is a few millimetres larger than the rear one.
    # Seat all four contact patches on a common plane without pitching the body.
    var ground_bottom := INF
    for wheel in wheels:
        ground_bottom = minf(ground_bottom, wheel.steer.position.y - float(wheel.radius))
    for wheel in wheels:
        wheel.steer.position.y = ground_bottom + float(wheel.radius)
    return wheels.size() == 4 and brake_materials.size() > 0 and front_materials.size() == 2

func _wheel_centre(part: MeshInstance3D, transform: Transform3D, side: float) -> Vector3:
    var bounds := AABB()
    var started := false
    for surface in range(part.mesh.get_surface_count()):
        var arrays := part.mesh.surface_get_arrays(surface)
        var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
        for vertex in vertices:
            var point := transform * vertex
            if point.x * side <= 0.0:
                continue
            if not started:
                bounds = AABB(point, Vector3.ZERO)
                started = true
            else:
                bounds = bounds.expand(point)
    return bounds.get_center()

func _split_surface(part: MeshInstance3D, surface: int, transform: Transform3D, centre: Vector3, side: float, neutral_basis: Basis) -> ArrayMesh:
    var arrays := part.mesh.surface_get_arrays(surface)
    var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
    var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
    var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
    var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
    var builder := SurfaceTool.new()
    builder.begin(Mesh.PRIMITIVE_TRIANGLES)
    var normal_basis := transform.basis.inverse().transposed()
    var count := 0
    var triangle_count := indices.size() / 3 if not indices.is_empty() else vertices.size() / 3
    for triangle in range(triangle_count):
        var first: int = indices[triangle * 3] if not indices.is_empty() else triangle * 3
        if (transform * vertices[first]).x * side <= 0.0:
            continue
        for corner in range(3):
            var index: int = indices[triangle * 3 + corner] if not indices.is_empty() else triangle * 3 + corner
            if not normals.is_empty():
                builder.set_normal((neutral_basis * normal_basis * normals[index]).normalized())
            if not uvs.is_empty():
                builder.set_uv(uvs[index])
            builder.add_vertex(neutral_basis * (transform * vertices[index] - centre))
            count += 1
    if count == 0:
        push_error("[240SX rig] Empty wheel surface")
        return null
    builder.index()
    if not uvs.is_empty() and not normals.is_empty():
        builder.generate_tangents()
    return builder.commit()

func sync(race_car, model_scale: float, delta: float) -> void:
    var distance := float(race_car.distance_travelled)
    var travelled := maxf(distance - _last_distance, 0.0)
    _last_distance = distance
    for wheel in wheels:
        wheel.steer.rotation.y = -float(race_car.steering_angle) if bool(wheel.front) else 0.0
        var roll_pivot: Node3D = wheel.roll
        roll_pivot.rotation.x = fposmod(roll_pivot.rotation.x + travelled / maxf(float(wheel.radius) * model_scale, 0.01), TAU)
    if not wheels.is_empty():
        wheel_phase = float(wheels[0].roll.rotation.x)
    var target_brake := float(race_car.brake_in)
    brake_strength = lerpf(brake_strength, target_brake, 1.0 - exp(-25.0 * maxf(delta, 0.0)))
    for material in brake_materials:
        material.emission_energy_multiplier = lerpf(0.3, 2.4, brake_strength)
