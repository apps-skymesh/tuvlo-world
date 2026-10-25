class_name HomesteadWorldData
extends RefCounted

# Read-only authoritative projection. This runtime has no save, approve, currency
# or reset methods. Only a validated host snapshot can change committed items.
var items: Array[Dictionary] = []
var inventory: Dictionary = {}
var land_sides: Array[String] = []
var discovered := false
var approvals := 0
var growth_tree_id=""
# Ready materials by scene key (piece ID or edge producer). Display only.
var harvest: Dictionary = {}
var edges := false
var visitor := ""
var wheat_garden := false
var farm_stages: Array = []
var farm_fruit_stage := -1
var production: Array[Dictionary] = []
const STATION_KINDS={"field":"garden","mill":"windmill","oven":"cottage","pantry":"cottage","orchard":"orchard"}
const STATION_GOODS={"field":["wheat"],"mill":["flour"],"oven":["bread","tart"],"pantry":["meal"],"orchard":["fruit"]}
const HARVEST_MATERIALS=["wood","stone","food","wheat"]
const EDGE_PRODUCERS=["woods","quarry","waterside"]

func apply_snapshot(raw: Dictionary) -> bool:
 var next: Array[Dictionary] = []
 var ids := {}
 var unplaced := {}
 if not raw.get("items") is Array or raw.items.size() > 4096:
  return false
 for object in raw.items:
  if not object is Dictionary or not object.get("id") is String or ids.has(object.id):
   return false
  if not HomesteadItems.DEFINITIONS.has(object.get("kind", "")):
   return false
  ids[object.id] = true
  if not object.get("cell") is Dictionary:
   unplaced[object.id] = {"id":object.id,"kind":object.kind,"cell":Vector2i(-3,7) if object.kind in ["greenhouse","orchard"] else Vector2i(8,8),"rotation":int(object.get("rotation",0)),"style":int(object.get("style",0))}
   continue
  var x = object.cell.get("x")
  var z = object.cell.get("z")
  var rotation = object.get("rotation", 0)
  if not (x is int or x is float) or not (z is int or z is float): return false
  if absf(float(x)) > 32 or absf(float(z)) > 32 or int(rotation) < 0 or int(rotation) > 3: return false
  ids[object.id] = true
  next.append({"id":object.id, "kind":object.kind, "cell":Vector2i(int(x),int(z)), "rotation":int(rotation), "style":int(object.get("style",0))})
 var lands: Array[String] = []
 for side in raw.get("land", []):
  if side not in ["east", "west", "north"]: return false
  if side not in lands: lands.append(side)
 var ready := {}
 var raw_harvest = raw.get("harvest", {})
 if not raw_harvest is Dictionary or raw_harvest.size() > 32: return false
 for key in raw_harvest:
  if not key is String or key.length() > 64 or not raw_harvest[key] in HARVEST_MATERIALS: return false
  if key in EDGE_PRODUCERS or ids.has(key): ready[key] = raw_harvest[key]
 var next_visitor=raw.get("visitor", "")
 if next_visitor not in ["", "baker", "storyteller"]: return false
 visitor=next_visitor
 var stages=raw.get("farmStages",[])
 if stages == null: stages=[]
 if not stages is Array or stages.size() not in [0,2]: return false
 for stage in stages:
  if not (stage is int or stage is float) or int(stage) < 0 or int(stage) > 4: return false
 farm_stages=stages
 var fruit_stage=raw.get("farmFruitStage",-1)
 if fruit_stage == null: fruit_stage=-1
 if not (fruit_stage is int or fruit_stage is float) or int(fruit_stage) < -1 or int(fruit_stage) > 2: return false
 farm_fruit_stage=int(fruit_stage)
 var next_production: Array[Dictionary]=[]
 var raw_production=raw.get("production",[])
 if not raw_production is Array or raw_production.size()>5: return false
 var stations={}
 for status in raw_production:
  if not status is Dictionary: return false
  var station=status.get("station","")
  if not station is String or not STATION_KINDS.has(station) or stations.has(station): return false
  if status.get("good","") not in STATION_GOODS[station]: return false
  var place_id=status.get("placeID","")
  if not place_id is String: return false
  var placed=false
  for item in next:
   if item.id==place_id and item.kind==STATION_KINDS[station]: placed=true
  if not placed: return false
  for key in ["state","remaining","progress"]:
   if not (status.get(key) is int or status.get(key) is float) or not is_finite(float(status[key])): return false
  # JSON numbers arrive as floats; normalize integral enum/count fields before use.
  var state=int(status.state)
  var remaining=int(status.remaining)
  if state!=status.state or state not in [0,1,2] or remaining!=status.remaining or remaining<0 or remaining>86400 or status.progress<0 or status.progress>1: return false
  stations[station]=true
  var normalized=status.duplicate()
  normalized.state=state
  normalized.remaining=remaining
  next_production.append(normalized)
 production=next_production
 wheat_garden=raw.get("wheatGarden",false)==true
 items = next
 harvest = ready
 edges = raw.get("edges", false) == true
 inventory = unplaced
 land_sides = lands
 discovered = raw.get("discovered", false) == true
 approvals = maxi(0, int(raw.get("approvedWins",0)))
 growth_tree_id = raw.get("growthTreeID","")
 return true

func buildable(cell: Vector2i) -> bool:
 if HomesteadItems.BASE_BOUNDS.has_point(cell): return true
 for side in land_sides:
  if HomesteadItems.LAND_BOUNDS[side].has_point(cell): return true
 return false

func find(id) -> Dictionary:
 for item in items:
  if item.id == id: return item
 return {}
func item_at(cell: Vector2i, excluding = "") -> Dictionary:
 for item in items:
  if item.id != excluding and Rect2i(item.cell, HomesteadItems.footprint(item.kind,item.rotation)).has_point(cell): return item
 return {}
func placement_error(kind: String, cell: Vector2i, rotation: int, excluding = "") -> String:
 if not HomesteadItems.DEFINITIONS.has(kind): return "unknown-item"
 for z in HomesteadItems.footprint(kind,rotation).y:
  for x in HomesteadItems.footprint(kind,rotation).x:
   var square = cell + Vector2i(x,z)
   if kind in ["greenhouse","orchard"] and not HomesteadItems.LAND_BOUNDS.west.has_point(square): return "outside-land"
   if not buildable(square): return "outside-land"
   if not item_at(square,excluding).is_empty(): return "occupied"
 return ""
