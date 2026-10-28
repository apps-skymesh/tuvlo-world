"""Original joint-local homestead companions. Blender --background --python.
Godot Y-up via cottage xyz(); named matte materials and vertex paint, no textures.
"""
import bpy, math, sys
from pathlib import Path
from mathutils import Vector
sys.dont_write_bytecode=True
sys.path.insert(0,str(Path(__file__).resolve().parent))
import build_farm_buildings as craft
from build_farm_buildings import mesh, rings as craft_rings, rod, group, xyz

for name,h in {'GoldenCoat':'c49963','WarmEar':'967047','CreamFur':'ecdbb7',
 'Fleece':'eee2c5','FleeceShadow':'d4c5a6','SheepFace':'a18e70',
 'Hoof':'746756','Nose':'38483e','EyeWhite':'f3e8d3','Iris':'795c3c',
 'Pupil':'293c34','EyeGlint':'fff5df','Collar':'6b9582','Tag':'d6b367'}.items():
 m=bpy.data.materials.new(name);m.use_nodes=True
 c=tuple(craft.srgb(int(h[i:i+2],16)/255) for i in (0,2,4))+(1,)
 m.diffuse_color=c;m.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=c
 m.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.8 if name!='EyeGlint' else .35
 craft.M[name]=m

def rings(name,rows,mat,n=32):
 return craft_rings(name,[(r[0],r[1],r[2],0,r[3]) if len(r)==4 else r for r in rows],mat,n)

def smooth(o,level=1):
 bpy.context.view_layer.objects.active=o
 mod=o.modifiers.new('Sculpted contours','SUBSURF');mod.levels=level
 bpy.ops.object.modifier_apply(modifier=mod.name)
 return o

def oval(name,p,size,mat,wool=False):
 pts=[];faces=[];n=36 if wool else 24;rows=22 if wool else 14
 for j in range(rows+1):
  v=math.pi*j/rows
  for i in range(n):
   u=i*math.tau/n
   ripple=1+(.035*math.sin(u*9+math.sin(v*7))*math.sin(v*11) if wool else 0)
   pts.append((p[0]+size[0]*math.sin(v)*math.cos(u)*ripple,p[1]+size[1]*math.cos(v)*ripple,p[2]+size[2]*math.sin(v)*math.sin(u)*ripple))
 for j in range(rows):
  for i in range(n):
   a=j*n+i;b=j*n+(i+1)%n;faces.append((a,b,b+n,a+n))
 return mesh(name,pts,faces,mat)

def body(dog):
 pts=[];faces=[];n=64;rows=36
 # One continuous chest-to-haunch surface; sheep curls are sculpted into it.
 for j in range(rows+1):
  t=math.pi*j/rows;z=math.cos(t)*(.36 if dog else .40)
  for i in range(n):
   a=i*math.tau/n;s=math.sin(t)
   curl=0 if dog else .018*math.sin(a*11+math.sin(t*9))*math.sin(t*16)
   rx=(.245 if dog else .32)*s+curl*s
   ry=(.225 if dog else .29)*s+curl*s
   pts.append((rx*math.cos(a),(.43 if dog else .47)+ry*math.sin(a)+(.025*math.cos(t) if dog else 0),z))
 for j in range(rows):
  for i in range(n):
   a=j*n+i;b=j*n+(i+1)%n;faces.append((a,b,b+n,a+n))
 return mesh('Sculpted chest and haunches' if dog else 'Continuous curled fleece',pts,faces,'GoldenCoat' if dog else 'Fleece')

def sweep(name,points,radii,mat):
 pts=[];faces=[];n=12
 for j,p in enumerate(points):
  p=Vector(p);t=(Vector(points[min(j+1,len(points)-1)])-Vector(points[max(0,j-1)])).normalized()
  u=t.cross(Vector((1,0,0))).normalized();v=t.cross(u).normalized()
  for i in range(n):
   a=i*math.tau/n;pts.append(tuple(p+radii[j]*(u*math.cos(a)+v*math.sin(a))))
 for j in range(len(points)-1):
  for i in range(n):
   a=j*n+i;b=j*n+(i+1)%n;faces.append((a,b,b+n,a+n))
 faces.extend([tuple(range(n-1,-1,-1)),tuple((len(points)-1)*n+i for i in range(n))])
 return mesh(name,pts,faces,mat)

def eyes(dog):
 for side,label in [(-1,'Left'),(1,'Right')]:
  before=set(bpy.context.scene.objects)
  oval('Warm ivory eye',(0,0,0),(.038,.044,.024),'EyeWhite')
  oval('Chestnut iris',(side*-.003,-.003,.020),(.022,.030,.010),'Iris')
  oval('Deep pupil',(side*-.003,-.003,.028),(.013,.023,.005),'Pupil')
  oval('Eye catchlight',(-.007,.010,.032),(.007,.009,.003),'EyeGlint')
  group('Eye'+label,[o for o in bpy.context.scene.objects if o not in before],(side*.102,.065,.145 if dog else .135))

def ears(dog):
 for side,label in [(-1,'Left'),(1,'Right')]:
  before=set(bpy.context.scene.objects)
  if dog:
   smooth(rings('Soft folded ear',[(.035,.025,.028,0),(0,.064,.038,0),(-.09,.077,.041,.008),(-.20,.061,.033,.035),(-.255,.032,.022,.045),(-.265,.008,.008,.043)],'WarmEar',24))
   oval('Ear inner fold',(0,-.12,.066),(.040,.075,.007),'GoldenCoat')
  else:
   # A broad horizontal ear, tapered at its outer tip.
   oval('Soft outward sheep ear',(side*.065,0,0),(.13,.055,.043),'SheepFace')
   oval('Ear inner velvet',(side*.065,0,.037),(.086,.032,.007),'CreamFur')
  ear=group('Ear'+label,[o for o in bpy.context.scene.objects if o not in before],(side*.19,.105,-.015))
  ear.rotation_euler.y=side*(-.24 if dog else -.18)

def animal(dog):
 before=set(bpy.context.scene.objects)
 body(dog)
 if dog:
  smooth(rings('Cream chest bib',[(.25,.06,.025,.269),(.32,.115,.025,.292),(.46,.13,.035,.287),(.55,.085,.026,.26),(.58,.03,.018,.24)],'CreamFur',24))
 group('Body',[o for o in bpy.context.scene.objects if o not in before])
 for x in [-.17,.17]:
  for z in [-.23,.22]:
   smooth(rings('Tapered leg',[(.05,.04,.046,x,z),(.10,.047,.052,x,z),(.22,.043,.046,x,z-.015),(.32,.065,.068,x,z-.018),(.39,.075,.071,x,z-.02)],'GoldenCoat' if dog else 'SheepFace',20))
   smooth(rings('Rounded paw' if dog else 'Soft cloven hoof',[(.012,.044,.061,x,z+.015),(.024,.062,.082,x,z+.025),(.07,.064,.077,x,z+.022),(.10,.041,.046,x,z)],'CreamFur' if dog else 'Hoof',20))
   for dx in ([-.02,.02] if dog else [0]):
    rod('Toe seam',(x+dx,.035,z+.096),(x+dx,.064,z+.090),.0035,'WarmEar' if dog else 'FleeceShadow',8)
 before=set(bpy.context.scene.objects)
 smooth(rings('Sculpted cheeks and brow',[(-.18,.045,.055,-.01),(-.14,.12,.10,0),(-.07,.184,.152,0),(.035,.202,.173,-.01),(.14,.178,.147,-.025),(.21,.105,.09,-.025),(.23,.03,.025,-.02)],'GoldenCoat' if dog else 'SheepFace',36))
 smooth(rings('Tapered soft muzzle',[(-.125,.04,.045,.175),(-.105,.105,.067,.186),(-.065,.123,.079,.189),(-.02,.094,.067,.177),(.01,.04,.035,.15)],'CreamFur' if dog else 'SheepFace',32))
 oval('Velvet nose',(0,-.041,.255),(.053,.031,.024) if dog else (.036,.022,.017),'Nose')
 rod('Muzzle center',(0,-.068,.253),(0,-.09,.251),.004,'WarmEar',8)
 for side in [-1,1]:
  sweep('Quiet smile',[(0,-.09,.251),(side*.027,-.101,.249),(side*.055,-.095,.245)],[.0035,.0035,.002],'WarmEar')
  if dog:
   for dx,dy in [(.061,-.047),(.082,-.064),(.05,-.076)]:oval('Muzzle freckle',(side*dx,dy,.257),(.004,.004,.002),'WarmEar')
 if not dog: oval('Curled forehead fleece',(0,.17,-.035),(.183,.087,.14),'Fleece',True)
 eyes(dog);ears(dog)
 # Only top-level newly-created pieces belong to the head; retain eye/ear pivots.
 group('Head',[o for o in bpy.context.scene.objects if o not in before and o.parent is None],(0,.63 if dog else .61,.265))
 before=set(bpy.context.scene.objects)
 if dog:
  points=[(0,0,0),(.025,.04,-.08),(.06,.09,-.16),(.11,.15,-.21),(.16,.18,-.22),(.19,.185,-.20)]
  smooth(sweep('Soft curved tail',points,[.063,.061,.052,.042,.028,.009],'GoldenCoat'))
  oval('Cream tail tip',(.175,.18,-.209),(.025,.026,.023),'CreamFur')
 else:
  smooth(sweep('Short wool tail',[(0,0,0),(0,-.015,-.04),(0,-.055,-.07),(0,-.09,-.06)],[.052,.046,.033,.008],'Fleece'))
 group('Tail',[o for o in bpy.context.scene.objects if o not in before],(0,.43,-.32))
 if dog:
  # Collar follows the chest rather than cutting across the muzzle.
  pts=[(math.cos(i*math.tau/48)*.175,.505+math.sin(i*math.tau/48)*.14,.25) for i in range(49)]
  sweep('Woven sage collar',pts,[.018]*49,'Collar')
  oval('Small brass tag',(0,.365,.278),(.034,.040,.010),'Tag')

craft.export_models([('dog',lambda:animal(True)),('sheep',lambda:animal(False))],Path(__file__).resolve().parents[1]/'Godot/assets')
