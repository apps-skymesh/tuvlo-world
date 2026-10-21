class_name HomesteadNavigation
extends RefCounted
var grid=AStarGrid2D.new()
var data: HomesteadWorldData
var revision=0
func rebuild(world_data: HomesteadWorldData):
	data=world_data
	grid.region=Rect2i(-4,-4,26,20)
	grid.cell_size=Vector2.ONE
	grid.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.default_compute_heuristic=AStarGrid2D.HEURISTIC_OCTILE
	grid.default_estimate_heuristic=AStarGrid2D.HEURISTIC_OCTILE
	grid.update()
	for z in range(-4,16):
		for x in range(-4,22):
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
	for z in range(-4,16):
		for x in range(-4,22):
			var cell=Vector2i(x,z)
			if not open(cell): continue
			var distance=HomesteadItems.cell_center(cell).distance_squared_to(point)
			if distance<best_distance:
				best_distance=distance
				best_cell=cell
	return best_cell
func path(from: Vector3,to: Vector3) -> PackedVector3Array:
	var result=PackedVector3Array()
	var points=grid.get_id_path(closest(from),closest(to))
	for cell in points: result.append(HomesteadItems.cell_center(cell))
	return result
func approach(item: Dictionary) -> Vector3:
	var size=HomesteadItems.footprint(item.kind,item.rotation)
	var center=HomesteadItems.item_center(item)
	var forward=Vector3(sin(item.rotation*PI/2),0,cos(item.rotation*PI/2))
	var distance=(float(size.x) if item.rotation%2 else float(size.y))/2+0.65
	return HomesteadItems.cell_center(closest(center+forward*distance))
