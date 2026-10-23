class_name HomesteadPresentation
extends Node3D
var data: HomesteadWorldData
var prop_root: Node3D
var land_root: Node3D
var foliage: Array[Node3D]=[]
var waters: Array[ShaderMaterial]=[]
var clock=0.0
var reduced_motion=false
var nodes: Dictionary={}
var preview_node: Node3D
var preview_item: Node3D
var preview_item_id=""
var grid_root: Node3D
var grid_visible=false
var visual_revision=0

func setup(world_data: HomesteadWorldData):
	data=world_data
	land_root=Node3D.new()
	add_child(land_root)
	prop_root=Node3D.new()
	add_child(prop_root)
	grid_root=Node3D.new()
	add_child(grid_root)
	rebuild()

func rebuild():
	for child in prop_root.get_children():
		prop_root.remove_child(child)
		child.queue_free()
	for child in land_root.get_children():
		land_root.remove_child(child)
		child.queue_free()
	nodes.clear()
	foliage.clear()
	waters.clear()
	build_island()
	for item in data.items:
		var root=make_item(item.kind,item.rotation,false,int(item.get("style",0)))
		prop_root.add_child(root)
		root.position=HomesteadItems.item_center(item)
		root.set_meta("item_id",item.id)
		if item.kind=="tree" and item.id==data.growth_tree_id:
			root.get_child(0).scale=Vector3.ONE*(0.35 if data.approvals<3 else 0.65 if data.approvals<13 else 1.0)
		if item.kind=="cottage" and data.approvals>=34:
			for x in [-1.4,1.4]:
				HomesteadMesh.box(root,Vector3(x,1.5,1.35),Vector3(0.18,0.28,0.18),"edc577",0.03)
		HomesteadStaticBatcher.consolidate(root,foliage)
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
	visual_revision+=1
	refresh_grid()

func build_island():
	HomesteadMesh.polygon_slab(land_root,HomesteadMesh.rounded_outline(HomesteadItems.BASE_LAND_SIZE.x,HomesteadItems.BASE_LAND_SIZE.y,2.3),-0.18,-0.9,"c1a785")
	HomesteadMesh.polygon_slab(land_root,HomesteadMesh.rounded_outline(19.05,17.05,2.15),-0.07,-0.4,"d9c7a0")
	HomesteadMesh.polygon_slab(land_root,HomesteadMesh.rounded_outline(18.8,16.8,2.1),0,-0.19,"9caf7c")
	# Slightly inset grass gives the miniature a soft, continuous rim.
	var lawn=HomesteadMesh.polygon_slab(land_root,HomesteadMesh.rounded_outline(18.45,16.45,1.9),0.018,-0.05,"a9ba89")
	var meadow=ShaderMaterial.new()
	meadow.shader=preload("res://scripts/meadow.gdshader")
	lawn.material_override=meadow
	# All future plots remain part of the visible world. Rendering one never
	# grants ownership: navigation/placement still read authoritative land_sides.
	for side in HomesteadItems.LAND_CENTERS:
		var available=side in data.land_sides
		var patch=Node3D.new()
		patch.name="Land_"+side
		patch.set_meta("available",available)
		land_root.add_child(patch)
		patch.position=HomesteadItems.LAND_CENTERS[side]
		HomesteadMesh.polygon_slab(patch,HomesteadMesh.rounded_outline(HomesteadItems.PLOT_SIZE.x,HomesteadItems.PLOT_SIZE.y,0.7),-0.18,-0.9,"c1a785")
		HomesteadMesh.polygon_slab(patch,HomesteadMesh.rounded_outline(4.4,4.5,0.65),0.025,-0.2,"a9ba89" if available else "939b80")
		if available:
			if side=="west": meadow_border(patch)
			for i in 3:
				HomesteadMesh.box(patch,Vector3(-1.3+i*1.3,0.06,0),Vector3(0.8,0.06,0.8),"d7c7a8",0.08)
		else:
			# A low closed gate and quiet scrub make the inactive boundary legible.
			var gate=Node3D.new()
			patch.add_child(gate)
			gate.position=Vector3(0,0,1.7) if side=="north" else Vector3(-1.7 if side=="east" else 1.7,0,0)
			gate.rotation.y=0 if side=="north" else PI/2
			for x in [-1.0,0,1.0]:
				HomesteadMesh.box(gate,Vector3(x,0.39,0),Vector3(0.10,0.78,0.10),"a18b6b",0.025)
			for y in [0.29,0.60]:
				HomesteadMesh.box(gate,Vector3(0,y,0),Vector3(2.2,0.10,0.09),"b8a482",0.025)
			for i in 7:
				var angle=i*2.4
				var point=Vector3(cos(angle)*1.25,0.12,sin(angle)*1.05)
				HomesteadMesh.ellipsoid(patch,point,Vector3(0.30,0.18,0.24),"7e8b6e" if i%2 else "a5ad8b")
		HomesteadStaticBatcher.consolidate(patch,[])
	# Low rocks and tufts outside the buildable grid frame the coast.
	for p in [Vector3(-8.8,0,3.4),Vector3(7.6,0,-7.5),Vector3(-3.2,0,7.9),Vector3(8.5,0,5.7)]:
		HomesteadMesh.ellipsoid(land_root,p+Vector3(0,0.2,0),Vector3(0.5,0.28,0.4),"b8b7a5")
		HomesteadMesh.ellipsoid(land_root,p+Vector3(0.4,0.12,0.25),Vector3(0.27,0.16,0.22),"ced0bb")

func make_item(kind: String,rotation: int,ghost=false,style=0) -> Node3D:
	var root=Node3D.new()
	var art=Node3D.new()
	root.add_child(art)
	art.rotation.y=rotation*PI/2
	match kind:
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
	if kind in ["cottage","garden","tree","bench","nook","treehouse","workshop","greenhouse"]:
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

func meadow_border(root: Node3D):
	# Peripheral planting never occupies or conceals usable expansion cells.
	for i in 10:
		var point=Vector3(-1.75+i*0.38,0,2.1 if i%2==0 else -2.1)
		HomesteadMesh.ellipsoid(root,point+Vector3(0,0.12,0),Vector3(0.19,0.13,0.14),"80966e")
		HomesteadMesh.rod(root,point+Vector3(0,0.09,0),point+Vector3(0,0.36,0),0.018,"829774")
		HomesteadMesh.ellipsoid(root,point+Vector3(0,0.38,0),Vector3(0.10,0.06,0.10),"e2c4a3" if i%3 else "bda7b3")

func garden(root: Node3D):
	for x in [-0.72,0.72]:
		HomesteadMesh.box(root,Vector3(x,0.16,0),Vector3(1.23,0.3,1.72),"b48a62",0.07)
		HomesteadMesh.box(root,Vector3(x,0.315,0),Vector3(1.03,0.05,1.5),"71614e",0.03)
		for z in [-0.48,0,0.48]:
			for dx in [-0.24,0.24]:
				var plant=Vector3(x+dx,0.37,z)
				# Broad overlapping leaves read as planted vegetables at follow distance.
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
	for z in range(-4,16):
		for x in range(-4,22):
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
	if is_instance_valid(preview_node):
		remove_child(preview_node)
		preview_node.queue_free()
	preview_node=Node3D.new()
	add_child(preview_node)
	preview_node.position=HomesteadItems.center(cell,size)+Vector3(0,0.07,0)
	var color=Color("e7ca81") if selected else (Color("b2dcc1") if valid else Color("dc947d"))
	var plane=PlaneMesh.new()
	plane.size=Vector2(size.x-0.06,size.y-0.06)
	var tile=MeshInstance3D.new()
	tile.mesh=plane
	color.a=0.55
	tile.material_override=HomesteadMesh.transparent(color)
	preview_node.add_child(tile)
	var border=ImmediateMesh.new()
	border.surface_begin(Mesh.PRIMITIVE_LINES,HomesteadMesh.transparent(Color(color.r*0.55,color.g*0.55,color.b*0.55,1)))
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
	preview_item.position=HomesteadItems.center(cell,HomesteadItems.footprint(item.kind,rotation))+Vector3(0,0.12,0)
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
