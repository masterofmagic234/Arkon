extends SceneTree
## Offline compilation of the generated overhead rig atlas. Runtime animates
## the original painted parts; it never recolours, crops or generates artwork.
const BASE := "res://assets/level3/carolina147"
const SOURCE := BASE + "/source/rig-parts.png"
const NAMES := ["head", "torso", "upper_left", "upper_right", "forearm_left", "forearm_right", "leg_left", "leg_right", "cone_pistol", "cone_shotgun", "cone_carbine", "baton", "cone_projectile", "air_puff_0", "air_puff_1", "air_puff_2"]
const SIZES := [Vector2i(16,12), Vector2i(16,20), Vector2i(7,4), Vector2i(7,4), Vector2i(10,4), Vector2i(10,4), Vector2i(9,5), Vector2i(9,5), Vector2i(13,6), Vector2i(17,6), Vector2i(17,5), Vector2i(17,3), Vector2i(6,4), Vector2i(8,6), Vector2i(8,6), Vector2i(8,6)]
const ROWS := [0,420,700,980,1254]
const COLUMNS := [0,320,640,960,1254]
const PALETTE := [Color8(15,17,23),Color8(24,24,30),Color8(34,37,46),Color8(45,48,58),Color8(62,65,75),Color8(85,88,100),Color8(115,116,124),Color8(160,156,150),Color8(211,198,174),Color8(245,229,202),Color8(248,206,175),Color8(225,169,139),Color8(187,123,108),Color8(118,66,65),Color8(52,26,35),Color8(76,27,40),Color8(106,35,48),Color8(147,43,56),Color8(190,57,65),Color8(220,84,78),Color8(26,36,51),Color8(40,52,70),Color8(54,67,84),Color8(73,85,99),Color8(51,59,45),Color8(78,89,63),Color8(107,119,82),Color8(148,153,112),Color8(180,162,123),Color8(226,170,79),Color8(248,207,112),Color8(255,241,189)]
const CONE_PALETTE := [Color8(24,19,18),Color8(38,26,19),Color8(59,36,23),Color8(83,50,29),Color8(112,68,39),Color8(146,92,51),Color8(185,128,72),Color8(220,169,104)]
func _init() -> void: call_deferred("run")
func run() -> void:
    var source := Image.load_from_file(ProjectSettings.globalize_path(SOURCE))
    assert(source != null and source.get_size() == Vector2i(1254,1254), "Reviewed heroine atlas size changed")
    source.convert(Image.FORMAT_RGBA8)
    var manifest := {"source":SOURCE,"source_sha256":FileAccess.get_sha256(SOURCE),"palette_size":PALETTE.size(),"cone_palette_size":CONE_PALETTE.size(),"processing":"Authored cell crop, alpha threshold, aspect-preserving nearest sampling, hero/weapon palette and warm brown projectile palette. No drawing or synthesis.","parts":{}}
    for index in range(NAMES.size()):
        var column := index % 4
        var row := index / 4
        var region := Rect2i(COLUMNS[column],ROWS[row],COLUMNS[column+1]-COLUMNS[column],ROWS[row+1]-ROWS[row])
        var cell := source.get_region(region)
        var bounds := _bounds(cell)
        var image := cell.get_region(bounds)
        var target: Vector2i = SIZES[index]
        var ratio := minf(float(target.x)/image.get_width(),float(target.y)/image.get_height())
        var size_ := Vector2i(maxi(1,roundi(image.get_width()*ratio)),maxi(1,roundi(image.get_height()*ratio)))
        image.resize(size_.x,size_.y,Image.INTERPOLATE_NEAREST)
        var canvas := Image.create_empty(target.x,target.y,false,Image.FORMAT_RGBA8)
        canvas.blit_rect(image,Rect2i(Vector2i.ZERO,size_),Vector2i((target.x-size_.x)/2,(target.y-size_.y)/2))
        _palette(canvas,NAMES[index]=="cone_projectile")
        var path := BASE.path_join(NAMES[index]+".png")
        assert(canvas.save_png(path)==OK,"Hero part output failed")
        manifest.parts[NAMES[index]]={"cell":[region.position.x,region.position.y,region.size.x,region.size.y],"bounds":[bounds.position.x,bounds.position.y,bounds.size.x,bounds.size.y],"size":[target.x,target.y],"sha256":FileAccess.get_sha256(path)}
    var puff := Image.create_empty(24,8,false,Image.FORMAT_RGBA8)
    for index in range(3):
        var image := Image.load_from_file(ProjectSettings.globalize_path(BASE.path_join("air_puff_%d.png"%index)))
        puff.blit_rect(image,Rect2i(Vector2i.ZERO,image.get_size()),Vector2i(index*8,1))
    assert(puff.save_png(BASE.path_join("air_puff_strip3.png"))==OK)
    manifest.puff_sha256=FileAccess.get_sha256(BASE.path_join("air_puff_strip3.png"))
    FileAccess.open(BASE.path_join("source/bake.json"),FileAccess.WRITE).store_string(JSON.stringify(manifest,"  ")+"\n")
    print("CAROLINA RIG ART: PASS — original overhead parts, shared32colour hero/weapon palette, brown cone palette, binary alpha")
    quit()
func _bounds(image: Image) -> Rect2i:
    var low := image.get_size()
    var high := Vector2i(-1,-1)
    for y in range(image.get_height()):
        for x in range(image.get_width()):
            if image.get_pixel(x,y).a < .5: continue
            low.x=mini(low.x,x);low.y=mini(low.y,y)
            high.x=maxi(high.x,x);high.y=maxi(high.y,y)
    assert(high.x>=low.x and high.y>=low.y,"Empty authored part")
    return Rect2i(low,high-low+Vector2i.ONE)
func _palette(image: Image, cone: bool=false) -> void:
    var colours: Array = CONE_PALETTE if cone else PALETTE
    for y in range(image.get_height()):
        for x in range(image.get_width()):
            var color := image.get_pixel(x,y)
            if color.a < .5:
                image.set_pixel(x,y,Color.TRANSPARENT)
                continue
            var nearest: Color=colours[0]
            var distance := INF
            for candidate: Color in colours:
                var next := Vector3(color.r-candidate.r,color.g-candidate.g,color.b-candidate.b).length_squared()
                if next < distance: nearest=candidate;distance=next
            image.set_pixel(x,y,nearest)
