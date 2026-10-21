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
 var rig=scene.resident.model.rig
 scene.resident.set_physics_process(false)
 # Exercise the real schedule and navigation without waiting for wall-clock time.
 for i in 12000: scene.resident._physics_process(1.0/60.0)
 check(scene.resident.distance_walked>10,"Resident should walk purposefully")
 check(scene.resident.arrivals.get("garden",0)>0,"Resident must reach and water garden")
 check(scene.resident.arrivals.get("bench",0)>0,"Resident must reach and sit on bench")
 check(scene.resident.blocked_samples==0,"Resident must not walk through obstacles")
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
 scene._input(touch)
 scene._physics_process(1.0/60.0)
 check(messages.any(func(message): return message.type=="selected" and message.payload.id=="cottage"),"Visible cottage must be selectable by its 3D collider")
 var command={"version":1,"session":"test-child-session","type":"select","payload":{"id":"cottage"}}
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
