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
 items = next
 inventory = unplaced
 land_sides = lands
 discovered = raw.get("discovered", false) == true
 approvals = maxi(0, int(raw.get("approvedWins",0)))
 growth_tree_id = raw.get("growthTreeID","")
 return true

func buildable(cell: Vector2i) -> bool:
 if cell.x >= 0 and cell.x < 18 and cell.y >= 0 and cell.y < 16:
  return not ((cell.x < 2 or cell.x > 15) and (cell.y < 2 or cell.y > 13))
 if cell.y >= 6 and cell.y < 10:
  if "east" in land_sides and cell.x >= 18 and cell.x < 22: return true
  if "west" in land_sides and cell.x >= -4 and cell.x < 0: return true
 return "north" in land_sides and cell.x >= 7 and cell.x < 11 and cell.y >= -4 and cell.y < 0

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
   if kind in ["greenhouse","orchard"] and not (square.x>=-4 and square.x<0 and square.y>=6 and square.y<10): return "outside-land"
   if not buildable(square): return "outside-land"
   if not item_at(square,excluding).is_empty(): return "occupied"
 return ""
