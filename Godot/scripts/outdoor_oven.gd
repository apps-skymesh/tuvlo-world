class_name HomesteadOutdoorOven
extends Node3D
const MODEL=preload("res://assets/oven/cozy_outdoor_oven.glb")
var art: Node3D
var loaf: Node3D
var heat: MeshInstance3D
var body: StaticBody3D
func _init():
 art=MODEL.instantiate()
 add_child(art)
 prepare(art)
 loaf=HomesteadHarvestCraft.attach(self,"Bread",Vector3(0,0.96,0.73),Vector3.ONE*0.70)
 loaf.visible=false
 heat=HomesteadMesh.box(self,Vector3(0,1.13,0.39),Vector3(0.48,0.26,0.012),"d99c51",0.04)
 var warm=HomesteadMesh.material("d99c51").duplicate()
 warm.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
 warm.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
 warm.albedo_color.a=0.35
 heat.material_override=warm
 heat.visible=false
 heat.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 body=StaticBody3D.new()
 body.collision_layer=1
 body.collision_mask=0
 body.set_meta("production_station","oven")
 var shape=CollisionShape3D.new()
 var box=BoxShape3D.new()
 box.size=Vector3(1.86,2.25,1.75)
 shape.shape=box
 shape.position.y=1.125
 body.add_child(shape)
 add_child(body)
func prepare(node: Node):
 if node is MeshInstance3D: node.material_override=node.get_active_material(0).duplicate()
 for child in node.get_children(): prepare(child)
func update_status(status: Dictionary):
 heat.visible=status.get("state",0)==1
 loaf.visible=status.get("state",0)==2 and status.get("good","")=="bread"
