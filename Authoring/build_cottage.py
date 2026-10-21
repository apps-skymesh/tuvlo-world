"""Original Tuvlo cottage. Run with Blender --background --python this_file.
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
 'leaf':'658258', 'leafLight':'8da36b', 'petal':'e8b0a0', 'cream':'f0d49b'
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
def arch(name,x,base,z,width,height,depth,mat):
 r=width/2; outline=[(-r,0),(r,0)]
 for i in range(17):
  t=i*math.pi/16;outline.append((math.cos(t)*r,height-r+math.sin(t)*r))
 n=len(outline);points=[(x+a,base+b,z+d) for d in [-depth/2,depth/2] for a,b in outline]
 faces=[tuple(range(n-1,-1,-1)),tuple(range(n,n*2))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
 return mesh(name,points,faces,mat,.018)
def roof_height(t):return 3.65-.78*t-.17*t*t+.065*math.sin(t*math.pi)
def roof_strip(name,side,a,b,z0,z1,thickness,mat):
 points=[];steps=4
 for lower in [False,True]:
  for z in [z0,z1]:
   for i in range(steps+1):
    t=a+(b-a)*i/steps;points.append((side*t*2.03,roof_height(t)-(thickness if lower else 0),z))
 n=steps+1;faces=[]
 for i in range(steps):
  faces.extend([(i,i+1,n+i+1,n+i),(2*n+i,3*n+i,3*n+i+1,2*n+i+1),(i,2*n+i,2*n+i+1,i+1),(n+i,n+i+1,3*n+i+1,3*n+i)])
 faces.extend([(0,n,3*n,2*n),(n-1,2*n-1,4*n-1,3*n-1)])
 return mesh(name,points,faces,mat,.016)

# Human-scale stone plinth and soft plaster volume.
box('Foundation shadow reveal',(0,.10,0),(3.68,.20,2.72),'wood',.07)
for side in [-1,1]:
 for i in range(9):
  box('Hand cut foundation stone',(-1.61+i*.40,.235,side*1.285),(.385,.25,.21),'stoneLight' if i%3 else 'stone',.035)
 for i in range(6):
  box('Foundation side stone',(side*1.72,.235,-1.04+i*.415),(.20,.25,.39),'stone' if i%2 else 'stoneLight',.03)
box('Rounded lime plaster walls',(0,1.42,0),(3.47,2.22,2.50),'plaster',.095)
for z in [-1.245,1.245]:
 points=[(x,y,z+d) for d in [-.035,.035] for x,y in [(-1.72,2.48),(1.72,2.48),(0,3.61)]]
 mesh('Lime plaster gable',points,[(0,2,1),(3,4,5),(0,1,4,3),(1,2,5,4),(2,0,3,5)],'plaster')
 box('Gable timber tie',(0,2.54,z+(.04 if z>0 else -.04)),(3.44,.075,.08),'woodLight',.018)
# A curved roof with visible courses: authored mesh, not rotated rectangular slabs.
for side in [-1,1]:
 roof_strip('Deep eave shadow',side,0,1.025,-1.55,1.55,.13,'wood')
 for row in range(5):
  for column in range(11):
   z=-1.52+column*.278
   roof_strip('Individual clay tile',side,max(0,row*.20-.015),min(1.035,(row+1)*.20+.025),z,z+.266,.055,['roof','roofLight','roofShade'][rng.choices([0,1,2],[7,2,1])[0]])
 # Solid fascia follows the full curve at both ends.
 for z in [-1.575,1.575]:
  for i in range(12):
   a=i/12;b=(i+1)/12
   rod('Curved timber bargeboard',(side*a*2.04,roof_height(a)-.10,z),(side*b*2.04,roof_height(b)-.10,z),.055,'woodLight')
for i in range(12):
 z=-1.54+i*.274;rod('Rounded ridge cap',(0,3.675,z),(0,3.675,z+.29),.10,'roofLight')
# Quoin stones, timber sill and shallow lime courses.
for x in [-1.72,1.72]:
 for y in [.48,.79,1.10,1.41,1.72,2.03,2.34]:
  box('Corner dressed stone',(x,y,1.245),(.19,.24,.17),'stoneLight',.025)
for z in [-1.266,1.266]:box('Oak sill rail',(0,.44,z),(3.48,.11,.08),'woodLight',.02)
# Arched entry, fitted planks and a recessed glazing panel.
arch('Entry surround',0,.30,1.294,1.10,1.98,.14,'trim')
arch('Entry deep reveal',0,.33,1.382,.91,1.80,.07,'wood')
arch('Oak door',0,.35,1.423,.78,1.67,.045,'woodLight')
for x in [-.25,-.125,0,.125,.25]:box('Door plank joints',(x,.93,1.45),(.011,1.03,.008),'wood',.002)
arch('Door glazing inset',0,1.39,1.46,.33,.39,.025,'glass')
box('Door glass cross',(0,1.59,1.48),(.027,.28,.018),'trim',.005)
leaf((.26,1.03,1.49),(.038,.038,.035),'brass')
for y,z,w,d in [(.10,1.51,1.28,.44),(.21,1.39,1.08,.30)]:box('Worn doorstep',(0,y,z),(w,.15,d),'stoneLight',.045)
# Deep front windows; shutters have individual slats and fitted flower boxes.
for x in [-1.08,1.08]:
 arch('Window stone surround',x,1.04,1.285,.73,1.05,.14,'trim')
 arch('Inset window shadow',x,1.09,1.367,.57,.91,.025,'wood')
 arch('Teal glass',x,1.13,1.389,.49,.82,.02,'glass')
 box('Window mullion',(x,1.53,1.412),(.037,.76,.03),'trim',.006)
 box('Window transom',(x,1.51,1.414),(.48,.04,.027),'trim',.006)
 box('Window reflected sky',(x-.12,1.72,1.414),(.04,.23,.006),'glassLight',.006)
 for side in [-1,1]:
  box('Painted shutter',(x+side*.48,1.54,1.32),(.20,.88,.09),'teal',.018)
  for row in range(7):box('Shutter louvres',(x+side*.48,1.25+row*.09,1.378),(.16,.035,.035),'tealLight',.008)
 box('Stone window sill',(x,1.01,1.41),(.84,.12,.30),'stoneLight',.028)
 box('Curved flower box',(x,.85,1.47),(.79,.23,.27),'woodLight',.045)
 box('Planter soil',(x,.98,1.47),(.68,.025,.19),'soil',.01)
 for i in range(6):
  a=x-.29+i*.115
  leaf((a,1.02,1.48),(.12,.10,.12),'leaf' if i%2 else 'leafLight')
  h=1.10+(i%3)*.045
  rod('Flower stem',(a,1.0,1.51),(a,h,1.51),.009,'leaf')
  for j in range(5):
   t=j*math.tau/5;leaf((a+math.cos(t)*.035,h+math.sin(t)*.035,1.53),(.029,.027,.016),'petal' if i%2 else 'cream')
  leaf((a,h,1.55),(.016,.016,.012),'brass')
# Side windows, with real depth and sill rather than a blank facade.
for side in [-1,1]:
 x=side*1.75
 box('Side window reveal',(x,1.49,0),(.08,.90,.82),'wood',.03)
 box('Side window frame',(x+side*.055,1.49,0),(.06,.84,.76),'trim',.03)
 box('Side window glazing',(x+side*.09,1.49,0),(.02,.67,.60),'glass',.01)
 box('Side mullion',(x+side*.11,1.49,0),(.03,.68,.04),'trim',.008)
 box('Side transom',(x+side*.11,1.49,0),(.03,.04,.60),'trim',.008)
 box('Side sill',(x+side*.05,1.03,0),(.25,.12,.95),'stoneLight',.025)
# Gable oculus and inset wooden spokes.
for r,mat,z in [(.245,'wood',1.268),(.20,'trim',1.285),(.15,'glass',1.31)]:
 bpy.ops.mesh.primitive_cylinder_add(vertices=32,radius=r,depth=.035,location=xyz((0,2.91,z)),rotation=(math.pi/2,0,0));finish(bpy.context.object,'Round loft window',mat,.008)
box('Loft cross',(0,2.91,1.337),(.028,.28,.025),'trim',.005)
box('Loft transom',(0,2.91,1.338),(.28,.028,.025),'trim',.005)
# A masonry chimney with a recessed opening and dressed cap.
for row in range(5):
 y=3.21+row*.17
 box('Chimney masonry',(.96,y,-.56),(.43,.16,.46),'plasterShade' if row%2 else 'stoneLight',.025)
box('Chimney cap',(.96,4.02,-.56),(.59,.12,.61),'stoneLight',.03)
box('Chimney soot inset',(.96,4.089,-.56),(.33,.008,.35),'iron',.018)
# Fitted wall lantern and small iron bracket.
rod('Lantern bracket',(.59,2.12,1.32),(.59,2.12,1.62),.023,'iron')
box('Lantern warm glass',(.59,1.94,1.58),(.17,.25,.16),'cream',.025)
for y in [1.80,2.08]:box('Lantern cap',(.59,y,1.58),(.23,.055,.23),'iron',.02)
for x in [.505,.675]:rod('Lantern frame',(x,1.82,1.66),(x,2.06,1.66),.012,'iron')
# A shallow back door and utility detail keep rotations intentional.
box('Rear hatch',(0,1.15,-1.27),(.78,1.60,.08),'teal',.065)
for y in [.55,.98,1.41,1.83]:box('Rear door rail',(0,y,-1.32),(.72,.045,.025),'tealLight',.01)

# Consolidate by material; retain material names for existing treehouse roof styles.
bpy.ops.object.select_all(action='DESELECT')
for mat in M.values():
 objects=[o for o in list(bpy.context.scene.objects) if o.type=='MESH' and o.data.materials and o.data.materials[0]==mat]
 if not objects:continue
 for o in objects:o.select_set(True)
 bpy.context.view_layer.objects.active=objects[0];bpy.ops.object.join()
 obj=bpy.context.object;obj.name='Cottage_'+mat.name
 # Gentle vertex-painted underside darkening survives both Godot renderers.
 colors=obj.data.color_attributes.new(name='Color',type='BYTE_COLOR',domain='CORNER')
 for poly in obj.data.polygons:
  for loop in poly.loop_indices:
   vertex=obj.matrix_world @ obj.data.vertices[obj.data.loops[loop].vertex_index].co
   shade=.90+.10*min(1,max(0,vertex.z/3.5))
   colors.data[loop].color=(shade,shade,shade,1)
 bpy.ops.object.select_all(action='DESELECT')
output=Path(__file__).resolve().parents[1]/'Godot/assets/cottage/cozy_cottage.glb'
bpy.ops.export_scene.gltf(filepath=str(output),export_format='GLB',export_yup=True,export_materials='EXPORT',export_vertex_color='ACTIVE',export_all_vertex_colors=True,export_extras=False,export_cameras=False,export_lights=False)
print('Tuvlo original cottage asset:',output,output.stat().st_size,'bytes')
