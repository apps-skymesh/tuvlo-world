class_name HomesteadFarmBuildingArt
extends RefCounted
const MODELS={
 "windmill":preload("res://assets/windmill/cozy_windmill.glb"),
 "barn":preload("res://assets/barn/cozy_barn.glb"),
 "doghouse":preload("res://assets/doghouse/cozy_doghouse.glb"),
 "grill":preload("res://assets/grill/cozy_grill.glb")}
static func attach(parent: Node3D,kind: String,style=0) -> Node3D:
 var model=MODELS[kind].instantiate()
 parent.add_child(model)
 prepare(model,kind,style)
 if kind=="grill": set_grill_status(model,0)
 return model
static func prepare(node: Node,kind: String,style: int):
 if node is MeshInstance3D:
  var material=node.get_active_material(0).duplicate()
  material.vertex_color_use_as_albedo=true
  if kind=="windmill":
   if material.resource_name=="MillRoof": material.albedo_color=Color("527c69" if style==0 else "b46b4e")
   if material.resource_name=="Canvas" and style!=0: material.albedo_color=Color("90aa9a")
  node.material_override=material
 for child in node.get_children(): prepare(child,kind,style)

# These are visual cues from the existing saved job, never another recipe clock.
static func set_grill_status(parent: Node,state: int):
 var food=parent.find_child("CookingFood",true,false)
 var heat=parent.find_child("WarmCoals",true,false)
 if food: food.visible=state in [1,2]
 if heat: heat.visible=state==1
