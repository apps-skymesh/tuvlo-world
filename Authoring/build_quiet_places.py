"""Original pond, reading nook and treehouse. Blender --background --python.
Reuse the cottage xyz conversion and farm craft helpers; no external art.
"""
import bpy,math,random,sys
from pathlib import Path
from mathutils import Vector
sys.dont_write_bytecode=True
sys.path.insert(0,str(Path(__file__).resolve().parent))
import build_farm_buildings as craft
from build_farm_buildings import box,mesh,rod,rings,arch,roof,gable,beam,group,xyz
rng=random.Random(7419)
for name,h in {'PondWater':'72aeb1','PondBank':'9b9d70','WetSand':'9baf98','SandShelf':'c5bc91','StoneWarm':'b9b79e','StoneCool':'8d9b91','StoneMoss':'859776','LilyDark':'547b51','PetalLight':'f2debf','FlowerHeart':'d8b468','WetStone':'8d9b90','Bank':'acac86','Leaf':'6f955a','LeafLight':'94ae69','LeafGold':'b4b873','Lily':'7d9e67','Petal':'e7c29c','Fabric':'c9879d','Paper':'f0e1b9','BookBlue':'648e88','BookRed':'ba8068','BookGold':'d4b165','BookPlum':'a58ba0','TreehouseRoof':'d2b267'}.items():
 m=bpy.data.materials.new(name);m.use_nodes=True;c=tuple(craft.srgb(int(h[i:i+2],16)/255) for i in (0,2,4))+(1,)
 m.diffuse_color=c;m.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=c;m.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.88
 craft.M[name]=m

def leaf(name,p,a,length,width,mat,lift=.025):
 p=Vector(p);u=Vector((math.cos(a),.12,math.sin(a)));v=Vector((-math.sin(a),0,math.cos(a)))
 pts=[p-u*length*.5,p-u*length*.2+v*width,p+u*length*.3+v*width*.65,p+u*length*.5,p+u*length*.3-v*width*.65,p-u*length*.2-v*width,p+Vector((0,lift,0))]
 return mesh(name,[tuple(q) for q in pts],[(i,(i+1)%6,6) for i in range(6)],mat)

def outline(radius_x,radius_z,n=64):
 return [(math.cos(a)*radius_x*(1+.065*math.sin(a*3)+.025*math.cos(a*5)),math.sin(a)*radius_z*(1+.05*math.sin(a*3))) for a in [j*math.tau/n for j in range(n)]]

def pond():
 prng=random.Random(9327)
 n=80
 # A small cove interrupts the shoreline; the broad front shelf stays open.
 def shore(a):
  dent=.16*math.exp(-((math.atan2(math.sin(a-.65),math.cos(a-.65)))/.33)**2)
  r=1+.105*math.sin(3*a+.4)+.055*math.cos(2*a-.8)-dent
  return (math.cos(a)*1.04*r-.035,math.sin(a)*.94*r-.025)
 shape=[shore(j*math.tau/n) for j in range(n)]
 def ribbon(name,sections,mat):
  pts=[(x*q,y,z*q) for q,y in sections for x,z in shape]
  faces=[]
  for ring in range(len(sections)-1):
   for j in range(n):
    nxt=(j+1)%n;faces.append((ring*n+j,ring*n+nxt,(ring+1)*n+nxt,(ring+1)*n+j))
  return mesh(name,pts,faces,mat)
 ribbon('Sloped grassy bank',[(.86,.022),(1.025,.10),(1.11,.115),(1.19,.008)],'PondBank')
 ribbon('Sandy shallow shelf',[(.78,.025),(.94,.063),(1.025,.099)],'SandShelf')
 ribbon('Damp shoreline',[(.93,.064),(.985,.086),(1.015,.095)],'WetSand')
 # Subdivided surface follows the actual shore. Vertex red is a depth mask,
 # not a painted blue circle; both the mask and radial UVs survive GLB export.
 levels=[.20,.43,.66,.82,.93,1.0]
 pts=[(0,.096,0)]+[(x*q,.096,z*q) for q in levels for x,z in shape]
 depths=[1.0]+[1-q for q in levels for j in range(n)]
 faces=[(0,1+(j+1)%n,1+j) for j in range(n)]
 for ring in range(len(levels)-1):
  for j in range(n):
   k=(j+1)%n;faces.append((1+ring*n+j,1+ring*n+k,1+(ring+1)*n+k,1+(ring+1)*n+j))
 water=mesh('WaterSurface',pts,faces,'PondWater')
 water.data.uv_layers.new(name='WaterUV')
 water.data.color_attributes.new(name='Color',type='BYTE_COLOR',domain='CORNER')
 # Adding a CustomData layer can invalidate Blender's earlier layer wrapper.
 uv=water.data.uv_layers['WaterUV']
 paint=water.data.color_attributes['Color']
 for f in water.data.polygons:
  for index in f.loop_indices:
   vi=water.data.loops[index].vertex_index;v=water.data.vertices[vi].co
   uv.data[index].uv=(.5+v.x/2.8,.5-v.y/2.8)
   paint.data[index].color=(depths[vi],1,1,1)
 def stone(name,x,z,rx,rz,h,mat):
  # Low broad crowns, chipped shoulders and asymmetric profiles avoid beads.
  count=9;pts=[]
  offsets=[prng.uniform(.86,1.08) for _ in range(count)]
  for y,scale in [(.008,.78),(.045,1.0),(h*.76,.97),(h,.65)]:
   for j in range(count):
    a=j*math.tau/count;pts.append((x+math.cos(a)*rx*scale*offsets[j],y,z+math.sin(a)*rz*scale*offsets[j]))
  faces=[tuple(range(count-1,-1,-1)),tuple(3*count+j for j in range(count))]
  for row in range(3):
   for j in range(count):faces.append((row*count+j,row*count+(j+1)%count,(row+1)*count+(j+1)%count,(row+1)*count+j))
  return mesh(name,pts,faces,mat,.012)
 for j,a in enumerate([-2.95,-2.48,-2.06,-.64,-.28,.10,.58,1.96,2.30]):
  x,z=shore(a);x*=1.035;z*=1.035
  stone('Clustered shoreline stone',x,z,prng.uniform(.15,.23),prng.uniform(.12,.19),prng.uniform(.13,.205),['StoneWarm','StoneCool','StoneMoss'][j%3])
 stone('Broad viewing stone',-.39,.99,.31,.19,.13,'StoneWarm')
 stone('Small bank ledge',-.79,.85,.21,.14,.11,'StoneCool')
 for base in [(-.90,-.55),(.81,.56)]:
  for j in range(4):
   x=base[0]+prng.uniform(-.14,.14);z=base[1]+prng.uniform(-.10,.10)
   stone('Shore pebble',x,z,.045+prng.random()*.025,.035+prng.random()*.018,.035+prng.random()*.025,'StoneWarm' if j%2 else 'StoneCool')
 # Low sedges and ground leaves frame two banks without covering a visiting kid.
 for x,z in [(-.83,-.63),(.80,.69),(-1.00,.05)]:
  for j in range(7):
   leaf('Bank sedge',(x+prng.uniform(-.065,.065),.095,z+prng.uniform(-.05,.05)),j*.94,.18+prng.random()*.05,.014,'Leaf' if j%2 else 'LeafGold',.105)
  for j in range(3):leaf('Bank ground leaf',(x,.082,z),j*2.1,.20,.044,'LeafLight',.025)
 before=set(bpy.context.scene.objects)
 for index,(x,z,r,a) in enumerate([(-.40,.17,.23,.25),(-.67,.31,.14,1.25),(.46,-.39,.17,-.6)]):
  angles=[a+.20+j*(math.tau-.40)/32 for j in range(33)]
  points=[(x,.128,z)]+[(x+r*math.cos(t),.128,z+r*.78*math.sin(t)) for t in angles]
  mesh('Notched floating lily',points,[(0,j+1,j) for j in range(1,33)],'Lily' if index==0 else 'LilyDark')
  # A single sculpted bloom is the focal detail, with a folded double corolla.
  if index==0:
   for tier,count,length,lift in [(0,9,.135,.055),(1,7,.085,.065)]:
    for j in range(count):leaf('Folded water lily petal',(x,.153+tier*.014,z),j*math.tau/count+tier*.28,length,.024,'PetalLight' if j%3 else 'Petal',lift)
   rings('Warm flower heart',[(.181,.035,.035,x,z),(.218,.027,.027,x,z)],'FlowerHeart',12)
 group('Lilies',[o for o in bpy.context.scene.objects if o not in before])
 before=set(bpy.context.scene.objects)
 for x,z in [(.56,-.65),(.76,-.49)]:
  for j in range(8):leaf('Low marsh blade',(x+prng.uniform(-.05,.05),.11,z+prng.uniform(-.04,.04)),1.1+j*.43,.20,.016,'Leaf' if j%2 else 'LeafGold',.11)
 group('MarshPlants',[o for o in bpy.context.scene.objects if o not in before])


def book(p,size,mat):
 x,y,z=p;w,h,d=size
 box('Book cover',(x,y,z),(w,h,d),mat,.009)
 box('Layered paper',(x+.008,y+.006,z+.012),(w*.87,h*.76,d*.91),'Paper',.004)
 box('Colored book spine',(x,y,z+d/2+.004),(w,h,.018),mat,.004)
 for v in [-.22,0,.22]:box('Page edges',(x+w*.45,y+v*h,z+.01),(.005,.006,d*.83),'Cloth',.002)

def nook():
 box('Nook stone terrace',(0,.055,0),(1.88,.11,1.86),'StoneLight',.06)
 for x in [-.58,.58]:
  for z in [-.28,.27]:box('Bench foot',(x,.27,z),(.11,.38,.12),'Timber',.02)
 box('Seat apron',(0,.43,0),(1.48,.12,.75),'TimberLight',.035)
 for x in [-.68,.68]:box('Back upright',(x,.76,-.32),(.095,.82,.10),'Timber',.02)
 for y in [.78,1.01]:box('Curved back slat',(0,y,-.34),(1.46,.15,.10),'TimberLight',.035)
 for x in [-.34,.34]:box('Soft seat cushion',(x,.535,.015),(.65,.13,.61),'Fabric',.07)
 for side in [-1,1]:
  box('Arm rest',(side*.70,.74,.04),(.13,.10,.76),'TimberLight',.035)
  box('Arm support',(side*.70,.60,.29),(.09,.26,.10),'Timber',.018)
 box('Bookcase back',(-.73,.69,-.80),(.39,1.12,.055),'Timber',.018)
 for x in [-.92,-.54]:box('Open bookcase side',(x,.69,-.64),(.045,1.12,.32),'TimberLight',.012)
 for y in [.26,.70,1.15]:box('Bookcase shelf',(-.73,y,-.58),(.42,.055,.41),'Trim',.012)
 for i,mat in enumerate(['BookBlue','BookRed','BookGold','BookPlum']):book((-.86+i*.085,.91,-.57),(.065,.33,.25),mat)
 for i,mat in enumerate(['BookGold','BookBlue']):book((-.73,.36+i*.11,-.57),(.28,.075,.27),mat)
 before=set(bpy.context.scene.objects)
 # An open, folded paper book rests on the cushion, rather than a flat icon.
 for side in [-1,1]:
  pts=[(.13,.625,.03),(.13+side*.23,.66,.03),(.13+side*.23,.66,.35),(.13,.625,.35)]
  mesh('Open book pages',pts,[(0,1,2,3)],'Paper')
  rod('Book cover rim',pts[1],pts[2],.008,'BookRed',8)
 for z in [.10,.17,.24,.30]:rod('Printed page line',(.16,.637,z),(.32,.663,z),.003,'Cloth',6)

 group('SeatBook',[o for o in bpy.context.scene.objects if o not in before])

def treehouse():
 rings('Rooted treehouse trunk',[(0,.28,.25,-.95,.68),(.22,.25,.23,-.95,.65),(1.8,.19,.18,-.98,.45),(3.5,.12,.11,-1.02,-.25),(4.3,.035,.03,-.65,-.48)],'Timber',16)
 for j in range(5):
  a=j*math.tau/5;beam('Spreading root',(-.95,.12,.68),(-.95+.30*math.cos(a),.035,.68+.30*math.sin(a)),.12,.10,'Timber')
 for side in [-1,1]:
  rod('Canopy branch',(-1.02,2.75,.10),(side*.70,4.18,-.52),.085,'Timber',12)
  beam('Deck knee brace',(-.96,1.10,.55),(side*.95,1.99,.42),.11,.12,'Timber')
 box('Raised deck',(0,2.04,0),(2.60,.17,2.48),'Timber',.045)
 for j in range(11):box('Deck boards',(-1.17+j*.234,2.145,0),(.223,.05,2.38),'TimberLight',.009)
 for x in [-1.17,1.17]:
  for z in [-1.08,1.08]:box('Deck railing post',(x,2.51,z),(.09,.77,.09),'Timber',.02)
  for y in [2.42,2.76]:box('Side guardrail',(x,y,0),(.065,.07,2.20),'Trim',.014)
 for x in [-.83,.83]:
  for y in [2.42,2.76]:box('Open ladder guardrail',(x,y,1.08),(.66,.07,.065),'Trim',.014)
 box('Cabin walls',(0,2.76,-.17),(1.58,1.20,1.41),'Plaster',.05)
 gable('Cabin front gable',0,-.17,1.58,1.41,3.36,3.89,'Plaster')
 roof('Treehouse shingle',0,-.17,1.89,1.72,3.36,3.96,'TreehouseRoof')
 for x in [-.76,.76]:box('Cabin corner',(x,2.75,.55),(.09,1.23,.07),'Trim',.018)
 arch('Cabin doorway',-.22,2.17,.565,.61,1.08,.06,'Timber')
 arch('Cabin door',-.22,2.20,.607,.49,.99,.035,'Door')
 rod('Round door latch',(-.07,2.64,.637),(-.07,2.64,.65),.025,'Brass')
 arch('Reading window frame',.48,2.62,.565,.34,.52,.06,'Trim')
 arch('Reading window glass',.48,2.65,.606,.25,.40,.02,'Glass')
 box('Window sill',(.48,2.62,.64),(.41,.06,.15),'TimberLight',.012)
 for x in [-.36,.36]:beam('Ladder side',(x,.04,1.39),(x,2.17,1.13),.075,.07,'Timber')
 for j in range(8):
  y=.17+j*.25;z=1.39-(y-.04)/2.13*.26
  box('Ladder rung',(0,y,z),(.78,.065,.11),'Trim',.018)
 before=set(bpy.context.scene.objects)
 for cluster,(cx,cy,cz) in enumerate([(-.85,4.0,-.52),(.80,4.02,-.55),(-.35,4.38,-.63),(.35,4.40,-.72),(-.88,3.53,-.70)]):
  for j in range(48):
   a=rng.random()*math.tau;r=rng.random()**.5*.43
   x=max(-1.20,min(1.20,cx+math.cos(a)*r));z=max(-1.20,min(.20,cz+math.sin(a)*r))
   y=cy+(rng.random()-.5)*.26
   leaf('Shaped canopy leaf',(x,y,z),a,.33+rng.random()*.15,.09,['Leaf','LeafLight','LeafGold'][(j+cluster)%3],.045)
 group('Canopy',[o for o in bpy.context.scene.objects if o not in before])

output_root=Path(__file__).resolve().parents[1]/'Godot/assets'
models=[('pond',pond),('nook',nook),('treehouse',treehouse)]
requested=set(sys.argv[sys.argv.index('--')+1:]) if '--' in sys.argv else set()
craft.export_models([entry for entry in models if not requested or entry[0] in requested],output_root)
