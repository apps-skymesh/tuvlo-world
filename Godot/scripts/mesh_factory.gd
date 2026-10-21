class_name HomesteadMesh
extends RefCounted
static var materials: Dictionary={}
static var sphere_mesh: SphereMesh
static var rounded_meshes: Dictionary={}
static func material(hex: String,roughness=0.86) -> StandardMaterial3D:
	var key=hex+str(roughness)
	if materials.has(key): return materials[key]
	var m=StandardMaterial3D.new()
	m.albedo_color=Color(hex)
	m.roughness=roughness
	materials[key]=m
	return m
static func transparent(color: Color) -> StandardMaterial3D:
	var m=StandardMaterial3D.new()
	m.albedo_color=color
	m.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode=BaseMaterial3D.CULL_DISABLED
	m.no_depth_test=false
	return m
static func instance(parent: Node3D,mesh: Mesh,color: String,pos: Vector3) -> MeshInstance3D:
	var node=MeshInstance3D.new()
	node.mesh=mesh
	node.material_override=material(color)
	node.position=pos
	parent.add_child(node)
	return node
static func ellipsoid(parent: Node3D,pos: Vector3,scale: Vector3,color: String) -> MeshInstance3D:
	if sphere_mesh==null:
		sphere_mesh=SphereMesh.new()
		sphere_mesh.radius=1
		sphere_mesh.height=2
		sphere_mesh.radial_segments=16
		sphere_mesh.rings=8
	var node=instance(parent,sphere_mesh,color,pos)
	node.scale=scale
	return node
static func box(parent: Node3D,pos: Vector3,size: Vector3,color: String,radius=0.06) -> MeshInstance3D:
	var key=str(size)+str(radius)
	if not rounded_meshes.has(key): rounded_meshes[key]=rounded_box(size,radius)
	return instance(parent,rounded_meshes[key],color,pos)
static func cylinder(parent: Node3D,pos: Vector3,radius: float,height: float,color: String,top_radius=-1.0) -> MeshInstance3D:
	var mesh=CylinderMesh.new()
	mesh.top_radius=radius if top_radius<0 else top_radius
	mesh.bottom_radius=radius
	mesh.height=height
	mesh.radial_segments=12
	return instance(parent,mesh,color,pos)
static func rod(parent: Node3D,a: Vector3,b: Vector3,radius: float,color: String) -> MeshInstance3D:
	var node=cylinder(parent,(a+b)/2,radius,a.distance_to(b),color)
	var direction=(b-a).normalized()
	if absf(direction.dot(Vector3.UP))<0.999:
		node.quaternion=Quaternion(Vector3.UP,direction)
	return node
static func torus(parent: Node3D,pos: Vector3,radius: float,thickness: float,color: String) -> MeshInstance3D:
	var mesh=TorusMesh.new()
	mesh.inner_radius=radius-thickness
	mesh.outer_radius=radius+thickness
	mesh.rings=24
	mesh.ring_segments=8
	return instance(parent,mesh,color,pos)
static func rounded_box(size: Vector3,radius: float) -> ArrayMesh:
	var half=size/2
	var r=minf(radius,minf(half.x,minf(half.y,half.z))*0.9)
	var inner=half-Vector3.ONE*r
	var vertices=PackedVector3Array()
	var normals=PackedVector3Array()
	var indices=PackedInt32Array()
	var faces=[[Vector3.RIGHT,Vector3.UP,Vector3.BACK],[Vector3.LEFT,Vector3.UP,Vector3.FORWARD],[Vector3.UP,Vector3.BACK,Vector3.RIGHT],[Vector3.DOWN,Vector3.FORWARD,Vector3.RIGHT],[Vector3.BACK,Vector3.UP,Vector3.LEFT],[Vector3.FORWARD,Vector3.UP,Vector3.RIGHT]]
	var segments=4
	for face in faces:
		var n: Vector3=face[0]
		var u: Vector3=face[1]
		var v: Vector3=face[2]
		var start=vertices.size()
		for y in range(segments+1):
			for x in range(segments+1):
				var p=(n+u*(float(x)/segments*2-1)+v*(float(y)/segments*2-1))*half
				var core=p.clamp(-inner,inner)
				var normal=(p-core).normalized()
				vertices.append(core+normal*r)
				normals.append(normal)
		for y in segments:
			for x in segments:
				var a=start+y*(segments+1)+x
				indices.append_array(PackedInt32Array([a,a+segments+1,a+1,a+1,a+segments+1,a+segments+2]))
	var arrays=[]
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices
	arrays[Mesh.ARRAY_NORMAL]=normals
	arrays[Mesh.ARRAY_INDEX]=indices
	var mesh=ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return mesh
static func polygon_slab(parent: Node3D,outline: PackedVector2Array,top: float,bottom: float,color: String) -> MeshInstance3D:
	var vertices=PackedVector3Array()
	var normals=PackedVector3Array()
	var triangulation=Geometry2D.triangulate_polygon(outline)
	for i in range(0,triangulation.size(),3):
		for k in [0,1,2]:
			var p=outline[triangulation[i+k]]
			vertices.append(Vector3(p.x,top,p.y))
			normals.append(Vector3.UP)
	for i in outline.size():
		var a=outline[i]
		var b=outline[(i+1)%outline.size()]
		var normal=Vector3(b.y-a.y,0,a.x-b.x).normalized()
		for p in [Vector3(a.x,top,a.y),Vector3(a.x,bottom,a.y),Vector3(b.x,top,b.y),Vector3(b.x,top,b.y),Vector3(a.x,bottom,a.y),Vector3(b.x,bottom,b.y)]:
			vertices.append(p)
			normals.append(normal)
	var arrays=[]
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices
	arrays[Mesh.ARRAY_NORMAL]=normals
	var mesh=ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var node=instance(parent,mesh,color,Vector3.ZERO)
	var m=material(color).duplicate()
	m.cull_mode=BaseMaterial3D.CULL_DISABLED
	node.material_override=m
	return node
static func rounded_outline(width: float,depth: float,radius: float) -> PackedVector2Array:
	var result=PackedVector2Array()
	for corner in 4:
		var angle=-PI/2+corner*PI/2
		var center=Vector2((1 if corner in [0,1] else -1)*(width/2-radius),(1 if corner in [1,2] else -1)*(depth/2-radius))
		for step in range(7):
			var a=angle+step*PI/12
			result.append(center+Vector2(cos(a),sin(a))*radius)
	return result

# Shared, soft contact shade works in both Mobile and Compatibility renderers.
static var contact_material: ShaderMaterial
static func contact_shadow(parent: Node3D, size: Vector2) -> MeshInstance3D:
	if contact_material==null:
		contact_material=ShaderMaterial.new()
		contact_material.shader=preload("res://scripts/contact_shadow.gdshader")
	var plane=PlaneMesh.new()
	plane.size=size
	var node=MeshInstance3D.new()
	node.mesh=plane
	node.material_override=contact_material
	node.position.y=0.032
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	return node
