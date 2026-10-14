extends RefCounted
# Flat forest earth over a genuinely depressed tunnel; no distant mountain.
const Data=preload("res://scripts/race_level_data.gd")
const Batch=preload("res://scripts/race_canvas_batch.gd")
var batch=Batch.new()
var models: Array=[]
var triangles := 0
var transformed_vertices := 0
func setup(host) -> void:
    # Earth is behind the far tunnel lining, which hides it through the hole.
    batch.setup(host,"ForestTunnelCover",host.grass_texture,-4)
    batch.node.material=host.road_mesh.verge_material
func bind(host) -> void:
    models.clear()
    for z in range(int(Data.TUNNEL_START),int(Data.TUNNEL_END),40):
        var points := PackedVector3Array()
        for dz: float in [0,40]:
            var at := float(z)+dz
            var c: float=host._smooth_track_x(at/40)
            for x: float in [-Data.CUT_WALL_X,Data.CUT_WALL_X]: points.append(Vector3(c+x,Data.terrain_height(at),at))
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
                uv.append(Vector2(2,1.0/p.z))
            triangles+=maxi(0,points.size()-2)
            batch.polygon(points,Color.WHITE,uv)
    batch.commit()
