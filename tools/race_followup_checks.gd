extends RefCounted
const Data=preload("res://scripts/race_level_data.gd")
const Math=preload("res://scripts/race_math.gd")
const SkyLayout=preload("res://scripts/race_sky_layout.gd")

static func run(level) -> String:
    var player=level.controller.player
    var renderer=level.renderer
    var route_failure := preload("res://tools/race_route_checks.gd").run(level)
    if not route_failure.is_empty(): return route_failure
    for size_: Vector2 in [Vector2(960,540),Vector2(1280,720),Vector2(1600,720)]:
        var previous := Vector2.ZERO
        for z in range(int(Data.TUNNEL_END-180),int(Data.TUNNEL_END+290),5):
            var horizon := size_.y*(496.0/720.0)*.5+806.4*Data.road_grade(z)
            var rect := SkyLayout.city_rect(size_,horizon,renderer.city_texture.get_size(),1)
            if previous!=Vector2.ZERO and rect.size.distance_to(previous)>.01:
                return "The city stretches during the first seconds after the tunnel"
            if absf(rect.size.x/rect.size.y-renderer.city_texture.get_size().aspect())>.001:
                return "City panorama aspect ratio is distorted"
            previous=rect.size
    var started: bool=level.state.race_started;level.state.race_started=true
    for sector in range(1,Data.SECTOR_STARTS.size()):
        var visible := 0.0
        var start: float=Data.SECTOR_STARTS[sector]-330
        for tick in range(430):
            player.world_z=start+tick*Data.PLAYER_MAX_SPEED/60
            level.presentation._process(1.0/60)
            if level.presentation.sign_notice_panel.visible:
                visible+=1.0/60
                if not level.presentation.sign_notice.text.contains(preload("res://scripts/race_location_signs.gd").NAMES[sector]):
                    return "The high-speed location notice shows the wrong name"
        if visible<4.5: return "The name disappears before a high-speed driver can read it"
    level.state.race_started=started
    if level.presentation.sign_notice_panel.mouse_filter!=Control.MOUSE_FILTER_IGNORE:
        return "The location notice steals touch steering input"
    if Data.road_height(Data.TUNNEL_START)+Data.TUNNEL_RADIUS>=Data.terrain_height(Data.TUNNEL_START):
        return "The tunnel roof is not underground"
    for size_: Vector2 in [Vector2(960,540),Vector2(1280,720),Vector2(1600,720)]:
        var moon := SkyLayout.moon_rect(size_,size_.x*.73)
        if moon.end.y>size_.y*.08: return "The moon is low enough to cover the skyline"
    if Data.SECTOR_NAMES.size()!=7 or Data.SECTOR_NAMES[5]!="ОКРАИНЫ ГОРОДА": return "The city outskirts sector is missing"
    print("RACE FOLLOWUP: PASS — stable city; raised moon; underground forest tunnel; seven readable sectors")
    return ""

static func _place(player,z: float,level) -> void:
    var canonical: float=(z+player.grid_world_z_offset)/40
    player.segment_index=floori(canonical);player.segment_progress=canonical-player.segment_index
    player.world_z=z;player.lateral_offset=0
    player.world_x=Math.track_center_x(z/40,level.controller.track_x)
