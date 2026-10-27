class_name HomesteadWell
extends Node3D
const MODEL=preload("res://assets/well/cozy_well.glb")
var art: Node3D
var drops: Array[MeshInstance3D]=[]
var clock=0.0
func _init():
 art=MODEL.instantiate()
 add_child(art)
 prepare_materials(art)
func prepare_materials(node: Node):
 if node is MeshInstance3D: node.material_override=node.get_active_material(0).duplicate()
 for child in node.get_children(): prepare_materials(child)
func place(center: Vector3):
 art.visible=center.is_finite()
 position=center if center.is_finite() else Vector3.ZERO
 if not center.is_finite():
  for drop in drops: drop.visible=false
func stream(from: Vector3,to: Vector3,active: bool,delta: float):
 if active and drops.is_empty():
  for i in 10:
   var drop=HomesteadMesh.ellipsoid(self,Vector3.ZERO,Vector3(0.019,0.032,0.019),"b5dfe5")
   drop.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
   drops.append(drop)
 if active: clock+=delta
 for i in drops.size():
  var drop=drops[i]
  drop.visible=active
  if active:
   var t=fposmod(clock*1.6+float(i)/drops.size(),1.0)
   drop.global_position=from.lerp(to,t)+Vector3(0,0.09*sin(t*PI),0)
func update_watering(resident: HomesteadResident,delta: float,quiet: bool):
 var filling=resident.state=="fill" and resident.fetching_water and art.visible
 var target=resident.data.find(resident.target_id)
 var farming=resident.state=="water" and not target.is_empty() and target.kind=="garden"
 var start=to_global(Vector3(-0.93,0.97,-0.30)) if filling else resident.model.can.to_global(Vector3(0.29,0.09,0))
 var finish=resident.model.can.to_global(Vector3(0,0.12,0))
 if farming:
  finish=HomesteadItems.item_center(target).move_toward(resident.position,0.6)+Vector3(0,0.38,0)
 stream(start,finish,(filling or farming) and not quiet,delta)
