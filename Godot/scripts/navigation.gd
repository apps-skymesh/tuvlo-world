class_name HomesteadNavigation
extends RefCounted
var grid=AStarGrid2D.new()
var data: HomesteadWorldData
var revision=0
func rebuild(world_data: HomesteadWorldData):
	data=world_data
	grid.region=HomesteadItems.WORLD_BOUNDS
	grid.cell_size=Vector2.ONE
	grid.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.default_compute_heuristic=AStarGrid2D.HEURISTIC_OCTILE
	grid.default_estimate_heuristic=AStarGrid2D.HEURISTIC_OCTILE
	grid.update()
	for z in range(HomesteadItems.WORLD_BOUNDS.position.y,HomesteadItems.WORLD_BOUNDS.end.y):
		for x in range(HomesteadItems.WORLD_BOUNDS.position.x,HomesteadItems.WORLD_BOUNDS.end.x):
			var cell=Vector2i(x,z)
			var occupied=data.item_at(cell)
			var blocked=not data.buildable(cell) or (not occupied.is_empty() and HomesteadItems.DEFINITIONS[occupied.kind].blocks)
			grid.set_point_solid(cell,blocked)
			grid.set_point_weight_scale(cell,0.8 if not occupied.is_empty() and occupied.kind=="path" else 1.0)
	revision+=1
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

func approach(item: Dictionary) -> Vector3:
	var size=HomesteadItems.footprint(item.kind,item.rotation)
	var center=HomesteadItems.item_center(item)
	var forward=Vector3(sin(item.rotation*PI/2),0,cos(item.rotation*PI/2))
	var distance=(float(size.x) if item.rotation%2 else float(size.y))/2+0.65
	return HomesteadItems.cell_center(closest(center+forward*distance))
