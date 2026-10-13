extends RefCounted
# Two coherent ground surfaces consume the existing shared main camera.
# UV floats carry homogeneous road coordinates without colour quantization.
const ROWS := 128
const Data=preload("res://scripts/race_level_data.gd")
var road := ArrayMesh.new()
var verge := ArrayMesh.new()
var road_node: MeshInstance2D
var verge_node: MeshInstance2D
var back: Polygon2D
var road_material: ShaderMaterial
var verge_material: ShaderMaterial
var _road_vertices := PackedVector3Array()
var _road_uv := PackedVector2Array()
var _verge_vertices := PackedVector3Array()
var _verge_uv := PackedVector2Array()
var _road_indices := PackedInt32Array()
var _verge_indices := PackedInt32Array()
var _road_arrays: Array=[]
var _verge_arrays: Array=[]
func setup(host: Node2D, asphalt: Texture2D, grass: Texture2D) -> void:
    back=Polygon2D.new();back.color=Color("152534");back.z_index=-4;host.add_child(back)
    road_material=ShaderMaterial.new();road_material.shader=preload("res://shaders/race_ground.gdshader")
    verge_material=road_material.duplicate();verge_material.set_shader_parameter("meadow",true)
    verge_node=_node(host,"ProjectedVerge",verge,grass,verge_material,-3)
    road_node=_node(host,"ProjectedRoad",road,asphalt,road_material,-2)
    _road_vertices.resize(ROWS*2);_road_uv.resize(ROWS*2)
    _verge_vertices.resize(ROWS*4);_verge_uv.resize(ROWS*4)
    for i in range(ROWS-2,-1,-1):
        _quad_indices(_road_indices,i*2,i*2+1,(i+1)*2+1,(i+1)*2)
        _quad_indices(_verge_indices,i*4,i*4+1,(i+1)*4+1,(i+1)*4)
        _quad_indices(_verge_indices,i*4+2,i*4+3,(i+1)*4+3,(i+1)*4+2)
    _road_arrays.resize(Mesh.ARRAY_MAX);_verge_arrays.resize(Mesh.ARRAY_MAX)
    _road_arrays[Mesh.ARRAY_INDEX]=_road_indices;_verge_arrays[Mesh.ARRAY_INDEX]=_verge_indices
func _node(host: Node2D, name_: String, mesh_: ArrayMesh, tex: Texture2D, mat: ShaderMaterial, depth: int) -> MeshInstance2D:
    var node := MeshInstance2D.new()
    node.name=name_;node.mesh=mesh_;node.texture=tex;node.material=mat;node.z_index=depth
    host.add_child(node);return node
func _quad_indices(target: PackedInt32Array, a: int,b: int,c: int,d: int) -> void:
    target.append_array(PackedInt32Array([a,b,c,a,c,d]))
func update(host: Node2D, size_: Vector2) -> void:
    var play_h: float=size_.y*host.PLAYFIELD_FRACTION
    var horizon: float=host._horizon(play_h)
    back.polygon=PackedVector2Array([Vector2(0,horizon),Vector2(size_.x,horizon),size_,Vector2(0,size_.y)])
    var at: float=host.player_car.track_phase()
    var camera_x: float=host._camera_world_x(at)
    var behind: float=host._behind()
    var far_z: float=60*Data.SEGMENT_HEIGHT+behind
    var zoom: float=host.camera_state.zoom if host.camera_state!=null else 1.0
    for material in [road_material,verge_material]:
        material.set_shader_parameter("logical_size",size_)
        material.set_shader_parameter("horizon",horizon)
        material.set_shader_parameter("vertical_scale",(play_h-horizon)*6.0*zoom)
        material.set_shader_parameter("focal",.84*zoom*size_.x*.75)
        material.set_shader_parameter("camera_yaw",float(host.camera_state.yaw_offset) if host.camera_state!=null else 0.0)
        material.set_shader_parameter("camera_roll",float(host.camera_state.roll) if host.camera_state!=null else 0.0)
        material.set_shader_parameter("origin",Vector2(camera_x,at*Data.SEGMENT_HEIGHT-behind))
        material.set_shader_parameter("car_position",Vector2(float(host.player_car.world_x),at*Data.SEGMENT_HEIGHT))
        material.set_shader_parameter("car_yaw",float(host.player_car.heading_yaw))
    var rivals := PackedVector4Array()
    for ai in host.ai_cars:
        rivals.append(Vector4(float(ai.car.world_x),float(ai.car.world_z),float(ai.car.heading_yaw),1))
    for material in [road_material,verge_material]: material.set_shader_parameter("rival_lights",rivals)
    for i in range(ROWS):
        var t := float(i)/float(ROWS-1)
        var z := 4.8/lerpf(1.0,4.8/far_z,t)-6.0+behind
        var segment := at+(z-behind)/Data.SEGMENT_HEIGHT
        var centre: float=host._smooth_track_x(segment)
        var edge := Data.ROAD_WIDTH*.5+.32
        var outer := minf(1000.0,z*2.0+30.0)
        for side in range(2):
            var lateral := edge*(-1.0 if side==0 else 1.0)
            var relative_x := centre-camera_x+lateral
            var screen: Vector2=host._project_relative(relative_x,z,size_.x,play_h,horizon)
            var q: float=1.0/maxf(host._world_to_camera(relative_x,z).y,.5)
            _road_vertices[i*2+side]=Vector3(screen.x,screen.y,0)
            _road_uv[i*2+side]=Vector2(lateral*q,q)
            for boundary in range(2):
                var width := outer if boundary==0 else edge
                var x := centre-camera_x+width*(-1.0 if side==0 else 1.0)
                var p: Vector2=host._project_relative(x,z,size_.x,play_h,horizon)
                var index := i*4+side*2+boundary
                _verge_vertices[index]=Vector3(p.x,p.y,0);_verge_uv[index]=Vector2.ZERO
    _road_arrays[Mesh.ARRAY_VERTEX]=_road_vertices;_road_arrays[Mesh.ARRAY_TEX_UV]=_road_uv
    _verge_arrays[Mesh.ARRAY_VERTEX]=_verge_vertices;_verge_arrays[Mesh.ARRAY_TEX_UV]=_verge_uv
    road.clear_surfaces();road.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,_road_arrays)
    verge.clear_surfaces();verge.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,_verge_arrays)
