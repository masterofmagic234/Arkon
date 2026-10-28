extends SceneTree
## Offline irradiance re-lighting. Must run with a real GL/Vulkan renderer:
## the Dummy renderer discards LightmapGI probe arrays when reading them.
const OUTPUT="res://assets/level1/botanical/lighting/garden_evening.lmbake"
const TINT=Color(.13,.19,.32)
func _init() -> void:call_deferred("run")
func run() -> void:
    if DisplayServer.get_name()=="headless":push_error("EVENING BAKE: a native rendering server is required");quit(1);return
    var source=load("res://assets/level1/botanical/lighting/garden.scn").instantiate()
    var original: LightmapGIData=source.get_node("BakedGI").light_data
    var result=LightmapGIData.new()
    var textures: Array[TextureLayered]=[]
    for texture in original.get_lightmap_textures():
        var images: Array[Image]=[]
        for layer in range(texture.get_layers()):
            var image: Image=texture.get_layer_data(layer);image.convert(Image.FORMAT_RGBF)
            var values=image.get_data().to_float32_array()
            for i in range(0,values.size(),3):values[i]*=TINT.r;values[i+1]*=TINT.g;values[i+2]*=TINT.b
            var relit=Image.create_from_data(image.get_width(),image.get_height(),false,Image.FORMAT_RGBF,values.to_byte_array());relit.convert(Image.FORMAT_RGBH);images.append(relit)
        var array=Texture2DArray.new();array.create_from_images(images);textures.append(array)
    result.set_lightmap_textures(textures)
    result.uses_spherical_harmonics=original.uses_spherical_harmonics
    result.set("user_data",original.get("user_data").duplicate(true))
    var probes: Dictionary=original.get("probe_data").duplicate(true)
    var sh: PackedColorArray=probes.sh
    for i in range(sh.size()):sh[i]=Color(sh[i].r*TINT.r,sh[i].g*TINT.g,sh[i].b*TINT.b,sh[i].a)
    probes.sh=sh;result.set("probe_data",probes)
    var error=ResourceSaver.save(result,OUTPUT,ResourceSaver.FLAG_COMPRESS)
    if error!=OK:push_error("EVENING BAKE: save failed");source.free();quit(1);return
    var report={"tool":"tools/prepare_botanical_evening.gd","tool_sha256":FileAccess.get_sha256("res://tools/prepare_botanical_evening.gd"),"source":"assets/level1/botanical/lighting/garden.lmbake","output":OUTPUT.trim_prefix("res://"),"source_sha256":FileAccess.get_sha256("res://assets/level1/botanical/lighting/garden.lmbake"),"output_sha256":FileAccess.get_sha256(OUTPUT),"operation":"Linear irradiance re-lighting of baked indirect sky light and all SH coefficients; receiver UV2, geometry, occlusion and probe positions remain intact. Moon direct light and local lamps are authored separately.","rgb_irradiance_multiplier":[TINT.r,TINT.g,TINT.b],"textures":textures.size(),"layers":textures[0].get_layers(),"probes":probes.points.size(),"sh_coefficients":sh.size(),"receivers":result.get_user_count(),"runtime_processing":false}
    FileAccess.open("res://assets/level1/botanical/lighting/evening-provenance.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("EVENING BAKE: PASS — ",report)
    source.free();result=null;original=null
    await process_frame;quit(0)
