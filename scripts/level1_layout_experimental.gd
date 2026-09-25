extends Node3D

# Runtime-generated experimental Level 1.
# The ASCII matrix is the single source of truth for walls/collision.
# This keeps the 56x16 experiment easy to iterate without hand-authoring
# hundreds of MapWall nodes in a .tscn.

const LevelData = preload("res://scripts/level_data.gd")
const Level1Door = preload("res://scripts/level1_door.gd")

const GRASS_PATH := "res://assets/grass.png"
const WALL_FALLBACK_PATH := "res://assets/hedge_wall_0.png"
const TREE_PATH := "res://assets/oak_tree.png"
const ACORN_PATH := "res://assets/acorn.png"
const PINE_PATH := "res://assets/pine_tree.png"
const LAMP_PATH := "res://assets/street_lamp.png"
const KEY_PATH := "res://assets/sprCellKeys.png"

const EXPECTED_WALL_COUNT := 508

const TREE_REQUESTS := [
    Vector2(-45.0, -0.9), Vector2(-41.4, 4.5), Vector2(-34.2, -4.5), Vector2(-27.0, 5.1),
    Vector2(-21.6, -4.5), Vector2(-14.4, 4.5), Vector2(-7.2, -0.9), Vector2(-1.8, 5.1),
    Vector2(5.4, -4.5), Vector2(10.8, 4.5), Vector2(18.0, -4.5), Vector2(25.2, 4.5),
    Vector2(30.6, -4.5), Vector2(37.8, 4.5), Vector2(45.0, -4.5), Vector2(46.8, 5.1)
]

const LANTERN_REQUESTS := [
    Vector2(-46.8, -4.5), Vector2(-39.6, -0.9), Vector2(-30.6, 5.1),
    Vector2(-21.6, -2.7), Vector2(-10.8, 4.5), Vector2(-1.8, -0.9),
    Vector2(9.0, 4.5), Vector2(18.0, -4.5), Vector2(27.0, 2.7),
    Vector2(34.2, -2.7), Vector2(41.4, 4.5), Vector2(48.6, -0.9)
]

func _ready() -> void:
    if get_node_or_null("Walls") != null:
        return
    _build_level()

func _build_level() -> void:
    var floor_root := Node3D.new()
    floor_root.name = "Floor"
    add_child(floor_root)
    _build_floor(floor_root)

    var walls_root := Node3D.new()
    walls_root.name = "Walls"
    add_child(walls_root)
    _build_walls(walls_root)

    var props_root := Node3D.new()
    props_root.name = "Props"
    add_child(props_root)

    var pickups_root := Node3D.new()
    pickups_root.name = "Pickups"
    add_child(pickups_root)
    _build_pickups(pickups_root)

    var enemies_root := Node3D.new()
    enemies_root.name = "Enemies"
    add_child(enemies_root)
    _build_squirrels(enemies_root)

    var decor_root := Node3D.new()
    decor_root.name = "Decor"
    add_child(decor_root)
    _build_decor(decor_root)

    var doors_root := Node3D.new()
    doors_root.name = "Doors"
    add_child(doors_root)
    _build_doors(doors_root)

func _cell_to_world(cell: Vector2i, y: float) -> Vector3:
    return Vector3(
        LevelData.MAP_WORLD_ORIGIN.x + float(cell.x) * LevelData.CELL_SIZE,
        y,
        LevelData.MAP_WORLD_ORIGIN.y + float(cell.y) * LevelData.CELL_SIZE
    )

func _world_to_cell(position: Vector2) -> Vector2i:
    return Vector2i(
        int(round((position.x - LevelData.MAP_WORLD_ORIGIN.x) / LevelData.CELL_SIZE)),
        int(round((position.y - LevelData.MAP_WORLD_ORIGIN.y) / LevelData.CELL_SIZE))
    )

func _is_walkable(cell: Vector2i) -> bool:
    if cell.x < 0 or cell.x >= LevelData.MAP_WIDTH or cell.y < 0 or cell.y >= LevelData.MAP_HEIGHT:
        return false
    return str(LevelData.CANONICAL_MAP[cell.y]).substr(cell.x, 1) == "."

func _snap_to_walkable(requested: Vector2, preferred_zone: int = -1) -> Vector2:
    var origin := _world_to_cell(requested)
    var min_x := 0
    var max_x := LevelData.MAP_WIDTH - 1
    if preferred_zone >= 0:
        min_x = preferred_zone * 14
        max_x = mini(min_x + 13, LevelData.MAP_WIDTH - 1)

    var best := Vector2i(-1, -1)
    var best_score := 1_000_000.0
    for radius in range(0, 9):
        for z in range(maxi(0, origin.y - radius), mini(LevelData.MAP_HEIGHT - 1, origin.y + radius) + 1):
            for x in range(maxi(min_x, origin.x - radius), mini(max_x, origin.x + radius) + 1):
                var cell := Vector2i(x, z)
                if not _is_walkable(cell):
                    continue
                var score := float(abs(x - origin.x) + abs(z - origin.y))
                if score < best_score:
                    best_score = score
                    best = cell
        if best.x >= 0:
            break

    if best.x < 0:
        return requested
    var world := _cell_to_world(best, 0.0)
    return Vector2(world.x, world.z)

func _make_billboard_material(texture_path: String, energy: float = 0.0) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
    mat.billboard_keep_scale = true
    mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    var texture := load(texture_path) as Texture2D
    if texture != null:
        mat.albedo_texture = texture
        if energy > 0.0:
            mat.emission_enabled = true
            mat.emission_texture = texture
            mat.emission = Color(1.0, 0.8, 0.45, 1.0)
            mat.emission_energy_multiplier = energy
    return mat

func _build_floor(root: Node3D) -> void:
    var ground := MeshInstance3D.new()
    ground.name = "Ground"
    var mesh := PlaneMesh.new()
    mesh.size = Vector2(
        float(LevelData.MAP_WIDTH) * LevelData.CELL_SIZE,
        float(LevelData.MAP_HEIGHT) * LevelData.CELL_SIZE
    )
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(0.18, 0.27, 0.18, 1.0)
    mat.albedo_texture = load(GRASS_PATH) as Texture2D
    mat.roughness = 1.0
    mesh.material = mat
    ground.mesh = mesh
    root.add_child(ground)

func _build_walls(root: Node3D) -> void:
    var wall_mesh := BoxMesh.new()
    wall_mesh.size = Vector3(LevelData.CELL_SIZE, 2.6, LevelData.CELL_SIZE)
    var wall_material := StandardMaterial3D.new()
    wall_material.albedo_texture = load(WALL_FALLBACK_PATH) as Texture2D
    wall_material.albedo_color = Color(0.72, 0.82, 0.76, 1.0)
    wall_material.roughness = 1.0
    wall_mesh.material = wall_material

    var wall_shape := BoxShape3D.new()
    wall_shape.size = wall_mesh.size

    var wall_index := 0
    for z in range(LevelData.MAP_HEIGHT):
        var row: String = str(LevelData.CANONICAL_MAP[z])
        for x in range(LevelData.MAP_WIDTH):
            if row.substr(x, 1) != "#":
                continue
            var body := StaticBody3D.new()
            body.name = "MapWall_%03d" % wall_index
            body.position = _cell_to_world(Vector2i(x, z), 1.3)
            body.collision_layer = LevelData.WORLD_LAYER
            body.collision_mask = 0

            var mesh_instance := MeshInstance3D.new()
            mesh_instance.name = "Mesh"
            mesh_instance.mesh = wall_mesh
            body.add_child(mesh_instance)

            var collision := CollisionShape3D.new()
            collision.name = "Collision"
            collision.shape = wall_shape
            body.add_child(collision)

            root.add_child(body)
            wall_index += 1

    print("[Level1 Experiment] generated %d wall cells (expected %d)" % [wall_index, EXPECTED_WALL_COUNT])

func _build_pickups(root: Node3D) -> void:
    var acorn_mesh := QuadMesh.new()
    acorn_mesh.size = Vector2(0.78, 0.78)
    acorn_mesh.material = _make_billboard_material(ACORN_PATH)

    for i in range(LevelData.ACORN_POSITIONS.size()):
        var desired: Vector2 = LevelData.ACORN_POSITIONS[i]
        var position_xz := _snap_to_walkable(desired, i / 2)
        var acorn := MeshInstance3D.new()
        acorn.name = LevelData.ACORN_NAMES[i]
        acorn.position = Vector3(position_xz.x, 0.55, position_xz.y)
        acorn.mesh = acorn_mesh
        root.add_child(acorn)

    var key_mesh := QuadMesh.new()
    key_mesh.size = Vector2(0.9, 0.9)
    key_mesh.material = _make_billboard_material(KEY_PATH, 1.2)

    for i in range(LevelData.KEY_POSITIONS.size()):
        var position_xz := _snap_to_walkable(LevelData.KEY_POSITIONS[i], i)
        var key := MeshInstance3D.new()
        key.name = LevelData.KEY_NAMES[i]
        key.position = Vector3(position_xz.x, 0.75, position_xz.y)
        key.scale = Vector3.ONE * 1.15
        key.mesh = key_mesh
        root.add_child(key)

    var pine_mesh := QuadMesh.new()
    pine_mesh.size = Vector2(1.05, 1.55)
    pine_mesh.material = _make_billboard_material(PINE_PATH)

    for i in range(LevelData.PINE_CONE_POSITIONS.size()):
        var zone := mini(i, 3)
        var position_xz := _snap_to_walkable(LevelData.PINE_CONE_POSITIONS[i], zone)
        var pine := MeshInstance3D.new()
        pine.name = "FakePineCone" if i == 0 else "FakePineCone_%02d" % (i + 1)
        pine.position = Vector3(position_xz.x, 0.45, position_xz.y)
        pine.mesh = pine_mesh
        root.add_child(pine)

func _build_squirrels(root: Node3D) -> void:
    var squirrel_mesh := QuadMesh.new()
    squirrel_mesh.size = Vector2(1.9, 1.9)
    squirrel_mesh.material = _make_billboard_material("res://squirrel_scout_1.png", 0.35)

    for id in LevelData.SQUIRREL_NAMES:
        var requested: Vector2 = LevelData.SQUIRREL_HOME[id]
        var zone := int(_world_to_cell(requested).x / 14)
        var position_xz := _snap_to_walkable(requested, clampi(zone, 0, 3))

        var squirrel := MeshInstance3D.new()
        squirrel.name = id
        squirrel.position = Vector3(position_xz.x, 0.95, position_xz.y)
        squirrel.mesh = squirrel_mesh

        var hitbox := Area3D.new()
        hitbox.name = "Hitbox"
        hitbox.collision_layer = LevelData.SQUIRREL_LAYER
        hitbox.collision_mask = 0
        var collision := CollisionShape3D.new()
        collision.name = "Collision"
        var shape := BoxShape3D.new()
        shape.size = Vector3(1.0, 1.8, 0.4)
        collision.shape = shape
        hitbox.add_child(collision)
        squirrel.add_child(hitbox)

        root.add_child(squirrel)

func _build_decor(root: Node3D) -> void:
    var tree_mesh := QuadMesh.new()
    tree_mesh.size = Vector2(2.8, 3.5)
    tree_mesh.material = _make_billboard_material(TREE_PATH)

    for i in range(TREE_REQUESTS.size()):
        var request: Vector2 = TREE_REQUESTS[i]
        var zone := mini(i / 4, 3)
        var position_xz := _snap_to_walkable(request, zone)
        var tree := MeshInstance3D.new()
        tree.name = "Tree%02d" % (i + 1)
        tree.position = Vector3(position_xz.x, 1.55, position_xz.y)
        tree.mesh = tree_mesh
        root.add_child(tree)

    var lamp_mesh := QuadMesh.new()
    lamp_mesh.size = Vector2(1.1, 2.2)
    lamp_mesh.material = _make_billboard_material(LAMP_PATH, 1.4)

    for i in range(LANTERN_REQUESTS.size()):
        var request: Vector2 = LANTERN_REQUESTS[i]
        var zone := mini(i / 3, 3)
        var position_xz := _snap_to_walkable(request, zone)

        var lantern := Node3D.new()
        lantern.name = "Lantern%02d" % (i + 1)
        lantern.position = Vector3(position_xz.x, 0.0, position_xz.y)

        var sprite := MeshInstance3D.new()
        sprite.name = "Sprite"
        sprite.position = Vector3(0, 1.15, 0)
        sprite.mesh = lamp_mesh
        lantern.add_child(sprite)

        var light := OmniLight3D.new()
        light.name = "Light"
        light.position = Vector3(0, 1.8, 0)
        light.light_color = Color(1, 0.58, 0.28, 1)
        light.light_energy = 0.75
        light.omni_range = 4.0
        light.shadow_enabled = false
        lantern.add_child(light)

        root.add_child(lantern)

func _build_doors(root: Node3D) -> void:
    var door_material := StandardMaterial3D.new()
    door_material.albedo_color = Color(0.21, 0.15, 0.08, 1)
    door_material.roughness = 0.8
    door_material.emission_enabled = true
    door_material.emission = Color(0.16, 0.07, 0.015, 1)
    door_material.emission_energy_multiplier = 0.45

    var key_material := _make_billboard_material(KEY_PATH, 1.5)

    for i in range(LevelData.DOOR_NAMES.size()):
        var door := Node3D.new()
        door.name = LevelData.DOOR_NAMES[i]
        door.position = Vector3(LevelData.DOOR_POSITIONS[i].x, 0.0, LevelData.DOOR_POSITIONS[i].y)
        door.rotation_degrees.y = 90.0
        door.set_script(Level1Door)
        door.set("required_key", i + 1)

        var pivot := Node3D.new()
        pivot.name = "Pivot"
        pivot.position = Vector3(0, 0, -1.8)
        door.add_child(pivot)

        var leaf := AnimatableBody3D.new()
        leaf.name = "Leaf"
        leaf.position = Vector3(0, 1.3, 1.8)
        leaf.collision_layer = LevelData.WORLD_LAYER
        leaf.collision_mask = 1
        pivot.add_child(leaf)

        var mesh := MeshInstance3D.new()
        mesh.name = "Mesh"
        var door_mesh := BoxMesh.new()
        door_mesh.size = Vector3(0.34, 2.6, 3.6)
        door_mesh.material = door_material
        mesh.mesh = door_mesh
        leaf.add_child(mesh)

        var collision := CollisionShape3D.new()
        collision.name = "Collision"
        var door_shape := BoxShape3D.new()
        door_shape.size = Vector3(0.36, 2.6, 3.6)
        collision.shape = door_shape
        leaf.add_child(collision)

        var icon := MeshInstance3D.new()
        icon.name = "KeyIcon"
        icon.position = Vector3(0, 0.25, -0.2)
        var icon_mesh := QuadMesh.new()
        icon_mesh.size = Vector2(0.6, 0.6)
        icon_mesh.material = key_material
        icon.mesh = icon_mesh
        leaf.add_child(icon)

        root.add_child(door)
