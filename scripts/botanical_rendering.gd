extends RefCounted
## Retain the original instancing batches and their distance hysteresis. A
## visible prefix excludes clusters that neither enter the camera frustum nor
## cast a shadow into it. No authored transforms or foliage cards are removed.
const CELL=12.0
class Cluster:
    var buffer:=PackedFloat32Array()
    var indices:=PackedInt32Array()
    var bounds: AABB
    var center: Vector3
    var extent: Vector3
    var shadow_length: float
    var visible:=true
class Batch:
    var multi: MultiMesh
    var clusters: Array[Cluster]=[]
    var stride: int
    var shadow: bool
    var original: PackedFloat32Array
    var cutout:=false
    var positions:=PackedVector3Array()
    var elements: Array[PackedFloat32Array]=[]
    var cluster_for_instance: Array[Cluster]=[]
    var order:=PackedInt32Array()
static func optimize_materials(world: Node3D) -> void:
    for key in ["stone","trim","paving","wood","bark","cliff"]:
        var source: StandardMaterial3D=world.mats[key]
        var material=ShaderMaterial.new();material.shader=preload("res://shaders/woodland/garden_triplanar.gdshader")
        material.set_shader_parameter("albedo",source.albedo_color)
        material.set_shader_parameter("texture_albedo",source.albedo_texture)
        material.set_shader_parameter("texture_normal",source.normal_texture)
        material.set_shader_parameter("texture_roughness",source.roughness_texture)
        material.set_shader_parameter("has_normal",source.normal_enabled)
        material.set_shader_parameter("has_roughness",source.roughness_texture!=null)
        material.set_shader_parameter("roughness",source.roughness)
        material.set_shader_parameter("normal_scale",source.normal_scale)
        material.set_shader_parameter("uv_scale",source.uv1_scale)
        material.set_shader_parameter("blend_sharpness",source.uv1_triplanar_sharpness)
        world.mats[key]=material
var records: Array[Batch]=[]
var last_camera:=Transform3D(Basis.IDENTITY,Vector3(INF,INF,INF))
var last_projection:=Vector4.ZERO
var enabled:=true
var foliage_sorting_enabled:=true
var last_sort_position:=Vector3(INF,INF,INF)
var force_upload:=false
var upload_count:=0
var last_update_usec:=0
var light_direction:=Vector3.ZERO
func setup(world: Node3D) -> void:
    # The dummy renderer does not provide MultiMesh buffers or bounds. Gameplay
    # headless gates do not render and have no visibility work to optimize.
    if DisplayServer.get_name()=="headless":return
    light_direction=-world.get_node("GardenSun").global_basis.z
    for source in world.get_children():
        if not source is MultiMeshInstance3D:continue
        if source.material_override in [world.mats.glass,world.mats.water]:continue
        var multi: MultiMesh=source.multimesh
        var original: PackedFloat32Array=multi.buffer
        var stride=16 if multi.use_custom_data else 12
        var clusters={}
        var positions:=PackedVector3Array()
        var elements: Array[PackedFloat32Array]=[]
        var cluster_for_instance: Array[Cluster]=[]
        var cutout=source.material_override==world.mats.leaves
        for i in range(multi.instance_count):
            var t=multi.get_instance_transform(i)
            var key=Vector2i(floori(t.origin.x/CELL),floori(t.origin.z/CELL))
            var bound=source.global_transform*(t*multi.mesh.get_aabb())
            if not clusters.has(key):
                var cluster=Cluster.new();cluster.bounds=bound;clusters[key]=cluster
            var cluster: Cluster=clusters[key]
            var element:=original.slice(i*stride,(i+1)*stride)
            cluster.buffer.append_array(element)
            if cutout:elements.append(element)
            cluster_for_instance.append(cluster)
            cluster.indices.append(i);positions.append(source.global_transform*t.origin)
            cluster.bounds=cluster.bounds.merge(bound)
        var record=Batch.new();record.clusters.assign(clusters.values())
        record.cutout=cutout;record.positions=positions;record.elements=elements;record.cluster_for_instance=cluster_for_instance
        for cluster: Cluster in record.clusters:
            cluster.center=cluster.bounds.get_center()
            # Include every original vertex and a two-meter guard band for
            # soft-shadow filtering and floating-point edge cases.
            cluster.extent=cluster.bounds.size*.5+Vector3.ONE*2.0
            # A shadow cannot reach below the garden's lowest receiver. Using
            # the real cluster height keeps this conservative without retaining
            # every low flower pot as if it were a forty-meter tree.
            cluster.shadow_length=maxf(0,(cluster.bounds.end.y+6.0)/maxf(.001,-light_direction.y))
        multi.custom_aabb=source.get_aabb()
        record.multi=multi;record.stride=stride;record.shadow=source.cast_shadow!=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;record.original=original;records.append(record)

func update(camera: Camera3D) -> void:
    if camera==null or not enabled or records.is_empty():return
    var projection:=Vector4(camera.fov,camera.near,camera.far,camera.get_viewport().get_visible_rect().size.aspect())
    if last_camera.is_equal_approx(camera.global_transform) and projection.is_equal_approx(last_projection):return
    var started:=Time.get_ticks_usec()
    last_camera=camera.global_transform;last_projection=projection
    var planes: Array[Plane]=camera.get_frustum()
    var forward:=-camera.global_basis.z
    var inside:=camera.global_position+forward*minf(camera.far*.5,30.0)
    for i in range(planes.size()):
        if planes[i].distance_to(inside)>0:planes[i]=-planes[i]
    var shadow_planes: Array[Plane]=planes.duplicate()
    shadow_planes.append(Plane(forward,forward.dot(camera.global_position+forward*55.0)))
    var normals:=PackedVector3Array()
    for plane in shadow_planes:normals.append(plane.normal.abs())
    var extensions:=PackedFloat32Array()
    for plane in shadow_planes:extensions.append(maxf(0,-plane.normal.dot(light_direction)))
    # Ordering changes no geometry or shading. The driver can reject hidden
    # cutout fragments sooner when nearby foliage has already written depth,
    # particularly in the normal/roughness prepass required by SSAO. Quantized
    # integer keys sort in native code; a one-meter threshold avoids uploading
    # every batch on each tiny camera movement or head turn.
    var eye:=camera.global_position
    var sort_moved:=last_sort_position.distance_squared_to(eye)>=1.0
    if sort_moved:last_sort_position=eye
    for record: Batch in records:
        var changed:=false
        for cluster: Cluster in record.clusters:
            var visible_:=intersects(planes,normals,cluster.center,cluster.extent)
            if not visible_ and record.shadow:visible_=casts_into_view(shadow_planes,normals,extensions,cluster.center,cluster.extent,cluster.shadow_length)
            if cluster.visible!=visible_:changed=true;cluster.visible=visible_
        if not changed and not force_upload and not (record.cutout and foliage_sorting_enabled and sort_moved):continue
        var buffer:=PackedFloat32Array()
        if record.cutout and foliage_sorting_enabled:
            # Visibility changes only filter a cached ordering. They must not
            # recompute all distances and sort again on each camera turn.
            if sort_moved or record.order.is_empty():
                var keys:=PackedInt64Array()
                for index in range(record.positions.size()):
                    var distance_bin:=int(eye.distance_squared_to(record.positions[index])*16.0)
                    keys.append((distance_bin<<32)|index)
                keys.sort();record.order.clear()
                for key in keys:record.order.append(int(key&0xffffffff))
            for index in record.order:
                if not record.cluster_for_instance[index].visible:continue
                # Reuse immutable twelve-float blocks. Creating thousands of
                # temporary slices on a turn would trade GPU overdraw for CPU
                # allocation spikes on the phone.
                buffer.append_array(record.elements[index])
        else:
            for cluster: Cluster in record.clusters:
                if cluster.visible:buffer.append_array(cluster.buffer)
        var visible_count:=buffer.size()/record.stride
        buffer.resize(record.original.size())
        record.multi.buffer=buffer;record.multi.visible_instance_count=visible_count
        upload_count+=1
    force_upload=false
    last_update_usec=Time.get_ticks_usec()-started

static func intersects(planes: Array[Plane],normals: PackedVector3Array,center: Vector3,extent: Vector3) -> bool:
    for i in range(planes.size()):
        if planes[i].distance_to(center)>normals[i].dot(extent):return false
    return true
static func casts_into_view(planes: Array[Plane],normals: PackedVector3Array,extensions: PackedFloat32Array,center: Vector3,extent: Vector3,length_: float) -> bool:
    for i in range(planes.size()):
        if planes[i].distance_to(center)>normals[i].dot(extent)+extensions[i]*length_:return false
    return true
func set_enabled(value: bool) -> void:
    enabled=value;last_camera=Transform3D(Basis.IDENTITY,Vector3(INF,INF,INF));last_sort_position=Vector3(INF,INF,INF);force_upload=true
    for record in records:
        record.multi.buffer=record.original;record.multi.visible_instance_count=-1
        for cluster in record.clusters:cluster.visible=true

func set_foliage_sorting_enabled(value: bool) -> void:
    foliage_sorting_enabled=value;force_upload=true
    last_camera=Transform3D(Basis.IDENTITY,Vector3(INF,INF,INF));last_sort_position=Vector3(INF,INF,INF)

static func add_occluders(world: Node3D) -> void:
    # Only real opaque surfaces occlude. Invisible physics boundaries, water,
    # glass and alpha-cutout foliage must never hide an object behind them.
    for source in world.get_children():
        if not source is MeshInstance3D:continue
        if source.material_override!=world.mats.ground:continue
        var arrays=source.mesh.surface_get_arrays(0)
        var occluder=ArrayOccluder3D.new();occluder.set_arrays(arrays[Mesh.ARRAY_VERTEX],arrays[Mesh.ARRAY_INDEX])
        var instance=OccluderInstance3D.new();instance.occluder=occluder;instance.name="TerrainOccluder";instance.transform=source.transform;world.add_child(instance)
