"""Original Tuvlo house extension (A70 step 2): the outdoor kitchen bench and the
front porch. Blender --background --python this_file. Godot X/Y-up/Z-front
helpers, converted for glTF. No external models, textures or network access.
Kitchen envelope: 2 x 2 squares, 2.45 high. Porch: 2.4 wide, 1.1 deep, 2.5 high.
"""
import bpy, bmesh, math, random
from pathlib import Path
from mathutils import Vector
rng = random.Random(70211)
COLORS = {
 'plaster':'efdfbd','trim':'faf0d5','stone':'b9b4a2','stoneLight':'d5cbb2','stoneDark':'9c9683',
 'wood':'8b6148','woodLight':'b98a5b','woodPale':'d3aa72','woodDark':'6e4a33','endGrain':'e0c08a',
 'roof':'bd7559','roofLight':'cb8966','roofShade':'aa624d',
 'teal':'648c80','tealLight':'7ca092','canvas':'f3e6c6','copper':'c47a4a','copperLight':'e0a172',
 'brass':'d8b66a','iron':'535e58','glass':'f6d9a0','clay':'b56f51','clayLight':'cc8c64',
 'leaf':'658258','leafLight':'8da36b','apple':'c9473b','carrot':'e0873a','bread':'d79a52','breadLight':'ecc07f',
 'wicker':'c99c5e','wickerDark':'a67a44','cloth':'e6d2b0','clothCheck':'c46a55','jar':'d9e6dd','jam':'b0454a','honey':'e3a23b','flour':'f4ecd8',
 'cushion':'7ca092','petal':'e8b0a0','petalLight':'f3d2c4','soil':'625646'
}
def srgb(v): return v/12.92 if v<.04045 else ((v+.055)/1.055)**2.4
def build_materials():
 M={}
 for name,h in COLORS.items():
  m=bpy.data.materials.new(name);m.use_nodes=True;c=tuple(srgb(int(h[i:i+2],16)/255) for i in (0,2,4))+(1,)
  b=m.node_tree.nodes['Principled BSDF'];b.inputs['Base Color'].default_value=c
  b.inputs['Roughness'].default_value=.38 if name in ('copper','copperLight','brass','jar','glass') else .82
  if name in ('copper','copperLight','brass'): b.inputs['Metallic'].default_value=.55
  m.diffuse_color=c;M[name]=m
 return M
def xyz(p): return (p[0],-p[2],p[1])
def finish(o,name,mat,bevel=0):
 o.name=name;o.data.materials.append(M[mat]);bpy.context.view_layer.objects.active=o
 if bevel:
  m=o.modifiers.new('Soft','BEVEL');m.width=bevel;m.segments=3;bpy.ops.object.modifier_apply(modifier=m.name)
 for p in o.data.polygons: p.use_smooth=True
 n=o.modifiers.new('Weighted','WEIGHTED_NORMAL');n.keep_sharp=True;n.weight=50;bpy.ops.object.modifier_apply(modifier=n.name)
 return o
def box(name,p,s,mat,bevel=.02):
 bpy.ops.mesh.primitive_cube_add(size=1,location=xyz(p));o=bpy.context.object;o.dimensions=(s[0],s[2],s[1]);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);return finish(o,name,mat,bevel)
def rod(name,a,b,r,mat,n=14,bevel=.004):
 a,b=Vector(xyz(a)),Vector(xyz(b));bpy.ops.mesh.primitive_cylinder_add(vertices=n,radius=r,depth=(b-a).length,location=(a+b)/2);o=bpy.context.object;o.rotation_mode='QUATERNION';o.rotation_quaternion=(b-a).to_track_quat('Z','Y');return finish(o,name,mat,bevel)
def ball(name,p,s,mat,seg=16):
 bpy.ops.mesh.primitive_uv_sphere_add(segments=seg,ring_count=max(8,seg//2),radius=1,location=xyz(p));o=bpy.context.object;o.scale=(s[0],s[2],s[1]);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);return finish(o,name,mat)
def cone(name,p,r1,r2,h,mat,n=16):
 bpy.ops.mesh.primitive_cone_add(vertices=n,radius1=r1,radius2=r2,depth=h,location=xyz((p[0],p[1]+h/2,p[2])));return finish(bpy.context.object,name,mat,.004)
def turned_post(name,x,z,y0,y1,mat):
 # A lathe profile: base, slim shaft with beads, capital.
 prof=[(0,y0),(.085,y0),(.085,y0+.05),(.065,y0+.09),(.055,y0+.30),(.07,y0+.34),(.05,y0+.38),(.045,y1-.30),(.065,y1-.26),(.05,y1-.20),(.05,y1-.08),(.08,y1-.05),(.08,y1),(0,y1)]
 pts=[];faces=[];n=20
 for (r,y) in prof:
  for j in range(n):
   a=j*math.tau/n;pts.append((x+r*math.cos(a),y,z+r*math.sin(a)))
 for i in range(len(prof)-1):
  for j in range(n):
   a=i*n+j;b=i*n+(j+1)%n;faces.append((a,b,b+n,a+n))
 d=bpy.data.meshes.new(name);d.from_pydata([xyz(p) for p in pts],[],faces);d.update();bm=bmesh.new();bm.from_mesh(d);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(d);bm.free()
 o=bpy.data.objects.new(name,d);bpy.context.collection.objects.link(o);return finish(o,name,mat)
def wicker_basket(x,y,z,r,h,lid):
 rod('Basket body',(x,y,z),(x,y+h,z),r,'wicker',18)
 for k in range(4): rod('Basket weave',(x,y+.02+k*h/4,z),(x,y+.035+k*h/4,z),r+.006,'wickerDark',18,.002)
 ball('Basket cloth',(x,y+h,z),(r*.95,.035,r*.95),lid,14)
 bpy.ops.mesh.primitive_torus_add(major_radius=r*.62,minor_radius=.012,location=xyz((x,y+h+.07,z)));o=bpy.context.object;o.rotation_euler=(0,0,0);o.rotation_euler[0]=math.pi/2;bpy.ops.object.transform_apply(rotation=True);finish(o,'Basket handle','wickerDark')
def consolidate(prefix):
 for mat in M.values():
  objs=[o for o in list(bpy.context.scene.objects) if o.type=='MESH' and o.data.materials and o.data.materials[0]==mat]
  if not objs: continue
  bpy.ops.object.select_all(action='DESELECT')
  for o in objs: o.select_set(True)
  bpy.context.view_layer.objects.active=objs[0]
  if len(objs)>1: bpy.ops.object.join()
  o=bpy.context.object;o.name=prefix+mat.name
  col=o.data.color_attributes.new(name='Color',type='BYTE_COLOR',domain='CORNER')
  for f in o.data.polygons:
   for li in f.loop_indices:
    v=o.matrix_world@o.data.vertices[o.data.loops[li].vertex_index].co;sh=.9+.1*min(1,max(0,v.z/2.4));col.data[li].color=(sh,sh,sh,1)
def export(name):
 out=Path(__file__).resolve().parents[1]/('Godot/assets/house/'+name+'.glb');out.parent.mkdir(parents=True,exist_ok=True)
 bpy.ops.export_scene.gltf(filepath=str(out),export_format='GLB',export_yup=True,export_materials='EXPORT',export_vertex_color='ACTIVE',export_all_vertex_colors=True,export_cameras=False,export_lights=False)
 print('Tuvlo house extension:',out,out.stat().st_size)
def reset():
 bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
 for m in list(bpy.data.materials): bpy.data.materials.remove(m)
 return build_materials()

# ---------- Kitchen bench ----------
M=reset()
box('Stone plinth',(0,.06,0),(1.86,.12,1.62),'stone',.05)
for i in range(7):
 box('Plinth edge stone',(-.80+i*.267,.135,.79),(.25,.05,.09),'stoneLight' if i%2 else 'stoneDark',.015)
for sx in (-1,1):
 for sz in (-1,1):
  box('Bench leg',(sx*.78,.52,sz*.34+.12),(.11,.78,.11),'woodDark',.02)
box('Lower shelf',(0,.34,.12),(1.62,.05,.72),'wood',.012)
box('Apron',(0,.82,.50),(1.62,.10,.05),'woodLight',.012)
# Butcher-block worktop: alternating staves with end grain.
for i in range(12):
 box('Worktop stave',(-.825+i*.15,.93,.12),(.148,.10,.90),'woodPale' if i%2 else 'woodLight',.01)
box('Worktop front edge',(0,.93,.575),(1.80,.10,.02),'endGrain',.006)
# Back splash and shelf.
for i in range(6): box('Back plank',(-.75+i*.30,1.42,-.36),(.29,.90,.05),'wood' if i%2 else 'woodLight',.01)
box('Spice shelf',(0,1.55,-.27),(1.70,.04,.20),'woodDark',.01)
box('Top shelf',(0,1.88,-.27),(1.70,.04,.20),'woodDark',.01)
for sx in (-.70,0,.70): box('Shelf bracket',(sx,1.50,-.30),(.04,.10,.14),'woodDark',.01)
# Jars on the spice shelf.
for i,(fill) in enumerate(['jam','honey','flour','jam','honey','flour','jam']):
 x=-.66+i*.22;rod('Glass jar',(x,1.57,-.27),(x,1.74,-.27),.055,'jar',16);rod('Jar filling',(x,1.575,-.27),(x,1.69,-.27),.048,fill,16)
 rod('Jar lid',(x,1.74,-.27),(x,1.765,-.27),.058,'clothCheck' if i%2 else 'cloth',16)
# Herb pots on the top shelf.
for i in range(4):
 x=-.60+i*.40;cone('Terracotta pot',(x,1.90,-.27),.075,.10,.13,'clay');ball('Herbs',(x,2.10,-.27),(.13,.11,.12),'leafLight' if i%2 else 'leaf',14)
# Rail with hanging copper pans and ladles.
rod('Hanging rail',(-.78,1.32,-.30),(.78,1.32,-.30),.012,'brass')
for i,x in enumerate([-.55,-.20,.20,.55]):
 rod('Hook',(x,1.32,-.29),(x,1.22,-.27),.006,'iron',8)
 if i%2==0:
  rod('Copper pan',(x,1.10,-.25),(x,1.13,-.25),.11,'copper',22);rod('Pan rim',(x,1.13,-.25),(x,1.14,-.25),.115,'copperLight',22)
 else:
  rod('Ladle handle',(x,1.22,-.27),(x,1.02,-.25),.01,'copper',8);ball('Ladle bowl',(x,1.0,-.24),(.05,.03,.05),'copperLight',12)
# Worktop dressing: board, loaf, rolling pin, flour bowl, knife.
box('Cutting board',(-.42,1.0,.18),(.55,.035,.34),'endGrain',.012)
ball('Loaf',(-.45,1.07,.18),(.16,.07,.09),'bread',18);ball('Loaf crust',(-.45,1.10,.18),(.13,.035,.075),'breadLight',14)
for k in range(3): box('Loaf score',(-.52+k*.07,1.13,.18),(.012,.008,.08),'bread',.002)
rod('Rolling pin',(.05,1.02,.32),(.48,1.02,.32),.03,'woodLight',16);rod('Pin handle',(-.03,1.02,.32),(.05,1.02,.32),.015,'woodDark');rod('Pin handle',(.48,1.02,.32),(.56,1.02,.32),.015,'woodDark')
cone('Mixing bowl',(.45,.98,.02),.09,.17,.11,'tealLight',24);ball('Flour in bowl',(.45,1.09,.02),(.15,.03,.15),'flour',16)
ball('Apple',(.18,1.03,-.05),(.045,.045,.045),'apple',12);ball('Apple',(.25,1.03,.02),(.045,.045,.045),'apple',12)
# Lower shelf: pantry baskets and a produce crate.
wicker_basket(-.52,.37,.12,.18,.20,'clothCheck')
wicker_basket(-.05,.37,.12,.16,.18,'cloth')
box('Produce crate',(.48,.47,.12),(.42,.20,.36),'woodLight',.01)
for k in range(3): box('Crate slat',(.48,.40+k*.065,.305),(.42,.03,.01),'woodDark',.004)
for k in range(5): ball('Apple',(.34+k*.07,.60,.06+(k%2)*.10),(.045,.045,.045),'apple',12)
for k in range(3): cone('Carrot',(.40+k*.09,.57,.22),.022,.002,.13,'carrot',10)
# Pergola with a striped canvas awning.
for sx in (-1,1): box('Pergola post',(sx*.86,1.30,-.48),(.09,2.40,.09),'woodDark',.015)
box('Pergola beam',(0,2.46,-.48),(1.95,.10,.10),'wood',.015)
stripes=8
for i in range(stripes):
 x0=-.95+i*1.9/stripes;x1=x0+1.9/stripes
 pts=[(x0,2.48,-.50),(x1,2.48,-.50),(x1,2.12,.55),(x0,2.12,.55),(x0,2.50,-.50),(x1,2.50,-.50),(x1,2.14,.55),(x0,2.14,.55)]
 d=bpy.data.meshes.new('Awning stripe');d.from_pydata([xyz(p) for p in pts],[],[(0,1,2,3),(7,6,5,4),(0,4,5,1),(1,5,6,2),(2,6,7,3),(3,7,4,0)]);d.update()
 o=bpy.data.objects.new('Awning stripe',d);bpy.context.collection.objects.link(o);finish(o,'Awning stripe','teal' if i%2 else 'canvas')
for i in range(stripes):
 x=-.95+(i+.5)*1.9/stripes;ball('Scallop',(x,2.10,.56),(.11,.06,.02),'teal' if i%2 else 'canvas',12)
rod('Awning arm',(-.86,2.0,-.45),(-.86,2.12,.52),.012,'iron');rod('Awning arm',(.86,2.0,-.45),(.86,2.12,.52),.012,'iron')
# Lantern.
rod('Lantern chain',(.70,2.12,.40),(.70,1.92,.40),.006,'iron',8)
box('Lantern cap',(.70,1.90,.40),(.13,.03,.13),'brass',.01);box('Lantern glass',(.70,1.80,.40),(.10,.16,.10),'glass',.01);box('Lantern base',(.70,1.71,.40),(.12,.02,.12),'brass',.006)
consolidate('Kitchen_');export('kitchen_bench')

# ---------- Front porch ----------
M=reset()
for i in range(2):
 box('Porch step',(0,.06+i*.10,.85-i*.22),(1.30-i*.10,.10,.30),'stoneLight' if i else 'stone',.03)
box('Porch deck',(0,.24,0),(2.30,.07,1.05),'woodLight',.012)
for i in range(9): box('Deck board seam',(-1.02+i*.255,.276,0),(.008,.004,1.0),'woodDark',.001)
for sx in (-1,1): turned_post('Turned porch post',sx*1.02,.42,.27,2.21,'trim')
# Canopy: a lean-to roof from the cottage wall (back, high) to the posts (front, low),
# a solid sloped base with overlapping rows of tiles in the cottage's colours.
back_z,front_z,back_y,front_y,width=-.55,.80,2.62,2.20,2.56
def slope_y(z): return back_y+(front_y-back_y)*(z-back_z)/(front_z-back_z)
def slab(name,x0,x1,z0,z1,lift,thick,mat):
 pts=[(x0,slope_y(z0)+lift,z0),(x1,slope_y(z0)+lift,z0),(x1,slope_y(z1)+lift,z1),(x0,slope_y(z1)+lift,z1)]
 pts+= [(x,y-thick,z) for x,y,z in pts]
 d=bpy.data.meshes.new(name);d.from_pydata([xyz(p) for p in pts],[],[(0,1,2,3),(7,6,5,4),(0,4,5,1),(1,5,6,2),(2,6,7,3),(3,7,4,0)]);d.update()
 bm=bmesh.new();bm.from_mesh(d);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(d);bm.free()
 o=bpy.data.objects.new(name,d);bpy.context.collection.objects.link(o);return finish(o,name,mat,.008)
slab('Canopy base',-width/2,width/2,back_z,front_z+.04,0,.07,'roofShade')
rows=6;depth=(front_z-back_z)/rows
for r in range(rows):
 z0=back_z+r*depth-.02;z1=z0+depth+.05
 n=10;w=width/n
 for i in range(n+1):
  x0=-width/2+i*w-(w/2 if r%2 else 0);x1=x0+w-.012
  x0=max(x0,-width/2);x1=min(x1,width/2)
  if x1-x0<.04: continue
  slab('Roof tile',x0,x1,z0,z1,.03+.012*(r%2),.035,['roof','roofLight','roofShade'][(i+r)%3])
slab('Ridge flashing',-width/2,width/2,back_z-.04,back_z+.10,.07,.05,'trim')
box('Canopy fascia',(0,front_y-.02,front_z+.04),(width+.04,.10,.06),'trim',.012)
box('Canopy beam',(0,front_y-.10,.42),(2.30,.10,.10),'wood',.012)
for sx in (-1,1): rod('Brace',(sx*1.02,1.86,.42),(sx*.78,front_y-.14,.42),.025,'trim')
# Cushioned bench and flower boxes.
box('Bench seat',(-.62,.62,-.18),(.86,.06,.32),'wood',.012);box('Bench back',(-.62,.92,-.33),(.86,.36,.04),'woodLight',.012)
for sx in (-.98,-.26): box('Bench leg',(sx,.43,-.18),(.05,.34,.28),'woodDark',.01)
box('Seat cushion',(-.62,.68,-.17),(.80,.06,.28),'cushion',.03)
for k in range(2): ball('Throw pillow',(-.88+k*.5,.80,-.27),(.12,.10,.05),'tealLight' if k else 'petal',12)
for sx in (-1,1):
 box('Flower box',(sx*.95,.38,.62),(.40,.18,.20),'teal',.02);box('Box soil',(sx*.95,.48,.62),(.36,.02,.16),'soil',.005)
 for k in range(5):
  x=sx*.95-.15+k*.075;ball('Leaf',(x,.52,.62),(.055,.035,.06),'leaf',10);ball('Petal cluster',(x,.57,.62+(k%2-.5)*.05),(.035,.03,.035),'petal' if k%2 else 'petalLight',10)
# Hanging lantern and doormat.
rod('Lantern chain',(.45,2.28,.30),(.45,1.98,.30),.006,'iron',8)
box('Lantern cap',(.45,1.96,.30),(.12,.03,.12),'brass',.01);box('Lantern glass',(.45,1.86,.30),(.09,.15,.09),'glass',.01)
box('Doormat',(.40,.28,-.30),(.60,.01,.36),'clothCheck',.01)
consolidate('Porch_');export('front_porch')
