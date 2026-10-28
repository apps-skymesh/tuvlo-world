class_name HomesteadQuietPlaceArt
extends RefCounted
const MODELS={
 "pond":preload("res://assets/pond/cozy_pond.glb"),
 "nook":preload("res://assets/nook/cozy_nook.glb"),
 "treehouse":preload("res://assets/treehouse/cozy_treehouse.glb")}
static func attach(parent: Node3D,kind: String,style: int) -> Node3D:
 var model=MODELS[kind].instantiate()
 parent.add_child(model)
 if kind=="pond":
  var unused=model.find_child("MarshPlants" if style==0 else "Lilies",true,false)
  if unused:
   unused.get_parent().remove_child(unused)
   unused.free()
 prepare(model,kind,style)
 return model
static func prepare(node: Node,kind: String,style: int):
 if node is MeshInstance3D:
  var material=node.get_active_material(0).duplicate()
  material.vertex_color_use_as_albedo=true
  if material.resource_name=="PondWater":
   var water=ShaderMaterial.new()
   water.resource_name="PondWater"
   water.shader=preload("res://scripts/pond_water.gdshader")
   node.material_override=water
  else:
   if kind=="nook" and material.resource_name=="Fabric" and style!=0: material.albedo_color=Color("83a89a")
   if kind=="treehouse" and material.resource_name=="TreehouseRoof": material.albedo_color=Color("d2b267" if style==0 else "ac7894")
   node.material_override=material
 for child in node.get_children(): prepare(child,kind,style)
