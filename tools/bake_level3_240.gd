extends SceneTree
## Offline sprite preparation from ImageGen's two deliberately separate parts.
## No 3D, AI generation, image synthesis or pixel work occurs in game runtime.
const SOURCE := "res://assets/level3/vehicles/source/240-parts.png"
const BODY_OUT := "res://assets/level3/vehicles/player_240_body.png"
const DOOR_OUT := "res://assets/level3/vehicles/player_240_door.png"
const PALETTE := [Color8(0,0,0),Color8(11,13,16),Color8(20,23,27),Color8(31,35,42),Color8(45,49,58),Color8(65,71,82),Color8(89,99,112),Color8(124,134,145),Color8(172,180,184),Color8(215,220,212),Color8(251,245,214),Color8(255,225,153),Color8(194,126,34),Color8(78,19,25),Color8(138,27,37),Color8(213,36,48),Color8(255,70,80),Color8(32,80,75),Color8(29,117,103),Color8(25,157,132),Color8(16,194,157),Color8(16,222,175),Color8(45,241,195),Color8(92,249,213),Color8(152,255,231),Color8(225,255,241)]
func _init() -> void:call_deferred("_run")
func _run() -> void:
    var source := Image.load_from_file(ProjectSettings.globalize_path(SOURCE))
    assert(source != null and source.get_size()==Vector2i(1888,833),"Reviewed two-part240 source changed")
    source.convert(Image.FORMAT_RGBA8)
    var body := source.get_region(Rect2i(390,151,1103,438))
    body.resize(107,42,Image.INTERPOLATE_NEAREST)
    body=_pixels(body)
    var canvas := Image.create_empty(107,70,false,Image.FORMAT_RGBA8)
    canvas.blit_rect(body,Rect2i(Vector2i.ZERO,body.get_size()),Vector2i(0,14))
    var door := source.get_region(Rect2i(788,642,339,124))
    door.resize(33,12,Image.INTERPOLATE_NEAREST)
    door=_pixels(door)
    assert(canvas.save_png(BODY_OUT)==OK and door.save_png(DOOR_OUT)==OK,"240 sprite output failed")
    var manifest := {"source":SOURCE,"source_sha256":FileAccess.get_sha256(SOURCE),"source_size":[1888,833],"body_source_rect":[390,151,1103,438],"door_source_rect":[788,642,339,124],"body_canvas":[107,70],"body_image_size":[107,42],"door_image_size":[33,12],"heading":"right (+X)","driver_side":"north (-Y)","door_hinge":[13,-16],"boarding_socket":[-9,-34],"door_pivot_in_texture":[32,5],"palette_colors":PALETTE.size(),"alpha":"binary","filter":"nearest","body_sha256":FileAccess.get_sha256(BODY_OUT),"door_sha256":FileAccess.get_sha256(DOOR_OUT)}
    FileAccess.open("res://assets/level3/vehicles/source/240-bake.json",FileAccess.WRITE).store_string(JSON.stringify(manifest,"  ")+"\n")
    print("LEVEL3 240 BAKE: PASS —107x70 top-down palette sprite, separate33x12 driverdoor")
    quit()
func _pixels(image: Image) -> Image:
    for y in range(image.get_height()):
        for x in range(image.get_width()):
            var color := image.get_pixel(x,y)
            if color.a<.5:
                image.set_pixel(x,y,Color.TRANSPARENT)
                continue
            var best: Color=PALETTE[0];var distance_:=INF
            for candidate: Color in PALETTE:
                var delta := Vector3(color.r-candidate.r,color.g-candidate.g,color.b-candidate.b).length_squared()
                if delta<distance_:best=candidate;distance_=delta
            image.set_pixel(x,y,best)
    return image
