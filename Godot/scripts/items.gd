class_name HomesteadItems
extends RefCounted

# Land units contain 5x5 building squares. Saved item coordinates never move.
const SQUARES_PER_PLOT=5
const STARTER_PLOTS=4
const EXPANSION_PLOTS=2
const BASE_BOUNDS=Rect2i(0,0,20,20)
const WORLD_BOUNDS=Rect2i(-10,-10,40,30)
const LAND_BOUNDS={"west":Rect2i(-10,0,10,10),"east":Rect2i(20,0,10,10),"north":Rect2i(0,-10,10,10)}
const BASE_LAND_SIZE=Vector2(20.7,20.7)
const BASE_LAND_CENTER=Vector3(1,0,2)
const PLOT_SIZE=Vector2(10.5,10.5)
const LAND_CENTERS={"north":Vector3(-4,0,-13),"east":Vector3(16,0,-3),"west":Vector3(-14,0,-3)}
# Fixed producer scenery beside the clearing: never buildable or walkable.
const EDGE_CENTERS={"woods":Vector3(-14.2,0,6.4),"quarry":Vector3(16.2,0,6.4)}
const EDGE_SIZE=Vector2(8,7)

const DEFINITIONS={
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
