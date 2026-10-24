class_name HomesteadPresentation
extends Node3D
var data: HomesteadWorldData
var prop_root: Node3D
var land_root: Node3D
var foliage: Array[Node3D]=[]
var waters: Array[ShaderMaterial]=[]
var sails: Array[Node3D]=[]
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
var harvest_root: Node3D
var bubbles: Array[Node3D]=[]
const BUBBLE_SHADER=preload("res://scripts/harvest_bubble.gdshader")

func setup(world_data: HomesteadWorldData):
	data=world_data
	land_root=Node3D.new()
	add_child(land_root)
	prop_root=Node3D.new()
	add_child(prop_root)
	grid_root=Node3D.new()
	add_child(grid_root)
	harvest_root=Node3D.new()
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
	foliage.clear()
	sails.clear()
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
		var growth=(0 if data.approvals<3 else 1 if data.approvals<13 else 2) if item.kind=="tree" and item.id==data.growth_tree_id else -1
		var signature=JSON.stringify([item.kind,item.rotation,item.get("style",0),growth,data.approvals>=34 if item.kind=="cottage" else data.approvals>=55 if item.kind=="path" else false,[data.wheat_garden,data.harvest.values().has("wheat")] if item.kind=="garden" else []])
		if nodes.has(item.id):
			var existing: Node3D=nodes[item.id]
			if existing.get_meta("art_signature","")==signature:
				existing.position=HomesteadItems.item_center(item)
				foliage.append_array(existing.get_meta("foliage",[]))
				waters.append_array(existing.get_meta("waters",[]))
				sails.append_array(existing.get_meta("sails",[]))
				continue
			prop_root.remove_child(existing)
			existing.queue_free()
		var foliage_start=foliage.size()
		var waters_start=waters.size()
		var sails_start=sails.size()
		var root=make_item(item.kind,item.rotation,false,int(item.get("style",0)))
		prop_root.add_child(root)
		root.position=HomesteadItems.item_center(item)
		root.set_meta("item_id",item.id)
		if item.kind=="tree" and item.id==data.growth_tree_id:
			root.get_child(0).scale=Vector3.ONE*(0.35 if data.approvals<3 else 0.65 if data.approvals<13 else 1.0)
		if item.kind=="cottage" and data.approvals>=34:
			for x in [-1.4,1.4]:
				HomesteadMesh.box(root,Vector3(x,1.5,1.35),Vector3(0.18,0.28,0.18),"edc577",0.03)
		HomesteadStaticBatcher.consolidate(root,foliage+sails)
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
		if item.kind=="tree" and item.id==data.growth_tree_id: height*=0.35 if data.approvals<3 else 0.65 if data.approvals<13 else 1.0
		shape.size=Vector3(size.x,height,size.y)
		collider.shape=shape
		collider.position.y=shape.size.y/2
		root.set_meta("art_signature",signature)
		root.set_meta("foliage",foliage.slice(foliage_start))
		root.set_meta("waters",waters.slice(waters_start))
		root.set_meta("sails",sails.slice(sails_start))
	visual_revision+=1
	refresh_grid()

# Owned regions form one surface: there is no colored tile or raised seam at
# purchase boundaries. The shader samples world coordinates across all land.
func land_outline(bounds: Rect2i) -> PackedVector2Array:
	var corner=HomesteadItems.cell_center(bounds.position)-Vector3(0.5,0,0.5)
	return PackedVector2Array([Vector2(corner.x,corner.z),Vector2(corner.x+bounds.size.x,corner.z),Vector2(corner.x+bounds.size.x,corner.z+bounds.size.y),Vector2(corner.x,corner.z+bounds.size.y)])

func terrain_surface(parent: Node3D, outline: PackedVector2Array, dormant=false):
	var soil=Geometry2D.offset_polygon(outline,0.3,Geometry2D.JOIN_ROUND)
	var rim=Geometry2D.offset_polygon(outline,0.12,Geometry2D.JOIN_ROUND)
	for shape in soil: HomesteadMesh.polygon_slab(parent,shape,-0.12,-0.9,"bda782")
	for shape in rim: HomesteadMesh.polygon_slab(parent,shape,-0.025,-0.25,"c8bc95")
	var lawn=HomesteadMesh.polygon_slab(parent,outline,0.018,-0.06,"a9ba89")
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
	for side in data.land_sides:
		var merged=Geometry2D.merge_polygons(outline,land_outline(HomesteadItems.LAND_BOUNDS[side]))
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
		if available:
			if side=="west": meadow_border(patch)
			if side=="east": waterside_bank(patch)
		else:
			terrain_surface(patch,HomesteadMesh.rounded_outline(10.0,10.0,0.14),true)
			var gate=Node3D.new()
			patch.add_child(gate)
			gate.position=Vector3(0,0,4.85) if side=="north" else Vector3(-4.85 if side=="east" else 4.85,0,0)
			gate.rotation.y=0 if side=="north" else PI/2
			for x in [-1.0,0,1.0]:
				HomesteadMesh.box(gate,Vector3(x,0.39,0),Vector3(0.10,0.78,0.10),"a18b6b",0.025)
			for y in [0.29,0.60]:
				HomesteadMesh.box(gate,Vector3(0,y,0),Vector3(2.2,0.10,0.09),"b8a482",0.025)
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
	terrain_surface(patch,HomesteadMesh.rounded_outline(HomesteadItems.EDGE_SIZE.x,HomesteadItems.EDGE_SIZE.y,1.6))
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
		holder.scale=Vector3.ONE*(0.85+0.12*(i%3))
		holder.rotation.y=i*1.3
		tree(holder,false)
	var pile=Node3D.new()
	patch.add_child(pile)
	pile.position=Vector3(0.3,0,0.9)
	for row in 2:
		for i in (3-row):
			var log_node=HomesteadMesh.cylinder(pile,Vector3(-0.32+i*0.32+row*0.16,0.16+row*0.27,0),0.15,1.3,"9b7254")
			log_node.rotation.z=PI/2
			HomesteadMesh.cylinder(pile,Vector3(-0.32+i*0.32+row*0.16,0.16+row*0.27,0.655),0.13,0.012,"e2c48f").rotation.x=PI/2
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
	for bubble in bubbles:
		harvest_root.remove_child(bubble)
		bubble.queue_free()
	bubbles.clear()
	for key in data.harvest:
		var anchor=harvest_anchor(key)
		if anchor==null: continue
		var bubble=Node3D.new()
		harvest_root.add_child(bubble)
		bubble.position=anchor
		bubble.set_meta("anchor",anchor)
		var quad=QuadMesh.new()
		quad.size=Vector2(1.7,1.7)
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
		sphere.radius=0.9
		collider.shape=sphere
		body.add_child(collider)
		bubbles.append(bubble)

func make_item(kind: String,rotation: int,ghost=false,style=0) -> Node3D:
	var root=Node3D.new()
	var art=Node3D.new()
	root.add_child(art)
	art.rotation.y=rotation*PI/2
	match kind:
		"windmill": windmill(art,ghost,style)
		"orchard": orchard(art,style)
		"greenhouse": greenhouse(art)
		"workshop": workshop(art)
		"cottage": cottage(art)
		"garden": garden(art)
		"pond": pond(art,ghost,style)
		"bench": bench(art)
		"tree": tree(art,ghost)
		"flowers": flowers(art,ghost)
		"rocks": rocks(art)
		"nook": reading_nook(art,style)
		"treehouse": treehouse(art,style)
		"path": path_tile(art)
	if kind in ["cottage","garden","tree","bench","nook","treehouse","workshop","greenhouse","orchard","windmill"]:
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
			node.material_override=material
			node.set_meta("cottage_roof",material.resource_name.begins_with("roof"))
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
	var roof_color="78988b" if style==0 else "ad806d"
	HomesteadMesh.cylinder(root,Vector3(0,0.10,0),1.31,0.20,"c9bc9c")
	HomesteadMesh.cylinder(root,Vector3(0,1.25,0),0.91,2.3,"eadfc5",0.65)
	for angle in 8:
		var a=angle*TAU/8
		HomesteadMesh.rod(root,Vector3(sin(a)*0.90,0.24,cos(a)*0.90),Vector3(sin(a)*0.67,2.35,cos(a)*0.67),0.045,"b7a07c")
	HomesteadMesh.torus(root,Vector3(0,0.38,0),0.86,0.045,"bea47c")
	HomesteadMesh.torus(root,Vector3(0,2.28,0),0.67,0.045,"bea47c")
	HomesteadMesh.cylinder(root,Vector3(0,2.65,0),0.98,0.72,roof_color,0.06)
	HomesteadMesh.ellipsoid(root,Vector3(0,3.04,0),Vector3(0.10,0.11,0.10),"c3a56c")
	# Arched timber doorway and a stone doorstep, facing the visit approach.
	HomesteadMesh.box(root,Vector3(0,0.64,0.86),Vector3(0.57,0.98,0.12),"947c5b",0.16)
	for x in [-0.17,0,0.17]:
		HomesteadMesh.box(root,Vector3(x,0.61,0.94),Vector3(0.025,0.77,0.025),"c6ad83",0.008)
	HomesteadMesh.ellipsoid(root,Vector3(0.17,0.61,0.98),Vector3(0.035,0.035,0.025),"d7be86")
	HomesteadMesh.box(root,Vector3(0,0.15,1.03),Vector3(0.83,0.16,0.39),"d9cbaa",0.06)
	for side in [-1,1]:
		var window=HomesteadMesh.box(root,Vector3(side*0.61,1.59,0.50),Vector3(0.24,0.39,0.08),"7e9b96",0.10)
		window.rotation.y=side*0.55
		HomesteadMesh.rod(root,Vector3(side*0.61,1.40,0.56),Vector3(side*0.61,1.78,0.56),0.018,"e4d3ac")
	var pivot=Node3D.new()
	root.add_child(pivot)
	pivot.position=Vector3(0,2.27,1.02)
	pivot.rotation.z=0.22
	for arm in 4:
		var blade=Node3D.new()
		pivot.add_child(blade)
		blade.rotation.z=arm*PI/2
		HomesteadMesh.rod(blade,Vector3(0,0,0),Vector3(0,1.62,0),0.035,"a68a61")
		var sail=HomesteadMesh.box(blade,Vector3(0.13,1.03,0),Vector3(0.33,1.08,0.045),"e9d9b5" if style==0 else "90aa9a",0.025)
		sail.rotation.y=0.20
		for rung in 4:
			HomesteadMesh.box(blade,Vector3(0.13,0.63+rung*0.26,0.04),Vector3(0.36,0.025,0.035),"baa07b",0.008)
	HomesteadMesh.ellipsoid(pivot,Vector3(0,0,0.06),Vector3(0.14,0.14,0.11),"b28e59")
	if not ghost: sails.append(pivot)
	# Harvest sacks and a scoop give the recipe a visible home in the scene.
	for i in 2:
		HomesteadMesh.ellipsoid(root,Vector3(-0.89+i*0.28,0.37,0.69),Vector3(0.24,0.29,0.21),"d5c29b")
		HomesteadMesh.torus(root,Vector3(-0.89+i*0.28,0.61,0.69),0.11,0.02,"a58c63")
	HomesteadMesh.box(root,Vector3(0.86,0.37,0.61),Vector3(0.40,0.08,0.35),roof_color,0.025)
	HomesteadMesh.rod(root,Vector3(0.86,0.41,0.60),Vector3(1.05,0.63,0.60),0.025,"b49b73")

# Sage joinery, translucent glazing and warm terracotta: an airy garden room.
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
	var leaf_color=["83a477","9aaf7b","9b9b85"][clampi(style,0,2)]
	var fruit_color=["c98270","d5b36b","9c8bb2"][clampi(style,0,2)]
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
			HomesteadMesh.ellipsoid(root,crown,Vector3(0.39,0.44,0.34),leaf_color)
		for j in 6:
			var point=base+Vector3(-0.25+(j%3)*0.25,1.62+(j%3)*0.25,0.57 if j<3 else -0.57)
			HomesteadMesh.ellipsoid(root,point,Vector3(0.13,0.16 if style==1 else 0.13,0.13),fruit_color)
			HomesteadMesh.rod(root,point,point+Vector3(0.01,0.14,0),0.012,"8c7757")
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
		HomesteadMesh.ellipsoid(root,Vector3(-0.10+i*0.10,0.37,0.62),Vector3(0.07,0.07,0.07),fruit_color)
	HomesteadMesh.box(root,Vector3(0.64,0.22,0.77),Vector3(0.24,0.19,0.04),"e5d8b6",0.02)
	HomesteadMesh.ellipsoid(root,Vector3(0.64,0.23,0.80),Vector3(0.045,0.045,0.015),fruit_color)

func meadow_border(root: Node3D):
	# Peripheral planting never occupies or conceals usable expansion cells.
	for i in 10:
		var point=Vector3(-4.5+i,0,5.1 if i%2==0 else -5.1)
		HomesteadMesh.ellipsoid(root,point+Vector3(0,0.12,0),Vector3(0.19,0.13,0.14),"80966e")
		HomesteadMesh.rod(root,point+Vector3(0,0.09,0),point+Vector3(0,0.36,0),0.018,"829774")
		HomesteadMesh.ellipsoid(root,point+Vector3(0,0.38,0),Vector3(0.10,0.06,0.10),"e2c4a3" if i%3 else "bda7b3")

func waterside_bank(root: Node3D):
	# The stream sits outside the 2x2-plot buildable cells. Its dry bank
	# stays open for walking and future paid places; scenery grants no items.
	var stream=Node3D.new()
	stream.name="WatersideStream"
	root.add_child(stream)
	stream.position=Vector3(0,0,-5.48)
	HomesteadMesh.box(stream,Vector3(0,-0.18,0),Vector3(10.35,0.43,1.02),"c1a785",0.18)
	HomesteadMesh.box(stream,Vector3(0,0.025,0),Vector3(10.15,0.06,0.78),"b7b59a",0.12)
	var water=HomesteadMesh.box(stream,Vector3(0,0.065,0),Vector3(9.95,0.025,0.57),"70abb0",0.10)
	var material=ShaderMaterial.new()
	material.shader=preload("res://scripts/water.gdshader")
	water.material_override=material
	waters.append(material)
	for i in 26:
		var x=-4.88+i*0.39
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
	for x in [-0.72,0.72]:
		HomesteadMesh.box(root,Vector3(x,0.16,0),Vector3(1.23,0.3,1.72),"b48a62",0.07)
		HomesteadMesh.box(root,Vector3(x,0.315,0),Vector3(1.03,0.05,1.5),"71614e",0.03)
		for z in [-0.48,0,0.48]:
			for dx in [-0.24,0.24]:
				var plant=Vector3(x+dx,0.37,z)
				if data.wheat_garden:
					var ripe=data.harvest.values().has("wheat")
					var height=0.56 if ripe else 0.22
					var tint="c9a55c" if ripe else "80a965"
					HomesteadMesh.rod(root,plant,plant+Vector3(0.025,height,0),0.018,tint)
					for seed in 3:
						var y=height-0.06-seed*0.065
						for side in [-1,1]:
							var head=HomesteadMesh.ellipsoid(root,plant+Vector3(side*0.045,y,0),Vector3(0.035,0.065,0.025),tint)
							head.rotation.z=-side*0.45
				else:
					for leaf_index in 4:
						var angle=leaf_index*TAU/4+(0.35 if x>0 else 0.0)
						var offset=Vector3(cos(angle)*0.09,0.06,sin(angle)*0.09)
						var leaf=HomesteadMesh.ellipsoid(root,plant+offset,Vector3(0.075,0.045,0.17),"548d57" if leaf_index%2 else "80af61")
						leaf.rotation=Vector3(-0.25,PI/2-angle,0)
					HomesteadMesh.ellipsoid(root,plant+Vector3(0,0.14,0),Vector3(0.075,0.10,0.075),"b3d47b")
	HomesteadMesh.rod(root,Vector3(1.28,0,-0.68),Vector3(1.28,0.88,-0.68),0.035,"a47c58")
	HomesteadMesh.box(root,Vector3(1.28,0.75,-0.68),Vector3(0.35,0.28,0.045),"dac7a0",0.035)

func pond(root: Node3D,ghost: bool,style=0):
	HomesteadMesh.ellipsoid(root,Vector3(0,0.05,0),Vector3(1.46,0.12,1.4),"a49d81")
	var surface=HomesteadMesh.cylinder(root,Vector3(0,0.13,0),1.27,0.055,"55a9b4")
	surface.scale.z=0.95
	var material=ShaderMaterial.new()
	material.shader=preload("res://scripts/water.gdshader")
	surface.material_override=material
	if not ghost: waters.append(material)
	for i in 16:
		var a=i*TAU/16
		var stone=HomesteadMesh.ellipsoid(root,Vector3(cos(a)*1.32,0.17,sin(a)*1.26),Vector3(0.21,0.17,0.18),"c6c4ac" if i%3 else "b4b19c")
		stone.rotation.y=a
	for p in ([Vector3(-0.45,0.18,0.45),Vector3(0.6,0.18,-0.3)] if style==0 else []):
		var lily=HomesteadMesh.cylinder(root,p,0.27,0.022,"8eaa78")
		lily.scale.z=0.85
	for i in (4 if style==1 else 0):
		var p=Vector3(0.76+i*0.1,0,0.79-i*0.11)
		HomesteadMesh.rod(root,p+Vector3(0,0.13,0),p+Vector3(-0.05,0.75+i*0.07,0),0.025,"6f9371")
		HomesteadMesh.ellipsoid(root,p+Vector3(-0.05,0.75+i*0.07,0),Vector3(0.05,0.13,0.05),"ad8567")

func bench(root: Node3D):
	for x in [-0.65,0.65]:
		for z in [-0.25,0.25]:
			HomesteadMesh.box(root,Vector3(x,0.27,z),Vector3(0.11,0.54,0.12),"897960",0.025)
		HomesteadMesh.box(root,Vector3(x,0.66,-0.32),Vector3(0.11,0.86,0.11),"897960",0.02)
	for z in [-0.22,0,0.22]:
		HomesteadMesh.box(root,Vector3(0,0.59,z),Vector3(1.8,0.12,0.18),"bb8b62",0.045)
	for y in [0.84,1.05]:
		HomesteadMesh.box(root,Vector3(0,y,-0.32),Vector3(1.8,0.15,0.11),"c49a70",0.045)

func tree(root: Node3D,ghost: bool):
	HomesteadMesh.cylinder(root,Vector3(0,0.85,0),0.16,1.7,"9b7c59",0.1)
	HomesteadMesh.rod(root,Vector3(0,1.1,0),Vector3(0.48,2.0,0.1),0.085,"9b7c59")
	var crown=Node3D.new()
	root.add_child(crown)
	crown.position.y=1.45
	HomesteadMesh.ellipsoid(crown,Vector3(-0.39,0.69,0.06),Vector3(0.72,0.85,0.73),"83a273")
	HomesteadMesh.ellipsoid(crown,Vector3(0.34,0.88,-0.03),Vector3(0.76,1.02,0.76),"94ad7b")
	HomesteadMesh.ellipsoid(crown,Vector3(0.04,1.46,0.04),Vector3(0.62,0.81,0.62),"a1b685")
	if not ghost: foliage.append(crown)
	for p in [Vector3(0.25,0.05,0.28),Vector3(-0.3,0.04,0.1)]:
		HomesteadMesh.ellipsoid(root,p,Vector3(0.21,0.07,0.15),"92a677")

func flowers(root: Node3D,ghost: bool):
	HomesteadMesh.ellipsoid(root,Vector3(0,0.035,0),Vector3(0.46,0.05,0.43),"91a778")
	var patch=Node3D.new()
	root.add_child(patch)
	for i in 5:
		var a=i*2.4
		var p=Vector3(cos(a)*0.28,0.28+(i%2)*0.13,sin(a)*0.27)
		HomesteadMesh.rod(patch,Vector3(p.x,0,p.z),p,0.018,"779365")
		HomesteadMesh.ellipsoid(patch,Vector3(p.x+0.08,p.y*0.5,p.z),Vector3(0.12,0.045,0.06),"8da36e")
		for petal in 5:
			var angle=petal*TAU/5
			HomesteadMesh.ellipsoid(patch,p+Vector3(cos(angle)*0.075,0,sin(angle)*0.075),Vector3(0.075,0.05,0.075),"e0a295" if i%2 else "f0dec1")
		HomesteadMesh.ellipsoid(patch,p+Vector3(0,0.035,0),Vector3.ONE*0.05,"d9b565")
	if not ghost: foliage.append(patch)

func rocks(root: Node3D):
	var r=HomesteadMesh.ellipsoid(root,Vector3(-0.1,0.26,0),Vector3(0.38,0.3,0.34),"a7afa2")
	r.rotation.z=0.22
	HomesteadMesh.ellipsoid(root,Vector3(0.25,0.12,0.2),Vector3(0.2,0.15,0.18),"bec4b1")
func path_tile(root: Node3D):
	# Worn fitted stones leave small grass seams, rather than square beige blocks.
	for i in 3:
		var pivot=Node3D.new()
		root.add_child(pivot)
		pivot.position=Vector3(-0.24+i*0.23,0,0.10 if i%2 else -0.12)
		pivot.rotation.y=-0.07+i*0.06
		var outline=HomesteadMesh.rounded_outline(0.37,0.66 if i%2 else 0.72,0.11)
		HomesteadMesh.polygon_slab(pivot,outline,0.06,0.025,["c4bda7","d0c4a7","bbb9a3"][i])
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
		preview_item=make_item(item.kind,rotation,true,int(item.get("style",0)))
		add_child(preview_item)
		if item.kind=="tree" and item.id==data.growth_tree_id:
			preview_item.get_child(0).scale=Vector3.ONE*(0.35 if data.approvals<3 else 0.65 if data.approvals<13 else 1.0)
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
func clear_preview():
	clear_preview_object()
	if is_instance_valid(preview_node):
		remove_child(preview_node)
		preview_node.queue_free()
	preview_node=null
func _process(delta):
	if not reduced_motion: clock+=delta
	for i in foliage.size():
		var plant=foliage[i]
		if is_instance_valid(plant): plant.rotation.z=sin(clock*0.8+i*1.7)*0.017 if not reduced_motion else 0
	for pivot in sails:
		if is_instance_valid(pivot) and not reduced_motion:
			var camera=get_viewport().get_camera_3d()
			if camera and not camera.is_position_behind(pivot.global_position) and camera.unproject_position(pivot.global_position).x>=0 and get_viewport().get_visible_rect().has_point(camera.unproject_position(pivot.global_position)):
				pivot.rotation.z+=delta*0.12
	for i in bubbles.size():
		var bubble=bubbles[i]
		if is_instance_valid(bubble):
			bubble.position=bubble.get_meta("anchor")+Vector3(0,0.0 if reduced_motion else sin(clock*2.2+i*1.3)*0.12,0)
	for water in waters:
		water.set_shader_parameter("clock",clock)
		water.set_shader_parameter("motion",0.0 if reduced_motion else 1.0)

func update_character_visibility(camera: Camera3D,feet: Vector3,enabled: bool):
	var target=feet+Vector3(0,1.1,0)
	var segment=target-camera.global_position
	var length_squared=segment.length_squared()
	for item in data.items:
		if item.kind not in ["tree","cottage","treehouse"]: continue
		var root: Node3D=nodes.get(item.id)
		if not is_instance_valid(root): continue
		var center=HomesteadItems.item_center(item)+Vector3(0,2.3 if item.kind=="tree" else 2.8 if item.kind=="treehouse" else 1.9,0)
		var amount=(center-camera.global_position).dot(segment)/maxf(0.01,length_squared)
		var radius=1.35 if item.kind=="tree" else 2.5
		var obstructs=enabled and amount>0 and amount<1 and (camera.global_position+segment*amount).distance_to(center)<radius
		if bool(root.get_meta("camera_faded",false))!=obstructs:
			root.set_meta("camera_faded",obstructs)
			fade_obstruction(root,obstructs)
func fade_obstruction(node: Node,faded: bool):
	if node is MeshInstance3D:
		if faded and node.material_override is StandardMaterial3D:
			node.set_meta("camera_original_material",node.material_override)
			var material=node.material_override.duplicate()
			material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
			material.albedo_color.a=0.13
			material.depth_draw_mode=BaseMaterial3D.DEPTH_DRAW_DISABLED
			node.material_override=material
		elif not faded and node.has_meta("camera_original_material"):
			node.material_override=node.get_meta("camera_original_material")
			node.remove_meta("camera_original_material")
	for child in node.get_children(): fade_obstruction(child,faded)

func reading_nook(root: Node3D,style=0):
	HomesteadMesh.box(root,Vector3(0,0.1,0),Vector3(1.9,0.2,1.9),"d0c7ad",0.09)
	var seat=Node3D.new()
	root.add_child(seat)
	seat.scale=Vector3(0.8,0.8,0.8)
	bench(seat)
	HomesteadMesh.box(root,Vector3(0,0.57,0),Vector3(1.4,0.1,0.55),"c9879d" if style==0 else "83a89a",0.045)
	HomesteadMesh.box(root,Vector3(-0.7,0.65,-0.65),Vector3(0.35,1.1,0.3),"bb8055",0.04)
	for i in 4:
		HomesteadMesh.box(root,Vector3(-0.8+i*0.07,1.25,-0.65),Vector3(0.05,0.28,0.22),["83a89a","c98778","dfbf77","b2a0bf"][i],0.008)

func treehouse(root: Node3D,style=0):
	tree(root,true)
	HomesteadMesh.box(root,Vector3(0,2.1,0),Vector3(2.7,0.2,2.7),"bb8055",0.08)
	var house=Node3D.new()
	root.add_child(house)
	house.position.y=2.15
	house.scale=Vector3(0.55,0.55,0.55)
	cottage(house)
	recolor_roof(house,"dfbf77" if style==0 else "b484b2")
	for i in 7:
		HomesteadMesh.box(root,Vector3(0,0.3+i*0.28,1.45),Vector3(0.7,0.07,0.12),"d0c7ad",0.02)
	for x in [-0.4,0.4]:
		HomesteadMesh.box(root,Vector3(x,1.15,1.45),Vector3(0.08,2.3,0.1),"bb8055",0.02)

func recolor_roof(node: Node,color: String):
	if node is MeshInstance3D and bool(node.get_meta("cottage_roof",false)):
		var material=node.material_override.duplicate()
		material.albedo_color=Color(color)
		node.material_override=material
	for child in node.get_children(): recolor_roof(child,color)
