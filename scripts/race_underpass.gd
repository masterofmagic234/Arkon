extends RefCounted
# Flat forest earth over a genuinely depressed tunnel; no distant mountain.
const Data=preload("res://scripts/race_level_data.gd")
const Batch=preload("res://scripts/race_canvas_batch.gd")
var batch=Batch.new()
var models: Array=[]
var triangles := 0
var transformed_vertices := 0
func setup(host) -> void:
    batch.setup(host,"ForestTunnelCover",host.grass_texture,-3)
func bind(host) -> void:
    models.clear()
    for z: float in [Data.TUNNEL_START,Data.TUNNEL_END]:
        var points := PackedVector3Array()
        var center: float=host._smooth_track_x(z/40)
        for dz: float in [0,90]:
            var at := z+dz if z==Data.TUNNEL_START else z-dz
            var c: float=host._smooth_track_x(at/40)
            for x: float in [-100,100]: points.append(Vector3(c+x,0,at))
        models.append({"z":z,"points":points,"faces":[PackedInt32Array([0,1,3]),PackedInt32Array([0,3,2])]})
func draw(host,frame,vp: Vector2) -> void:
    batch.begin();triangles=0;transformed_vertices=0
    var origin: float=host.player_car.world_z
    if origin>=Data.TUNNEL_START and origin<Data.TUNNEL_END: batch.commit();return
    for model in models:
        if absf(float(model.z)-origin)>800: continue
        transformed_vertices+=model.points.size()
        for face in model.faces:
            var camera: Array[Vector3]=[]
            for id in face: camera.append(frame.transform*model.points[id])
            var points := PackedVector2Array();var uv := PackedVector2Array()
            for p in frame.clip(camera,true):
                points.append(frame.project(p))
                var world: Vector3=frame.inverse*p;uv.append(Vector2(world.x,world.z)/3)
            triangles+=maxi(0,points.size()-2)
            batch.polygon(points,Color("365747"),uv)
    batch.commit()
