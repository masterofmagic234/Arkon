extends SceneTree
# Offline sprite preparation. ImageGen supplies the new anatomy; the original
# authored clothing, weapons and eight poses are retained by the asset bake.
# Only the final strips are consumed by the game: still one sprite per actor.
const OUTPUT := "res://assets/level3/squirrels/"
const SOURCE := "res://assets/level3/source/"
const FRAME := 80
const PALETTE := [Color8(0,0,0),Color8(48,48,58),Color8(76,80,90),Color8(110,115,125),Color8(150,154,161),Color8(196,198,201),Color8(255,228,191),Color8(170,120,125),Color.WHITE]
const WALK := [
    {"name":"gunman","source":"Combat/Enemy/sprEWalkSilencer_strip8.png","head":Vector2i(12,12),"head_box":Rect2i(5,5,15,14),"tail_root":Vector2i(6,16),"up":false},
    {"name":"melee","source":"Combat/Enemy/sprEWalkBat_strip8.png","head":Vector2i(12,11),"head_box":Rect2i(4,3,16,16),"tail_root":Vector2i(12,25),"up":true},
    {"name":"butcher","source":"Player/sprPigButcher_strip8.png","head":Vector2i(16,9),"head_box":Rect2i(8,3,16,13),"tail_root":Vector2i(16,25),"up":true},
]

func _init() -> void: call_deferred("_run")

func _run() -> void:
    var source := Image.load_from_file(OUTPUT+"source/anatomy.png")
    if source==null or source.is_empty(): _fail("Missing generated anatomy");return
    source.convert(Image.FORMAT_RGBA8)
    var half := source.get_size()/2
    var head := _part(source.get_region(Rect2i(Vector2i.ZERO,half)),Vector2i(13,13))
    var tail := _part(source.get_region(Rect2i(Vector2i(half.x,0),half)),Vector2i(18,24))
    var resting_head := _part(source.get_region(Rect2i(Vector2i(0,half.y),half)),Vector2i(13,13))
    var resting_tail := _part(source.get_region(Rect2i(half,half)),Vector2i(25,14))
    var manifest := {"anatomy_sha256":FileAccess.get_sha256(OUTPUT+"source/anatomy.png"),"frame_size":FRAME,"strips":[]}
    for spec in WALK:
        var original := Image.load_from_file(SOURCE+spec.source)
        original.convert(Image.FORMAT_RGBA8)
        var size_ := Vector2i(original.get_width()/8,original.get_height())
        var padding := (Vector2i.ONE*FRAME-size_)/2
        var atlas := Image.create_empty(FRAME*8,FRAME,false,Image.FORMAT_RGBA8)
        var face := head.duplicate() as Image
        var plume := tail.duplicate() as Image
        var root := Vector2i(16,22)
        if spec.up:
            face.rotate_90(COUNTERCLOCKWISE)
            plume.rotate_90(COUNTERCLOCKWISE)
            root=Vector2i(22,1)
        var bounds: Array=[]
        for frame in range(8):
            var body := original.get_region(Rect2i(Vector2i(frame*size_.x,0),size_))
            var center := _head_center(body,spec.head_box,spec.head)
            var bob := center-Vector2i(spec.head)
            var canvas := Image.create_empty(FRAME,FRAME,false,Image.FORMAT_RGBA8)
            var swing: int = [0,-1,-1,0,0,1,1,0][frame]
            var tail_at: Vector2i=padding+Vector2i(spec.tail_root)-root+bob+(Vector2i(swing,0) if spec.up else Vector2i(0,swing))
            canvas.blend_rect(plume,Rect2i(Vector2i.ZERO,plume.get_size()),tail_at)
            canvas.blend_rect(body,Rect2i(Vector2i.ZERO,size_),padding)
            canvas.blend_rect(face,Rect2i(Vector2i.ZERO,face.get_size()),padding+center-Vector2i(6,6))
            var used := canvas.get_used_rect()
            if not Rect2i(2,2,FRAME-4,FRAME-4).encloses(used): _fail("Clipped walk frame: "+spec.name);return
            atlas.blit_rect(canvas,Rect2i(Vector2i.ZERO,canvas.get_size()),Vector2i(frame*FRAME,0))
            bounds.append([used.position.x,used.position.y,used.size.x,used.size.y])
        var path: String = OUTPUT+"walk_"+spec.name+"_strip8.png"
        if atlas.save_png(path)!=OK: _fail("Cannot save "+path);return
        manifest.strips.append({"path":path,"frames":8,"original":spec.source,"source_sha256":FileAccess.get_sha256(SOURCE+spec.source),"bounds":bounds,"output_sha256":FileAccess.get_sha256(path)})
        print("SQUIRRELS BAKE: ",spec.name," — eight original poses, padded 80px frame")
    var dead := Image.load_from_file(SOURCE+"Combat/Enemy/sprEDeadFrontPool_strip2.png")
    dead.convert(Image.FORMAT_RGBA8)
    var corpse_size := Vector2i(dead.get_width()/2,dead.get_height())
    var corpse_padding := (Vector2i.ONE*FRAME-corpse_size)/2
    var dead_atlas := Image.create_empty(FRAME*2,FRAME,false,Image.FORMAT_RGBA8)
    for frame in range(2):
        var canvas := Image.create_empty(FRAME,FRAME,false,Image.FORMAT_RGBA8)
        canvas.blend_rect(resting_tail,Rect2i(Vector2i.ZERO,resting_tail.get_size()),corpse_padding+Vector2i(23,31)-Vector2i(23,7))
        canvas.blend_rect(dead,Rect2i(Vector2i(frame*corpse_size.x,0),corpse_size),corpse_padding)
        canvas.blend_rect(resting_head,Rect2i(Vector2i.ZERO,resting_head.get_size()),corpse_padding+Vector2i(54,29)-Vector2i(6,6))
        if not Rect2i(2,2,FRAME-4,FRAME-4).encloses(canvas.get_used_rect()): _fail("Clipped resting pose");return
        dead_atlas.blit_rect(canvas,Rect2i(0,0,FRAME,FRAME),Vector2i(frame*FRAME,0))
    var dead_path := OUTPUT+"resting_strip2.png"
    if dead_atlas.save_png(dead_path)!=OK: _fail("Cannot save resting poses");return
    manifest.strips.append({"path":dead_path,"frames":2,"output_sha256":FileAccess.get_sha256(dead_path)})
    FileAccess.open(OUTPUT+"source/bake_manifest.json",FileAccess.WRITE).store_string(JSON.stringify(manifest,"  ")+"\n")
    print("LEVEL3 SQUIRRELS BAKE: PASS")
    quit(0)

func _part(image: Image, size_: Vector2i) -> Image:
    # Hard alpha and a small palette match the existing 1px-outline sprites.
    # This is format conversion of generated anatomy, not redrawn source art.
    for y in range(image.get_height()):
        for x in range(image.get_width()):
            var color := image.get_pixel(x,y)
            if color.a<.5: image.set_pixel(x,y,Color.TRANSPARENT)
            else: color.a=1.0;image.set_pixel(x,y,color)
    image=image.get_region(image.get_used_rect())
    image.resize(size_.x,size_.y,Image.INTERPOLATE_NEAREST)
    for y in range(size_.y):
        for x in range(size_.x):
            var color := image.get_pixel(x,y)
            if color.a==0: continue
            var nearest: Color=PALETTE[0]
            var distance_ := INF
            for candidate: Color in PALETTE:
                var d := Vector3(color.r-candidate.r,color.g-candidate.g,color.b-candidate.b).length_squared()
                if d<distance_: nearest=candidate;distance_=d
            image.set_pixel(x,y,nearest)
    return image

func _head_center(image: Image, region: Rect2i, fallback: Vector2i) -> Vector2i:
    var total := Vector2.ZERO
    var count := 0
    for y in range(region.position.y,region.end.y):
        for x in range(region.position.x,region.end.x):
            var color := image.get_pixel(x,y)
            if color.a>.5 and color.r>.7 and color.g>.4 and color.r>color.g*1.05 and color.g>color.b*1.05:
                total+=Vector2(x,y);count+=1
    if count==0: return fallback
    return Vector2i((total/count).round())

func _fail(message: String) -> void:
    push_error("LEVEL3 SQUIRRELS BAKE: "+message)
    quit(1)
