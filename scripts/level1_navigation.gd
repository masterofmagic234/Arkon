extends Node3D
class_name Level1Navigation

const LevelData = preload("res://scripts/level_data.gd")
const Props = preload("res://scripts/level1_park_props.gd")
var region: NavigationRegion3D
var revision := 0
var navigation_ready := false
var pending_mesh: NavigationMesh
var publishing_iteration := -1
var publishing_region_iteration := -1

func setup() -> void:
    if region == null:
        var map := get_world_3d().navigation_map
        NavigationServer3D.map_set_cell_size(map,0.15)
        NavigationServer3D.map_set_cell_height(map,0.10)
        region = NavigationRegion3D.new()
        region.name = "Level1NavigationRegion"
        add_child(region)
        SignalBus.object_interacted.connect(_on_gate_changed)
    rebuild()

func _on_gate_changed(_id: StringName, state: StringName) -> void:
    if state == &"opened":
        call_deferred("rebuild")

func rebuild() -> void:
    revision += 1
    var mesh := NavigationMesh.new()
    mesh.cell_size = 0.15
    mesh.cell_height = 0.10
    mesh.agent_radius = mesh.cell_size*3.0
    mesh.agent_height = 1.8
    mesh.agent_max_climb = 0.0
    mesh.edge_max_error = 0.5
    mesh.region_min_size = 0.0
    var source := NavigationMeshSourceGeometryData3D.new()
    var half := Vector2(LevelData.MAP_WIDTH*LevelData.CELL_SIZE,LevelData.MAP_HEIGHT*LevelData.CELL_SIZE)*0.5
    source.add_faces(PackedVector3Array([
        Vector3(half.x,0,half.y),Vector3(-half.x,0,half.y),Vector3(half.x,0,-half.y),
        Vector3(-half.x,0,half.y),Vector3(-half.x,0,-half.y),Vector3(half.x,0,-half.y)]),Transform3D.IDENTITY)
    # Recast erodes the actual walls for capsule clearance at concave corners.
    # Contiguous runs retain the authored grid with fewer source outlines.
    for z in range(LevelData.MAP_HEIGHT):
        var x := 0
        while x<LevelData.MAP_WIDTH:
            if LevelData.CANONICAL_MAP[z][x]!="#":
                x += 1
                continue
            var first := x
            while x<LevelData.MAP_WIDTH and LevelData.CANONICAL_MAP[z][x]=="#": x += 1
            var left := LevelData.cell_bounds_world(Vector2i(first,z))
            _add_rectangle(source,Rect2(left.position,Vector2((x-first)*LevelData.CELL_SIZE,LevelData.CELL_SIZE)))
    for gate in get_tree().get_nodes_in_group("level1_door"):
        if not gate.is_open:
            _add_rectangle(source,LevelData.cell_bounds_world(LevelData.world_to_cell(gate.global_position.x,gate.global_position.z)))
    for prop in Props.footprints():
        source.add_projected_obstruction(Props.outline(prop),-0.1,6.0,false)
    pending_mesh=mesh
    NavigationServer3D.bake_from_source_geometry_data_async(mesh,source)

func _process(_delta: float) -> void:
    # No callback bound to a scene that may be restarted while baking.
    if pending_mesh and not NavigationServer3D.is_baking_navigation_mesh(pending_mesh):
        _publish(pending_mesh,revision)
        pending_mesh=null
    if publishing_iteration>=0:
        var map := get_world_3d().navigation_map
        var region_updated := NavigationServer3D.region_get_iteration_id(region.get_rid())>publishing_region_iteration
        var map_updated := NavigationServer3D.map_get_iteration_id(map)>publishing_iteration
        if not region_updated or not map_updated: return
        if region.navigation_mesh.vertices.is_empty(): return
        # An empty-map synchronization can finish while the actual region is
        # still being committed on another thread. Check the query surface too.
        var query_ready := NavigationServer3D.map_get_closest_point_owner(map,region.navigation_mesh.vertices[0])==region.get_rid()
        if query_ready:
            navigation_ready=true
            publishing_iteration=-1

func _add_rectangle(source: NavigationMeshSourceGeometryData3D, rect: Rect2) -> void:
    source.add_projected_obstruction(PackedVector3Array([
        Vector3(rect.position.x,0,rect.position.y),Vector3(rect.end.x,0,rect.position.y),
        Vector3(rect.end.x,0,rect.end.y),Vector3(rect.position.x,0,rect.end.y)]),-0.1,6.0,false)

func _publish(mesh: NavigationMesh, generation: int) -> void:
    if generation!=revision or not is_inside_tree(): return
    # This park is a flat ground plane. Recast's voxel-height offset should
    # not reintroduce the old below/above-waist waypoint reach bug.
    var vertices := mesh.vertices
    for i in range(vertices.size()): vertices[i].y=0.0
    mesh.vertices=vertices
    publishing_iteration=NavigationServer3D.map_get_iteration_id(get_world_3d().navigation_map)
    publishing_region_iteration=NavigationServer3D.region_get_iteration_id(region.get_rid())
    region.navigation_mesh = mesh
    navigation_ready=false
