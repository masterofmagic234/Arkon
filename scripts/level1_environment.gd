extends Node3D
class_name Level1Environment

const LevelData = preload("res://scripts/level_data.gd")

const WALL_TEXTURE_PATHS := [
    "res://wall_zone1.png",
    "res://wall_zone2.png",
    "res://wall_zone3.png",
    "res://wall_zone4.png",
]
const FLOOR_TEXTURE_PATHS := [
    "res://floor_zone_1(1).jpg",
    "res://floor_zone_2(1).jpg",
    "res://floor_zone_3(1).jpg",
    "res://floor_zone_4(1).jpg",
]
const FLOOR_UV_SCALE := Vector3(0.22, 0.22, 0.22)
const FLOOR_ALBEDO_TINT := Color(0.82, 0.88, 0.98, 1.0)
const FOG_COLOR := Color(0.12, 0.17, 0.25, 1.0)
const CAMERA_FAR := 45.0
const ZONE_COUNT := 4
const HERO_GRASS_PATH := "res://assets/floor_grass_hero.png"
const HERO_GRASS_SHADER := "res://scripts/hero_grass_fade.gdshader"
const WALL_SHADER_PATH := "res://shaders/level1_wall_night.gdshader"
const HERO_GRASS_SPOTS := [
    Vector3(-43.2, 0.02, -7.2),
    Vector3(-34.2, 0.02, -2.7),
    Vector3(-24.3, 0.02, 5.4),
    Vector3(-10.8, 0.02, -8.1),
    Vector3(-1.8, 0.02, 7.2),
    Vector3(9.0, 0.02, 2.7),
    Vector3(21.6, 0.02, -5.4),
    Vector3(32.4, 0.02, 7.2),
    Vector3(43.2, 0.02, -7.2),
    Vector3(50.4, 0.02, 5.4),
]

func _ready() -> void:
    call_deferred("_setup")

func _setup() -> void:
    _prepare_environment_materials()
    _build_mobile_wall_visuals()
    _setup_atmosphere()
    _spawn_leaves()
    _build_hero_grass_spots()
    _setup_mobile_visibility()

func _prepare_environment_materials() -> void:
    var layout := get_parent().get_node_or_null("Level1Layout") as Node3D
    if layout == null:
        return

    _build_floor_zones(layout)
    _prepare_billboard_edge_materials(layout)

    # Reuse one material per zone texture instead of duplicating a
    # StandardMaterial3D for every wall segment. Each wall uses the same
    # spatial zone index as the floor, so Level 1 reads as four coherent areas.
    var wall_materials: Dictionary = {}
    var walls_root := layout.get_node_or_null("Walls") as Node3D
    if walls_root == null:
        return

    for child in walls_root.get_children():
        if not (child is StaticBody3D) or not child.name.begins_with("MapWall_"):
            continue

        var mesh_instance := child.get_node_or_null("Mesh") as MeshInstance3D
        if mesh_instance == null or mesh_instance.mesh == null:
            continue

        var zone_index := _zone_index_for_world_x(child.position.x)
        var texture_path: String = WALL_TEXTURE_PATHS[zone_index]
        var wall_material: ShaderMaterial = wall_materials.get(texture_path) as ShaderMaterial

        if wall_material == null:
            var wall_texture := load(texture_path) as Texture2D
            if wall_texture == null:
                continue
            wall_material = _make_wall_material(wall_texture)
            wall_materials[texture_path] = wall_material

        mesh_instance.material_override = wall_material
        mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _zone_index_for_world_x(world_x: float) -> int:
    var map_left := LevelData.MAP_WORLD_ORIGIN.x
    var map_right := map_left + float(LevelData.MAP_WIDTH) * LevelData.CELL_SIZE
    var zone_width := maxf((map_right - map_left) / float(ZONE_COUNT), 0.001)
    return clampi(
        int(floor((world_x - map_left) / zone_width)),
        0,
        ZONE_COUNT - 1
    )

func _make_wall_material(texture: Texture2D) -> ShaderMaterial:
    var shader := load(WALL_SHADER_PATH) as Shader
    if shader == null:
        push_error("[Walls] Missing wall shader: %s" % WALL_SHADER_PATH)
        return null

    var material := ShaderMaterial.new()
    material.shader = shader
    material.set_shader_parameter("albedo_tex", texture)
    material.set_shader_parameter("triplanar_scale", Vector3(0.4, 0.4, 0.4))
    material.set_shader_parameter("emission_tint", Vector3(0.72, 0.80, 1.0))
    material.set_shader_parameter("emission_energy", 1.15)
    material.set_shader_parameter("ao_strength", 0.58)
    material.set_shader_parameter("ao_height", 0.72)
    return material

func _build_floor_zones(layout: Node3D) -> void:
    var floor_root := layout.get_node_or_null("Floor") as Node3D
    var source_ground := layout.get_node_or_null("Floor/Ground") as MeshInstance3D
    if floor_root == null or source_ground == null or source_ground.mesh == null:
        push_warning("[Ground] Level 1 floor source mesh is missing.")
        return

    var source_mesh := source_ground.mesh as PlaneMesh
    if source_mesh == null:
        push_warning("[Ground] Level 1 floor source mesh is not a PlaneMesh.")
        return

    var old_zones := floor_root.get_node_or_null("ZoneGrounds")
    if old_zones != null:
        old_zones.queue_free()

    source_ground.visible = false

    var zones_root := Node3D.new()
    zones_root.name = "ZoneGrounds"
    floor_root.add_child(zones_root)

    var map_width_world := float(LevelData.MAP_WIDTH) * LevelData.CELL_SIZE
    var zone_width := map_width_world / float(ZONE_COUNT)
    var floor_depth := source_mesh.size.y

    for zone_index in range(ZONE_COUNT):
        var material := StandardMaterial3D.new()
        var floor_texture := load(FLOOR_TEXTURE_PATHS[zone_index]) as Texture2D
        if floor_texture == null:
            push_error("[Ground] Missing Level 1 floor texture: %s" % FLOOR_TEXTURE_PATHS[zone_index])
            continue

        material.albedo_texture = floor_texture
        material.albedo_color = FLOOR_ALBEDO_TINT

        # The new zone textures are 2K, so keep their authored detail large
        # enough to read across each 25.2 m zone without a dense repetition.
        material.uv1_triplanar = true
        material.uv1_world_triplanar = true
        material.uv1_scale = FLOOR_UV_SCALE
        material.uv1_offset = Vector3.ZERO
        material.texture_repeat = true
        material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC

        # The authored bright moon/puddle accents also contribute a restrained
        # emissive layer so the global glow processor can pick them up.
        material.emission_enabled = true
        material.emission_texture = floor_texture
        material.emission = Color(0.42, 0.52, 0.72, 1.0)
        material.emission_energy_multiplier = 0.62

        # Preserve the established Level 1 night presentation. The floor image
        # itself supplies all visible detail; do not multiply it with a green tint.
        material.roughness = 1.0
        material.metallic = 0.0
        material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

        var zone_mesh := source_mesh.duplicate() as PlaneMesh
        zone_mesh.size = Vector2(zone_width, floor_depth)
        zone_mesh.material = material

        var zone_node := MeshInstance3D.new()
        zone_node.name = "Zone_%d" % (zone_index + 1)
        zone_node.mesh = zone_mesh
        zone_node.position = Vector3(
            LevelData.MAP_WORLD_ORIGIN.x
                + zone_width * (float(zone_index) + 0.5),
            source_ground.position.y,
            source_ground.position.z
        )
        zone_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        zone_node.set_meta("level1_zone_index", zone_index)
        zones_root.add_child(zone_node)

    print(
        "[Ground] Level 1 split into %d matched wall/floor zones; floor UV1 scale=%s"
        % [ZONE_COUNT, FLOOR_UV_SCALE]
    )
func _prepare_billboard_edge_materials(layout: Node3D) -> void:
    var tree_texture_path := "res://assets/oak_tree.png"
    var safe_materials: Dictionary = {}
    var meshes := layout.find_children("*", "MeshInstance3D", true, false)
    for node in meshes:
        var mesh_node := node as MeshInstance3D
        if mesh_node == null or mesh_node.mesh == null:
            continue
        for surface in range(mesh_node.mesh.get_surface_count()):
            var material := mesh_node.get_active_material(surface)
            if not (material is StandardMaterial3D):
                continue
            var standard := material as StandardMaterial3D
            if standard.albedo_texture == null or standard.albedo_texture.resource_path != tree_texture_path:
                continue

            var cleaned := safe_materials.get(tree_texture_path) as StandardMaterial3D
            if cleaned == null:
                cleaned = standard.duplicate() as StandardMaterial3D
                cleaned.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
                cleaned.alpha_scissor_threshold = 0.48
                cleaned.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
                cleaned.cull_mode = BaseMaterial3D.CULL_BACK
                safe_materials[tree_texture_path] = cleaned
            mesh_node.set_surface_override_material(surface, cleaned)


func _setup_mobile_visibility() -> void:
    # Aggressive mobile culling: let the fog hide the cutoff so the renderer
    # does not spend time drawing distant walls, trees and squirrels.
    var camera := get_parent().get_node_or_null("Player/Camera3D") as Camera3D
    if camera == null:
        return
    camera.near = 0.05
    camera.far = CAMERA_FAR

func _build_mobile_wall_visuals() -> void:
    var layout := get_parent().get_node_or_null("Level1Layout") as Node3D
    if layout == null:
        return

    # Collision bodies remain intact. Visual MultiMeshes are split spatially so
    # frustum culling can remove distant chunks instead of treating the whole map
    # as one giant AABB.
    if get_node_or_null("MobileWallVisuals") != null:
        return

    var first_mesh: MeshInstance3D = null
    var grouped: Dictionary = {}
    var walls_root := layout.get_node_or_null("Walls") as Node3D
    if walls_root == null:
        return

    const CHUNK_CELLS_X: int = 14
    const CHUNK_CELLS_Z: int = 8

    for child in walls_root.get_children():
        if not (child is StaticBody3D) or not child.name.begins_with("MapWall_"):
            continue
        var mesh_instance := child.get_node_or_null("Mesh") as MeshInstance3D
        if mesh_instance == null or mesh_instance.mesh == null:
            continue
        if first_mesh == null:
            first_mesh = mesh_instance

        var cell_x: int = int(round((child.position.x - LevelData.MAP_WORLD_ORIGIN.x) / LevelData.CELL_SIZE))
        var cell_z: int = int(round((child.position.z - LevelData.MAP_WORLD_ORIGIN.y) / LevelData.CELL_SIZE))
        var max_chunk_x: int = int(ceil(float(LevelData.MAP_WIDTH) / CHUNK_CELLS_X)) - 1
        var max_chunk_z: int = int(ceil(float(LevelData.MAP_HEIGHT) / CHUNK_CELLS_Z)) - 1
        var chunk_x: int = clampi(floori(float(cell_x) / CHUNK_CELLS_X), 0, max_chunk_x)
        var chunk_z: int = clampi(floori(float(cell_z) / CHUNK_CELLS_Z), 0, max_chunk_z)
        var chunk_id: String = "%d_%d" % [chunk_x, chunk_z]
        var texture_index: int = _zone_index_for_world_x(child.position.x)

        if not grouped.has(chunk_id):
            grouped[chunk_id] = {}
        var by_texture: Dictionary = grouped[chunk_id]
        if not by_texture.has(texture_index):
            by_texture[texture_index] = []
        (by_texture[texture_index] as Array).append(child)

        mesh_instance.visible = false

    if first_mesh == null or grouped.is_empty():
        return

    var container := Node3D.new()
    container.name = "MobileWallVisuals"
    add_child(container)

    var batch_count := 0
    for chunk_id in grouped.keys():
        var by_texture: Dictionary = grouped[chunk_id]
        for texture_index in by_texture.keys():
            var entries: Array = by_texture[texture_index]
            if entries.is_empty():
                continue

            var mm := MultiMesh.new()
            mm.transform_format = MultiMesh.TRANSFORM_3D
            mm.mesh = first_mesh.mesh
            mm.instance_count = entries.size()

            var min_pos := (entries[0] as Node3D).position
            var max_pos := min_pos
            for entry in entries:
                var body := entry as Node3D
                min_pos.x = minf(min_pos.x, body.position.x)
                min_pos.y = minf(min_pos.y, body.position.y)
                min_pos.z = minf(min_pos.z, body.position.z)
                max_pos.x = maxf(max_pos.x, body.position.x)
                max_pos.y = maxf(max_pos.y, body.position.y)
                max_pos.z = maxf(max_pos.z, body.position.z)

            # Keep the 8 MultiMesh draw calls, but make each batch's bounds cover
            # the complete playable world. This prevents camera-frustum culling
            # from exposing holes when a distant wall chunk is partly off-screen.
            var map_left := LevelData.MAP_WORLD_ORIGIN.x
            var map_top := LevelData.MAP_WORLD_ORIGIN.y
            var map_width := float(LevelData.MAP_WIDTH) * LevelData.CELL_SIZE
            var map_depth := float(LevelData.MAP_HEIGHT) * LevelData.CELL_SIZE
            mm.custom_aabb = AABB(
                Vector3(map_left - 4.0, -1.0, map_top - 4.0),
                Vector3(map_width + 8.0, 5.0, map_depth + 8.0)
            )

            for i in range(entries.size()):
                var body := entries[i] as Node3D
                mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, body.position))

            var instance := MultiMeshInstance3D.new()
            instance.name = "Walls_%s_Mat%d" % [chunk_id, int(texture_index)]
            instance.multimesh = mm
            instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

            var texture := load(WALL_TEXTURE_PATHS[int(texture_index)]) as Texture2D
            var mat := _make_wall_material(texture)
            if mat == null:
                continue
            instance.material_override = mat
            container.add_child(instance)
            batch_count += 1

    var wall_count := 0
    for chunk_id in grouped.keys():
        var by_texture: Dictionary = grouped[chunk_id]
        for texture_index in by_texture.keys():
            wall_count += (by_texture[texture_index] as Array).size()
    print("[Perf] Level 1 wall visuals spatially batched: %d walls -> %d culled MultiMeshes" % [wall_count, batch_count])

func _setup_atmosphere() -> void:
    var we := get_parent().get_node_or_null("WorldEnvironment") as WorldEnvironment
    if we == null or we.environment == null:
        push_warning("[Atmosphere] WorldEnvironment not found")
        return
    var env := we.environment
    var renderer := str(ProjectSettings.get_setting("rendering/renderer/rendering_method", ""))

    # The project intentionally uses GL Compatibility for Android.
    # Volumetric fog is Forward+ only, so use a lightweight depth/height fog
    # fallback here instead of enabling an effect the target renderer cannot draw.
    if renderer != "gl_compatibility":
        env.volumetric_fog_enabled = true
        env.volumetric_fog_density = 0.015
        env.volumetric_fog_emission = Color(0.4, 0.5, 0.7)
        env.volumetric_fog_emission_energy = 0.6
        env.volumetric_fog_albedo = Color(0.9, 0.95, 1.0)
        env.volumetric_fog_length = 60.0
    else:
        env.volumetric_fog_enabled = false
        env.fog_enabled = true
        # Depth fog must dissolve the maze before either the level boundary or
        # Camera3D.far becomes visible. This keeps the player in a continuous
        # blue night haze instead of exposing a hard vertical world cutoff.
        env.fog_mode = Environment.FOG_MODE_DEPTH
        env.fog_density = 1.0
        env.fog_depth_begin = 10.0
        env.fog_depth_end = 32.0
        env.fog_depth_curve = 1.35
        env.fog_height = 0.0
        env.fog_height_density = 0.0
        env.fog_light_color = FOG_COLOR
        env.fog_light_energy = 1.0
        env.fog_sky_affect = 0.0
        env.fog_sun_scatter = 0.0
        env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
        env.ambient_light_color = Color(0.32, 0.39, 0.56)
        env.ambient_light_sky_contribution = 0.0
        env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED

    # Compatibility uses a simplified glow implementation: bloom and the
    # lower HDR threshold are the important controls. The authored emission
    # on walls, floors, lamps and pickups therefore produces a visible halo.
    env.glow_enabled = true
    env.glow_intensity = 1.35
    env.glow_bloom = 0.18
    env.glow_hdr_threshold = 0.55
    env.glow_hdr_scale = 1.0
    env.glow_hdr_luminance_cap = 4.0

    # AgX tonemapping — supported by the Android Compatibility renderer.
    env.tonemap_mode = Environment.TONE_MAPPER_AGX
    env.tonemap_exposure = 1.0
    env.tonemap_white = 2.5

    # Slightly deepen ambient for more night contrast.
    env.ambient_light_energy = 0.65

    print("[Atmosphere] Night atmosphere enabled. Renderer: %s" % renderer)

func _spawn_leaves() -> void:
    if get_node_or_null("FallingLeaves") != null:
        return

    var leaves := GPUParticles3D.new()
    leaves.name = "FallingLeaves"
    # Keep the drifting-leaf effect, but make it cheap enough for mobile.
    leaves.amount = 8
    leaves.lifetime = 8.0
    leaves.preprocess = 1.5
    leaves.explosiveness = 0.0
    leaves.randomness = 0.8

    var mat := ParticleProcessMaterial.new()
    mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
    mat.emission_box_extents = Vector3(50, 1, 14)
    mat.direction = Vector3(0, -1, 0)
    mat.spread = 15.0
    mat.initial_velocity_min = 0.6
    mat.initial_velocity_max = 1.4
    mat.gravity = Vector3(0.2, -0.3, 0.1)
    mat.scale_min = 0.4
    mat.scale_max = 0.9
    mat.angular_velocity_min = -30.0
    mat.angular_velocity_max = 30.0

    var draw_pass := QuadMesh.new()
    draw_pass.size = Vector2(0.15, 0.15)
    var leaf_mat := StandardMaterial3D.new()
    leaf_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    leaf_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    leaf_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
    leaf_mat.albedo_color = Color(0.55, 0.35, 0.15, 0.85)
    draw_pass.material = leaf_mat

    leaves.draw_pass_1 = draw_pass
    leaves.process_material = mat
    leaves.position = Vector3(0, 10, 0)
    leaves.local_coords = false
    add_child(leaves)
    print("[Atmosphere] Falling leaves spawned.")

func _build_hero_grass_spots() -> void:
    # Clean previous spots (in case scene reloads).
    for child in get_children():
        if child.name.begins_with("HeroGrass_"):
            child.queue_free()

    if not ResourceLoader.exists(HERO_GRASS_PATH):
        print("[HeroGrass] hero tile not found, skipping.")
        return

    var hero_tex := load(HERO_GRASS_PATH) as Texture2D
    if hero_tex == null:
        print("[HeroGrass] failed to load hero tile.")
        return

    var shader_res: Shader = null
    if ResourceLoader.exists(HERO_GRASS_SHADER):
        shader_res = load(HERO_GRASS_SHADER) as Shader
    if shader_res == null:
        print("[HeroGrass] shader not found, using plain material.")
        return

    var mat := ShaderMaterial.new()
    mat.shader = shader_res
    mat.set_shader_parameter("albedo_tex", hero_tex)
    mat.set_shader_parameter("fade_inner", 0.35)
    mat.set_shader_parameter("fade_outer", 0.80)

    var quad := QuadMesh.new()
    quad.size = Vector2(7.0, 7.0)
    quad.material = mat

    for i in HERO_GRASS_SPOTS.size():
        var spot: Vector3 = HERO_GRASS_SPOTS[i]
        var node := MeshInstance3D.new()
        node.name = "HeroGrass_%02d" % i
        node.mesh = quad
        node.rotation_degrees = Vector3(-90.0, randf() * 360.0, 0.0)
        node.position = Vector3(spot.x, spot.y, spot.z)
        node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        add_child(node)

    print("[HeroGrass] spawned ", HERO_GRASS_SPOTS.size(), " hero spots.")


