extends RefCounted
# One art direction for the entire park: ink, lagoon, cream and lantern amber.
const COLORS := {"bark":"66534e","hedge":"3f6c68","leaf":"5d8c7c","leaf_light":"7da391","gold_leaf":"d3ad79","stone":"c7c4ac","stone_dark":"42646d","wood":"a48565","iron":"213f49","brass":"c9ab79","lamp":"ffe0a1","acorn":"dca666","key":"efc987","moon":"e4e9d5","lamp_moon":"add8c2","lamp_gallery":"d5bba5","shadow":"2b4b4d"}
const FOG := Color("1a3448")
const WALL_HEIGHT := 2.05
static func flat(color: Color) -> ShaderMaterial:
    var m:=ShaderMaterial.new();m.shader=preload("res://shaders/level1_cozy_solid.gdshader");m.set_shader_parameter("tint",color);return m
static func materials(host) -> void:
    for id in COLORS:
        var energy:=1.1 if id in ["lamp","lamp_moon","lamp_gallery","moon"] else (.15 if id in ["key","acorn"] else 0.0)
        host.materials[id]=host._material(Color(COLORS[id]),energy)
    for id in ["leaf","leaf_light","gold_leaf","hedge"]:
        host.materials[id]=flat(Color(COLORS[id]));host.materials[id].set_shader_parameter("sway",.008)
    for i in range(5):host.materials["wall_%d"%i]=flat(Color("6c9090") if i==4 else Color("54787b"))
    host.materials.outer_wall=flat(Color("608387"))
    host.materials.outer_wall_cap=flat(Color("d6ceb3"))
    host.materials.boundary=ShaderMaterial.new();host.materials.boundary.shader=preload("res://shaders/level1_cozy_wall.gdshader")
    host.materials.boundary.set_shader_parameter("tint",Color("577e7e"));host.materials.boundary.set_shader_parameter("coping",Color("d6ceb3"))
