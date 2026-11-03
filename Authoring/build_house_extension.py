"""Original Tuvlo house extension (A70 step 2): the outdoor kitchen bench and the
front porch. Blender --background --python this_file. Godot X/Y-up/Z-front
helpers, converted for glTF. No external models, textures or network access.
Kitchen envelope: 2 x 2 squares, 2.62 high. Porch: 2.4 wide, 1.1 deep, 2.5 high.
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
# A covered summer kitchen built like the cottage: stone plinth and lower wall,
# cream plaster above with a shuttered window, and a terracotta lean-to roof.
M=reset()
box('Stone plinth',(0,.06,0),(1.92,.12,1.74),'stone',.05)
for i in range(7):
 box('Plinth edge stone',(-.82+i*.273,.135,.84),(.25,.05,.09),'stoneLight' if i%2 else 'stoneDark',.015)
# Back wall: three courses of dressed stone under plaster, with corner quoins.
wall_z=-.74
for row in range(3):
 n=6;w=1.86/n
 for i in range(n+1):
  x0=-.93+i*w-(w/2 if row%2 else 0);x1=x0+w-.02
  x0=max(x0,-.93);x1=min(x1,.93)
  if x1-x0<.05: continue
  box('Wall stone',((x0+x1)/2,.24+row*.22,wall_z),(x1-x0,.20,.22),['stone','stoneLight','stoneDark'][(i+row)%3],.025)
box('Plaster wall',(0,1.62,wall_z),(1.86,1.36,.18),'plaster',.03)
for k in range(5):
 for sx in (-1,1): box('Corner quoin',(sx*.86,.82+k*.28+(.07 if k%2 else 0),wall_z+.01),(.16 if k%2 else .22,.24,.22),'stoneLight',.02)
# Side wall on the left, a little lower, so the kitchen reads as a room.
box('Side wall stone',(-.88,.46,-.30),(.18,.68,.88),'stoneDark',.03)
box('Side wall plaster',(-.88,1.30,-.36),(.16,1.00,.76),'plaster',.03)
# Window with reveal, frame, mullions, slatted shutters, sill and flower box.
wx,wy=.42,1.62
box('Window reveal',(wx,wy,wall_z+.06),(.62,.66,.08),'wood',.02)
box('Window frame',(wx,wy,wall_z+.10),(.56,.60,.04),'trim',.015)
box('Window glazing',(wx,wy,wall_z+.115),(.46,.50,.01),'glass',.004)
box('Mullion',(wx,wy,wall_z+.125),(.03,.50,.02),'trim',.004);box('Transom',(wx,wy,wall_z+.125),(.46,.03,.02),'trim',.004)
for side in (-1,1):
 box('Painted shutter',(wx+side*.42,wy,wall_z+.12),(.20,.62,.05),'teal',.014)
 for k in range(6): box('Shutter slat',(wx+side*.42,wy-.24+k*.095,wall_z+.15),(.16,.02,.012),'tealLight',.003)
box('Stone window sill',(wx,wy-.37,wall_z+.15),(.66,.06,.16),'stoneLight',.018)
box('Flower box',(wx,wy-.48,wall_z+.20),(.58,.15,.16),'woodLight',.02);box('Box soil',(wx,wy-.41,wall_z+.20),(.54,.02,.12),'soil',.004)
for k in range(6):
 x=wx-.22+k*.088;ball('Leaf',(x,wy-.37,wall_z+.20),(.05,.035,.055),'leaf',10);ball('Petal cluster',(x,wy-.32,wall_z+.21+(k%2-.5)*.04),(.032,.028,.032),'petal' if k%2 else 'petalLight',10)
# Shelf with jars and a pan rail on the plaster beside the window.
box('Wall shelf',(-.42,1.86,wall_z+.17),(.80,.04,.18),'woodDark',.01)
for sx in (-.72,-.12): box('Shelf bracket',(sx,1.80,wall_z+.14),(.04,.10,.12),'woodDark',.01)
for i,fill in enumerate(['jam','honey','flour','jam']):
 x=-.70+i*.19;rod('Glass jar',(x,1.88,wall_z+.17),(x,2.05,wall_z+.17),.055,'jar',16);rod('Jar filling',(x,1.885,wall_z+.17),(x,2.0,wall_z+.17),.048,fill,16)
 rod('Jar lid',(x,2.05,wall_z+.17),(x,2.075,wall_z+.17),.058,'clothCheck' if i%2 else 'cloth',16)
rod('Pan rail',(-.80,1.50,wall_z+.14),(-.04,1.50,wall_z+.14),.012,'brass')
for i,x in enumerate([-.66,-.42,-.18]):
 rod('Hook',(x,1.50,wall_z+.15),(x,1.40,wall_z+.17),.006,'iron',8)
 if i!=1:
  rod('Copper pan',(x,1.28,wall_z+.20),(x,1.31,wall_z+.20),.10,'copper',22);rod('Pan rim',(x,1.31,wall_z+.20),(x,1.32,wall_z+.20),.105,'copperLight',22)
 else:
  rod('Ladle handle',(x,1.40,wall_z+.17),(x,1.20,wall_z+.19),.01,'copper',8);ball('Ladle bowl',(x,1.18,wall_z+.20),(.05,.03,.05),'copperLight',12)
# Counter: plastered base with teal doors under a butcher-block top.
cz=-.40
box('Counter base',(0,.50,cz),(1.66,.76,.58),'plaster',.03)
box('Counter plinth',(0,.15,cz+.02),(1.70,.06,.60),'stoneDark',.012)
for i,x in enumerate([-.54,0,.54]):
 box('Cupboard door',(x,.52,cz+.30),(.46,.56,.03),'teal',.014)
 box('Door panel',(x,.52,cz+.315),(.36,.44,.01),'tealLight',.004)
 ball('Door knob',(x+(.16 if i!=1 else 0),.56,cz+.33),(.022,.022,.022),'brass',10)
for i in range(12):
 box('Worktop stave',(-.825+i*.15,.93,cz),(.148,.09,.66),'woodPale' if i%2 else 'woodLight',.01)
box('Worktop front edge',(0,.93,cz+.335),(1.80,.09,.02),'endGrain',.006)
# Worktop dressing: board, loaf, rolling pin, flour bowl, kettle, apples.
box('Cutting board',(-.40,.995,cz+.06),(.52,.035,.32),'endGrain',.012)
ball('Loaf',(-.43,1.06,cz+.06),(.15,.07,.09),'bread',18);ball('Loaf crust',(-.43,1.09,cz+.06),(.12,.035,.075),'breadLight',14)
for k in range(3): box('Loaf score',(-.50+k*.07,1.12,cz+.06),(.012,.008,.08),'bread',.002)
rod('Rolling pin',(.02,1.0,cz+.20),(.40,1.0,cz+.20),.028,'woodLight',16);rod('Pin handle',(-.05,1.0,cz+.20),(.02,1.0,cz+.20),.014,'woodDark');rod('Pin handle',(.40,1.0,cz+.20),(.47,1.0,cz+.20),.014,'woodDark')
cone('Mixing bowl',(.18,.975,cz-.12),.08,.15,.10,'tealLight',24);ball('Flour in bowl',(.18,1.075,cz-.12),(.13,.028,.13),'flour',16)
ball('Copper kettle',(.62,1.06,cz-.06),(.12,.10,.12),'copper',20);rod('Kettle lid knob',(.62,1.15,cz-.06),(.62,1.19,cz-.06),.02,'copperLight',10)
rod('Kettle spout',(.70,1.04,cz-.06),(.80,1.12,cz-.06),.018,'copper',10)
for k in range(3): ball('Apple',(.36+k*.06,1.02,cz+.16-(k%2)*.06),(.042,.042,.042),'apple',12)
# Lean-to roof: terracotta tile rows from the wall down to two turned posts.
k_back_z,k_front_z,k_back_y,k_front_y,k_width=-.86,.92,2.58,2.12,2.12
def k_slope(z): return k_back_y+(k_front_y-k_back_y)*(z-k_back_z)/(k_front_z-k_back_z)
def k_slab(name,x0,x1,z0,z1,lift,thick,mat):
 pts=[(x0,k_slope(z0)+lift,z0),(x1,k_slope(z0)+lift,z0),(x1,k_slope(z1)+lift,z1),(x0,k_slope(z1)+lift,z1)]
 pts+= [(x,y-thick,z) for x,y,z in pts]
 d=bpy.data.meshes.new(name);d.from_pydata([xyz(p) for p in pts],[],[(0,1,2,3),(7,6,5,4),(0,4,5,1),(1,5,6,2),(2,6,7,3),(3,7,4,0)]);d.update()
 bm=bmesh.new();bm.from_mesh(d);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(d);bm.free()
 o=bpy.data.objects.new(name,d);bpy.context.collection.objects.link(o);return finish(o,name,mat,.008)
k_slab('Roof base',-k_width/2,k_width/2,k_back_z,k_front_z+.04,0,.07,'roofShade')
rows=7;depth=(k_front_z-k_back_z)/rows
for r in range(rows):
 z0=k_back_z+r*depth-.02;z1=z0+depth+.05
 n=9;w=k_width/n
 for i in range(n+1):
  x0=-k_width/2+i*w-(w/2 if r%2 else 0);x1=x0+w-.012
  x0=max(x0,-k_width/2);x1=min(x1,k_width/2)
  if x1-x0<.04: continue
  k_slab('Roof tile',x0,x1,z0,z1,.03+.012*(r%2),.035,['roof','roofLight','roofShade'][(i+r)%3])
k_slab('Ridge flashing',-k_width/2,k_width/2,k_back_z-.04,k_back_z+.10,.07,.05,'trim')
box('Roof fascia',(0,k_front_y-.02,k_front_z+.04),(k_width+.04,.10,.06),'trim',.012)
box('Roof beam',(0,k_front_y-.12,.66),(1.96,.10,.10),'wood',.012)
for sx in (-1,1):
 turned_post('Turned post',sx*.88,.66,.12,k_front_y-.16,'trim')
 rod('Brace',(sx*.88,1.72,.66),(sx*.62,k_front_y-.17,.66),.025,'trim')
# Herb bundles drying from the beam, and a lantern on the right post.
for i,x in enumerate([-.46,-.16,.14]):
 rod('Herb string',(x,k_front_y-.17,.66),(x,1.80,.66),.004,'iron',6)
 ball('Herb bundle',(x,1.74,.66),(.07,.10,.06),'leafLight' if i%2 else 'leaf',12);box('Bundle tie',(x,1.82,.66),(.06,.02,.05),'cloth',.004)
rod('Lantern arm',(.88,1.92,.66),(.88,1.92,.82),.012,'iron',8);rod('Lantern chain',(.88,1.92,.82),(.88,1.80,.82),.006,'iron',8)
box('Lantern cap',(.88,1.78,.82),(.12,.03,.12),'brass',.01);box('Lantern glass',(.88,1.69,.82),(.09,.15,.09),'glass',.01);box('Lantern base',(.88,1.60,.82),(.11,.02,.11),'brass',.006)
# Pantry baskets and a produce crate in front, inside the plinth.
wicker_basket(-.52,.12,.42,.17,.20,'clothCheck')
box('Produce crate',(.40,.24,.40),(.42,.22,.32),'woodLight',.01)
for k in range(3): box('Crate slat',(.40,.17+k*.07,.565),(.42,.03,.01),'woodDark',.004)
for k in range(5): ball('Apple',(.26+k*.07,.39,.34+(k%2)*.10),(.045,.045,.045),'apple',12)
for k in range(3): cone('Carrot',(.32+k*.09,.36,.50),.022,.002,.13,'carrot',10)
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
