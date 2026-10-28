"""Original folded reading book; Blender --background --python, cottage xyz()."""
import bpy,sys
from pathlib import Path
sys.dont_write_bytecode=True
sys.path.insert(0,str(Path(__file__).resolve().parent))
import build_farm_buildings as craft
from build_farm_buildings import mesh,rod,group
for name,h in {'BookPaper':'f0e5c7','BookCover':'628f83','BookInk':'b3a384','BookRibbon':'c08671'}.items():
 m=bpy.data.materials.new(name);m.use_nodes=True
 c=tuple(craft.srgb(int(h[i:i+2],16)/255) for i in (0,2,4))+(1,)
 m.diffuse_color=c;m.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=c
 m.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.87
 craft.M[name]=m

def leaf(name,side,y,mat):
 pts=[]
 for z in [-.145,.145]:
  for x,h in [(0,.018),(.035,.036),(.11,.031),(.22,.005)]:pts.append((side*x,h+y,z))
 o=mesh(name,pts,[(i,i+1,i+5,i+4) for i in range(3)],mat)
 bpy.context.view_layer.objects.active=o
 mod=o.modifiers.new('Paper thickness','SOLIDIFY');mod.thickness=.002
 bpy.ops.object.modifier_apply(modifier=mod.name)
 return o

def book():
 for side in [-1,1]:
  leaf('Folded cloth cover',side,-.012,'BookCover')
  for y in [-.006,-.002,.002,.006]:leaf('Layered cream paper',side,y,'BookPaper')
  for z in [-.09,-.045,0,.045,.09]:
   rod('Quiet printed line',(side*.063,.047,z),(side*.177,.026,z),.0016,'BookInk',6)
 rod('Bound spine',(0,.005,-.15),(0,.005,.15),.008,'BookCover',12)
 mesh('Ribbon bookmark',[(-.015,.024,.08),(.01,.024,.08),(.01,-.025,.19),(-.002,-.025,.175),(-.015,-.025,.19)],[(0,1,2,3,4)],'BookRibbon')
 page=leaf('Lifted page',1,.011,'BookPaper')
 group('TurningPage',[page])

craft.export_models([('reading_book',book)],Path(__file__).resolve().parents[1]/'Godot/assets')
