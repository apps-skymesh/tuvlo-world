extends SceneTree
# Disposable desktop host for the real runtime. Excluded from app exports.
var world
var elapsed=0.0
var duration=0.0
var output=""
var capture_index=0
var capture_times=[1.0,4.0,8.0,14.0,19.0]
var payload: Dictionary
var activity_label: Label
var appearance_index=0
var events=[]
var busy_capture=false
var motion_samples=[]
var next_sample=0.0
var started_ms=0
var initial_camera="overview"
var animals_slice=false
var equipped=false
var cottage_slice=false
var tree_slice=false
var well_slice=false
var well_phase=-1
var well_elapsed=0.0
var tree_story_clock=-1.0
var tree_story_step=-1
var next_tree_frame=0.0
var tree_captures=[]
var tree_label: Label
var meadow_slice=false
var windmill_slice=false
var greenhouse_slice=false
var orchard_slice=false
var waterside_slice=false
var production_phase=-1
var construction_review=false
var construction_step=-1
func _initialize(): call_deferred("run")
func run():
 started_ms=Time.get_ticks_msec()
 root.size_changed.connect(keep_landscape)
 keep_landscape()
 DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
 var args=OS.get_cmdline_user_args()
 for index in args.size():
  if args[index]=="--construction": construction_review=true; windmill_slice=true; capture_times=[1.0,4.0,8.0,13.0,17.0]
  if args[index]=="--animals": animals_slice=true
  if args[index]=="--equipped": equipped=true
  if args[index]=="--windmill": windmill_slice=true
  if args[index]=="--cottage": cottage_slice=true
  if args[index]=="--well": well_slice=true; tree_slice=true; cottage_slice=true
  if args[index]=="--tree": tree_slice=true; cottage_slice=true
  if args[index]=="--waterside": meadow_slice=true; waterside_slice=true
  if args[index]=="--meadow": meadow_slice=true
  if args[index]=="--orchard": meadow_slice=true; greenhouse_slice=true; orchard_slice=true
  if args[index]=="--greenhouse": meadow_slice=true; greenhouse_slice=true
  if args[index]=="--camera" and index+1<args.size(): initial_camera=args[index+1]
  if args[index]=="--seconds" and index+1<args.size(): duration=clampf(float(args[index+1]),1,60)
  if args[index]=="--capture" and index+1<args.size(): output=args[index+1]
 if output!="": DirAccess.make_dir_recursive_absolute(output)
 world=load("res://scenes/homestead.tscn").instantiate()
 root.add_child(world)
 world.host_message.connect(on_message)
 build_controls()
 reset(equipped)
 camera(initial_camera)
 if tree_slice:
  tree_seed()
  tree_camera()
  tree_story_clock=0.0
  if well_slice: start_well_story()
 if animals_slice: send("camera",{"mode":"place","id":"barn","zoom":1.1})
func keep_landscape():
 # This host is a landscape-only visual lab; app orientation uses UIKit's lease.
 var maximum_height=maxi(540,int(root.size.x*0.625))
 if root.size.y>maximum_height: root.size=Vector2i(root.size.x,maximum_height)
func snapshot():
 world.receive_host_json(JSON.stringify({"version":1,"session":"mac-disposable-lab","type":"snapshot","payload":payload}))
func send(type: String,value: Dictionary={}):
 world.receive_host_json(JSON.stringify({"version":1,"session":"mac-disposable-lab","type":type,"payload":value}))
func reset(equipped: bool):
 world.clear_host_session()
 payload={"items":[
  {"id":"cottage","kind":"cottage","cell":{"x":3,"z":2},"rotation":0},
  {"id":"garden","kind":"garden","cell":{"x":3,"z":7},"rotation":0},
  {"id":"tree","kind":"tree","cell":{"x":11,"z":3},"rotation":0}],
  "land":[],"appearance":{"hair":3,"outfit":0},"approvedWins":21,"growthTreeID":"tree",
  "edges":true,"harvest":{"woods":"wood","quarry":"stone","garden":"food"}}
 for z in range(5,10): payload.items.append({"id":"path-%d"%z,"kind":"path","cell":{"x":7,"z":z},"rotation":0})
 if cottage_slice:
  payload.items=[
   {"id":"cottage","kind":"cottage","cell":{"x":7,"z":3},"rotation":0},
   {"id":"garden","kind":"garden","cell":{"x":4,"z":8},"rotation":0},
   {"id":"tree","kind":"tree","cell":{"x":12,"z":7},"rotation":0}]
  for z in range(6,11): payload.items.append({"id":"path-%d"%z,"kind":"path","cell":{"x":9,"z":z},"rotation":0})
 if equipped:
  payload.items.append({"id":"bench","kind":"bench","cell":{"x":8,"z":10},"rotation":0})
  payload.items.append({"id":"pond","kind":"pond","cell":{"x":12,"z":7},"rotation":0})
 if meadow_slice:
  payload.land=["west"]
  payload.items.append({"id":"workshop","kind":"workshop","cell":{"x":1,"z":11},"rotation":0})
 if windmill_slice:
  payload.items.append({"id":"windmill","kind":"windmill","cell":{"x":10,"z":10},"rotation":0})
 if waterside_slice:
  payload.land.append("east")
 if greenhouse_slice:
  payload.items.append({"id":"greenhouse","kind":"greenhouse","cell":{"x":-3,"z":8},"rotation":0})
 if orchard_slice:
  payload.items.append({"id":"orchard","kind":"orchard","cell":{"x":-4,"z":6},"rotation":0,"style":1})
 if animals_slice:
  payload.items.append({"id":"barn","kind":"barn","cell":{"x":10,"z":5},"rotation":0})
  payload.items.append({"id":"doghouse","kind":"doghouse","cell":{"x":8,"z":11},"rotation":0})
  payload.items.append({"id":"grill","kind":"grill","cell":{"x":12,"z":10},"rotation":0})
  payload.production=[{"placeID":"barn","station":"barn","good":"meat","state":1,"remaining":45,"progress":0.5},{"placeID":"grill","station":"grill","good":"meal","state":1,"remaining":30,"progress":0.5}]
 snapshot()
func camera(mode: String): send("camera",{"mode":mode})
func button(parent: Node,text: String,action: Callable):
 var control=Button.new()
 control.text=text
 control.pressed.connect(action)
 parent.add_child(control)
func build_controls():
 var layer=CanvasLayer.new()
 root.add_child(layer)
 var toolbar=HBoxContainer.new()
 toolbar.position=Vector2(16,14)
 layer.add_child(toolbar)
 if tree_slice:
  button(toolbar,"Tree",tree_camera)
  button(toolbar,"Home",func(): camera("home"))
  button(toolbar,"Water trip",start_well_story)
  button(toolbar,"Seed",func(): tree_story_clock=-1; well_phase=-1; tree_seed())
  button(toolbar,"Mission +1",func(): tree_story_clock=-1; well_phase=-1; tree_mission(1))
  button(toolbar,"Full grown",func(): tree_story_clock=-1; well_phase=-1; tree_set(13))
  button(toolbar,"Missed day",func(): tree_story_clock=-1; well_phase=-1; send("treeLeaves",{"yellow":true}))
  button(toolbar,"Play life",func(): well_phase=-1; tree_seed(); tree_story_step=-1; tree_story_clock=0.0)
  button(toolbar,"Quiet",func(): payload.reducedMotion=not payload.get("reducedMotion",false); snapshot())
  tree_label=Label.new()
  tree_label.position=Vector2(18,50)
  layer.add_child(tree_label)
  activity_label=Label.new()
  activity_label.position=Vector2(18,root.size.y-40)
  layer.add_child(activity_label)
  return
 for mode in ["home","overview","follow"]: button(toolbar,mode.capitalize(),func(): camera(mode))
 var options=MenuButton.new()
 options.text="Camera options"
 toolbar.add_child(options)
 for title in ["Close up","Zoom in","Zoom out"]: options.get_popup().add_item(title)
 options.get_popup().id_pressed.connect(camera_option)
 button(toolbar,"Cottage",func():
  cottage_slice=true
  reset(false)
  camera("home"))
 button(toolbar,"Starter",func():
  cottage_slice=false
  reset(false))
 button(toolbar,"Equipped",func(): reset(true))
 button(toolbar,"Production",cycle_production)
 button(toolbar,"Look",func():
  appearance_index+=1
  payload.appearance={"hair":appearance_index%13,"outfit":appearance_index%6}
  snapshot())
 button(toolbar,"Quiet",func():
  payload.reducedMotion=not payload.get("reducedMotion",false)
  snapshot())
 button(toolbar,"Pause",func(): send("lifecycle",{"paused":not world.paused}))
 var footer=VBoxContainer.new()
 footer.position=Vector2(16,root.size.y-85)
 layer.add_child(footer)
 activity_label=Label.new()
 activity_label.add_theme_color_override("font_color",Color("304c49"))
 footer.add_child(activity_label)
 var hint=Label.new()
 hint.add_theme_color_override("font_color",Color("304c49"))
 hint.text="Mac visual lab • disposable layout • no family data\nTap to visit · hold to pick up · drag to move · R rotate · Enter place · Esc cancel"
 footer.add_child(hint)
# Manual visual states, not a replacement for the native farm/inventory host.
func cycle_production():
 production_phase=(production_phase+1)%3
 var has_mill=false
 var has_orchard=false
 for item in payload.items:
  has_mill=has_mill or item.id=="windmill"
  has_orchard=has_orchard or item.id=="orchard"
 if not has_mill: payload.items.append({"id":"windmill","kind":"windmill","cell":{"x":10,"z":10},"rotation":0})
 if not has_orchard: payload.items.append({"id":"orchard","kind":"orchard","cell":{"x":-4,"z":6},"rotation":0})
 if "west" not in payload.land: payload.land.append("west")
 payload.harvest={"woods":"wood","quarry":"stone"}
 payload.farmStages=[0,0] if production_phase==0 else [2,3] if production_phase==1 else [4,4]
 payload.farmFruitStage=production_phase
 payload.production=[]
 for spec in [["garden","field","wheat"],["windmill","mill","flour"],["cottage","oven","bread"],["cottage","pantry","meal"],["orchard","orchard","fruit"]]:
  payload.production.append({"placeID":spec[0],"station":spec[1],"good":spec[2],"state":production_phase,"remaining":30 if production_phase==1 else 0,"progress":0.5 if production_phase==1 else float(production_phase)/2.0})
 snapshot()
 activity_label.text="Production: "+["Idle","Working","Ready"][production_phase]

# Disposable mission approvals and family-day state only; no real family store.
func tree_camera():
 world.pan_focus=HomesteadItems.item_center(world.data.find("tree"))+Vector3(0,1.4,0)
 world.pan_size=6.4
 send("camera",{"mode":"pan","resetZoom":true})
func tree_set(wins: int):
 world.presentation.pending_tree_growth=0
 world.presentation.yellow_leaves=false
 world.resident.watering_remaining=0
 world.resident.watering_tree_id=""
 world.resident.fetching_water=false
 world.resident.carrying_water=false
 world.resident.model.carrying_water=false
 payload.approvedWins=wins
 snapshot()
 send("treeLeaves",{"yellow":false})
func tree_seed():
 tree_set(0)
 world.resident.position=HomesteadItems.cell_center(Vector2i(10,7))
 world.resident.route.clear()
 world.resident.state="pause"
 world.resident.timer=2.0
func tree_mission(count: int):
 payload.approvedWins+=count
 snapshot()
 send("waterTree",{"count":count})
func start_well_story():
 tree_story_clock=-1
 tree_set(13)
 world.resident.position=HomesteadItems.cell_center(world.navigation.closest(world.navigation.well_approach()+Vector3(-1,0,0))) if world.navigation.well_center.is_finite() else Vector3.ZERO
 world.resident.route.clear()
 world.resident.state="pause"
 world.resident.timer=100
 world.pan_focus=Vector3(0.5,1.2,0.5)
 world.pan_size=9.2
 send("camera",{"mode":"pan","resetZoom":true})
 well_phase=0
 well_elapsed=0.0
func advance_tree_story(delta: float):
 if well_phase>=0:
  well_elapsed+=delta
  if well_phase==0 and well_elapsed>1:
   well_phase=1
   tree_mission(1)
  elif well_phase==1 and world.resident.watering_remaining==0:
   well_phase=2
   world.resident.visit("garden")
  elif well_phase==2 and world.resident.state=="water" and world.resident.target_id=="garden":
   well_phase=3
 if tree_story_clock>=0:
  tree_story_clock+=delta
  if tree_story_step<0:
   tree_story_step=0
   tree_seed()
  # Wait for the real refill/walk/watering to finish, rather than cutting a trip.
  var wait=7.0 if tree_story_step==8 else 3.0
  if tree_story_clock>=wait and world.resident.watering_remaining==0:
   tree_story_step+=1
   tree_story_clock=0.0
   if tree_story_step==8: send("treeLeaves",{"yellow":true})
   elif tree_story_step<=9: tree_mission(3 if tree_story_step in [4,5,6] else 1)
   else: tree_story_clock=-1
 var model=world.presentation.nodes.tree.get_child(0).get_node("MissionTree")
 var stage="Planted seed" if model.wins==0 else "Seedling" if model.wins<3 else "Young tree" if model.wins<13 else "Full grown"
 if world.resident.watering_remaining>0: stage="Watering"
 elif model.yellow: stage="Amber leaves · growth kept"
 elif model.thirst>0.03: stage="Recovering"
 if well_slice: stage=world.resident.activity
 tree_label.text=stage+" · "+str(payload.approvedWins)+" approved missions"
 if output!="" and not busy_capture and elapsed>=next_tree_frame:
  next_tree_frame=elapsed+0.2
  tree_captures.append({"frame":capture_index+1,"wins":model.wins,"yellow":model.yellow,"stage":stage})
  busy_capture=true
  capture_index+=1
  capture()

func camera_option(id: int):
 match id:
  0: camera("detail")
  1: send("camera",{"zoom":0.85})
  2: send("camera",{"zoom":1.18})

func on_message(raw: String):
 var message=JSON.parse_string(raw)
 if message.type=="activity":
  events.append({"seconds":snapped(elapsed,0.01),"state":world.resident.state,"destination":world.resident.destination_kind})
 if message.type=="selected": send("select",{"id":message.payload.id,"fromHold":message.payload.get("gesture","")=="hold"})
 if message.type=="productionRequested": activity_label.text="Open "+message.payload.station+" menu (native host action)"
 if message.type=="visited": send("visit",{"id":message.payload.id})
 # Disposable collect: the bubble leaves; nothing is saved.
 for key in ["visited","gather"]:
  if message.type==key:
   var id=message.payload.get("id",message.payload.get("producer",""))
   if payload.harvest.has(id):
    payload.harvest.erase(id)
    snapshot()
 if message.type=="placementIntent":
  for item in payload.items:
   if item.id==message.payload.id:
    item.cell=message.payload.cell
    item.rotation=message.payload.rotation
  snapshot()
  send("cancel")
func _unhandled_key_input(event):
 if not event.is_pressed() or event.is_echo(): return
 match event.keycode:
  KEY_PLUS, KEY_EQUAL, KEY_KP_ADD: send("camera",{"zoom":1.0/1.2})
  KEY_MINUS, KEY_KP_SUBTRACT: send("camera",{"zoom":1.2})
  KEY_LEFT: send("nudge",{"x":-1})
  KEY_RIGHT: send("nudge",{"x":1})
  KEY_UP: send("nudge",{"z":-1})
  KEY_DOWN: send("nudge",{"z":1})
  KEY_R: send("rotate")
  KEY_ENTER: send("confirm")
  KEY_ESCAPE: send("cancel")
func _process(delta):
 if world==null: return false
 elapsed+=delta
 if tree_slice: advance_tree_story(delta)
 if construction_review:
  var step=mini(3,int(elapsed/5.0))
  if step!=construction_step:
   construction_step=step
   payload.construction=[] if step==3 else [{"placeID":"windmill","remaining":[40,22,6][step],"progress":[0.1,0.5,0.86][step]}]
   snapshot()
 activity_label.text=world.resident.activity
 if elapsed>=next_sample:
  next_sample+=0.5
  var actor=world.resident
  motion_samples.append({"seconds":snapped(elapsed,0.01),"state":actor.state,"position":[actor.position.x,actor.position.z],"facing":actor.facing,"leftLeg":actor.model.left_leg.rotation.x,"leftKnee":actor.model.left_knee.rotation.x,"rightArm":actor.model.right_arm.rotation.x,"canVisible":actor.model.can.visible,"animation":actor.model.animator.current_animation})
 if not tree_slice and output!="" and not busy_capture and capture_index<capture_times.size() and elapsed>=capture_times[capture_index]:
  busy_capture=true
  capture_index+=1
  capture()
 if duration>0 and float(Time.get_ticks_msec()-started_ms)/1000>=duration and not busy_capture:
  if output!="":
   var report={"engine":Engine.get_version_info(),"platform":OS.get_name(),"seconds":elapsed,"wallSeconds":float(Time.get_ticks_msec()-started_ms)/1000,"renderer":RenderingServer.get_video_adapter_name(),"motionSamples":motion_samples,"events":events,"distanceWalked":world.resident.distance_walked,"blockedSamples":world.resident.blocked_samples,"residentSourceSHA256":FileAccess.get_sha256("res://scripts/resident.gd"),"modelSourceSHA256":FileAccess.get_sha256("res://scripts/resident_model.gd"),"sceneSourceSHA256":FileAccess.get_sha256("res://scripts/homestead.gd"),"presentationSourceSHA256":FileAccess.get_sha256("res://scripts/presentation.gd"),"harnessSHA256":FileAccess.get_sha256("res://tests/mac_playground.gd")}
   if tree_slice: report.treeFrames=tree_captures
   var file=FileAccess.open(output+"/manifest.json",FileAccess.WRITE)
   file.store_string(JSON.stringify(report,"  "))
  print("HOMESTEAD_MAC_REVIEW seconds=",snapped(elapsed,0.1)," distance=",world.resident.distance_walked," blocked=",world.resident.blocked_samples)
  quit()
 return false
func capture():
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(output+"/frame-%04d.png"%capture_index)
 busy_capture=false
