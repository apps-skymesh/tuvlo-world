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
var equipped=false
var cottage_slice=false
func _initialize(): call_deferred("run")
func run():
 started_ms=Time.get_ticks_msec()
 root.size_changed.connect(keep_landscape)
 keep_landscape()
 DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
 var args=OS.get_cmdline_user_args()
 for index in args.size():
  if args[index]=="--equipped": equipped=true
  if args[index]=="--cottage": cottage_slice=true
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
  "land":[],"appearance":{"hair":3,"outfit":0},"approvedWins":21,"growthTreeID":"tree"}
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
 for mode in ["home","overview","follow"]: button(toolbar,mode.capitalize(),func(): camera(mode))
 var options=MenuButton.new()
 options.text="Camera options"
 toolbar.add_child(options)
 for title in ["Close up","Rotate left","Rotate right","Zoom in","Zoom out"]: options.get_popup().add_item(title)
 options.get_popup().id_pressed.connect(camera_option)
 button(toolbar,"Cottage",func():
  cottage_slice=true
  reset(false)
  camera("home"))
 button(toolbar,"Starter",func():
  cottage_slice=false
  reset(false))
 button(toolbar,"Equipped",func(): reset(true))
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
func camera_option(id: int):
 match id:
  0: camera("detail")
  1: send("camera",{"rotation":-PI/4})
  2: send("camera",{"rotation":PI/4})
  3:
   if world.camera_mode=="overview": camera("follow")
   send("camera",{"zoom":0.85})
  4: send("camera",{"zoom":1.18})
func on_message(raw: String):
 var message=JSON.parse_string(raw)
 if message.type=="activity":
  events.append({"seconds":snapped(elapsed,0.01),"state":world.resident.state,"destination":world.resident.destination_kind})
 if message.type=="selected": send("select",{"id":message.payload.id,"fromHold":message.payload.get("gesture","")=="hold"})
 if message.type=="visited": send("visit",{"id":message.payload.id})
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
 activity_label.text=world.resident.activity
 if elapsed>=next_sample:
  next_sample+=0.5
  var actor=world.resident
  motion_samples.append({"seconds":snapped(elapsed,0.01),"state":actor.state,"position":[actor.position.x,actor.position.z],"facing":actor.facing,"leftLeg":actor.model.left_leg.rotation.x,"leftKnee":actor.model.left_knee.rotation.x,"rightArm":actor.model.right_arm.rotation.x,"canVisible":actor.model.can.visible,"animation":actor.model.animator.current_animation})
 if output!="" and not busy_capture and capture_index<capture_times.size() and elapsed>=capture_times[capture_index]:
  busy_capture=true
  capture_index+=1
  capture()
 if duration>0 and float(Time.get_ticks_msec()-started_ms)/1000>=duration and not busy_capture:
  if output!="":
   var report={"engine":Engine.get_version_info(),"platform":OS.get_name(),"seconds":elapsed,"wallSeconds":float(Time.get_ticks_msec()-started_ms)/1000,"renderer":RenderingServer.get_video_adapter_name(),"motionSamples":motion_samples,"events":events,"distanceWalked":world.resident.distance_walked,"blockedSamples":world.resident.blocked_samples,"residentSourceSHA256":FileAccess.get_sha256("res://scripts/resident.gd"),"modelSourceSHA256":FileAccess.get_sha256("res://scripts/resident_model.gd"),"sceneSourceSHA256":FileAccess.get_sha256("res://scripts/homestead.gd"),"presentationSourceSHA256":FileAccess.get_sha256("res://scripts/presentation.gd"),"harnessSHA256":FileAccess.get_sha256("res://tests/mac_playground.gd")}
   var file=FileAccess.open(output+"/manifest.json",FileAccess.WRITE)
   file.store_string(JSON.stringify(report,"  "))
  print("HOMESTEAD_MAC_REVIEW seconds=",snapped(elapsed,0.1)," distance=",world.resident.distance_walked," blocked=",world.resident.blocked_samples)
  quit()
 return false
func capture():
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(output+"/frame-%02d.png"%capture_index)
 busy_capture=false
