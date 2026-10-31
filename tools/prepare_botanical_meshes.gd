@tool
extends SceneTree
## Bake full-resolution originals plus subpixel LODs with Godot's meshoptimizer.
## The exported game loads these resources; it never runs an editor importer.
func _init() -> void:
    call_deferred("run")
func bake(source: Mesh,path: String) -> void:
    var importer=ImporterMesh.new()
    importer.add_surface(Mesh.PRIMITIVE_TRIANGLES,source.surface_get_arrays(0))
    importer.generate_lods(60,60,[])
    var mesh=importer.get_mesh()
    # A dedicated shadow/depth mesh uses the exact same surface and positions;
    # Godot can fetch positions without all the PBR vertex attributes.
    var arrays=mesh.surface_get_arrays(0)
    var shadow=ArrayMesh.new();var vertices=PackedVector3Array();var indices=PackedInt32Array();var lookup={}
    var source_indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
    if source_indices.is_empty():
        for i in range(arrays[Mesh.ARRAY_VERTEX].size()):source_indices.append(i)
    for index in source_indices:
        var vertex: Vector3=arrays[Mesh.ARRAY_VERTEX][index]
        if not lookup.has(vertex):lookup[vertex]=vertices.size();vertices.append(vertex)
        indices.append(lookup[vertex])
    var shadow_arrays=[];shadow_arrays.resize(Mesh.ARRAY_MAX);shadow_arrays[Mesh.ARRAY_VERTEX]=vertices;shadow_arrays[Mesh.ARRAY_INDEX]=indices
    var lods={}
    for level in range(importer.get_surface_lod_count(0)):
        var lod=PackedInt32Array()
        for index in importer.get_surface_lod_indices(0,level):lod.append(lookup[arrays[Mesh.ARRAY_VERTEX][index]])
        lods[importer.get_surface_lod_size(0,level)]=lod
    shadow.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,shadow_arrays,[],lods);mesh.shadow_mesh=shadow
    ResourceSaver.save(mesh,path,ResourceSaver.FLAG_COMPRESS)
    print("BOTANICAL LOD: ",path.get_file()," ",importer.get_surface_lod_count(0)," levels; original preserved")
func run() -> void:
    DirAccess.make_dir_recursive_absolute("res://assets/level1/botanical/meshes")
    for kind in ["petal","specimen"]:
        var sphere=SphereMesh.new();sphere.radius=.18;sphere.height=.65 if kind=="petal" else .4
        bake(sphere,"res://assets/level1/botanical/meshes/"+kind+".res")
    var world=load("res://scripts/botanical_world.gd").new();world.set_meta("reference_rendering",true);root.add_child(world);world._materials()
    world._tapered_branch(Vector3.ZERO,Vector3.UP,.1,.01)
    for key in ["box","cylinder","rock","branch"]:bake(world.meshes[key],"res://assets/level1/botanical/meshes/"+key+".res")
    world._terrain()
    var number=0
    for child in world.get_children():
        if not child is MeshInstance3D:continue
        bake(child.mesh,"res://assets/level1/botanical/meshes/terrain_%d.res"%number);number+=1
    world.free()
    quit()
