extends RefCounted
## Reversible profile for the actual visible receivers as well as their hidden
## source batches. Embedded baked-ground materials need the same treatment.
const GROUND = preload("res://shaders/woodland/garden_ground_fast.gdshader")
const HERBS = preload("res://shaders/woodland/garden_herbs_fast.gdshader")
const TRIPLANAR = preload("res://shaders/woodland/garden_triplanar_fast.gdshader")
var records: Array[Dictionary]=[]
var copies: Dictionary={}
var enabled:=false
var counts: Dictionary={"ground":0,"herbs":0,"triplanar":0}

static func make_material(source: ShaderMaterial, shader: Shader) -> ShaderMaterial:
    var material=ShaderMaterial.new()
    material.shader=shader
    var available={}
    for parameter in source.shader.get_shader_uniform_list():available[String(parameter.name)]=true
    for parameter in shader.get_shader_uniform_list():
        var name_=String(parameter.name)
        if not available.has(name_):continue
        var value=source.get_shader_parameter(name_)
        if value!=null:material.set_shader_parameter(name_,value)
    material.render_priority=source.render_priority
    return material

func _kind(source: ShaderMaterial) -> String:
    if source.shader in [GROUND,HERBS,TRIPLANAR]:return ""
    var path=source.shader.resource_path
    if path=="res://shaders/woodland/garden_herbs.gdshader":return "herbs"
    if path=="res://shaders/woodland/garden_triplanar.gdshader":return "triplanar"
    # Baked terrain holds an embedded copy, not the live source shader path.
    var parameters={}
    for parameter in source.shader.get_shader_uniform_list():parameters[String(parameter.name)]=true
    if parameters.has("grass") and parameters.has("soil"):return "ground"
    return ""

func setup(world: Node3D) -> void:
    for node in world.find_children("*","GeometryInstance3D",true,false):
        if node.get_meta("performance_preserve_material_147",false):continue
        if node.material_override!=null:
            _record(node,node.material_override as ShaderMaterial,-1,node.material_override)
        elif node is MeshInstance3D:
            # All 231 baked receivers store materials on their mesh surfaces.
            # A node-level-only scan would optimize hidden source terrain while
            # leaving every actual visible embedded ground shader unchanged.
            for surface in range(node.mesh.get_surface_count()):
                _record(node,node.get_active_material(surface) as ShaderMaterial,surface,node.get_surface_override_material(surface))

func _record(node: GeometryInstance3D,source: ShaderMaterial,surface: int,original_override: Material) -> void:
    if source==null:return
    var kind=_kind(source)
    if kind.is_empty():return
    var optimized: ShaderMaterial
    if copies.has(source):optimized=copies[source]
    else:
        optimized=make_material(source,{"ground":GROUND,"herbs":HERBS,"triplanar":TRIPLANAR}[kind])
        copies[source]=optimized
    records.append({"node":node,"original":source,"original_override":original_override,"optimized":optimized,"kind":kind,"surface":surface})
    counts[kind]+=1

func set_enabled(value: bool) -> void:
    enabled=value
    for record in records:
        if not is_instance_valid(record.node):continue
        if record.surface>=0:
            record.node.set_surface_override_material(record.surface,record.optimized if value else record.original_override)
        else:record.node.material_override=record.optimized if value else record.original_override

func summary() -> Dictionary:
    return {"enabled":enabled,"receivers":records.size(),"unique_materials":copies.size(),"kinds":counts.duplicate()}
