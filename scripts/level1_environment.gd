extends Node3D
class_name Level1Environment

const LevelData = preload("res://scripts/level_data.gd")

const WALL_TEXTURE_PATHS := [
    "res://wall_zone1.png",
    "res://wall_zone2.png",
    "res://wall_zone3.png",
    "res://wall_zone4.png",
]
const FLOOR_TEXTURE_PATH := "res://assets/grass.png"
const HERO_GRASS_PATH := "res://assets/floor_grass_hero.png"
const HERO_GRASS_SHADER := "res://scripts/hero_grass_fade.gdshader"
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

    # Make the new floor texture visibly read as grass instead of the nearly-black
    # fallback tint from the original scene material.
    var ground := layout.get_node_or_null("Floor/Ground") as MeshInstance3D
    if ground and ground.mesh:
        var ground_mesh := ground.mesh.duplicate() as PlaneMesh
        if ground_mesh:
            var ground_material := ground_mesh.material
            if ground_material is StandardMaterial3D:
                ground_material = ground_material.duplicate() as StandardMaterial3D
                # Match the wall visual language on the ground:
                # world-space triplanar mapping, repeated detail, mipmapped filtering,
                # but keep normal lighting so the floor still reads as a real surface.
                ground_material.albedo_color = Color(0.72, 0.82, 0.70, 1.0)
                var floor_texture := load(FLOOR_TEXTURE_PATH) as Texture2D
                if floor_texture:
                    ground_material.albedo_texture = floor_texture

                # World-space triplanar mapping keeps the floor texture continuous.
                ground_material.uv1_triplanar = true
                ground_material.uv1_world_triplanar = true

                # Larger grass detail: fewer visible repetitions across the map.
                ground_material.uv1_scale = Vector3(0.35, 0.35, 0.35)

                # Repeat the texture and preserve detail at grazing angles/distance.
                ground_material.texture_repeat = true
                ground_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
                ground_material.uv1_offset = Vector3.ZERO

                # Keep the established unshaded night-scene floor treatment.
                ground_material.roughness = 1.0
                ground_material.metallic = 0.0
                ground_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

                ground_mesh.material = ground_material
            ground.mesh = ground_mesh

    # Reuse one material per wall-zone texture instead of duplicating a
    # StandardMaterial3D for every wall segment. This keeps material/resource
    # count low and lets Android's renderer batch matching wall surfaces.
    var wall_materials: Dictionary = {}
    var wall_index := 0
    var walls_root := layout.get_node_or_null("Walls") as Node3D
    if walls_root == null:
        return
    for child in walls_root.get_children():
        if not (child is StaticBody3D) or not child.name.begins_with("MapWall_"):
            continue
        var mesh_instance := child.get_node_or_null("Mesh") as MeshInstance3D
        if mesh_instance == null or mesh_instance.mesh == null:
            continue

        var texture_path: String = WALL_TEXTURE_PATHS[wall_index % WALL_TEXTURE_PATHS.size()]
        var wall_material: StandardMaterial3D = wall_materials.get(texture_path) as StandardMaterial3D
        if wall_material == null:
            wall_material = StandardMaterial3D.new()
            var wall_texture := load(texture_path) as Texture2D
            if wall_texture:
                wall_material.albedo_texture = wall_texture
            wall_material.albedo_color = Color.WHITE
            wall_material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
            wall_material.roughness = 1.0
            # Wall textures contain the moon accents. A low-energy emission
            # texture makes those bright crescents feed the scene glow without
            # changing the wall texture itself.
            wall_material.emission_enabled = true
            wall_material.emission_texture = wall_texture
            wall_material.emission = Color(0.72, 0.80, 1.0, 1.0)
            wall_material.emission_energy_multiplier = 0.28
            wall_material.uv1_triplanar = true
            wall_material.uv1_world_triplanar = true
            wall_material.uv1_scale = Vector3(0.4, 0.4, 0.4)
            wall_material.uv1_offset = Vector3.ZERO
            wall_materials[texture_path] = wall_material

        # Keep each wall's geometry resource intact; only override its material.
        mesh_instance.material_override = wall_material
        mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        wall_index += 1

func _setup_mobile_visibility() -> void:
    # Aggressive mobile culling: let the fog hide the cutoff so the renderer
    # does not spend time drawing distant walls, trees and squirrels.
    var camera := get_parent().get_node_or_null("Player/Camera3D") as Camera3D
    if camera == null:
        return
    camera.near = 0.05
    camera.far = 22.0

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
    var wall_index := 0
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
        var texture_index: int = wall_index % WALL_TEXTURE_PATHS.size()

        if not grouped.has(chunk_id):
            grouped[chunk_id] = {}
        var by_texture: Dictionary = grouped[chunk_id]
        if not by_texture.has(texture_index):
            by_texture[texture_index] = []
        (by_texture[texture_index] as Array).append(child)

        mesh_instance.visible = false
        wall_index += 1

    if first_mesh == null or wall_index == 0:
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

            var margin := Vector3(1.2, 1.5, 1.2)
            mm.custom_aabb = AABB(min_pos - margin, (max_pos - min_pos) + margin * 2.0)

            for i in range(entries.size()):
                var body := entries[i] as Node3D
                mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, body.position))

            var instance := MultiMeshInstance3D.new()
            instance.name = "Walls_%s_Mat%d" % [chunk_id, int(texture_index)]
            instance.multimesh = mm
            instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

            var mat := StandardMaterial3D.new()
            var texture := load(WALL_TEXTURE_PATHS[int(texture_index)]) as Texture2D
            if texture:
                mat.albedo_texture = texture
            mat.albedo_color = Color.WHITE
            mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
            mat.cull_mode = BaseMaterial3D.CULL_BACK
            mat.roughness = 1.0
            mat.emission_enabled = true
            mat.emission_texture = texture
            mat.emission = Color(0.72, 0.80, 1.0, 1.0)
            mat.emission_energy_multiplier = 0.28
            mat.uv1_triplanar = true
            mat.uv1_world_triplanar = true
            mat.uv1_scale = Vector3(0.4, 0.4, 0.4)
            instance.material_override = mat
            container.add_child(instance)
            batch_count += 1

    print("[Perf] Level 1 wall visuals spatially batched: %d walls -> %d culled MultiMeshes" % [wall_index, batch_count])

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
        # Depth fog gives this tiny map a predictable mobile cutoff.
        env.fog_mode = Environment.FOG_MODE_DEPTH
        env.fog_density = 1.0
        env.fog_depth_begin = 5.0
        env.fog_depth_end = 12.0
        env.fog_depth_curve = 1.0
        env.fog_height = 0.0
        env.fog_height_density = 0.0
        env.fog_light_color = Color(0.40, 0.48, 0.66)
        env.fog_light_energy = 0.55
        env.fog_sky_affect = 0.0
        env.fog_sun_scatter = 0.0
        env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
        env.ambient_light_color = Color(0.32, 0.39, 0.56)
        env.ambient_light_sky_contribution = 0.0
        env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED

    # Controlled bloom/glow for the night scene. Keep it subtle so the
    # mobile renderer gets atmosphere without washing out the grass and walls.
    env.glow_enabled = true
    env.glow_intensity = 1.2
    env.glow_bloom = 0.3
    env.glow_strength = 1.1
    env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN

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


