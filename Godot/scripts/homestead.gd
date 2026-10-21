extends Node3D
# Versioned, renderer-only boundary: native Tuvlo owns all committed state.
signal host_message(json: String)
var data=HomesteadWorldData.new()
var navigation=HomesteadNavigation.new()
var presentation=HomesteadPresentation.new()
var resident=HomesteadResident.new()
var creature: HomesteadCreature
var camera=Camera3D.new()
var session=""
var layout_signature=""
var camera_mode="overview"
var yaw=0.25
const OVERVIEW_PITCH=PI/6 # 30 degrees: roofs and faces read without flattening the land.
var zoom=1.0
var camera_initialized=false
var orbit_yaw=0.25
var orbit_focus=Vector3.ZERO
var orbit_pitch=OVERVIEW_PITCH
var envelope_revision=-1
var scenery_radius=24.0
var fit_key=Vector3(INF,INF,INF)
var fit_cache={}

var reduced_motion=false
var paused=false
var ready_for_snapshot=false
var web_callback
var selected_id=""
var preview_cell=Vector2i.ZERO
var preview_rotation=0
var preview_revision=0
var dragging=false
var pending_pick=null
var previous_touch=Vector2.ZERO
var clock=0.0
var metrics_clock=0.0
var diagnostics=false
var pending_intent=""

func _ready():
 Engine.max_fps=60
 var environment=WorldEnvironment.new()
 var settings=Environment.new()
 settings.background_mode=Environment.BG_COLOR
 settings.background_color=Color("e7eddf")
 settings.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
 settings.ambient_light_color=Color("cedddc")
 settings.ambient_light_energy=0.58
 # Match the character-review stage; Compatibility/WebGL must retain palette contrast.
 settings.tonemap_mode=Environment.TONE_MAPPER_LINEAR
 environment.environment=settings
 add_child(environment)
 var light=DirectionalLight3D.new()
 light.rotation_degrees=Vector3(-48,-38,0)
 light.light_color=Color("fff0d8")
 light.light_energy=1.05
 light.light_angular_distance=0.8
 light.shadow_opacity=0.68
 light.directional_shadow_max_distance=100.0
 light.shadow_enabled=true
 add_child(light)
 var fill=DirectionalLight3D.new()
 fill.rotation_degrees=Vector3(-28,145,0)
 fill.light_color=Color("c9e0e2")
 fill.light_energy=0.16
 fill.light_specular=0.0
 add_child(fill)
 add_child(camera)
 camera.near=0.08
 camera.far=180.0
 camera.projection=Camera3D.PROJECTION_ORTHOGONAL
 camera.current=true
 add_child(presentation)
 presentation.setup(data)
 navigation.rebuild(data)
 add_child(resident)
 resident.setup(data,navigation)
 resident.activity_changed.connect(func(_text): call_deferred("send_activity"))
 ready_for_snapshot=true
 resident.set_physics_process(false)
 if OS.has_feature("web"):
  web_callback=JavaScriptBridge.create_callback(_web_receive)
  JavaScriptBridge.get_interface("window").tuvloReceive=web_callback
 emit_message("ready",{"protocol":1})

func _web_receive(arguments):
 if arguments.size()==1 and arguments[0] is String: receive_host_json(arguments[0])

func emit_message(type: String,payload: Dictionary):
 var json=JSON.stringify({"version":1,"session":session,"type":type,"payload":payload})
 host_message.emit(json)
 if OS.has_feature("web"):
  var handler=JavaScriptBridge.get_interface("window").webkit.messageHandlers.world
  handler.postMessage(json)

func receive_host_json(json: String):
 if not ready_for_snapshot or json.length()>1000000: return
 var packet=JSON.parse_string(json)
 if not packet is Dictionary or packet.get("version")!=1: return
 var type=packet.get("type","")
 var payload=packet.get("payload",{})
 if not payload is Dictionary: return
 if type=="snapshot":
  if not packet.get("session") is String or packet.session.length()>64: return
  var next_data=HomesteadWorldData.new()
  if not next_data.apply_snapshot(payload):
   emit_message("error",{"code":"invalid-snapshot"})
   return
  var first_snapshot=session==""
  var changing_child=session!="" and session!=packet.session
  var new_discovery=not data.discovered and next_data.discovered and not first_snapshot and not changing_child
  session=packet.session
  var wins=int(payload.get("approvedWins",0))
  var growth=0 if wins<3 else (1 if wins<13 else 2)
  var signature=JSON.stringify([payload.get("items",[]),payload.get("land",[]),growth,wins>=34,wins>=55])
  data.items=next_data.items
  data.land_sides=next_data.land_sides
  data.approvals=next_data.approvals
  data.growth_tree_id=next_data.growth_tree_id
  data.discovered=next_data.discovered
  reduced_motion=payload.get("reducedMotion",false)==true
  diagnostics=payload.get("diagnostics",false)==true
  if signature!=layout_signature:
   layout_signature=signature
   presentation.rebuild()
   navigation.rebuild(data)
   resident.world_changed()
   if is_instance_valid(creature): creature.world_changed()
  if changing_child:
   resident.route.clear()
   resident.state="pause"
   resident.timer=0.5
   resident.position=HomesteadItems.cell_center(navigation.closest(Vector3.ZERO))
  resident.model.apply_appearance(payload.get("appearance",{}))
  if data.discovered and not is_instance_valid(creature):
   creature=HomesteadCreature.new()
   add_child(creature)
   creature.setup(data,navigation,not new_discovery)
   if new_discovery: resident.greet_discovery()
  elif not data.discovered and is_instance_valid(creature):
   remove_child(creature)
   creature.queue_free()
   creature=null
  if selected_id!="": update_preview()
  set_paused(false)
  emit_message("snapshotApplied",{"revision":payload.get("revision","")})
  return
 if packet.get("session")!=session or session=="": return
 match type:
  "lifecycle": set_paused(payload.get("paused",true)==true)
  "camera":
   if payload.get("mode") in ["overview","home","follow","detail"]:
    if camera_mode!=payload.mode: zoom=1.0
    camera_mode=payload.mode
   if payload.get("resetZoom",false)==true: zoom=1.0
   zoom=clampf(zoom*clampf(float(payload.get("zoom",1)),0.75,1.3),1.0 if camera_mode=="overview" else 0.65,1.5)
   yaw+=clampf(float(payload.get("rotation",0)),-PI,PI)
  "select":
   selected_id=payload.get("id","")
   var item=selected_item()
   if item.is_empty():
    selected_id=""
    presentation.clear_preview()
   else:
    preview_cell=item.cell
    preview_rotation=item.rotation
    update_preview()
  "nudge":
   preview_cell+=Vector2i(clampi(int(payload.get("x",0)),-1,1),clampi(int(payload.get("z",0)),-1,1))
   preview_cell=preview_cell.clamp(Vector2i(-4,-4),Vector2i(21,15))
   update_preview()
  "previewVerdict":
   var item=selected_item()
   if int(payload.get("revision",-1))==preview_revision and not item.is_empty():
    presentation.highlight(preview_cell,HomesteadItems.footprint(item.kind,preview_rotation),payload.get("valid",false)==true)
  "rotate":
   preview_rotation=(preview_rotation+1)%4
   update_preview()
  "cancel":
   pending_intent=""
   selected_id=""
   presentation.clear_preview()
  "confirm":
   var item=selected_item()
   if not item.is_empty() and data.placement_error(item.kind,preview_cell,preview_rotation,selected_id)=="":
    if pending_intent=="": pending_intent=new_command_id()
    emit_message("placementIntent",{"commandID":pending_intent,"id":selected_id,"cell":{"x":preview_cell.x,"z":preview_cell.y},"rotation":preview_rotation})

func set_paused(value: bool):
 var was_paused=paused
 paused=value
 if value:
  pending_pick=null
  dragging=false
 process_mode=Node.PROCESS_MODE_DISABLED if value else Node.PROCESS_MODE_INHERIT
 RenderingServer.render_loop_enabled=not value
 resident.set_physics_process(not paused and session!="")
 resident.model.set_process(not paused)
 presentation.set_process(not paused)
 if is_instance_valid(creature): creature.set_physics_process(not paused)
 if was_paused and not paused and selected_id!="": update_preview()

# The native app retains one engine but releases all child-specific scene state.
func clear_host_session():
 session=""
 selected_id=""
 pending_intent=""
 pending_pick=null
 layout_signature=""
 diagnostics=false
 data.items.clear()
 data.inventory.clear()
 data.land_sides.clear()
 data.approvals=0
 data.growth_tree_id=""
 data.discovered=false
 presentation.clear_preview()
 presentation.rebuild()
 navigation.rebuild(data)
 resident.route.clear()
 resident.target_id=""
 resident.state="pause"
 resident.arrivals.clear()
 resident.pending_discovery=false
 resident.model.apply_appearance({})
 resident.model.set_motion("idle")
 if is_instance_valid(creature):
  creature.queue_free()
  creature=null
 camera_mode="overview"
 yaw=0.25
 zoom=1.0
 camera_initialized=false
 set_paused(true)

func update_preview():
 pending_intent=""
 preview_revision+=1
 var item=selected_item()
 if item.is_empty(): return
 var valid=data.placement_error(item.kind,preview_cell,preview_rotation,selected_id)==""
 presentation.highlight(preview_cell,HomesteadItems.footprint(item.kind,preview_rotation),valid)
 emit_message("preview",{"revision":preview_revision,"valid":valid,"cell":{"x":preview_cell.x,"z":preview_cell.y},"rotation":preview_rotation})

func _input(event):
 if paused or session=="": return
 if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed:
  dragging=false
  return
 if event is InputEventScreenTouch or event is InputEventScreenDrag or event is InputEventMouseButton or event is InputEventMouseMotion:
  if not get_viewport().get_visible_rect().has_point(event.position): return
 if event is InputEventScreenDrag:
  if selected_id=="": yaw-=event.relative.x*0.006
  else: point_at(event.position)
 elif event is InputEventScreenTouch and event.pressed: point_at(event.position)
 elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
  dragging=event.pressed
  previous_touch=event.position
  if event.pressed: point_at(event.position)
 elif event is InputEventMouseMotion and dragging:
  if selected_id=="": yaw-=event.relative.x*0.006
  else: point_at(event.position)

func point_at(point: Vector2):
 if selected_id=="":
  pending_pick=point
  return
 var from=camera.project_ray_origin(point)
 var direction=camera.project_ray_normal(point)
 var hit=Plane(Vector3.UP,0).intersects_ray(from,direction)
 if hit==null: return
 var cell=HomesteadItems.cell_at(hit)
 if preview_cell!=cell:
  preview_cell=cell
  update_preview()

func _physics_process(_delta):
 if paused or pending_pick==null: return
 var point: Vector2=pending_pick
 pending_pick=null
 var from=camera.project_ray_origin(point)
 var direction=camera.project_ray_normal(point)
 var query=PhysicsRayQueryParameters3D.create(from,from+direction*100,1)
 var result=get_world_3d().direct_space_state.intersect_ray(query)
 if not result.is_empty():
  var id=result.collider.get_meta("item_id","")
  if not data.find(id).is_empty():
   emit_message("selected",{"id":id})
   return
 var hit=Plane(Vector3.UP,0).intersects_ray(from,direction)
 if hit!=null:
  var item=data.item_at(HomesteadItems.cell_at(hit))
  if not item.is_empty(): emit_message("selected",{"id":item.id})

func _process(delta):
 if paused: return
 clock+=delta
 metrics_clock+=delta
 if diagnostics and metrics_clock>=5:
  metrics_clock=0
  emit_message("metrics",{"fps":Engine.get_frames_per_second(),"processSeconds":Performance.get_monitor(Performance.TIME_PROCESS),"staticBytes":Performance.get_monitor(Performance.MEMORY_STATIC),"drawCalls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"residentSteps":resident.steps})
 presentation.reduced_motion=reduced_motion
 resident.reduced_motion=reduced_motion
 if is_instance_valid(creature): creature.reduced_motion=reduced_motion
 var viewport=get_viewport().get_visible_rect().size
 var aspect=viewport.x/maxf(1,viewport.y)
 var immediate=reduced_motion or not camera_initialized
 var blend=1-exp(-delta*5.5)
 orbit_yaw=yaw if immediate else lerp_angle(orbit_yaw,yaw,blend)
 var overview=overview_fit(aspect,orbit_yaw)
 var focus=overview.focus
 var size=overview.size*zoom
 var pitch=OVERVIEW_PITCH
 if camera_mode in ["follow","detail"]:
  focus=resident.position+Vector3(0,1.0,0)
  size=(7.0 if camera_mode=="follow" else 3.8)*zoom
  pitch=deg_to_rad(28)
 elif camera_mode=="home":
  for item in data.items:
   if item.kind=="cottage":
    focus=HomesteadItems.item_center(item)+Vector3(0,1.1,1.4)
    size=9.0*zoom
    break
 # The fitted center already changes smoothly with orbit_yaw. A second lag
 # here can crop a plot while Overview rotates or returns from a closer view.
 orbit_focus=focus if immediate or camera_mode=="overview" else orbit_focus.lerp(focus,blend)
 orbit_pitch=pitch if immediate else lerpf(orbit_pitch,pitch,blend)
 if envelope_revision!=presentation.visual_revision:
  scenery_radius=0.0
  for point in overview_points(): scenery_radius=maxf(scenery_radius,Vector2(point.x,point.z).length())
  scenery_radius+=2.0 # authored roof/eave margin, independent of placement collision boxes
  envelope_revision=presentation.visual_revision
 # Orthographic magnification is camera.size. The lens stays beyond the entire
 # scenery envelope at every angle, even while focus/mode changes. Interpolate
 # angles, never the camera's Cartesian position (a chord can cross a building).
 var radius=maxf(32.0,scenery_radius+Vector2(orbit_focus.x,orbit_focus.z).length()+8.0)
 camera.position=orbit_focus+Vector3(sin(orbit_yaw)*radius,radius*tan(orbit_pitch),cos(orbit_yaw)*radius)
 camera.size=size if immediate else lerpf(camera.size,size,blend)
 if camera_mode=="overview": camera.size=maxf(size,camera.size)
 camera.look_at(orbit_focus)
 camera_initialized=true
 presentation.update_character_visibility(camera,resident.position,camera_mode in ["follow","detail"])

func overview_points() -> Array[Vector3]:
 # Include inactive plots as well as the active clearing; no imaginary roofs
 # at empty corners. Keep these extents shared with the terrain renderer.
 var points: Array[Vector3]=[]
 var regions=[{"center":Vector3.ZERO,"size":HomesteadItems.BASE_LAND_SIZE}]
 for center in HomesteadItems.LAND_CENTERS.values(): regions.append({"center":center,"size":HomesteadItems.PLOT_SIZE})
 for region in regions:
  var half_size=region.size*0.5
  for x in [-half_size.x,half_size.x]:
   for z in [-half_size.y,half_size.y]:
    for y in [-0.9,0.8]: points.append(region.center+Vector3(x,y,z))
 for item in data.items:
  var center=HomesteadItems.item_center(item)
  var half_size=Vector2(HomesteadItems.footprint(item.kind,item.rotation))*0.5+Vector2.ONE*0.25
  var height=HomesteadItems.DEFINITIONS[item.kind].height
  for x in [-half_size.x,half_size.x]:
   for z in [-half_size.y,half_size.y]: points.append(center+Vector3(x,height,z))
 return points

func overview_fit(aspect: float,angle: float=INF) -> Dictionary:
 if is_inf(angle): angle=yaw
 var key=Vector3(angle,aspect,presentation.visual_revision)
 if key.is_equal_approx(fit_key): return fit_cache
 var horizontal=Vector3(cos(angle),0,-sin(angle))
 var vertical=Vector3(-sin(angle)*sin(OVERVIEW_PITCH),cos(OVERVIEW_PITCH),-cos(angle)*sin(OVERVIEW_PITCH))
 var low=Vector2(INF,INF)
 var high=Vector2(-INF,-INF)
 for point in overview_points():
  var projected=Vector2(horizontal.dot(point),vertical.dot(point))
  low=low.min(projected)
  high=high.max(projected)
 var center=(low+high)*0.5
 var extent=high-low
 fit_cache={"focus":horizontal*center.x+vertical*center.y,"size":maxf(extent.y,extent.x/maxf(aspect,0.2))*1.12}
 fit_key=key
 return fit_cache

func overview_size(aspect: float) -> float:
 return overview_fit(aspect).size

func selected_item() -> Dictionary:
 var placed=data.find(selected_id)
 return placed if not placed.is_empty() else data.inventory.get(selected_id,{})

func send_activity():
 emit_message("activity",{"key":resident.state,"destination":resident.destination_kind})

func new_command_id() -> String:
 var bytes=Crypto.new().generate_random_bytes(16)
 bytes[6]=(bytes[6]&15)|64
 bytes[8]=(bytes[8]&63)|128
 var hex=bytes.hex_encode()
 return hex.substr(0,8)+"-"+hex.substr(8,4)+"-"+hex.substr(12,4)+"-"+hex.substr(16,4)+"-"+hex.substr(20,12)
