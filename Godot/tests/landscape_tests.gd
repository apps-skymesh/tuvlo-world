extends RefCounted

static func run(scene,expect: Callable,bounds_of: Callable):
 for kind in ["grove_tree","aspen_tree","pine_tree","path","flowers","rocks"]:
  var holder=Node3D.new();scene.add_child(holder)
  var model=HomesteadLandscapeArt.attach(holder,kind)
  var crown=model.find_child("Crown",true,false)
  var height=3.7 if kind.ends_with("tree") else HomesteadItems.DEFINITIONS[kind].height
  for rotation in 4:
   model.rotation.y=rotation*PI/2
   for tilt in ([-.017,.017] if crown else [0.0]):
    if crown: crown.rotation.z=tilt
    var bounds=bounds_of.call(holder)
    expect.call(bounds.position.x>=-.52 and bounds.end.x<=.52 and bounds.position.z>=-.52 and bounds.end.z<=.52,"Landscape vertices fit every rotated square/sway: "+kind)
    expect.call(bounds.position.y>=-.02 and bounds.end.y<=height+.02,"Landscape art respects ground and height: "+kind)
  for mesh in model.find_children("*","MeshInstance3D",true,false):
   for index in mesh.mesh.get_surface_count():
    var material=mesh.get_active_material(index)
    var arrays=mesh.mesh.surface_get_arrays(index)
    expect.call(material is StandardMaterial3D and material.vertex_color_use_as_albedo and material.resource_name!="","Landscape surfaces retain named materials and vertex paint")
    expect.call(arrays[Mesh.ARRAY_COLOR] is PackedColorArray and arrays[Mesh.ARRAY_COLOR].size()==arrays[Mesh.ARRAY_VERTEX].size(),"Landscape paint survives each GLB surface")
  if kind=="rocks":
   var moss=false
   for mesh in model.find_children("*","MeshInstance3D",true,false):
    for index in mesh.mesh.get_surface_count(): moss=moss or mesh.get_active_material(index).resource_name=="RockMoss"
   expect.call(moss,"Stone multi-surface import retains the separate moss material")
  holder.free()
 var before=scene.presentation.foliage.size()
 var ghost_tree=scene.presentation.make_item("tree",1,true)
 var ghost_flowers=scene.presentation.make_item("flowers",2,true)
 expect.call(scene.presentation.foliage.size()==before,"Landscape ghosts never register live sway pivots")
 ghost_tree.free();ghost_flowers.free()
 var mission=scene.presentation.make_item("tree",0,false,0,2)
 expect.call(mission.find_child("MissionTree",true,false)!=null,"Landscape replacement never replaces the special mission tree")
 mission.free()
 for kind in ["tree","flowers"]:
  var live=scene.presentation.make_item(kind,0,false)
  scene.add_child(live)
  var crown=live.find_child("Crown",true,false)
  expect.call(crown!=null and crown in scene.presentation.foliage,"Live landscape retains its authored sway pivot")
  scene.presentation.reduced_motion=true
  var quiet_clock=scene.presentation.clock
  scene.presentation._process(.1)
  expect.call(is_zero_approx(crown.rotation.z) and scene.presentation.clock==quiet_clock,"Reduce Motion freezes new landscape sway")
  scene.presentation.reduced_motion=false
  live.free()
 var batch=Node3D.new();scene.add_child(batch)
 for i in 3:
  var path=HomesteadLandscapeArt.attach(batch,"path")
  path.position.x=i
 expect.call(HomesteadStaticBatcher.consolidate(batch,[])>0,"Shared landscape materials retain effective static batching")
 for mesh in batch.find_children("*","MeshInstance3D",true,false):
  var arrays=mesh.mesh.surface_get_arrays(0)
  expect.call(arrays[Mesh.ARRAY_COLOR].size()==arrays[Mesh.ARRAY_VERTEX].size(),"Batched paths preserve authored paint")
 batch.free()
