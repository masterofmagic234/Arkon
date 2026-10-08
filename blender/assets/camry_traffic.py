import bpy, math, os
from mathutils import Vector

# Camry XV70-inspired traffic vehicle for Arkon.
# Low/mid-poly game asset, built from shaped lofts rather than block primitives.
# Front of the vehicle is -X.

# ---------- scene / collections ----------
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
for coll in list(bpy.data.collections):
    if coll.name != "Collection":
        bpy.data.collections.remove(coll)

asset_coll = bpy.data.collections.new("ASSET_CAMRY_XV70_TRAFFIC")
bpy.context.scene.collection.children.link(asset_coll)
preview_coll = bpy.data.collections.new("PREVIEW_ONLY")
bpy.context.scene.collection.children.link(preview_coll)
default_coll = bpy.data.collections.get("Collection")
if default_coll:
    bpy.data.collections.remove(default_coll)

def move_to_collection(ob, coll):
    for c in list(ob.users_collection):
        c.objects.unlink(ob)
    coll.objects.link(ob)

# ---------- materials ----------
def make_mat(name, color, metallic=0.0, roughness=0.35, alpha=1.0):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.diffuse_color = (*color, alpha)
    m.use_nodes = True
    bs = m.node_tree.nodes.get("Principled BSDF")
    bs.inputs["Base Color"].default_value = (*color, 1)
    bs.inputs["Metallic"].default_value = metallic
    bs.inputs["Roughness"].default_value = roughness
    if alpha < 1:
        bs.inputs["Alpha"].default_value = alpha
        m.surface_render_method = "DITHERED"
    return m

paint = make_mat("Camry Red Metallic", (0.44, 0.008, 0.018), 0.68, 0.22)
paint_hi = make_mat("Body Highlight Red", (0.63, 0.014, 0.026), 0.62, 0.23)
black = make_mat("Gloss Black", (0.008, 0.010, 0.012), 0.12, 0.27)
rubber = make_mat("Tire Rubber", (0.012, 0.014, 0.017), 0.0, 0.88)
glass = make_mat("Dark Glass", (0.028, 0.055, 0.070), 0.12, 0.17, 0.88)
alloy = make_mat("Silver Alloy", (0.52, 0.56, 0.61), 0.78, 0.21)
chrome = make_mat("Chrome", (0.72, 0.75, 0.78), 0.9, 0.14)
lamp = make_mat("LED Headlamp", (0.74, 0.87, 1.0), 0.16, 0.15)
tail = make_mat("Tail Lamp Red", (0.62, 0.006, 0.012), 0.18, 0.18)
amber = make_mat("Turn Amber", (1.0, 0.20, 0.015), 0.08, 0.2)
interior = make_mat("Interior Black", (0.016, 0.018, 0.021), 0.0, 0.72)
plate_mat = make_mat("Plate", (0.72, 0.73, 0.70), 0.0, 0.42)

# ---------- mesh helpers ----------
def add_mesh(name, verts, faces, material, bevel=0.0, collection=asset_coll):
    me = bpy.data.meshes.new(name + "_Mesh")
    me.from_pydata(verts, [], faces)
    me.update()
    ob = bpy.data.objects.new(name, me)
    collection.objects.link(ob)
    if material:
        me.materials.append(material)
    if bevel:
        b = ob.modifiers.new("Automotive edge softness", "BEVEL")
        b.width = bevel
        b.segments = 3
        ob.modifiers.new("Weighted normals", "WEIGHTED_NORMAL")
    return ob

def cube(name, loc, dims, material, bevel=0.025, collection=asset_coll):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    ob = bpy.context.object
    ob.name = name
    ob.dimensions = dims
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    ob.data.materials.append(material)
    if bevel:
        b = ob.modifiers.new("Soft edges", "BEVEL")
        b.width = bevel
        b.segments = 3
        ob.modifiers.new("Weighted normals", "WEIGHTED_NORMAL")
    move_to_collection(ob, collection)
    return ob

def uv(name, loc, scale, material, segments=20, rings=10, collection=asset_coll):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, location=loc)
    ob = bpy.context.object
    ob.name = name
    ob.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    ob.data.materials.append(material)
    bpy.ops.object.shade_smooth()
    move_to_collection(ob, collection)
    return ob

def cyl(name, loc, radius, depth, material, axis="Y", vertices=24):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=loc)
    ob = bpy.context.object
    ob.name = name
    if axis == "Y":
        ob.rotation_euler[0] = math.pi/2
    elif axis == "X":
        ob.rotation_euler[1] = math.pi/2
    ob.data.materials.append(material)
    bpy.ops.object.shade_smooth()
    move_to_collection(ob, asset_coll)
    return ob

def beam(name, a, b, radius, material, vertices=10):
    a, b = Vector(a), Vector(b)
    d = b-a
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=d.length, location=(a+b)/2)
    ob=bpy.context.object
    ob.name=name
    ob.rotation_mode="QUATERNION"
    ob.rotation_quaternion=d.to_track_quat("Z","Y")
    ob.data.materials.append(material)
    move_to_collection(ob, asset_coll)
    return ob

def loft(name, stations, material, bevel=0.0):
    # stations = [(x, [(y,z), ...]), ...], each cross section closed.
    verts=[]
    for x, section in stations:
        verts.extend([(x,y,z) for y,z in section])
    m=len(stations[0][1])
    faces=[]
    for i in range(len(stations)-1):
        for j in range(m):
            a=i*m+j
            b=i*m+(j+1)%m
            c=(i+1)*m+(j+1)%m
            d=(i+1)*m+j
            faces.append((a,b,c,d))
    faces.append(tuple(range(m-1,-1,-1)))
    faces.append(tuple((len(stations)-1)*m+j for j in range(m)))
    return add_mesh(name, verts, faces, material, bevel)

def poly(name, points, material, bevel=0.0):
    return add_mesh(name, [(float(x),float(y),float(z)) for x,y,z in points], [tuple(range(len(points)))], material, bevel)

# ---------- root / metadata ----------
bpy.ops.object.empty_add(type="PLAIN_AXES", location=(0,0,0))
root=bpy.context.object
root.name="TRAFFIC_CAMRY_XV70_ROOT"
move_to_collection(root, asset_coll)
root["asset_role"]="incoming traffic vehicle"
root["vehicle_family"]="Toyota Camry XV70-inspired"
root["approx_dimensions_m"]="4.89 x 1.84 x 1.45"
root["forward_axis"]="-X"
root["game_target"]="Arkon Level 2 opposing traffic"

# ---------- lower body: deliberately long, low, and rounded ----------
# Cross section order: bottom-left -> bottom-right -> outer shoulder -> upper shoulder -> top-right -> top-center -> top-left -> upper shoulder -> outer shoulder.
body_sections = [
    (-2.46, [(-0.60,0.36),(0.60,0.36),(0.73,0.48),(0.69,0.65),(0.56,0.76),(0.00,0.82),(-0.56,0.76),(-0.69,0.65),(-0.73,0.48)]),
    (-2.25, [(-0.78,0.36),(0.78,0.36),(0.84,0.50),(0.81,0.70),(0.67,0.82),(0.00,0.92),(-0.67,0.82),(-0.81,0.70),(-0.84,0.50)]),
    (-1.72, [(-0.87,0.37),(0.87,0.37),(0.94,0.52),(0.92,0.77),(0.77,0.91),(0.00,1.00),(-0.77,0.91),(-0.92,0.77),(-0.94,0.52)]),
    (-0.75, [(-0.89,0.38),(0.89,0.38),(0.96,0.54),(0.95,0.80),(0.80,0.94),(0.00,1.03),(-0.80,0.94),(-0.95,0.80),(-0.96,0.54)]),
    ( 0.25, [(-0.89,0.39),(0.89,0.39),(0.96,0.55),(0.95,0.80),(0.79,0.94),(0.00,1.02),(-0.79,0.94),(-0.95,0.80),(-0.96,0.55)]),
    ( 1.10, [(-0.87,0.40),(0.87,0.40),(0.94,0.55),(0.92,0.77),(0.76,0.91),(0.00,0.97),(-0.76,0.91),(-0.92,0.77),(-0.94,0.55)]),
    ( 1.88, [(-0.81,0.41),(0.81,0.41),(0.88,0.54),(0.85,0.73),(0.69,0.86),(0.00,0.91),(-0.69,0.86),(-0.85,0.73),(-0.88,0.54)]),
    ( 2.34, [(-0.69,0.42),(0.69,0.42),(0.78,0.53),(0.76,0.67),(0.60,0.78),(0.00,0.83),(-0.60,0.78),(-0.76,0.67),(-0.78,0.53)])
]
body=loft("Sculpted lower body", body_sections, paint, 0.035)
body.parent=root

# Side shoulder / rocker accents.
for side in (-1,1):
    cube("Lower side skirt", (0.02, side*0.915, 0.48), (2.95,0.075,0.10), black, 0.025).parent=root
    # Thin shoulder highlight line, matching the strong XV70 character line.
    beam("Upper side crease",(-1.58,side*0.914,0.82),(1.86,side*0.862,0.72),0.012,paint_hi,10).parent=root

# ---------- greenhouse: sloped windshield, low roof, fast C-pillar ----------
greenhouse_sections = [
    (-1.30, [(-0.55,0.95),(0.55,0.95),(0.50,1.20),(0.42,1.38),(0.00,1.43),(-0.42,1.38),(-0.50,1.20)]),
    (-0.72, [(-0.52,0.98),(0.52,0.98),(0.50,1.26),(0.44,1.45),(0.00,1.49),(-0.44,1.45),(-0.50,1.26)]),
    ( 0.43, [(-0.51,0.98),(0.51,0.98),(0.50,1.28),(0.43,1.46),(0.00,1.50),(-0.43,1.46),(-0.50,1.28)]),
    ( 1.28, [(-0.60,0.94),(0.60,0.94),(0.57,1.17),(0.45,1.33),(0.00,1.40),(-0.45,1.33),(-0.57,1.17)])
]
green=loft("Low swept greenhouse", greenhouse_sections, paint, 0.028)
green.parent=root

# Windows follow the greenhouse silhouette.
poly("Windshield",[
    (-1.26,-0.515,1.00),(-1.26,0.515,1.00),(-0.76,0.47,1.40),(-0.76,-0.47,1.40)
],glass,0.008).parent=root
poly("Rear windshield",[
    (0.53,-0.47,1.41),(0.53,0.47,1.41),(1.23,0.55,1.02),(1.23,-0.55,1.02)
],glass,0.008).parent=root

for side in (-1,1):
    poly("Front side window",[
        (-1.15,side*0.565,1.00),(-0.72,side*0.535,1.37),(0.03,side*0.535,1.43),(0.02,side*0.67,1.00)
    ],glass,0.008).parent=root
    poly("Rear side window",[
        (0.10,side*0.67,1.00),(0.10,side*0.535,1.43),(0.48,side*0.535,1.42),(1.16,side*0.62,1.00)
    ],glass,0.008).parent=root

    # B and C pillars.
    cube("B pillar",(0.04,side*0.675,1.20),(0.055,0.035,0.46),black,0.012).parent=root
    cube("C pillar",(0.93,side*0.625,1.17),(0.065,0.040,0.37),black,0.012).parent=root
    # Chrome window surround strip.
    beam("Window lower trim",(-1.08,side*0.692,0.99),(1.17,side*0.642,0.99),0.009,chrome,8).parent=root

    # Door handles.
    cube("Front door handle",(-0.18,side*0.885,0.79),(0.19,0.025,0.032),chrome,0.01).parent=root
    cube("Rear door handle",(0.77,side*0.835,0.78),(0.19,0.025,0.032),chrome,0.01).parent=root

    # Mirror housing and glass.
    uv("Mirror housing",(-0.98,side*0.83,0.94),(0.14,0.105,0.075),paint,16,8).parent=root
    cube("Mirror glass",(-0.98,side*0.918,0.945),(0.105,0.012,0.055),glass,0.008).parent=root

# ---------- front end: the important XV70 identity ----------
# Lower wide grille opening.
poly("Main lower grille",[
    (-2.505,-0.66,0.43),(-2.505,0.66,0.43),(-2.505,0.58,0.72),(-2.505,0.28,0.78),
    (-2.505,-0.28,0.78),(-2.505,-0.58,0.72)
],black,0.012).parent=root
for z in (0.47,0.53,0.59,0.65,0.71):
    beam("Grille horizontal bar",(-2.535,-0.58,z),(-2.535,0.58,z),0.012,alloy,8).parent=root

# Upper grille winglets.
poly("Upper grille left",[
    (-2.50,-0.10,0.82),(-2.50,-0.72,0.70),(-2.50,-0.40,0.77),(-2.50,-0.08,0.88)
],black,0.01).parent=root
poly("Upper grille right",[
    (-2.50,0.10,0.82),(-2.50,0.72,0.70),(-2.50,0.40,0.77),(-2.50,0.08,0.88)
],black,0.01).parent=root

# Generic oval badge (avoid exact logo reproduction).
uv("Front oval badge",(-2.55,0,0.865),(0.018,0.10,0.064),chrome,24,12).parent=root
uv("Badge inset",(-2.57,0,0.865),(0.012,0.071,0.042),black,20,10).parent=root

# Slim swept LED headlamps.
for side in (-1,1):
    poly("Swept LED headlamp",[
        (-2.49,side*0.27,0.86),(-2.42,side*0.70,0.74),(-2.02,side*0.61,0.88),(-1.91,side*0.30,0.94)
    ],lamp,0.014).parent=root
    # Turn-signal blade.
    beam("Headlamp amber blade",(-2.40,side*0.63,0.79),(-2.12,side*0.59,0.84),0.009,amber,8).parent=root
    # Lower corner trim.
    poly("Fog light surround",[
        (-2.48,side*0.52,0.44),(-2.48,side*0.70,0.54),(-2.48,side*0.61,0.63),(-2.48,side*0.45,0.54)
    ],black,0.01).parent=root
    cube("Fog light",(-2.515,side*0.55,0.52),(0.018,0.10,0.035),lamp,0.008).parent=root

# ---------- rear end ----------
# Trunk lip.
cube("Trunk lip",(2.33,0,0.82),(0.16,1.00,0.05),paint_hi,0.018).parent=root
for side in (-1,1):
    poly("Thin rear tail lamp",[
        (2.39,side*0.18,0.82),(2.38,side*0.70,0.73),(2.04,side*0.60,0.86),(2.02,side*0.20,0.91)
    ],tail,0.014).parent=root
    poly("Tail lamp white section",[
        (2.395,side*0.24,0.84),(2.38,side*0.63,0.76),(2.25,side*0.58,0.79),(2.27,side*0.25,0.88)
    ],lamp,0.008).parent=root

cube("Rear plate recess",(2.425,0,0.63),(0.035,0.56,0.17),black,0.025).parent=root
cube("Rear plate",(2.45,0,0.64),(0.02,0.46,0.11),plate_mat,0.008).parent=root
cube("Rear lower dark trim",(2.42,0,0.50),(0.08,1.00,0.09),black,0.025).parent=root
for side in (-1,1):
    cyl("Exhaust tip",(2.47,side*0.50,0.47),0.052,0.13,chrome,"X",20)

# ---------- wheels ----------
for x in (-1.50, 1.42):
    for side in (-1,1):
        y=side*0.89
        z=0.45
        bpy.ops.mesh.primitive_torus_add(
            major_radius=0.275, minor_radius=0.092,
            major_segments=32, minor_segments=12,
            location=(x,y,z), rotation=(math.pi/2,0,0)
        )
        tire=bpy.context.object
        tire.name="Traffic tire"
        tire.data.materials.append(rubber)
        bpy.ops.object.shade_smooth()
        move_to_collection(tire, asset_coll)
        tire.parent=root

        rim=cyl("Alloy rim",(x,y+side*0.018,z),0.215,0.065,alloy,"Y",32)
        rim.parent=root
        inset=cyl("Dark rim inset",(x,y+side*0.056,z),0.158,0.022,black,"Y",28)
        inset.parent=root
        hub=cyl("Center hub",(x,y+side*0.070,z),0.045,0.018,chrome,"Y",20)
        hub.parent=root

        for k in range(10):
            a=2*math.pi*k/10
            r1=0.045; r2=0.175
            p1=(x+math.sin(a)*r1,y+side*0.083,z+math.cos(a)*r1)
            p2=(x+math.sin(a+0.11)*r2,y+side*0.083,z+math.cos(a+0.11)*r2)
            sp=beam("Fine alloy spoke",p1,p2,0.010,alloy,8)
            sp.parent=root

# Wheel arch outlines, only the visible upper arc.
for x in (-1.50,1.42):
    for side in (-1,1):
        curve=bpy.data.curves.new("Wheel arch curve","CURVE")
        curve.dimensions="3D"
        curve.bevel_depth=0.018
        curve.bevel_resolution=2
        spl=curve.splines.new("POLY")
        pts=[]
        for i in range(15):
            ang=math.radians(10+i*160/14)
            pts.append((x+0.355*math.cos(ang), side*0.915, 0.45+0.355*math.sin(ang), 1))
        spl.points.add(len(pts)-1)
        for p, co in zip(spl.points, pts):
            p.co=co
        ob=bpy.data.objects.new("Wheel arch trim",curve)
        asset_coll.objects.link(ob)
        ob.data.materials.append(black)
        ob.parent=root

# ---------- cabin silhouettes ----------
cube("Dashboard",(-0.83,0,1.07),(0.52,0.98,0.11),interior,0.04).parent=root
for side in (-1,1):
    cube("Front seat",(-0.22,side*0.25,1.12),(0.28,0.31,0.42),interior,0.07).parent=root
    cube("Rear seat",(0.78,side*0.24,1.08),(0.26,0.32,0.27),interior,0.06).parent=root
beam("Roof antenna",(0.73,0,1.50),(0.90,0,1.56),0.010,black,8).parent=root

# ---------- preview camera / lights (not exported) ----------
bpy.ops.mesh.primitive_plane_add(size=18, location=(0,0,0.02))
floor=bpy.context.object
floor.name="PREVIEW_GROUND"
floor.data.materials.append(make_mat("Preview Ground",(0.055,0.060,0.068),0.0,0.88))
move_to_collection(floor, preview_coll)

for name, loc, power, size in [
    ("Key",(-4.5,-5.5,6.5),1100,5.5),
    ("Fill",(1.5,4.0,4.5),800,4.0),
    ("Rim",(4.0,-1.0,4.0),900,3.0)
]:
    bpy.ops.object.light_add(type="AREA", location=loc)
    light=bpy.context.object
    light.name=name
    light.data.energy=power
    light.data.shape="DISK"
    light.data.size=size
    light.rotation_euler=(Vector((0,0,0.8))-light.location).to_track_quat("-Z","Y").to_euler()
    move_to_collection(light, preview_coll)

bpy.ops.object.camera_add(location=(-7.4,-7.7,3.35))
cam=bpy.context.object
cam.name="PREVIEW_CAMERA"
cam.rotation_euler=(Vector((0,0,0.78))-cam.location).to_track_quat("-Z","Y").to_euler()
cam.data.lens=52
bpy.context.scene.camera=cam
move_to_collection(cam, preview_coll)

scene=bpy.context.scene
scene.render.engine="BLENDER_WORKBENCH"
scene.render.resolution_x=1280
scene.render.resolution_y=720
scene.render.resolution_percentage=100
scene.render.image_settings.file_format="PNG"
scene.render.filepath=os.path.join(os.getcwd(),"camry_traffic_preview.png")
scene.world.color=(0.12,0.12,0.12)

# ---------- export ----------
# Hide preview collection from GLB and select only asset geometry + root.
for ob in bpy.context.scene.objects:
    ob.select_set(False)
for ob in asset_coll.objects:
    ob.select_set(True)
bpy.context.view_layer.objects.active=root

blend_out=os.environ.get("BLENDER_ASSET_OUTPUT",os.path.join(os.getcwd(),"camry_traffic.blend"))
glb_out=os.environ.get("BLENDER_GLB_OUTPUT",os.path.join(os.getcwd(),"camry_traffic.glb"))

bpy.ops.export_scene.gltf(
    filepath=glb_out,
    export_format="GLB",
    use_selection=True,
    export_apply=True
)
print("EXPORTED GLB",glb_out)

bpy.ops.wm.save_as_mainfile(filepath=blend_out)
print("SAVED BLEND",blend_out)
