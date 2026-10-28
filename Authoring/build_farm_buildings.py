"""Original Tuvlo mill, barn, dog house and grill. Blender --background --python.
Godot Y-up coordinates use the cottage xyz conversion; no external art.
"""
import bpy,bmesh,math,os
from pathlib import Path
from mathutils import Vector
COLORS={'Plaster':'e8d9b7','Stone':'b5ab92','StoneLight':'d3c5a7','Timber':'936b4a','TimberLight':'c39b68','Trim':'f1e4c4','Door':'866149','Glass':'708e88','MillRoof':'668a7d','Clay':'b77455','ClayLight':'cb8d65','BarnRed':'ae6450','BarnLight':'c27e61','Canvas':'e9d9b5','Iron':'53665f','IronDark':'34473f','Steel':'a4aea2','Brass':'c9a65c','Hay':'d9bd77','Cloth':'d2c09a','Water':'9cbbb0'}
def srgb(x):return x/12.92 if x<.04045 else ((x+.055)/1.055)**2.4
M={}
for name,h in COLORS.items():
 m=bpy.data.materials.new(name);m.use_nodes=True;c=tuple(srgb(int(h[i:i+2],16)/255) for i in (0,2,4))+(1,)
 m.diffuse_color=c;m.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=c;m.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.85 if name not in ['Iron','Steel'] else .55;M[name]=m

def xyz(p):return (p[0],-p[2],p[1])
def finish(o,name,mat,bevel=0):
 o.name=name;o.data.materials.append(M[mat]);bpy.context.view_layer.objects.active=o
 if bevel:
  mod=o.modifiers.new('Hand softened edge','BEVEL');mod.width=bevel;mod.segments=3;bpy.ops.object.modifier_apply(modifier=mod.name)
 for p in o.data.polygons:p.use_smooth=True
 if bevel:
  mod=o.modifiers.new('Weighted normals','WEIGHTED_NORMAL');bpy.ops.object.modifier_apply(modifier=mod.name)
 return o

def box(name,p,size,mat,bevel=.02):
 bpy.ops.mesh.primitive_cube_add(size=1,location=xyz(p));o=bpy.context.object;o.dimensions=(size[0],size[2],size[1]);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);return finish(o,name,mat,bevel)
def mesh(name,pts,faces,mat,bevel=0):
 d=bpy.data.meshes.new(name);d.from_pydata([xyz(p) for p in pts],[],faces);d.update();bm=bmesh.new();bm.from_mesh(d);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(d);bm.free();o=bpy.data.objects.new(name,d);bpy.context.collection.objects.link(o);return finish(o,name,mat,bevel)
def rod(name,a,b,r,mat,n=12):
 a,b=Vector(xyz(a)),Vector(xyz(b));bpy.ops.mesh.primitive_cylinder_add(vertices=n,radius=r,depth=(b-a).length,location=(a+b)/2);o=bpy.context.object;o.rotation_mode='QUATERNION';o.rotation_quaternion=(b-a).to_track_quat('Z','Y');return finish(o,name,mat,.004)
def rings(name,rows,mat,n=32):
 pts=[];faces=[]
 for y,rx,rz,x,z in rows:
  for j in range(n):a=j*math.tau/n;pts.append((x+rx*math.cos(a),y,z+rz*math.sin(a)))
 for k in range(len(rows)-1):
  for j in range(n):a=k*n+j;b=k*n+(j+1)%n;faces.append((a,b,b+n,a+n))
 faces.extend([tuple(range(n-1,-1,-1)),tuple((len(rows)-1)*n+j for j in range(n))]);return mesh(name,pts,faces,mat)
def arch(name,x,base,z,width,height,depth,mat):
 r=width/2;outline=[(-r,0),(r,0)]+[(math.cos(j*math.pi/16)*r,height-r+math.sin(j*math.pi/16)*r) for j in range(17)];n=len(outline)
 pts=[(x+a,base+b,z+d) for d in [-depth/2,depth/2] for a,b in outline]
 return mesh(name,pts,[tuple(range(n-1,-1,-1)),tuple(n+j for j in range(n))]+[(j,(j+1)%n,(j+1)%n+n,j+n) for j in range(n)],mat,.012)
def roof(name,cx,cz,width,depth,eave,peak,mat='Clay'):
 # Slightly curved tiled slopes, with separate material for existing look IDs.
 for side in [-1,1]:
  for row in range(4):
   for col in range(8):
    a=row/4;b=(row+1)/4;z0=cz-depth/2+col*depth/8;z1=z0+depth/8-.012;pts=[]
    for lower in [0,.055]:
     for z in [z0,z1]:
      for t in [a,b]:pts.append((cx+side*t*width/2,peak-(peak-eave)*t-.04*math.sin(t*math.pi)-lower,z))
    mesh(name,pts,[(0,1,3,2),(4,6,7,5),(0,4,5,1),(2,3,7,6),(0,2,6,4),(1,5,7,3)],mat if mat!='Clay' else 'ClayLight' if (row+col)%5==0 else 'Clay',.008)
 rod('Rounded ridge',(cx,peak+.015,cz-depth/2),(cx,peak+.015,cz+depth/2),.035,'TimberLight')
def gable(name,cx,cz,width,depth,base,peak,mat):
 pts=[(cx+x,y,cz+z) for z in [-depth/2,depth/2] for x,y in [(-width/2,base),(width/2,base),(0,peak)]]
 return mesh(name,pts,[(0,2,1),(3,4,5),(0,1,4,3),(1,2,5,4),(2,0,3,5)],mat,.012)
def group(name,parts,pos=(0,0,0)):
 root=bpy.data.objects.new(name,None);bpy.context.collection.objects.link(root);root.location=xyz(pos)
 for o in parts:o.parent=root
 return root

def windmill():
 rings('Stone octagonal plinth',[(0,1.15,1.15,0,0),(.18,1.18,1.18,0,0),(.24,1.10,1.10,0,0)],'Stone',16)
 rings('Tapered plaster tower',[(.20,.91,.91,0,0),(.32,.89,.89,0,0),(2.80,.59,.59,0,0),(2.88,.57,.57,0,0)],'Plaster',32)
 for j in range(8):
  a=j*math.tau/8;rod('Tower upright',(.88*math.sin(a),.27,.88*math.cos(a)),(.59*math.sin(a),2.85,.59*math.cos(a)),.026,'TimberLight')
 for y,r in [(.31,.88),(2.70,.61)]:
  for j in range(32):
   a=j*math.tau/32;b=(j+1)*math.tau/32;rod('Timber hoop',(r*math.cos(a),y,r*math.sin(a)),(r*math.cos(b),y,r*math.sin(b)),.024,'TimberLight',8)
 rings('Curved mill cap',[(2.84,.84,.84,0,0),(2.94,.85,.85,0,0),(3.15,.65,.65,0,0),(3.39,.39,.39,0,0),(3.53,.05,.05,0,0)],'MillRoof',32)
 for j in range(8):
  a=j*math.tau/8;rod('Cap seam',(.81*math.cos(a),2.97,.81*math.sin(a)),(.03*math.cos(a),3.54,.03*math.sin(a)),.012,'Timber')
 arch('Door frame',0,.22,.89,.66,1.15,.08,'Trim');arch('Planked mill door',0,.25,.942,.53,1.06,.035,'Door')
 for x in [-.16,0,.16]:box('Door seam',(x,.70,.968),(.015,.72,.012),'TimberLight',.004)
 rod('Brass latch',(.12,.68,.98),(.18,.68,.98),.015,'Brass')
 box('Doorstep',(0,.16,1.00),(.82,.18,.45),'StoneLight',.04)
 for side in [-1,1]:
  arch('Mill window frame',side*.49,1.64,.60,.26,.46,.06,'Trim');arch('Mill glass',side*.49,1.67,.64,.19,.36,.018,'Glass')
  rod('Window mullion',(side*.49,1.69,.66),(side*.49,1.98,.66),.009,'Trim')
 before=set(bpy.context.scene.objects)
 for arm in range(4):
  a=arm*math.pi/2;u=Vector((math.sin(a),math.cos(a),0));v=Vector((math.cos(a),-math.sin(a),0))
  rod('Sail spoke',tuple(u*.10),tuple(u*1.43),.027,'Timber')
  pts=[tuple(u*r+v*w+Vector((0,0,z))) for z in [-.025,.025] for r,w in [(.45,-.025),(.45,.27),(1.39,.37),(1.39,-.025)]]
  mesh('Tapered sail canvas',pts,[(0,1,2,3),(4,7,6,5),(0,4,5,1),(1,5,6,2),(2,6,7,3),(3,7,4,0)],'Canvas',.012)
  for r in [.48,.77,1.06,1.36]:rod('Sail batten',tuple(u*r+v*(-.04)+Vector((0,0,.034))),tuple(u*r+v*(.28+.08*(r-.45))+Vector((0,0,.034))),.012,'TimberLight',8)
 rod('Rotor hub',(0,0,-.07),(0,0,.13),.105,'Brass',16)
 group('Rotor',[o for o in bpy.context.scene.objects if o not in before],(0,2.45,1.08))
 for x,z in [(-.80,.65),(.80,.65)]:
  rings('Flour sack',[(.21,.17,.14,x,z),(.27,.23,.18,x,z),(.52,.21,.16,x,z),(.61,.10,.08,x,z),(.65,.11,.08,x,z)],'Cloth',20)
  rod('Sack tie',(x-.11,.61,z),(x+.11,.61,z),.012,'Timber')

def barn():
 box('Barn stone foundation',(-.25,.12,-.45),(3.45,.24,2.05),'Stone',.07)
 box('Barn timber body',(-.25,1.13,-.56),(3.08,1.96,1.65),'BarnRed',.045)
 gable('Barn gable',-.25,-.56,3.08,1.65,2.11,3.18,'BarnRed')
 for x in range(12):box('Front plank seam',(-1.69+x*.262,1.18,.282),(.024,1.87,.022),'BarnLight',.006)
 for side in [-1,1]:
  for z in range(7):box('Side plank seam',(-.25+side*1.548,1.14,-1.30+z*.25),(.024,1.85,.023),'BarnLight',.006)
 roof('Individual clay barn tile',-.25,-.52,3.46,1.95,2.17,3.25)
 for x in [-1.78,1.28]:box('Cream corner trim',(x,1.14,.31),(.12,2.00,.09),'Trim',.018)
 box('Door lintel',(-.53,1.88,.34),(1.48,.12,.12),'Trim',.018)
 for side in [-1,1]:
  box('Barn door',(-.53+side*.32,.98,.34),(.61,1.63,.08),'Door',.018)
  for x in [-.61,.61]:box('Door upright',(-.53+x,.98,.40),(.07,1.66,.06),'Trim',.01)
  rod('Cross braced door',(-.53+side*.58,.20,.415),(-.53,1.76,.415),.025,'Trim')
  rod('Door pull',(-.53+side*.08,.92,.44),(-.53+side*.08,1.08,.44),.012,'Iron')
 arch('Hayloft frame',-.53,2.13,.32,.62,.63,.07,'Trim');arch('Hayloft shutter',-.53,2.17,.37,.49,.50,.04,'Glass')
 for x in [-1.65,1.65]:box('Pen post',(x,.42,1.18),(.10,.84,.10),'Timber',.02)
 for y in [.36,.63]:box('Pen rail',(0,y,1.18),(3.40,.065,.065),'TimberLight',.016)
 box('Feed bin',(-1.4,.24,.73),(.52,.36,.45),'Timber',.04);box('Wheat feed',(-1.4,.425,.73),(.43,.025,.36),'Hay',.025)

def doghouse():
 box('Kennel stone pad',(-.35,.065,-.28),(1.26,.13,1.27),'Stone',.05)
 # Real open front: side/back walls and an upper gable leave the doorway clear.
 box('Kennel floor',(-.35,.17,-.28),(1.10,.12,1.10),'TimberLight',.03)
 for side in [-1,1]:box('Kennel side',(-.35+side*.48,.57,-.28),(.13,.75,1.03),'Timber',.025)
 box('Kennel back',(-.35,.57,-.77),(1.0,.75,.10),'Timber',.03)
 gable('Kennel front gable',-.35,-.28,1.11,1.15,.94,1.27,'TimberLight')
 roof('Kennel clay shingle',-.35,-.28,1.26,1.28,.94,1.32,'MillRoof')
 arch('Door shadow',-.35,.22,-.65,.68,.67,.02,'IronDark')
 for side in [-1,1]:box('Door trim',(-.35+side*.34,.54,.28),(.075,.62,.06),'Trim',.02)
 box('Kennel lintel',(-.35,.83,.28),(.73,.10,.06),'Trim',.035)
 box('Soft bed',(-.35,.25,-.20),(.72,.10,.68),'Canvas',.08)
 box('Paw plaque',(-.35,1.02,.32),(.38,.14,.045),'Trim',.04)
 for x in [-.46,-.24]:rod('Paw carving',(x,1.025,.346),(x,1.025,.355),.025,'Timber',12)
 rings('Water bowl',[(.02,.19,.19,.62,-.60),(.06,.20,.20,.62,-.60),(.16,.17,.17,.62,-.60)],'Iron',24)
 rings('Still bowl water',[(.135,.135,.135,.62,-.60),(.14,.135,.135,.62,-.60)],'Water',24)

def grill():
 box('Grill stone pad',(0,.045,0),(1.80,.09,1.65),'Stone',.06)
 for x in [-.65,.43]:
  for z in [-.42,.42]:rod('Splayed grill leg',(x,.14,z),(x*.77,.83,z*.75),.035,'Iron')
 rings('Shaped enamel bowl',[(.66,.28,.22,-.15,0),(.72,.50,.40,-.15,0),(.89,.65,.51,-.15,0),(1.02,.65,.51,-.15,0)],'Iron',32)
 rings('Dark grill bed',[(.99,.59,.45,-.15,0),(1.01,.59,.45,-.15,0)],'IronDark',32)
 for j in range(9):
  x=-.66+j*.128;z=.42*math.sqrt(max(0,1-((x+.15)/.59)**2));rod('Steel cooking grate',(x,1.035,-z),(x,1.035,z),.011,'Steel')
 box('Timber side shelf',(.66,.96,0),(.41,.07,.86),'TimberLight',.028)
 for z in [-.24,0,.24]:box('Shelf seam',(.66,1.0,z),(.34,.008,.008),'Timber',.003)
 # A low open wind hood leaves the grill visible under the 1.4 m limit.
 pts=[];faces=[];n=24
 for y in [.98,1.25]:
  for j in range(n+1):a=math.pi+j*math.pi/n;pts.append((-.15+.63*math.cos(a),y,.51*math.sin(a)))
 for j in range(n):faces.append((j,j+1,j+n+2,j+n+1))
 o=mesh('Open grill wind hood',pts,faces,'Iron');bpy.context.view_layer.objects.active=o;m=o.modifiers.new('Enamel wall','SOLIDIFY');m.thickness=.025;bpy.ops.object.modifier_apply(modifier=m.name)
 rod('Cool front handle',(-.43,.91,.57),(.13,.91,.57),.022,'Timber')
 for z in [-.4,.4]:rod('Wheel axle',(-.69,.16,z-.035),(-.69,.16,z+.035),.13,'IronDark',20)
 box('Folded cloth',(.65,1.015,.18),(.27,.028,.29),'Canvas',.02)

output_root=Path(os.environ.get('TUVLO_FARM_OUTPUT',str(Path(__file__).resolve().parents[1]/'Godot/assets')))
for name,build in [('windmill',windmill),('barn',barn),('doghouse',doghouse),('grill',grill)]:
 bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False);build()
 # Keep Rotor as an articulated group while consolidating all matte surfaces.
 roots=[None]+[o for o in list(bpy.context.scene.objects) if o.type=='EMPTY']
 for root in roots:
  for mat in M.values():
   objects=[o for o in list(bpy.context.scene.objects) if o.type=='MESH' and o.parent==root and o.data.materials[0]==mat]
   if not objects:continue
   bpy.ops.object.select_all(action='DESELECT')
   for o in objects:o.select_set(True)
   bpy.context.view_layer.objects.active=objects[0]
   if len(objects)>1:bpy.ops.object.join()
   o=bpy.context.object;o.name=(root.name if root else name)+'_'+mat.name
   colors=o.data.color_attributes.new(name='Color',type='BYTE_COLOR',domain='CORNER')
   for f in o.data.polygons:
    for loop in f.loop_indices:
     v=o.matrix_world@o.data.vertices[o.data.loops[loop].vertex_index].co;shade=.93+.07*min(1,max(0,v.z/3));colors.data[loop].color=(shade,shade,shade,1)
 out=output_root/name/('cozy_'+name+'.glb');out.parent.mkdir(parents=True,exist_ok=True)
 bpy.ops.export_scene.gltf(filepath=str(out),export_format='GLB',export_yup=True,export_materials='EXPORT',export_vertex_color='ACTIVE',export_all_vertex_colors=True,export_cameras=False,export_lights=False)
 print('Original farm building:',name,out.stat().st_size)
