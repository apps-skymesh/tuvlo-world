class_name HomesteadVisibility
extends RefCounted
# The fixed 30-degree World camera, in world units, independent of zoom/pan.
static func project(point: Vector3,direction: Vector3) -> Vector2:
 var right=Vector3(direction.z,0,-direction.x)
 var up=Vector3(-direction.x*0.5,0.8660254,-direction.z*0.5)
 return Vector2(point.dot(right),point.dot(up))
static func item_bounds(item: Dictionary,direction: Vector3) -> Rect2:
 var size=Vector2(HomesteadItems.footprint(item.kind,item.rotation))*0.5+Vector2.ONE*0.15
 if item.kind=="tree": size=Vector2.ONE*1.55
 return projected_box(HomesteadItems.item_center(item),Vector3(size.x,HomesteadItems.DEFINITIONS[item.kind].height,size.y),direction)
static func projected_box(center: Vector3,extent: Vector3,direction: Vector3) -> Rect2:
 var low=Vector2(INF,INF)
 var high=Vector2(-INF,-INF)
 for x in [-extent.x,extent.x]:
  for z in [-extent.z,extent.z]:
   for y in [0.0,extent.y]:
    var p=project(center+Vector3(x,y,z),direction)
    low=low.min(p)
    high=high.max(p)
 return Rect2(low,high-low)
static func overlap(a: Rect2,b: Rect2) -> float:
 return a.intersection(b).get_area() if a.intersects(b) else 0.0

# Permanent front-edge slots. They depend only on the placed piece and role,
# never on the child, camera, zoom, timers, or which neighbouring badge is present.
static func marker_position(item: Dictionary,role: String) -> Vector3:
 var size=HomesteadItems.footprint(item.kind,item.rotation)
 var side=clampf(float(size.x)*0.30,0.65,1.15)
 var x=-side if role in ["material","oven"] else side
 var y=1.05 if item.kind in ["garden","pond"] else 1.15
 if role=="construction":
  x=0.0
  y=1.45
 return HomesteadItems.item_center(item)+Vector3(x,y,float(size.y)*0.5+0.9)
static func marker_bounds(item: Dictionary,role: String,direction: Vector3) -> Rect2:
 var point=project(marker_position(item,role),direction)
 return Rect2(point-Vector2(0.65,0.8),Vector2(1.3,1.3))

func markers(entries: Array,items: Array):
 for marker in entries:
  if not is_instance_valid(marker): continue
  var id=str(marker.get_meta("marker_place_id",""))
  var place={}
  for item in items:
   if item.id==id:
    place=item
    break
  var target: Vector3=marker.get_meta("marker_anchor",marker.get_meta("anchor",Vector3.ZERO))
  if not place.is_empty(): target=marker_position(place,str(marker.get_meta("marker_role","material")))
  if not marker.has_meta("fixed_marker_position") or not marker.global_position.is_equal_approx(target):
   marker.global_position=target
   marker.set_meta("fixed_marker_position",target)
  if not marker.scale.is_equal_approx(Vector3.ONE*0.82): marker.scale=Vector3.ONE*0.82
  marker.set_meta("marker_placed",true)
