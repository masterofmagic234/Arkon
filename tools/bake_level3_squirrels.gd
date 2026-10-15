extends SceneTree
# Offline cutout rig. Entire animal bodies and limbs replace the human frames.
# Production loads baked strips, one shared sprite per opponent.
const ROOT := "res://assets/level3/squirrels/"
const FRAME := 80
const KINDS := ["gunman","melee","butcher"]
const CLIPS := {"idle":8,"walk":12,"windup":8,"attack":6,"stun":4,"fall":6}
const PALETTE := [Color8(0,0,0),Color8(35,38,47),Color8(63,68,81),Color8(100,105,120),Color8(145,148,160),Color8(191,193,201),Color8(244,241,224),Color8(255,228,191),Color8(188,164,126),Color8(142,91,51),Color8(204,135,45),Color8(244,180,72),Color8(39,91,98),Color8(37,57,76),Color8(174,124,131),Color.WHITE]

func _init() -> void: call_deferred("_run")
func _run() -> void:
    var source := Image.load_from_file(ProjectSettings.globalize_path(ROOT+"source/rig_parts.png"))
    if source==null: _fail("Missing rig parts");return
    source.convert(Image.FORMAT_RGBA8)
    var resting := Image.load_from_file(ProjectSettings.globalize_path(ROOT+"source/rest_heads.png"))
    if resting==null or resting.get_size()!=Vector2i(2172,724): _fail("Missing resting heads");return
    resting.convert(Image.FORMAT_RGBA8)
    var xs := [0,355,590,905,1200,1460,1774]
    var ys := [0,285,550,887]
    if source.get_size()!=Vector2i(1774,887): _fail("Unexpected source dimensions");return
    var manifest := {"source_sha256":FileAccess.get_sha256(ROOT+"source/rig_parts.png"),"resting_sha256":FileAccess.get_sha256(ROOT+"source/rest_heads.png"),"frame_size":FRAME,"parts":[],"strips":[]}
    for role in range(3):
        var sizes: Array=[Vector2i(18,14),Vector2i(13,12),Vector2i(20,25),Vector2i(9,7),Vector2i(8,5),Vector2i(15,5)]
        if role==1: sizes=[Vector2i(18,14),Vector2i(13,12),Vector2i(21,25),Vector2i(10,7),Vector2i(8,5),Vector2i(19,5)]
        if role==2: sizes=[Vector2i(23,18),Vector2i(15,14),Vector2i(23,28),Vector2i(11,8),Vector2i(9,6),Vector2i(14,7)]
        var parts: Array[Image]=[]
        for column in range(6):
            var region := Rect2i(xs[column],ys[role],xs[column+1]-xs[column],ys[role+1]-ys[role])
            parts.append(_part(source.get_region(region),sizes[column]))
            manifest.parts.append({"role":KINDS[role],"part":column,"source_rect":[region.position.x,region.position.y,region.size.x,region.size.y],"native_size":[sizes[column].x,sizes[column].y]})
        parts.append(_part(resting.get_region(Rect2i(role*724,0,724,724)),sizes[1]))
        for clip: String in CLIPS:
            var count: int=CLIPS[clip]
            var atlas := Image.create_empty(FRAME*count,FRAME,false,Image.FORMAT_RGBA8)
            var bounds: Array=[]
            for frame in range(count):
                var loop_: bool=clip in ["idle","walk","stun"]
                var canvas := _pose(parts,role,clip,float(frame)/float(count if loop_ else count-1))
                var used := canvas.get_used_rect()
                if not Rect2i(2,2,FRAME-4,FRAME-4).encloses(used): _fail("Clipped %s %s %s"%[KINDS[role],clip,frame]);return
                atlas.blit_rect(canvas,Rect2i(0,0,FRAME,FRAME),Vector2i(frame*FRAME,0))
                bounds.append([used.position.x,used.position.y,used.size.x,used.size.y])
            var path := ROOT+"%s_%s_strip%d.png"%[KINDS[role],clip,count]
            if atlas.save_png(path)!=OK: _fail("Cannot write "+path);return
            manifest.strips.append({"path":path,"frames":count,"bounds":bounds,"sha256":FileAccess.get_sha256(path)})
        print("SQUIRREL RIG BAKE: ",KINDS[role]," — complete new animal body, 44 poses")
    FileAccess.open(ROOT+"source/rig_manifest.json",FileAccess.WRITE).store_string(JSON.stringify(manifest,"  ")+"\n")
    print("LEVEL3 SQUIRREL RIG BAKE: PASS")
    quit(0)

func _pose(parts: Array[Image], role: int, clip: String, t: float) -> Image:
    var canvas := Image.create_empty(FRAME,FRAME,false,Image.FORMAT_RGBA8)
    var wave := sin(t*TAU)
    var stride := 0.0
    var bounce := 0.0
    var twist := 0.0
    var tail_angle := sin(t*TAU-.8)*.045
    var head_angle := 0.0
    var body_scale := Vector2.ONE
    var body_at := Vector2(40,40)
    var weapon_angle := 0.0 if role==0 else -.48
    var weapon_at := Vector2(8,5) if role<2 else Vector2(10,6)
    var arm_reach := 0.0
    var spread := 1.0
    var fall := 0.0
    if clip=="idle":
        body_scale=Vector2(1.0+wave*.025,1.0-wave*.025)
        head_angle=wave*.025;bounce=roundf(wave*.65)
    elif clip=="walk":
        stride=wave*([2.7,4.0,3.5][role])
        bounce=-absf(wave)*([.75,1.5,1.0][role])
        twist=wave*([.035,.075,.055][role])
        tail_angle=sin(t*TAU-1.1)*([.15,.23,.18][role])
        body_scale=Vector2(1.0+absf(wave)*.025,1.0-absf(wave)*.04)
        if role==2: bounce=roundf(bounce);head_angle=-twist*.6
    elif clip=="windup":
        body_at.x-=t*(1.0 if role==0 else 2.5)
        var pull := minf(1,t/.6)
        var release := clampf((t-.6)/.4,0,1)
        twist=-t*.04 if role==0 else -.22*pull*(1-release*.85)
        head_angle=-twist*.75
        tail_angle=.1+t*.35
        weapon_angle=lerpf(0,-.12,t) if role==0 else (lerpf(-.48,-1.75,pull) if t<=.6 else lerpf(-1.75,-.12,pow(release,1.5)))
        arm_reach=-t*1.5;spread=1.0+t*.25
    elif clip=="attack":
        var impact := sin(t*PI)
        body_at.x+=(-2.0 if role==0 else 2.8)*impact
        twist=(.03 if role==0 else .25)*impact;head_angle=-twist*.5
        tail_angle=-.28*impact
        weapon_angle=-.12*(1-t) if role==0 else (sin(t/.35*PI*.5)*.95 if t<.35 else lerpf(.95,-.48,(t-.35)/.65))
        weapon_at.x+=(-2.0 if role==0 else 3.0)*impact;arm_reach=impact*2.0
    elif clip=="stun":
        twist=wave*.13;head_angle=-wave*.10;tail_angle=wave*.12
        body_scale=Vector2(1.04,.92);weapon_angle=.6+wave*.07;spread=1.3
    elif clip=="fall":
        fall=t;head_angle=-t*.1;tail_angle=-t*.3
        spread=1.0+t*.12;body_scale=Vector2(1.0+t*.08,1.0-t*.10)
        weapon_angle=t*.8;weapon_at+=Vector2(t*4,t*4);body_at+=Vector2(t*2,t*3)
    body_at.y+=roundf(bounce)
    var heavy := role==2
    var hip := -5.0 if not heavy else -6.0
    var width := (6.0 if not heavy else 8.0)*spread
    # Delayed tail sway; alternating rear paw contact and lift.
    var tail := parts[2]
    _stamp(canvas,tail,Vector2(tail.get_width()*.89,tail.get_height()*.83),body_at+Vector2(-7 if not heavy else -9,0),tail_angle+twist*.35,Vector2.ONE)
    for side in [-1,1]:
        var paw := parts[3].duplicate() as Image
        if side==1: paw.flip_y()
        var step: float=stride*side
        var lift := maxf(0.0,sin(t*TAU+(0 if side==1 else PI))) if clip=="walk" else 0.0
        _stamp(canvas,paw,Vector2(3,paw.get_height()/2.0),body_at+Vector2(hip+step,side*(width+lift*.8)),twist+side*(.12+fall*.5),Vector2.ONE)
    var torso := parts[0]
    _stamp(canvas,torso,Vector2(torso.get_width()*.5,torso.get_height()*.5),body_at,twist,body_scale)
    var head := parts[6] if clip=="stun" or (clip=="fall" and t>=.4) else parts[1]
    _stamp(canvas,head,Vector2(head.get_width()*.43,head.get_height()*.5),body_at+Vector2(7 if not heavy else 9,-twist*4),head_angle+twist*.45,Vector2.ONE)
    var hand_at := body_at+weapon_at
    var weapon := parts[5]
    _stamp(canvas,weapon,Vector2(2,weapon.get_height()*.55),hand_at,weapon_angle,Vector2.ONE)
    for side in [-1,1]:
        var paw := parts[4].duplicate() as Image
        if side==1: paw.flip_y()
        var shoulder := body_at+Vector2(3 if not heavy else 5,side*(5 if not heavy else 7))
        var grip := hand_at+Vector2(1 if side==1 else 3,-1 if side==1 else 0).rotated(weapon_angle)
        if role!=0 and clip=="walk": shoulder.x-=stride*side*.2
        _stamp(canvas,paw,Vector2(1,paw.get_height()*.5),shoulder+Vector2(arm_reach,0),shoulder.direction_to(grip).angle()+fall*side*.3,Vector2.ONE)
    if fall>0:
        var tilted := Image.create_empty(FRAME,FRAME,false,Image.FORMAT_RGBA8)
        _stamp(tilted,canvas,Vector2(40,40),Vector2(40,40),fall*.72,Vector2.ONE)
        return tilted
    return canvas

func _part(image: Image, size_: Vector2i) -> Image:
    for y in range(image.get_height()):
        for x in range(image.get_width()):
            var color := image.get_pixel(x,y)
            if color.a<.5: image.set_pixel(x,y,Color.TRANSPARENT)
            else: color.a=1;image.set_pixel(x,y,color)
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

func _stamp(canvas: Image, part: Image, pivot: Vector2, at: Vector2, angle: float, scale_: Vector2) -> void:
    var transform_ := Transform2D(angle,scale_,0,at)
    transform_.origin-=transform_.basis_xform(pivot)
    var inverse := transform_.affine_inverse()
    var box := transform_*Rect2(Vector2.ZERO,Vector2(part.get_size()))
    for y in range(maxi(0,floori(box.position.y)),mini(FRAME,ceili(box.end.y))):
        for x in range(maxi(0,floori(box.position.x)),mini(FRAME,ceili(box.end.x))):
            var from := Vector2i((inverse*Vector2(x+.5,y+.5)).floor())
            if from.x<0 or from.y<0 or from.x>=part.get_width() or from.y>=part.get_height(): continue
            var color := part.get_pixelv(from)
            if color.a>.5: canvas.set_pixel(x,y,color)
func _fail(message: String) -> void:
    push_error("SQUIRREL RIG BAKE: "+message)
    quit(1)
