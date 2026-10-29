class_name HomesteadResident
extends Node3D
signal activity_changed(text: String)
signal tree_watered
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
var schedule=["garden","nook","bench","pond","treehouse","cottage"]
var place_visit: HomesteadPlaceVisit
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
var target_rotation=0
var activity_scale=1.0
var fetching_water=false
var carrying_water=false
var watering_remaining=0
var watering_tree_id=""
var reduced_motion=false
var steps=0
# A child's tap on open ground sets a brisker pace for that one walk.
var pace=1.0

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
	if watering_remaining>0 and not data.find(watering_tree_id).is_empty():
		visit(watering_tree_id)
		return
	if pending_discovery:
		pending_discovery=false
		destination_kind="discovery"
		var habitat=HomesteadHabitat.best(data)
		if not habitat.pond.is_empty():
			target_id=habitat.pond.id
			start_route(navigation.approach(habitat.pond,position),"Going to greet a new friend")
			return
	# Visit only places actually present, instead of repeatedly walking home for
	# missing demo destinations in a starter or partially furnished world.
	for attempt in schedule.size():
		schedule_index=(schedule_index+1)%schedule.size()
		if schedule_index==0: cycles+=1
		destination_kind=schedule[schedule_index]
		var candidates=[]
		for item in data.items:
			if item.kind==destination_kind and data.building(item.id).is_empty(): candidates.append(item)
		if candidates.is_empty(): continue
		var target: Dictionary=candidates[cycles%candidates.size()]
		if target.kind=="garden":
			visit(target.id)
			return
		target_id=target.id
		start_route(navigation.approach(target,position),{"garden":"Off to tend the garden","bench":"Finding a sunny seat","pond":"Visiting the pond","nook":"Finding a book","treehouse":"Visiting the treehouse","cottage":"Heading home"}[destination_kind])
		return
	target_id=""
	state="pause"
	timer=2.0
	speed=0
	model.set_motion("idle")
	announce("Enjoying a quiet moment")
# Tap visits are read-only play. The host still owns placement and progression.
func water_growth_tree(id: String, times: int):
	if times<=0 or id=="": return
	if watering_tree_id==id and watering_remaining>0:
		watering_remaining+=times
		return
	watering_remaining=times
	watering_tree_id=id
	visit(id)
func cancel_tree_watering():
	var active=watering_tree_id!="" and target_id==watering_tree_id
	watering_remaining=0
	watering_tree_id=""
	if not active: return
	fetching_water=false
	carrying_water=false
	model.carrying_water=false
	route.clear()
	state="pause"
	timer=0.8
	model.set_motion("idle")
func visit(id: String):
	var target=data.find(id)
	if target.is_empty() or not data.building(id).is_empty(): return
	if place_visit!=null:
		if id!=target_id: place_visit.leave(self,id)
		return
	target_id=id
	destination_kind=target.kind
	if target.kind=="garden" or (id==watering_tree_id and watering_remaining>0):
		var can_fetch=navigation.well_center.is_finite() and not carrying_water and not reduced_motion
		if can_fetch:
			var entry=navigation.well_approach()
			can_fetch=not navigation.path(position,entry).is_empty() and not navigation.path(entry,navigation.approach(target,entry)).is_empty()
		if can_fetch:
			fetching_water=true
			model.carrying_water=false
			model.set_motion("idle")
			start_route(navigation.well_approach(),"Getting water from the well")
			return
	else: carrying_water=false
	fetching_water=false
	model.carrying_water=carrying_water
	model.set_motion("idle")
	start_route(navigation.approach(target,position),"Bringing water to the "+target.kind if carrying_water else "Visiting a favorite place")
# Tap-to-walk is presentation only: no item, save or reward is involved.
# Busy moments (watering, a seat, a place visit) finish first.
func walk_to(point: Vector3) -> bool:
	if watering_remaining>0 or place_visit!=null or fetching_water or carrying_water: return false
	if state in ["seating","rest","unseating"]: return false
	var cell=HomesteadItems.cell_at(point)
	if not navigation.open(cell): return false
	target_id=""
	destination_kind="stroll"
	model.set_motion("idle")
	start_route(HomesteadItems.cell_center(cell),"Walking over")
	if state!="walking": return false
	pace=1.35
	return true
func start_route(destination: Vector3,text: String):
	current_target=destination
	var target=data.find(target_id)
	target_anchor=HomesteadItems.item_center(target) if not target.is_empty() else destination
	target_rotation=int(target.get("rotation",0))
	route=navigation.path(position,destination)
	if route.is_empty():
		recoveries+=1
		state="pause"
		timer=1.0
		announce("Looking for another way")
		return
	if position.distance_to(route[0])<0.12: route.remove_at(0)
	if route.is_empty():
		arrive()
		return
	state="walking"
	announce(text)
func world_changed():
	if model==null: return
	var target=data.find(target_id)
	var target_changed=not target.is_empty() and (HomesteadItems.item_center(target).distance_to(target_anchor)>0.01 or int(target.rotation)!=target_rotation or not navigation.open(HomesteadItems.cell_at(current_target)))
	if place_visit!=null and (target.is_empty() or target_changed):
		cancel_place_visit()
	var seated_safely=(place_visit!=null and not target_changed) or state in ["seating","rest","unseating"] and not target.is_empty() and target.kind=="bench" and not target_changed
	var relocated=false
	if not navigation.open(HomesteadItems.cell_at(position)) and not seated_safely:
		position=HomesteadItems.cell_center(navigation.closest(position))
		recoveries+=1
		relocated=true
	if fetching_water and not target.is_empty():
		if not navigation.well_center.is_finite() or navigation.path(position,navigation.well_approach()).is_empty():
			fetching_water=false
			start_route(navigation.approach(target,position),"Off to water")
		elif state=="walking" or current_target.distance_to(navigation.well_approach())>0.01 or relocated:
			start_route(navigation.well_approach(),"Taking the new path to the well")
		return
	if target.is_empty() and target_id!="":
		fetching_water=false
		carrying_water=false
		model.carrying_water=false
		route.clear()
		state="pause"
		timer=0.8
		speed=0
		model.set_motion("idle")
		announce("Finding a new place to visit")
		recoveries+=1
	elif not target.is_empty():
		# Unrelated decorating leaves a seated or gardening resident undisturbed.
		var active=state in ["walking","align","seating","unseating","rest","water","fill","look","wave"]
		if active and (state=="walking" or target_changed or relocated):
			start_route(navigation.approach(target,position),"Taking the new path")
			recoveries+=1
	elif state=="walking":
		start_route(HomesteadItems.cell_center(navigation.closest(current_target)),"Taking a clear path")
func cancel_place_visit():
	if place_visit==null: return
	place_visit=null
	model.foot_shadow.visible=true
	position=HomesteadItems.cell_center(navigation.closest(position))
	state="pause"
	timer=.8
	model.set_motion("idle")

func notice_sunny_day():
	announce("A sunny day")
	if reduced_motion or place_visit!=null or state in ["walking","seating","unseating"]: return
	state="look"
	timer=2.4
	model.set_motion("idle")
func greet_discovery():
	pending_discovery=true
	if place_visit==null and state not in ["walking","seating"]:
		timer=minf(timer,1.0)
func arrive():
	pace=1.0
	speed=0
	state="align"
	timer=0.65
	model.set_motion("idle")
	var target=data.find(target_id)
	if not target.is_empty():
		var direction=(navigation.well_center if fetching_water else HomesteadItems.item_center(target))-position
		desired_facing=atan2(direction.x,direction.z)
	else: desired_facing=facing+0.4
func begin_activity():
	if fetching_water:
		state="fill"
		timer=2.4
		model.set_motion("fill")
		announce("Filling the watering can")
		return
	arrivals[destination_kind]=int(arrivals.get(destination_kind,0))+1
	if watering_remaining>0 and target_id==watering_tree_id:
		state="water"
		timer=1.7
		model.set_motion("water")
		announce("Watering the tree")
		return
	var target=data.find(target_id)
	if destination_kind=="garden" and not target.is_empty():
		state="water"
		timer=rng.randf_range(4.5,6.5)*activity_scale
		model.set_motion("water")
		announce("Watering the garden")
	elif destination_kind in ["nook","treehouse"] and not target.is_empty():
		var visit=HomesteadPlaceVisit.new()
		if (destination_kind!="treehouse" or not reduced_motion) and visit.begin(self,target):
			place_visit=visit
		else:
			state="look"
			timer=3.0*activity_scale
			model.set_motion("idle")
			announce("Enjoying this little place")
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
		announce("Watching the water" if destination_kind=="pond" else "A little pause at home" if destination_kind=="cottage" else "Enjoying this little place")
func finish_activity():
	if state=="fill":
		fetching_water=false
		carrying_water=true
		model.carrying_water=true
		var target=data.find(target_id)
		if not target.is_empty():
			start_route(navigation.approach(target,position),"Bringing water to the "+target.kind)
			return
		carrying_water=false
		model.carrying_water=false
	if state=="water" and watering_remaining>0 and target_id==watering_tree_id:
		watering_remaining-=1
		tree_watered.emit()
		if watering_remaining>0:
			begin_activity()
			return
		watering_tree_id=""
	if state=="rest":
		var target=data.find(target_id)
		if not target.is_empty():
			seat_start=position
			seat_target=navigation.approach(target,position)
			state="unseating"
			timer=0
			model.set_motion("idle")
			return
	carrying_water=false
	fetching_water=false
	model.carrying_water=false
	model.set_motion("idle")
	state="pause"
	timer=rng.randf_range(1.2,2.6)*activity_scale
func _physics_process(delta):
	if model==null: return
	steps+=1
	model.reduced_motion=reduced_motion
	model.carrying_water=carrying_water
	if place_visit!=null:
		if reduced_motion and place_visit.kind=="treehouse" and not place_visit.exiting: place_visit.leave(self)
		if place_visit.tick(self,delta):
			var pending=place_visit.pending_id
			place_visit=null
			if pending!="": visit(pending)
		facing=rotate_toward(facing,desired_facing,delta*4.5)
		rotation.y=facing
		return
	if state=="walking":
		if route.is_empty():
			arrive()
			return
		# Remove reached points before moving: a straight path must not lose a
		# physics frame at every tile boundary.
		while not route.is_empty() and position.distance_to(route[0])<0.001:
			route.remove_at(0)
		if route.is_empty():
			arrive()
			return
		var direction=(route[0]-position).normalized()
		var anticipation=route[0]
		if position.distance_to(anticipation)<0.28 and route.size()>1:
			anticipation=anticipation.move_toward(route[1],0.28-position.distance_to(anticipation))
		var look_direction=(anticipation-position).normalized()
		desired_facing=atan2(look_direction.x,look_direction.z)
		var previous_facing=facing
		facing=rotate_toward(facing,desired_facing,delta*4.5)
		# Turn toward the route before stepping. A sharp corner slows the body
		# rather than sliding it sideways while its feet still face the old path.
		var alignment=maxf(0,cos(angle_difference(facing,desired_facing)))
		var remaining=position.distance_to(route[0])
		for i in range(1,route.size()): remaining+=route[i-1].distance_to(route[i])
		var bend_limit=1.0
		if route.size()>1 and position.distance_to(route[0])<0.65:
			var next_direction=(route[1]-route[0]).normalized()
			bend_limit=lerpf(0.50,1.0,maxf(0,direction.dot(next_direction)))
		# An unhurried child's pace: ease into the first steps and settle into
		# the stop instead of reaching full speed in a few frames.
		var desired_speed=minf(0.9*pace*bend_limit,sqrt(remaining*1.6))*alignment*alignment
		var accel=lerpf(0.9,2.0,clampf(speed/(0.9*pace),0,1)) if desired_speed>speed else 3.2
		speed=move_toward(speed,desired_speed,delta*accel)
		var budget=speed*delta*alignment
		var moved=0.0
		while budget>0.00001 and not route.is_empty():
			var next=route[0]
			var distance=position.distance_to(next)
			var step=minf(distance,budget)
			var proposed=position.move_toward(next,step)
			if not navigation.open(HomesteadItems.cell_at(proposed)):
				blocked_samples+=1
				start_route(current_target,"Finding a clear path")
				break
			position=proposed
			moved+=step
			budget-=step
			if distance>step+0.00001: break
			route.remove_at(0)
			# Carry unused distance across collinear points, never around a corner
			# until the facing/speed calculation has seen that new direction.
			if not route.is_empty() and direction.dot((route[0]-position).normalized())<0.94: break
		distance_walked+=moved
		if route.is_empty(): arrive()
		elif moved>0.0001: model.set_motion("walk",moved/maxf(delta,0.0001))
		elif absf(angle_difference(previous_facing,facing))>.002:
			model.set_motion("turn",absf(angle_difference(previous_facing,facing))/maxf(delta,.0001))
		else: model.set_motion("idle")
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
	if state!="walking": facing=rotate_toward(facing,desired_facing,delta*4.5)
	model.look_yaw=angle_difference(facing,desired_facing)
	model.activity_camera_yaw=angle_difference(facing,atan2(navigation.view_direction.x,navigation.view_direction.z))
	rotation.y=facing
