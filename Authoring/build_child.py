"""Original articulated child surfaces; Blender --background --python build_child.py.
Godot coordinates and the cottage xyz conversion; no external assets.
Each named part retains the existing resident rig's joint-local dimensions.
"""
import bpy, bmesh, math, os
from pathlib import Path
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
PALETTE={'Skin':'e1b68f','Arm':'dfb38c','Leg':'d9af88','Top':'83a89a','Shorts':'b59562','Leather':'975f48','Canvas':'e8deca','Hair':'695440'}
M={}
def xyz(p): return (p[0],-p[2],p[1])
def srgb(v): return v/12.92 if v<.04045 else ((v+.055)/1.055)**2.4
for name,h in PALETTE.items():
 m=bpy.data.materials.new(name+'_'+h);m.use_nodes=True
 c=tuple(srgb(int(h[i:i+2],16)/255) for i in (0,2,4))+(1,)
 m.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=c
 m.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.84
 m.diffuse_color=c;M[name]=m

def mesh(name,points,faces,mat):
 data=bpy.data.meshes.new(name);data.from_pydata([xyz(p) for p in points],[],faces);data.update()
 bm=bmesh.new();bm.from_mesh(data);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(data);bm.free()
 obj=bpy.data.objects.new(name,data);bpy.context.collection.objects.link(obj);obj.data.materials.append(M[mat])
 for poly in data.polygons:poly.use_smooth=True
 return obj

def rings(name,rows,mat,n=40):
 # Each row: height, half-width, half-depth, forward offset. Continuous surfaces,
 # with a softly squared cross-section for cloth and rounder cheeks/palms.
 points=[];faces=[]
 for y,rx,rz,z in rows:
  for i in range(n):
   a=2*math.pi*i/n;points.append((rx*math.cos(a),y,z+rz*math.sin(a)))
 for r in range(len(rows)-1):
  for i in range(n):
   a=r*n+i;b=r*n+(i+1)%n;faces.append((a,b,b+n,a+n))
 faces.extend([tuple(range(n-1,-1,-1)),tuple((len(rows)-1)*n+i for i in range(n))])
 return mesh(name,points,faces,mat)

def smooth(obj,levels=2):
 bpy.context.view_layer.objects.active=obj
 mod=obj.modifiers.new('Sculpted transitions','SUBSURF');mod.levels=levels
 bpy.ops.object.modifier_apply(modifier=mod.name)
 return obj

def box(name,p,size,mat,bevel):
 bpy.ops.mesh.primitive_cube_add(size=1,location=xyz(p));o=bpy.context.object;o.name=name
 o.dimensions=(size[0],size[2],size[1]);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 o.data.materials.append(M[mat]);bpy.context.view_layer.objects.active=o
 m=o.modifiers.new('Soft stitched edges','BEVEL');m.width=bevel;m.segments=4;bpy.ops.object.modifier_apply(modifier=m.name)
 for f in o.data.polygons:f.use_smooth=True
 m=o.modifiers.new('Weighted normals','WEIGHTED_NORMAL');bpy.ops.object.modifier_apply(modifier=m.name)
 return o

def group(name,parts):
 root=bpy.data.objects.new(name,None);bpy.context.collection.objects.link(root)
 for p in parts:p.parent=root
 return root

# A broad forehead, soft cheek, tapered jaw and tucked chin; facial details stay
# on the native head joint, so blinks, expressions and glasses remain articulated.
face=smooth(rings('Sculpted cheeks',[
 (-.298,.025,.025,-.005),(-.278,.10,.095,0),(-.23,.185,.17,0),
 (-.14,.253,.231,-.008),(-.04,.281,.252,-.014),(.065,.284,.251,-.014),
 (.17,.26,.222,-.015),(.25,.19,.16,-.02),(.294,.07,.06,-.02),(.30,.012,.012,-.02)],'Skin'))
group('Face',[face])
# Shaped fabric has shoulder slope, a fitted neckline and a lightly rolled hem.
shirt=smooth(rings('Tailored shirt',[(.018,.216,.154,0),(.028,.229,.162,0),(.06,.23,.164,0),(.13,.24,.17,0),(.30,.229,.16,0),(.44,.243,.15,0),(.50,.24,.145,0),(.55,.19,.13,0),(.595,.115,.105,0)],'Top'))
group('Shirt',[shirt])
for name,length,rows,mat in [
 ('Sleeve',.27,[(0,.078,.080,0),(-.055,.092,.087,0),(-.16,.088,.081,0),(-.24,.083,.077,0),(-.262,.084,.078,0),(-.272,.077,.073,0)],'Top'),
 ('UpperLeg',.32,[(.02,.095,.10,0),(-.07,.109,.105,.003),(-.24,.097,.092,.006),(-.31,.087,.083,.004),(-.325,.08,.076,0)],'Shorts'),
 ('LowerLeg',.28,[(.01,.071,.073,0),(-.05,.077,.075,0),(-.14,.073,.067,0),(-.23,.059,.056,0),(-.28,.054,.052,0)],'Leg'),
 ('Forearm',.23,[(.01,.06,.062,0),(-.04,.067,.064,0),(-.12,.06,.057,.002),(-.20,.046,.046,.005),(-.235,.043,.043,.008)],'Arm')]:
 group(name,[smooth(rings(name+' sculpt',rows,mat))])
for side,name in [(-1,'RightHand'),(1,'LeftHand')]:
 palm=smooth(rings('Palm',[(-.20,.032,.032,.012),(-.23,.052,.039,.016),(-.275,.055,.043,.022),(-.308,.04,.034,.025),(-.319,.015,.018,.025)],'Arm',24))
 thumb=smooth(rings('Thumb',[(-.216,.012,.017,.022),(-.23,.025,.027,.031),(-.259,.021,.024,.041),(-.277,.009,.012,.047)],'Arm',20))
 for v in thumb.data.vertices:v.co.x+=side*.045
 group(name,[palm,thumb])
# Foot-shaped uppers rather than a rounded block: narrow heel, wide toe, fitted
# cream sole, inset tongue, crossed laces and a small back pull tab.
parts=[]
parts.append(box('Flexible sole',(0,-.089,.045),(.194,.031,.325),'Canvas',.014))
parts.append(smooth(rings('Leather upper',[(-.082,.086,.147,.045),(-.065,.094,.154,.045),(-.028,.091,.151,.043),(.005,.078,.116,.023),(.032,.063,.073,-.021),(.038,.049,.053,-.028)],'Leather',40)))
parts.append(box('Tongue',(0,.021,.047),(.087,.018,.13),'Canvas',.008))
parts.append(box('Heel pull',(0,.02,-.087),(.038,.052,.021),'Canvas',.008))
for z in [.035,.068,.10]:
 for side in [-1,1]:
  lace=box('Crossed cotton lace',(0,.035,z),(.083,.008,.008),'Canvas',.004)
  lace.rotation_euler.z=side*.20
  parts.append(lace)
group('Shoe',parts)
# Hair is a fitted scalp with swept locks and continuous curtains. Style indices
# are the existing saved catalogue IDs; no strand is a stacked sphere.
from mathutils import Vector

def sweep(name,path,widths,mat='Hair',flatten=1):
 pts=[];faces=[];n=10
 for k,p in enumerate(path):
  tangent=Vector(path[min(k+1,len(path)-1)])-Vector(path[max(0,k-1)])
  tangent.normalize();normal=tangent.cross(Vector((0,0,1)))
  if normal.length<.01:normal=tangent.cross(Vector((1,0,0)))
  normal.normalize();binormal=tangent.cross(normal).normalized()
  for i in range(n):
   a=i*2*math.pi/n
   v=Vector(p)+widths[k]*(math.cos(a)*normal+math.sin(a)*binormal*flatten)
   pts.append(tuple(v))
 for k in range(len(path)-1):
  for i in range(n):
   a=k*n+i;b=k*n+(i+1)%n;faces.append((a,b,b+n,a+n))
 faces.extend([tuple(range(n-1,-1,-1)),tuple((len(path)-1)*n+i for i in range(n))])
 return mesh(name,pts,faces,mat)

def cap(style):
 pts=[];faces=[];n=64;rows=20
 for r in range(rows+1):
  for i in range(n):
   a=i*2*math.pi/n;front=max(0,math.sin(a))
   edge=1.68-front*.47+max(0,-math.sin(a))*.35
   if style in [3,4,9]:edge=1.86-front*.61
   if style in [0,1,12]:edge+=front*(.12*math.sin(3*a+.8) if style==0 else .20*math.cos(a+.3))
   t=max(.004,r/rows*edge)
   ripple=1+.014*math.sin(a*17+t*3)*math.sin(t)
   size=(.354,.374,.321) if style==7 else (.302,.323,.278)
   pts.append((size[0]*math.sin(t)*math.cos(a)*ripple,size[1]*math.cos(t)+.009,size[2]*math.sin(t)*math.sin(a)*ripple-.016))
 for r in range(rows):
  for i in range(n):
   a=r*n+i;b=r*n+(i+1)%n;faces.append((a,b,b+n,a+n))
 return mesh('Fitted scalp',pts,faces,'Hair')

for style in range(13):
 locks=[cap(style)]
 if style in [0,1,12]:
  for j in range(6):
   x=-.205+j*.074;path=[]
   for k in range(13):
    t=k/12;path.append((x*(.6+.4*t)+.05*math.sin(t*math.pi),.30-.19*t,.07+.195*t))
   locks.append(sweep('Swept fringe',path,[.012+.022*math.sin(math.pi*k/12) for k in range(13)],flatten=.55))
 if style in [2,7]:
  for row in range(4 if style==7 else 3):
   t=.34+row*.34
   for j in range(14):
    a=(j+row*.5)*2*math.pi/14
    if style==7 and row>=2 and math.sin(a)>.25:continue
    size=(.354,.374,.321) if style==7 else (.302,.323,.278)
    center=Vector((size[0]*math.sin(t)*math.cos(a),size[1]*math.cos(t),size[2]*math.sin(t)*math.sin(a)-.016))
    normal=Vector((center.x,center.y,center.z+.016)).normalized()
    u=normal.cross(Vector((0,1,0))).normalized();v=normal.cross(u).normalized()
    radius=.05 if style==7 else .033
    path=[tuple(center+normal*.002+radius*(math.cos(k*math.pi/9)*u+math.sin(k*math.pi/9)*v)) for k in range(12)]
    locks.append(sweep('Sculpted curl',path,[.011 if style==7 else .009]*12))
 if style in [3,4,9]:
  pts=[];faces=[];n=48;rows=14
  for r in range(rows+1):
   t=r/rows;y=.13-t*(.43 if style==4 else .59)
   for i in range(n+1):
    a=math.pi-.22+i/n*(math.pi+.44)
    width=.274+.032*math.sin(t*math.pi)
    wave=.014*math.sin(t*11+i*.4) if style==9 else .006*math.sin(i*1.1)
    pts.append(((width+wave)*math.cos(a),y+.012*math.sin(i*.9)*t,(.26+wave)*math.sin(a)-.027+.025*t))
  for r in range(rows):
   for i in range(n):
    a=r*(n+1)+i;faces.append((a,a+1,a+n+2,a+n+1))
  curtain=mesh('Flowing hair curtain',pts,faces,'Hair')
  bpy.context.view_layer.objects.active=curtain
  mod=curtain.modifiers.new('Hair hem thickness','SOLIDIFY');mod.thickness=.028
  bpy.ops.object.modifier_apply(modifier=mod.name)
  locks.append(curtain)
 if style in [5,6,8]:
  for side in ([0] if style==5 else [-1,1]):
   for strand in range(3 if style==8 else 1):
    path=[];widths=[]
    for k in range(25):
     t=k/24;spiral=t*math.pi*7+strand*math.pi*2/3
     x=side*(.275+.065*math.sin(t*math.pi)) if side else .025*math.sin(t*math.pi)
     y=.04-.44*t;z=-.17-.13*math.sin(t*math.pi) if side else -.27-.11*math.sin(t*math.pi)
     if style==8:x+=.025*math.cos(spiral);z+=.025*math.sin(spiral)
     path.append((x,y,z));widths.append((.027 if style==8 else .075)*(.75+.25*math.sin(t*math.pi))*(1-.8*t**5))
    locks.append(sweep('Woven braid' if style==8 else 'Tapered ponytail',path,widths))
 if style==10:
  path=[]
  for k in range(65):
   t=k/64;a=t*math.pi*5;r=.09*(1-.8*t)
   path.append((r*math.cos(a),.235+r*math.sin(a),-.248-.08*t))
  locks.append(sweep('Coiled bun',path,[.037]*len(path)))
 if style==11:
  for j in range(5):
   x=-.21+j*.105
   path=[(x,.22,.04),(x*.95,.31,.03),(x*.7+.035,.395,-.015)]
   locks.append(smooth(sweep('Shaped pointed tuft',path,[.065,.043,.002]),1))
 group('Hair'+str(style),locks)

# Combine by part and material: sculpted curls/locks stay one draw surface,
# while each palette surface remains independently recolorable on the rig.
for root in [o for o in bpy.context.scene.objects if o.type=='EMPTY']:
 for material in M.values():
  surfaces=[o for o in list(root.children) if o.type=='MESH' and o.data.materials[0]==material]
  if not surfaces:continue
  bpy.ops.object.select_all(action='DESELECT')
  for o in surfaces:o.select_set(True)
  bpy.context.view_layer.objects.active=surfaces[0]
  if len(surfaces)>1:bpy.ops.object.join()
  bpy.context.object.name=root.name+'_'+material.name

# Monochrome vertex paint gives underside/contact warmth without baking noon
# lighting into the model, and remains neutral under saved palette changes.
for obj in list(bpy.context.scene.objects):
 if obj.type!='MESH':continue
 colors=obj.data.color_attributes.new(name='Color',type='BYTE_COLOR',domain='CORNER')
 for poly in obj.data.polygons:
  for loop in poly.loop_indices:
   n=obj.data.vertices[obj.data.loops[loop].vertex_index].normal
   shade=.95+.05*max(0,n.z)
   colors.data[loop].color=(shade,shade,shade,1)
output=Path(os.environ.get('TUVLO_CHILD_OUTPUT',str(Path(__file__).resolve().parents[1]/'Godot/assets/child/cozy_child_parts.glb')))
output.parent.mkdir(parents=True,exist_ok=True)
bpy.ops.export_scene.gltf(filepath=str(output),export_format='GLB',export_yup=True,export_materials='EXPORT',export_vertex_color='ACTIVE',export_all_vertex_colors=True,export_cameras=False,export_lights=False)
print('Original Tuvlo child parts:',output,output.stat().st_size)
