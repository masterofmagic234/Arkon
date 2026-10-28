extends RefCounted
## Compact instancing batches preserve authored transforms and visibility ranges. A
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
    var shadow_visible:=true
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
    var cluster_order: Array[Cluster]=[]
    var sort_position:=Vector3(INF,INF,INF)
    var canopy: MultiMeshInstance3D
    var canopy_bounds: AABB
    var canopy_ao:=true
    var near_mesh: Mesh
    var far_mesh: Mesh
    var shadow_multi: MultiMesh
    var instance: MultiMeshInstance3D
    var legacy_mesh: Mesh
static var mask_cache: Dictionary={}
static func alpha_mask(atlas: Texture2D) -> Texture2D:
    if mask_cache.has(atlas):return mask_cache[atlas]
    var image:=atlas.get_image()
    if image==null:return null
    if image.is_compressed() and image.decompress()!=OK:return null
    image.convert(Image.FORMAT_RGBA8)
    var source:=image.get_data()
    var coverage:=PackedByteArray();coverage.resize(source.size()/4)
    for i in range(coverage.size()):coverage[i]=source[i*4+3]
    # Extract decoded platform alpha, including the EXISTING mip chain. Never
    # regenerate mips or derive coverage from the uncompressed source PNG.
    var mask:=Image.create_from_data(image.get_width(),image.get_height(),image.has_mipmaps(),Image.FORMAT_R8,coverage)
    var texture:=ImageTexture.create_from_image(mask)
    mask_cache[atlas]=texture
    return texture
static func atlas_alpha_shader(source: Shader) -> Shader:
    var shader:=Shader.new()
    shader.code=source.code.replace("texture(alpha_mask, UV).r","texture(atlas, UV).a")
    return shader
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
    # Avoid fragment pow on GL; the original platform atlas still supplies alpha.
    var color_atlas=preload("res://assets/level1/botanical/foliage_color_gl.png") if RenderingServer.get_current_rendering_method()=="gl_compatibility" else world.ATLAS
    var foliage=ShaderMaterial.new();foliage.shader=preload("res://shaders/woodland/garden_foliage.gdshader");foliage.set_shader_parameter("atlas",color_atlas)
    var canopy=ShaderMaterial.new();canopy.shader=preload("res://shaders/woodland/garden_canopy.gdshader");canopy.set_shader_parameter("atlas",color_atlas)
    var mask:=alpha_mask(world.ATLAS)
    for material in [foliage,canopy]:
        material.set_shader_parameter("alpha_mask",mask if mask!=null else world.ATLAS)
        if mask==null:material.shader=atlas_alpha_shader(material.shader)
    # Binary canopy is opaque after its mask test. Populate depth/color before
    # genuinely translucent glass, whose default priority is zero; sorting a
    # whole foliage batch by its center cannot safely interleave it with panes.
    canopy.render_priority=-1
    world.mats.leaves=foliage;world.mats.canopy=canopy
    for i in range(6):
        var key="leaf%d"%i;var arrays=world.meshes[key].surface_get_arrays(0)
        var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
        # cull_disabled already flips the normal before the old fragment code
        # flips it back. Preserve that accepted same-normal look on both sides,
        # including shadow normal bias, with fixed backface culling instead.
        for k in [0,1,2,3,4,5,0,2,1,3,5,4]:
            st.set_normal(arrays[Mesh.ARRAY_NORMAL][k]);st.set_color(arrays[Mesh.ARRAY_COLOR][k]);st.set_uv(arrays[Mesh.ARRAY_TEX_UV][k]);st.add_vertex(arrays[Mesh.ARRAY_VERTEX][k])
        world.meshes[key]=st.commit()
        world.meshes["shadow_"+key]=world.meshes[key]
        var shaped: ArrayMesh=load("res://assets/level1/botanical/meshes/foliage_%d.res"%i).duplicate()
        var solid=ShaderMaterial.new();solid.shader=preload("res://shaders/woodland/garden_leaf_solid.gdshader");solid.set_shader_parameter("atlas",color_atlas)
        shaped.surface_set_material(0,solid);shaped.surface_set_material(1,foliage)
        world.meshes[key]=shaped
        if i==0:
            var distant: ArrayMesh=shaped.duplicate()
            distant.surface_set_material(1,canopy)
            world.meshes.leaf0_far=distant

var records: Array[Batch]=[]
var last_camera:=Transform3D(Basis.IDENTITY,Vector3(INF,INF,INF))
var last_projection:=Vector4.ZERO
var enabled:=true
var foliage_sorting_enabled:=true
var cluster_sorting_enabled:=RenderingServer.get_current_rendering_method()=="gl_compatibility"
var foliage_geometry_enabled:=true
var last_sort_position:=Vector3(INF,INF,INF)
var force_upload:=false
var upload_count:=0
var buffer_upload_bytes:=0
var last_update_usec:=0
var light_direction:=Vector3.ZERO
var foliage_opaque: Material
var foliage_far: Material
func setup(world: Node3D) -> void:
    # The dummy renderer does not provide MultiMesh buffers or bounds. Gameplay
    # headless gates do not render and have no visibility work to optimize.
    if DisplayServer.get_name()=="headless":return
    light_direction=-world.get_node("GardenSun").global_basis.z
    foliage_opaque=world.mats.leaves;foliage_far=world.mats.canopy
    for source in world.get_children():
        if not source is MultiMeshInstance3D:continue
        if source.get_meta("foliage_shadow_proxy",false):continue
        if source.material_override in [world.mats.glass,world.mats.water]:continue
        var multi: MultiMesh=source.multimesh
        var original: PackedFloat32Array=multi.buffer
        var stride=16 if multi.use_custom_data else 12
        var clusters={}
        var positions:=PackedVector3Array()
        var elements: Array[PackedFloat32Array]=[]
        var cluster_for_instance: Array[Cluster]=[]
        var cutout=source.get_meta("botanical_cutout",source.get_meta("botanical_foliage",false))
        for i in range(multi.instance_count):
            var t=multi.get_instance_transform(i)
            var key=Vector2i(floori(t.origin.x/CELL),floori(t.origin.z/CELL))
            var bound=source.global_transform*(t*(AABB(Vector3(-.5,-.5,0),Vector3(1,1,0)) if cutout else multi.mesh.get_aabb()))
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
        record.instance=source
        if cutout:
            record.near_mesh=multi.mesh;record.legacy_mesh=source.get_meta("foliage_legacy_mesh")
        record.cutout=cutout;record.positions=positions;record.elements=elements;record.cluster_for_instance=cluster_for_instance
        if source.get_meta("foliage_casts_shadow",false):
            record.canopy=source;record.canopy_bounds=source.global_transform*source.get_aabb()
            record.near_mesh=multi.mesh;record.far_mesh=world.meshes.leaf0_far
        var proxy=source.get_meta("foliage_shadow_node") if source.has_meta("foliage_shadow_node") else null
        if proxy!=null:record.shadow_multi=proxy.multimesh
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
        if record.shadow_multi!=null:record.shadow_multi.custom_aabb=multi.custom_aabb
        record.multi=multi;record.stride=stride;record.shadow=source.cast_shadow!=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF or source.has_meta("foliage_shadow_node");record.original=original;records.append(record)

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
    # GL sorts coarse clusters every four meters; Forward+ retains native
    # integer card sorting every meter. Turns only filter cached orders.
    var eye:=camera.global_position
    var sort_moved:=last_sort_position.distance_squared_to(eye)>=(16.0 if cluster_sorting_enabled else 1.0)
    if sort_moved:last_sort_position=eye
    for record: Batch in records:
        var sort_record:=record.sort_position.distance_squared_to(eye)>=(16.0 if cluster_sorting_enabled else 1.0)
        if record.canopy!=null:
            # Preserve original screen-space contact shading on every nearby
            # card, conservatively using the entire ORIGINAL batch bounds.
            # Far-only batches bypass normals; the hysteresis avoids chatter.
            # Reconstructed opaque interiors can use the original AO path.
            # Preserve contact shading at every distance; the old far-card
            # workaround is no longer applied to the new geometry or its A/B.
            if not record.canopy_ao:
                record.canopy_ao=true;apply_foliage_geometry(record)
        var changed:=false;var shadow_changed:=force_upload;var any_color_visible:=false
        for cluster: Cluster in record.clusters:
            var color_visible:=intersects(planes,normals,cluster.center,cluster.extent)
            any_color_visible=any_color_visible or color_visible
            var shadow_visible:=color_visible
            if not shadow_visible and record.shadow:shadow_visible=casts_into_view(shadow_planes,normals,extensions,cluster.center,cluster.extent,cluster.shadow_length)
            # An independent original-card shadow buffer retains the old union
            # of visible and offscreen shadow casters. Camera geometry no longer
            # has to submit those offscreen plants just to retain their shadows.
            var visible_:=color_visible if record.shadow_multi!=null else shadow_visible
            if cluster.shadow_visible!=shadow_visible:shadow_changed=true
            cluster.shadow_visible=shadow_visible
            if cluster.visible!=visible_:changed=true;cluster.visible=visible_
        var sort_visible=record.cutout and foliage_sorting_enabled and sort_record and any_color_visible
        var update_color=changed or force_upload or sort_visible
        if not update_color and not (record.shadow_multi!=null and shadow_changed):continue
        if update_color:
            var buffer:=PackedFloat32Array()
            if record.cutout and foliage_sorting_enabled and cluster_sorting_enabled:
                if sort_record or record.cluster_order.is_empty():
                    record.cluster_order.assign(record.clusters)
                    record.cluster_order.sort_custom(func(a,b):return a.center.distance_squared_to(eye)<b.center.distance_squared_to(eye))
                    record.sort_position=eye
                for cluster in record.cluster_order:
                    if cluster.visible:buffer.append_array(cluster.buffer)
            elif record.cutout and foliage_sorting_enabled:
                # Visibility changes only filter a cached ordering. They must not
                # recompute all distances and sort again on each camera turn.
                if sort_record or record.order.is_empty():
                    var keys:=PackedInt64Array()
                    for index in range(record.positions.size()):
                        var distance_bin:=int(eye.distance_squared_to(record.positions[index])*16.0)
                        keys.append((distance_bin<<32)|index)
                    keys.sort();record.order.clear()
                    for key in keys:record.order.append(int(key&0xffffffff))
                    record.sort_position=eye
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
            buffer_upload_bytes+=buffer.size()*4
        if record.shadow_multi!=null and shadow_changed:
            var shadow_buffer:=PackedFloat32Array()
            for cluster in record.clusters:
                if cluster.shadow_visible:shadow_buffer.append_array(cluster.buffer)
            var shadow_count:=shadow_buffer.size()/record.stride
            shadow_buffer.resize(record.original.size())
            record.shadow_multi.buffer=shadow_buffer;record.shadow_multi.visible_instance_count=shadow_count
            upload_count+=1
            buffer_upload_bytes+=shadow_buffer.size()*4
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
        record.sort_position=Vector3(INF,INF,INF)
        record.multi.buffer=record.original;record.multi.visible_instance_count=-1
        if record.shadow_multi!=null:
            record.shadow_multi.buffer=record.original;record.shadow_multi.visible_instance_count=-1
        if record.canopy!=null and not value:
            record.canopy_ao=true;apply_foliage_geometry(record)
        for cluster in record.clusters:cluster.visible=true;cluster.shadow_visible=true

func apply_foliage_geometry(record: Batch) -> void:
    if foliage_geometry_enabled:
        record.multi.mesh=record.far_mesh if record.canopy!=null and not record.canopy_ao else record.near_mesh
        record.instance.material_override=null
    else:
        record.multi.mesh=record.legacy_mesh
        record.instance.material_override=foliage_far if record.canopy!=null and not record.canopy_ao else foliage_opaque
func set_foliage_geometry_enabled(value: bool) -> void:
    foliage_geometry_enabled=value
    for record in records:
        if record.cutout:apply_foliage_geometry(record)

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

## Offline benchmark estimate only; never called in gameplay. Projected card
## area weights the surviving cutout/opaque area at the renderer-selected LOD.
## Perspective within each card and fragment quad scheduling are not modeled.
func foliage_workload(camera: Camera3D) -> Dictionary:
    var viewport=camera.get_viewport();var size_=Vector2(viewport.size)
    var screen=PackedVector2Array([Vector2.ZERO,Vector2(size_.x,0),size_,Vector2(0,size_.y)])
    var threshold=viewport.mesh_lod_threshold/size_.x
    var multiplier=2.0/camera.get_camera_projection().x.x
    var original_area=0.0;var masked_area=0.0;var solid_area=0.0;var count=0;var lod_counts={}
    for record in records:
        if not record.cutout:continue
        var levels=record.near_mesh.get_meta("coverage")
        var bounds=record.instance.global_transform*record.instance.get_aabb()
        var distance=camera.global_position.distance_to(camera.global_position.clamp(bounds.position,bounds.end))*multiplier
        var level=0
        if distance>0:
            for i in range(1,levels.size()):
                if (.5/levels[i-1].resolution)*record.instance.lod_bias/distance>threshold:break
                level=i
        var total=record.multi.visible_instance_count
        if total<0:total=record.multi.instance_count
        lod_counts[str(levels[level].resolution)]=lod_counts.get(str(levels[level].resolution),0)+total
        for i in range(total):
            var transform_=record.instance.global_transform*record.multi.get_instance_transform(i)
            var quad:=PackedVector2Array();var valid=true
            for point in [Vector3(-.5,-.5,0),Vector3(.5,-.5,0),Vector3(.5,.5,0),Vector3(-.5,.5,0)]:
                var world=transform_*point
                if camera.is_position_behind(world):valid=false;break
                quad.append(camera.unproject_position(world))
            if not valid:continue
            var area=0.0
            for polygon in Geometry2D.intersect_polygons(quad,screen):
                var signed_area=0.0
                for k in range(polygon.size()):signed_area+=polygon[k].cross(polygon[(k+1)%polygon.size()])
                area+=absf(signed_area)*.5
            if area==0:continue
            count+=1;original_area+=area
            masked_area+=area*levels[level].edge_area/(.98*.98) if foliage_geometry_enabled else area
            if foliage_geometry_enabled:solid_area+=area*levels[level].core_area/(.98*.98)
    return {"original_card_area_estimate":original_area,"masked_area_estimate":masked_area,"opaque_area_estimate":solid_area,"masked_area_ratio":masked_area/maxf(1,original_area),"on_screen_cards":count,"lod_instances":lod_counts,"note":"Projected-card area weighted by UV coverage, not GPU invocations or phone timing."}
