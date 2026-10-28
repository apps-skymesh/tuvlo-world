"""Original landscape miniatures. Blender --background --python; cottage xyz().
All placed props fit their existing building square; no downloaded art/textures.
"""
import bpy,math,random,sys
from pathlib import Path
from mathutils import Vector
sys.dont_write_bytecode=True
sys.path.insert(0,str(Path(__file__).resolve().parent))
import build_farm_buildings as craft
from build_farm_buildings import mesh,rod,rings,group
for name,h in {'GroveBark':'987451','BarkLight':'b29970','BirchBark':'d1c7a3',
 'BarkMark':'81795f','GroveLeaf':'6a8c59','GroveLeafLight':'91a766','GroveLeafGold':'b2b579',
 'PineLeaf':'527d60','PineLight':'7d9970','PathStone':'c4bba0','PathLight':'d7c8a7',
 'PathShadow':'a9ad94','CreviceMoss':'82936a','Stem':'698558','LeafVein':'a7b67b',
 'PetalCream':'f0dfad','PetalPeach':'dbaa8b','PetalBlue':'9caac4','Pollen':'c8a258',
 'RockWarm':'b7b49d','RockCool':'949f92','RockFace':'c9c1a5','RockMoss':'889673'}.items():
 m=bpy.data.materials.new(name);m.use_nodes=True
 c=tuple(craft.srgb(int(h[i:i+2],16)/255) for i in (0,2,4))+(1,)
 m.diffuse_color=c;m.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=c
 m.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.9
 craft.M[name]=m

def leaf(name,p,angle,length,width,mat,lift=.025):
 p=Vector(p);u=Vector((math.cos(angle),0,math.sin(angle)));v=Vector((-u.z,0,u.x))
 pts=[p-u*length*.5,p-u*length*.18+v*width,p+u*length*.27+v*width*.68,p+u*length*.5,p+u*length*.27-v*width*.68,p-u*length*.18-v*width,p+Vector((0,lift,0))]
 return mesh(name,[tuple(q) for q in pts],[(i,(i+1)%6,6) for i in range(6)],mat)

def stone(name,p,rx,rz,height,mat,seed,bevel=.012,sculpt=False):
 rng=random.Random(seed);n=8;pts=[]
 profile=[(.003,.72),(.20*height,.98),(.64*height,1),(.95*height,.65),(height,.16)] if sculpt else [(.003,.78),(.025,1),(.78*height,.95),(height,.65)]
 radii=[rng.uniform(.88,1.08) for _ in range(n)]
 for y,scale in profile:
  for j in range(n):
   a=j*math.tau/n;pts.append((p[0]+rx*scale*radii[j]*math.cos(a)+(y*.12 if sculpt else 0),p[1]+y,p[2]+rz*scale*radii[j]*math.sin(a)))
 faces=[tuple(range(n-1,-1,-1)),tuple((len(profile)-1)*n+j for j in range(n))]
 for k in range(len(profile)-1):
  for j in range(n):faces.append((k*n+j,k*n+(j+1)%n,(k+1)*n+(j+1)%n,(k+1)*n+j))
 o=mesh(name,pts,faces,mat,0 if sculpt else bevel)
 if sculpt:
  bpy.context.view_layer.objects.active=o
  mod=o.modifiers.new('Soft weathered rock edges','BEVEL');mod.width=.016;mod.segments=3
  bpy.ops.object.modifier_apply(modifier=mod.name)
  if mat=='RockWarm':
   o.data.materials.append(craft.M['RockMoss'])
   for face in o.data.polygons:
    c=face.center
    if c.z>height*.58 and c.y>-p[2]+.08 and c.x<p[0]+.06:face.material_index=1
 return o

def tree(variant):
 rng=random.Random(812+variant)
 bark='BirchBark' if variant==1 else 'GroveBark'
 height=3.12 if variant==1 else 2.78 if variant==2 else 2.28
 rings('Bent tapered trunk',[(.006,.095,.082,0,0),(.16,.10,.085,0,0),(.9,.066,.062,-.025,.01),(1.7,.046,.043,.025,-.015),(height*.83,.026,.023,-.02,0),(height,.006,.006,.01,0)],bark,16)
 for j in range(4):
  a=j*math.tau/4+.4
  rod('Root flare',(0,.11,0),(.18*math.cos(a),.018,.18*math.sin(a)),.027,bark,10)
 if variant==1:
  for j in range(9):
   y=.34+j*.18
   rod('Soft birch bark mark',(-.035,y,.067),(.015+(j%3)*.009,y+.012,.062),.008,'BarkMark',8)
 before=set(bpy.context.scene.objects)
 if variant<2:
  for b in range(12):
   a=b*2.399;cy=(1.78+b*.108) if variant==1 else (1.39+(b//3)*.25);cx=math.cos(a)*(.20 if b<9 else .12);cz=math.sin(a)*(.18 if b<9 else .10)
   # Keep branches static under the trunk; the leaf crown gets its own pivot.
   branch=rod('Forked branch',(0,cy-.26,0),(cx,cy,cz),.019 if b<5 else .012,bark,10)
   before.add(branch)
   for j in range(34):
    t=j*2.4;radius=.16*math.sqrt(rng.random())
    x=max(-.36,min(.36,cx+math.cos(t)*radius));z=max(-.36,min(.36,cz+math.sin(t)*radius))
    y=cy-1.65+(rng.random()-.4)*.20
    leaf('Shaped grove leaf',(x,y,z),t,.18 if variant==0 else .15,.052 if variant==0 else .065,['GroveLeaf','GroveLeafLight','GroveLeafGold'][(j+b)%3],.025)
 else:
  for level in range(9):
   cy=.72+level*.24;radius=.43-level*.046
   for j in range(7):
    a=j*math.tau/7+level*.5;u=Vector((math.cos(a),0,math.sin(a)));v=Vector((-u.z,0,u.x))
    p=Vector((0,cy-1.65,0))
    # A scalloped, drooping frond, rather than stacked cones or spheres.
    pts=[p,p+u*radius*.55+v*.11,p+u*radius+v*.06+Vector((0,-.11,0)),p+u*(radius+.025)+Vector((0,-.16,0)),p+u*radius-v*.06+Vector((0,-.11,0)),p+u*radius*.55-v*.11,p+u*radius*.42+Vector((0,.035,0))]
    mesh('Layered pine frond',[tuple(q) for q in pts],[(k,(k+1)%6,6) for k in range(6)],'PineLeaf' if (j+level)%3 else 'PineLight')
 if variant==2:
  for j in range(5):leaf('Soft pine tip',(0,1.03,0),j*math.tau/5,.16,.027,'PineLight',.07)
 group('Crown',[o for o in bpy.context.scene.objects if o not in before],(0,1.65,0))

def path():
 for i,(x,z,rx,rz) in enumerate([(-.065,-.035,.27,.25),(-.30,.29,.16,.17),(.23,.28,.18,.18),(.20,-.32,.19,.12),(-.30,-.27,.14,.16)]):
  stone('Worn fitted paver',(x,0,z),rx,rz,.065+(i%2)*.009,['PathStone','PathLight','PathShadow'][i%3],400+i,.012)
 for j,(x,z) in enumerate([(-.04,-.42),(-.37,.02),(.38,.43),(.37,-.05)]):
  for k in range(3):leaf('Moss in stone seam',(x,.018,z),j+k*2,.075,.018,'CreviceMoss',.01)
 # A quiet chip at the edge adds scale without making the path raised or busy.
 stone('Small worn chip',(.035,0,.40),.05,.047,.035,'PathStone',541,.006)

def flowers():
 before=set(bpy.context.scene.objects)
 for j,(x,z,y) in enumerate([(-.25,-.22,.39),(.16,-.22,.48),(-.04,.03,.57),(.29,.12,.35),(-.27,.23,.43),(.08,.29,.40)]):
  rod('Bent flower stem',(x,0,z),(x-.025,y*.55,z+.015),.010,'Stem',8)
  rod('Bent flower stem',(x-.025,y*.55,z+.015),(x,y,z),.008,'Stem',8)
  for side in [-1,1]:leaf('Folded stem leaf',(x+side*.035,y*.38,z),j+side,.16,.041,'GroveLeaf',.035)
  count=6 if j%3==0 else 5
  for petal in range(count):
   a=petal*math.tau/count;u=Vector((math.cos(a),0,math.sin(a)));v=Vector((-u.z,0,u.x));p=Vector((x,y,z))
   pts=[];faces=[]
   for row in range(7):
    t=row/6;r=.012+.106*t;w=.052*math.sin(math.pi*t)**.55
    for col in range(5):
     q=(col-2)/2
     pts.append(tuple(p+u*r+v*w*q+Vector((0,.005+.040*t*t+.012*q*q*math.sin(math.pi*t),0))))
   for row in range(6):
    for col in range(4):
     k=row*5+col;faces.append((k,k+1,k+6,k+5))
   petal_obj=mesh('Soft curved cup petal',pts,faces,['PetalCream','PetalBlue','PetalPeach'][j%3])
   bpy.context.view_layer.objects.active=petal_obj
   mod=petal_obj.modifiers.new('Petal curvature','SUBSURF');mod.levels=1;bpy.ops.object.modifier_apply(modifier=mod.name)
   mod=petal_obj.modifiers.new('Petal edge','SOLIDIFY');mod.thickness=.002;bpy.ops.object.modifier_apply(modifier=mod.name)
  rings('Warm flower heart',[(y,.025,.025,x,z),(y+.026,.020,.020,x,z),(y+.03,.006,.006,x,z)],'Pollen',12)
 group('Crown',[o for o in bpy.context.scene.objects if o not in before])
 for j in range(7):leaf('Low ground rosette',(-.12,.025,.05),j*.9,.29,.052,'GroveLeafLight',.025)

def rocks():
 stone('Broad softened fieldstone',(-.10,0,-.06),.34,.31,.32,'RockWarm',91,.02,True)
 stone('Cool companion stone',(.29,0,.22),.15,.17,.17,'RockCool',94,.014,True)
 stone('Flat weathered chip',(-.30,0,.32),.11,.12,.09,'RockFace',97,.009,True)


craft.export_models([('grove_tree',lambda:tree(0)),('aspen_tree',lambda:tree(1)),('pine_tree',lambda:tree(2)),('path',path),('flowers',flowers),('rocks',rocks)],Path(__file__).resolve().parents[1]/'Godot/assets')
