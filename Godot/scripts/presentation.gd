class_name HomesteadPresentation
extends Node3D
var data: HomesteadWorldData
var marker_layout=HomesteadVisibility.new()
var well: HomesteadWell
var prop_root: Node3D
var land_root: Node3D
var foliage: Array[Node3D]=[]
var waters: Array[ShaderMaterial]=[]
var sails: Array[Node3D]=[]
var pet_parts: Array[Node3D]=[]
var clock=0.0
var reduced_motion=false
var nodes: Dictionary={}
var preview_node: Node3D
var highlight_size=Vector2i.ZERO
var highlight_fill: StandardMaterial3D
var highlight_border: StandardMaterial3D
var preview_item: Node3D
var preview_item_id=""
var grid_root: Node3D
var grid_visible=false
var visual_revision=0
var land_signature=""
var land_waters: Array[ShaderMaterial]=[]
var pending_tree_growth=0
var yellow_leaves=false
var harvest_root: Node3D
var bubbles: Array[Node3D]=[]
var ovens: Dictionary={}
var kitchens: Dictionary={}
## Production cards hide the focused place's own map bubbles; the card shows them.
var hidden_marker_place=""
# Screen fraction of the HUD's warehouse box; collected goods fly there.
var warehouse_point=Vector2(0.86,0.07)
var porches: Dictionary={}
const KITCHEN_MODEL=preload("res://assets/house/kitchen_bench.glb")
const PORCH_MODEL=preload("res://assets/house/front_porch.glb")
var ready_goods: Dictionary={}
var production_root: Node3D
var production_nodes: Dictionary={}
var production_effects: Dictionary={}
var construction_nodes: Dictionary={}
var harvest_signature=""
var awakening: HomesteadAwakening
# Bubbles the child just tapped, by producer key, with the clock time of the tap.
var collecting: Dictionary={}
const BUBBLE_SHADER=preload("res://scripts/harvest_bubble.gdshader")
const PRODUCT_ART={"wheat":preload("res://assets/goods/wheat.png"),"flour":preload("res://assets/goods/flour.png"),"bread":preload("res://assets/goods/bread.png"),"meal":preload("res://assets/goods/meal.png"),"fruit":preload("res://assets/goods/fruit.png"),"tart":preload("res://assets/goods/tart.png"),"meat":preload("res://assets/goods/meat.png")}

func setup(world_data: HomesteadWorldData):
	data=world_data
	well=HomesteadWell.new()
	well.name="SharedWell"
	add_child(well)
	well.place(Vector3.INF)
	var valley=HomesteadValley.new()
	valley.name="Valley"
	add_child(valley)
	awakening=HomesteadAwakening.new()
	awakening.name="Awakening"
	add_child(awakening)
	land_root=Node3D.new()
	add_child(land_root)
	prop_root=Node3D.new()
	add_child(prop_root)
	grid_root=Node3D.new()
	add_child(grid_root)
	harvest_root=Node3D.new()
	production_root=Node3D.new()
	production_root.name="Production"
	add_child(production_root)
	harvest_root.name="Harvest"
	add_child(harvest_root)
	rebuild()

func rebuild():
	# Layout commits move existing roots. Rebuild artwork only when its style,
	# rotation or earned growth changed; UI work must not recreate the island.
	var next_land=JSON.stringify([data.land_sides,data.edges])
	if next_land!=land_signature:
		for child in land_root.get_children():
			land_root.remove_child(child)
			child.queue_free()
		waters.clear()
		build_island()
		land_waters=waters.duplicate()
		land_signature=next_land
	awakening.wake(data.approvals,reduced_motion)
	foliage.clear()
	sails.clear()
	pet_parts.clear()
	waters=land_waters.duplicate()
	var present={}
	for item in data.items: present[item.id]=true
	for id in nodes.keys():
		if not present.has(id):
			var removed: Node3D=nodes[id]
			prop_root.remove_child(removed)
			removed.queue_free()
			nodes.erase(id)
	for item in data.items:
		var tree_wins=max(0,data.approvals-pending_tree_growth)
		var growth=(0 if tree_wins<3 else 1 if tree_wins<13 else 2) if item.kind=="tree" and item.id==data.growth_tree_id else -1
		var build=data.building(item.id)
		var building_phase=-1 if build.is_empty() else int(floor(clampf(build.progress,0.0,0.999)*5.0))
		var completed=nodes.has(item.id) and nodes[item.id].get_meta("building",false) and build.is_empty()
		var signature=JSON.stringify([building_phase,item.kind,item.rotation,item.get("style",0),growth,tree_wins if growth>=0 else 0,yellow_leaves and growth>=0,data.approvals>=34 if item.kind=="cottage" else data.approvals>=55 if item.kind=="path" else false,[data.wheat_garden,data.harvest.values().has("wheat"),data.farm_stages] if item.kind=="garden" else data.farm_fruit_stage if item.kind=="orchard" else []])
		if nodes.has(item.id):
			var existing: Node3D=nodes[item.id]
			if existing.get_meta("art_signature","")==signature:
				existing.position=HomesteadItems.item_center(item)
				foliage.append_array(existing.get_meta("foliage",[]))
				waters.append_array(existing.get_meta("waters",[]))
				sails.append_array(existing.get_meta("sails",[]))
				pet_parts.append_array(existing.get_meta("pet_parts",[]))
				continue
			var growing=existing.get_child(0).get_node_or_null("MissionTree")
			if growing is HomesteadMissionTree and growth>=0 and not existing.get_meta("building",false) and building_phase<0 and is_equal_approx(existing.get_child(0).rotation.y,item.rotation*PI/2):
				growing.configure(tree_wins,yellow_leaves,reduced_motion)
				existing.position=HomesteadItems.item_center(item)
				existing.set_meta("art_signature",signature)
				for child in existing.get_children():
					if child is StaticBody3D:
						var collider=child.get_child(0)
						var height=1.4 if tree_wins<3 else 2.4 if tree_wins<13 else 3.6
						collider.shape.size=Vector3(1,height,1)
						collider.position.y=height/2
				continue
			prop_root.remove_child(existing)
			existing.queue_free()
		var foliage_start=foliage.size()
		var waters_start=waters.size()
		var sails_start=sails.size()
		var root=make_item(item.kind,item.rotation,false,int(item.get("style",0)),growth) if building_phase in [-1,4] else Node3D.new()
		if building_phase>=0: construction_site(root,item,building_phase)
		root.set_meta("building",building_phase>=0)
		prop_root.add_child(root)
		root.position=HomesteadItems.item_center(item)
		root.set_meta("item_id",item.id)
		if item.kind=="cottage" and data.approvals>=34:
			for x in [-1.4,1.4]:
				HomesteadMesh.box(root,Vector3(x,1.5,1.35),Vector3(0.18,0.28,0.18),"edc577",0.03)
		for pivot in sails.slice(sails_start): pivot.set_meta("item_id",item.id)
		var own_pets: Array[Node3D]=[]
		for part in root.find_children("*","Node3D",true,false):
			if part.has_meta("pet_motion"): own_pets.append(part)
		pet_parts.append_array(own_pets)
		root.set_meta("pet_parts",own_pets)
		var animated: Array[Node3D]=[]
		animated.append_array(foliage)
		animated.append_array(sails)
		animated.append_array(pet_parts)
		# Job-driven visibility needs its own batching boundary, like animation.
		for group_name in ["CookingFood","WarmCoals","SeatBook"]:
			var group=root.find_child(group_name,true,false)
			if group:
				animated.append(group)
				if group_name=="SeatBook": root.set_meta("seat_book",group)
		if root.has_meta("build_tool"): animated.append(root.get_meta("build_tool"))
		HomesteadStaticBatcher.consolidate(root,animated)
		nodes[item.id]=root
		var size=HomesteadItems.footprint(item.kind,item.rotation)
		var body=StaticBody3D.new()
		root.add_child(body)
		body.set_meta("item_id",item.id)
		body.collision_layer=1
		body.collision_mask=0
		var collider=CollisionShape3D.new()
		body.add_child(collider)
		var shape=BoxShape3D.new()
		var height=HomesteadItems.DEFINITIONS[item.kind].height
		if item.kind=="tree" and item.id==data.growth_tree_id: height=1.4 if tree_wins<3 else 2.4 if tree_wins<13 else 3.6
		shape.size=Vector3(size.x,height,size.y)
		collider.shape=shape
		collider.position.y=shape.size.y/2
		root.set_meta("art_signature",signature)
		root.set_meta("foliage",foliage.slice(foliage_start))
		root.set_meta("waters",waters.slice(waters_start))
		root.set_meta("sails",sails.slice(sails_start))
		if completed and not reduced_motion: reveal_finished(root,size)
	visual_revision+=1
	refresh_grid()

# Owned regions form one surface: there is no colored tile or raised seam at
# purchase boundaries. The shader samples world coordinates across all land.
func land_outline(bounds: Rect2i) -> PackedVector2Array:
	var corner=HomesteadItems.cell_center(bounds.position)-Vector3(0.5,0,0.5)
	return PackedVector2Array([Vector2(corner.x,corner.z),Vector2(corner.x+bounds.size.x,corner.z),Vector2(corner.x+bounds.size.x,corner.z+bounds.size.y),Vector2(corner.x,corner.z+bounds.size.y)])

func terrain_surface(parent: Node3D, outline: PackedVector2Array, dormant=false):
	# The valley already supplies the ground beneath every region. Extra soil
	# slabs formed beige outlines that made the mainland look like cut-out tiles.
	var lawn=HomesteadMesh.polygon_slab(parent,outline,0.018,-0.06,"a9ba89",false)
	# A top-only turf surface receives building shadows without casting an
	# artificial platform edge onto the surrounding valley.
	lawn.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var grass=ShaderMaterial.new()
	grass.shader=preload("res://scripts/meadow.gdshader")
	grass.set_shader_parameter("dormant",1.0 if dormant else 0.0)
	lawn.material_override=grass
	lawn.set_meta("continuous_grass",true)
	lawn.set_meta("ground_outline",outline)

func build_island():
	var clearing=Node3D.new()
	clearing.name="StartingLand"
	land_root.add_child(clearing)
	var outline=land_outline(HomesteadItems.BASE_BOUNDS)
	var additions: Array[PackedVector2Array]=[]
	if data.edges:
		# Ground, necks and resource scenery share one slab: no floating islands
		# or internal raised rims. This is scenery, not extra purchasable cells.
		for producer in HomesteadItems.EDGE_CENTERS:
			var center=HomesteadItems.EDGE_CENTERS[producer]
			var neck=Rect2(-12.0 if producer=="woods" else 10.8,5.1,3.2,5.8)
			additions.append(PackedVector2Array([neck.position,Vector2(neck.end.x,neck.position.y),neck.end,Vector2(neck.position.x,neck.end.y)]))
			var edge_outline=HomesteadMesh.rounded_outline(HomesteadItems.EDGE_SIZE.x,HomesteadItems.EDGE_SIZE.y,1.6)
			for i in edge_outline.size(): edge_outline[i]+=Vector2(center.x,center.z)
			additions.append(edge_outline)
	for side in data.land_sides: additions.append(land_outline(HomesteadItems.LAND_BOUNDS[side]))
	for addition in additions:
		var merged=Geometry2D.merge_polygons(outline,addition)
		if merged.size()==1: outline=merged[0]
	# Round only the outside shoreline, never the former purchase seams.
	for inset in Geometry2D.offset_polygon(outline,-0.16,Geometry2D.JOIN_ROUND):
		for softened in Geometry2D.offset_polygon(inset,0.16,Geometry2D.JOIN_ROUND):
			terrain_surface(clearing,softened)
	# Locked land stays distinct and unbuildable; purchasing joins it seamlessly.
	for side in HomesteadItems.LAND_CENTERS:
		var available=side in data.land_sides
		var patch=Node3D.new()
		patch.name="Land_"+side
		patch.set_meta("available",available)
		land_root.add_child(patch)
		patch.position=HomesteadItems.LAND_CENTERS[side]
		if side=="east": beach_cove(patch,not available)
		if available:
			if side=="west": meadow_border(patch)
			if side=="east": waterside_bank(patch)
		else:
			terrain_surface(patch,HomesteadMesh.rounded_outline(12.0,12.0,0.14),true)
			var gate=Node3D.new()
			patch.add_child(gate)
			gate.position=Vector3(0,0,5.85) if side=="north" else Vector3(-5.85 if side=="east" else 5.85,0,0)
			gate.rotation.y=0 if side=="north" else PI/2
			for x in [-1.0,0,1.0]:
				HomesteadMesh.box(gate,Vector3(x,0.39,0),Vector3(0.10,0.78,0.10),"a18b6b",0.025)
			for y in [0.29,0.60]:
				HomesteadMesh.box(gate,Vector3(0,y,0),Vector3(2.2,0.10,0.09),"b8a482",0.025)
			if side=="north": mountain_ridge(patch)
			elif side=="west": future_meadow(patch)
			else:
				for point in [Vector2(-3.1,-2.3),Vector2(2.7,-1.8),Vector2(-1.8,3.2)]:
					HomesteadMesh.ellipsoid(patch,Vector3(point.x,0.12,point.y),Vector3(0.5,0.22,0.4),"7e8b6e")
		HomesteadStaticBatcher.consolidate(patch,[])
	if data.edges:
		woods_edge()
		quarry_edge()

func edge_patch(producer: String) -> Node3D:
	var patch=Node3D.new()
	patch.name="Edge_"+producer
	land_root.add_child(patch)
	patch.position=HomesteadItems.EDGE_CENTERS[producer]
	var body=StaticBody3D.new()
	patch.add_child(body)
	body.set_meta("producer_id",producer)
	body.collision_layer=1
	body.collision_mask=0
	var collider=CollisionShape3D.new()
	body.add_child(collider)
	var shape=BoxShape3D.new()
	shape.size=Vector3(HomesteadItems.EDGE_SIZE.x,2.6,HomesteadItems.EDGE_SIZE.y)
	collider.shape=shape
	collider.position.y=1.3
	return patch

func woods_edge():
	# A small stand of trees and a log pile: the woods make wood.
	var patch=edge_patch("woods")
	var spots=[Vector3(-2.6,0,-1.8),Vector3(-0.9,0,-2.3),Vector3(1.0,0,-1.9),Vector3(2.7,0,-1.2),Vector3(-2.9,0,0.6),Vector3(2.9,0,1.3),Vector3(-1.6,0,2.0)]
	for i in spots.size():
		var holder=Node3D.new()
		patch.add_child(holder)
		holder.position=spots[i]
		holder.scale=Vector3(1.45,1,1.45)*(0.85+0.12*(i%3))
		holder.rotation.y=i*1.3
		tree(holder,false,i%3)
	var pile=Node3D.new()
	patch.add_child(pile)
	pile.position=Vector3(0.3,0,0.9)
	HomesteadHarvestCraft.attach(pile,"WoodPile")
	HomesteadMesh.box(pile,Vector3(1.1,0.22,0.25),Vector3(0.5,0.44,0.5),"8b6a4e",0.05)
	HomesteadMesh.rod(pile,Vector3(1.05,0.44,0.25),Vector3(1.25,0.95,0.15),0.03,"a47c58")
	HomesteadMesh.box(pile,Vector3(1.28,0.98,0.14),Vector3(0.24,0.12,0.05),"9aa3a0",0.02)
	HomesteadStaticBatcher.consolidate(patch,[])

func quarry_edge():
	# A low cliff of pale rock with cut blocks: the quarry makes stone.
	var patch=edge_patch("quarry")
	var boulders=[[Vector3(-2.2,0.55,-1.9),Vector3(1.3,0.9,1.0),"a7afa2"],[Vector3(-0.4,0.75,-2.2),Vector3(1.4,1.15,1.0),"b5bcae"],[Vector3(1.6,0.6,-2.0),Vector3(1.2,0.85,0.95),"9ea69a"],[Vector3(2.9,0.4,-0.9),Vector3(0.8,0.6,0.8),"b0b7a9"],[Vector3(-3.0,0.35,0.4),Vector3(0.7,0.45,0.6),"a3ab9e"]]
	for spec in boulders:
		var rock=HomesteadMesh.ellipsoid(patch,spec[0],spec[1],spec[2])
		rock.rotation.y=spec[0].x*0.7
	for i in 4:
		HomesteadMesh.box(patch,Vector3(-0.8+i*0.55,0.2,0.6+(i%2)*0.3),Vector3(0.48,0.4,0.4),"c9ccc0" if i%2 else "bfc3b6",0.04)
	HomesteadMesh.box(patch,Vector3(-0.53,0.6,0.75),Vector3(0.48,0.4,0.4),"d1d3c8",0.04)
	HomesteadMesh.rod(patch,Vector3(1.6,0.0,1.4),Vector3(1.9,0.9,1.2),0.035,"a47c58")
	HomesteadMesh.ellipsoid(patch,Vector3(1.95,0.95,1.2),Vector3(0.16,0.1,0.08),"8b9391")
	HomesteadStaticBatcher.consolidate(patch,[])

func harvest_anchor(key: String) -> Variant:
	if HomesteadItems.EDGE_CENTERS.has(key): return HomesteadItems.EDGE_CENTERS[key]+Vector3(0,3.9 if key=="woods" else 3.0,0)
	if key=="waterside": return HomesteadItems.LAND_CENTERS.east+Vector3(0,1.6,-3.6)
	if nodes.has(key):
		var item=data.find(key)
		if item.is_empty(): return null
		var height: float=HomesteadItems.DEFINITIONS[item.kind].height
		return HomesteadItems.item_center(item)+Vector3(0,height+1.0,0)
	return null

# Bubbles mirror the host's ready materials; tapping one routes like its place.
func update_harvest():
	update_production()
	var anchors={}
	for key in data.harvest: anchors[key]=harvest_anchor(key)
	var signature=JSON.stringify([data.harvest,anchors])
	if signature==harvest_signature: return
	var first=harvest_signature==""
	harvest_signature=signature
	var previous={}
	for bubble in bubbles:
		var key=str(bubble.get_meta("producer_key",""))
		previous[key]=true
		if not data.harvest.has(key) and collecting.has(key): fly_to_wallet(bubble)
		else:
			harvest_root.remove_child(bubble)
			bubble.queue_free()
	bubbles.clear()
	collecting.clear()
	for key in data.harvest:
		var anchor=harvest_anchor(key)
		if anchor==null: continue
		var bubble=Node3D.new()
		harvest_root.add_child(bubble)
		bubble.position=anchor
		bubble.set_meta("anchor",anchor)
		bubble.set_meta("producer_key",key)
		bubble.set_meta("marker_place_id",key)
		bubble.set_meta("marker_role","material")
		var quad=QuadMesh.new()
		quad.size=Vector2.ONE
		var face=MeshInstance3D.new()
		face.mesh=quad
		face.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material=ShaderMaterial.new()
		material.shader=BUBBLE_SHADER
		material.set_shader_parameter("kind",["wood","stone","food","wheat"].find(data.harvest[key]))
		face.material_override=material
		bubble.add_child(face)
		var body=StaticBody3D.new()
		bubble.add_child(body)
		if nodes.has(key): body.set_meta("item_id",key)
		else: body.set_meta("producer_id",key)
		body.collision_layer=1
		body.collision_mask=0
		var collider=CollisionShape3D.new()
		var sphere=SphereShape3D.new()
		sphere.radius=0.76
		collider.shape=sphere
		body.add_child(collider)
		bubbles.append(bubble)
		if not first and not previous.has(key) and not reduced_motion: pop_in(face)

# Cached badges change uniforms, not island geometry, on the host's one-second tick.
func place_ovens(centers: Dictionary):
	for id in ovens.keys():
		if not centers.has(id):
			remove_child(ovens[id])
			ovens[id].queue_free()
			ovens.erase(id)
	for id in centers:
		if not ovens.has(id):
			var oven=HomesteadOutdoorOven.new()
			oven.name="OutdoorOven"
			add_child(oven)
			oven.body.set_meta("oven_place_id",id)
			ovens[id]=oven
		ovens[id].position=centers[id]
		var item=data.find(id)
		ovens[id].rotation.y=item.rotation*PI/2
	update_production()
# The extended house (A70): the kitchen bench packs meals beside the cottage,
# and a porch shelters the front door once the house starts cooking.
func place_kitchens(centers: Dictionary):
	for table in [kitchens,porches]:
		for id in table.keys():
			if not centers.has(id):
				remove_child(table[id]); table[id].queue_free(); table.erase(id)
	for id in centers:
		var item=data.find(id)
		if item.is_empty(): continue
		if not kitchens.has(id):
			var bench=Node3D.new(); bench.name="KitchenBench"
			bench.add_child(KITCHEN_MODEL.instantiate())
			var body=StaticBody3D.new(); body.collision_layer=1; body.collision_mask=0
			body.set_meta("production_station","pantry"); body.set_meta("oven_place_id",id)
			var shape=CollisionShape3D.new(); var box=BoxShape3D.new(); box.size=Vector3(1.86,2.4,1.62)
			shape.shape=box; shape.position.y=1.2; body.add_child(shape); bench.add_child(body)
			add_child(bench); kitchens[id]=bench
		kitchens[id].position=centers[id]
		kitchens[id].rotation.y=item.rotation*PI/2
		if not porches.has(id):
			var porch=PORCH_MODEL.instantiate(); porch.name="FrontPorch"; porch.scale=Vector3.ONE*0.82
			add_child(porch); porches[id]=porch
		porches[id].position=HomesteadItems.item_center(item)+Vector3(0,0,1.95).rotated(Vector3.UP,item.rotation*PI/2)
		porches[id].rotation.y=item.rotation*PI/2
	update_production()
func oven_marker(id: String) -> Vector3:
	return ovens[id].position+Vector3(0,1.15,1.85)

func update_production():
	for item in data.items:
		if item.kind=="grill" and nodes.has(item.id): HomesteadFarmBuildingArt.set_grill_status(nodes[item.id],0)
	var present={}
	for status in data.production:
		var anchor=harvest_anchor(status.placeID)
		if anchor==null: continue
		present[status.station]=true
		var bubble: Node3D=production_nodes.get(status.station)
		if not is_instance_valid(bubble):
			bubble=make_status_bubble()
			production_nodes[status.station]=bubble
			bubble.get_meta("body").set_meta("production_station",status.station)
		var offset=0.0
		if status.station in ["oven","pantry"]: offset=-1.0 if status.station=="oven" else 1.0
		var camera=get_viewport().get_camera_3d()
		var point=anchor+(camera.global_basis.x if camera else Vector3.RIGHT)*offset
		bubble.set_meta("marker_anchor",point)
		bubble.set_meta("marker_place_id",status.placeID)
		bubble.set_meta("marker_role",status.station)
		if not bubble.has_meta("marker_placed"): bubble.position=point
		# A finished job pops its product up on the map, so it is seen from anywhere.
		var was=int(bubble.get_meta("state",-1))
		bubble.set_meta("state",int(status.state))
		if int(status.state)==2 and was!=-1 and was!=2 and not reduced_motion: pop_in(bubble.get_child(0))
		var material: ShaderMaterial=bubble.get_meta("material")
		material.set_shader_parameter("kind",(9 if status.good=="meat" else ["wood","stone","fruit","wheat","flour","bread","meal","tart"].find(status.good)))
		material.set_shader_parameter("production_state",status.state)
		material.set_shader_parameter("progress",status.progress)
		material.set_shader_parameter("sample_time",fmod(Time.get_ticks_msec()/1000.0,3600.0))
		material.set_shader_parameter("progress_rate",(1.0-status.progress)/maxf(1.0,status.remaining))
		material.set_shader_parameter("smooth_progress",not reduced_motion)
		material.set_shader_parameter("shows_product",PRODUCT_ART.has(status.good))
		if PRODUCT_ART.has(status.good): material.set_shader_parameter("product",PRODUCT_ART[status.good])
		material.set_shader_parameter("lively",not reduced_motion)
		var label: Label3D=bubble.get_meta("label")
		# The product fills the face, so the countdown sits just beneath it.
		label.position.y=-0.62 if PRODUCT_ART.has(status.good) else 0.0
		label.text=countdown(int(status.remaining)) if status.state==1 else ""

		if status.station=="grill" and nodes.has(status.placeID):
			HomesteadFarmBuildingArt.set_grill_status(nodes[status.placeID],status.state)
		if status.station=="oven":
			var outdoor: HomesteadOutdoorOven=ovens.get(status.placeID)
			if is_instance_valid(outdoor): outdoor.update_status(status)
			var loaf: Node3D=ready_goods.get(status.station)
			if not is_instance_valid(loaf):
				loaf=HomesteadHarvestCraft.attach(production_root,"Bread")
				HomesteadMesh.box(loaf,Vector3(0,-0.012,0),Vector3(0.72,0.035,0.34),"b99565",0.025)
				ready_goods[status.station]=loaf
			var bakery=data.find(status.placeID)
			loaf.position=HomesteadItems.item_center(bakery)+Vector3(1.15,0.32,1.47).rotated(Vector3.UP,int(bakery.rotation)*PI/2)
			loaf.rotation.y=int(bakery.rotation)*PI/2
			loaf.visible=not is_instance_valid(outdoor) and status.good=="bread" and status.state==2
		# Baking has a quiet physical cue at the authored chimney; packing at the porch.
		if status.station in ["oven","pantry","barn","grill"]:
			var effect: Node3D=production_effects.get(status.station)
			if not is_instance_valid(effect):
				effect=Node3D.new()
				production_root.add_child(effect)
				production_effects[status.station]=effect
				if status.station in ["oven","grill","pantry"]:
					for i in 3:
						var puff=HomesteadMesh.ellipsoid(effect,Vector3.ZERO,Vector3.ONE*0.11,"f5ead3")
						puff.material_override=HomesteadMesh.transparent(Color(0.97,0.93,0.84,0.36))
						puff.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				elif status.station=="barn":
					HomesteadMesh.box(effect,Vector3.ZERO,Vector3(0.55,0.14,0.32),"98764f",0.025)
					HomesteadMesh.box(effect,Vector3(0,0.075,0),Vector3(0.46,0.025,0.24),"d9b76c",0.02)
					for i in 6:
						HomesteadMesh.ellipsoid(effect,Vector3(-0.16+float(i%3)*0.14,0.105,-0.06+float(i/3)*0.12),Vector3(0.045,0.025,0.035),"f3d58c")
			var item=data.find(status.placeID)
			var local=Vector3(0.96,4.13,-0.56) if status.station=="oven" else Vector3(-0.25,1.2,0.15) if status.station=="grill" else Vector3(-1.25,0.3,1.1) if status.station=="barn" else Vector3(-0.65,0.55,1.45)
			effect.position=HomesteadItems.item_center(item)+local.rotated(Vector3.UP,int(item.rotation)*PI/2)
			if status.station=="oven" and ovens.has(status.placeID):
				effect.position=ovens[status.placeID].to_global(Vector3(-0.40,2.17,-0.37))
			# The kitchen bench steams from its copper kettle's spout.
			if status.station=="pantry" and kitchens.has(status.placeID):
				effect.position=kitchens[status.placeID].to_global(Vector3(0.80,1.16,-0.46))
				effect.scale=Vector3.ONE*0.6
			effect.set_meta("working",status.state==1)
	for station in production_nodes.keys():
		if not present.has(station):
			# A collected product flies to the warehouse; anything else simply leaves.
			if int(production_nodes[station].get_meta("state",-1))==2: fly_to_wallet(production_nodes[station],warehouse_point)
			else:
				production_root.remove_child(production_nodes[station])
				production_nodes[station].queue_free()
			production_nodes.erase(station)
			if ready_goods.has(station):
				ready_goods[station].queue_free()
				ready_goods.erase(station)
			if production_effects.has(station):
				production_root.remove_child(production_effects[station])
				production_effects[station].queue_free()
				production_effects.erase(station)
	for id in ovens:
		if not data.production.any(func(status): return status.station=="oven" and status.placeID==id): ovens[id].update_status({})
	update_construction()
	update_livestock_growth()
	update_production_effects()

func update_livestock_growth():
	# Apply saved growth on snapshots even when Reduce Motion pauses processing.
	var growth=0.0
	for status in data.production:
		if status.station=="barn": growth=status.progress if status.state==1 else 1.0 if status.state==2 else 0.0
	for part in pet_parts:
		if is_instance_valid(part) and part.get_meta("livestock",false):
			# Collection starts the next young flock, without a slaughter scene.
			part.scale=Vector3.ONE*lerpf(0.60,0.90,clampf(growth,0.0,1.0))

func countdown(seconds: int) -> String:
	return "%d:%02d" % [maxi(0,seconds)/60,maxi(0,seconds)%60]

func make_status_bubble() -> Node3D:
	var bubble=Node3D.new()
	production_root.add_child(bubble)
	var face=MeshInstance3D.new()
	var quad=QuadMesh.new()
	quad.size=Vector2.ONE
	face.mesh=quad
	face.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material=ShaderMaterial.new()
	material.shader=BUBBLE_SHADER
	material.set_shader_parameter("sun_track",preload("res://assets/time/WorldTimeRing.png"))
	material.set_shader_parameter("sun_waiting",preload("res://assets/time/WorldTimeWaiting.png"))
	material.set_shader_parameter("sun_bloom",preload("res://assets/time/WorldTimeBloom.png"))
	face.material_override=material
	bubble.add_child(face)
	bubble.set_meta("material",material)
	var body=StaticBody3D.new()
	body.collision_layer=1
	body.collision_mask=0
	var collider=CollisionShape3D.new()
	var sphere=SphereShape3D.new()
	sphere.radius=0.76
	collider.shape=sphere
	body.add_child(collider)
	bubble.add_child(body)
	bubble.set_meta("body",body)
	var label=Label3D.new()
	label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size=40
	label.pixel_size=0.0046
	label.modulate=Color("263e32")
	label.outline_modulate=Color("fff3d9")
	label.outline_size=0
	# Badge text is a world-space annotation, above its transparent plate.
	# A global Z offset alone can lose the depth comparison at gameplay pitch.
	label.no_depth_test=true
	label.render_priority=1
	label.position.y=0.0
	label.position.z=0.015
	bubble.add_child(label)
	bubble.set_meta("label",label)
	return bubble

func update_construction():
	var present={}
	for build in data.construction:
		present[build.placeID]=true
		var bubble: Node3D=construction_nodes.get(build.placeID)
		if not is_instance_valid(bubble):
			bubble=make_status_bubble()
			bubble.get_meta("body").set_meta("construction_id",build.placeID)
			construction_nodes[build.placeID]=bubble
		var item=data.find(build.placeID)
		var phase=int(floor(clampf(build.progress,0.0,0.999)*5.0))
		var height=1.15+float(phase)*0.38
		var anchor=HomesteadItems.item_center(item)+Vector3(0,height,0)
		bubble.set_meta("marker_anchor",anchor)
		bubble.set_meta("marker_place_id",build.placeID)
		bubble.set_meta("marker_role","construction")
		if not bubble.has_meta("marker_placed"): bubble.position=anchor
		var material: ShaderMaterial=bubble.get_meta("material")
		material.set_shader_parameter("kind",8)
		material.set_shader_parameter("production_state",2 if build.remaining<=0 else 1)
		material.set_shader_parameter("progress",build.progress)
		material.set_shader_parameter("sample_time",fmod(Time.get_ticks_msec()/1000.0,3600.0))
		material.set_shader_parameter("progress_rate",(1.0-build.progress)/maxf(1.0,build.remaining))
		material.set_shader_parameter("smooth_progress",not reduced_motion)
		bubble.get_meta("label").text=countdown(build.remaining) if build.remaining>0 else ""
	for id in construction_nodes.keys():
		if not present.has(id):
			production_root.remove_child(construction_nodes[id])
			construction_nodes[id].queue_free()
			construction_nodes.erase(id)

func construction_site(root: Node3D,item: Dictionary,phase: int):
	var size=HomesteadItems.footprint(item.kind,item.rotation)
	var width=float(size.x)*0.47
	var depth=float(size.y)*0.47
	var post_h=0.42 if phase<=0 else 0.85 if phase==1 else minf(2.15,HomesteadItems.DEFINITIONS[item.kind].height*0.55+0.45)
	if phase<4:
		HomesteadMesh.box(root,Vector3(0,0.06,0),Vector3(size.x,0.12,size.y),"c8baa0",0.06)
	if phase==0:
		for i in 4:
			HomesteadMesh.box(root,Vector3(-width*0.7+i*width*0.46,0.22,depth-0.22),Vector3(0.08,0.32,0.08),"9b7a53",0.01)
	if phase>=1 and phase<4:
		for x in [-width,width]:
			for z in [-depth,depth]:
				HomesteadMesh.box(root,Vector3(x,post_h/2.0,z),Vector3(0.09,post_h,0.09),"9b7a53",0.015)
	if phase>=2 and phase<4:
		for z in [-depth,depth]:
			HomesteadMesh.box(root,Vector3(0,post_h,z),Vector3(width*2.0+0.12,0.1,0.12),"c8a674",0.02)
			HomesteadMesh.rod(root,Vector3(-width,0.25,z),Vector3(width,post_h,z),0.035,"c8a674")
		for x in [-width,width]:
			HomesteadMesh.box(root,Vector3(x,post_h*0.62,0),Vector3(0.1,0.1,depth*2.0),"d3b783",0.02)
	if phase==3:
		HomesteadMesh.box(root,Vector3(0,0.48,0),Vector3(maxf(0.4,width*1.5),0.72,maxf(0.4,depth*1.5)),"e4d2b0",0.04)
	if phase>=4:
		for x in [-width,width]:
			HomesteadMesh.box(root,Vector3(x,0.9,depth+0.16),Vector3(0.08,1.7,0.08),"9b7a53",0.01)
	var tool=Node3D.new()
	root.add_child(tool)
	tool.position=Vector3(width-0.2,0.55+float(mini(phase,3))*0.15,depth+0.12)
	HomesteadMesh.box(tool,Vector3(0,0.18,0),Vector3(0.06,0.4,0.06),"9b7047",0.01)
	HomesteadMesh.box(tool,Vector3(0,0.4,0),Vector3(0.3,0.1,0.12),"718077",0.02)
	root.set_meta("build_tool",tool)

func reveal_finished(root: Node3D,size: Vector2i):
	if root.get_child_count()>0:
		var art=root.get_child(0)
		art.scale=Vector3.ONE*0.96
		create_tween().tween_property(art,"scale",Vector3.ONE,0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var halo=HomesteadMesh.cylinder(root,Vector3(0,0.025,0),maxf(size.x,size.y)*0.62,0.01,"e7c984")
	halo.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	halo.material_override=HomesteadMesh.transparent(Color(0.91,0.78,0.49,0.25))
	var tween=create_tween().set_parallel(true)
	tween.tween_property(halo,"scale",Vector3(1.18,1,1.18),0.65)
	tween.tween_property(halo.material_override,"albedo_color:a",0.0,0.65)
	tween.chain().tween_callback(halo.queue_free)

# A ready mill rests until its flour is collected.
func station_ready(station: String) -> bool:
	for status in data.production:
		if status.station==station: return status.state==2
	return false

func station_working(station: String) -> bool:
	for status in data.production:
		if status.station==station: return status.state==1
	return false

func update_production_effects():
	for station in production_effects:
		var effect: Node3D=production_effects[station]
		effect.visible=effect.get_meta("working",false) and (station=="barn" or not reduced_motion)
		if station=="barn": continue
		for i in effect.get_child_count():
			var phase=fmod(clock*0.32+float(i)/3.0,1.0)
			var puff: Node3D=effect.get_child(i)
			puff.position=Vector3(sin(phase*PI)*0.13,phase*0.85,0)
			puff.scale=Vector3.ONE*sin(phase*PI)*0.12

func make_item(kind: String,rotation: int,ghost=false,style=0,growth=-1) -> Node3D:
	var root=Node3D.new()
	var art=Node3D.new()
	root.add_child(art)
	art.rotation.y=rotation*PI/2
	match kind:
		"barn": barn(art)
		"doghouse": doghouse(art)
		"grill": grill(art)
		"windmill": windmill(art,ghost,style)
		"orchard": orchard(art,style)
		"greenhouse": greenhouse(art)
		"workshop": workshop(art)
		"cottage": cottage(art)
		"garden": garden(art)
		"pond": pond(art,ghost,style)
		"bench": bench(art)
		"tree": mission_tree(art,ghost,growth,growth_fill(max(0,data.approvals-pending_tree_growth)),yellow_leaves) if growth>=0 else tree(art,ghost)
		"flowers": flowers(art,ghost)
		"rocks": rocks(art)
		"nook": reading_nook(art,style)
		"treehouse": treehouse(art,style,ghost)
		"path": path_tile(art)
	if kind in ["cottage","garden","tree","bench","nook","treehouse","workshop","greenhouse","orchard","windmill","barn","doghouse","grill"]:
		var size: Vector2i=HomesteadItems.DEFINITIONS[kind].size
		HomesteadMesh.contact_shadow(art,Vector2(size)*1.2)
	return root

func cottage(root: Node3D):
	# Reproducible, original authored model; same footprint/identity as before.
	var scene=preload("res://assets/cottage/cozy_cottage.glb").instantiate()
	root.add_child(scene)
	prepare_cottage_materials(scene)

func prepare_cottage_materials(node: Node):
	if node is MeshInstance3D and node.mesh.get_surface_count()==1:
		var material=node.get_active_material(0)
		if material is StandardMaterial3D:
			var copy=material.duplicate()
			if str(copy.resource_name).begins_with("roof"):
				copy.albedo_color=copy.albedo_color.lerp(Color("e4532a"),0.45)
			node.material_override=copy
			node.set_meta("cottage_roof",str(copy.resource_name).begins_with("roof"))
	for child in node.get_children(): prepare_cottage_materials(child)

# Original miniature joinery, open front and paper details stay readable from
# the normal landscape camera. The footprint is the same authoritative 3x3.
func workshop(root: Node3D):
	HomesteadMesh.box(root,Vector3(0,0.08,0),Vector3(2.78,0.16,2.65),"c8b18a",0.10)
	for i in 8:
		HomesteadMesh.box(root,Vector3(-1.15+i*0.33,0.18,0),Vector3(0.31,0.08,2.45),"d8c09a",0.025)
	for x in [-1.18,1.18]:
		for z in [-1.03,0.98]:
			HomesteadMesh.box(root,Vector3(x,1.18,z),Vector3(0.14,2.1,0.14),"a48360",0.035)
	for i in 7:
		HomesteadMesh.box(root,Vector3(0,0.42+i*0.23,-1.05),Vector3(2.36,0.21,0.10),"d3bd96" if i%2 else "c9af87",0.02)
	for x in [-0.69,0.69]:
		var roof=HomesteadMesh.box(root,Vector3(x,2.34,0),Vector3(1.53,0.12,2.85),"78978b",0.045)
		roof.rotation.z=0.32 if x<0 else -0.32
	HomesteadMesh.rod(root,Vector3(0,2.57,-1.39),Vector3(0,2.57,1.39),0.07,"a8bdad")
	# Cream valance and brass badge frame the open work area.
	HomesteadMesh.box(root,Vector3(0,2.04,1.08),Vector3(2.32,0.22,0.08),"eee1c3",0.035)
	HomesteadMesh.cylinder(root,Vector3(0,2.03,1.15),0.13,0.045,"c6a15e").rotation.x=PI/2
	for x in [-0.79,0.79]:
		for z in [-0.12,0.61]:
			HomesteadMesh.box(root,Vector3(x,0.61,z),Vector3(0.10,0.84,0.10),"967554",0.02)
	HomesteadMesh.box(root,Vector3(0,1.04,0.23),Vector3(2.02,0.14,1.02),"c59970",0.05)
	HomesteadMesh.box(root,Vector3(0,1.12,0.26),Vector3(1.1,0.018,0.68),"eee3c9",0.01)
	# A folded bird, pencil cup and little tool rack make it a maker's place.
	var wing=HomesteadMesh.box(root,Vector3(0,1.20,0.29),Vector3(0.48,0.035,0.34),"c58f73",0.012)
	wing.rotation.z=0.18
	HomesteadMesh.rod(root,Vector3(-0.23,1.17,0.29),Vector3(0.29,1.27,0.20),0.035,"e7c2a1")
	HomesteadMesh.cylinder(root,Vector3(0.73,1.23,0.04),0.12,0.28,"88a195")
	for i in 3:
		HomesteadMesh.rod(root,Vector3(0.67+i*0.06,1.24,0.04),Vector3(0.64+i*0.08,1.58,0.06),0.018,"cba46d")
	HomesteadMesh.box(root,Vector3(0,1.52,-0.94),Vector3(1.58,0.58,0.05),"83998a",0.035)
	for x in [-0.47,0,0.47]:
		HomesteadMesh.rod(root,Vector3(x,1.34,-0.88),Vector3(x,1.68,-0.88),0.025,"dec49b")
		HomesteadMesh.box(root,Vector3(x,1.68,-0.88),Vector3(0.18,0.07,0.08),"bea06b",0.02)
	HomesteadMesh.cylinder(root,Vector3(-0.95,0.48,1.06),0.24,0.49,"dfc79e",0.29)

# Original plaster-and-joinery mill, including two free material/sail looks.
# The animated pivot survives static batching; quiet/offscreen mills do no work.
func windmill(root: Node3D,ghost=false,style=0):
	var model=HomesteadFarmBuildingArt.attach(root,"windmill",style)
	var rotor=model.find_child("Rotor",true,false)
	rotor.rotation.z=0.22
	if not ghost: sails.append(rotor)

func greenhouse(root: Node3D):
	HomesteadMesh.box(root,Vector3(0,0.09,0),Vector3(2.82,0.18,1.84),"cbbb9d",0.08)
	var glass=HomesteadMesh.transparent(Color(0.65,0.84,0.80,0.20))
	for x in [-1.28,1.28]:
		for z in [-0.79,0.79]:
			HomesteadMesh.box(root,Vector3(x,1.05,z),Vector3(0.10,1.86,0.10),"6c9183",0.025)
		for z in [-0.38,0.34]:
			var pane=HomesteadMesh.box(root,Vector3(x,1.15,z),Vector3(0.025,1.53,0.68),"cde4d5",0.003)
			pane.material_override=glass
	for z in [-0.81,0.81]:
		HomesteadMesh.box(root,Vector3(0,1.97,z),Vector3(2.67,0.10,0.10),"6c9183",0.02)
		for x in [-0.87,0,0.87]:
			HomesteadMesh.rod(root,Vector3(x,1.99,z),Vector3(0,2.58,z),0.035,"89aa98")
	for side in [-1,1]:
		var roof=HomesteadMesh.box(root,Vector3(side*0.66,2.28,0),Vector3(1.47,0.025,1.81),"cde4d5",0.005)
		roof.rotation.z=-side*0.43
		roof.material_override=glass
		for z in [-0.86,0,0.86]:
			HomesteadMesh.rod(root,Vector3(side*1.33,1.98,z),Vector3(0,2.59,z),0.038,"7a9b8c")
	HomesteadMesh.rod(root,Vector3(0,2.6,-0.9),Vector3(0,2.6,0.9),0.045,"c3aa75")
	# Open central doorway keeps the pots and planting bench readable.
	for x in [-0.47,0.47]:
		HomesteadMesh.box(root,Vector3(x,1.06,0.82),Vector3(0.06,1.76,0.07),"89aa98",0.015)
	HomesteadMesh.box(root,Vector3(0,1.98,0.83),Vector3(0.96,0.12,0.08),"e4d8b9",0.02)
	HomesteadMesh.cylinder(root,Vector3(0,1.99,0.89),0.09,0.03,"c3aa75").rotation.x=PI/2
	HomesteadMesh.box(root,Vector3(0,0.78,-0.48),Vector3(2.34,0.10,0.47),"bea582",0.025)
	for x in [-0.93,0.93]:
		HomesteadMesh.box(root,Vector3(x,0.43,-0.48),Vector3(0.08,0.66,0.08),"8b9980",0.02)
	for i in 3:
		var base=Vector3(-0.78+i*0.78,0.95,-0.47)
		HomesteadMesh.cylinder(root,base,0.18,0.24,"c9987c",0.23)
		HomesteadMesh.torus(root,base+Vector3(0,0.12,0),0.22,0.025,"deb497")
		HomesteadMesh.rod(root,base,base+Vector3(0,0.52,0),0.02,"729176")
		for side in [-1,1]:
			HomesteadMesh.ellipsoid(root,base+Vector3(side*0.10,0.29,0),Vector3(0.14,0.06,0.07),"809e78")
		HomesteadMesh.ellipsoid(root,base+Vector3(0,0.52,0),Vector3(0.12,0.10,0.10),"e4cb8f" if i==0 else "a99dbb" if i==2 else "709873")
	for x in [-0.87,0.87]:
		HomesteadMesh.rod(root,Vector3(x,2.16,-0.18),Vector3(x,1.74,-0.18),0.012,"c8b384")
		HomesteadMesh.cylinder(root,Vector3(x,1.68,-0.18),0.15,0.18,"cfac8a",0.19)
		for leaf in 4:
			HomesteadMesh.ellipsoid(root,Vector3(x+sin(leaf*1.8)*0.14,1.56-leaf*0.07,-0.12),Vector3(0.12,0.09,0.07),"779780")
	HomesteadMesh.cylinder(root,Vector3(0.91,0.34,0.46),0.16,0.31,"8eaaa4")
	HomesteadMesh.rod(root,Vector3(1.02,0.40,0.46),Vector3(1.25,0.58,0.46),0.04,"8eaaa4")
	HomesteadMesh.torus(root,Vector3(0.76,0.38,0.46),0.14,0.025,"c7b783").rotation.x=PI/2

# Two trained fruit trees, low stone edging and a woven harvest basket.
# Three enduring looks are cosmetic; fruit play never changes the ledger.
func orchard(root: Node3D,style=0):
	var leaf_color=["3f9a44","62c452","7aaa4e"][clampi(style,0,2)]
	var fruit_color=["e4543c","f0c22a","9a62d6"][clampi(style,0,2)]
	HomesteadMesh.box(root,Vector3(0,0.06,0),Vector3(1.84,0.12,1.78),"acb18b",0.10)
	for x in [-0.88,0.88]:
		for z in [-0.65,0,0.65]:
			HomesteadMesh.box(root,Vector3(x,0.14,z),Vector3(0.14,0.19,0.58),"c8bda0",0.05)
	for z in [-0.82,0.82]:
		HomesteadMesh.box(root,Vector3(0,0.14,z),Vector3(1.72,0.19,0.14),"c8bda0",0.05)
	for i in 2:
		var base=Vector3(-0.44+i*0.88,0,-0.16+(i%2)*0.3)
		HomesteadMesh.cylinder(root,base+Vector3(0,0.16,0),0.36,0.10,"8b8064")
		HomesteadMesh.rod(root,base+Vector3(0,0.12,0),base+Vector3(0.03,1.99,0),0.065,"a28a65")
		for side in [-1,1]:
			HomesteadMesh.rod(root,base+Vector3(0,1.10,0),base+Vector3(side*0.35,1.70,0.04),0.035,"a28a65")
		for j in 4:
			var crown=base+Vector3(sin(j*2.2)*0.21,1.78+j*0.13,cos(j*2.2)*0.18)
			var leaves=HomesteadMesh.ellipsoid(root,crown,Vector3(0.39,0.44,0.34),leaf_color)
			if data.farm_fruit_stage==1: foliage.append(leaves)
		for j in (6 if data.farm_fruit_stage in [-1,2] else 0):
			var point=base+Vector3(-0.25+(j%3)*0.25,1.62+(j%3)*0.25,0.57 if j<3 else -0.57)
			HomesteadHarvestCraft.attach(root,"Apple",point,Vector3(1,1.2 if style==1 else 1,1),fruit_color if style>0 else "")
		HomesteadMesh.ellipsoid(root,base+Vector3(-0.24,0.25,0.2),Vector3(0.18,0.08,0.14),"889c76")
	# Raised, interlaced basket bands and brass-edged label make the scale readable.
	for i in 5:
		HomesteadMesh.torus(root,Vector3(0,0.22+i*0.035,0.62),0.19,0.018,"c6a477")
	for i in 8:
		var a=i*TAU/8
		HomesteadMesh.rod(root,Vector3(sin(a)*0.17,0.20,0.62+cos(a)*0.17),Vector3(sin(a)*0.20,0.37,0.62+cos(a)*0.20),0.012,"e0c297")
	var handle=HomesteadMesh.torus(root,Vector3(0,0.42,0.62),0.19,0.02,"c6a477")
	handle.rotation.x=PI/2
	for i in 3:
		HomesteadHarvestCraft.attach(root,"Apple",Vector3(-0.10+i*0.10,0.39,0.62),Vector3.ONE*0.53,fruit_color if style>0 else "")
	HomesteadMesh.box(root,Vector3(0.64,0.22,0.77),Vector3(0.24,0.19,0.04),"e5d8b6",0.02)
	HomesteadMesh.ellipsoid(root,Vector3(0.64,0.23,0.80),Vector3(0.045,0.045,0.015),fruit_color)

func meadow_border(root: Node3D):
	# Peripheral planting never occupies or conceals usable expansion cells.
	for i in 12:
		var point=Vector3(-5.5+i,0,6.1 if i%2==0 else -6.1)
		HomesteadMesh.ellipsoid(root,point+Vector3(0,0.12,0),Vector3(0.19,0.13,0.14),"80966e")
		HomesteadMesh.rod(root,point+Vector3(0,0.09,0),point+Vector3(0,0.36,0),0.018,"829774")
		HomesteadMesh.ellipsoid(root,point+Vector3(0,0.38,0),Vector3(0.10,0.06,0.10),"e2c4a3" if i%3 else "bda7b3")

func waterside_bank(root: Node3D):
	# The stream sits outside the 12x12 buildable cells. Its dry bank
	# stays open for walking and future paid places; scenery grants no items.
	var stream=Node3D.new()
	stream.name="WatersideStream"
	root.add_child(stream)
	stream.position=Vector3(0,0,-6.48)
	HomesteadMesh.box(stream,Vector3(0,-0.18,0),Vector3(12.35,0.43,1.02),"c1a785",0.18)
	HomesteadMesh.box(stream,Vector3(0,0.025,0),Vector3(12.15,0.06,0.78),"b7b59a",0.12)
	var water=HomesteadMesh.box(stream,Vector3(0,0.065,0),Vector3(11.95,0.025,0.57),"70abb0",0.10)
	var material=ShaderMaterial.new()
	material.shader=preload("res://scripts/water.gdshader")
	water.material_override=material
	waters.append(material)
	for i in 31:
		var x=-5.88+i*0.39
		for z in [-0.40,0.40]:
			HomesteadMesh.ellipsoid(stream,Vector3(x,0.10,z),Vector3(0.22,0.13,0.12),"c9c7af" if i%3 else "a9b4a1")
	for x in [-1.72,1.65]:
		for i in 4:
			var p=Vector3(x+i*0.055,0.1,-0.40)
			HomesteadMesh.rod(stream,p,p+Vector3(-0.06,0.37+i*0.04,0),0.018,"7a9479")
			HomesteadMesh.ellipsoid(stream,p+Vector3(-0.06,0.47+i*0.04,0),Vector3(0.035,0.09,0.035),"a38b69")
	for x in [-1.0,0.9]:
		var lily=HomesteadMesh.cylinder(stream,Vector3(x,0.09,0),0.13,0.012,"94ab80")
		lily.scale.z=0.75
	# Pale edge markers frame the arrival without placing a paid footbridge.
	for z in [-1.55,1.55]:
		HomesteadMesh.box(root,Vector3(-1.95,0.20,z),Vector3(0.15,0.40,0.15),"d0c2a5",0.04)

func garden(root: Node3D):
	HomesteadHarvestCraft.attach(root,"GardenBeds")
	for x in [-0.72,0.72]:
		var stage=int(data.farm_stages[0 if x<0 else 1]) if data.farm_stages.size()==2 else -1
		if stage==0: continue
		for z in [-0.48,0,0.48]:
			for dx in [-0.24,0.24]:
				var plant=Vector3(x+dx,0.312,z)
				if data.wheat_garden or stage>=1:
					var growth=stage if stage>=1 else 4 if data.harvest.values().has("wheat") else 1
					var stalk=HomesteadHarvestCraft.attach(root,"Wheat%d"%growth,plant)
					if growth>=2: foliage.append(stalk)
				else:
					HomesteadHarvestCraft.attach(root,"Greens",plant)

func pond(root: Node3D,ghost: bool,style=0):
	var model=HomesteadQuietPlaceArt.attach(root,"pond",style)
	for surface in model.find_children("*","MeshInstance3D",true,false):
		if surface.material_override is ShaderMaterial and not ghost: waters.append(surface.material_override)

func bench(root: Node3D):
	for x in [-0.65,0.65]:
		for z in [-0.25,0.25]:
			HomesteadMesh.box(root,Vector3(x,0.27,z),Vector3(0.11,0.54,0.12),"897960",0.025)
		HomesteadMesh.box(root,Vector3(x,0.66,-0.32),Vector3(0.11,0.86,0.11),"897960",0.02)
	for z in [-0.22,0,0.22]:
		HomesteadMesh.box(root,Vector3(0,0.59,z),Vector3(1.8,0.12,0.18),"bb8b62",0.045)
	for y in [0.84,1.05]:
		HomesteadMesh.box(root,Vector3(0,y,-0.32),Vector3(1.8,0.15,0.11),"c49a70",0.045)

func tree(root: Node3D,ghost: bool,variant=0):
	var model=HomesteadLandscapeArt.attach(root,["grove_tree","aspen_tree","pine_tree"][posmod(variant,3)])
	var crown=model.find_child("Crown",true,false)
	if crown and not ghost: foliage.append(crown)

# The mission tree has its own seedling, young, and mature forms. The mature
# canopy keeps its existing overhang; the one-square stem placement never moves.
func growth_fill(wins: int) -> float:
	if wins<3: return clampf(float(wins)/2.0,0.0,1.0)
	if wins<13: return clampf(float(wins-3)/9.0,0.0,1.0)
	return 1.0
func mission_tree(root: Node3D,ghost: bool,stage: int,fill: float,yellow=false):
	var model=HomesteadMissionTree.new()
	model.name="MissionTree"
	root.add_child(model)
	var wins=roundi(fill*2) if stage<=0 else 3+roundi(fill*9) if stage==1 else 13
	model.configure(wins,yellow,reduced_motion,ghost)

func flowers(root: Node3D,ghost: bool):
	var model=HomesteadLandscapeArt.attach(root,"flowers")
	var crown=model.find_child("Crown",true,false)
	if crown and not ghost: foliage.append(crown)

func rocks(root: Node3D):
	HomesteadLandscapeArt.attach(root,"rocks")

func path_tile(root: Node3D):
	HomesteadLandscapeArt.attach(root,"path")
	if data!=null and data.approvals>=55:
		for x in [-0.42,0.42]:
			HomesteadMesh.ellipsoid(root,Vector3(x,0.08,0.25),Vector3(0.05,0.035,0.07),"d8bf7d")

func set_grid_visible(value: bool):
	grid_visible=value
	grid_root.visible=value
	if value: refresh_grid()
func refresh_grid():
	for child in grid_root.get_children():
		grid_root.remove_child(child)
		child.queue_free()
	if not grid_visible: return
	var mat=HomesteadMesh.transparent(Color(0.28,0.4,0.28,0.15))
	var lines=ImmediateMesh.new()
	lines.surface_begin(Mesh.PRIMITIVE_LINES,mat)
	for z in range(HomesteadItems.WORLD_BOUNDS.position.y,HomesteadItems.WORLD_BOUNDS.end.y):
		for x in range(HomesteadItems.WORLD_BOUNDS.position.x,HomesteadItems.WORLD_BOUNDS.end.x):
			var cell=Vector2i(x,z)
			if not data.buildable(cell): continue
			var center=HomesteadItems.cell_center(cell)
			for pair in [[Vector3(-0.5,0.045,-0.5),Vector3(0.5,0.045,-0.5)],[Vector3(-0.5,0.045,-0.5),Vector3(-0.5,0.045,0.5)]]:
				lines.surface_add_vertex(center+pair[0])
				lines.surface_add_vertex(center+pair[1])
	lines.surface_end()
	var node=MeshInstance3D.new()
	node.mesh=lines
	grid_root.add_child(node)
func highlight(cell: Vector2i,size: Vector2i,valid: bool,selected=false):
	# Reuse the same GPU resources for pointer motion and host verdicts.
	if not is_instance_valid(preview_node) or highlight_size!=size:
		if is_instance_valid(preview_node):
			remove_child(preview_node)
			preview_node.queue_free()
		highlight_size=size
		preview_node=Node3D.new()
		add_child(preview_node)
		var plane=PlaneMesh.new()
		plane.size=Vector2(size.x-0.06,size.y-0.06)
		var tile=MeshInstance3D.new()
		tile.mesh=plane
		highlight_fill=HomesteadMesh.transparent(Color.WHITE)
		tile.material_override=highlight_fill
		preview_node.add_child(tile)
		var border=ImmediateMesh.new()
		highlight_border=HomesteadMesh.transparent(Color.WHITE)
		border.surface_begin(Mesh.PRIMITIVE_LINES,highlight_border)
		var hw=size.x/2.0
		var hd=size.y/2.0
		var points=[Vector3(-hw,0.02,-hd),Vector3(hw,0.02,-hd),Vector3(hw,0.02,hd),Vector3(-hw,0.02,hd)]
		for i in 4:
			border.surface_add_vertex(points[i])
			border.surface_add_vertex(points[(i+1)%4])
		border.surface_end()
		var outline=MeshInstance3D.new()
		outline.mesh=border
		preview_node.add_child(outline)
	preview_node.position=HomesteadItems.center(cell,size)+Vector3(0,0.07,0)
	var color=Color("e7ca81") if selected else (Color("72d990") if valid else Color("ef766c"))
	highlight_fill.albedo_color=Color(color,0.58)
	highlight_border.albedo_color=Color(color.r*0.55,color.g*0.55,color.b*0.55,1)
# Keep the authoritative world untouched while the actual piece follows the
# child's pointer. Only the native host can commit this draft.
func preview_object(item: Dictionary,cell: Vector2i,rotation: int):
	if preview_item_id!=item.id or not is_instance_valid(preview_item):
		clear_preview_object()
		preview_item_id=item.id
		var growth=-1
		if item.kind=="tree" and item.id==data.growth_tree_id:
			growth=0 if data.approvals<3 else 1 if data.approvals<13 else 2
		preview_item=make_item(item.kind,rotation,true,int(item.get("style",0)),growth)
		add_child(preview_item)
	if nodes.has(item.id): nodes[item.id].visible=false
	preview_item.position=HomesteadItems.center(cell,HomesteadItems.footprint(item.kind,rotation))+Vector3(0,0.32,0)
	preview_item.get_child(0).rotation.y=rotation*PI/2
func clear_preview_object():
	if nodes.has(preview_item_id): nodes[preview_item_id].visible=true
	if is_instance_valid(preview_item):
		remove_child(preview_item)
		preview_item.queue_free()
	preview_item=null
	preview_item_id=""
# A not-yet-built piece shown where it would first go, before any purchase.
var spot_model: Node3D
func show_spot_model(kind: String,cell: Vector2i):
	clear_spot_model()
	if not HomesteadItems.DEFINITIONS.has(kind): return
	spot_model=make_item(kind,0) # Full colour: the building as it will really look.
	spot_model.position=HomesteadItems.center(cell,HomesteadItems.footprint(kind,0))
	add_child(spot_model)
func clear_spot_model():
	if is_instance_valid(spot_model):
		remove_child(spot_model)
		spot_model.queue_free()
	spot_model=null
func clear_preview():
	clear_preview_object()
	if is_instance_valid(preview_node):
		remove_child(preview_node)
		preview_node.queue_free()
	preview_node=null
# Map bubbles grow a little as the camera pulls back and shrink as it closes in,
# so they stay readable without covering the building at any zoom.
func adapt_marker_scale():
	var camera=get_viewport().get_camera_3d()
	if camera==null: return
	# Nearly constant on screen: zooming in grows badges a little, zooming out shrinks them a little.
	var factor=clampf(pow(camera.size/12.0,0.8),0.5,2.0)
	var target=Vector3.ONE*0.82*factor
	for marker in bubbles+production_nodes.values()+construction_nodes.values():
		if not is_instance_valid(marker): continue
		marker.set_meta("adaptive_scale",true)
		if not marker.scale.is_equal_approx(target): marker.scale=target
func _process(delta):
	adapt_marker_scale()
	if not reduced_motion: clock+=delta
	for build in data.construction:
		if nodes.has(build.placeID):
			var tool=nodes[build.placeID].get_meta("build_tool",null)
			if is_instance_valid(tool): tool.rotation.z=0.0 if reduced_motion else sin(clock*2.4)*0.16
	for i in foliage.size():
		var plant=foliage[i]
		if is_instance_valid(plant): plant.rotation.z=sin(clock*0.8+i*1.7)*0.017 if not reduced_motion else 0
	for pivot in sails:
		if is_instance_valid(pivot) and not reduced_motion and data.building(str(pivot.get_meta("item_id",""))).is_empty() and not station_ready("mill"):
			var camera=get_viewport().get_camera_3d()
			if camera and not camera.is_position_behind(pivot.global_position) and camera.unproject_position(pivot.global_position).x>=0 and get_viewport().get_visible_rect().has_point(camera.unproject_position(pivot.global_position)):
				pivot.rotation.z+=delta*(0.95 if station_working("mill") else 0.14) # milling turns the sails briskly; no smoke
	for part in pet_parts:
		if not is_instance_valid(part): continue
		HomesteadAnimalArt.animate(part,clock,reduced_motion)
	update_production_effects()
	# Ready products bob gently until collected.
	for marker in production_nodes.values():
		if is_instance_valid(marker) and marker.get_child_count()>0:
			var face: Node3D=marker.get_child(0)
			face.position.y=absf(sin(clock*2.6))*0.10 if int(marker.get_meta("state",-1))==2 and not reduced_motion else 0.0
	for water in waters:
		water.set_shader_parameter("clock",clock)
		water.set_shader_parameter("motion",0.0 if reduced_motion else 1.0)

func layout_markers():
	var entries=[]
	entries.append_array(bubbles)
	entries.append_array(production_nodes.values())
	entries.append_array(construction_nodes.values())
	for entry in entries:
		var id=str(entry.get_meta("marker_place_id",""))
		if entry.get_meta("marker_role","")=="oven" and ovens.has(id):
			entry.set_meta("utility_marker",oven_marker(id))
		elif entry.get_meta("marker_role","")=="pantry" and kitchens.has(id):
			entry.set_meta("utility_marker",kitchens[id].position+Vector3(0,2.75,0.45))
		elif entry.has_meta("utility_marker"): entry.remove_meta("utility_marker")
	marker_layout.markers(entries,data.items)
	if hidden_marker_place!="":
		for entry in entries:
			if str(entry.get_meta("marker_place_id",""))==hidden_marker_place: entry.visible=false

func blocks_view(camera: Camera3D,target: Vector3,center: Vector3,radius: float) -> bool:
	var segment=target-camera.global_position
	var amount=(center-camera.global_position).dot(segment)/maxf(0.01,segment.length_squared())
	return amount>0 and amount<1 and (camera.global_position+segment*amount).distance_to(center)<radius
func update_character_visibility(camera: Camera3D,feet: Vector3,enabled: bool,inspected_id: String="",subject_height: float=1.65):
	var face=feet+Vector3(0,subject_height,0)
	var chest=feet+Vector3(0,1.0 if inspected_id=="" else 0.35,0)
	for item in data.items:
		if not HomesteadItems.DEFINITIONS[item.kind].blocks or HomesteadItems.DEFINITIONS[item.kind].height<0.9: continue
		var root: Node3D=nodes.get(item.id)
		if not is_instance_valid(root): continue
		var height=HomesteadItems.DEFINITIONS[item.kind].height
		var center=HomesteadItems.item_center(item)+Vector3(0,2.3 if item.kind=="tree" else height*0.55,0)
		var size=HomesteadItems.footprint(item.kind,item.rotation)
		var radius=1.35 if item.kind=="tree" else clampf(maxf(size.x,size.y)*0.55,0.7,2.5)
		var tree_stage=int(root.get_child(0).get_meta("growth_stage",2)) if item.kind=="tree" else -1
		if tree_stage in [0,1]:
			center=HomesteadItems.item_center(item)+Vector3(0,0.55 if tree_stage==0 else 1.25,0)
			radius=0.35 if tree_stage==0 else 0.8
		var mode=2 if enabled and item.id!=inspected_id and (blocks_view(camera,face,center,radius) or blocks_view(camera,chest,center,radius)) else 0
		if enabled and mode==0 and item.id!=inspected_id and inspected_id=="" and item.kind=="tree" and tree_stage>=1:
			for cottage_item in data.items:
				if cottage_item.kind!="cottage": continue
				var door=HomesteadItems.item_center(cottage_item)+Vector3(0,1.35,1.5).rotated(Vector3.UP,cottage_item.rotation*PI/2)
				if blocks_view(camera,door,center,radius):
					mode=1 if item.id==data.growth_tree_id else 2
					break
		if int(root.get_meta("visibility_mode",0))!=mode or bool(root.get_meta("camera_faded",false))!=(mode>0):
			fade_obstruction(root,false)
			if mode>0: fade_obstruction(root,true,mode==1)
			root.set_meta("visibility_mode",mode)
			root.set_meta("camera_faded",mode>0)
	for oven in ovens.values():
		var hidden=enabled and (blocks_view(camera,face,oven.position+Vector3(0,1.15,0),1.0) or blocks_view(camera,chest,oven.position+Vector3(0,1.15,0),1.0))
		if bool(oven.get_meta("camera_faded",false))!=hidden:
			oven.set_meta("camera_faded",hidden)
			fade_obstruction(oven.art,hidden)
	var well_hidden=enabled and well.art.visible and (blocks_view(camera,face,well.position+Vector3(0,1.3,0),1.05) or blocks_view(camera,chest,well.position+Vector3(0,1.3,0),1.05))
	if bool(well.get_meta("camera_faded",false))!=well_hidden:
		well.set_meta("camera_faded",well_hidden)
		fade_obstruction(well.art,well_hidden)
func fade_obstruction(node: Node,faded: bool,leaves_only=false):
	if node is MeshInstance3D:
		if faded and (not leaves_only or str(node.name).begins_with("Crown")) and node.material_override is StandardMaterial3D:
			node.set_meta("camera_original_material",node.material_override)
			var material=node.material_override.duplicate()
			material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
			material.albedo_color.a=0.24
			material.depth_draw_mode=BaseMaterial3D.DEPTH_DRAW_DISABLED
			node.material_override=material
		elif not faded and node.has_meta("camera_original_material"):
			node.material_override=node.get_meta("camera_original_material")
			node.remove_meta("camera_original_material")
	for child in node.get_children(): fade_obstruction(child,faded,leaves_only)

func set_reading_place(id: String):
	for key in nodes:
		if not nodes[key].has_meta("seat_book"): continue
		var book=nodes[key].get_meta("seat_book")
		if is_instance_valid(book): book.visible=key!=id

func reading_nook(root: Node3D,style=0):
	HomesteadQuietPlaceArt.attach(root,"nook",style)

func treehouse(root: Node3D,style=0,ghost=false):
	var model=HomesteadQuietPlaceArt.attach(root,"treehouse",style)
	var canopy=model.find_child("Canopy",true,false)
	if canopy and not ghost: foliage.append(canopy)

func recolor_roof(node: Node,color: String):
	if node is MeshInstance3D and bool(node.get_meta("cottage_roof",false)):
		var material=node.material_override.duplicate()
		material.albedo_color=Color(color)
		node.material_override=material
	for child in node.get_children(): recolor_roof(child,color)

# Small authored homestead additions; animals belong to their saved building.
func barn(root: Node3D):
	HomesteadFarmBuildingArt.attach(root,"barn")
	var sheep=Node3D.new()
	root.add_child(sheep)
	sheep.position=Vector3(-0.30,0.02,0.98)
	sheep.scale=Vector3.ONE*0.60
	sheep.set_meta("livestock",true)
	farm_animal(sheep,false)

func doghouse(root: Node3D):
	HomesteadFarmBuildingArt.attach(root,"doghouse")
	var dog=Node3D.new()
	root.add_child(dog)
	dog.position=Vector3(0.4,0,0.44)
	farm_animal(dog,true)

func farm_animal(root: Node3D,is_dog: bool):
	HomesteadAnimalArt.attach(root,is_dog)

func grill(root: Node3D):
	HomesteadFarmBuildingArt.attach(root,"grill")

# Future regions hint at different journeys without granting land or inventory.
func future_meadow(root: Node3D):
	var grove=Node3D.new()
	grove.name="FutureMeadowGrove"
	root.add_child(grove)
	for i in 4:
		var holder=Node3D.new()
		grove.add_child(holder)
		holder.position=Vector3(-4.5+i*2.8,0,-4.3+sin(i*1.9)*0.5)
		holder.scale=Vector3(1.45,1,1.45)*(0.65+0.06*(i%2))
		tree(holder,false,i%3)
	# An asymmetric sweep of meadow flowers, rather than a grid of filler props.
	for i in 22:
		var angle=float(i)*0.24-1.5
		var point=Vector3(sin(angle)*3.7,0.10,cos(angle)*2.2-0.3)
		HomesteadMesh.ellipsoid(root,point,Vector3(0.25,0.12,0.17),"7e946e")
		if i%2==0:
			HomesteadMesh.ellipsoid(root,point+Vector3(0,0.17,0),Vector3(0.10,0.07,0.10),"dac696" if i%3 else "b9aec0")
	for i in 8:
		var point=Vector3(-1.7+sin(i*0.47)*2.0,0.035,3.8-i*0.72)
		HomesteadMesh.ellipsoid(root,point,Vector3(0.22,0.045,0.15),"b8b5a1")

func beach_cove(root: Node3D,dormant: bool):
	var cove=Node3D.new()
	cove.name="BeachCove"
	root.add_child(cove)
	# All twelve usable columns remain dry. The cove lies beyond their east edge.
	var shore=PackedVector2Array([Vector2(5.8,-6),Vector2(8,-6.3),Vector2(9,-5),Vector2(8.2,-2),Vector2(9.2,1),Vector2(8.7,5.8),Vector2(6,6)])
	HomesteadMesh.polygon_slab(cove,shore,0.02,-0.9,"d3c09a" if dormant else "e5cf9e")
	var wet=PackedVector2Array([Vector2(7.5,-6.2),Vector2(8,-6.3),Vector2(9,-5),Vector2(8.2,-2),Vector2(9.2,1),Vector2(8.7,5.8),Vector2(8.1,5.9),Vector2(8.6,1),Vector2(7.7,-2),Vector2(8.4,-5)])
	HomesteadMesh.polygon_slab(cove,wet,0.026,-0.07,"c5b79b" if dormant else "c7ba96")
	var sea=PackedVector2Array([Vector2(8,-6.3),Vector2(10.5,-6.3),Vector2(10.8,-2),Vector2(10.4,2.5),Vector2(9.6,6.3),Vector2(8.7,5.8),Vector2(9.2,1),Vector2(8.2,-2),Vector2(9,-5)])
	var water=HomesteadMesh.polygon_slab(cove,sea,0.006,-0.82,"78aaa8")
	var material=ShaderMaterial.new()
	material.shader=preload("res://scripts/water.gdshader")
	material.set_shader_parameter("water_color",Color("91b3ac" if dormant else "67b7b8"))
	water.material_override=material
	waters.append(material)
	for i in 15:
		var z=-5.7+i*0.78
		var x=8.4+sin(z*1.03)*0.44
		HomesteadMesh.ellipsoid(cove,Vector3(x,0.035,z),Vector3(0.24,0.012,0.055),"e5e2c9")
	for spec in [[Vector3(6.65,0.12,-4.8),0.5],[Vector3(7.0,0.1,4.9),0.4]]:
		HomesteadMesh.ellipsoid(cove,spec[0],Vector3(spec[1],0.20,spec[1]*0.7),"b9bca9")
	HomesteadMesh.rod(cove,Vector3(6.7,0.12,2.0),Vector3(7.3,0.14,2.8),0.08,"b9a17a")
	for i in 7:
		var point=Vector3(6.7+sin(i*2.4)*0.35,0.06,-0.9+i*0.47)
		HomesteadMesh.ellipsoid(cove,point,Vector3(0.07,0.035,0.06),"f0dfbd")
	for i in 5:
		var base=Vector3(6.25+i*0.10,0.04,4.3)
		HomesteadMesh.rod(cove,base,base+Vector3(-0.12,0.48+i*0.06,0.06),0.022,"8e9e75")

func mountain_ridge(root: Node3D):
	var ridge=Node3D.new()
	ridge.name="FutureMountainRidge"
	root.add_child(ridge)
	mountain_peak(ridge,Vector3(-3.2,0,-2),2.4,4.4,"8d9b91")
	mountain_peak(ridge,Vector3(0.1,0,-3),3.0,6.4,"84958c")
	mountain_peak(ridge,Vector3(3.5,0,-2),2.1,4.7,"99a49a")
	for i in 6:
		var holder=Node3D.new()
		ridge.add_child(holder)
		holder.position=Vector3(-4.8+i*1.85,0,1.4+sin(i*1.7)*0.7)
		holder.scale=Vector3(1.45,1,1.45)*(0.54+0.07*(i%3))
		tree(holder,false,i%3)
	for i in 9:
		HomesteadMesh.ellipsoid(ridge,Vector3(-4.9+i*1.2,0.15,3+sin(i*1.3)*0.6),Vector3(0.35,0.25,0.27),"a5ae9d")

func mountain_peak(root: Node3D,origin: Vector3,radius: float,height: float,color: String):
	var vertices=PackedVector3Array()
	var normals=PackedVector3Array()
	var snow_vertices=PackedVector3Array()
	var snow_normals=PackedVector3Array()
	var peak=origin+Vector3(radius*0.12,height,-radius*0.08)
	for i in 7:
		var angle=float(i)*TAU/7
		var next_angle=float(i+1)*TAU/7
		var a=origin+Vector3(cos(angle)*radius*(1.0+0.09*sin(i*2.3)),0,sin(angle)*radius*0.79)
		var b=origin+Vector3(cos(next_angle)*radius*(1.0+0.09*sin((i+1)*2.3)),0,sin(next_angle)*radius*0.79)
		var normal=(peak-a).cross(b-a).normalized()
		vertices.append_array(PackedVector3Array([a,b,peak]))
		normals.append_array(PackedVector3Array([normal,normal,normal]))
		var sa=a.lerp(peak,0.75+0.035*sin(i*2.8))
		var sb=b.lerp(peak,0.75+0.035*sin((i+1)*2.8))
		snow_vertices.append_array(PackedVector3Array([sa+normal*0.008,sb+normal*0.008,peak+normal*0.008]))
		snow_normals.append_array(PackedVector3Array([normal,normal,normal]))
	for snow in [false,true]:
		var arrays=[]
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX]=snow_vertices if snow else vertices
		arrays[Mesh.ARRAY_NORMAL]=snow_normals if snow else normals
		var mesh=ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		HomesteadMesh.instance(root,mesh,"ece9d9" if snow else color,Vector3.ZERO)

# A soft ring where the child tapped to walk. Display only.
func show_tap(point: Vector3):
	var ring=HomesteadMesh.torus(self,point+Vector3(0,0.05,0),0.32,0.035,"fff6dc")
	ring.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material=HomesteadMesh.transparent(Color("fff6dc"))
	ring.material_override=material
	var tween=ring.create_tween()
	if reduced_motion:
		tween.tween_interval(0.5)
	else:
		tween.set_parallel(true)
		tween.tween_property(ring,"scale",Vector3.ONE*1.6,0.55).set_ease(Tween.EASE_OUT)
		tween.tween_property(material,"albedo_color:a",0.0,0.55)
		tween.set_parallel(false)
	tween.tween_callback(ring.queue_free)

# A new ready bubble grows in with a small overshoot. Layout owns the bubble
# root's scale, so only the face animates.
func pop_in(face: Node3D):
	face.scale=Vector3.ONE*0.01
	var tween=face.create_tween()
	tween.tween_property(face,"scale",Vector3.ONE,0.38).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# The tap answers at once; the flight waits for the saved collection.
func mark_collecting(key: String):
	collecting[key]=clock
	if reduced_motion: return
	for bubble in bubbles:
		if str(bubble.get_meta("producer_key",""))!=key or bubble.get_child_count()==0: continue
		var face: Node3D=bubble.get_child(0)
		var tween=face.create_tween()
		tween.tween_property(face,"scale",Vector3.ONE*1.22,0.09).set_ease(Tween.EASE_OUT)
		tween.tween_property(face,"scale",Vector3.ONE*1.08,0.14)
		# A tap that opens a menu instead of collecting settles back.
		tween.tween_interval(1.2)
		tween.tween_property(face,"scale",Vector3.ONE,0.2)

# A collected bubble leaves the map and flies to the wallet at the top centre.
# Presentation only: the host has already saved the materials.
func fly_to_wallet(bubble: Node3D,toward: Vector2=Vector2(0.5,0.05)):
	var camera=get_viewport().get_camera_3d()
	if reduced_motion or camera==null or bubble.get_child_count()==0:
		bubble.get_parent().remove_child(bubble)
		bubble.queue_free()
		return
	for body in bubble.find_children("*","StaticBody3D",true,false): body.queue_free()
	var start=bubble.global_position
	var size=get_viewport().get_visible_rect().size
	var depth=maxf(1.0,camera.global_position.distance_to(start)*0.55)
	var target=camera.project_position(Vector2(size.x*toward.x,size.y*toward.y),depth)
	var lift=start.lerp(target,0.3)+camera.global_basis.y*0.8
	var face: MeshInstance3D=bubble.get_child(0)
	var material: ShaderMaterial=face.material_override
	var tween=bubble.create_tween()
	tween.tween_property(bubble,"scale",bubble.scale*1.25,0.1).set_ease(Tween.EASE_OUT)
	var arc=func(t: float): bubble.global_position=start.lerp(lift,t).lerp(lift.lerp(target,t),t)
	tween.tween_method(arc,0.0,1.0,0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(bubble,"scale",bubble.scale*0.45,0.6)
	tween.parallel().tween_method(func(v: float): material.set_shader_parameter("fade",v),1.0,0.0,0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(bubble.queue_free)
