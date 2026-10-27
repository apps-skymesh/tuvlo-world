"""Original Tuvlo shared well. Run with Blender --background --python this_file.
Coordinates in helpers are Godot's X/Y-up/Z-front, converted for glTF export.
No third-party models, textures, records or network access are used.
"""
import bpy, bmesh, math, random
from pathlib import Path
from mathutils import Vector

rng = random.Random(72531)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
M = {}
COLORS = {
 'plaster':'efdfbd', 'plasterShade':'decca6', 'trim':'faf0d5',
 'roof':'bd7559', 'roofLight':'cb8966', 'roofShade':'aa624d',
 'wood':'8b6148', 'woodLight':'b98a5b', 'stone':'b9b4a2', 'stoneLight':'d5cbb2',
 'teal':'648c80', 'tealLight':'7ca092', 'glass':'547f85', 'glassLight':'a4c6bd',
 'iron':'535e58', 'brass':'d8b66a', 'soil':'625646',
 'water':'4c9caa', 'rope':'c4aa78', 'leaf':'658258', 'leafLight':'8da36b', 'petal':'e8b0a0', 'cream':'f0d49b'
}
def srgb(v): return v/12.92 if v<.04045 else ((v+.055)/1.055)**2.4
for name, h in COLORS.items():
 mat = bpy.data.materials.new(name); mat.use_nodes=True
 color=tuple(srgb(int(h[i:i+2],16)/255) for i in (0,2,4))+(1,)
 bsdf=mat.node_tree.nodes.get('Principled BSDF'); bsdf.inputs['Base Color'].default_value=color
 bsdf.inputs['Roughness'].default_value=.86 if name!='glass' else .32
 mat.diffuse_color=color
 M[name]=mat

def xyz(p): return (p[0], -p[2], p[1])
def finish(obj, name, material, bevel=0):
 obj.name=name; obj.data.materials.append(M[material])
 if bevel:
  mod=obj.modifiers.new('Hand softened edges','BEVEL'); mod.width=bevel; mod.segments=3
  bpy.context.view_layer.objects.active=obj; bpy.ops.object.modifier_apply(modifier=mod.name)
 for poly in obj.data.polygons: poly.use_smooth=True
 normal=obj.modifiers.new('Weighted face normals','WEIGHTED_NORMAL'); normal.keep_sharp=True; normal.weight=50
 bpy.context.view_layer.objects.active=obj; bpy.ops.object.modifier_apply(modifier=normal.name)
 return obj

def box(name,p,size,mat,bevel=.025):
 bpy.ops.mesh.primitive_cube_add(size=1, location=xyz(p));obj=bpy.context.object
 obj.dimensions=(size[0],size[2],size[1]);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 return finish(obj,name,mat,bevel)
def mesh(name,points,faces,mat,bevel=0):
 data=bpy.data.meshes.new(name);data.from_pydata([xyz(p) for p in points],[],faces);data.update()
 bm=bmesh.new();bm.from_mesh(data);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(data);bm.free()
 obj=bpy.data.objects.new(name,data);bpy.context.collection.objects.link(obj)
 bpy.ops.object.select_all(action='DESELECT');obj.select_set(True)
 return finish(obj,name,mat,bevel)
def rod(name,a,b,r,mat):
 a=Vector(xyz(a));b=Vector(xyz(b));bpy.ops.mesh.primitive_cylinder_add(vertices=12,radius=r,depth=(b-a).length,location=(a+b)/2)
 obj=bpy.context.object;obj.rotation_quaternion=(b-a).to_track_quat('Z','Y');obj.rotation_mode='QUATERNION';obj.rotation_quaternion=(b-a).to_track_quat('Z','Y')
 return finish(obj,name,mat,.008)
def leaf(p,scale,mat):
 bpy.ops.mesh.primitive_uv_sphere_add(segments=12,ring_count=8,radius=1,location=xyz(p));o=bpy.context.object;o.scale=(scale[0],scale[2],scale[1]);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 return finish(o,'Organic foliage',mat)
# Individual, softened annular masonry blocks leave the water genuinely open.
def stone_ring(name, low, high, outer, inner, count, alternate=False):
 for i in range(count):
  a=(i+(0.5 if alternate else 0))*math.tau/count+.015
  b=a+math.tau/count-.03
  points=[(math.cos(t)*r,y,math.sin(t)*r) for y in [low,high] for r in [inner,outer] for t in [a,b]]
  mesh(name,points,[(0,1,3,2),(4,6,7,5),(0,4,5,1),(2,3,7,6),(0,2,6,4),(1,5,7,3)],'stoneLight' if i%3 else 'stone',.018)
stone_ring('Foundation stones',.015,.15,.80,.48,14)
for row in range(3):stone_ring('Dressed well stone',.13+row*.19,.315+row*.19,.71,.49,12,row%2==1)
stone_ring('Rounded cap stones',.70,.83,.78,.45,16)
bpy.ops.mesh.primitive_cylinder_add(vertices=48,radius=.47,depth=.018,location=xyz((0,.24,0)))
finish(bpy.context.object,'Water surface','water',.005)
for x in [-.61,.61]:
 box('Oak roof upright',(x,1.28,0),(.13,1.83,.16),'wood',.025)
 box('Stone post foot',(x,.31,0),(.23,.32,.26),'stoneLight',.03)
 box('Oak post collar',(x,1.83,0),(.20,.10,.23),'woodLight',.02)
 for z in [-.30,.30]:rod('Shaped oak brace',(x,1.57,0),(x,2.02,z),.045,'woodLight')
# Curved small clay tiles echo the cottage without copying its proportions.
for side in [-1,1]:
 for row in range(4):
  a=row/4;b=(row+1)/4
  for col in range(7):
   z=-.79+col*.225
   def roof_y(t):return 2.44-.45*t-.06*t*t
   x0=side*a*.96;x1=side*b*.96
   points=[(x,y-d,zp) for d in [0,.045] for zp in [z,z+.215] for x,y in [(x0,roof_y(a)),(x1,roof_y(b))]]
   mesh('Soft clay roof tile',points,[(0,1,3,2),(4,6,7,5),(0,4,5,1),(2,3,7,6),(0,2,6,4),(1,5,7,3)],['roof','roofLight','roofShade'][(col+row*2)%3],.012)
 for z in [-.83,.83]:rod('Rounded eave trim',(0,2.41,z),(side*.97,1.90,z),.048,'woodLight')
rod('Roof ridge',(0,2.45,-.84),(0,2.45,.84),.07,'roofLight')
# Visible spindle, rope and bucket, with a fitted side tap for the watering can.
rod('Oak spindle',(-.73,1.67,0),(.75,1.67,0),.065,'woodLight')
for i in range(12):
 x=-.18+i*.03
 bpy.ops.mesh.primitive_torus_add(major_radius=.082,minor_radius=.014,major_segments=16,minor_segments=6,location=xyz((x,1.67,0)),rotation=(0,math.pi/2,0))
 finish(bpy.context.object,'Wound hemp rope','rope')
rod('Hanging rope',(.03,1.61,.07),(.03,.51,.07),.016,'rope')
for i in range(12):
 a=i*math.tau/12
 box('Bucket stave',(.03+math.cos(a)*.145,.42,.07+math.sin(a)*.145),(.065,.23,.045),'woodLight',.01).rotation_euler.z=-a
for y in [.33,.51]:
 bpy.ops.mesh.primitive_torus_add(major_radius=.15,minor_radius=.016,major_segments=24,minor_segments=8,location=xyz((.03,y,.07)))
 finish(bpy.context.object,'Bucket hoop','iron')
rod('Winch crank',(.79,1.67,0),(.79,1.43,0),.026,'iron')
rod('Winch grip',(.77,1.43,0),(.94,1.43,0),.037,'teal')
rod('Water feed',(-.68,.76,-.30),(-.68,1.06,-.30),.035,'brass')
rod('Brass fill spout',(-.68,1.06,-.30),(-.93,1.06,-.30),.033,'brass')
rod('Downturned spout',(-.93,1.06,-.30),(-.93,.97,-.30),.035,'brass')
box('Tap cross',(-.68,1.10,-.30),(.14,.035,.035),'teal',.012)
# A few original leaves soften the foot without widening its footprint.
for i in range(4):
 a=i*2.4;leaf((.64+math.cos(a)*.09,.09,.52+math.sin(a)*.10),(.11,.08,.07),'leafLight' if i%2 else 'leaf')
for material in M.values():
 objects=[o for o in list(bpy.context.scene.objects) if o.type=='MESH' and o.data.materials and o.data.materials[0]==material]
 if not objects:continue
 bpy.ops.object.select_all(action='DESELECT')
 for o in objects:o.select_set(True)
 bpy.context.view_layer.objects.active=objects[0];bpy.ops.object.join();obj=bpy.context.object;obj.name='Well_'+material.name
 colors=obj.data.color_attributes.new(name='Color',type='BYTE_COLOR',domain='CORNER')
 for loop in obj.data.loops:
  v=obj.matrix_world@obj.data.vertices[loop.vertex_index].co
  shade=.89+.11*min(1,max(0,v.z/2.5));colors.data[loop.index].color=(shade,shade,shade,1)
output=Path(__file__).resolve().parents[1]/'Godot/assets/well/cozy_well.glb'
output.parent.mkdir(parents=True,exist_ok=True)
bpy.ops.export_scene.gltf(filepath=str(output),export_format='GLB',export_yup=True,export_materials='EXPORT',export_vertex_color='ACTIVE',export_all_vertex_colors=True,export_cameras=False,export_lights=False)
print('Tuvlo original well:',output,output.stat().st_size,'bytes')
