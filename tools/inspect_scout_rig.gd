extends SceneTree

const MODEL_PATH := "res://Meshy_AI_Acorn_Guardian_0923182156_texture (1).glb"

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    var packed: PackedScene = load(MODEL_PATH) as PackedScene
    if packed == null:
        push_error("SCOUT RIG INSPECT: could not load " + MODEL_PATH)
        quit(1)
        return

    var instance: Node = packed.instantiate()
    if instance == null:
        push_error("SCOUT RIG INSPECT: could not instantiate model")
        quit(1)
        return

    root.add_child(instance)
    print("SCOUT RIG INSPECT: ROOT=", instance.name, " TYPE=", instance.get_class())

    var skeletons: Array[Node] = instance.find_children("*", "Skeleton3D", true, false)
    print("SCOUT RIG INSPECT: skeleton_count=", skeletons.size())

    for skeleton_node: Node in skeletons:
        var skeleton: Skeleton3D = skeleton_node as Skeleton3D
        if skeleton == null:
            continue

        print("SKELETON path=", instance.get_path_to(skeleton))
        print("SKELETON bones=", skeleton.get_bone_count())

        for bone_index: int in range(skeleton.get_bone_count()):
            var parent: int = skeleton.get_bone_parent(bone_index)
            print(
                "BONE ", bone_index,
                " name=", str(skeleton.get_bone_name(bone_index)),
                " parent=", parent
            )

        print("SKIN INFO: version=", skeleton.get_version(),
            " process_mode=", skeleton.get_process_mode())

    var players: Array[Node] = instance.find_children("*", "AnimationPlayer", true, false)
    print("SCOUT RIG INSPECT: animation_player_count=", players.size())

    for player_node: Node in players:
        var player: AnimationPlayer = player_node as AnimationPlayer
        if player == null:
            continue

        print("ANIMATION_PLAYER path=", instance.get_path_to(player))
        print("ANIMATION_PLAYER libraries=", player.get_animation_library_list())

        for library_name: StringName in player.get_animation_library_list():
            var library: AnimationLibrary = player.get_animation_library(library_name)
            if library == null:
                continue
            var animation_names: Array[StringName] = library.get_animation_list()
            print("LIBRARY ", library_name, " animations=", animation_names)

            for animation_name: StringName in animation_names:
                var animation: Animation = library.get_animation(animation_name)
                if animation == null:
                    continue
                print(
                    "ANIMATION ", animation_name,
                    " length=", animation.length,
                    " tracks=", animation.get_track_count()
                )

                var limit: int = mini(animation.get_track_count(), 12)
                for track_index: int in range(limit):
                    print(
                        "TRACK ", track_index,
                        " type=", animation.track_get_type(track_index),
                        " path=", animation.track_get_path(track_index)
                    )


    var meshes: Array[Node] = instance.find_children("*", "MeshInstance3D", true, false)
    print("SCOUT RIG INSPECT: mesh_count=", meshes.size())
    for mesh_node: Node in meshes:
        var mesh_instance: MeshInstance3D = mesh_node as MeshInstance3D
        if mesh_instance == null or mesh_instance.mesh == null:
            continue
        var mesh: Mesh = mesh_instance.mesh
        print("MESH path=", instance.get_path_to(mesh_instance),
            " surfaces=", mesh.get_surface_count(),
            " primitive=", mesh.get_class())
        for surface_index: int in range(mesh.get_surface_count()):
            var material: Material = mesh.surface_get_material(surface_index)
            var std: StandardMaterial3D = material as StandardMaterial3D
            if std == null:
                print("SURFACE ", surface_index, " material=", material)
            else:
                var tex: Texture2D = std.albedo_texture
                print(
                    "SURFACE ", surface_index,
                    " albedo_color=", std.albedo_color,
                    " texture=", tex.resource_path if tex != null else "<none>",
                    " metallic=", std.metallic,
                    " roughness=", std.roughness
                )

    print("SCOUT RIG INSPECT: PASS")
    quit(0)
