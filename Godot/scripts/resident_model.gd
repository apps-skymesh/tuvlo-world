class_name HomesteadResidentModel
extends Node3D
var foot_shadow: MeshInstance3D
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
var left_elbow: Node3D
var can: Node3D
var read_clock=0.0
var reading_book: Node3D
var turning_page: Node3D
var clock=0.0
var reduced_motion=false
var carrying_water=false
var eyes: Array[MeshInstance3D]=[]
var eye_glints: Array[MeshInstance3D]=[]
var eye_whites: Array[MeshInstance3D]=[]
var pupils: Array[MeshInstance3D]=[]
var mode="idle"
var appearance=HomesteadAppearance.DEFAULT.duplicate()
var appearance_applied=false
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
var ears: Array[MeshInstance3D]=[]
# Gentle attention: the head eases toward a glance or the path ahead.
var look_yaw=0.0
var activity_camera_yaw=0.0
var glance=Vector2.ZERO
var glance_target=Vector2.ZERO
var next_glance=2.0
var next_blink=3.0
var blink_left=0.0
var look_rng=RandomNumberGenerator.new()
func _ready():
	look_rng.seed=91357
	foot_shadow=HomesteadMesh.contact_shadow(self,Vector2(0.85,0.68))
	rig=Node3D.new()
	rig.name="Rig"
	add_child(rig)
	hips=Node3D.new()
	hips.name="Hips"
	rig.add_child(hips)
	hips.position.y=0.705
	garment(hips,[[-0.13,0.228,0.158],[0.04,0.216,0.15],[0.14,0.205,0.145]],"b59562")
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
		HomesteadChildCraft.attach(ankle,"Shoe")
		soft_form(knee,Vector3.ZERO,Vector3(0.076,0.076,0.076),"d9af88")
	HomesteadChildCraft.attach(hips,"Shirt")
	outfit_details=Node3D.new()
	hips.add_child(outfit_details)
	HomesteadMesh.box(outfit_details,Vector3(0,0.22,0.185),Vector3(0.32,0.32,0.035),"c3a36c",0.025)
	for x in [-0.11,0.11]:
		HomesteadMesh.box(outfit_details,Vector3(x,0.41,0.167),Vector3(0.047,0.3,0.025),"c3a36c",0.008)
		soft_form(outfit_details,Vector3(x,0.32,0.23),Vector3.ONE*0.022,"eddbb2")
	left_arm=limb(hips,"LeftArm",Vector3(-0.245,0.49,0),0.27,0.09,"83a89a")
	right_arm=limb(hips,"RightArm",Vector3(0.245,0.49,0),0.27,0.09,"83a89a")
	left_elbow=limb(left_arm,"LeftElbow",Vector3(0,-0.27,0),0.23,0.065,"dfb38c")
	right_elbow=limb(right_arm,"RightElbow",Vector3(0,-0.27,0),0.23,0.065,"dfb38c")
	for arm in [left_arm,right_arm]:
		HomesteadMesh.torus(arm,Vector3(0,-0.25,0),0.083,0.012,"83a89a")
	for elbow in [left_elbow,right_elbow]:
		soft_form(elbow,Vector3.ZERO,Vector3(0.066,0.066,0.066),"dfb38c")
		HomesteadChildCraft.attach(elbow,"RightHand" if elbow==right_elbow else "LeftHand")
	HomesteadMesh.cylinder(hips,Vector3(0,0.65,0),0.09,0.16,"dfb38c")
	head=Node3D.new()
	head.name="Head"
	hips.add_child(head)
	head.position.y=0.91
	HomesteadChildCraft.attach(head,"Face")
	for x in [-0.27,0.27]:
		ears.append(soft_form(head,Vector3(x,-0.025,0),Vector3(0.044,0.064,0.045),"d6a482"))
	for x in [-0.1,0.1]:
		eye_whites.append(soft_form(head,Vector3(x,0.008,0.235),Vector3(0.050,0.066,0.013),"fff9ed"))
		var eye=soft_form(head,Vector3(x,0.008,0.246),Vector3(0.040,0.056,0.014),"4c443b")
		eyes.append(eye)
		pupils.append(soft_form(head,Vector3(x,0.005,0.258),Vector3(0.014,0.026,0.005),"28342f"))
		eye_glints.append(soft_form(head,Vector3(x-0.008,0.02,0.266),Vector3.ONE*0.0085,"fff9ed"))
		eye_glints.append(soft_form(head,Vector3(x+0.009,-0.012,0.264),Vector3.ONE*0.0042,"fff9ed"))
		soft_form(head,Vector3(x*1.65,-0.075,0.207),Vector3(0.041,0.022,0.007),"d3987f")
	soft_form(head,Vector3(0,-0.043,0.249),Vector3(0.029,0.028,0.027),"d6a17d")
	expression_root=Node3D.new()
	head.add_child(expression_root)
	grin_teeth=HomesteadMesh.ellipsoid(expression_root,Vector3(0,-0.118,0.242),Vector3(0.072,0.022,0.008),"f7edd8")
	dimples=Node3D.new()
	head.add_child(dimples)
	for side in [-1,1]: soft_form(dimples,Vector3(side*0.075,-0.11,0.232),Vector3.ONE*0.008,"9f7156")
	# Curved, shallow smile and brows sit against the face rather than floating beads.
	for i in 10:
		var x0=-0.064+i*0.0128
		var x1=x0+0.0128
		var y0=-0.136+0.030*(x0/0.064)*(x0/0.064)
		var y1=-0.136+0.030*(x1/0.064)*(x1/0.064)
		HomesteadMesh.rod(expression_root,Vector3(x0,y0,0.236),Vector3(x1,y1,0.236),0.0045,"8c604f")
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
	reading_book=preload("res://assets/reading_book/cozy_reading_book.glb").instantiate()
	hips.add_child(reading_book)
	reading_book.position=Vector3(0,.24,.42)
	for surface in reading_book.find_children("*","MeshInstance3D",true,false):
		var material=surface.get_active_material(0).duplicate()
		material.vertex_color_use_as_albedo=true
		surface.material_override=material
	turning_page=reading_book.find_child("TurningPage",true,false)
	reading_book.visible=false
	build_animations()
	remember_colors(self)
	apply_appearance(appearance)
func limb(parent: Node3D,node_name: String,pos: Vector3,_length: float,_radius: float,_color: String) -> Node3D:
	var joint=Node3D.new()
	joint.name=node_name
	parent.add_child(joint)
	joint.position=pos
	var part="UpperLeg" if node_name.ends_with("Leg") else "LowerLeg" if node_name.ends_with("Knee") else "Sleeve" if node_name.ends_with("Arm") else "Forearm"
	HomesteadChildCraft.attach(joint,part)
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
	# Relaxed child gait: a .36 m planted stride under a slightly forward,
	# swaying pelvis. Two-bone keys are solved in the leaning hip frame so the
	# stance sole stays flat on the ground; the swing foot rolls off its toe
	# and lifts its toe before contact. Speed follows actual movement.
	var lean=0.045
	var hip_track=[]
	var sway_track=[]
	var body_track=[]
	for i in 33:
		var time=float(i)/32
		var shift=cos(TAU*(time-0.3))
		hip_track.append([time*0.8,0.668+0.014*pow(sin(time*TAU),2)])
		sway_track.append([time*0.8,-0.011*shift])
		body_track.append([time*0.8,Vector3(lean,0,0.028*shift)])
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
			var z=lerpf(0.18,-0.18,t) if stance else lerpf(-0.18,0.18,smoothstep(0,1,t))
			var lift=0.0 if stance else sin(pow(t,0.8)*PI)*0.085
			var hip_y=0.668+0.014*pow(sin(time*TAU),2)
			var down=hip_y-(0.105+lift)
			# Express the ground target in the forward-leaning hip frame.
			var lz=z*cos(lean)+down*sin(lean)
			var ld=down*cos(lean)-z*sin(lean)
			var distance=clampf(Vector2(lz,ld).length(),0.08,0.599)
			var hip_angle=-atan2(lz,ld)-acos(clampf((0.32*0.32+distance*distance-0.28*0.28)/(2*0.32*distance),-1,1))
			var knee_angle=PI-acos(clampf((0.32*0.32+0.28*0.28-distance*distance)/(2*0.32*0.28),-1,1))
			var roll=0.0
			if not stance: roll=0.32*smoothstep(0.0,0.12,t)*(1.0-smoothstep(0.25,0.55,t))-0.2*smoothstep(0.55,0.85,t)*(1.0-smoothstep(0.9,1.0,t))
			hip_keys.append([time*0.8,Vector3(hip_angle,0,0)])
			knee_keys.append([time*0.8,Vector3(knee_angle,0,0)])
			ankle_keys.append([time*0.8,Vector3(-hip_angle-knee_angle-lean+roll,0,0)])
		animation_track(walk,leg,"rotation",hip_keys,Animation.INTERPOLATION_LINEAR)
		animation_track(walk,knee,"rotation",knee_keys,Animation.INTERPOLATION_LINEAR)
		animation_track(walk,ankle,"rotation",ankle_keys,Animation.INTERPOLATION_LINEAR)
	# Arms swing opposite their leg, bending more on the forward swing.
	for side in 2:
		var arm=left_arm if side==0 else right_arm
		var elbow=left_elbow if side==0 else right_elbow
		var arm_keys=[]
		var elbow_keys=[]
		for i in 17:
			var time=float(i)/16
			var swing=cos(TAU*(time+0.06))*(1 if side==0 else -1)
			arm_keys.append([time*0.8,Vector3(swing*0.36-lean,0,0.06 if side==1 else -0.06)])
			elbow_keys.append([time*0.8,Vector3(-0.16-0.28*maxf(0,-swing),0,0)])
		animation_track(walk,arm,"rotation",arm_keys)
		animation_track(walk,elbow,"rotation",elbow_keys)
	animation_track(walk,hips,"position:y",hip_track,Animation.INTERPOLATION_LINEAR)
	animation_track(walk,hips,"position:x",sway_track,Animation.INTERPOLATION_LINEAR)
	animation_track(walk,hips,"rotation",body_track,Animation.INTERPOLATION_LINEAR)
	library.add_animation("walk",walk)
	var idle=Animation.new()
	idle.length=4.8
	idle.loop_mode=Animation.LOOP_LINEAR
	# Quiet standing: slow breath, a soft weight shift onto one leg and arms
	# that settle with it, rather than a frozen mannequin.
	for node in [left_leg,right_leg,left_ankle,right_ankle]:
		animation_track(idle,node,"rotation",[[0,Vector3.ZERO],[4.8,Vector3.ZERO]])
	animation_track(idle,left_knee,"rotation",[[0,Vector3.ZERO],[1.2,Vector3.ZERO],[2.4,Vector3(0.10,0,0)],[3.6,Vector3(0.10,0,0)],[4.8,Vector3.ZERO]])
	animation_track(idle,right_knee,"rotation",[[0,Vector3(0.06,0,0)],[1.2,Vector3(0.06,0,0)],[2.4,Vector3.ZERO],[3.6,Vector3.ZERO],[4.8,Vector3(0.06,0,0)]])
	animation_track(idle,left_arm,"rotation",[[0,Vector3(0.02,0,-0.05)],[1.2,Vector3(0.03,0,-0.07)],[2.4,Vector3(-0.02,0,-0.04)],[3.6,Vector3(0.01,0,-0.06)],[4.8,Vector3(0.02,0,-0.05)]])
	animation_track(idle,right_arm,"rotation",[[0,Vector3(-0.02,0,0.04)],[1.2,Vector3(0.01,0,0.06)],[2.4,Vector3(0.03,0,0.07)],[3.6,Vector3(-0.01,0,0.05)],[4.8,Vector3(-0.02,0,0.04)]])
	for elbow in [left_elbow,right_elbow]:
		animation_track(idle,elbow,"rotation",[[0,Vector3(-0.10,0,0)],[2.4,Vector3(-0.14,0,0)],[4.8,Vector3(-0.10,0,0)]])
	animation_track(idle,hips,"position:y",[[0,0.703],[0.35,0.732],[0.7,0.704],[1.2,0.708],[2.4,0.700],[2.75,0.730],[3.1,0.704],[3.6,0.707],[4.8,0.703]])
	animation_track(idle,hips,"position:x",[[0,0.006],[1.2,0.006],[2.4,-0.006],[3.6,-0.006],[4.8,0.006]])
	animation_track(idle,hips,"rotation",[[0,Vector3(0,0,-0.015)],[1.2,Vector3(0,0,-0.015)],[2.4,Vector3(0,0,0.015)],[3.6,Vector3(0,0,0.015)],[4.8,Vector3(0,0,-0.015)]])
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
		animation_track(clip,hips,"position:y",[[0,0.705],[clip.length,0.705]])
		animation_track(clip,left_elbow,"rotation",[[0,Vector3(-0.1,0,0)],[clip.length,Vector3(-0.1,0,0)]])
	var sit=Animation.new()
	sit.length=1
	sit.loop_mode=Animation.LOOP_LINEAR
	animation_track(sit,hips,"position:y",[[0,0.765],[1,0.765]])
	for leg in [left_leg,right_leg]: animation_track(sit,leg,"rotation",[[0,Vector3(-1.5,0,0)],[1,Vector3(-1.5,0,0)]])
	for knee in [left_knee,right_knee]: animation_track(sit,knee,"rotation",[[0,Vector3(1.5,0,0)],[1,Vector3(1.5,0,0)]])
	for arm in [left_arm,right_arm]: animation_track(sit,arm,"rotation",[[0,Vector3(-0.5,0,0)],[1,Vector3(-0.5,0,0)]])
	animation_track(sit,right_elbow,"rotation",[[0,Vector3.ZERO],[1,Vector3.ZERO]])
	for ankle in [left_ankle,right_ankle]: animation_track(sit,ankle,"rotation",[[0,Vector3.ZERO],[1,Vector3.ZERO]])
	for elbow in [left_elbow]: animation_track(sit,elbow,"rotation",[[0,Vector3.ZERO],[1,Vector3.ZERO]])
	library.add_animation("sit",sit)
	for clip in [wave,water,sit]:
		animation_track(clip,hips,"position:x",[[0,0.0],[clip.length,0.0]])
		animation_track(clip,hips,"rotation",[[0,Vector3.ZERO],[clip.length,Vector3.ZERO]])
	for clip in [idle,walk,water,sit,wave]:
		animation_track(clip,can,"rotation",[[0,Vector3.ZERO],[clip.length,Vector3.ZERO]])
	# The carrying gait keeps the existing planted-foot walk, holding the can level.
	var carry=walk.duplicate() as Animation
	for i in range(carry.get_track_count()-1,-1,-1):
		var path=carry.track_get_path(i)
		if path==NodePath(str(get_path_to(right_arm))+":rotation") or path==NodePath(str(get_path_to(right_elbow))+":rotation") or path==NodePath(str(get_path_to(can))+":rotation"):
			carry.remove_track(i)
	animation_track(carry,right_arm,"rotation",[[0,Vector3(-0.22,0,-0.09)],[0.8,Vector3(-0.22,0,-0.09)]])
	animation_track(carry,right_elbow,"rotation",[[0,Vector3(-0.65,0,0)],[0.8,Vector3(-0.65,0,0)]])
	animation_track(carry,can,"rotation",[[0,Vector3(0.87,0,0.09)],[carry.length,Vector3(0.87,0,0.09)]])
	library.add_animation("carry",carry)
	for title in ["hold","fill"]:
		var pose=idle.duplicate() as Animation
		for i in range(pose.get_track_count()-1,-1,-1):
			var path=pose.track_get_path(i)
			if path==NodePath(str(get_path_to(right_arm))+":rotation") or path==NodePath(str(get_path_to(right_elbow))+":rotation") or path==NodePath(str(get_path_to(can))+":rotation"):
				pose.remove_track(i)
		animation_track(pose,right_arm,"rotation",[[0,Vector3(-0.70 if title=="fill" else -0.22,0,-0.09)],[pose.length,Vector3(-0.70 if title=="fill" else -0.22,0,-0.09)]])
		animation_track(pose,right_elbow,"rotation",[[0,Vector3(-0.28 if title=="fill" else -0.65,0,0)],[pose.length,Vector3(-0.28 if title=="fill" else -0.65,0,0)]])
		var level=Vector3(0.98 if title=="fill" else 0.87,0,0.09)
		animation_track(pose,can,"rotation",[[0,level],[pose.length,level]])
		library.add_animation(title,pose)
	var read=sit.duplicate() as Animation
	read.length=6.0
	pose_track(read,hips,"position:y",[[0,.73],[4,.73]])
	pose_track(read,hips,"rotation",[[0,Vector3(.06,0,0)],[4,Vector3(.06,0,0)]])
	for side in 2:
		var arm=left_arm if side==0 else right_arm
		var elbow=left_elbow if side==0 else right_elbow
		var sign=1 if side==0 else -1
		pose_track(read,arm,"rotation",[[0,Vector3(-.65,0,sign*.10)],[4,Vector3(-.65,0,sign*.10)]])
		pose_track(read,elbow,"rotation",[[0,Vector3(-1.0,0,sign*.15)],[4,Vector3(-1.0,0,sign*.15)]])
	pose_track(read,right_arm,"rotation",[[0,Vector3(-.65,0,-.10)],[4.5,Vector3(-.65,0,-.10)],[5.0,Vector3(-.55,.12,-.22)],[5.5,Vector3(-.65,0,-.10)],[6,Vector3(-.65,0,-.10)]])
	pose_track(read,right_elbow,"rotation",[[0,Vector3(-1,0,-.15)],[4.5,Vector3(-1,0,-.15)],[5.0,Vector3(-1,0,-.45)],[5.5,Vector3(-1,0,-.15)],[6,Vector3(-1,0,-.15)]])
	library.add_animation("read",read)
	var climb=Animation.new()
	climb.length=1.2
	climb.loop_mode=Animation.LOOP_LINEAR
	animation_track(climb,hips,"position:y",[[0,.705],[1.2,.705]])
	animation_track(climb,hips,"position:x",[[0,0.0],[1.2,0.0]])
	animation_track(climb,hips,"rotation",[[0,Vector3.ZERO],[1.2,Vector3.ZERO]])
	for side in 2:
		var leg_keys=[];var knee_keys=[];var arm_keys=[];var elbow_keys=[];var ankle_keys=[]
		for i in 33:
			var t=float(i)/32
			var phase=t*TAU+side*PI
			var down=.705-(.19+.10*sin(phase))
			var reach=clampf(Vector2(.22,down).length(),.08,.599)
			var thigh=-atan2(.22,down)-acos(clampf((.32*.32+reach*reach-.28*.28)/(.64*reach),-1,1))
			var knee=PI-acos(clampf((.32*.32+.28*.28-reach*reach)/(.64*.28),-1,1))
			leg_keys.append([t*1.2,Vector3(thigh,0,0)])
			knee_keys.append([t*1.2,Vector3(knee,0,0)])
			ankle_keys.append([t*1.2,Vector3(-thigh-knee,0,0)])
			down=1.195-(1.52+.10*sin(phase+PI))
			reach=clampf(Vector2(.28,down).length(),.06,.559)
			var shoulder=-atan2(.28,down)-acos(clampf((.27*.27+reach*reach-.29*.29)/(.54*reach),-1,1))
			var elbow=PI-acos(clampf((.27*.27+.29*.29-reach*reach)/(.54*.29),-1,1))
			arm_keys.append([t*1.2,Vector3(shoulder,0,-.10 if side==0 else .10)])
			elbow_keys.append([t*1.2,Vector3(elbow,0,0)])
		animation_track(climb,left_leg if side==0 else right_leg,"rotation",leg_keys,Animation.INTERPOLATION_LINEAR)
		animation_track(climb,left_knee if side==0 else right_knee,"rotation",knee_keys,Animation.INTERPOLATION_LINEAR)
		animation_track(climb,left_ankle if side==0 else right_ankle,"rotation",ankle_keys,Animation.INTERPOLATION_LINEAR)
		animation_track(climb,left_arm if side==0 else right_arm,"rotation",arm_keys,Animation.INTERPOLATION_LINEAR)
		animation_track(climb,left_elbow if side==0 else right_elbow,"rotation",elbow_keys,Animation.INTERPOLATION_LINEAR)
	library.add_animation("climb",climb)
	animator.add_animation_library("",library)
	animator.play("idle")
func pose_track(clip: Animation,node: Node3D,property: String,keys: Array):
	var path=NodePath(str(get_path_to(node))+":"+property)
	for i in range(clip.get_track_count()-1,-1,-1):
		if clip.track_get_path(i)==path: clip.remove_track(i)
	animation_track(clip,node,property,keys)
func set_motion(next: String,speed=1.0):
	if carrying_water and next in ["walk","idle"]: next="carry" if next=="walk" else "hold"
	can.visible=next in ["water","fill","carry","hold"]
	reading_book.visible=next=="read"
	if mode!=next:
		if next=="read": read_clock=0.0
		if next in ["idle","walk","carry","hold"]: animator.play(next,0.22)
		else:
			animator.play("idle",0)
			animator.advance(0)
			animator.play(next,0.25)
		mode=next
		if reduced_motion and next not in ["walk","carry"]:
			animator.advance(0.3)
			animator.seek(1.0 if next=="wave" else 0.25,true)
	# .36 m planted-foot travel over 60% of the .8 s cycle gives .75 m/s.
	# Rig forward scale follows saved build, not its vertical height scale.
	var stride_speed=0.75*[0.86,1.0,1.17][appearance.build]
	animator.speed_scale=maxf(0.05,speed/stride_speed) if next in ["walk","carry"] else 1.0
func _process(delta):
	if not reduced_motion: clock+=delta
	if animator and mode not in ["walk","carry"]: animator.speed_scale=0.0 if reduced_motion else 1.0
	var height_scale=[0.9,1.0,1.12][appearance.height]
	position.y=lerpf(position.y,(.60 if mode=="read" else .65)*(1.0-height_scale) if mode in ["sit","read"] else 0.0,minf(1,delta*12))
	if skirt:
		skirt.rotation.x=lerpf(skirt.rotation.x,-0.95 if mode in ["sit","read"] else -.35 if mode=="climb" else 0.0,minf(1,delta*12))
		skirt.scale.z=lerpf(skirt.scale.z,1.5 if mode in ["walk","carry"] else 1.0,minf(1,delta*12))
	if turning_page:
		if mode=="read" and not reduced_motion: read_clock+=delta
		var turn=fposmod(read_clock,6.0)
		turning_page.visible=mode=="read" and not reduced_motion and turn>4.6 and turn<5.6
		turning_page.rotation.z=PI*smoothstep(4.6,5.6,turn)
	# Natural blinks: irregular spacing with an occasional double blink.
	if not reduced_motion:
		next_blink-=delta
		if next_blink<=0:
			blink_left=0.13
			next_blink=look_rng.randf_range(2.2,5.5) if look_rng.randf()>0.18 else 0.28
		blink_left-=delta
	var blink=not reduced_motion and blink_left>0
	for glint in eye_glints: glint.visible=not blink
	for white in eye_whites: white.scale.y=normal_eye_height*0.16 if blink else normal_eye_height*1.18
	for pupil in pupils: pupil.scale.y=normal_eye_height*0.08 if blink else normal_eye_height*0.58
	for eye in eyes: eye.scale.y=normal_eye_height*0.15 if blink else normal_eye_height
	if reduced_motion:
		head.rotation=Vector3(.40,0,0) if mode=="read" else Vector3.ZERO
		return
	# Idle glances settle on a point for a few seconds; walking looks into the
	# coming turn. Both ease, so the head never snaps.
	next_glance-=delta
	if next_glance<=0:
		next_glance=look_rng.randf_range(1.8,4.2)
		glance_target=Vector2(look_rng.randf_range(-0.45,0.45),look_rng.randf_range(-0.10,0.12)) if look_rng.randf()>0.3 else Vector2.ZERO
	var goal=Vector2.ZERO
	if mode=="idle": goal=glance_target
	elif mode=="read": goal=Vector2(sin(clock*.5)*.025,.40)
	elif mode=="climb": goal=Vector2(0,-.08)
	elif mode in ["water","fill"]: goal=Vector2(clampf(activity_camera_yaw,-0.22,0.22),0.06)
	elif mode in ["walk","carry"]: goal=Vector2(clampf(look_yaw*0.6,-0.5,0.5),0.06)
	glance=glance.lerp(goal,minf(1,delta*(3.0 if mode in ["walk","carry"] else 2.2)))
	head.rotation.y=glance.x
	head.rotation.x=glance.y+(sin(clock*0.9)*0.015 if mode=="idle" else 0.0)

func remember_colors(node: Node):
	if node is MeshInstance3D and node.material_override is StandardMaterial3D and not node.has_meta("original_color"):
		node.set_meta("original_color",node.material_override.albedo_color.to_html(false))
	for child in node.get_children(): remember_colors(child)
func recolor(node: Node,palette: Dictionary):
	if node is MeshInstance3D:
		var original=str(node.get_meta("original_color",""))
		if palette.has(original):
			var material=HomesteadMesh.material(palette[original])
			if node.has_meta("authored_surface"):
				material=material.duplicate()
				material.vertex_color_use_as_albedo=true
			node.material_override=material
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

# The saved 0...12 style catalogue uses original fitted Blender surfaces.
func build_hair(style: int):
	for child in hair_root.get_children():
		hair_root.remove_child(child)
		child.queue_free()
	HomesteadChildCraft.attach(hair_root,"Hair%d"%style)
	hair_style=style
func apply_appearance(raw: Dictionary):
	var normalized=HomesteadAppearance.normalize(raw)
	if head==null: return
	if appearance_applied and normalized==appearance: return
	appearance=normalized
	appearance_applied=true
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
	# A slightly larger head keeps the friendly storybook proportion.
	head.scale=[Vector3.ONE,Vector3(1.05,0.95,1),Vector3(0.92,1.12,1),Vector3(1.1,0.96,1)][appearance.face]*1.06
	# Long and full styles cover the ears; a skin dot on the hair reads as a defect.
	for ear in ears: ear.visible=not appearance.hair in [3,4,7,9]
	normal_eye_height=[0.054,0.064,0.038][appearance.eyes]
	for white in eye_whites: white.scale.y=normal_eye_height*1.18
	for pupil in pupils: pupil.scale.y=normal_eye_height*0.58
	for eye in eyes:
		eye.scale.x=0.048 if appearance.eyes==2 else 0.040
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
