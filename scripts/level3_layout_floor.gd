@tool
extends Node2D

const StoreData = preload("res://scripts/level3_store_data.gd")
const AssetVisual = preload("res://scripts/level3_asset_visual.gd")

func _ready() -> void:
    queue_redraw()

func _process(_delta: float) -> void:
    if Engine.is_editor_hint():
        queue_redraw()

func _draw() -> void:
    var map := StoreData.get_map()

    for y in range(map.size()):
        for x in range(map[y].length()):
            if map[y][x] == "#":
                continue

            draw_rect(
                Rect2(
                    Vector2(x * StoreData.tile_size(), y * StoreData.tile_size()),
                    Vector2(StoreData.tile_size(), StoreData.tile_size())
                ),
                Color(0.055, 0.050, 0.055, 1.0),
                true
            )

    for region_data in StoreData.get_room_floor_regions():
        var cell_rect: Rect2 = region_data["rect"]
        var world_rect := Rect2(
            cell_rect.position * float(StoreData.tile_size()),
            cell_rect.size * float(StoreData.tile_size())
        )

        draw_rect(world_rect, region_data["color"], true)

        var texture := AssetVisual.first_frame_texture(String(region_data["texture"]))
        if texture != null:
            draw_texture_rect(
                texture,
                world_rect.grow(-2.0),
                true,
                Color(1.0, 1.0, 1.0, float(region_data["alpha"]))
            )
