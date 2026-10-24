extends Node3D
## Slingshot targets participate in the real hitscan, not UI button events.
const Hitbox=preload("res://scripts/components/hitbox_3d_component.gd")
var mission: RefCounted
var symbol := 0
var surface: MeshInstance3D
func _ready() -> void:
    add_to_group("woodland_target")
    var hit=Hitbox.new();hit.name="Hitbox"
    var collider=CollisionShape3D.new();collider.name="CollisionShape3D"
    var shape=SphereShape3D.new();shape.radius=.7;collider.shape=shape
    hit.add_child(collider);add_child(hit)
    surface=MeshInstance3D.new();var disc=CylinderMesh.new();disc.height=.14;disc.top_radius=.6;disc.bottom_radius=.6;disc.radial_segments=24
    surface.mesh=disc;surface.rotation.x=PI*.5
    var mat=StandardMaterial3D.new();mat.albedo_color=[Color("719c63"),Color("d6d8c2"),Color("c99552")][symbol]
    mat.emission_enabled=true;mat.emission=mat.albedo_color*.18;surface.material_override=mat;add_child(surface)
    var label=Label3D.new();label.text=["ЛИСТ","ЛУНА","ЖЁЛУДЬ"][symbol];label.position=Vector3(0,-1,.2);label.font_size=40;label.pixel_size=.006;add_child(label)
func take_damage(_amount: int,_source: Node=null) -> bool:
    if mission==null:return false
    mission.target_hit(symbol)
    return true
