extends RefCounted
const Data = preload("res://scripts/level_data.gd")
const CLUSTERS := [[Vector2i(20,49),24,4.0],[Vector2i(23,20),56,7.5],[Vector2i(20,7),24,4.0],[Vector2i(69,20),24,5.0],[Vector2i(64,48),64,8.5]]

static func build(parent: Node3D) -> Node3D:
    var root_ := Node3D.new()
    root_.name = "ParkFireflies"
    parent.add_child(root_)
    var rng := RandomNumberGenerator.new()
    rng.seed = 15112026
    var buckets: Dictionary = {}
    for cluster in CLUSTERS:
        var center := Data.cell_center_world(cluster[0])
        for i in range(cluster[1]):
            var p := center
            for attempt in range(24):
                var angle := rng.randf()*TAU
                var radius := sqrt(rng.randf())*float(cluster[2])
                p=center+Vector3(cos(angle)*radius,rng.randf_range(0.55,2.7),sin(angle)*radius)
                var cell := Data.world_to_cell(p.x,p.z)
                if Data.is_pond(cell) or Data.CANONICAL_MAP[cell.y][cell.x]==".": break
            var key := Vector2i(floori(p.x/8.0),floori(p.z/8.0))
            if not buckets.has(key): buckets[key]=[]
            buckets[key].append([p,rng.randf_range(0.70,1.25),Color(rng.randf(),rng.randf(),rng.randf(),1.0)])
    var mesh := QuadMesh.new()
    mesh.size=Vector2(0.25,0.25)
    var material := ShaderMaterial.new()
    material.shader=preload("res://shaders/level1_firefly.gdshader")
    for key: Vector2i in buckets:
        var mm := MultiMesh.new()
        mm.transform_format=MultiMesh.TRANSFORM_3D
        mm.use_custom_data=true
        mm.mesh=mesh
        mm.instance_count=buckets[key].size()
        for i in range(mm.instance_count):
            var entry: Array = buckets[key][i]
            mm.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*float(entry[1])),entry[0]))
            mm.set_instance_custom_data(i,entry[2])
        var node := MultiMeshInstance3D.new()
        node.name="Fireflies_%d_%d"%[key.x,key.y]
        node.multimesh=mm
        node.material_override=material
        node.extra_cull_margin=0.7
        node.visibility_range_end=36.0
        node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        root_.add_child(node)
    return root_
