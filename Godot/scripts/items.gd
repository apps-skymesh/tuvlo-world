class_name HomesteadItems
extends RefCounted

# Visible terrain extents are independent of authoritative build permission.
const BASE_LAND_SIZE=Vector2(19.3,17.3)
const PLOT_SIZE=Vector2(4.5,4.6)
const LAND_CENTERS={"north":Vector3(0,0,-10),"east":Vector3(11,0,0),"west":Vector3(-11,0,0)}

const DEFINITIONS={
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
