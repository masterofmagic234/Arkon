extends RefCounted
# Clip scenery BEFORE submission. Shader discards over a full projected road
# still run full-screen fragment work on tile GPUs. No shared mutable 2D mesh,
# no mesh readback, extra viewport, camera, texture pass or resolution change.
const DEPTH_SHADER=preload("res://shaders/race_scenery_depth.gdshader")
const PRIORITY := 100
var root: Node3D
var entries: Array[Dictionary]=[]
var materials: Array[ShaderMaterial]=[]
var _size := Vector2i.ZERO
var _transform := Transform2D.IDENTITY
var bounds := Rect2()
var minimum_depth := 0.0
var source_triangles := 0
var submitted_triangles := 0
var build_usec := 0
var warming := false

func setup(overlay,host) -> void:
    root=Node3D.new();root.name="AirframeSceneryDepth";root.visible=false
    overlay.world_root.add_child(root)
    for ground in [true,false]:
        var material:=ShaderMaterial.new();material.shader=DEPTH_SHADER
        material.render_priority=PRIORITY
        material.set_shader_parameter("ground_mesh",ground)
        if not ground: material.set_shader_parameter("coverage_texture",host.scenery.atlas)
        materials.append(material)
        var mesh:=MeshInstance3D.new();mesh.mesh=ArrayMesh.new()
        mesh.material_override=material
        mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        mesh.custom_aabb=AABB(Vector3(-100000,-100000,-100000),Vector3(200000,200000,200000))
        root.add_child(mesh)
        entries.append({"mesh":mesh,"v":PackedVector3Array(),"uv":PackedVector2Array(),"c":PackedColorArray(),"ids":PackedInt32Array()})

func set_enabled(active: bool) -> void:
    if root!=null: root.visible=active or warming

func sync(overlay,host,active: bool,airframe: Node3D) -> void:
    if root==null: setup(overlay,host)
    set_enabled(active)
    if not active: return
    var size_: Vector2i=overlay.viewport.size
    var transform: Transform2D=overlay.get_transform().affine_inverse()
    if size_!=_size or transform!=_transform:
        _size=size_;_transform=transform
        for material in materials: material.set_shader_parameter("logical_size",Vector2(size_))
    bounds=_airframe_bounds(overlay.camera,airframe,Vector2(size_))
    var farthest: float=-overlay.camera.to_local(airframe.global_position).z+8.0
    minimum_depth=1.0/maxf(farthest+.1,.1)

func prewarm(overlay,host) -> void:
    if root==null: setup(overlay,host)
    warming=true;root.visible=true
    # A real draw with the production vertex format/material, clipped wholly
    # outside the viewport. Constructing a hidden material does not warm its
    # graphics pipeline on drivers that compile lazily on first submission.
    for i in range(entries.size()):
        var arrays:=[];arrays.resize(Mesh.ARRAY_MAX)
        arrays[Mesh.ARRAY_VERTEX]=PackedVector3Array([Vector3(-8,-8,.01),Vector3(-7,-8,.01),Vector3(-8,-7,.01)])
        arrays[Mesh.ARRAY_TEX_UV]=PackedVector2Array([Vector2.ZERO,Vector2.ZERO,Vector2.ZERO])
        arrays[Mesh.ARRAY_COLOR]=PackedColorArray([Color.WHITE,Color.WHITE,Color.WHITE])
        arrays[Mesh.ARRAY_INDEX]=PackedInt32Array([0,1,2])
        entries[i].mesh.mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
        entries[i].mesh.show()

func finish_prewarm() -> void:
    warming=false
    if is_instance_valid(root):root.hide()

func update_sources(host) -> void:
    if root==null or not root.visible or warming: return
    var start:=Time.get_ticks_usec()
    source_triangles=0;submitted_triangles=0
    for entry in entries:
        entry.v.clear();entry.uv.clear();entry.c.clear();entry.ids.clear()
    if bounds.has_area():
        var road=host.road_mesh
        _append(entries[0],road._road_vertices,road._road_uv,PackedColorArray(),road._road_indices,true)
        _append(entries[0],road._road_vertices,road._road_uv,PackedColorArray(),road._far_road_indices,true)
        _append(entries[0],road._verge_vertices,road._verge_uv,PackedColorArray(),road._verge_indices,true)
        _append(entries[0],road._verge_vertices,road._verge_uv,PackedColorArray(),road._far_verge_indices,true)
        var underpass=host.scenery.underpass.batch
        _append(entries[0],underpass.vertices,underpass.uv,underpass.colors,underpass.indices,true)
        for batch in [host.scenery.opaque,host.scenery.distant_opaque,host.scenery.boards,host.scenery.distant_boards]:
            _append(entries[1],batch.vertices,batch.uv,batch.colors,batch.indices,false)
    for entry in entries:
        var mesh: ArrayMesh=entry.mesh.mesh
        mesh.clear_surfaces();entry.mesh.visible=not entry.ids.is_empty()
        if entry.ids.is_empty(): continue
        var arrays:=[];arrays.resize(Mesh.ARRAY_MAX)
        arrays[Mesh.ARRAY_VERTEX]=entry.v;arrays[Mesh.ARRAY_TEX_UV]=entry.uv
        arrays[Mesh.ARRAY_COLOR]=entry.c;arrays[Mesh.ARRAY_INDEX]=entry.ids
        mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
        submitted_triangles+=entry.ids.size()/3
    build_usec=Time.get_ticks_usec()-start

func _append(out: Dictionary,vertices: PackedVector3Array,uv: PackedVector2Array,colors: PackedColorArray,indices: PackedInt32Array,ground: bool) -> void:
    source_triangles+=indices.size()/3
    for i in range(0,indices.size(),3):
        var a:=vertices[indices[i]];var b:=vertices[indices[i+1]];var c:=vertices[indices[i+2]]
        var qa:=uv[indices[i]].y if ground else a.z
        var qb:=uv[indices[i+1]].y if ground else b.z
        var qc:=uv[indices[i+2]].y if ground else c.z
        if maxf(qa,maxf(qb,qc))<minimum_depth: continue
        var pa:=_transform*Vector2(a.x,a.y);var pb:=_transform*Vector2(b.x,b.y);var pc:=_transform*Vector2(c.x,c.y)
        var lo:=pa.min(pb).min(pc);var hi:=pa.max(pb).max(pc)
        if hi.x<bounds.position.x or hi.y<bounds.position.y or lo.x>bounds.end.x or lo.y>bounds.end.y: continue
        var polygon: Array=[]
        for k in range(3):
            var id:=indices[i+k];var v:=vertices[id];var p:=_transform*Vector2(v.x,v.y)
            polygon.append([Vector3(p.x,p.y,uv[id].y if ground else v.z),uv[id],Color.WHITE if colors.is_empty() else colors[id]])
        if not bounds.encloses(Rect2(lo,hi-lo)):
            polygon=_clip(polygon,0,bounds.position.x,true)
            polygon=_clip(polygon,0,bounds.end.x,false)
            polygon=_clip(polygon,1,bounds.position.y,true)
            polygon=_clip(polygon,1,bounds.end.y,false)
        if polygon.size()<3: continue
        var first: int=out.v.size()
        for point in polygon:
            out.v.append(point[0]);out.uv.append(point[1]);out.c.append(point[2])
        for k in range(1,polygon.size()-1): out.ids.append_array(PackedInt32Array([first,first+k,first+k+1]))

func _clip(input: Array,axis: int,edge: float,greater: bool) -> Array:
    var out: Array=[]
    if input.is_empty(): return out
    var previous: Array=input[-1]
    var was_inside: bool=previous[0][axis]>=edge if greater else previous[0][axis]<=edge
    for current: Array in input:
        var inside: bool=current[0][axis]>=edge if greater else current[0][axis]<=edge
        if inside!=was_inside:
            var t: float=(edge-previous[0][axis])/(current[0][axis]-previous[0][axis])
            out.append([previous[0].lerp(current[0],t),previous[1].lerp(current[1],t),previous[2].lerp(current[2],t)])
        if inside: out.append(current)
        previous=current;was_inside=inside
    return out

func _airframe_bounds(camera: Camera3D,airframe: Node3D,size_: Vector2) -> Rect2:
    var center:=camera.to_local(airframe.global_position)
    if -center.z<=8.0+camera.near: return Rect2(Vector2.ZERO,size_)
    var rect:=Rect2(camera.unproject_position(airframe.global_position),Vector2.ZERO)
    for x: float in [-8,8]:
        for y: float in [-8,8]:
            for z: float in [-8,8]: rect=rect.expand(camera.unproject_position(camera.to_global(center+Vector3(x,y,z))))
    return rect.grow(2).intersection(Rect2(Vector2.ZERO,size_))
