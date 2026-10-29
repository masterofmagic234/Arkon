@tool
extends SceneTree
## Offline-only LOD generation for the five corrected terrain tiles.
func _init() -> void:call_deferred("run")
func run() -> void:
    var world=load("res://scripts/botanical_world.gd").new()
    world.set_meta("reference_rendering",true);root.add_child(world)
    world._materials();world._terrain()
    var saved=[]
    for node in world.get_children():
        if not node is MeshInstance3D or not node.get_meta("authored_geometry151",false):continue
        var number=int(str(node.get_meta("lightmap_source_id")).trim_prefix("terrain:"))
        var importer:=ImporterMesh.new()
        importer.add_surface(Mesh.PRIMITIVE_TRIANGLES,node.mesh.surface_get_arrays(0))
        importer.generate_lods(60,60,[])
        var mesh=importer.get_mesh()
        mesh.set_meta("world151_terrain",true)
        mesh.set_meta("source_tile",number)
        mesh.set_meta("lod_count",importer.get_surface_lod_count(0))
        var path="res://assets/level1/botanical/meshes/terrain151_%d.res"%number
        assert(ResourceSaver.save(mesh,path,ResourceSaver.FLAG_COMPRESS)==OK)
        saved.append({"tile":number,"lods":importer.get_surface_lod_count(0),"path":path})
    assert(saved.size()==5)
    world.free();print("WORLD151 TERRAIN LODS: ",JSON.stringify(saved));quit()
