class_name HomesteadAnimalArt
extends RefCounted

const MODELS={"dog":preload("res://assets/dog/cozy_dog.glb"),"sheep":preload("res://assets/sheep/cozy_sheep.glb")}
static var materials={}

static func attach(parent: Node3D,is_dog: bool):
 var kind="dog" if is_dog else "sheep"
 var model=MODELS[kind].instantiate()
 parent.add_child(model)
 parent.name="Dog" if is_dog else "Sheep"
 # Keep the growth anchor separate from breathing so snapshot scale survives.
 parent.set_meta("pet_motion","anchor")
 prepare(model,kind,float(parent.get_instance_id()%13)*.31)

static func prepare(node: Node,kind: String,phase: float):
 if node is MeshInstance3D:
  var source=node.get_active_material(0)
  var key=kind+source.resource_name
  if not materials.has(key):
   var material=source.duplicate()
   material.vertex_color_use_as_albedo=true
   materials[key]=material
  node.material_override=materials[key]
 if str(node.name) in ["Body","Head","Tail","EarLeft","EarRight","EyeLeft","EyeRight"]:
  node.set_meta("pet_motion",str(node.name))
  node.set_meta("pet_species",kind)
  node.set_meta("pet_phase",phase)
  node.set_meta("pet_rest",node.position)
 for child in node.get_children(): prepare(child,kind,phase)

static func animate(part: Node3D,time: float,quiet: bool):
 var role=str(part.get_meta("pet_motion",""))
 if role=="anchor": return
 var dog=part.get_meta("pet_species","")=="dog"
 var t=time+float(part.get_meta("pet_phase",0.0))
 if role=="Body":
  part.position=part.get_meta("pet_rest",Vector3.ZERO)+Vector3(0,0 if quiet else sin(t*1.9)*.004,0)
 elif role=="Head":
  var graze=0.0 if quiet or dog else smoothstep(-.2,.8,sin(t*.55))
  part.position=part.get_meta("pet_rest",Vector3.ZERO)+Vector3(0,-graze*.21,graze*.02)
  part.rotation.x=0 if quiet else sin(t*.9)*.025 if dog else graze*.80
  part.rotation.y=0 if quiet else sin(t*.63)*(.10 if dog else .04)
 elif role=="Tail":
  part.rotation.z=0 if quiet else sin(t*(5.5 if dog else 2.4))*(.32 if dog else .07)
 elif role.begins_with("Ear"):
  # Preserve each authored ear's rest rotation; only add a tiny local flick.
  part.rotation.x=0 if quiet else sin(t*1.4+(0 if role=="EarLeft" else .8))*.035
 elif role.begins_with("Eye"):
  var blink=fposmod(t,5.1)
  part.scale.y=1.0 if quiet else lerpf(.08,1.0,clampf(absf(blink-2.3)/.085,0.0,1.0))
