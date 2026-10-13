extends RefCounted
# Two coherent ground surfaces consume the existing shared main camera.
# UV floats carry homogeneous road coordinates without colour quantization.
const ROWS := 128
const Data=preload("res://scripts/race_level_data.gd")
const RaceProjection=preload("res://scripts/race_projection.gd")
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
    var at: float=host.player_car.track_phase()
    var camera_x: float=host._camera_world_x(at)
    var behind: float=host._behind()
    var far_z: float=60*Data.SEGMENT_HEIGHT+behind
    var zoom: float=host.camera_state.zoom if host.camera_state!=null else 1.0
    var world_horizon: float=horizon+host.CAMERA_DEPTH*zoom*size_.x*host.ROAD_SCREEN_SCALE*(float(host.camera_state.road_grade) if host.camera_state!=null else 0.0)
    back.polygon=PackedVector2Array([Vector2(0,world_horizon),Vector2(size_.x,world_horizon),size_,Vector2(0,size_.y)])
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
        material.set_shader_parameter("bridge_start",Data.BRIDGE_START)
        material.set_shader_parameter("bridge_end",Data.BRIDGE_END)
        material.set_shader_parameter("tunnel_start",Data.TUNNEL_START)
        material.set_shader_parameter("tunnel_end",Data.TUNNEL_END)
    var rivals := PackedVector4Array()
    for ai in host.ai_cars:
        var z: float=ai.car.world_z
        rivals.append(Vector4(float(ai.car.world_x)+host._curve_presentation_shift(z),z,host._presentation_heading(z,float(ai.car.heading_yaw)),1))
    for material in [road_material,verge_material]: material.set_shader_parameter("rival_lights",rivals)
    _verge_vertices.clear();_verge_uv.clear();_verge_indices.clear()
    var previous_sides: Array[Vector3] = []
    for i in range(ROWS):
        var t := float(i)/float(ROWS-1)
        # Reciprocal screen spacing left a single 330→2400 m strip. It erased
        # distant bends/grades into a straight chord. Log depth retains the
        # same row budget while sampling the complete visible route.
        var z := 4.8*pow(far_z/4.8,t)-6.0+behind
        var segment := at+(z-behind)/Data.SEGMENT_HEIGHT
        var centre: float=host._smooth_track_x(segment)
        var edge := Data.ROAD_WIDTH*.5+.32
        var outer := z*3.0+40.0
        var sides: Array[Vector3] = []
        var world_z: float=float(host.player_car.world_z)+z-behind
        for side in range(2):
            var lateral := edge*(-1.0 if side==0 else 1.0)
            var relative_x: float=centre-camera_x+lateral+host._curve_presentation_shift(world_z)
            var screen: Vector2=host._project_relative(relative_x,z,size_.x,play_h,horizon,host._road_relative_height(world_z))
            var q: float=1.0/maxf(host._world_to_camera(relative_x,z).y,.5)
            _road_vertices[i*2+side]=Vector3(screen.x,screen.y,0)
            _road_uv[i*2+side]=Vector2(lateral*q,q)
            for boundary in range(2):
                var width := outer if boundary==0 else edge
                sides.append(host._camera_point(Vector3(centre+width*(-1.0 if side==0 else 1.0),0,world_z)))
        if i>0:
            for side in range(2):
                var offset := side*2
                var clipped := RaceProjection.clip_camera(host,[previous_sides[offset],previous_sides[offset+1],sides[offset+1],sides[offset]],size_)
                var first := _verge_vertices.size()
                for camera: Vector3 in clipped:
                    var p: Vector2=host._project_camera_point(camera,size_)
                    _verge_vertices.append(Vector3(p.x,p.y,0))
                    _verge_uv.append(Vector2(0,1.0/camera.z))
                for corner in range(1,clipped.size()-1):
                    _verge_indices.append_array(PackedInt32Array([first,first+corner,first+corner+1]))
        previous_sides=sides
    _road_arrays[Mesh.ARRAY_VERTEX]=_road_vertices;_road_arrays[Mesh.ARRAY_TEX_UV]=_road_uv
    # Elevated strips overlap on screen: distant terrain must be behind crests.
    _verge_indices.reverse()
    _verge_arrays[Mesh.ARRAY_VERTEX]=_verge_vertices;_verge_arrays[Mesh.ARRAY_TEX_UV]=_verge_uv
    _verge_arrays[Mesh.ARRAY_INDEX]=_verge_indices
    road.clear_surfaces();road.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,_road_arrays)
    verge.clear_surfaces();verge.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,_verge_arrays)
