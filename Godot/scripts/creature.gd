class_name HomesteadCreature
extends Node3D
var navigation: HomesteadNavigation
var data: HomesteadWorldData
var art: Node3D
var route=PackedVector3Array()
var timer=2.0
var arrived=false
var clock=0.0
var reduced_motion=false
var visits=0
func setup(world_data: HomesteadWorldData,nav: HomesteadNavigation,immediate=false):
	data=world_data
	navigation=nav
	art=Node3D.new()
	add_child(art)
	HomesteadMesh.ellipsoid(art,Vector3(0,0.31,0),Vector3(0.28,0.25,0.39),"f1e4c1")
	HomesteadMesh.ellipsoid(art,Vector3(0,0.57,0.22),Vector3(0.2,0.21,0.19),"f5e8c9")
	HomesteadMesh.ellipsoid(art,Vector3(0,0.49,0.43),Vector3(0.12,0.055,0.13),"dba76b")
	for x in [-0.165,0.165]:
		HomesteadMesh.ellipsoid(art,Vector3(x,0.6,0.31),Vector3.ONE*0.025,"4c5143")
		HomesteadMesh.ellipsoid(art,Vector3(x*1.6,0.33,0),Vector3(0.055,0.13,0.23),"dfd4b4")
	for x in [-0.12,0.12]:
		HomesteadMesh.box(art,Vector3(x,0.055,0.08),Vector3(0.13,0.06,0.2),"d6a16a",0.025)
	HomesteadMesh.ellipsoid(art,Vector3(0,0.79,0.18),Vector3(0.065,0.09,0.07),"e9d7b1")
	var shadow=HomesteadMesh.cylinder(self,Vector3(0,0.022,0),0.28,0.004,"64735b")
	shadow.material_override=HomesteadMesh.transparent(Color(0.22,0.29,0.21,0.12))
	position=HomesteadItems.cell_center(navigation.closest(Vector3(7.5,0,6.5)))
	if immediate: position=target_position()
	else: route=navigation.path(position,target_position())
func target_position() -> Vector3:
	var habitat=HomesteadHabitat.best(data)
	if habitat.pond.is_empty(): return HomesteadItems.cell_center(navigation.closest(Vector3(3,0,2)))
	var center=HomesteadItems.item_center(habitat.pond)
	return HomesteadItems.cell_center(navigation.closest(center+Vector3(-2.2,0,1.4)))
func world_changed():
	if not navigation.open(HomesteadItems.cell_at(position)): position=HomesteadItems.cell_center(navigation.closest(position))
	route=navigation.path(position,target_position())
func _physics_process(delta):
	if art==null: return
	clock+=delta
	if not route.is_empty():
		var direction=route[0]-position
		if direction.length()<0.04:
			route.remove_at(0)
			if route.is_empty():
				arrived=true
				visits+=1
		else:
			position=position.move_toward(route[0],delta*0.7)
			rotation.y=lerp_angle(rotation.y,atan2(direction.x,direction.z),minf(1,delta*5))
			art.rotation.z=sin(clock*8)*0.035 if not reduced_motion else 0
	else:
		art.rotation.z=0
		rotation.y=lerp_angle(rotation.y,0.45,minf(1,delta*2))
		timer-=delta
		if timer<=0:
			timer=9.0
			var target=target_position()+Vector3(sin(clock)*1.2,0,cos(clock)*1.2)
			route=navigation.path(position,HomesteadItems.cell_center(navigation.closest(target)))
