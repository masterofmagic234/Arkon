extends RefCounted

# This branch uses the project's existing artwork. Shared source textures are
# read-only; per-level materials are owned by the park.
const OAK = preload("res://assets/oak_tree.png")
const PINE = preload("res://assets/pine_tree.png")
const HEDGE = preload("res://assets/hedge_wall_0.png")
const FLOORS := [
    preload("res://floor_zone_1(1).jpg"),
    preload("res://floor_zone_2(1).jpg"),
    preload("res://floor_zone_3(1).jpg"),
    preload("res://floor_zone_4(1).jpg"),
]
const WALLS := [
    preload("res://wall_zone1.png"),
    preload("res://wall_zone2.png"),
    preload("res://wall_zone3.png"),
    preload("res://wall_zone4.png"),
]
const GUARDIAN = preload("res://Meshy_AI_Acorn_Guardian_0923182156_texture (1).glb")
const SURFACE_SHADER = preload("res://shaders/level1_asset_surface.gdshader")

static func surface(texture_: Texture2D, tint: Vector3, scale_: float = 0.36) -> ShaderMaterial:
    var material := ShaderMaterial.new()
    material.shader = SURFACE_SHADER
    material.set_shader_parameter("surface_tex",texture_)
    material.set_shader_parameter("tint",tint)
    material.set_shader_parameter("texture_scale",scale_)
    return material

static func tree_material(pine: bool) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_texture = PINE if pine else OAK
    material.albedo_color = Color(0.86,0.97,0.87)
    material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
    material.alpha_scissor_threshold = 0.42
    material.cull_mode = BaseMaterial3D.CULL_DISABLED
    material.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
    material.billboard_keep_scale = true
    material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
    material.roughness = 1.0
    material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
    return material

static func guardian(height: float) -> Node3D:
    var model := GUARDIAN.instantiate() as Node3D
    var bounds := AABB()
    var first := true
    for node: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
        var transform_ := node.transform
        var parent := node.get_parent() as Node3D
        while parent != model:
            transform_ = parent.transform*transform_
            parent = parent.get_parent() as Node3D
        var box := transform_*node.get_aabb()
        bounds = box if first else bounds.merge(box)
        first = false
        node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        for i in range(node.mesh.get_surface_count()):
            var source := node.get_active_material(i) as StandardMaterial3D
            if source:
                var material := source.duplicate() as StandardMaterial3D
                material.albedo_color *= Color(0.72,0.78,0.65)
                material.metallic = 0.32
                material.roughness = 0.72
                node.set_surface_override_material(i,material)
    var scale_ := height/maxf(bounds.size.y,0.01)
    var basis_ := Basis(Vector3.UP,PI)*Basis.from_scale(Vector3.ONE*scale_)
    var base := Vector3(bounds.get_center().x,bounds.position.y,bounds.get_center().z)
    model.transform = Transform3D(basis_,-(basis_*base))
    return model
