class_name HomesteadNavigation
extends RefCounted
var grid=AStarGrid2D.new()
var data: HomesteadWorldData
var revision=0
var well_cell=Vector2i(10000,10000)
var well_center=Vector3.INF
var oven_centers: Dictionary={}
var oven_cells: Dictionary={}
var view_direction=Vector3(sin(0.25),0,cos(0.25))
func rebuild(world_data: HomesteadWorldData):
	data=world_data
	grid.region=HomesteadItems.WORLD_BOUNDS
	grid.cell_size=Vector2.ONE
	grid.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.default_compute_heuristic=AStarGrid2D.HEURISTIC_OCTILE
	grid.default_estimate_heuristic=AStarGrid2D.HEURISTIC_OCTILE
	grid.update()
	# Rasterize once instead of scanning every placed object for every cell.
	# Preserve item_at's first-object behavior for older overlapping layouts.
	var occupied_cells={}
	for item in data.items:
		var footprint=HomesteadItems.footprint(item.kind,item.rotation)
		for z in footprint.y:
			for x in footprint.x:
				var cell=item.cell+Vector2i(x,z)
				if grid.is_in_boundsv(cell) and not occupied_cells.has(cell): occupied_cells[cell]=item
	for z in range(HomesteadItems.WORLD_BOUNDS.position.y,HomesteadItems.WORLD_BOUNDS.end.y):
		for x in range(HomesteadItems.WORLD_BOUNDS.position.x,HomesteadItems.WORLD_BOUNDS.end.x):
			var cell=Vector2i(x,z)
			var occupied=occupied_cells.get(cell,{})
			var blocked=not data.buildable(cell) or (not occupied.is_empty() and HomesteadItems.DEFINITIONS[occupied.kind].blocks)
			grid.set_point_solid(cell,blocked)
			grid.set_point_weight_scale(cell,0.8 if not occupied.is_empty() and occupied.kind=="path" else 1.0)
	place_water_source(occupied_cells)
	place_baking_ovens(occupied_cells)
	revision+=1
# Renderer utility only: never displace a saved object, path or unowned land.
# A vacant one-square ring preserves routes around the new scenery obstacle.
func place_water_source(occupied: Dictionary):
	well_center=Vector3.INF
	if not data.items.any(func(item): return item.kind in ["tree","garden"]): return
	var silhouettes=[]
	var water_places=[]
	for item in data.items:
		if item.kind in ["path","flowers","rocks"]: continue
		silhouettes.append(HomesteadVisibility.item_bounds(item,view_direction))
		if item.kind in ["garden","pond","windmill","greenhouse","orchard","workshop","cottage","barn","grill"]:
			for role in ["material","production"]:
				silhouettes.append(HomesteadVisibility.marker_bounds(item,role,view_direction))
		if item.kind in ["tree","garden"]: water_places.append(HomesteadItems.item_center(item))
	var best=Vector2i(10000,10000)
	var best_score=INF
	for z in range(1,17):
		for x in range(1,17):
			var cell=Vector2i(x,z)
			var clear=true
			for dz in range(-1,3):
				for dx in range(-1,3):
					var square=cell+Vector2i(dx,dz)
					if not data.buildable(square) or occupied.has(square) or not open(square): clear=false
			if not clear: continue
			var center=HomesteadItems.center(cell,HomesteadItems.WELL_SIZE)
			var outline=HomesteadVisibility.projected_box(center,Vector3(1.05,HomesteadItems.WELL_HEIGHT,0.95),view_direction)
			var score=0.0
			for silhouette in silhouettes:
				score+=HomesteadVisibility.overlap(outline.grow(0.25),silhouette.grow(0.2))*18.0
			for place in water_places: score+=center.distance_to(place)*0.24/maxi(1,water_places.size())
			if cell==well_cell: score-=0.35
			if score<best_score:
				best=cell
				best_score=score
	if best.x==10000: return
	well_cell=best
	well_center=HomesteadItems.center(best,HomesteadItems.WELL_SIZE)
	for z in 2:
		for x in 2: grid.set_point_solid(best+Vector2i(x,z),true)

# Cottage-owned utility: no new saved place, land, price or recipe. The same
# empty ring as the well keeps doors, existing paths and surrounding routes clear.
func place_baking_ovens(occupied: Dictionary):
	var previous=oven_cells.duplicate()
	oven_centers.clear()
	oven_cells.clear()
	var silhouettes=[]
	for item in data.items:
		if item.kind not in ["path","flowers","rocks"]: silhouettes.append(HomesteadVisibility.item_bounds(item,view_direction))
		if item.kind in ["garden","pond","windmill","greenhouse","orchard","workshop","cottage","barn","grill"]:
			for role in ["material","production"]: silhouettes.append(HomesteadVisibility.marker_bounds(item,role,view_direction))
	if well_center.is_finite(): silhouettes.append(HomesteadVisibility.projected_box(well_center,Vector3(1.05,2.6,0.95),view_direction))
	for cottage in data.items:
		if cottage.kind!="cottage" or not data.building(cottage.id).is_empty(): continue
		var desired=HomesteadItems.item_center(cottage)+Vector3(-3.0,0,0).rotated(Vector3.UP,cottage.rotation*PI/2)
		var best=Vector2i(10000,10000)
		var best_score=INF
		for z in range(HomesteadItems.WORLD_BOUNDS.position.y,HomesteadItems.WORLD_BOUNDS.end.y-1):
			for x in range(HomesteadItems.WORLD_BOUNDS.position.x,HomesteadItems.WORLD_BOUNDS.end.x-1):
				var cell=Vector2i(x,z)
				var clear=true
				for dz in range(-1,3):
					for dx in range(-1,3):
						var square=cell+Vector2i(dx,dz)
						if not data.buildable(square) or occupied.has(square) or not open(square): clear=false
				if not clear: continue
				var center=HomesteadItems.center(cell,Vector2i(2,2))
				var outline=HomesteadVisibility.projected_box(center,Vector3(1.0,2.3,1.0),view_direction)
				var score=center.distance_to(desired)
				for silhouette in silhouettes: score+=HomesteadVisibility.overlap(outline.grow(0.15),silhouette)*10.0
				if previous.get(cottage.id,Vector2i(10000,10000))==cell: score-=0.35
				if score<best_score:
					best=cell
					best_score=score
		if best.x==10000: continue
		var center=HomesteadItems.center(best,Vector2i(2,2))
		oven_cells[cottage.id]=best
		oven_centers[cottage.id]=center
		silhouettes.append(HomesteadVisibility.projected_box(center,Vector3(1,2.3,1),view_direction))
		for z in 2:
			for x in 2: grid.set_point_solid(best+Vector2i(x,z),true)

func well_approach() -> Vector3:
	# The authored filling tap is on the west, clear of the open water and roof.
	return well_center+Vector3(-1.42,0,0.10)

func open(cell: Vector2i) -> bool:
	return grid.is_in_boundsv(cell) and not grid.is_point_solid(cell)
func closest(point: Vector3) -> Vector2i:
	var desired=HomesteadItems.cell_at(point)
	if open(desired): return desired
	var best_cell=Vector2i(5,5)
	var best_distance=INF
	for z in range(HomesteadItems.WORLD_BOUNDS.position.y,HomesteadItems.WORLD_BOUNDS.end.y):
		for x in range(HomesteadItems.WORLD_BOUNDS.position.x,HomesteadItems.WORLD_BOUNDS.end.x):
			var cell=Vector2i(x,z)
			if not open(cell): continue
			var distance=HomesteadItems.cell_center(cell).distance_squared_to(point)
			if distance<best_distance:
				best_distance=distance
				best_cell=cell
	return best_cell
# The same body clearance is used when rounding bends and skipping tile centers.
# Never smooth across a blocked cell or an inactive plot.
const BODY_RADIUS=0.22
func corridor_clear(from: Vector3,to: Vector3) -> bool:
	var count=maxi(1,ceili(from.distance_to(to)/0.10))
	for i in range(count+1):
		var point=from.lerp(to,float(i)/count)
		for offset in [Vector3.ZERO,Vector3(BODY_RADIUS,0,0),Vector3(-BODY_RADIUS,0,0),Vector3(0,0,BODY_RADIUS),Vector3(0,0,-BODY_RADIUS),Vector3(0.16,0,0.16),Vector3(-0.16,0,0.16),Vector3(0.16,0,-0.16),Vector3(-0.16,0,-0.16)]:
			if not open(HomesteadItems.cell_at(point+offset)): return false
	return true
func path(from: Vector3,to: Vector3) -> PackedVector3Array:
	var raw=PackedVector3Array()
	var points=grid.get_id_path(closest(from),closest(to))
	for cell in points: raw.append(HomesteadItems.cell_center(cell))
	if not raw.is_empty() and corridor_clear(raw[-1],to): raw[-1]=to
	if raw.size()<2: return raw
	# Start where the feet actually are, when that segment has clearance.
	if corridor_clear(from,raw[1]): raw[0]=from
	var corners=PackedVector3Array([raw[0]])
	for i in range(1,raw.size()-1):
		var incoming=(raw[i]-raw[i-1]).normalized()
		var outgoing=(raw[i+1]-raw[i]).normalized()
		if incoming.dot(outgoing)<0.999: corners.append(raw[i])
	corners.append(raw[raw.size()-1])
	var result=PackedVector3Array([corners[0]])
	for i in range(1,corners.size()-1):
		var corner=corners[i]
		var radius=minf(0.30,minf(corners[i-1].distance_to(corner),corner.distance_to(corners[i+1]))*0.32)
		var entry=corner.move_toward(corners[i-1],radius)
		var exit=corner.move_toward(corners[i+1],radius)
		var bend=PackedVector3Array([entry])
		for step in range(1,7):
			var t=float(step)/6
			bend.append(entry.lerp(corner,t).lerp(corner.lerp(exit,t),t))
		var clear=corridor_clear(result[result.size()-1],entry)
		for step in range(1,bend.size()): clear=clear and corridor_clear(bend[step-1],bend[step])
		if clear and corridor_clear(exit,corners[i+1]): result.append_array(bend)
		else: result.append(corner)
	result.append(corners[corners.size()-1])
	return result

func approach(item: Dictionary,from: Vector3=Vector3.INF) -> Vector3:
	if item.kind in ["tree","garden"]: return watering_approach(item,from)
	var size=HomesteadItems.footprint(item.kind,item.rotation)
	var center=HomesteadItems.item_center(item)
	var forward=Vector3(sin(item.rotation*PI/2),0,cos(item.rotation*PI/2))
	var distance=(float(size.x) if item.rotation%2 else float(size.y))/2+0.65
	if item.kind in ["garden","pond","tree"]:
		var best=Vector3.INF
		var best_score=-INF
		for side in [Vector3.FORWARD,Vector3.BACK,Vector3.LEFT,Vector3.RIGHT]:
			var reach=(float(size.x) if absf(side.x)>0.5 else float(size.y))/2+0.65
			var cell=HomesteadItems.cell_at(center+side*reach)
			if not open(cell): continue
			var point=HomesteadItems.cell_center(cell)
			var travel=0.0
			if from.is_finite():
				var route=grid.get_id_path(closest(from),cell)
				if route.is_empty(): continue
				for i in range(1,route.size()): travel+=Vector2(route[i]).distance_to(Vector2(route[i-1]))
			# Face the activity across its far edge when reachable, without a
			# long detour solely for the camera. Doors and seats keep their fronts.
			var facing=(center-point).normalized()
			var score=facing.dot(view_direction)*(0.2 if item.kind=="tree" else 1.2)-travel*0.1
			if score>best_score:
				best_score=score
				best=point
		if best.is_finite(): return best
	return HomesteadItems.cell_center(closest(center+forward*distance))

# Choose an actual reachable work position, then face the plant, never the lens.
func watering_approach(item: Dictionary,from: Vector3) -> Vector3:
	var size=HomesteadItems.footprint(item.kind,item.rotation)
	var center=HomesteadItems.item_center(item)
	var choices=[]
	var shortest=INF
	for side in [Vector3.FORWARD,Vector3.BACK,Vector3.LEFT,Vector3.RIGHT]:
		var reach=(float(size.x) if absf(side.x)>0.5 else float(size.y))/2+(1.42 if item.kind=="tree" else 0.72)
		var tangent=Vector3(-side.z,0,side.x)
		for shift in ([-0.8,0.0,0.8] if item.kind=="tree" else [-0.58,0.0,0.58]):
			var point=center+side*reach+tangent*shift
			var cell=HomesteadItems.cell_at(point)
			if not open(cell) or not corridor_clear(HomesteadItems.cell_center(cell),point): continue
			var distance=0.0
			if from.is_finite():
				var route=grid.get_id_path(closest(from),cell)
				if route.is_empty(): continue
				for i in range(1,route.size()): distance+=Vector2(route[i]).distance_to(Vector2(route[i-1]))
			shortest=minf(shortest,distance)
			var facing=(center-point).normalized()
			var lateral=absf((center-point).dot(Vector3(view_direction.z,0,-view_direction.x)))
			var hidden=2.6 if item.kind=="tree" and lateral<1.55 and facing.dot(view_direction)>0.2 else 0.0
			var marker_overlap=0.0
			var worker=HomesteadVisibility.projected_box(point,Vector3(0.45,1.95,0.4),view_direction)
			if item.kind=="garden":
				for role in ["material","production"]:
					marker_overlap+=HomesteadVisibility.overlap(worker,HomesteadVisibility.marker_bounds(item,role,view_direction))
			choices.append({"point":point,"distance":distance,"score":facing.dot(view_direction)*2.4-distance*0.12-hidden-marker_overlap*4.0})
	var best=Vector3.INF
	var score=-INF
	for choice in choices:
		if choice.distance<=shortest+3.5 and choice.score>score:
			score=choice.score
			best=choice.point
	return best if best.is_finite() else HomesteadItems.cell_center(closest(center+Vector3(0,0,1.2)))
