"""Original garden and harvest craft. Blender --background --python this_file.
Godot X/Y-up/Z-forward, cottage xyz conversion. No external assets.
"""
import bpy,bmesh,math,os
from pathlib import Path
from mathutils import Vector
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
COLORS={'Timber':'a87d54','TimberLight':'c5a071','EndGrain':'dec293','Bark':'79533d','BarkLight':'986747','Soil':'66513e','SoilLight':'80634a','Iron':'5e6557','Leaf':'668446','LeafLight':'8fa354','WheatGreen':'8d9c54','WheatGold':'d4ab50','WheatLight':'ecd38a','AppleSkin':'bb5944','AppleWarm':'d57b51','Stem':'75523c','Crust':'b4773d','CrustLight':'dca65e','BreadScore':'f3d69a','Cream':'e5d2a2'}
M={}
def xyz(p):return (p[0],-p[2],p[1])
def srgb(x):return x/12.92 if x<.04045 else ((x+.055)/1.055)**2.4
for name,h in COLORS.items():
 m=bpy.data.materials.new(name);m.use_nodes=True;c=tuple(srgb(int(h[i:i+2],16)/255) for i in (0,2,4))+(1,)
 m.diffuse_color=c;m.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=c;m.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.88 if name!='AppleSkin' else .45;M[name]=m

def finish(o,name,mat,bevel=0):
 o.name=name;o.data.materials.append(M[mat]);bpy.context.view_layer.objects.active=o
 if bevel:
  mod=o.modifiers.new('Hand softened edge','BEVEL');mod.width=bevel;mod.segments=3;bpy.ops.object.modifier_apply(modifier=mod.name)
 for f in o.data.polygons:f.use_smooth=True
 if bevel:
  mod=o.modifiers.new('Weighted normals','WEIGHTED_NORMAL');bpy.ops.object.modifier_apply(modifier=mod.name)
 return o

def mesh(name,pts,faces,mat):
 d=bpy.data.meshes.new(name);d.from_pydata([xyz(p) for p in pts],[],faces);d.update();bm=bmesh.new();bm.from_mesh(d);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(d);bm.free()
 o=bpy.data.objects.new(name,d);bpy.context.collection.objects.link(o);return finish(o,name,mat)
def box(name,p,size,mat,r=.01):
 bpy.ops.mesh.primitive_cube_add(size=1,location=xyz(p));o=bpy.context.object;o.dimensions=(size[0],size[2],size[1]);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);return finish(o,name,mat,r)
def rod(name,a,b,r,mat,n=10):
 a,b=Vector(xyz(a)),Vector(xyz(b));bpy.ops.mesh.primitive_cylinder_add(vertices=n,radius=r,depth=(b-a).length,location=(a+b)/2);o=bpy.context.object;o.rotation_mode='QUATERNION';o.rotation_quaternion=(b-a).to_track_quat('Z','Y');return finish(o,name,mat)
def group(name,parts):
 o=bpy.data.objects.new(name,None);bpy.context.collection.objects.link(o)
 for p in parts:p.parent=o
 return o

def blade(name,a,b,width,mat,curve=.025):
 a,b=Vector(a),Vector(b);axis=(b-a).normalized();side=axis.cross(Vector((0,1,0)))
 if side.length<.01:side=Vector((1,0,0))
 side.normalize();pts=[];faces=[];steps=8
 for k in range(steps+1):
  t=k/steps;c=a.lerp(b,t)+Vector((0,curve*math.sin(t*math.pi),0));w=width*math.sin(t*math.pi)**.8
  pts.extend([tuple(c-side*w),tuple(c+Vector((0,w*.18,0))),tuple(c+side*w)])
 for k in range(steps):
  for i in range(2):j=k*3+i;faces.append((j,j+1,j+4,j+3))
 o=mesh(name,pts,faces,mat);bpy.context.view_layer.objects.active=o;mod=o.modifiers.new('Leaf edge thickness','SOLIDIFY');mod.thickness=.002;bpy.ops.object.modifier_apply(modifier=mod.name);return o

def grain(a,b,width,mat):
 a,b=Vector(a),Vector(b);axis=(b-a).normalized();side=axis.cross(Vector((0,0,1))).normalized();normal=axis.cross(side).normalized();pts=[];faces=[];n=8;rows=6
 for k in range(rows+1):
  t=k/rows;c=a.lerp(b,t);r=width*max(.015,math.sin(t*math.pi)**.72)
  for j in range(n):
   angle=j*math.tau/n;pts.append(tuple(c+side*r*math.cos(angle)+normal*r*.65*math.sin(angle)))
 for k in range(rows):
  for j in range(n):
   i=k*n+j;next=k*n+(j+1)%n;faces.append((i,next,next+n,i+n))
 return mesh('Sculpted wheat grain',pts,faces,mat)

parts=[]
# Two original square-foot beds fit the saved 3 x 2 footprint; complete crop
# silhouettes stay below the existing .65 m definition height.
for x in [-.72,.72]:
 parts.append(box('Dark soil',(x,.232,0),(1.13,.12,1.62),'Soil',.035))
 for z in [-.84,.84]:
  parts.append(box('End plank',(x,.16,z),(1.25,.27,.075),'Timber',.023))
  parts.append(box('Hand worn top rail',(x,.296,z),(1.28,.045,.095),'TimberLight',.014))
 for side in [-1,1]:
  parts.append(box('Side plank',(x+side*.60,.16,0),(.075,.27,1.65),'Timber',.02))
  parts.append(box('Top side rail',(x+side*.60,.296,0),(.095,.045,1.68),'TimberLight',.014))
  for z in [-.77,.77]:
   parts.append(box('Corner joint',(x+side*.57,.15,z),(.095,.29,.095),'TimberLight',.018))
   for y in [.11,.22]:parts.append(rod('Iron peg',(x+side*.57,y,z-.052),(x+side*.57,y,z+.052),.009,'Iron',8))
 for z in [-.48,0,.48]:
  parts.append(box('Cultivated soil ridge',(x,.299,z),(1.04,.018,.09),'SoilLight',.008))
# A low, carved sprout sign is inside the same height/footprint.
parts.append(rod('Garden sign stake',(1.30,0,-.64),(1.30,.58,-.64),.022,'Timber'))
parts.append(box('Garden sign',(1.30,.55,-.64),(.30,.18,.035),'TimberLight',.025))
parts.append(blade('Carved sprout',(1.30,.50,-.617),(1.23,.57,-.617),.02,'Leaf',0))
parts.append(blade('Carved sprout',(1.30,.50,-.617),(1.37,.59,-.617),.018,'Leaf',0))
group('GardenBeds',parts)
# Joint-local wheat clusters use curved stalks and paired, pointed grains.
for stage in range(1,5):
 parts=[];height=[0,.08,.14,.23,.31][stage];mat='WheatGold' if stage==4 else 'WheatGreen'
 for j in range(3 if stage>=3 else 2):
  x=(j-1)*.035;z=(j%2)*.028;lean=.015*(j-1);path=[(x+lean*(k/6)**2,height*k/6,z) for k in range(7)]
  for k in range(6):parts.append(rod('Curved wheat stalk',path[k],path[k+1],.006,mat,8))
  for side in [-1,1]:parts.append(blade('Wheat blade',(x,height*.35,z),(x+side*.075,height*.68,z+.02),.012,mat,.018))
  if stage>=3:
   for row in range(4):
    y=height-.028-row*.022
    for side in [-1,1]:
     parts.append(grain((x+lean,y-.016,z),(x+lean+side*.035,y+.022,z+.003),.016,'WheatLight' if stage==4 and row%2==0 else mat))
     if stage==4:parts.append(rod('Fine wheat awn',(x+lean+side*.023,y+.014,z),(x+lean+side*.035,y+.054,z),.0012,'WheatLight',6))
 group('Wheat'+str(stage),parts)
parts=[]
for j in range(7):
 a=j*math.tau/7;parts.append(blade('Folded kitchen leaf',(0,.014,0),(math.cos(a)*.15,.045+(j%2)*.025,math.sin(a)*.15),.055,'LeafLight' if j%3 else 'Leaf',.045))
for j in range(4):
 a=j*math.tau/4;parts.append(blade('Inner cabbage heart',(0,.02,0),(math.cos(a)*.07,.14,math.sin(a)*.07),.035,'LeafLight',.025))
group('Greens',parts)
# Lobed apple with flattened base and a recessed crown, sculpted as one surface.
pts=[];faces=[];n=32;rows=20
for k in range(rows+1):
 t=k*math.pi/rows;y=.126*math.cos(t);radius=.126*math.sin(t)
 for j in range(n):
  a=j*math.tau/n;r=radius*(1+.035*math.cos(5*a))
  yy=y-.028*math.exp(-(t/.30)**2)+.012*math.exp(-((t-math.pi)/.27)**2)
  pts.append((r*math.cos(a),yy,r*math.sin(a)))
for k in range(rows):
 for j in range(n):a=k*n+j;b=k*n+(j+1)%n;faces.append((a,b,b+n,a+n))
parts=[mesh('Dimpled apple',pts,faces,'AppleSkin'),rod('Apple stem',(0,.095,0),(.018,.16,.006),.009,'Stem')]
parts.append(blade('Apple leaf',(.012,.145,.005),(.09,.155,.026),.024,'Leaf',.015));group('Apple',parts)
# Split firewood: irregular polygonal bark and visible nested end grain.
parts=[]
for row in range(2):
 for j in range(3-row):
  x=-.32+j*.32+row*.16;y=.16+row*.27;r=.145;n=12;pts=[]
  for z in [-.63,.63]:
   for k in range(n):
    a=k*math.tau/n;rr=r*(1+.07*math.sin(k*2.4+j));pts.append((x+rr*math.cos(a),y+rr*math.sin(a),z))
  faces=[tuple(range(n-1,-1,-1)),tuple(n+k for k in range(n))]+[(k,(k+1)%n,(k+1)%n+n,k+n) for k in range(n)]
  parts.append(mesh('Polygonal bark',pts,faces,'Bark' if j%2 else 'BarkLight'))
  for z in [-.635,.635]:
   parts.append(rod('Cut end grain',(x,y,z-.003),(x,y,z+.003),r*.87,'EndGrain',16))
   for radius in [.052,.088]:
    for k in range(12):
     a=k*math.tau/12;b=(k+1)*math.tau/12
     parts.append(rod('Growth ring',(x+radius*math.cos(a),y+radius*math.sin(a),z+.004),(x+radius*math.cos(b),y+radius*math.sin(b),z+.004),.002,'Timber',6))
group('WoodPile',parts)
# A batard loaf: broad middle, tucked ends, flat baked base and open scoring.
pts=[];faces=[];n=32;rows=24
for k in range(rows+1):
 t=k/rows;x=(t-.5)*.64;radius=math.sin(t*math.pi)**.45
 for j in range(n):
  a=j*math.tau/n;y=max(.012,.075+.10*math.sin(a))*radius+.012
  pts.append((x,y,.14*math.cos(a)*radius))
for k in range(rows):
 for j in range(n):a=k*n+j;b=k*n+(j+1)%n;faces.append((a,b,b+n,a+n))
parts=[mesh('Hand shaped loaf',pts,faces,'Crust')]
for x in [-.16,0,.16]:
 path=[]
 for k in range(13):
  t=k/12;z=-.105+.21*t;xx=x+(t-.5)*.075;yy=.077+.10*math.sqrt(max(0,1-(z/.14)**2))
  path.append((xx,yy+.004,z))
 for k in range(12):parts.append(rod('Open score',path[k],path[k+1],.008,'BreadScore',8))
group('Bread',parts)
# Consolidate each reusable part by surface, with neutral underside vertex paint.
for root in [o for o in list(bpy.context.scene.objects) if o.type=='EMPTY']:
 for mat in M.values():
  objects=[o for o in list(root.children) if o.type=='MESH' and o.data.materials[0]==mat]
  if not objects:continue
  bpy.ops.object.select_all(action='DESELECT')
  for o in objects:o.select_set(True)
  bpy.context.view_layer.objects.active=objects[0]
  if len(objects)>1:bpy.ops.object.join()
  o=bpy.context.object;o.name=root.name+'_'+mat.name
  colors=o.data.color_attributes.new(name='Color',type='BYTE_COLOR',domain='CORNER')
  for poly in o.data.polygons:
   for loop in poly.loop_indices:
    shade=.94+.06*max(0,o.data.vertices[o.data.loops[loop].vertex_index].normal.z);colors.data[loop].color=(shade,shade,shade,1)
output=Path(os.environ.get('TUVLO_HARVEST_OUTPUT',str(Path(__file__).resolve().parents[1]/'Godot/assets/harvest/cozy_harvest.glb')));output.parent.mkdir(parents=True,exist_ok=True)
bpy.ops.export_scene.gltf(filepath=str(output),export_format='GLB',export_yup=True,export_materials='EXPORT',export_vertex_color='ACTIVE',export_all_vertex_colors=True,export_cameras=False,export_lights=False)
print('Tuvlo original harvest art:',output,output.stat().st_size)
