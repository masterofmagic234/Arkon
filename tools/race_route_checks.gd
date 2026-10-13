extends RefCounted
const Data=preload("res://scripts/race_level_data.gd")
const Math=preload("res://scripts/race_math.gd")

static func run(level) -> String:
    var player=level.controller.player
    var renderer=level.renderer
    var pattern: Array=level.controller.track_pattern
    var bends := 0
    var i := 0
    while i<pattern.size():
        var j := i+1
        while j<pattern.size() and pattern[j]==pattern[i]: j+=1
        if pattern[i] in [1,2,3,4]:
            bends+=1
            var peak := 0.0
            for k in range(i*8,j*8):
                peak=maxf(peak,absf(atan2(Math.track_center_slope(float(k)/8,level.controller.track_x),40)))
            if peak<.30: return "A map bend is stretched into an almost straight lane shift"
            _place(player,maxf(0,(i-1)*40),level)
            player.heading_yaw=0;level.camera_state.reset(player)
            renderer.road_mesh.update(renderer,Vector2(1280,720))
            var arrays: Array=renderer.road_mesh.road.surface_get_arrays(0)
            var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
            var uv: PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
            var bow := 0.0
            for row in range(vertices.size()/2):
                var depth := 1.0/uv[row*2].y
                if depth<50 or depth>180: continue
                var center := (vertices[row*2].x+vertices[row*2+1].x)*.5
                var half := absf(vertices[row*2+1].x-vertices[row*2].x)*.5
                bow=maxf(bow,absf(center-640)/maxf(half,.001))
            if bow<1.8: return "The actual projected road remains straight at a marked bend"
        i=j
    if bends<20: return "The sprint still has too few physical bends"
    print("RACE ROUTE: PASS — %d physical bends with visible road deflection and braking geometry"%bends)
    return ""

static func _place(player,z: float,level) -> void:
    var canonical: float=(z+player.grid_world_z_offset)/40
    player.segment_index=floori(canonical);player.segment_progress=canonical-player.segment_index
    player.world_z=z;player.lateral_offset=0
    player.world_x=Math.track_center_x(z/40,level.controller.track_x)
