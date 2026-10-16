extends RefCounted
# Conservative blockers sit strictly inside visible masonry. Gates and trees
# are excluded, so opening a gate never exposes a hidden static blocker.
static func build(parent: Node3D, walls: Array[AABB]) -> void:
    var vertices := PackedVector3Array()
    var indices := PackedInt32Array()
    for wall in walls:
        var start := vertices.size()
        for x in [wall.position.x,wall.end.x]:
            for y in [wall.position.y,wall.end.y]:
                for z in [wall.position.z,wall.end.z]: vertices.append(Vector3(x,y,z))
        for index in [0,1,3,0,3,2,4,6,7,4,7,5,0,4,5,0,5,1,2,3,7,2,7,6,0,2,6,0,6,4,1,5,7,1,7,3]: indices.append(start+index)
    var occluder := ArrayOccluder3D.new()
    occluder.set_arrays(vertices,indices)
    var node := OccluderInstance3D.new()
    node.name="OpaqueParkWalls";node.occluder=occluder
    parent.add_child(node)
    parent.get_viewport().use_occlusion_culling=true
