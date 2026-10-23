extends SceneTree
var failures=0
func check(value: bool,message: String):
 if not value:
  failures+=1
  push_error(message)
func _initialize(): call_deferred("run")
func run():
 var scene=load("res://scenes/homestead.tscn").instantiate()
 root.add_child(scene)
 await process_frame
 var items=[
  {"id":"cottage","kind":"cottage","cell":{"x":3,"z":2},"rotation":0},
  {"id":"garden","kind":"garden","cell":{"x":2,"z":10},"rotation":0},
  {"id":"bench","kind":"bench","cell":{"x":8,"z":10},"rotation":0},
  {"id":"pond","kind":"pond","cell":{"x":11,"z":7},"rotation":0}
 ]
 var payload={"items":items,"land":[],"appearance":{"hair":3},"approvedWins":21,"discovered":false}
 var packet={"version":1,"session":"test-child-session","type":"snapshot","payload":payload}
 scene.receive_host_json(JSON.stringify(packet))
 check(scene.data.items.size()==4,"Host snapshot must replace empty scene")
 # Rendering future terrain must never make it navigable or placeable.
 for side in HomesteadItems.LAND_CENTERS:
  var patch=scene.presentation.land_root.get_node_or_null("Land_"+side)
  check(patch!=null and not patch.get_meta("available",true),"Every inactive plot must remain visibly represented")
 for cell in [Vector2i(-2,7),Vector2i(19,7),Vector2i(8,-2)]:
  check(not scene.navigation.open(cell),"Inactive land cannot be used by residents")
  check(scene.data.placement_error("flowers",cell,0)=="outside-land","Visible inactive land cannot accept placement")
 scene.data.land_sides.append("east")
 scene.presentation.rebuild()
 scene.navigation.rebuild(scene.data)
 check(scene.presentation.land_root.get_node("Land_east").get_meta("available")==true,"An authoritative activation updates its visual state")
 check(scene.navigation.open(Vector2i(19,7)),"Only an authoritative active plot becomes navigable")
 scene.data.land_sides.clear()
 scene.presentation.rebuild()
 scene.navigation.rebuild(scene.data)
 # The host may preview a future meadow without granting land. A committed
 # west-only snapshot opens west cells while leaving east and north blocked.
 scene.receive_host_json(JSON.stringify({"version":1,"session":"test-child-session","type":"landPreview","payload":{"west":true}}))
 check(not scene.navigation.open(Vector2i(-2,7)),"A meadow preview must never grant land")
 scene.receive_host_json(JSON.stringify({"version":1,"session":"test-child-session","type":"landPreview","payload":{"west":false}}))
 scene.data.land_sides.append("west")
 scene.presentation.rebuild()
 scene.navigation.rebuild(scene.data)
 check(scene.navigation.open(Vector2i(-2,7)),"Committed west meadow becomes walkable")
 check(not scene.navigation.open(Vector2i(19,7)),"Meadow purchase cannot unlock east")
 check(HomesteadItems.footprint("workshop",0)==Vector2i(3,3),"Workshop native and runtime footprints must match")
 var workshop=scene.presentation.make_item("workshop",0)
 check(workshop.get_child(0).get_child_count()>30,"Workshop has its own authored joinery and workbench")
 workshop.free()
 check(HomesteadItems.footprint("greenhouse",0)==Vector2i(3,2),"Greenhouse uses the shared compact footprint")
 var greenhouse=scene.presentation.make_item("greenhouse",0)
 check(greenhouse.get_child(0).get_child_count()>40,"Greenhouse has authored glass, joinery, hanging leaves and pots")
 greenhouse.free()
 var stored_greenhouse=HomesteadWorldData.new()
 check(stored_greenhouse.apply_snapshot({"items":[{"id":"stored-greenhouse","kind":"greenhouse","cell":null,"rotation":1}],"land":["west"]}),"Stored greenhouse remains owned inventory")
 var stored=stored_greenhouse.inventory["stored-greenhouse"]
 check(stored_greenhouse.placement_error(stored.kind,stored.cell,stored.rotation)=="","Stored greenhouse starts its rotated replacement preview in the meadow")
 check(scene.data.placement_error("greenhouse",Vector2i(-3,7),0)=="","Greenhouse fits inside owned west meadow")
 check(scene.data.placement_error("greenhouse",Vector2i(-3,7),1)=="","Rotated greenhouse fits inside owned west meadow")
 check(scene.data.placement_error("greenhouse",Vector2i(8,11),0)=="outside-land","Greenhouse remains a west-meadow building")
 var orchard=scene.presentation.make_item("orchard",0,false,2)
 check(orchard.get_child(0).get_child_count()>60,"Orchard has authored trees, fruit and a woven basket")
 orchard.free()
 check(HomesteadItems.footprint("orchard",0)==Vector2i(2,2),"Orchard shares the compact native footprint")
 check(scene.data.placement_error("orchard",Vector2i(-2,6),0)=="","Orchard fits the owned west meadow")
 check(scene.data.placement_error("orchard",Vector2i(8,11),0)=="outside-land","Orchard cannot be placed in the clearing")
 var stored_orchard=HomesteadWorldData.new()
 check(stored_orchard.apply_snapshot({"items":[{"id":"stored-orchard","kind":"orchard","cell":null,"rotation":1,"style":2}],"land":["west"]}),"Stored orchard is retained")
 var fruit_trees=stored_orchard.inventory["stored-orchard"]
 check(stored_orchard.placement_error(fruit_trees.kind,fruit_trees.cell,fruit_trees.rotation)=="","Stored orchard replacement starts in the meadow")
 check(fruit_trees.style==2,"Stored orchard preserves its chosen variety")
 scene.data.land_sides.clear()
 scene.presentation.rebuild()
 scene.navigation.rebuild(scene.data)
 # Fit the complete terrain and actual roof extents through a full orbit and
 # tablet/phone landscape aspects, not just the initial attractive angle.
 for aspect in [1.3,1.8,2.5,3.0]:
  for turn in 8:
   scene.yaw=turn*PI/4
   var fit=scene.overview_fit(aspect)
   var right=Vector3(cos(scene.yaw),0,-sin(scene.yaw))
   var up=Vector3(-sin(scene.yaw)*sin(scene.OVERVIEW_PITCH),cos(scene.OVERVIEW_PITCH),-cos(scene.yaw)*sin(scene.OVERVIEW_PITCH))
   for point in scene.overview_points():
    var offset=point-fit.focus
    check(absf(right.dot(offset))<fit.size*aspect/2,"All terrain must fit horizontally with margin at every camera rotation")
    check(absf(up.dot(offset))<fit.size/2,"All terrain must fit vertically with margin at every camera rotation")
 scene.yaw=0.25
 scene.receive_host_json(JSON.stringify({"version":1,"session":"test-child-session","type":"camera","payload":{"mode":"overview","zoom":0.01}}))
 check(scene.zoom==1.0,"Overview zoom cannot crop the full map")
 scene.receive_host_json(JSON.stringify({"version":1,"session":"test-child-session","type":"camera","payload":{"mode":"follow","zoom":0.01}}))
 check(scene.zoom>=0.65,"Detailed zoom has a safe lower bound")
 scene.receive_host_json(JSON.stringify({"version":1,"session":"test-child-session","type":"camera","payload":{"mode":"overview","resetZoom":true}}))
 var rig=scene.resident.model.rig
 scene.resident.set_physics_process(false)
 # Exercise the real schedule and navigation without waiting for wall-clock time.
 for i in 12000: scene.resident._physics_process(1.0/60.0)
 check(scene.resident.distance_walked>10,"Resident should walk purposefully")
 check(scene.resident.arrivals.get("garden",0)>0,"Resident must reach and water garden")
 check(scene.resident.arrivals.get("bench",0)>0,"Resident must reach and sit on bench")
 check(scene.resident.blocked_samples==0,"Resident must not walk through obstacles")
 # Keep moving through a straight tile boundary and face the direction of travel.
 var walker=scene.resident
 walker.position=HomesteadItems.cell_center(Vector2i(7,7))
 walker.facing=0
 walker.desired_facing=0
 walker.speed=1.2
 walker.state="walking"
 walker.route=PackedVector3Array([walker.position+Vector3(0,0,0.01),walker.position+Vector3(0,0,1),walker.position+Vector3(0,0,2)])
 var before=walker.position
 walker._physics_process(1.0/60.0)
 check(walker.position.distance_to(before)>0.019,"Straight waypoint must consume the remaining frame distance without a tile pause")
 walker.route=PackedVector3Array([walker.position+Vector3(0,0,-2)])
 walker.facing=0
 walker.speed=0
 before=walker.position
 walker._physics_process(1.0/60.0)
 check(walker.position==before,"Resident must turn before walking in the opposite direction")
 # A starter world has no bench or pond to visit; choose the next owned destination.
 var complete_items=scene.data.items.duplicate(true)
 scene.data.items=scene.data.items.filter(func(item): return item.kind in ["garden","cottage"])
 scene.navigation.rebuild(scene.data)
 walker.schedule_index=0
 walker.choose_destination()
 check(walker.destination_kind=="cottage" and walker.target_id=="cottage","Schedule must skip places that do not exist")
 scene.data.items=complete_items
 scene.navigation.rebuild(scene.data)
 # Ground contact is the contract; knee angles may change with a better gait.
 var model=walker.model
 model.set_motion("walk")
 model.animator.advance(0.3)
 for sample in 13:
  model.animator.seek(float(sample)*0.04,true)
  var sole=model.left_ankle.to_global(Vector3(0,-0.105,0)).y
  check(absf(sole-walker.position.y)<0.015,"Planted sole must remain on the ground throughout stance")
 model.animator.seek(0.2,true)
 var left_sole=model.left_ankle.to_global(Vector3(0,-0.105,0)).y
 var right_sole=model.right_ankle.to_global(Vector3(0,-0.105,0)).y
 check(right_sole-left_sole>0.04,"Swing foot must clear the ground while the other foot stays planted")
 # Camera safety is independent of zoom and angle: all modes keep the lens
 # outside the entire scene envelope, including intermediate opposite turns.
 for view in ["overview","home","follow","detail"]:
  scene.camera_mode=view
  for turn in 16:
   scene.yaw=turn*PI/4
   for frame in 8:
    scene._process(1.0/30.0)
    var horizontal=Vector2(scene.camera.position.x,scene.camera.position.z).length()
    check(horizontal>scene.scenery_radius+1.0,"Camera lens must remain outside all scenery through orbit transitions")
    check(scene.camera.position.y>6.0,"Camera must remain above roofs rather than moving inside them")
    if view=="overview":
     var viewport=scene.get_viewport().get_visible_rect()
     for point in scene.overview_points():
      check(viewport.has_point(scene.camera.unproject_position(point)),"Overview must keep every plot and roof visible during rotation")
 scene.camera_mode="overview"
 scene.yaw=0.25
 # Every rounded route segment retains the resident's swept-body clearance.
 var smooth_route=scene.navigation.path(HomesteadItems.cell_center(Vector2i(7,7)),scene.navigation.approach(scene.data.find("cottage")))
 for segment in range(1,smooth_route.size()):
  check(scene.navigation.corridor_clear(smooth_route[segment-1],smooth_route[segment]),"Rounded routes must not clip obstacles or inactive land")
 check(scene.overview_size(2.5)<23,"Landscape overview should use the vertical space instead of shrinking the island")
 check(scene.overview_size(0.5)>scene.overview_size(2.5),"Portrait overview must still fit the full island width")
 var position=scene.resident.position
 var activity=scene.resident.state
 payload.appearance={"hair":4,"skin":5,"height":2,"build":2}
 scene.receive_host_json(JSON.stringify(packet))
 check(scene.resident.model.rig==rig,"Appearance updates must preserve active rig")
 check(scene.resident.position==position and scene.resident.state==activity,"Appearance updates must preserve activity")
 check(scene.resident.model.appearance.hair==4,"Appearance should update")
 var target=scene.data.find(scene.resident.target_id)
 if not target.is_empty():
  payload.items=items.filter(func(item): return item.id!=target.id)
  scene.receive_host_json(JSON.stringify(packet))
  check(scene.resident.state=="pause","Removed destination must safely recover")
 # Restore the complete fixture after the deliberate destination-removal case.
 payload.items=items
 scene.receive_host_json(JSON.stringify(packet))
 var messages=[]
 scene.host_message.connect(func(raw): messages.append(JSON.parse_string(raw)))
 scene._process(1.0)
 await physics_frame
 var touch=InputEventScreenTouch.new()
 touch.pressed=true
 touch.position=Vector2(-20,-20)
 scene._input(touch)
 check(scene.pending_pick==null,"Touches outside the embedded viewport cannot select world objects")
 touch.position=scene.camera.unproject_position(HomesteadItems.item_center(scene.data.find("cottage"))+Vector3(0,2,0))
 var cottage_point=touch.position
 scene._input(touch)
 scene._physics_process(0.1)
 check(not messages.any(func(message): return message.type=="selected"),"A quick touch must not start editing")
 touch.pressed=false
 scene._input(touch)
 scene._physics_process(0.016)
 check(messages.any(func(message): return message.type=="visited" and message.payload.id=="cottage"),"A tap visits the visible cottage")
 check(not messages.any(func(message): return message.type=="selected"),"Visiting does not enter edit mode")
 scene.receive_host_json(JSON.stringify({"version":1,"session":"test-child-session","type":"visit","payload":{"id":"cottage"}}))
 check(scene.resident.target_id=="cottage","Tap visit uses the existing resident navigation")
 check(scene.selected_id=="" and scene.data.items.size()==4,"Visiting never edits the world")
 messages.clear()
 touch.pressed=true
 scene._input(touch)
 scene._physics_process(0.3)
 check(not messages.any(func(message): return message.type=="selected"),"Holding waits for the deliberate threshold")
 scene._physics_process(0.2)
 scene._physics_process(0.2)
 check(messages.filter(func(message): return message.type=="selected" and message.payload.id=="cottage").size()==1,"A completed hold selects exactly once")
 var command={"version":1,"session":"test-child-session","type":"select","payload":{"id":"cottage","fromHold":true}}
 scene.receive_host_json(JSON.stringify(command))
 check(not scene.resident.is_physics_processing(),"Residents pause while a piece is being edited")
 var anchor=scene.preview_cell
 scene.move_press(cottage_point)
 check(scene.preview_cell==anchor,"A held piece keeps its grab point without jumping")
 scene.receive_host_json(JSON.stringify({"version":1,"session":"test-child-session","type":"cancel","payload":{}}))
 check(scene.resident.is_physics_processing(),"Cancel resumes World life")
 messages.clear()
 scene._input(touch)
 scene._physics_process(0.1)
 var camera_yaw=scene.yaw
 var motion=InputEventScreenDrag.new()
 motion.position=cottage_point+Vector2(28,0)
 motion.relative=Vector2(28,0)
 scene._input(motion)
 scene._physics_process(0.6)
 check(scene.yaw!=camera_yaw,"Dragging the map orbits the camera")
 check(not messages.any(func(message): return message.type=="selected"),"An orbit drag cancels the hold")
 scene.reset_press()
 scene._input(touch)
 scene._physics_process(0.2)
 var second_touch=InputEventScreenTouch.new()
 second_touch.index=1
 second_touch.pressed=true
 second_touch.position=cottage_point+Vector2(30,0)
 scene._input(second_touch)
 scene._physics_process(0.6)
 check(not scene.pointer_down and not messages.any(func(message): return message.type=="selected"),"A second finger cancels object pickup")
 scene.receive_host_json(JSON.stringify(command))
 var home_before=scene.data.find("cottage").cell
 check(is_instance_valid(scene.presentation.preview_item),"Selection shows the actual moving piece")
 check(not scene.presentation.nodes.cottage.visible,"Only one visible cottage during placement")
 scene.preview_cell=Vector2i(6,2)
 scene.update_preview()
 check(scene.presentation.preview_item.position==HomesteadItems.center(Vector2i(6,2),HomesteadItems.footprint("cottage",0))+Vector3(0,0.12,0),"Piece follows draft location")
 check(scene.data.find("cottage").cell==home_before,"Dragging never changes committed data")
 scene.receive_host_json(JSON.stringify({"version":1,"session":"test-child-session","type":"cancel","payload":{}}))
 check(scene.presentation.preview_item==null and scene.presentation.nodes.cottage.visible,"Cancel restores original artwork")
 scene.receive_host_json(JSON.stringify(command))
 command.type="confirm"
 command.payload={}
 scene.receive_host_json(JSON.stringify(command))
 scene.receive_host_json(JSON.stringify(command))
 var intents=messages.filter(func(message): return message.type=="placementIntent")
 check(intents.size()==2,"Confirm should emit a bounded host intent")
 if intents.size()==2:
  check(intents[0].payload.commandID==intents[1].payload.commandID,"Retry must retain command identity")
  check(intents[0].payload.commandID.length()==36,"Command identity must be UUID-shaped")
 packet.payload={"items":items,"land":[],"appearance":{"hair":8,"outfit":2},"reducedMotion":true}
 scene.receive_host_json(JSON.stringify(packet))
 scene._process(1.0/60.0)
 scene.resident._physics_process(1.0/60.0)
 scene.resident.model.set_motion("wave")
 scene.resident.model._process(1.0/60.0)
 check(scene.resident.model.animator.speed_scale==0,"Reduced motion freezes nonessential waving")
 check(scene.presentation.reduced_motion,"Reduced motion stops ambient scenery")
 packet.payload=payload
 var old_count=scene.data.items.size()
 payload.items=[{"id":"invalid","kind":"currency-grant","cell":{"x":0,"z":0}}]
 scene.receive_host_json(JSON.stringify(packet))
 check(scene.data.items.size()==old_count,"Malformed snapshots must leave committed state intact")
 scene.receive_host_json(JSON.stringify({"version":1,"session":"test-child-session","type":"lifecycle","payload":{"paused":true}}))
 check(scene.paused and not scene.resident.is_physics_processing(),"Background must pause simulation")
 scene.receive_host_json(JSON.stringify({"version":1,"session":"test-child-session","type":"lifecycle","payload":{"paused":true,"previewing":true}}))
 var preview_position=scene.resident.position
 var preview_rig=scene.resident.model.rig
 scene.receive_host_json(JSON.stringify({"version":1,"session":"test-child-session","type":"camera","payload":{"mode":"detail","framing":0.22}}))
 check(scene.process_mode==Node.PROCESS_MODE_INHERIT and RenderingServer.render_loop_enabled,"An on-map editor must render its preview while simulation stays paused")
 scene._process(1.0/60.0)
 check(scene.camera.size<4.0 and scene.camera.h_offset>0.0,"Editor focuses the real character beside the panel")
 check(scene.resident.position==preview_position and not scene.resident.is_physics_processing() and scene.resident.model.rig==preview_rig,"Preview must not move residents or replace the rig")
 check(scene.resident.process_mode==Node.PROCESS_MODE_DISABLED and scene.presentation.process_mode==Node.PROCESS_MODE_DISABLED,"Preview must freeze descendant animations as well as simulation")
 scene.camera_preview_frames=0
 scene._process(1.0/60.0)
 check(scene.process_mode==Node.PROCESS_MODE_DISABLED and not RenderingServer.render_loop_enabled,"A settled editor preview must stop rendering")
 scene.receive_host_json(JSON.stringify({"version":1,"session":"test-child-session","type":"camera","payload":{"mode":"place","id":"cottage","framing":0.22}}))
 check(RenderingServer.render_loop_enabled,"Another preview camera change wakes the render loop")
 scene.receive_host_json(JSON.stringify({"version":1,"session":"test-child-session","type":"lifecycle","payload":{"paused":true}}))
 check(not scene.panel_preview and not RenderingServer.render_loop_enabled,"Backgrounding an editor must stop preview rendering")
 scene.receive_host_json(JSON.stringify({"version":1,"session":"wrong-child","type":"lifecycle","payload":{"paused":false}}))
 check(scene.paused,"Stale child session must not control scene")
 var retained_rig=scene.resident.model.rig
 scene.clear_host_session()
 check(scene.session=="" and scene.data.items.is_empty() and scene.data.inventory.is_empty(),"Native teardown releases child identifiers and owned objects")
 check(scene.paused and scene.selected_id=="" and scene.resident.target_id=="","Native teardown stops previews and activities")
 scene.receive_host_json(JSON.stringify({"version":1,"session":"next-child","type":"snapshot","payload":{"items":items,"land":[],"appearance":{"hair":3},"approvedWins":2}}))
 scene.receive_host_json(JSON.stringify({"version":1,"session":"next-child","type":"lifecycle","payload":{"paused":false}}))
 check(scene.session=="next-child" and not scene.paused and scene.data.items.size()==items.size(),"The same native engine can reopen for another child")
 check(scene.resident.model.rig==retained_rig,"Native reopening retains the active rig")
 scene.receive_host_json(JSON.stringify({"version":1,"session":"test-child-session","type":"select","payload":{"id":"cottage"}}))
 check(scene.selected_id=="","Prior child callbacks cannot mutate the reopened scene")
 scene.queue_free()
 await process_frame
 print("HOMESTEAD_RUNTIME_TESTS failures=",failures)
 quit(0 if failures==0 else 1)
