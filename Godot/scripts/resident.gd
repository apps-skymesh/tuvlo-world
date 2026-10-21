class_name HomesteadResident
extends Node3D
signal activity_changed(text: String)
var data: HomesteadWorldData
var navigation: HomesteadNavigation
var model: HomesteadResidentModel
var route=PackedVector3Array()
var state="pause"
var activity="Leaving home"
var destination_kind="garden"
var target_id=""
var timer=1.1
var speed=0.0
var facing=0.0
var desired_facing=0.0
var schedule=["garden","bench","pond","cottage"]
var schedule_index=-1
var cycles=0
var arrivals: Dictionary={}
var recoveries=0
var distance_walked=0.0
var blocked_samples=0
var rng=RandomNumberGenerator.new()
var pending_discovery=false
var seat_start=Vector3.ZERO
var seat_target=Vector3.ZERO
var current_target=Vector3.ZERO
var target_anchor=Vector3.ZERO
var activity_scale=1.0
var reduced_motion=false
var steps=0

func setup(world_data: HomesteadWorldData,nav: HomesteadNavigation):
	data=world_data
	navigation=nav
	rng.seed=72531
	position=HomesteadItems.cell_center(navigation.closest(Vector3(-3.5,0,-2.5)))
	model=HomesteadResidentModel.new()
	add_child(model)
	activity_changed.emit(activity)
func announce(text: String):
	activity=text
	activity_changed.emit(text)
func choose_destination():
	if pending_discovery:
		pending_discovery=false
		destination_kind="discovery"
		var habitat=HomesteadHabitat.best(data)
		if not habitat.pond.is_empty():
			target_id=habitat.pond.id
			start_route(navigation.approach(habitat.pond),"Going to greet a new friend")
			return
	schedule_index=(schedule_index+1)%schedule.size()
	if schedule_index==0: cycles+=1
	destination_kind=schedule[schedule_index]
	var candidates=[]
	for item in data.items:
		if item.kind==destination_kind: candidates.append(item)
	if candidates.is_empty():
		target_id=""
		current_target=HomesteadItems.cell_center(navigation.closest(Vector3.ZERO))
		start_route(current_target,"Taking a little stroll")
		return
	var target: Dictionary=candidates[cycles%candidates.size()]
	target_id=target.id
	start_route(navigation.approach(target),{"garden":"Off to tend the garden","bench":"Finding a sunny seat","pond":"Visiting the pond","cottage":"Heading home"}[destination_kind])
func start_route(destination: Vector3,text: String):
	current_target=destination
	var target=data.find(target_id)
	target_anchor=HomesteadItems.item_center(target) if not target.is_empty() else destination
	route=navigation.path(position,destination)
	if route.is_empty():
		recoveries+=1
		state="pause"
		timer=1.0
		announce("Looking for another way")
		return
	if position.distance_to(route[0])<0.12: route.remove_at(0)
	announce(text)
	if route.is_empty():
		arrive()
		return
	state="walking"
func world_changed():
	if model==null: return
	var target=data.find(target_id)
	var target_changed=not target.is_empty() and (HomesteadItems.item_center(target).distance_to(target_anchor)>0.01 or navigation.approach(target).distance_to(current_target)>0.01)
	var seated_safely=state in ["seating","rest","unseating"] and not target.is_empty() and target.kind=="bench" and not target_changed
	var relocated=false
	if not navigation.open(HomesteadItems.cell_at(position)) and not seated_safely:
		position=HomesteadItems.cell_center(navigation.closest(position))
		recoveries+=1
		relocated=true
	if target.is_empty() and target_id!="":
		route.clear()
		state="pause"
		timer=0.8
		speed=0
		model.set_motion("idle")
		announce("Finding a new place to visit")
		recoveries+=1
	elif not target.is_empty():
		# Unrelated decorating leaves a seated or gardening resident undisturbed.
		var active=state in ["walking","align","seating","unseating","rest","water","look","wave"]
		if active and (state=="walking" or target_changed or relocated):
			start_route(navigation.approach(target),"Taking the new path")
			recoveries+=1
	elif state=="walking":
		start_route(HomesteadItems.cell_center(navigation.closest(current_target)),"Taking a clear path")
func greet_discovery():
	pending_discovery=true
	if state not in ["walking","seating"]:
		timer=minf(timer,1.0)
func arrive():
	speed=0
	state="align"
	timer=0.65
	model.set_motion("idle")
	var target=data.find(target_id)
	if not target.is_empty():
		var direction=HomesteadItems.item_center(target)-position
		desired_facing=atan2(direction.x,direction.z)
	else: desired_facing=facing+0.4
func begin_activity():
	arrivals[destination_kind]=int(arrivals.get(destination_kind,0))+1
	var target=data.find(target_id)
	if destination_kind=="garden" and not target.is_empty():
		state="water"
		timer=rng.randf_range(4.5,6.5)*activity_scale
		model.set_motion("water")
		announce("Watering the garden")
	elif destination_kind=="bench" and not target.is_empty():
		state="seating"
		timer=0
		seat_start=position
		var forward=Vector3(sin(target.rotation*PI/2),0,cos(target.rotation*PI/2))
		seat_target=HomesteadItems.item_center(target)+forward*0.08
		desired_facing=atan2(forward.x,forward.z)
		announce("Resting on the bench")
	elif destination_kind=="discovery" or (destination_kind=="cottage" and cycles%2==0):
		state="wave"
		timer=2.5
		model.set_motion("wave")
		announce("Hello, little visitor!" if destination_kind=="discovery" else "A little hello from home")
	else:
		state="look"
		timer=rng.randf_range(3.0,5.0)*activity_scale
		model.set_motion("idle")
		announce("Watching the water" if destination_kind=="pond" else "A little pause at home")
func finish_activity():
	if state=="rest":
		var target=data.find(target_id)
		if not target.is_empty():
			seat_start=position
			seat_target=navigation.approach(target)
			state="unseating"
			timer=0
			model.set_motion("idle")
			return
	model.set_motion("idle")
	state="pause"
	timer=rng.randf_range(0.8,1.8)*activity_scale
func _physics_process(delta):
	if model==null: return
	steps+=1
	model.reduced_motion=reduced_motion
	if state=="walking":
		if route.is_empty():
			arrive()
			return
		var next=route[0]
		var distance=position.distance_to(next)
		if distance<0.035:
			position=next
			route.remove_at(0)
			if route.is_empty(): arrive()
			return
		var direction=(next-position).normalized()
		desired_facing=atan2(direction.x,direction.z)
		var remaining=distance
		for i in range(1,route.size()): remaining+=route[i-1].distance_to(route[i])
		var desired_speed=minf(1.35,sqrt(remaining*5))
		speed=move_toward(speed,desired_speed,delta*(3.2 if desired_speed>speed else 4.5))
		var proposed=position+direction*minf(distance,speed*delta)
		if navigation.open(HomesteadItems.cell_at(proposed)):
			distance_walked+=position.distance_to(proposed)
			position=proposed
		else:
			blocked_samples+=1
			start_route(current_target,"Finding a clear path")
		model.set_motion("walk",speed/0.9)
	elif state=="align":
		timer-=delta
		if timer<=0: begin_activity()
	elif state=="seating":
		timer+=delta
		var amount=clampf(timer/0.6,0,1)
		position=seat_start.lerp(seat_target,smoothstep(0,1,amount))
		model.set_motion("sit")
		if amount>=1:
			state="rest"
			timer=rng.randf_range(5,7)*activity_scale
	elif state=="unseating":
		timer+=delta
		position=seat_start.lerp(seat_target,smoothstep(0,1,clampf(timer/0.65,0,1)))
		if timer>=0.65:
			state="pause"
			timer=0.8
	elif state=="pause":
		timer-=delta
		if timer<=0: choose_destination()
	else:
		timer-=delta
		if timer<=0: finish_activity()
	facing=lerp_angle(facing,desired_facing,minf(1,delta*5.5))
	rotation.y=facing
