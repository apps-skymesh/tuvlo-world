"""Original outdoor baking oven art study, Blender --background --python.
Cottage Godot X/Y-up/Z-forward conversion; no external models or textures.
Prototype envelope: 2 x 2 squares, 2.3 m high. No new place/recipe is defined.
"""
import bpy,bmesh,math
from pathlib import Path
from mathutils import Vector
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
COLORS={'Plaster':'ead9b5','PlasterShade':'d6c49d','Hearth':'b6a58a','Stone':'b7ae97','StoneLight':'d1c4a7','Clay':'b56f51','ClayLight':'cc8c64','ClayShade':'92583f','Iron':'596259','Cavity':'3a3430','Wood':'805b40','EndGrain':'ccab70','Handle':'b08a58','Ember':'c67b43','Warm':'e4ad63'}
M={}
def srgb(x):return x/12.92 if x<.04045 else ((x+.055)/1.055)**2.4
for name,h in COLORS.items():
 m=bpy.data.materials.new(name);m.use_nodes=True;c=tuple(srgb(int(h[i:i+2],16)/255) for i in (0,2,4))+(1,)
 m.diffuse_color=c;m.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=c;m.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.86;M[name]=m

def xyz(p):return (p[0],-p[2],p[1])
def finish(o,name,mat,bevel=0):
 o.name=name;o.data.materials.append(M[mat]);bpy.context.view_layer.objects.active=o
 if bevel:
  m=o.modifiers.new('Hand softened joinery','BEVEL');m.width=bevel;m.segments=3;bpy.ops.object.modifier_apply(modifier=m.name)
 for p in o.data.polygons:p.use_smooth=True
 if bevel:
  m=o.modifiers.new('Weighted normals','WEIGHTED_NORMAL');bpy.ops.object.modifier_apply(modifier=m.name)
 return o

def mesh(name,pts,faces,mat,bevel=0):
 d=bpy.data.meshes.new(name);d.from_pydata([xyz(p) for p in pts],[],faces);d.update();bm=bmesh.new();bm.from_mesh(d);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(d);bm.free();o=bpy.data.objects.new(name,d);bpy.context.collection.objects.link(o);return finish(o,name,mat,bevel)
def box(name,p,size,mat,bevel=.025):
 bpy.ops.mesh.primitive_cube_add(size=1,location=xyz(p));o=bpy.context.object;o.dimensions=(size[0],size[2],size[1]);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);return finish(o,name,mat,bevel)
def rod(name,a,b,r,mat,n=12):
 a,b=Vector(xyz(a)),Vector(xyz(b));bpy.ops.mesh.primitive_cylinder_add(vertices=n,radius=r,depth=(b-a).length,location=(a+b)/2);o=bpy.context.object;o.rotation_mode='QUATERNION';o.rotation_quaternion=(b-a).to_track_quat('Z','Y');return finish(o,name,mat,.004)
def arch(name,width,base,spring,z,depth,mat):
 r=width/2;outline=[(-r,base),(r,base)]+[(math.cos(i*math.pi/20)*r,spring+math.sin(i*math.pi/20)*r) for i in range(21)];n=len(outline)
 pts=[(x,y,z+d) for d in [-depth/2,depth/2] for x,y in outline]
 return mesh(name,pts,[tuple(range(n-1,-1,-1)),tuple(n+i for i in range(n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)],mat,.008)

box('Stone footing',(0,.075,0),(1.85,.15,1.75),'Hearth',.075)
box('Shadow in wood bay',(0,.40,-.30),(1.23,.52,.35),'Cavity',.035)
box('Back masonry',(0,.43,-.59),(1.55,.60,.24),'PlasterShade',.065)
for side in [-1,1]:
 box('Plaster support',(side*.66,.46,0),(.34,.67,1.34),'Plaster',.075)
 for j in range(3):
  box('Corner stone',(side*.68,.20+j*.20,.61),(.31,.18,.13),'StoneLight' if j%2 else 'Stone',.025)
box('Broad hearth slab',(0,.845,.06),(1.86,.17,1.73),'Hearth',.065)
box('Working edge',(0,.91,.78),(1.80,.07,.23),'StoneLight',.035)
# A real half-dome shell with an open front mouth, rather than a full sphere.
pts=[];faces=[];n=64;rows=24
for k in range(rows+1):
 t=k*math.pi/(2*rows)
 for j in range(n):
  a=j*math.tau/n;pts.append((.77*math.sin(t)*math.cos(a),.94+.69*math.cos(t),-.16+.64*math.sin(t)*math.sin(a)))
for k in range(rows):
 for j in range(n):
  a=k*n+j;b=k*n+(j+1)%n;f=(a,b,b+n,a+n);c=[sum(pts[i][axis] for i in f)/4 for axis in range(3)]
  if c[2]>.24 and abs(c[0])<.33 and c[1]<1.40:continue
  faces.append(f)
mesh('Sculpted plaster dome',pts,faces,'Plaster')
arch('Deep oven mouth',.65,.94,1.13,.37,.025,'Cavity')
# Individual tapered arch bricks with soft corners and an oversized keystone.
for i in range(11):
 a=i*math.pi/11+.014;b=(i+1)*math.pi/11-.014;pts=[]
 for z in [.43,.60]:
  for r in [.335,.445]:
   for t in [a,b]:pts.append((math.cos(t)*r,1.12+math.sin(t)*r,z))
 mesh('Radial clay arch brick',pts,[(0,1,3,2),(4,6,7,5),(0,4,5,1),(2,3,7,6),(0,2,6,4),(1,5,7,3)],['Clay','ClayLight','ClayShade'][i%3],.009)
for side in [-1,1]:
 for y in [1.00,1.10]:box('Arch spring brick',(side*.39,y,.515),(.11,.09,.19),'ClayLight' if y==1.10 else 'Clay',.014)
box('Dark baking floor',(0,.955,.47),(.64,.025,.41),'Cavity',.018)
for x in [-.20,.03,.23]:
 rod('Warm coal',(x,.98,.40),(x+.04,.98,.48),.022,'Ember',8)
# A flue at the back leaves the hand-worked dome silhouette clear.
box('Flue shoulder',(-.40,1.57,-.37),(.41,.24,.43),'Plaster',.045)
for row in range(4):
 box('Clay chimney course',(-.40,1.73+row*.105,-.37),(.27,.095,.29),'ClayLight' if row%2 else 'Clay',.018)
box('Chimney shadow opening',(-.40,2.075,-.37),(.17,.01,.19),'Cavity',.01)
box('Chimney cap',(-.40,2.13,-.37),(.40,.065,.42),'StoneLight',.025)
# Stored firewood and a fitted bread peel establish its use without labels.
for row in range(2):
 for j in range(3-row):
  x=-.29+j*.28+row*.14;y=.25+row*.22
  rod('Split firewood',(x,y,-.29),(x,y,.58),.12,'Wood',10)
  rod('Pale cut grain',(x,y,.579),(x,y,.589),.104,'EndGrain',12)
rod('Bread peel handle',(-.83,.17,.74),(-.72,1.36,.55),.022,'Handle')
box('Bread peel blade',(-.71,1.47,.53),(.30,.29,.022),'Iron',.09)
rod('Iron resting hook',(-.82,.67,.65),(-.65,.67,.65),.015,'Iron')
# Consolidated material surfaces and subtle neutral vertex paint.
for mat in M.values():
 objects=[o for o in list(bpy.context.scene.objects) if o.type=='MESH' and o.data.materials[0]==mat]
 if not objects:continue
 bpy.ops.object.select_all(action='DESELECT')
 for o in objects:o.select_set(True)
 bpy.context.view_layer.objects.active=objects[0]
 if len(objects)>1:bpy.ops.object.join()
 o=bpy.context.object;o.name='Oven_'+mat.name
 colors=o.data.color_attributes.new(name='Color',type='BYTE_COLOR',domain='CORNER')
 for f in o.data.polygons:
  for loop in f.loop_indices:
   v=o.matrix_world@o.data.vertices[o.data.loops[loop].vertex_index].co;shade=.93+.07*min(1,max(0,v.z/2.1));colors.data[loop].color=(shade,shade,shade,1)
output=Path(__file__).resolve().parents[1]/'Godot/assets/oven/cozy_outdoor_oven.glb';output.parent.mkdir(parents=True,exist_ok=True)
bpy.ops.export_scene.gltf(filepath=str(output),export_format='GLB',export_yup=True,export_materials='EXPORT',export_vertex_color='ACTIVE',export_all_vertex_colors=True,export_cameras=False,export_lights=False)
print('Original Tuvlo outdoor oven:',output,output.stat().st_size)
