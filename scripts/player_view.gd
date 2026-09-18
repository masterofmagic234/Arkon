class_name PlayerView
extends RefCounted

# Presentation/setup for the player camera and Carolina portrait.
# It owns no gameplay state and handles no input.
var camera: Camera3D
var carolina: TextureRect

func setup(camera_node: Camera3D, carolina_node: TextureRect) -> void:
    camera = camera_node
    carolina = carolina_node

func apply() -> void:
    # Keep the fixed-height Wolfenstein-style camera, but give the player a
    # small downward pitch so wall tops and the world floor read with depth.
    camera.position.y = 0.9
    camera.rotation_degrees = Vector3(-5.0, 0.0, 0.0)
    camera.fov = 70.0
    camera.near = 0.05
    camera.far = 12.0
    carolina.texture = load("res://assets/carolina_face.png")
