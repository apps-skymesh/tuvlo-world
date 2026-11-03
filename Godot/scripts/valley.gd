class_name HomesteadValley
extends Node3D

# Countryside around the homestead so the World never floats in an empty
# colour. Scenery only: no colliders, no cells, never part of Overview fitting.
const HAZE=Color("ede5c7")
const GROUND_Y=-0.12
const CENTER=Vector3(3,0,-3)
var ground_material: ShaderMaterial

func _ready():
	var plane=PlaneMesh.new()
	plane.size=Vector2(240,240)
	var ground=MeshInstance3D.new()
	ground.name="ValleyGround"
	ground.mesh=plane
	ground.position=Vector3(CENTER.x,GROUND_Y,CENTER.z)
	ground.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ground_material=ShaderMaterial.new()
	ground_material.shader=preload("res://scripts/valley.gdshader")
	ground_material.set_shader_parameter("haze_color",HAZE)
	ground.material_override=ground_material
	add_child(ground)
	var scenery=Node3D.new()
	scenery.name="ValleyScenery"
	add_child(scenery)
	plant_hills(scenery)
	plant_treeline(scenery)
	HomesteadStaticBatcher.consolidate(scenery,[])
	for child in scenery.get_children():
		if child is GeometryInstance3D: child.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

# Haze in four steps keeps materials shared, so the scenery batches into a
# handful of draw calls.
func hazed(hex: String,point: Vector3) -> String:
	var distance=Vector2((point.x-CENTER.x)*0.8,point.z-CENTER.z).length()
	var step=floorf(clampf((distance-20.0)/42.0,0,1)*4.0)/4.0
	return Color(hex).lerp(HAZE,step*0.6).to_html(false)

# Soft rolling hills behind the north ridge and both sides; nothing tall sits
# between the fixed camera and the land.
func plant_hills(root: Node3D):
	var hills=[[Vector3(-30,0,-26),Vector3(11,3.2,7)],[Vector3(-14,0,-33),Vector3(13,4.0,7)],[Vector3(6,0,-36),Vector3(15,4.6,8)],[Vector3(22,0,-30),Vector3(11,3.4,7)],[Vector3(-38,0,-8),Vector3(8,2.6,10)],[Vector3(-40,0,12),Vector3(7,2.0,9)]]
	for spec in hills:
		HomesteadMesh.ellipsoid(root,spec[0]+Vector3(0,GROUND_Y-0.4,0),spec[1],Color(hazed("8fae76",spec[0])).lerp(Color("8fae76"),0.35).to_html(false))

func plant_treeline(root: Node3D):
	var rng=RandomNumberGenerator.new()
	rng.seed=40213
	# Clumps along the back and sides, outside every land, edge and cove outline.
	var bands=[[Vector2(-34,-24),Vector2(26,-21),34],[Vector2(-31,-20),Vector2(-24,16),12],[Vector2(-30,14),Vector2(-14,20),6]]
	for band in bands:
		var a: Vector2=band[0]
		var b: Vector2=band[1]
		for i in int(band[2]):
			var p=Vector3(rng.randf_range(a.x,b.x),GROUND_Y,rng.randf_range(a.y,b.y))
			if outside_land(p): tree_clump(root,p,rng)
	# Low shrubs along the front edge stay below the camera's view of the land.
	for i in 10:
		var p=Vector3(rng.randf_range(-26,24),GROUND_Y,rng.randf_range(15.5,21))
		if outside_land(p): HomesteadMesh.ellipsoid(root,p+Vector3(0,0.12,0),Vector3(0.7,0.42,0.6)*rng.randf_range(0.7,1.2),hazed("7d9866",p))

func outside_land(p: Vector3) -> bool:
	var keep_clear=[Rect2(-23,-22,26,10),Rect2(-23,-9,52,24),Rect2(-1,-12,24,4)]
	for area in keep_clear:
		if area.has_point(Vector2(p.x,p.z)): return false
	return p.x<25.5

# A loose group of one to three trees in mixed shapes, sizes and greens, so
# the distant treeline reads as woodland rather than a row of copies.
const LEAF_TONES=["5f8f55","6a9459","7c9f62","86a866","55835a"]
func tree_clump(root: Node3D,p: Vector3,rng: RandomNumberGenerator):
	var count=1+int(rng.randf()<0.55)+int(rng.randf()<0.25)
	for i in count:
		var spot=p+(Vector3(rng.randf_range(-1.1,1.1),0,rng.randf_range(-0.8,0.8)) if i>0 else Vector3.ZERO)
		if i>0 and not outside_land(spot): continue
		var scale=rng.randf_range(0.6,1.25)*(0.78 if i>0 else 1.0)
		var shape=rng.randi_range(0,3)
		var tone=LEAF_TONES[rng.randi_range(0,LEAF_TONES.size()-1)]
		HomesteadMesh.cylinder(root,spot+Vector3(0,0.35*scale,0),0.12*scale,0.7*scale,hazed("8a6d4f",spot))
		match shape:
			0: # Tall pine: two stacked cones.
				HomesteadMesh.cylinder(root,spot+Vector3(0,1.15*scale,0),0.78*scale,1.5*scale,hazed("54805a",spot),0.0)
				HomesteadMesh.cylinder(root,spot+Vector3(0,2.0*scale,0),0.52*scale,1.3*scale,hazed("54805a",spot),0.0)
			1: # Slim fir.
				HomesteadMesh.cylinder(root,spot+Vector3(0,1.5*scale,0),0.55*scale,2.4*scale,hazed("4e7a55",spot),0.0)
			2: # Broadleaf crown of three blobs.
				for blob in [Vector3(0,1.35,0),Vector3(-0.42,1.08,0.12),Vector3(0.4,1.12,-0.1)]:
					HomesteadMesh.ellipsoid(root,spot+blob*scale,Vector3(0.62,0.58,0.62)*scale,hazed(tone,spot))
			_: # Round crown, a little wider than tall.
				HomesteadMesh.ellipsoid(root,spot+Vector3(0,1.2*scale,0),Vector3(0.95,0.78,0.9)*scale,hazed(tone,spot))
