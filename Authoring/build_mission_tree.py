"""Original mission-tree forms. Blender --background --python build_mission_tree.py.
Godot coordinates, cottage xyz conversion; no external art. Placement stays 1x1;
the authored aerial canopy fits the existing 1.55 radius, below 3.7 height.
"""
import bpy, bmesh, math, random
from pathlib import Path
from mathutils import Vector

rng = random.Random(271027)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
M = {}
PALETTE = {'Heartwood':'815738', 'Bark ridges':'a37b50', 'Bark shade':'60452f',
           'Leaf forest':'397349', 'Leaf fern':'528c50', 'Leaf meadow':'75a45d',
           'Leaf sunlight':'a0bd72', 'Leaf new tips':'bfd28a', 'Leaf weather':'6e9b53',
           'Seed shell':'ac7950', 'Earth':'786044', 'Earth light':'9b8056'}
def xyz(p): return (p[0], -p[2], p[1])
def srgb(v): return v/12.92 if v < .04045 else ((v+.055)/1.055)**2.4
for name, h in PALETTE.items():
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    color = tuple(srgb(int(h[i:i+2],16)/255) for i in (0,2,4))+(1,)
    mat.diffuse_color = color
    bsdf = mat.node_tree.nodes.get('Principled BSDF')
    bsdf.inputs['Base Color'].default_value = color
    bsdf.inputs['Roughness'].default_value = .84 if 'Leaf' not in name else .73
    M[name] = mat

def mesh(name, points, faces, material):
    data = bpy.data.meshes.new(name)
    data.from_pydata([xyz(p) for p in points], [], faces)
    data.update()
    bm = bmesh.new(); bm.from_mesh(data)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bm.to_mesh(data); bm.free()
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    data.materials.append(M[material])
    for polygon in data.polygons: polygon.use_smooth = True
    return obj

def branch(name, path, radii, material='Heartwood', sides=10):
    points, faces = [], []
    for j, (center, radius) in enumerate(zip(path, radii)):
        center = Vector(center)
        tangent = (Vector(path[min(j+1,len(path)-1)])-Vector(path[max(0,j-1)])).normalized()
        axis = Vector((0,0,1)) if abs(tangent.z)<.9 else Vector((1,0,0))
        u = tangent.cross(axis).normalized(); v = tangent.cross(u).normalized()
        for i in range(sides):
            angle = math.tau*i/sides
            flute = 1+.075*math.cos(angle*5+j*.35)
            points.append(center+(u*math.cos(angle)+v*math.sin(angle))*radius*flute)
        if j:
            for i in range(sides):
                a=(j-1)*sides+i; b=(j-1)*sides+(i+1)%sides
                faces.append((a,b,b+sides,a+sides))
    faces.extend([tuple(range(sides-1,-1,-1)),tuple(range(len(points)-sides,len(points)))])
    return mesh(name, points, faces, material)

# A rooted, gently twisting trunk with a readable three-way fork.
trunk=[(0,.025,0),(-.045,.16,.015),(-.09,.48,.02),(-.06,.86,.015),
       (.045,1.22,0),(.10,1.58,-.035),(.04,1.94,-.06),(-.04,2.37,-.09)]
branch('Twisted heartwood',trunk,[.25,.21,.16,.145,.13,.105,.075,.022],sides=16)
for i in range(6):
    a=i*math.tau/6+.2; reach=.34+rng.random()*.1
    branch('Buttress root',[(0,.18,0),(math.cos(a)*.20,.065,math.sin(a)*.20),
           (math.cos(a)*reach,.015,math.sin(a)*reach)],[.10,.063,.008],sides=9)
# Delicate raised grain follows the trunk instead of texture noise.
for i in range(7):
    angle=i*math.tau/7
    line=[]
    for j in range(1,6):
        p=Vector(trunk[j]); r=[.25,.21,.16,.145,.13,.105][j]
        a=angle+j*.13
        line.append(p+Vector((math.cos(a)*r,.0,math.sin(a)*r)))
    branch('Flowing bark ridge',line,[.009,.011,.010,.008,.004], 'Bark ridges',5)

clusters=[]
# Staggered branch fans form an asymmetric oak crown with light between layers.
for ring, (y, reach, count) in enumerate([(1.94,.69,6),(2.39,.86,7),(2.92,.48,5)]):
    for i in range(count):
        a=i*math.tau/count+ring*1.15
        end=Vector((math.cos(a)*reach,y+rng.uniform(-.19,.19),math.sin(a)*reach))
        start=Vector((.05,1.10+ring*.34,-.02))
        mid=start.lerp(end,.58)+Vector((0,.05,0))
        branch('Sweeping bough',[start,start.lerp(mid,.5),mid,mid.lerp(end,.6)+Vector((0,.045,0)),end],[.085-ring*.013,.069-ring*.009,.047,.027,.009],sides=12)
        clusters.append((end,a,ring))
clusters.append((Vector((-.05,3.13,-.04)),.8,3))

def leaf(base, direction, length, width, material):
    aim=Vector(direction).normalized()
    axis=Vector((0,1,0)) if abs(aim.y)<.94 else Vector((1,0,0))
    side=aim.cross(axis).normalized(); normal=side.cross(aim).normalized()
    points=[]
    # Closed, softly folded almond leaves, each with a convex center vein.
    for layer in [0,1]:
        for row in range(5):
            t=row/4; half=width*math.sin(math.pi*t)
            for column in [-1,0,1]:
                lift=math.sin(math.pi*t)*(length*.12-abs(column)*width*.24)
                p=base+aim*(length*t)+side*(column*half)+normal*(lift-layer*.009)
                points.append(p)
    if any(math.hypot(p.x,p.z)>1.47 or p.y>3.58 for p in points): return
    faces=[]
    for j in range(4):
        for c in range(2):
            a=j*3+c
            faces.extend([(a,a+1,a+4,a+3),(a+15,a+18,a+19,a+16)])
        for c in [0,2]:
            a=j*3+c; faces.append((a,a+3,a+18,a+15))
    faces.extend([(0,15,17,2),(12,14,29,27)])
    mesh('Cupped leaf',points,faces,material)

for center, angle, ring in clusters:
    # Twigs support the leaf fans; varied yaw avoids repetitive rosettes.
    for fan in range(6):
        a=angle+fan*math.tau/6+rng.uniform(-.25,.25)
        tip=center+Vector((math.cos(a)*.29,rng.uniform(.07,.19),math.sin(a)*.29))
        branch('Leaf bearing twig',[center,tip],[.014,.003],'Bark shade',5)
        for j in range(6):
            t=.12+j*.14
            base=center.lerp(tip,t)
            sign=-1 if j%2 else 1
            yaw=a+sign*rng.uniform(.45,1.45)
            direction=(math.cos(yaw),rng.uniform(.22,.75),math.sin(yaw))
            choices=['Leaf forest','Leaf fern','Leaf meadow','Leaf sunlight']
            material=choices[rng.choices(range(4),weights=[2,4,5,2] if ring<2 else [0,2,5,5])[0]]
            if j==0 or (j==2 and fan%3==0): material='Leaf weather'
            elif ring==3 and j>3: material='Leaf new tips'
            leaf(base,direction,rng.uniform(.27,.36),rng.uniform(.08,.115),material)

def export_piece(filename, pivot):
    # Batch by surface, retaining separate crown and weathering surfaces.
    for material in M:
        objects=[o for o in bpy.context.scene.objects if o.type=='MESH' and o.data.materials[0]==M[material]]
        if not objects: continue
        bpy.ops.object.select_all(action='DESELECT')
        for obj in objects: obj.select_set(True)
        bpy.context.view_layer.objects.active=objects[0]
        bpy.ops.object.join(); obj=bpy.context.object
        obj.name=('Crown ' if material.startswith('Leaf') else '')+material
        colors=obj.data.color_attributes.new(name='Color',type='BYTE_COLOR',domain='CORNER')
        for loop in obj.data.loops:
            p=obj.data.vertices[loop.vertex_index].co
            shade=.84+.16*min(1,max(0,p.z/3.5))
            colors.data[loop.index].color=(shade,shade,shade,1)
        if material.startswith('Leaf'):
            bpy.context.scene.cursor.location=xyz((0,pivot,0))
            bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
    output=Path(__file__).resolve().parents[1]/'Godot/assets/tree'/filename
    output.parent.mkdir(parents=True,exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=str(output),export_format='GLB',export_yup=True,
        export_materials='EXPORT',export_vertex_color='ACTIVE',export_all_vertex_colors=True,
        export_cameras=False,export_lights=False)
    print('Original mission tree exported:',output,output.stat().st_size)

def clear():
    bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)

export_piece('mission_tree_mature.glb',1.65)
clear()
# A planted seed nestled in shaped soil, with two opening cotyledons.
branch('Planted earth',[(0,0,0),(0,.04,0),(0,.075,0)], [.32,.26,.06],'Earth',24)
branch('Seed shell',[(0,.055,.015),(.01,.13,.02),(.025,.17,.025)], [.065,.09,.018],'Seed shell',12)
branch('First shoot',[(0,.09,0),(-.02,.19,0),(.005,.27,0)],[.021,.015,.007],sides=10)
leaf(Vector((0,.23,0)),(-1,.35,.1),.16,.062,'Leaf weather')
leaf(Vector((0,.25,0)),(1,.6,-.1),.19,.07,'Leaf meadow')
export_piece('mission_tree_seed.glb',.22)
clear()
# Sapling leaves are the same folded shapes as the mature tree, not ellipsoids.
branch('Sapling stem',[(0,0,0),(-.035,.28,0),(.025,.64,-.015),(0,.97,0)], [.06,.039,.025,.008],sides=12)
for i in range(8):
    a=i*2.39996; y=.36+i*.081
    base=Vector((.0,y,0)); tip=base+Vector((math.cos(a)*.09,.04,math.sin(a)*.09))
    branch('Sapling twig',[base,tip],[.012,.004],sides=6)
    leaf(tip,(math.cos(a),.45,math.sin(a)),.24,.085,'Leaf weather' if i==0 else 'Leaf new tips' if i>5 else 'Leaf meadow')
export_piece('mission_tree_seedling.glb',.55)
clear()
branch('Young heartwood',[(0,0,0),(-.035,.34,0),(.03,.85,0),(.02,1.28,-.04),(0,1.73,0)], [.12,.09,.066,.043,.01],sides=14)
for i in range(7):
    a=i*2.39996; y=.91+i*.11
    base=Vector((.02,y-.25,0)); end=Vector((math.cos(a)*.35,y,math.sin(a)*.35))
    branch('Young bough',[base,base.lerp(end,.5)+Vector((0,.02,0)),end],[.035,.023,.005],sides=9)
    for j in range(8):
        yaw=a+(j-3.5)*.44
        leaf(end+Vector((0,j*.015,0)),(math.cos(yaw),.4+(j%3)*.2,math.sin(yaw)),.28,.09,'Leaf weather' if j==0 else 'Leaf meadow' if j%2 else 'Leaf fern')
leaf(Vector((0,1.71,0)),(.2,1,.1),.31,.1,'Leaf new tips')
export_piece('mission_tree_young.glb',1.0)
clear()
leaf(Vector((0,0,0)),(0,.1,1),.30,.10,'Leaf weather')
export_piece('mission_tree_leaf.glb',0)
