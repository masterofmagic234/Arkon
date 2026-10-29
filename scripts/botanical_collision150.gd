extends RefCounted
## Physical static surfaces from the authored solid meshes. Rendering, instance
## transforms, foliage and baked-lighting buffers are never modified here.
const CELL_SIZE:=32.0
const PLAY_BOUNDS=Rect2(-89,-98,178,176)
var records: Array[Dictionary]=[]
var bodies: Array[StaticBody3D]=[]
var excluded: Dictionary={}
var triangle_count:=0
var authored_instance_count:=0
var placement_sha256:=""
var spawn_query_volumes: Array[PackedVector3Array]=[]
const TRANSFORM_AUTHORITY="authored_CPU_put_transforms"
var _cells: Dictionary={}
var _faces: Dictionary={}

func bake(world: Node3D) -> void:
    authored_instance_count=world.collision_instances.size()
    var placements=[]
    for instance in world.collision_instances:placements.append([instance.kind,instance.material,transform_values(instance.at)])
    placement_sha256=JSON.stringify(placements).sha256_text()
    for instance in world.collision_instances:
        var at: Transform3D=instance.at;var mesh: Mesh=instance.mesh
        var kind: String=instance.kind;var material: String=instance.material
        if material=="bark" and (at*mesh.get_aabb()).position.y>world.surface_height_at(at.origin.x,at.origin.z)+1:
            _skip("overhead_tree_branches");continue
        if kind=="cylinder" and material=="iron" and absf(at.origin.z+22.3)<.05 and absf(at.origin.x)<3.1:
            _skip("decorative_open_entrance_grille");continue
        add(mesh,at,"world/"+kind+"/"+material,instance.label,material)
    for visual in world.find_children("*","GeometryInstance3D",true,false):
        if world.baked_lighting!=null and world.baked_lighting.baked_root!=null and world.baked_lighting.baked_root.is_ancestor_of(visual):
            _skip("baked_lighting_duplicate_receiver");continue
        if visual.has_meta("source_child"):_skip("baked_lighting_duplicate_receiver");continue
        if visual.get_meta("botanical_foliage",false) or visual.get_meta("foliage_shadow_proxy",false):_skip("foliage");continue
        if visual.name=="ContinuousOuterLandscape" or str(visual.get_meta("lightmap_source_id","")).begins_with("terrain:"):_skip("terrain_already_physical_or_inaccessible_apron");continue
        if visual is MultiMeshInstance3D:
            # Authored instances were consumed above. The separately generated
            # evening perimeter already owns its complete physical fence proxy.
            _skip("multimesh_from_authored_CPU_data_or_existing_perimeter")
        elif visual is MeshInstance3D and visual.mesh!=null:
            var material=visual.get_active_material(0)
            if material==world.mats.get("water") or material==world.mats.get("ground"):_skip("water_or_terrain");continue
            add(visual.mesh,world.global_transform.affine_inverse()*visual.global_transform,"world/individual",str(visual.name),"stone")
    _flush(world)

func bake_direct(root: Node3D,category: String,exclude_names: Array=[],material_name:="stone") -> void:
    for visual in root.get_children():
        if not visual is MeshInstance3D or visual.mesh==null or str(visual.name) in exclude_names or visual.get_meta("already_physical150",false):continue
        add(visual.mesh,root.global_transform.affine_inverse()*visual.global_transform,category,str(visual.name),material_name)
    _flush(root)

func _skip(reason: String) -> void:excluded[reason]=int(excluded.get(reason,0))+1

func add(mesh: Mesh,at: Transform3D,category: String,label: String,material: String) -> void:
    var bounds=at*mesh.get_aabb()
    if not PLAY_BOUNDS.intersects(Rect2(Vector2(bounds.position.x,bounds.position.z),Vector2(maxf(.001,bounds.size.x),maxf(.001,bounds.size.z)))):
        _skip("outside_physical_perimeter");return
    var source_id=mesh.get_instance_id()
    if not _faces.has(source_id):_faces[source_id]=mesh.get_faces()
    var source: PackedVector3Array=_faces[source_id]
    if source.is_empty():return
    var surface=&"wood" if material in ["wood","bark"] else (&"metal" if material=="iron" else &"stone")
    var cell=Vector2i(floori(at.origin.x/CELL_SIZE),floori(at.origin.z/CELL_SIZE))
    var key=str(cell)+":"+str(surface)
    if not _cells.has(key):_cells[key]={"points":PackedVector3Array(),"surface":surface,"cell":cell,"records":[]}
    var points: PackedVector3Array=_cells[key].points
    var start=points.size();points.resize(start+source.size())
    for i in range(source.size()):points[start+i]=at*source[i]
    _cells[key].points=points
    var sample=Vector3.ZERO;var normal=Vector3.UP
    for i in range(0,source.size(),3):
        var a=at*source[i];var b=at*source[i+1];var c=at*source[i+2];var cross=(b-a).cross(c-a)
        if cross.length_squared()>.0000000001:sample=(a+b+c)/3;normal=cross.normalized();break
    var record={"label":label,"category":category,"material":material,"bounds":bounds,"triangle_count":source.size()/3,"sample":sample,"normal":normal,"cell":cell,"policy":"authored_static_triangle_surface"}
    records.append(record);_cells[key].records.append(records.size()-1);triangle_count+=source.size()/3
    if category=="world/cliff/cliff":
        # Concave triangle shells do not report a capsule wholly inside a rock.
        # A small convex query volume supports cold-load recovery and navigation
        # clearance; actual actor/projectile movement ignores its layer64.
        var unique={};var volume=PackedVector3Array()
        for vertex in source:
            if unique.has(vertex):continue
            unique[vertex]=true;volume.append(at*vertex)
        spawn_query_volumes.append(volume)

func _flush(root: Node3D) -> void:
    var collision_root=Node3D.new();collision_root.name="AuthoredSolidCollision150";root.add_child(collision_root)
    for record in _cells.values():
        var body=StaticBody3D.new();body.name="Solid150_%d_%d_%s"%[record.cell.x,record.cell.y,str(record.surface)];body.collision_layer=1;body.set_meta("audio_surface",record.surface);body.set_meta("collision150_static",true)
        var shape=ConcavePolygonShape3D.new();shape.backface_collision=true;shape.set_faces(record.points)
        var collider=CollisionShape3D.new();collider.shape=shape;body.add_child(collider);collision_root.add_child(body);bodies.append(body)
        for index in record.records:records[index].body=body
    for points in spawn_query_volumes:
        var body=StaticBody3D.new();body.name="LoadOnlyRockVolume150";body.collision_layer=64;body.collision_mask=0;body.set_meta("collision150_policy","convex_query_volume_load_and_navigation_clearance")
        var shape=ConvexPolygonShape3D.new();shape.points=points
        var collider=CollisionShape3D.new();collider.shape=shape;body.add_child(collider);collision_root.add_child(body)
    _cells.clear();_faces.clear()

func summary() -> Dictionary:
    var categories={}
    for record in records:categories[record.category]=int(categories.get(record.category,0))+1
    return {"records":records.size(),"bodies":bodies.size(),"triangles":triangle_count,"spawn_query_volumes":spawn_query_volumes.size(),"spawn_query_layer":64,"transform_authority":TRANSFORM_AUTHORITY,"authored_instance_count":authored_instance_count,"placement_sha256":placement_sha256,"categories":categories,"excluded":excluded,"policy":"Authored static solid mesh triangles in32m material cells. Existing terrain/perimeter and trunk/bench proxies retained. Foliage, water, inaccessible apron, overhead tree branches and the decorative open entrance grille excluded. Twelve convex rock volumes on layer64 support cold-load and navigation-clearance queries; actual actor/projectile movement masks ignore them."}

static func transform_values(at: Transform3D) -> Array:
    return [at.basis.x.x,at.basis.x.y,at.basis.x.z,at.basis.y.x,at.basis.y.y,at.basis.y.z,at.basis.z.x,at.basis.z.y,at.basis.z.z,at.origin.x,at.origin.y,at.origin.z]

func rendered_transform_parity(world: Node3D) -> Dictionary:
    if DisplayServer.get_name()=="headless":return {"available":false,"reason":"DummyRenderingServer does not retain MultiMesh instance buffers"}
    var batches={}
    for node in world.get_children():
        if node is MultiMeshInstance3D:batches[str(node.get_meta("lightmap_source_id","")).trim_prefix("batch:")]=node
    var originals={}
    if world.rendering_optimizer!=null:
        for record in world.rendering_optimizer.records:originals[record.instance]=record
    var checked=0;var mismatch=[];var maximum_error:=0.0;var membership={}
    for instance in world.collision_instances:
        if not batches.has(instance.batch_key):mismatch.append(instance.label+":batch_missing");continue
        var node: MultiMeshInstance3D=batches[instance.batch_key]
        var actual: Transform3D
        if originals.has(node):
            # The renderer reorders a visible prefix and zeros its culled tail.
            # Its immutable original is the actual initial native GPU upload.
            var record=originals[node];var at: int=instance.batch_index*record.stride;var values: PackedFloat32Array=record.original
            actual=Transform3D(Basis(Vector3(values[at],values[at+4],values[at+8]),Vector3(values[at+1],values[at+5],values[at+9]),Vector3(values[at+2],values[at+6],values[at+10])),Vector3(values[at+3],values[at+7],values[at+11]))
        else:actual=node.multimesh.get_instance_transform(instance.batch_index)
        var wanted=transform_values(instance.at);var got=transform_values(actual);var error:=0.0
        for i in range(12):error=maxf(error,absf(float(wanted[i])-float(got[i])))
        maximum_error=maxf(maximum_error,error);checked+=1
        if error>.0001:mismatch.append(instance.label)
        if not membership.has(instance.batch_key):membership[instance.batch_key]={}
        var key=_transform_key(instance.at);membership[instance.batch_key][key]=int(membership[instance.batch_key].get(key,0))+1
    var visible_checked=0;var visible_mismatch=[]
    for key in membership:
        var node: MultiMeshInstance3D=batches[key];var multi=node.multimesh
        var count=multi.instance_count if multi.visible_instance_count<0 else multi.visible_instance_count
        for i in range(count):
            var transform_key=_transform_key(multi.get_instance_transform(i));visible_checked+=1
            if int(membership[key].get(transform_key,0))<=0:visible_mismatch.append(str(key)+":"+str(i))
            else:membership[key][transform_key]-=1
    return {"available":true,"checked":checked,"mismatches":mismatch,"maximum_component_error":maximum_error,"active_gpu_instances_checked":visible_checked,"active_gpu_mismatches":visible_mismatch,"placement_sha256":placement_sha256,"policy":"All CPU-authored solids equal the renderer's immutable original native upload; every frustum-repacked visible GPU instance must belong to that source multiset. No render buffers or culling state changed by this audit."}

static func _transform_key(at: Transform3D) -> String:
    var quantized=[]
    for value in transform_values(at):quantized.append(roundi(float(value)*10000))
    return str(quantized)

static func visible_prop(root: Node3D) -> StaticBody3D:
    var points=PackedVector3Array()
    for visual in root.find_children("*","MeshInstance3D",true,false):
        if visual.mesh==null:continue
        var at=root.global_transform.affine_inverse()*visual.global_transform
        for point in visual.mesh.get_faces():points.append(at*point)
    if points.is_empty():return null
    var body=StaticBody3D.new();body.name="VisiblePropCollision150";body.collision_layer=1;body.set_meta("audio_surface",&"wood")
    var shape=ConcavePolygonShape3D.new();shape.backface_collision=true;shape.set_faces(points)
    var collider=CollisionShape3D.new();collider.shape=shape;body.add_child(collider);root.add_child(body)
    root.visibility_changed.connect(func():body.set_deferred("collision_layer",1 if root.is_visible_in_tree() else 0))
    body.collision_layer=1 if root.is_visible_in_tree() else 0
    return body

static func mesh_bounds(root: Node3D) -> AABB:
    var bounds=AABB();var first=true
    for visual in root.find_children("*","MeshInstance3D",true,false):
        if visual.mesh==null:continue
        var box=root.global_transform.affine_inverse()*visual.global_transform*visual.get_aabb()
        bounds=box if first else bounds.merge(box);first=false
    return bounds

static func parked_car(root: Node3D) -> StaticBody3D:
    var bounds=mesh_bounds(root)
    var body=StaticBody3D.new();body.name="ParkedCarCollision150";body.collision_layer=1;body.set_meta("audio_surface",&"metal");body.set_meta("collision150_policy","conservative_model_bounds_proxy")
    var shape=BoxShape3D.new();shape.size=bounds.size
    var collider=CollisionShape3D.new();collider.shape=shape;collider.position=bounds.get_center();body.add_child(collider);root.add_child(body);return body
