class_name HomesteadNavigation
extends RefCounted
var grid=AStarGrid2D.new()
var data: HomesteadWorldData
var revision=0
var well_cell=Vector2i(10000,10000)
var well_center=Vector3.INF
var oven_centers: Dictionary={}
var oven_cells: Dictionary={}
# The kitchen bench (A70) attaches to the cottage's other side, like the oven.
var kitchen_centers: Dictionary={}
var kitchen_cells: Dictionary={}
var view_direction=Vector3(sin(0.25),0,cos(0.25))
const OUTBUILDING_GAP=2   # open cells between the cottage and its kitchen (the oven keeps one: the yard's edge is near)
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
# The well stands from the first visit beside the tree's spot and stays put
# as the cottage and later places are built (owner 2026-11-05).
const TREE_SPOT=Vector2i(12,2)
# Nearest clear spot whose outline stays apart from the tree's. Only the tree
# and the squares it needs decide it, so later buildings never move it.
func tree_well_cell(occupied: Dictionary) -> Vector2i:
	var anchor={"kind":"tree","cell":TREE_SPOT,"rotation":0}
	var trees=data.items.filter(func(item): return item.kind=="tree")
	var growing=trees.filter(func(item): return item.id==data.growth_tree_id)
	if not growing.is_empty(): anchor=growing[0]
	elif not trees.is_empty(): anchor=trees[0]
	var tree_outline=HomesteadVisibility.item_bounds(anchor,view_direction).grow(0.2)
	var tree_center=HomesteadItems.item_center(anchor)
	var best=Vector2i(10000,10000)
	var best_distance=INF
	for dz in range(-6,7):
		for dx in range(-6,7):
			var cell=anchor.cell+Vector2i(dx,dz)
			var center=HomesteadItems.center(cell,HomesteadItems.WELL_SIZE)
			var distance=center.distance_to(tree_center)
			if distance>=best_distance: continue
			var clear=true
			for z in 2:
				for x in 2:
					var square=cell+Vector2i(x,z)
					if not data.buildable(square) or occupied.has(square) or not open(square): clear=false
			var approach=cell+Vector2i(-1,1)
			if not clear or not data.buildable(approach) or occupied.has(approach) or not open(approach): continue
			var outline=HomesteadVisibility.projected_box(center,Vector3(1.05,HomesteadItems.WELL_HEIGHT,0.95),view_direction).grow(0.25)
			if HomesteadVisibility.overlap(outline,tree_outline)>=0.01: continue
			best=cell
			best_distance=distance
	return best
func place_water_source(occupied: Dictionary):
	well_center=Vector3.INF
	var fixed=tree_well_cell(occupied)
	if fixed.x!=10000:
		well_cell=fixed
		well_center=HomesteadItems.center(fixed,HomesteadItems.WELL_SIZE)
		for z in 2:
			for x in 2: grid.set_point_solid(fixed+Vector2i(x,z),true)
		return
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
	var previous_ovens=oven_cells.duplicate()
	var previous_kitchens=kitchen_cells.duplicate()
	oven_centers.clear(); oven_cells.clear()
	kitchen_centers.clear(); kitchen_cells.clear()
	if not data.oven_revealed: return
	var silhouettes=[]
	for item in data.items:
		if item.kind not in ["path","flowers","rocks"]: silhouettes.append(HomesteadVisibility.item_bounds(item,view_direction))
		if item.kind in ["garden","pond","windmill","greenhouse","orchard","workshop","cottage","barn","grill"]:
			for role in ["material","production"]: silhouettes.append(HomesteadVisibility.marker_bounds(item,role,view_direction))
	if well_center.is_finite(): silhouettes.append(HomesteadVisibility.projected_box(well_center,Vector3(1.05,2.6,0.95),view_direction))
	for cottage in data.items:
		if cottage.kind!="cottage" or not data.building(cottage.id).is_empty(): continue
		var oven=attach_beside(cottage,-3.0,previous_ovens.get(cottage.id,Vector2i(10000,10000)),occupied,silhouettes)
		if oven.x!=10000:
			oven_cells[cottage.id]=oven; oven_centers[cottage.id]=HomesteadItems.center(oven,Vector2i(2,2))
		# The kitchen never stands in front of (or behind) the oven, so the oven card shows the oven.
		var oven_outline=HomesteadVisibility.projected_box(oven_centers[cottage.id],Vector3(1.1,2.4,1.1),view_direction) if oven_centers.has(cottage.id) else Rect2()
		var kitchen=attach_beside(cottage,3.0,previous_kitchens.get(cottage.id,Vector2i(10000,10000)),occupied,silhouettes,1,2.6,Vector3.ZERO,oven_outline)
		# A crowded older yard still gets its kitchen: a snug 2 x 2 against another wall.
		for offset in [Vector3(3,0,0),Vector3(2.6,0,-2.2),Vector3(0,0,-3.2),Vector3(-2.6,0,-2.2),Vector3(2.6,0,2.4)]:
			if kitchen.x!=10000: break
			kitchen=attach_beside(cottage,3.0,previous_kitchens.get(cottage.id,Vector2i(10000,10000)),occupied,silhouettes,0,2.2,offset,oven_outline)
		# Only a yard with no clear wall at all lets the two overlap on screen.
		for offset in [Vector3(3,0,0),Vector3(2.6,0,-2.2),Vector3(0,0,-3.2),Vector3(-2.6,0,-2.2),Vector3(2.6,0,2.4)]:
			if kitchen.x!=10000: break
			kitchen=attach_beside(cottage,3.0,previous_kitchens.get(cottage.id,Vector2i(10000,10000)),occupied,silhouettes,0,2.2,offset)
		if kitchen.x!=10000:
			kitchen_cells[cottage.id]=kitchen; kitchen_centers[cottage.id]=HomesteadItems.center(kitchen,Vector2i(2,2))

# A 2 x 2 attachment beside the cottage with an empty ring, keeping doors,
# paths and routes clear; it then blocks walking like a placed piece.
func attach_beside(cottage: Dictionary,side: float,previous: Vector2i,occupied: Dictionary,silhouettes: Array,margin: int=1,reach: float=2.6,offset: Vector3=Vector3.ZERO,avoid: Rect2=Rect2()) -> Vector2i:
	var cottage_rect=Rect2i(cottage.cell,HomesteadItems.footprint(cottage.kind,cottage.rotation))
	var desired=HomesteadItems.item_center(cottage)+(offset if offset!=Vector3.ZERO else Vector3(side,0,0)).rotated(Vector3.UP,cottage.rotation*PI/2)
	var best=Vector2i(10000,10000)
	var best_score=INF
	for z in range(HomesteadItems.WORLD_BOUNDS.position.y,HomesteadItems.WORLD_BOUNDS.end.y-1):
		for x in range(HomesteadItems.WORLD_BOUNDS.position.x,HomesteadItems.WORLD_BOUNDS.end.x-1):
			var cell=Vector2i(x,z)
			var clear=true
			for dz in range(-margin,2+margin):
				for dx in range(-margin,2+margin):
					var square=cell+Vector2i(dx,dz)
					if not data.buildable(square) or occupied.has(square) or not open(square): clear=false
			if not clear: continue
			# SOLO 2026-11-06: a strip of open grass between the house and each
			# outbuilding, so the oven and kitchen read as places of their own.
			if Rect2i(cell,Vector2i(2,2)).grow(OUTBUILDING_GAP if side>0 else 1).intersects(cottage_rect): continue
			var center=HomesteadItems.center(cell,Vector2i(2,2))
			# Only spots against the wall compete; a far, unobstructed spot never wins.
			if side>0 and center.distance_to(desired)>reach: continue
			var outline=HomesteadVisibility.projected_box(center,Vector3(1.0,2.3,1.0),view_direction)
			if avoid.has_area() and HomesteadVisibility.overlap(outline,avoid)>0.0: continue
			var score=center.distance_to(desired)
			for silhouette in silhouettes: score+=HomesteadVisibility.overlap(outline.grow(0.15),silhouette)*10.0
			if previous==cell: score-=0.35
			if score<best_score:
				best=cell
				best_score=score
	if best.x==10000: return best
	var center=HomesteadItems.center(best,Vector2i(2,2))
	# An attachment stays beside the house; with no room there it simply waits.
	if side>0 and center.distance_to(desired)>reach: return Vector2i(10000,10000)
	silhouettes.append(HomesteadVisibility.projected_box(center,Vector3(1,2.4,1),view_direction))
	for z in 2:
		for x in 2: grid.set_point_solid(best+Vector2i(x,z),true)
	return best

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
