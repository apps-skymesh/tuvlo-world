class_name HomesteadMissionTree
extends Node3D
# Presentation only. Approved wins and the host's family-day flag own state.
const FORMS=[preload("res://assets/tree/mission_tree_seed.glb"),preload("res://assets/tree/mission_tree_seedling.glb"),preload("res://assets/tree/mission_tree_young.glb"),preload("res://assets/tree/mission_tree_mature.glb")]
const LEAF=preload("res://assets/tree/mission_tree_leaf.glb")
const HEIGHTS=[0.34,1.05,2.02,3.5]
const RADII=[0.32,0.4,0.65,1.47]
var wins=-1
var form=-1
var body: Node3D
var crown: Array[Node3D]=[]
var weather: Array[MeshInstance3D]=[]
var fallen: Array[Node3D]=[]
var drops: Array[MeshInstance3D]=[]
var target_size=1.0
var unfold=1.0
var yellow=false
var thirst=0.0
var fall_time=0.0
var clock=0.0
var quiet=false
var ghost=false
var pouring=false
var nozzle=Vector3.ZERO
# One watered mission swells the crown and lifts a few fresh leaves.
const GROWTH_PULSE=0.9
var pulse=0.0
var sprouts: Array[Node3D]=[]

func configure(earned: int, thirsty: bool, reduced: bool, preview=false):
 quiet=reduced
 ghost=preview
 var next_wins=maxi(0,earned)
 var next_form=0 if next_wins==0 else 1 if next_wins<3 else 2 if next_wins<13 else 3
 var next_size=1.0 if next_form in [0,3] else 0.7+0.3*float(next_wins-1) if next_form==1 else 0.68+0.32*float(next_wins-3)/9.0
 var first=body==null
 if first or next_form!=form:
  var previous_height=HEIGHTS[form]*body.scale.y if not first else HEIGHTS[next_form]*next_size
  var previous_radius=RADII[form]*body.scale.x if not first else RADII[next_form]*next_size
  if not first:
   remove_child(body)
   body.queue_free()
  # New surfaces need the normal camera-occlusion pass on this frame.
  get_parent().get_parent().set_meta("camera_faded",false)
  body=FORMS[next_form].instantiate()
  body.name="GrowingForm"
  add_child(body)
  crown.clear()
  weather.clear()
  prepare_surfaces(body)
  body.scale=Vector3(previous_radius/RADII[next_form],previous_height/HEIGHTS[next_form],previous_radius/RADII[next_form])
  unfold=1.0 if first or reduced or next_wins<wins else 0.35
  form=next_form
 target_size=next_size
 if first or reduced or next_wins<wins: body.scale=Vector3.ONE*target_size
 wins=next_wins
 get_parent().set_meta("growth_stage",0 if wins<3 else 1 if wins<13 else 2)
 get_parent().set_meta("canopy_radius",0.4 if wins<3 else 0.85 if wins<13 else 1.55)
 get_parent().set_meta("yellow_leaves",thirsty)
 get_parent().set_meta("tree_wins",wins)
 if thirsty!=yellow or first:
  yellow=thirsty
  if yellow: start_leaf_fall()
 if first or reduced: thirst=1.0 if yellow else 0.0
 apply_weather()

func prepare_surfaces(node: Node):
 if node is MeshInstance3D:
  var material=node.get_active_material(0).duplicate()
  node.material_override=material
  node.set_meta("leaf_green",material.albedo_color)
  if str(node.name).begins_with("Crown"):
   crown.append(node)
   if "weather" in str(node.name): weather.append(node)
 for child in node.get_children(): prepare_surfaces(child)

func apply_weather():
 for mesh in weather:
  # A bounded patch of older leaves changes; the healthy crown stays full.
  var material=mesh.material_override as StandardMaterial3D
  material.albedo_color=mesh.get_meta("leaf_green").lerp(Color("ddb34f"),thirst*0.95)
  if mesh.has_meta("camera_original_material"):
   mesh.get_meta("camera_original_material").albedo_color=material.albedo_color
  if get_parent().get_parent().get_meta("camera_faded",false): material.albedo_color.a=0.24

func start_leaf_fall():
 for leaf in fallen:
  remove_child(leaf)
  leaf.queue_free()
 fallen.clear()
 fall_time=0.0
 if form==0: return
 for i in (2 if form==1 else 3 if form==2 else 5):
  var leaf=LEAF.instantiate()
  add_child(leaf)
  prepare_fallen(leaf)
  var angle=i*2.39996+0.6
  var radius=RADII[form]*target_size*0.65
  leaf.set_meta("start",Vector3(cos(angle)*radius,HEIGHTS[form]*target_size*(0.63+0.045*i),sin(angle)*radius))
  leaf.set_meta("land",Vector3(cos(angle)*minf(0.42,radius),0.035,sin(angle)*minf(0.42,radius)))
  leaf.set_meta("delay",float(i)*0.43)
  fallen.append(leaf)

func prepare_fallen(node: Node):
 if node is MeshInstance3D:
  node.material_override=node.get_active_material(0).duplicate()
  node.material_override.albedo_color=Color("d4a34b")
 for child in node.get_children(): prepare_fallen(child)

var big_pulse=false
func celebrate_growth(stage_up=false):
 if quiet or ghost or body==null or form==0: return
 pulse=GROWTH_PULSE
 big_pulse=stage_up
 for leaf in sprouts:
  remove_child(leaf)
  leaf.queue_free()
 sprouts.clear()
 for i in (6 if big_pulse else 3):
  var leaf=LEAF.instantiate()
  add_child(leaf)
  prepare_sprout(leaf)
  var angle=i*(1.05 if big_pulse else 2.09)+0.4
  var radius=RADII[form]*target_size*0.45
  leaf.set_meta("start",Vector3(cos(angle)*radius,HEIGHTS[form]*target_size*0.82,sin(angle)*radius))
  leaf.visible=false
  sprouts.append(leaf)

# The first visit plants the tree: it rises from the soil with a soft swell.
func plant_pop():
 if quiet or ghost or body==null: return
 body.scale=Vector3.ONE*target_size*0.05
 unfold=0.2
 pulse=GROWTH_PULSE
 big_pulse=false

func prepare_sprout(node: Node):
 if node is MeshInstance3D:
  node.material_override=node.get_active_material(0).duplicate()
  node.material_override.albedo_color=Color("7cc35a")
  node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 for child in node.get_children(): prepare_sprout(child)

func set_water_source(world_nozzle: Vector3, active: bool):
 pouring=active and not quiet and not ghost
 if pouring: nozzle=to_local(world_nozzle)
 if pouring and drops.is_empty():
  for i in 9:
   var drop=HomesteadMesh.ellipsoid(self,Vector3.ZERO,Vector3(0.021,0.035,0.021),"a8d7dc")
   # Independent material keeps camera fading and the static batcher isolated.
   drop.material_override=drop.material_override.duplicate()
   drop.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
   drops.append(drop)
 for drop in drops: drop.visible=pouring

func _process(delta):
 if body==null: return
 if not quiet: clock+=delta
 var blend=1.0 if quiet else 1.0-exp(-delta*2.8)
 body.scale=body.scale.lerp(Vector3.ONE*target_size,blend)
 unfold=lerpf(unfold,1.0,blend)
 if quiet: pulse=0.0
 else: pulse=maxf(0.0,pulse-delta)
 var swell=0.0 if pulse<=0.0 else (0.22 if big_pulse else 0.14)*sin((1.0-pulse/GROWTH_PULSE)*PI)
 for i in crown.size():
  crown[i].scale=Vector3.ONE*unfold*(1.0+swell)
  crown[i].rotation.z=0.0 if quiet or ghost else sin(clock*0.85+i*1.6)*0.009
 thirst=lerpf(thirst,1.0 if yellow else 0.0,1.0 if quiet else 1.0-exp(-delta*1.3))
 apply_weather()
 fall_time+=delta if not quiet else 0.0
 for i in fallen.size():
  var leaf=fallen[i]
  var t=1.0 if quiet else clampf((fall_time-2.0-float(leaf.get_meta("delay")))/3.0,0.0,1.0)
  var start: Vector3=leaf.get_meta("start")
  var land: Vector3=leaf.get_meta("land")
  leaf.visible=quiet or fall_time>=2.0+float(leaf.get_meta("delay"))
  leaf.position=start.lerp(land,t)
  if not quiet: leaf.position+=Vector3(sin(t*TAU+i)*0.1,0,cos(t*TAU+i)*0.07)*sin(t*PI)
  leaf.rotation=Vector3(0.18 if t==1.0 else t*2.2, i*1.9+t*3.0, 0 if t==1.0 else sin(t*TAU)*0.5)
  leaf.scale=Vector3.ONE*(0.7 if form<3 else 1.0)*(1.0 if yellow else thirst)
 if not yellow and thirst<0.01 and not fallen.is_empty():
  for leaf in fallen:
   remove_child(leaf)
   leaf.queue_free()
  fallen.clear()
 var rise=1.0-pulse/GROWTH_PULSE
 for i in sprouts.size():
  var leaf=sprouts[i]
  leaf.visible=pulse>0.0
  leaf.position=leaf.get_meta("start")+Vector3(0,0.55*rise,0)
  leaf.rotation=Vector3(0.3,i*2.1+rise*2.4,sin(rise*TAU)*0.3)
  leaf.scale=Vector3.ONE*(0.6 if form<3 else 0.9)*maxf(0.01,sin(rise*PI))
 if pulse<=0.0 and not sprouts.is_empty():
  for leaf in sprouts:
   remove_child(leaf)
   leaf.queue_free()
  sprouts.clear()
 for i in drops.size():
  if not pouring: break
  var t=fposmod(clock*1.6+float(i)/drops.size(),1.0)
  drops[i].position=nozzle.lerp(Vector3(0,0.08,0),t)+Vector3(0,sin(t*PI)*0.10,0)
