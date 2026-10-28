class_name HomesteadLandscapeArt
extends RefCounted

const MODELS={
 "grove_tree":preload("res://assets/grove_tree/cozy_grove_tree.glb"),
 "aspen_tree":preload("res://assets/aspen_tree/cozy_aspen_tree.glb"),
 "pine_tree":preload("res://assets/pine_tree/cozy_pine_tree.glb"),
 "path":preload("res://assets/path/cozy_path.glb"),
 "flowers":preload("res://assets/flowers/cozy_flowers.glb"),
 "rocks":preload("res://assets/rocks/cozy_rocks.glb")}
static var materials={}

static func attach(parent: Node3D,kind: String) -> Node3D:
 var model=MODELS[kind].instantiate()
 parent.add_child(model)
 prepare(model)
 return model

static func prepare(node: Node):
 if node is MeshInstance3D:
  for index in node.mesh.get_surface_count():
   var source=node.get_active_material(index)
   var key=source.resource_name
   # Share immutable materials; retain the stone's separate moss surface.
   if not materials.has(key):
    var material=source.duplicate()
    material.vertex_color_use_as_albedo=true
    materials[key]=material
   if node.mesh.get_surface_count()==1: node.material_override=materials[key]
   else: node.set_surface_override_material(index,materials[key])
 for child in node.get_children(): prepare(child)
