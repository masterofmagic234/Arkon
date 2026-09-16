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
    camera.rotation = Vector3.ZERO
    camera.fov = 70.0
    camera.near = 0.05
    camera.far = 40.0
    carolina.texture = load("res://assets/carolina_face.png")
