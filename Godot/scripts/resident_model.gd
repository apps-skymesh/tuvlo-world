class_name HomesteadResidentModel
extends Node3D
var animator: AnimationPlayer
var rig: Node3D
var hips: Node3D
var head: Node3D
var left_leg: Node3D
var right_leg: Node3D
var left_knee: Node3D
var right_knee: Node3D
var left_ankle: Node3D
var right_ankle: Node3D
var left_arm: Node3D
var right_arm: Node3D
var right_elbow: Node3D
var can: Node3D
var clock=0.0
var reduced_motion=false
var eyes: Array[MeshInstance3D]=[]
var eye_glints: Array[MeshInstance3D]=[]
var eye_whites: Array[MeshInstance3D]=[]
var pupils: Array[MeshInstance3D]=[]
var mode="idle"
var appearance=HomesteadAppearance.DEFAULT.duplicate()
var hair_root: Node3D
var outfit_details: Node3D
var skirt: MeshInstance3D
var glasses_root: Node3D
var freckles_root: Node3D
var normal_eye_height=0.051
var hair_style=-1
var character_sphere: SphereMesh
var wardrobe: Node3D
var headwear: Node3D
var scarf_root: Node3D
var expression_root: Node3D
var grin_teeth: MeshInstance3D
var dimples: Node3D
func _ready():
	HomesteadMesh.contact_shadow(self,Vector2(0.85,0.68))
	rig=Node3D.new()
	rig.name="Rig"
	add_child(rig)
	hips=Node3D.new()
	hips.name="Hips"
	rig.add_child(hips)
	hips.position.y=0.705
	garment(hips,[[-0.13,0.235,0.16],[0.04,0.235,0.17],[0.14,0.22,0.16]],"b59562")
	left_leg=limb(hips,"LeftLeg",Vector3(-0.135,0,0),0.32,0.105,"b59562")
	right_leg=limb(hips,"RightLeg",Vector3(0.135,0,0),0.32,0.105,"b59562")
	left_knee=limb(left_leg,"LeftKnee",Vector3(0,-0.32,0),0.28,0.075,"d9af88")
	right_knee=limb(right_leg,"RightKnee",Vector3(0,-0.32,0),0.28,0.075,"d9af88")
	for knee in [left_knee,right_knee]:
		var ankle=Node3D.new()
		ankle.name="Ankle"
		ankle.position.y=-0.28
		knee.add_child(ankle)
		if knee==left_knee: left_ankle=ankle
		else: right_ankle=ankle
		HomesteadMesh.box(ankle,Vector3(0,-0.035,0.045),Vector3(0.19,0.14,0.32),"975f48",0.065)
		# A fitted sole, heel tab and inset laces follow the existing ankle rig.
		HomesteadMesh.box(ankle,Vector3(0,-0.091,0.045),Vector3(0.195,0.032,0.325),"e8deca",0.015)
		HomesteadMesh.box(ankle,Vector3(0,0.014,-0.09),Vector3(0.045,0.055,0.025),"e8deca",0.008)
		for z in [0.07,0.11,0.15]:
			HomesteadMesh.rod(ankle,Vector3(-0.045,0.035,z),Vector3(0.045,0.035,z),0.006,"e8deca")
		soft_form(knee,Vector3.ZERO,Vector3(0.076,0.076,0.076),"d9af88")
	garment(hips,[[0.02,0.225,0.16],[0.12,0.245,0.18],[0.39,0.235,0.16],[0.53,0.245,0.15],[0.60,0.13,0.115]],"83a89a")
	outfit_details=Node3D.new()
	hips.add_child(outfit_details)
	HomesteadMesh.box(outfit_details,Vector3(0,0.22,0.185),Vector3(0.32,0.32,0.035),"c3a36c",0.025)
	for x in [-0.11,0.11]:
		HomesteadMesh.box(outfit_details,Vector3(x,0.41,0.167),Vector3(0.047,0.3,0.025),"c3a36c",0.008)
		soft_form(outfit_details,Vector3(x,0.32,0.23),Vector3.ONE*0.022,"eddbb2")
	left_arm=limb(hips,"LeftArm",Vector3(-0.245,0.49,0),0.27,0.09,"83a89a")
	right_arm=limb(hips,"RightArm",Vector3(0.245,0.49,0),0.27,0.09,"83a89a")
	var left_elbow=limb(left_arm,"LeftElbow",Vector3(0,-0.27,0),0.23,0.065,"dfb38c")
	right_elbow=limb(right_arm,"RightElbow",Vector3(0,-0.27,0),0.23,0.065,"dfb38c")
	for arm in [left_arm,right_arm]:
		HomesteadMesh.torus(arm,Vector3(0,-0.25,0),0.083,0.012,"83a89a")
	for elbow in [left_elbow,right_elbow]:
		soft_form(elbow,Vector3.ZERO,Vector3(0.066,0.066,0.066),"dfb38c")
		soft_form(elbow,Vector3(0,-0.245,0),Vector3(0.062,0.078,0.055),"dfb38c")
		soft_form(elbow,Vector3(-0.045 if elbow==right_elbow else 0.045,-0.23,0.02),Vector3(0.025,0.04,0.03),"dfb38c")
	HomesteadMesh.cylinder(hips,Vector3(0,0.65,0),0.09,0.16,"dfb38c")
	head=Node3D.new()
	head.name="Head"
	hips.add_child(head)
	head.position.y=0.91
	soft_form(head,Vector3.ZERO,Vector3(0.285,0.30,0.255),"e1b68f")
	for x in [-0.27,0.27]:
		soft_form(head,Vector3(x,-0.025,0),Vector3(0.044,0.064,0.045),"d6a482")
	for x in [-0.1,0.1]:
		eye_whites.append(soft_form(head,Vector3(x,0.005,0.235),Vector3(0.039,0.051,0.013),"fff9ed"))
		var eye=soft_form(head,Vector3(x,0.005,0.246),Vector3(0.031,0.043,0.014),"4c443b")
		eyes.append(eye)
		pupils.append(soft_form(head,Vector3(x,0.005,0.258),Vector3(0.014,0.026,0.005),"28342f"))
		eye_glints.append(soft_form(head,Vector3(x-0.007,0.019,0.265),Vector3.ONE*0.006,"fff9ed"))
		soft_form(head,Vector3(x*1.65,-0.075,0.207),Vector3(0.041,0.022,0.007),"d3987f")
	soft_form(head,Vector3(0,-0.043,0.249),Vector3(0.029,0.028,0.027),"d6a17d")
	expression_root=Node3D.new()
	head.add_child(expression_root)
	grin_teeth=HomesteadMesh.ellipsoid(expression_root,Vector3(0,-0.115,0.238),Vector3(0.05,0.018,0.007),"f7edd8")
	dimples=Node3D.new()
	head.add_child(dimples)
	for side in [-1,1]: soft_form(dimples,Vector3(side*0.075,-0.11,0.232),Vector3.ONE*0.008,"9f7156")
	# Curved, shallow smile and brows sit against the face rather than floating beads.
	for i in 8:
		var x0=-0.044+i*0.011
		var x1=x0+0.011
		HomesteadMesh.rod(expression_root,Vector3(x0,-0.124+0.012*pow(x0/0.044,2),0.232),Vector3(x1,-0.124+0.012*pow(x1/0.044,2),0.232),0.004,"8c604f")
	for side in [-1,1]:
		var brow=soft_form(head,Vector3(side*0.1,0.083,0.23),Vector3(0.046,0.009,0.008),"695440")
		brow.rotation.z=side*-0.10
	hair_root=Node3D.new()
	head.add_child(hair_root)
	glasses_root=Node3D.new()
	head.add_child(glasses_root)
	for x in [-0.105,0.105]:
		var frame=HomesteadMesh.torus(glasses_root,Vector3(x,0.015,0.252),0.066,0.006,"514e48")
		frame.rotation.x=PI/2
	HomesteadMesh.rod(glasses_root,Vector3(-0.035,0.025,0.253),Vector3(0.035,0.025,0.253),0.009,"514e48")
	freckles_root=Node3D.new()
	head.add_child(freckles_root)
	for side in [-1,1]:
		for i in 3:
			soft_form(freckles_root,Vector3(side*(0.12+i*0.022),-0.06+(i%2)*0.017,0.229-i*0.006),Vector3.ONE*0.007,"9f7156")
	skirt=garment(hips,[[-0.44,0.32,0.235],[-0.41,0.32,0.235],[-0.18,0.275,0.20],[0.0,0.24,0.18]],"c3a36c")
	skirt.position.y=0.13
	# A small folded fabric triangle replaces the old rectangular neck block.
	var scarf_mesh=ArrayMesh.new()
	var scarf_arrays=[]
	scarf_arrays.resize(Mesh.ARRAY_MAX)
	scarf_arrays[Mesh.ARRAY_VERTEX]=PackedVector3Array([Vector3(-0.095,0.51,0.19),Vector3(0.095,0.51,0.19),Vector3(0.025,0.36,0.205)])
	scarf_arrays[Mesh.ARRAY_NORMAL]=PackedVector3Array([Vector3(0,0.3,1).normalized(),Vector3(0,0.3,1).normalized(),Vector3(0,0.3,1).normalized()])
	scarf_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,scarf_arrays)
	HomesteadMesh.instance(hips,scarf_mesh,"c58462",Vector3.ZERO)
	soft_form(hips,Vector3(0,0.505,0.195),Vector3(0.032,0.025,0.025),"c58462")
	scarf_root=Node3D.new()
	hips.add_child(scarf_root)
	# Reparent the existing scarf meshes, retaining their fitted rig coordinates.
	for child in hips.get_children():
		if child is MeshInstance3D and child.material_override is StandardMaterial3D and child.material_override.albedo_color.is_equal_approx(Color("c58462")):
			child.reparent(scarf_root)
	wardrobe=Node3D.new()
	hips.add_child(wardrobe)
	headwear=Node3D.new()
	head.add_child(headwear)
	can=Node3D.new()
	right_elbow.add_child(can)
	can.position=Vector3(0.03,-0.29,0.11)
	HomesteadMesh.cylinder(can,Vector3.ZERO,0.14,0.2,"739c94")
	HomesteadMesh.torus(can,Vector3(-0.14,0.07,0),0.1,0.022,"739c94").rotation.z=PI/2
	HomesteadMesh.rod(can,Vector3(0.1,0.01,0),Vector3(0.27,0.09,0),0.035,"739c94")
	can.visible=false
	build_animations()
	remember_colors(self)
	apply_appearance(appearance)
func limb(parent: Node3D,node_name: String,pos: Vector3,length: float,radius: float,color: String) -> Node3D:
	var joint=Node3D.new()
	joint.name=node_name
	parent.add_child(joint)
	joint.position=pos
	var mesh=CapsuleMesh.new()
	mesh.radius=radius
	mesh.height=length+radius*0.7
	mesh.radial_segments=24
	mesh.rings=8
	HomesteadMesh.instance(joint,mesh,color,Vector3(0,-length/2,0))
	return joint
func animation_track(animation: Animation,node: Node3D,property: String,values: Array,interpolation=Animation.INTERPOLATION_CUBIC):
	var index=animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(index,NodePath(str(get_path_to(node))+":"+property))
	animation.track_set_interpolation_type(index,interpolation)
	for key in values: animation.track_insert_key(index,key[0],key[1])
func build_animations():
	animator=AnimationPlayer.new()
	add_child(animator)
	animator.root_node=NodePath("..")
	var library=AnimationLibrary.new()
	var walk=Animation.new()
	walk.length=0.8
	walk.loop_mode=Animation.LOOP_LINEAR
	# A .70 m stride with a flat, planted stance and a short lifted swing.
	# Analytic two-bone keys keep the knee connected and sole level, rather than
	# swinging straight sticks through the floor. Speed follows actual movement.
	for side in 2:
		var leg=left_leg if side==0 else right_leg
		var knee=left_knee if side==0 else right_knee
		var ankle=left_ankle if side==0 else right_ankle
		var hip_keys=[]
		var knee_keys=[]
		var ankle_keys=[]
		for i in 33:
			var time=float(i)/32
			var phase=fposmod(time+side*0.5,1.0)
			var stance=phase<0.60
			var t=phase/0.60 if stance else (phase-0.60)/0.40
			var z=lerpf(0.21,-0.21,t) if stance else lerpf(-0.21,0.21,smoothstep(0,1,t))
			var lift=0.0 if stance else sin(t*PI)*0.09
			var hip_y=0.66+0.012*pow(sin(time*TAU),2)
			var down=hip_y-(0.105+lift)
			var distance=clampf(Vector2(z,down).length(),0.08,0.599)
			var hip_angle=-atan2(z,down)-acos(clampf((0.32*0.32+distance*distance-0.28*0.28)/(2*0.32*distance),-1,1))
			var knee_angle=PI-acos(clampf((0.32*0.32+0.28*0.28-distance*distance)/(2*0.32*0.28),-1,1))
			hip_keys.append([time*0.8,Vector3(hip_angle,0,0)])
			knee_keys.append([time*0.8,Vector3(knee_angle,0,0)])
			ankle_keys.append([time*0.8,Vector3(-hip_angle-knee_angle,0,0)])
		animation_track(walk,leg,"rotation",hip_keys,Animation.INTERPOLATION_LINEAR)
		animation_track(walk,knee,"rotation",knee_keys,Animation.INTERPOLATION_LINEAR)
		animation_track(walk,ankle,"rotation",ankle_keys,Animation.INTERPOLATION_LINEAR)
	for arm in [left_arm,right_arm]:
		var keys=[]
		var phase=PI if arm==left_arm else 0.0
		for i in 17: keys.append([i*0.05,Vector3(sin(i*PI/8+phase)*0.24,0,0.035 if arm==right_arm else -0.035)])
		animation_track(walk,arm,"rotation",keys)
	animation_track(walk,right_elbow,"rotation",[[0,Vector3(-0.12,0,0)],[0.8,Vector3(-0.12,0,0)]])
	animation_track(walk,hips,"position:y",[[0,0.66],[0.2,0.672],[0.4,0.66],[0.6,0.672],[0.8,0.66]])
	library.add_animation("walk",walk)
	var idle=Animation.new()
	idle.length=3
	idle.loop_mode=Animation.LOOP_LINEAR
	for node in [left_leg,right_leg,left_knee,right_knee,left_ankle,right_ankle,left_arm,right_arm,right_elbow]:
		animation_track(idle,node,"rotation",[[0,Vector3.ZERO],[3,Vector3.ZERO]])
	animation_track(idle,hips,"position:y",[[0,0.705],[1.5,0.713],[3,0.705]])
	library.add_animation("idle",idle)
	var wave=Animation.new()
	wave.length=2.4
	animation_track(wave,right_arm,"rotation",[[0,Vector3.ZERO],[0.4,Vector3(0,0,2.2)],[0.8,Vector3(0.3,0,2.5)],[1.15,Vector3(-0.3,0,2.1)],[1.5,Vector3(0.3,0,2.5)],[2.0,Vector3(0,0,2.2)],[2.4,Vector3.ZERO]])
	library.add_animation("wave",wave)
	var water=Animation.new()
	water.length=2.4
	water.loop_mode=Animation.LOOP_LINEAR
	animation_track(water,right_arm,"rotation",[[0,Vector3(-0.95,0,-0.12)],[1.2,Vector3(-1.08,0,-0.12)],[2.4,Vector3(-0.95,0,-0.12)]])
	animation_track(water,right_elbow,"rotation",[[0,Vector3(-0.3,0,-0.18)],[2.4,Vector3(-0.3,0,-0.18)]])
	animation_track(water,left_arm,"rotation",[[0,Vector3(-0.35,0,0.08)],[2.4,Vector3(-0.35,0,0.08)]])
	library.add_animation("water",water)
	for clip in [wave,water]:
		for ankle in [left_ankle,right_ankle]: animation_track(clip,ankle,"rotation",[[0,Vector3.ZERO],[clip.length,Vector3.ZERO]])
	var sit=Animation.new()
	sit.length=1
	sit.loop_mode=Animation.LOOP_LINEAR
	animation_track(sit,hips,"position:y",[[0,0.765],[1,0.765]])
	for leg in [left_leg,right_leg]: animation_track(sit,leg,"rotation",[[0,Vector3(-1.5,0,0)],[1,Vector3(-1.5,0,0)]])
	for knee in [left_knee,right_knee]: animation_track(sit,knee,"rotation",[[0,Vector3(1.5,0,0)],[1,Vector3(1.5,0,0)]])
	for arm in [left_arm,right_arm]: animation_track(sit,arm,"rotation",[[0,Vector3(-0.5,0,0)],[1,Vector3(-0.5,0,0)]])
	animation_track(sit,right_elbow,"rotation",[[0,Vector3.ZERO],[1,Vector3.ZERO]])
	for ankle in [left_ankle,right_ankle]: animation_track(sit,ankle,"rotation",[[0,Vector3.ZERO],[1,Vector3.ZERO]])
	library.add_animation("sit",sit)
	animator.add_animation_library("",library)
	animator.play("idle")
func set_motion(next: String,speed=1.0):
	can.visible=next=="water"
	if mode!=next:
		if next in ["idle","walk"]: animator.play(next,0.22)
		else:
			animator.play("idle",0)
			animator.advance(0)
			animator.play(next,0.25)
		mode=next
		if reduced_motion and next!="walk":
			animator.advance(0.3)
			animator.seek(1.0 if next=="wave" else 0.25,true)
	# .42 m planted-foot travel over 60% of the .8 s cycle gives .875 m/s.
	# Rig forward scale follows saved build, not its vertical height scale.
	var stride_speed=0.875*[0.86,1.0,1.17][appearance.build]
	animator.speed_scale=maxf(0.05,speed/stride_speed) if next=="walk" else 1.0
func _process(delta):
	if not reduced_motion: clock+=delta
	if animator and mode!="walk": animator.speed_scale=0.0 if reduced_motion else 1.0
	var height_scale=[0.9,1.0,1.12][appearance.height]
	position.y=lerpf(position.y,0.65*(1.0-height_scale) if mode=="sit" else 0.0,minf(1,delta*12))
	if skirt:
		skirt.rotation.x=lerpf(skirt.rotation.x,-0.95 if mode=="sit" else 0.0,minf(1,delta*12))
		skirt.scale.z=lerpf(skirt.scale.z,1.5 if mode=="walk" else 1.0,minf(1,delta*12))
	var blink=not reduced_motion and fmod(clock,4.9)>4.76
	for glint in eye_glints: glint.visible=not blink
	for white in eye_whites: white.scale.y=normal_eye_height*0.16 if blink else normal_eye_height*1.18
	for pupil in pupils: pupil.scale.y=normal_eye_height*0.08 if blink else normal_eye_height*0.58
	for eye in eyes: eye.scale.y=normal_eye_height*0.15 if blink else normal_eye_height
	if not reduced_motion:
		head.rotation.y=sin(clock*0.7)*0.09 if mode=="idle" else lerpf(head.rotation.y,0,minf(1,delta*5))
	else:
		head.rotation.y=0

func remember_colors(node: Node):
	if node is MeshInstance3D and node.material_override is StandardMaterial3D and not node.has_meta("original_color"):
		node.set_meta("original_color",node.material_override.albedo_color.to_html(false))
	for child in node.get_children(): remember_colors(child)
func recolor(node: Node,palette: Dictionary):
	if node is MeshInstance3D:
		var original=str(node.get_meta("original_color",""))
		if palette.has(original): node.material_override=HomesteadMesh.material(palette[original])
	for child in node.get_children(): recolor(child,palette)
func soft_form(parent: Node3D,pos: Vector3,size: Vector3,color: String) -> MeshInstance3D:
	if character_sphere==null:
		character_sphere=SphereMesh.new()
		character_sphere.radius=1.0
		character_sphere.height=2.0
		character_sphere.radial_segments=32
		character_sphere.rings=20
	var node=HomesteadMesh.instance(parent,character_sphere,color,pos)
	node.scale=size
	return node

# Continuous rings give clothing a tailored silhouette instead of stacked ovals.
func garment(parent: Node3D,rings: Array,color: String) -> MeshInstance3D:
	var vertices=PackedVector3Array()
	var normals=PackedVector3Array()
	var indices=PackedInt32Array()
	for r in rings.size():
		var row=rings[r]
		for i in 33:
			var angle=i*TAU/32
			vertices.append(Vector3(cos(angle)*row[1],row[0],sin(angle)*row[2]))
			normals.append(Vector3(cos(angle),0.07,sin(angle)).normalized())
			if r<rings.size()-1 and i<32:
				var a=r*33+i
				indices.append_array(PackedInt32Array([a,a+1,a+33,a+1,a+34,a+33]))
	var arrays=[]
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices
	arrays[Mesh.ARRAY_NORMAL]=normals
	arrays[Mesh.ARRAY_INDEX]=indices
	var mesh=ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return HomesteadMesh.instance(parent,mesh,color,Vector3.ZERO)

# A single fitted scalp follows a shaped hairline: high at the brow, low at the nape.
func hair_cap(style: int):
	var vertices=PackedVector3Array()
	var normals=PackedVector3Array()
	var indices=PackedInt32Array()
	for r in 17:
		for i in 49:
			var angle=i*TAU/48
			var front=maxf(0,sin(angle))
			var edge=1.65-front*0.45+maxf(0,-sin(angle))*0.4
			if style in [3,4,9]: edge=2.52-front*1.28
			if style in [0,1,12]: edge+=front*(0.13*sin(angle*3+0.8) if style==0 else 0.27*cos(angle+0.3))
			var t=float(r)/16*edge
			var n=Vector3(sin(t)*cos(angle),cos(t),sin(t)*sin(angle))
			vertices.append(n*Vector3(0.3,0.32,0.273)+Vector3(0,0.01,-0.014))
			normals.append(n)
			if r<16 and i<48:
				var a=r*49+i
				indices.append_array(PackedInt32Array([a,a+49,a+1,a+1,a+49,a+50]))
	var arrays=[]
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices
	arrays[Mesh.ARRAY_NORMAL]=normals
	arrays[Mesh.ARRAY_INDEX]=indices
	var mesh=ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	HomesteadMesh.instance(hair_root,mesh,"695440",Vector3.ZERO)

func build_hair(style: int):
	for child in hair_root.get_children():
		hair_root.remove_child(child)
		child.queue_free()
	hair_cap(style)
	match style:
		2,7:
			for row in (4 if style==7 else 3):
				for i in 12:
					var angle=(i+row*0.5)*TAU/12
					if style==7 and sin(angle)>0.35 and row>=2: continue
					var t=0.35+row*0.38
					var size=0.12 if style==7 else 0.075
					soft_form(hair_root,Vector3(cos(angle)*sin(t)*0.28,cos(t)*0.3,sin(angle)*sin(t)*0.26),Vector3.ONE*size,"695440")
		10:
			soft_form(hair_root,Vector3(0,0.245,-0.235),Vector3(0.115,0.12,0.105),"695440")
			HomesteadMesh.torus(hair_root,Vector3(0,0.24,-0.215),0.09,0.009,"c58462").rotation.x=PI/2
		3,4,9:
			for side in [-1,1]:
				var length=0.19 if style==4 else 0.32
				var lock=soft_form(hair_root,Vector3(side*0.25,-0.015-(length-0.19),-0.03),Vector3(0.065,length,0.15),"695440")
				lock.rotation.z=side*(0.18 if style==9 else 0.08)
		5:
			soft_form(hair_root,Vector3(0,-0.06,-0.3),Vector3(0.105,0.3,0.1),"695440")
		6,8:
			for side in [-1,1]:
				for i in (5 if style==8 else 1):
					soft_form(hair_root,Vector3(side*(0.28+0.01*i),-0.04-i*0.075,-0.1),Vector3(0.07,0.065 if style==8 else 0.24,0.07),"695440")
		11:
			for i in 5:
				var tuft=soft_form(hair_root,Vector3(-0.2+i*0.1,0.28,0),Vector3(0.07,0.14,0.07),"695440")
				tuft.rotation.z=0.25-i*0.12
	remember_colors(hair_root)
	hair_style=style
func apply_appearance(raw: Dictionary):
	appearance=HomesteadAppearance.normalize(raw)
	if head==null: return
	if hair_style!=appearance.hair: build_hair(appearance.hair)
	var skin=HomesteadAppearance.SKINS[appearance.skin]
	var hair=HomesteadAppearance.HAIR_COLORS[appearance.hair_color]
	var top=HomesteadAppearance.TOPS[appearance.top]
	var bottom=HomesteadAppearance.BOTTOMS[appearance.bottom]
	var shoe=HomesteadAppearance.SHOES[appearance.shoes]
	var scarf=HomesteadAppearance.SCARVES[appearance.scarf]
	var palette={"e1b68f":skin,"dfb38c":skin,"d9af88":skin,"d6a482":Color(skin).darkened(0.04).to_html(false),"d6a17d":Color(skin).darkened(0.02).to_html(false),"83a89a":top,"b59562":skin if appearance.outfit==2 else bottom,"c3a36c":bottom,"695440":hair,"75604a":Color(hair).lightened(0.05).to_html(false),"975f48":shoe,"c58462":scarf,"4c443b":HomesteadAppearance.EYES[appearance.eye_color]}
	palette["d3987f"]=Color(skin).lerp(Color("d48772"),0.23).to_html(false)
	palette["8c604f"]=Color(skin).darkened(0.45).to_html(false)
	palette["9f7156"]=Color(skin).darkened(0.28).to_html(false)
	recolor(self,palette)
	outfit_details.visible=appearance.outfit==4
	skirt.visible=appearance.outfit==2
	glasses_root.visible=appearance.glasses==1
	freckles_root.visible=appearance.freckles==1
	grin_teeth.visible=appearance.expression==1
	dimples.visible=appearance.expression==3
	expression_root.scale.x=1.15 if appearance.expression==1 else 1.0
	update_wardrobe()
	scarf_root.visible=appearance.accessory==1
	var heights=[0.9,1.0,1.12]
	var widths=[0.86,1.0,1.17]
	rig.scale=Vector3(widths[appearance.build],heights[appearance.height],widths[appearance.build])
	head.scale=[Vector3.ONE,Vector3(1.05,0.95,1),Vector3(0.92,1.12,1),Vector3(1.1,0.96,1)][appearance.face]
	normal_eye_height=[0.043,0.051,0.029][appearance.eyes]
	for white in eye_whites: white.scale.y=normal_eye_height*1.18
	for pupil in pupils: pupil.scale.y=normal_eye_height*0.58
	for eye in eyes:
		eye.scale.x=0.037 if appearance.eyes==2 else 0.031
		eye.scale.y=normal_eye_height

func update_wardrobe():
	for root in [wardrobe,headwear]:
		for child in root.get_children():
			root.remove_child(child)
			child.queue_free()
	var color=HomesteadAppearance.TOPS[appearance.top]
	# Tailored fabric hems and a small tonal pocket; no rig replacement.
	var trim=Color(color).darkened(0.14).to_html(false)
	var hem=HomesteadMesh.torus(wardrobe,Vector3(0,0.07,0),0.226,0.009,trim)
	hem.scale.z=0.73
	if appearance.outfit in [0,1]:
		HomesteadMesh.box(wardrobe,Vector3(0.105,0.36,0.166),Vector3(0.075,0.075,0.012),trim,0.016)
		HomesteadMesh.rod(wardrobe,Vector3(0.075,0.386,0.178),Vector3(0.135,0.386,0.178),0.004,Color(color).lightened(0.15).to_html(false))
	if appearance.outfit==1:
		HomesteadMesh.torus(wardrobe,Vector3(0,0.58,0),0.125,0.035,color).rotation.x=PI/2
		for x in [-0.045,0.045]: HomesteadMesh.rod(wardrobe,Vector3(x,0.53,0.19),Vector3(x,0.35,0.205),0.009,"e8deca")
	elif appearance.outfit in [3,5]:
		for side in [-1,1]:
			var collar=HomesteadMesh.box(wardrobe,Vector3(side*0.07,0.52,0.19),Vector3(0.1,0.09,0.025),"e8deca",0.01)
			collar.rotation.z=side*0.35
		for i in 4: HomesteadMesh.ellipsoid(wardrobe,Vector3(0,0.19+i*0.08,0.205),Vector3.ONE*0.012,"e8deca")
	if appearance.pattern==1:
		for i in 4: HomesteadMesh.box(wardrobe,Vector3(0,0.15+i*0.09,0.19),Vector3(0.34,0.022,0.025),"e8deca",0.005)
	elif appearance.pattern>1:
		if appearance.pattern==2:
			var points=PackedVector3Array()
			for i in 10:
				var angle=PI/2+i*TAU/10
				var radius=0.085 if i%2==0 else 0.038
				points.append(Vector3(cos(angle)*radius,0.34+sin(angle)*radius,0.21))
			var mesh=ImmediateMesh.new()
			mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
			for i in 10:
				for point in [Vector3(0,0.34,0.21),points[i],points[(i+1)%10]]:
					mesh.surface_set_normal(Vector3.FORWARD)
					mesh.surface_add_vertex(point)
			mesh.surface_end()
			var badge=HomesteadMesh.instance(wardrobe,mesh,"dfbf77",Vector3.ZERO)
			badge.material_override=badge.material_override.duplicate()
			badge.material_override.cull_mode=BaseMaterial3D.CULL_DISABLED
		else:
			for i in (6 if appearance.pattern==4 else 5):
				var angle=i*TAU/5
				var pos=Vector3((i%3-1)*0.09,0.25+floori(i/3.0)*0.12,0.21) if appearance.pattern==4 else Vector3(sin(angle)*0.05,0.34+cos(angle)*0.05,0.21)
				HomesteadMesh.ellipsoid(wardrobe,pos,Vector3(0.025,0.025,0.012),"dfbf77")
	if appearance.hat>0:
		HomesteadMesh.ellipsoid(headwear,Vector3(0,0.16,-0.01),Vector3(0.31,0.2,0.285),color)
		var sign_z=1 if appearance.hat==1 else -1
		HomesteadMesh.ellipsoid(headwear,Vector3(0,0.09,sign_z*0.3),Vector3(0.28,0.025,0.18),color)
