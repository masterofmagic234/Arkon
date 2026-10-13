extends SceneTree
# Offline asset preparation. The supplied canopy's projections are baked once;
# a neutral periodic aggregate avoids painted lighting bands on moving asphalt.
func _init() -> void: call_deferred("_run")
func _sample(image: Image, uv: Vector2) -> Color:
    var p := Vector2(fposmod(uv.x,1.0)*image.get_width(),fposmod(uv.y,1.0)*image.get_height())
    var x := floori(p.x);var y := floori(p.y)
    var a := image.get_pixel(x%image.get_width(),y%image.get_height()).srgb_to_linear()
    var b := image.get_pixel((x+1)%image.get_width(),y%image.get_height()).srgb_to_linear()
    var c := image.get_pixel(x%image.get_width(),(y+1)%image.get_height()).srgb_to_linear()
    var d := image.get_pixel((x+1)%image.get_width(),(y+1)%image.get_height()).srgb_to_linear()
    return a.lerp(b,p.x-x).lerp(c.lerp(d,p.x-x),p.y-y)
func _run() -> void:
    var source := Image.load_from_file("res://assets/level1/textures/park_oak_canopy.jpg")
    var atlas := Image.create(512,512,false,Image.FORMAT_RGB8)
    for y in range(512):
        for x in range(512):
            var a := (x+.5)/512.0*TAU;var b := (y+.5)/512.0*PI
            var n := Vector3(sin(b)*cos(a),cos(b),sin(b)*sin(a))
            var lobe := 1.0+.13*sin(a*3.0+b*1.7)*sin(b)+.085*cos(a*5.0-b*3.0)*sin(b)
            var p := n*.5*lobe*3.4/1.25
            var weights := Vector3(pow(absf(n.x),4),pow(absf(n.y),4),pow(absf(n.z),4))
            weights/=weights.x+weights.y+weights.z
            var color := _sample(source,Vector2(p.z,p.y))*weights.x+_sample(source,Vector2(p.x,p.z))*weights.y+_sample(source,Vector2(p.x,p.y))*weights.z
            color.a=1;atlas.set_pixel(x,y,color.linear_to_srgb())
    assert(atlas.save_png("res://assets/level1/textures/park_oak_canopy_baked.png")==OK)
    var noise := FastNoiseLite.new()
    noise.seed=241012;noise.frequency=.42;noise.fractal_octaves=2
    var field := NoiseTexture2D.new()
    field.width=512;field.height=512;field.seamless=true;field.seamless_blend_skirt=.15;field.noise=noise
    if field.get_image()==null: await field.changed
    var grain := field.get_image()
    var road := Image.create(512,512,false,Image.FORMAT_RGB8)
    for y in range(512):
        for x in range(512): road.set_pixel(x,y,Color(.39,.405,.42)*(.84+grain.get_pixel(x,y).r*.30))
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/level2"))
    assert(road.save_png("res://assets/level2/asphalt_aggregate.png")==OK)
    print("POLISH MATERIAL BAKE: PASS — blended supplied canopy; periodic neutral asphalt; deterministic seeds")
    quit(0)
