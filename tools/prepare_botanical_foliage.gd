@tool
extends SceneTree
func _init() -> void:
    var args=OS.get_cmdline_user_args()
    assert(args.size()==1,"Pass generated foliage JSON")
    var data=JSON.parse_string(FileAccess.get_file_as_string(args[0]))
    for tile in range(6):
        var mesh=ArrayMesh.new()
        for kind in ["core","edge"]:
            var vertices:=PackedVector3Array();var normals:=PackedVector3Array();var uvs:=PackedVector2Array();var colors:=PackedColorArray();var lods={};var base:=PackedInt32Array()
            for level in range(data.tiles[tile].size()):
                var entry=data.tiles[tile][level];var part=entry[kind];var offset=vertices.size()
                for p in part.xy:
                    vertices.append(Vector3((p[0]-.01)/.98-.5,.5-(p[1]-.01)/.98,0));normals.append(Vector3.FORWARD);colors.append(Color.WHITE)
                    uvs.append((Vector2(tile%3,tile/3)+Vector2(p[0],p[1]))/Vector2(3,2))
                var indices:=PackedInt32Array()
                for i in range(0,part.indices.size(),3):
                    var a=int(part.indices[i])+offset;var b=int(part.indices[i+1])+offset;var c=int(part.indices[i+2])+offset
                    indices.append_array(PackedInt32Array([a,b,c,a,c,b]))
                if level==0:base=indices
                else:lods[.5/float(data.tiles[tile][level-1].resolution)]=indices if not indices.is_empty() else PackedInt32Array([0,0,0])
            if base.is_empty():push_error("empty foliage surface");quit(1);return
            var arrays=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=normals;arrays[Mesh.ARRAY_TEX_UV]=uvs;arrays[Mesh.ARRAY_COLOR]=colors;arrays[Mesh.ARRAY_INDEX]=base
            mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],lods)
        mesh.set_meta("foliage_geometry",true)
        mesh.set_meta("coverage",data.tiles[tile].map(func(l):return {"resolution":l.resolution,"core_area":l.core.area,"edge_area":l.edge.area}))
        var path="res://assets/level1/botanical/meshes/foliage_%d.res"%tile
        assert(ResourceSaver.save(mesh,path,ResourceSaver.FLAG_COMPRESS)==OK)
        print("FOLIAGE MESH ",tile," vertices ",mesh.surface_get_array_len(0)+mesh.surface_get_array_len(1))
    quit()
