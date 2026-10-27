class_name HomesteadItems
extends RefCounted

# Starter plots contain 5x5 squares; extensions now contain 12x12 squares.
# Enlargement adds outer strips; saved item coordinates never move.
const WELL_SIZE=Vector2i(2,2)
const WELL_HEIGHT=2.6
const SQUARES_PER_PLOT=5
const STARTER_PLOTS=4
const EXPANSION_SIDE=12
const BASE_BOUNDS=Rect2i(0,0,20,20)
const WORLD_BOUNDS=Rect2i(-12,-12,44,32)
const LAND_BOUNDS={"west":Rect2i(-12,0,12,12),"east":Rect2i(20,0,12,12),"north":Rect2i(0,-12,12,12)}
const BASE_LAND_SIZE=Vector2(20.7,20.7)
const BASE_LAND_CENTER=Vector3(1,0,2)
const PLOT_SIZE=Vector2(12.6,12.6)
const LAND_CENTERS={"north":Vector3(-3,0,-14),"east":Vector3(17,0,-2),"west":Vector3(-15,0,-2)}
# Fixed producer scenery beside the clearing: never buildable or walkable.
const EDGE_CENTERS={"woods":Vector3(-14.2,0,8),"quarry":Vector3(16.2,0,8)}
const EDGE_SIZE=Vector2(8,7)
# Shared scenery extrema keep fitted Overview honest, including the new ridge
# and coastline outside usable squares. These points never grant buildable cells.
const SCENIC_POINTS=[Vector3(-5.912,4.42,-16.192),Vector3(-2.54,6.42,-17.24),Vector3(0.752,4.72,-16.168),Vector3(27.8,-0.8,-8.4),Vector3(27.8,0.4,4.4)]

const DEFINITIONS={
	"barn":{"title":"Barn","size":Vector2i(4,3),"blocks":true,"height":3.5,"color":"b46c52"},
	"doghouse":{"title":"Dog house","size":Vector2i(2,2),"blocks":true,"height":1.4,"color":"c79a6e"},
	"grill":{"title":"Grill","size":Vector2i(2,2),"blocks":true,"height":1.4,"color":"566b66"},
	"windmill":{"title":"Windmill","size":Vector2i(3,3),"blocks":true,"height":4.1,"color":"d9c8a5"},
	"orchard":{"title":"Orchard","size":Vector2i(2,2),"blocks":true,"height":2.8,"color":"8aa578"},
	"greenhouse":{"title":"Greenhouse","size":Vector2i(3,2),"blocks":true,"height":2.65,"color":"8ca99a"},
	"workshop":{"title":"Maker Workshop","size":Vector2i(3,3),"blocks":true,"height":2.8,"color":"b79470"},
	"path":{"title":"Path","size":Vector2i(1,1),"blocks":false,"height":0.12,"color":"d6c29c"},
	"flowers":{"title":"Flowers","size":Vector2i(1,1),"blocks":false,"height":0.65,"color":"dfaa9c"},
	"bench":{"title":"Bench","size":Vector2i(2,1),"blocks":true,"height":1.1,"color":"bb8055"},
	"pond":{"title":"Pond","size":Vector2i(3,3),"blocks":true,"height":0.25,"color":"7fbdc3"},
	"cottage":{"title":"Cottage","size":Vector2i(4,3),"blocks":true,"height":4.2,"color":"ead9b6"},
	"garden":{"title":"Garden","size":Vector2i(3,2),"blocks":true,"height":0.65,"color":"8fa877"},
	"tree":{"title":"Tree","size":Vector2i(1,1),"blocks":true,"height":3.7,"color":"83a574"},
	"nook":{"title":"Reading Nook","size":Vector2i(2,2),"blocks":true,"height":1.5,"color":"b2a0bf"},
	"treehouse":{"title":"Treetop Hideaway","size":Vector2i(3,3),"blocks":true,"height":4.8,"color":"bb8055"},
	"rocks":{"title":"Rocks","size":Vector2i(1,1),"blocks":true,"height":0.6,"color":"acb5a6"}
}
# Native Tuvlo owns inventory/prices. There is no runtime shop catalog.
static func footprint(kind: String,rotation: int) -> Vector2i:
	var size: Vector2i=DEFINITIONS[kind].size
	return Vector2i(size.y,size.x) if rotation%2!=0 else size
static func center(cell: Vector2i,size: Vector2i) -> Vector3:
	return Vector3(cell.x+float(size.x)/2-9,0,cell.y+float(size.y)/2-8)
static func cell_at(point: Vector3) -> Vector2i:
	return Vector2i(floori(point.x+9),floori(point.z+8))
static func cell_center(cell: Vector2i) -> Vector3:
	return Vector3(cell.x-8.5,0,cell.y-7.5)
static func item_center(item: Dictionary) -> Vector3:
	return center(item.cell,footprint(item.kind,item.rotation))
