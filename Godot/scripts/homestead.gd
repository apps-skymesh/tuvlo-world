extends Node3D
# Versioned, renderer-only boundary: native Tuvlo owns all committed state.
signal host_message(json: String)
var data=HomesteadWorldData.new()
var navigation=HomesteadNavigation.new()
var presentation=HomesteadPresentation.new()
var resident=HomesteadResident.new()
var guests: Array[HomesteadResident]=[]
var creature: HomesteadCreature
var camera=Camera3D.new()
var session=""
var layout_signature=""
var navigation_signature=""
var camera_mode="overview"
var focus_item_id=""
var focus_station=""
var panel_framing=0.0
var camera_preview_frames=0
var panel_preview=false
var hold_menu_camera=true
const FIXED_YAW=0.25
const MIN_CAMERA_SIZE=3.4
var yaw=FIXED_YAW
const OVERVIEW_PITCH=PI/6 # 30 degrees: roofs and faces read without flattening the land.
var zoom=1.0
var pan_focus=Vector3.ZERO
var pan_size=12.0
var camera_initialized=false
var orbit_yaw=0.25
var orbit_focus=Vector3.ZERO
var orbit_pitch=OVERVIEW_PITCH
var envelope_revision=-1
var scenery_radius=24.0
var fit_key=Vector3(INF,INF,INF)
var fit_cache={}

var reduced_motion=false
var sun: DirectionalLight3D
var sunrise_remaining=0.0
const SUNRISE_SECONDS=3.6
const SUN_REST_ENERGY=0.92
var paused=false
var ready_for_snapshot=false
var web_callback
var land_preview=false
var selected_id=""
var preview_cell=Vector2i.ZERO
var preview_rotation=0
var preview_revision=0
var dragging=false
var pending_pick=null
var previous_touch=Vector2.ZERO
const HOLD_SECONDS=0.45
const HOLD_SLOP=12.0
var pointer_down=false
var pointer_index=-1
var press_origin=Vector2.ZERO
var press_elapsed=0.0
var press_cancelled=false
var hold_candidate=""
var hold_emitted=false
var pending_visit=null
var grab_offset=Vector2i.ZERO
var moving_selection=false
var touches={}
var pinch_distance=0.0
var multitouch=false
var clock=0.0
var metrics_clock=0.0
var diagnostics=false
var pending_intent=""

func _ready():
 Engine.max_fps=60
 var environment=WorldEnvironment.new()
 var settings=Environment.new()
 settings.background_mode=Environment.BG_COLOR
 settings.background_color=Color("efe6c8")
 settings.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
 settings.ambient_light_color=Color("f6ead0")
 settings.ambient_light_energy=0.50
 # Keep diffuse highlights below clipping in the shipped Compatibility/WebGL renderer.
 # Tune the lights directly: post-process exposure is not shared by every renderer.
 # Glow stays off. The grade holds the highlight cap.
 settings.tonemap_mode=Environment.TONE_MAPPER_LINEAR
 environment.environment=settings
 add_child(environment)
 var light=DirectionalLight3D.new()
 light.rotation_degrees=Vector3(-48,-38,0)
 light.light_color=Color("fff4d0")
 light.light_energy=SUN_REST_ENERGY
 light.light_angular_distance=0.8
 light.shadow_opacity=0.68
 light.directional_shadow_max_distance=100.0
 light.shadow_enabled=true
 add_child(light)
 sun=light
 var fill=DirectionalLight3D.new()
 fill.rotation_degrees=Vector3(-28,145,0)
 fill.light_color=Color("c9e0e2")
 fill.light_energy=0.10
 fill.light_specular=0.0
 add_child(fill)
 # Grade the final 3D image as well as its lights. Native SwiftUI controls
 # stay outside this pass; no screen-space depth/normal buffers are needed.
 var grade_layer=CanvasLayer.new()
 grade_layer.layer=0
 add_child(grade_layer)
 var grade=ColorRect.new()
 grade.name="WorldColorGrade"
 grade.mouse_filter=Control.MOUSE_FILTER_IGNORE
 grade_layer.add_child(grade)
 grade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var grade_material=ShaderMaterial.new()
 grade_material.shader=preload("res://scripts/world_grade.gdshader")
 grade.material=grade_material
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
 resident.tree_watered.connect(_on_tree_watered)
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
  if changing_child:
   # All living-tree animation belongs to the previous child session.
   for root in presentation.nodes.values():
    presentation.prop_root.remove_child(root)
    root.queue_free()
   presentation.nodes.clear()
   layout_signature=""
   presentation.pending_tree_growth=0
   presentation.yellow_leaves=false
   resident.watering_remaining=0
   resident.watering_tree_id=""
   resident.fetching_water=false
   resident.carrying_water=false
   resident.model.carrying_water=false
   navigation.well_cell=Vector2i(10000,10000)
  var new_discovery=not data.discovered and next_data.discovered and not first_snapshot and not changing_child
  session=packet.session
  var wins=int(payload.get("approvedWins",0))
  # Crop art and building phases do not change walkable footprints.
  var next_navigation=JSON.stringify([next_data.items,next_data.land_sides,next_data.construction.filter(func(build): return next_data.find(build.placeID).get("kind","")=="cottage").map(func(build): return build.placeID)])
  var signature=JSON.stringify([payload.get("items",[]),payload.get("land",[]),wins,next_data.growth_tree_id,payload.get("reducedMotion",false)==true,wins>=34,wins>=55,next_data.edges,next_data.wheat_garden,next_data.harvest.values().has("wheat"),next_data.farm_stages,next_data.farm_fruit_stage,next_data.construction.map(func(build): return [build.placeID,int(floor(clampf(build.progress,0.0,0.999)*5.0))])])
  data.items=next_data.items
  data.inventory=next_data.inventory
  data.land_sides=next_data.land_sides
  data.approvals=next_data.approvals
  data.growth_tree_id=next_data.growth_tree_id
  data.discovered=next_data.discovered
  data.harvest=next_data.harvest
  data.edges=next_data.edges
  data.visitor=next_data.visitor
  data.visitors=next_data.visitors.duplicate()
  data.wheat_garden=next_data.wheat_garden
  data.production=next_data.production
  data.construction=next_data.construction
  data.farm_stages=next_data.farm_stages
  data.farm_fruit_stage=next_data.farm_fruit_stage
  reduced_motion=payload.get("reducedMotion",false)==true
  presentation.reduced_motion=reduced_motion
  resident.reduced_motion=reduced_motion
  # Animation may defer a reveal, never the authoritative earned size forever.
  if reduced_motion or data.find(data.growth_tree_id).is_empty() or (resident.watering_tree_id!="" and resident.watering_tree_id!=data.growth_tree_id):
   presentation.pending_tree_growth=0
   resident.cancel_tree_watering()
  else:
   presentation.pending_tree_growth=mini(presentation.pending_tree_growth,data.approvals)
   resident.watering_remaining=mini(resident.watering_remaining,presentation.pending_tree_growth)
   if presentation.pending_tree_growth==0: resident.cancel_tree_watering()
  diagnostics=payload.get("diagnostics",false)==true
  if signature!=layout_signature:
   layout_signature=signature
   presentation.rebuild()
  if next_navigation!=navigation_signature:
   navigation_signature=next_navigation
   navigation.rebuild(data)
   presentation.well.place(navigation.well_center)
   presentation.place_ovens(navigation.oven_centers)
   resident.world_changed()
   for person in guests:
    if is_instance_valid(person): person.world_changed()
   if is_instance_valid(creature): creature.world_changed()
  update_guest()
  presentation.update_harvest()
  # A replayed construction state can remove a deck without changing its grid.
  if resident.place_visit!=null and not data.building(resident.target_id).is_empty():
   resident.cancel_place_visit()
  if changing_child:
   resident.cancel_place_visit()
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
  "landPreview":
   var side=str(payload.get("side","west" if payload.get("west",false)==true else ""))
   var show=side in ["west","east"]
   if show:
    var bounds: Rect2i=HomesteadItems.LAND_BOUNDS[side]
    presentation.highlight(bounds.position,bounds.size,true)
   elif land_preview:
    presentation.clear_preview()
   land_preview=show
  "lifecycle": set_paused(payload.get("paused",true)==true,payload.get("previewing",false)==true)
  "sunrise": begin_sunrise()
  "waterTree": begin_tree_watering(maxi(0,int(payload.get("count",0))))
  "treeLeaves":
   var requested_yellow=payload.get("yellow",false)==true
   # The host clears its memory on approval; show recovery when water lands.
   if requested_yellow or resident.watering_remaining<=0 or reduced_motion:
    presentation.yellow_leaves=requested_yellow
   presentation.rebuild()
  "camera":
   hold_menu_camera=false # Only an explicit camera action may move a paused view.
   camera_preview_frames=1 if reduced_motion else 90
   if paused and panel_preview:
    process_mode=Node.PROCESS_MODE_INHERIT
    RenderingServer.render_loop_enabled=true
   if payload.get("mode") in ["overview","home","follow","detail","place","pan"]:
    if camera_mode!=payload.mode: zoom=1.0
    camera_mode=payload.mode
   if payload.has("id"): focus_item_id=str(payload.id)
   if payload.has("id") or payload.has("mode"): focus_station=str(payload.get("station",""))
   if payload.has("framing"): panel_framing=clampf(float(payload.framing),0,0.65)
   if payload.get("resetZoom",false)==true: zoom=1.0
   if payload.has("zoom"): zoom_camera(float(payload.zoom))
   # Camera rotation is deliberately fixed, including legacy host commands.
   yaw=FIXED_YAW
  "select":
   selected_id=payload.get("id","")
   var item=selected_item()
   if item.is_empty():
    selected_id=""
    presentation.clear_preview()
   else:
    preview_cell=item.cell
    preview_rotation=item.rotation
    grab_offset=Vector2i.ZERO
    reset_press(false)
    if payload.get("fromHold",false)==true and selected_id==hold_candidate:
     var grabbed=ground_cell(press_origin)
     if grabbed!=null: grab_offset=grabbed-preview_cell
     moving_selection=true
    update_preview()
    set_paused(paused,panel_preview)
  "nudge":
   preview_cell+=Vector2i(clampi(int(payload.get("x",0)),-1,1),clampi(int(payload.get("z",0)),-1,1))
   preview_cell=preview_cell.clamp(HomesteadItems.WORLD_BOUNDS.position,HomesteadItems.WORLD_BOUNDS.end-Vector2i.ONE)
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
   reset_press()
   presentation.clear_preview()
   set_paused(paused,panel_preview)
  "visit":
   if not paused and selected_id=="": resident.visit(str(payload.get("id","")))
  "confirm":
   var item=selected_item()
   if not item.is_empty() and data.placement_error(item.kind,preview_cell,preview_rotation,selected_id)=="":
    if pending_intent=="": pending_intent=new_command_id()
    emit_message("placementIntent",{"commandID":pending_intent,"id":selected_id,"cell":{"x":preview_cell.x,"z":preview_cell.y},"rotation":preview_rotation})

func set_paused(value: bool, previewing: bool=false):
 var was_paused=paused
 paused=value
 panel_preview=value and previewing
 if value and not was_paused: hold_menu_camera=true
 camera_preview_frames=(1 if reduced_motion or hold_menu_camera else 90) if panel_preview else 0
 if value:
  touches.clear()
  multitouch=false
  pinch_distance=0.0
  reset_press()
  dragging=false
 # A native window freezes simulation but may briefly render a new camera or
 # appearance. Background/teardown still stop the entire render loop.
 process_mode=Node.PROCESS_MODE_INHERIT if not value or panel_preview else Node.PROCESS_MODE_DISABLED
 RenderingServer.render_loop_enabled=not value or panel_preview
 resident.process_mode=Node.PROCESS_MODE_DISABLED if paused or selected_id!="" else Node.PROCESS_MODE_INHERIT
 presentation.process_mode=Node.PROCESS_MODE_DISABLED if paused and not production_preview_active() else Node.PROCESS_MODE_INHERIT
 if is_instance_valid(creature): creature.process_mode=Node.PROCESS_MODE_DISABLED if paused or selected_id!="" else Node.PROCESS_MODE_INHERIT
 resident.set_physics_process(not paused and session!="" and selected_id=="")
 resident.model.set_process(not paused and selected_id=="")
 for person in guests:
  if is_instance_valid(person):
   person.process_mode=Node.PROCESS_MODE_DISABLED if paused or selected_id!="" else Node.PROCESS_MODE_INHERIT
   person.set_physics_process(not paused and session!="" and selected_id=="")
   person.model.set_process(not paused and selected_id=="")
 presentation.set_process(not paused or production_preview_active())
 if is_instance_valid(creature): creature.set_physics_process(not paused and selected_id=="")
 if was_paused and not paused and selected_id!="": update_preview()

# The native app retains one engine but releases all child-specific scene state.
func clear_host_session():
 resident.cancel_place_visit()
 presentation.pending_tree_growth=0
 presentation.yellow_leaves=false
 resident.watering_remaining=0
 resident.watering_tree_id=""
 resident.fetching_water=false
 resident.carrying_water=false
 resident.model.carrying_water=false
 navigation.well_cell=Vector2i(10000,10000)
 session=""
 reset_press()
 selected_id=""
 pending_intent=""
 pending_pick=null
 layout_signature=""
 navigation_signature=""
 diagnostics=false
 data.items.clear()
 data.inventory.clear()
 data.land_sides.clear()
 data.approvals=0
 data.growth_tree_id=""
 data.discovered=false
 data.visitor=""
 data.visitors.clear()
 data.wheat_garden=false
 data.production.clear()
 data.construction.clear()
 data.harvest={}
 data.edges=false
 data.farm_stages=[]
 data.farm_fruit_stage=-1
 update_guest()
 presentation.clear_preview()
 presentation.rebuild()
 presentation.update_harvest()
 navigation.rebuild(data)
 presentation.well.place(navigation.well_center)
 presentation.place_ovens(navigation.oven_centers)
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
 focus_item_id=""
 focus_station=""
 panel_framing=0.0
 yaw=FIXED_YAW
 zoom=1.0
 camera_initialized=false
 set_paused(true)

func update_preview():
 pending_intent=""
 preview_revision+=1
 var item=selected_item()
 if item.is_empty(): return
 var valid=data.placement_error(item.kind,preview_cell,preview_rotation,selected_id)==""
 presentation.preview_object(item,preview_cell,preview_rotation)
 presentation.highlight(preview_cell,HomesteadItems.footprint(item.kind,preview_rotation),valid)
 emit_message("preview",{"revision":preview_revision,"valid":valid,"cell":{"x":preview_cell.x,"z":preview_cell.y},"rotation":preview_rotation})

# The same gesture state serves real touch and the disposable desktop host.
# A drag on open ground pans. A drag that starts on the selected piece moves
# that piece from where it already stands. Looking around never buys land.
func reset_press(release=true):
 pending_pick=null
 pending_visit=null
 hold_candidate=""
 hold_emitted=false
 moving_selection=false
 press_elapsed=0.0
 press_cancelled=true
 if release:
  pointer_down=false
  pointer_index=-1
  dragging=false
 if selected_id=="": presentation.clear_preview()

func ground_cell(point: Vector2):
 var hit=Plane(Vector3.UP,0).intersects_ray(camera.project_ray_origin(point),camera.project_ray_normal(point))
 return null if hit==null else HomesteadItems.cell_at(hit)

func begin_press(point: Vector2,index: int):
 reset_press()
 pointer_down=true
 pointer_index=index
 dragging=true
 press_origin=point
 previous_touch=point
 press_cancelled=false
 grab_offset=Vector2i.ZERO
 moving_selection=false
 if selected_id=="": pending_pick=point
 else:
  var cell=ground_cell(point)
  var item=selected_item()
  if not item.is_empty():
   var footprint=Rect2i(preview_cell,HomesteadItems.footprint(item.kind,preview_rotation))
   if cell!=null and footprint.has_point(cell):
    grab_offset=cell-preview_cell
    moving_selection=true
   elif str(object_at_screen(point).get("id",""))==selected_id:
    var grabbed=preview_cell if cell==null else Vector2i(clampi(cell.x,footprint.position.x,footprint.end.x-1),clampi(cell.y,footprint.position.y,footprint.end.y-1))
    grab_offset=grabbed-preview_cell
    moving_selection=true
  # Wait for a drag or release: the first finger of a pinch is not a move.

func move_press(point: Vector2):
 if not pointer_down: return
 var movement=point-previous_touch
 previous_touch=point
 if moving_selection:
  point_at(point)
  return
 if not hold_emitted:
  if press_origin.distance_to(point)>HOLD_SLOP:
   if not press_cancelled and selected_id=="":
    presentation.clear_preview()
    # Include the initial slop so the terrain stays under the finger.
    movement=point-press_origin
   press_cancelled=true
   pending_pick=null
   hold_candidate=""
  if press_cancelled: pan_camera(point-movement,point)

func ground_point(point: Vector2):
 return Plane(Vector3.UP,0).intersects_ray(camera.project_ray_origin(point),camera.project_ray_normal(point))

func pan_camera(from: Vector2,to: Vector2):
 var start=ground_point(from)
 var finish=ground_point(to)
 if start==null or finish==null: return
 if camera_mode!="pan":
  pan_focus=orbit_focus
  pan_size=camera.size
  zoom=1.0
  camera_mode="pan"
  emit_message("cameraPanned",{})
 pan_focus+=start-finish
 # Camera movement never unlocks land. Bound the center to the owned world.
 var bounds=HomesteadItems.BASE_BOUNDS
 for side in data.land_sides: bounds=bounds.merge(HomesteadItems.LAND_BOUNDS[side])
 pan_focus.x=clampf(pan_focus.x,bounds.position.x-9.0,bounds.end.x-9.0)
 pan_focus.z=clampf(pan_focus.z,bounds.position.y-8.0,bounds.end.y-8.0)

func end_press(point: Vector2,cancelled=false):
 if not pointer_down: return
 if not cancelled and moving_selection: point_at(point)
 if not cancelled and selected_id=="" and not press_cancelled and not hold_emitted and press_origin.distance_to(point)<=HOLD_SLOP:
  pending_visit=press_origin
 pointer_down=false
 pointer_index=-1
 dragging=false
 moving_selection=false
 pending_pick=null
 if selected_id=="": presentation.clear_preview()

# Absolute bounds work for the full expanded map as well as a close Follow view.
# Zooming Overview starts a free view; Overview itself always fits every plot.
func camera_base_size() -> float:
 match camera_mode:
  "pan": return pan_size
  "follow": return 7.0
  "detail": return 3.8
  "home", "place": return 9.0
 var viewport=get_viewport().get_visible_rect().size
 return overview_fit(viewport.x/maxf(1,viewport.y),FIXED_YAW).size

func zoom_camera(factor: float):
 if not is_finite(factor) or factor<=0 or is_equal_approx(factor,1.0): return
 if camera_mode=="overview":
  pan_focus=orbit_focus
  pan_size=camera.size*(1.0-panel_framing)
  zoom=1.0
  camera_mode="pan"
  emit_message("cameraPanned",{})
 var viewport=get_viewport().get_visible_rect().size
 var maximum=overview_fit(viewport.x/maxf(1,viewport.y),FIXED_YAW).size*2.0
 var base=maxf(0.1,camera_base_size())
 zoom=clampf(zoom*factor,MIN_CAMERA_SIZE/base,maximum/base)

func _input(event):
 if paused or session=="": return
 if event is InputEventScreenTouch:
  if not event.pressed:
   touches.erase(event.index)
   if multitouch:
    pinch_distance=0.0
    if touches.size()==2:
     var points=touches.values()
     pinch_distance=points[0].distance_to(points[1])
    if touches.is_empty():
     multitouch=false
     pinch_distance=0.0
     reset_press()
   elif pointer_index==event.index: end_press(event.position,event.canceled)
   return
  if not get_viewport().get_visible_rect().has_point(event.position): return
  touches[event.index]=event.position
  if touches.size()>1:
   reset_press()
   multitouch=true
   var points=touches.values()
   pinch_distance=points[0].distance_to(points[1]) if touches.size()==2 else 0.0
   return
  if not multitouch: begin_press(event.position,event.index)
 elif event is InputEventScreenDrag:
  if not touches.has(event.index): return
  touches[event.index]=event.position
  if multitouch:
   if touches.size()==2:
    var points=touches.values()
    var distance=points[0].distance_to(points[1])
    if pinch_distance>8 and distance>8: zoom_camera(pinch_distance/distance)
    pinch_distance=distance
   return
  if pointer_index!=event.index: return
  if not get_viewport().get_visible_rect().has_point(event.position):
   reset_press()
   return
  move_press(event.position)
 elif event is InputEventMagnifyGesture:
  reset_press()
  zoom_camera(1.0/maxf(0.01,event.factor))
 elif event is InputEventMouseButton:
  if event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
   if event.pressed:
    reset_press()
    zoom_camera(0.88 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1.0/0.88)
  elif event.button_index==MOUSE_BUTTON_LEFT:
   if not event.pressed: end_press(event.position)
   elif touches.is_empty() and get_viewport().get_visible_rect().has_point(event.position): begin_press(event.position,-2)
 elif event is InputEventMouseMotion and pointer_index==-2:
  if not get_viewport().get_visible_rect().has_point(event.position): reset_press()
  else: move_press(event.position)

func point_at(point: Vector2):
 if selected_id=="": return
 var cell=ground_cell(point)
 if cell==null: return
 cell=(cell-grab_offset).clamp(HomesteadItems.WORLD_BOUNDS.position,HomesteadItems.WORLD_BOUNDS.end-Vector2i.ONE)
 if preview_cell!=cell:
  preview_cell=cell
  update_preview()

func object_at_screen(point: Vector2) -> Dictionary:
 var from=camera.project_ray_origin(point)
 var direction=camera.project_ray_normal(point)
 var query=PhysicsRayQueryParameters3D.create(from,from+direction*100,1)
 var result=get_world_3d().direct_space_state.intersect_ray(query)
 if not result.is_empty():
  var item=data.find(result.collider.get_meta("item_id",""))
  if not item.is_empty(): return item
 var cell=ground_cell(point)
 return {} if cell==null else data.item_at(cell)

# Edge woods/quarry and their bubbles carry a producer name, never an item.
func producer_at_screen(point: Vector2) -> String:
 var from=camera.project_ray_origin(point)
 var query=PhysicsRayQueryParameters3D.create(from,from+camera.project_ray_normal(point)*100,1)
 var result=get_world_3d().direct_space_state.intersect_ray(query)
 if result.is_empty(): return ""
 return str(result.collider.get_meta("producer_id",""))

func production_at_screen(point: Vector2) -> Dictionary:
 var from=camera.project_ray_origin(point)
 var query=PhysicsRayQueryParameters3D.create(from,from+camera.project_ray_normal(point)*100,1)
 var result=get_world_3d().direct_space_state.intersect_ray(query)
 if result.is_empty(): return {}
 var building_id=str(result.collider.get_meta("construction_id",""))
 if not building_id.is_empty() and not data.building(building_id).is_empty(): return {"station":"construction","placeID":building_id}
 var station=str(result.collider.get_meta("production_station",""))
 var owner=str(result.collider.get_meta("oven_place_id",""))
 for status in data.production:
  if status.station==station and (owner=="" or status.placeID==owner): return status
 return {}

func production_preview_active() -> bool:
 if not panel_preview or reduced_motion: return false
 if not data.construction.is_empty(): return true
 for status in data.production:
  if status.state==1: return true
 return false

func advance_hold(delta: float):
 if not pointer_down or press_cancelled or hold_emitted or selected_id!="": return
 press_elapsed+=delta
 if hold_candidate=="": return
 var item=data.find(hold_candidate)
 if item.is_empty():
  reset_press()
  return
 if press_elapsed>=0.12 and not is_instance_valid(presentation.preview_node):
  presentation.highlight(item.cell,HomesteadItems.footprint(item.kind,item.rotation),true,true)
 if press_elapsed>=HOLD_SECONDS:
  hold_emitted=true
  emit_message("selected",{"id":hold_candidate,"gesture":"hold"})

func _physics_process(delta):
 if paused: return
 if pending_pick!=null:
  var point: Vector2=pending_pick
  pending_pick=null
  var item=object_at_screen(point)
  if pointer_down and not press_cancelled: hold_candidate=str(item.get("id","")) if production_at_screen(point).is_empty() else ""
 if pending_visit!=null:
  var point: Vector2=pending_visit
  pending_visit=null
  var production_status=production_at_screen(point)
  var producer=producer_at_screen(point)
  var item={} if producer!="" else object_at_screen(point)
  if not production_status.is_empty(): emit_message("productionRequested",{"station":production_status.station,"id":production_status.placeID})
  elif producer!="": emit_message("gather",{"producer":producer})
  elif not item.is_empty(): emit_message("visited",{"id":item.id})
  else:
   var cell=ground_cell(point)
   if cell!=null:
    var side=unowned_land_at(cell)
    if side!="": emit_message("landRequested",{"side":side})
 advance_hold(delta)

func unowned_land_at(cell: Vector2i) -> String:
 for side in HomesteadItems.LAND_BOUNDS:
  if side not in data.land_sides and HomesteadItems.LAND_BOUNDS[side].has_point(cell): return side
 return ""

func _process(delta):
 if presentation.nodes.has(data.growth_tree_id):
  var tree=presentation.nodes[data.growth_tree_id].get_child(0).get_node_or_null("MissionTree")
  if tree is HomesteadMissionTree:
   tree.quiet=reduced_motion
   tree.set_water_source(resident.model.can.to_global(Vector3(0.29,0.09,0)),resident.state=="water" and resident.target_id==data.growth_tree_id)
 if session=="": return
 if paused:
  if not panel_preview or (camera_preview_frames<=0 and not production_preview_active()):
   process_mode=Node.PROCESS_MODE_DISABLED
   RenderingServer.render_loop_enabled=false
   return
  camera_preview_frames=maxi(0,camera_preview_frames-1)
 # Native overlay windows pause residents, not the camera/appearance preview.
 if not paused:
  clock+=delta
  metrics_clock+=delta
  update_sunrise(delta)
  presentation.well.update_watering(resident,delta,reduced_motion)
 if diagnostics and metrics_clock>=5:
  metrics_clock=0
  emit_message("metrics",{"fps":Engine.get_frames_per_second(),"processSeconds":Performance.get_monitor(Performance.TIME_PROCESS),"staticBytes":Performance.get_monitor(Performance.MEMORY_STATIC),"drawCalls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"residentSteps":resident.steps})
 navigation.view_direction=Vector3(sin(orbit_yaw),0,cos(orbit_yaw))
 presentation.reduced_motion=reduced_motion
 presentation.set_reading_place(resident.target_id if resident.place_visit!=null and resident.place_visit.kind=="nook" and resident.place_visit.phase in ["sit","reading","stand"] else "")
 resident.reduced_motion=reduced_motion
 for person in guests:
  if is_instance_valid(person): person.reduced_motion=reduced_motion
 if is_instance_valid(creature): creature.reduced_motion=reduced_motion
 # Menus may redraw appearance/highlights without changing the held map view.
 if paused and hold_menu_camera and camera_initialized:
  presentation.layout_markers()
  return
 var viewport=get_viewport().get_visible_rect().size
 var aspect=viewport.x/maxf(1,viewport.y)
 var immediate=reduced_motion or not camera_initialized
 var blend=1-exp(-delta*12.0)
 yaw=FIXED_YAW
 orbit_yaw=FIXED_YAW
 var overview=overview_fit(aspect,orbit_yaw)
 var focus=overview.focus
 var size=overview.size*zoom
 var pitch=OVERVIEW_PITCH
 if camera_mode=="pan":
  focus=pan_focus
  size=pan_size*zoom
  pitch=OVERVIEW_PITCH
 elif camera_mode in ["follow","detail"]:
  focus=resident.position+Vector3(0,1.0,0)
  size=(7.0 if camera_mode=="follow" else 3.8)*zoom
  pitch=OVERVIEW_PITCH
 elif camera_mode=="place":
  var item=data.find(focus_item_id)
  if not item.is_empty():
   focus=HomesteadItems.item_center(item)+Vector3(0,0.7,0)
   size=6.4*zoom
   if focus_station=="oven" and presentation.ovens.has(focus_item_id):
    focus=presentation.ovens[focus_item_id].position+Vector3(0,1.05,0)
    size=4.4*zoom
  elif focus_item_id.begins_with("edge:") and HomesteadItems.EDGE_CENTERS.has(focus_item_id.substr(5)):
   focus=HomesteadItems.EDGE_CENTERS[focus_item_id.substr(5)]+Vector3(0,0.7,0)
   size=10.0*zoom
 elif camera_mode=="home":
  for item in data.items:
   if item.kind=="cottage":
    focus=HomesteadItems.item_center(item)+Vector3(0,1.1,1.4)
    size=9.0*zoom
    break
 # Overview and terrain drags use their exact center so plots remain fitted
 # and the map stays under the finger. Follow eases toward the resident.
 orbit_focus=focus if immediate or camera_mode in ["overview","pan"] else orbit_focus.lerp(focus,blend)
 orbit_pitch=pitch if immediate else lerpf(orbit_pitch,pitch,blend)
 if envelope_revision!=presentation.visual_revision:
  scenery_radius=0.0
  for point in overview_points(): scenery_radius=maxf(scenery_radius,Vector2(point.x,point.z).length())
  scenery_radius+=2.0 # authored roof/eave margin, independent of placement collision boxes
  envelope_revision=presentation.visual_revision
 # Orthographic magnification is camera.size. The lens stays beyond the entire
 # scenery envelope while focus/mode changes, including distant expansions.
 # Rebuild its position from the safe radius instead of cutting through roofs.
 var radius=maxf(32.0,scenery_radius+Vector2(orbit_focus.x,orbit_focus.z).length()+8.0)
 camera.position=orbit_focus+Vector3(sin(orbit_yaw)*radius,radius*tan(orbit_pitch),cos(orbit_yaw)*radius)
 # Reserve the bottom menu area, keeping the subject in the exposed map.
 size/=1.0-panel_framing
 camera.size=size if immediate else lerpf(camera.size,size,blend)
 if camera_mode=="overview": camera.size=maxf(size,camera.size)
 camera.h_offset=0.0
 camera.v_offset=-camera.size*panel_framing*0.5
 camera.look_at(orbit_focus)
 camera_initialized=true
 presentation.update_character_visibility(camera,resident.position,true)
 presentation.layout_markers()

func overview_points() -> Array[Vector3]:
 # Include inactive plots as well as the active clearing; no imaginary roofs
 # at empty corners. Keep these extents shared with the terrain renderer.
 var points: Array[Vector3]=[]
 points.append_array(HomesteadItems.SCENIC_POINTS)
 var regions=[{"center":HomesteadItems.BASE_LAND_CENTER,"size":HomesteadItems.BASE_LAND_SIZE}]
 for center in HomesteadItems.LAND_CENTERS.values(): regions.append({"center":center,"size":HomesteadItems.PLOT_SIZE})
 if "east" in data.land_sides: regions.append({"center":HomesteadItems.LAND_CENTERS.east+Vector3(0,0,-6.48),"size":Vector2(12.35,1.02)})
 if data.edges:
  for center in HomesteadItems.EDGE_CENTERS.values(): regions.append({"center":center,"size":HomesteadItems.EDGE_SIZE})
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

func begin_tree_watering(count: int):
 if count<=0 or data.growth_tree_id=="" or reduced_motion or data.find(data.growth_tree_id).is_empty(): return
 count=mini(count,maxi(0,data.approvals-presentation.pending_tree_growth))
 if count<=0: return
 presentation.pending_tree_growth+=count
 presentation.rebuild()
 resident.water_growth_tree(data.growth_tree_id,count)
func _on_tree_watered():
 if presentation.pending_tree_growth<=0: return
 presentation.pending_tree_growth-=1
 presentation.yellow_leaves=false
 presentation.rebuild()
func begin_sunrise():
 if not reduced_motion: sunrise_remaining=SUNRISE_SECONDS
 resident.notice_sunny_day()
 for person in guests:
  if is_instance_valid(person): person.notice_sunny_day()
func update_sunrise(delta: float):
 if reduced_motion: sunrise_remaining=0
 elif sunrise_remaining>0: sunrise_remaining=maxf(0,sunrise_remaining-delta)
 if sun==null: return
 var lift=0.0 if sunrise_remaining<=0 else sin((1.0-sunrise_remaining/SUNRISE_SECONDS)*PI)
 sun.light_energy=SUN_REST_ENERGY+0.22*lift
 sun.rotation_degrees.x=-48.0+6.0*lift
func send_activity():
 emit_message("activity",{"key":resident.state,"destination":resident.destination_kind,"text":resident.activity})

func new_command_id() -> String:
 var bytes=Crypto.new().generate_random_bytes(16)
 bytes[6]=(bytes[6]&15)|64
 bytes[8]=(bytes[8]&63)|128
 var hex=bytes.hex_encode()
 return hex.substr(0,8)+"-"+hex.substr(8,4)+"-"+hex.substr(12,4)+"-"+hex.substr(16,4)+"-"+hex.substr(20,12)

# The baker and storyteller stay in the saved visit. They are hidden until the
# yard feels alive. Hiding them does not spend or keep the loaf.
func update_guest():
 if guests.is_empty(): return
 for person in guests:
  if is_instance_valid(person):
   remove_child(person)
   person.queue_free()
 guests.clear()
