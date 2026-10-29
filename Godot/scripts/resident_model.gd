class_name HomesteadResidentModel
extends Node3D
const WALK_CYCLE=.9
const STANCE_FRACTION=.58
const STANCE_REACH=.21
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
var shirt_root: Node3D
var cloth_material: ShaderMaterial
var skirt_material: ShaderMaterial
var cloth_seated=0.0
var skirt: Node3D
var long_sleeves: Array[Node3D]=[]
var glasses_root: Node3D
var freckles_root: Node3D
var normal_eye_height=0.051
var hair_style=-1
var hair_under_cap=false
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
	shirt_root=HomesteadChildCraft.attach(hips,"Shirt")
	left_arm=limb(hips,"LeftArm",Vector3(-0.245,0.49,0),0.27,0.09,"83a89a")
	right_arm=limb(hips,"RightArm",Vector3(0.245,0.49,0),0.27,0.09,"83a89a")
	left_elbow=limb(left_arm,"LeftElbow",Vector3(0,-0.27,0),0.23,0.065,"dfb38c")
	right_elbow=limb(right_arm,"RightElbow",Vector3(0,-0.27,0),0.23,0.065,"dfb38c")
	for arm in [left_arm,right_arm]:
		HomesteadMesh.torus(arm,Vector3(0,-0.25,0),0.083,0.012,"83a89a")
	for elbow in [left_elbow,right_elbow]:
		soft_form(elbow,Vector3.ZERO,Vector3(0.066,0.066,0.066),"dfb38c")
		HomesteadChildCraft.attach(elbow,"RightHand" if elbow==right_elbow else "LeftHand")
		long_sleeves.append(HomesteadChildCraft.attach(elbow,"LongForearm"))
	HomesteadMesh.cylinder(hips,Vector3(0,0.65,0),0.09,0.16,"dfb38c")
	head=Node3D.new()
	head.name="Head"
	hips.add_child(head)
	head.position.y=0.91
	HomesteadChildCraft.attach(head,"Face")
	for x in [-0.27,0.27]:
		ears.append(soft_form(head,Vector3(x,-0.025,0),Vector3(0.044,0.064,0.045),"d6a482"))
	for x in [-0.1,0.1]:
		var side="L" if x<0 else "R"
		var anchor="Eye"+side
		eye_whites.append(soft_form(head,HomesteadChildCraft.face_point(anchor,.007),Vector3(0.050,0.066,0.009),"fff9ed"))
		var eye=soft_form(head,HomesteadChildCraft.face_point(anchor,.015),Vector3(0.040,0.056,0.010),"4c443b")
		eyes.append(eye)
		pupils.append(soft_form(head,HomesteadChildCraft.face_point(anchor,.024)+Vector3(0,-.003,0),Vector3(0.014,0.026,0.0035),"28342f"))
		eye_glints.append(soft_form(head,HomesteadChildCraft.face_point(anchor,.030)+Vector3(-.008,.012,0),Vector3.ONE*.0045,"fff9ed"))
		soft_form(head,HomesteadChildCraft.face_point("Cheek"+side,.002),Vector3(.035,.020,.003),"d3987f")
	soft_form(head,HomesteadChildCraft.face_point("Nose",.007),Vector3(.027,.024,.023),"d6a17d")
	expression_root=Node3D.new()
	head.add_child(expression_root)
	grin_teeth=HomesteadMesh.ellipsoid(expression_root,HomesteadChildCraft.face_point("Grin",.004),Vector3(.065,.019,.005),"f7edd8")
	dimples=Node3D.new()
	head.add_child(dimples)
	for side in ["L","R"]: soft_form(dimples,HomesteadChildCraft.face_point("Dimple"+side,.002),Vector3(.005,.005,.003),"9f7156")
	# Curved, shallow smile and brows sit against the face rather than floating beads.
	for i in 10:
		HomesteadMesh.rod(expression_root,HomesteadChildCraft.face_point("Smile"+str(i),.002),HomesteadChildCraft.face_point("Smile"+str(i+1),.002),.0035,"8c604f")
	for side in [-1,1]:
		var brow=soft_form(head,HomesteadChildCraft.face_point("BrowL" if side<0 else "BrowR",.004),Vector3(.046,.008,.005),"695440")
		brow.rotation.z=side*-0.10
	hair_root=Node3D.new()
	head.add_child(hair_root)
	glasses_root=Node3D.new()
	head.add_child(glasses_root)
	for x in [-0.105,0.105]:
		var frame=HomesteadMesh.torus(glasses_root,HomesteadChildCraft.face_point("EyeL" if x<0 else "EyeR",.043),0.066,0.005,"514e48")
		frame.rotation.x=PI/2
	var bridge_z=HomesteadChildCraft.face_point("EyeL",.043).z
	HomesteadMesh.rod(glasses_root,Vector3(-.035,.018,bridge_z),Vector3(.035,.018,bridge_z),.005,"514e48")
	for side in [-1,1]:
		HomesteadMesh.rod(glasses_root,Vector3(side*.17,.025,.266),Vector3(side*.266,.01,.025),.004,"514e48")
	freckles_root=Node3D.new()
	head.add_child(freckles_root)
	for side in [-1,1]:
		for i in 3:
			soft_form(freckles_root,HomesteadChildCraft.face_point("Freckle"+("L" if side<0 else "R")+str(i),.002),Vector3(.0045,.0045,.0025),"9f7156")
	skirt=HomesteadChildCraft.attach(hips,"DressSkirt")
	scarf_root=HomesteadChildCraft.attach(hips,"Neckerchief")
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
	walk.length=WALK_CYCLE
	walk.loop_mode=Animation.LOOP_LINEAR
	# Match swing-end velocity to the planted foot, rather than snapping from
	# a zero-velocity smoothstep to a moving stance. Heel/toe contact lets the
	# pelvis ride higher without a crouch or sliding the shoe through the floor.
	var lean=.03
	var hip_track=[]
	var sway_track=[]
	var body_track=[]
	for i in 33:
		var time=float(i)/32
		var shift=cos(TAU*(time-0.3))
		hip_track.append([time*WALK_CYCLE,.686+.006*pow(sin(time*TAU),2)])
		sway_track.append([time*WALK_CYCLE,-.008*shift])
		body_track.append([time*WALK_CYCLE,Vector3(lean,0,.016*shift)])
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
			var stance=phase<STANCE_FRACTION
			var t=phase/STANCE_FRACTION if stance else (phase-STANCE_FRACTION)/(1.0-STANCE_FRACTION)
			var z=lerpf(STANCE_REACH,-STANCE_REACH,t)
			var roll=-.24*(1.0-smoothstep(0.0,.18,t))+.24*smoothstep(.72,1.0,t)
			if not stance:
				var tangent=-2.0*STANCE_REACH*(1.0-STANCE_FRACTION)/STANCE_FRACTION
				z=(2*t*t*t-3*t*t+1)*-STANCE_REACH+(t*t*t-2*t*t+t)*tangent+(-2*t*t*t+3*t*t)*STANCE_REACH+(t*t*t-t*t)*tangent
				roll=.24*cos(PI*t)
			var lift=0.0 if stance else pow(sin(t*PI),1.2)*.065
			var contact=maxf(.105*cos(roll)+.17*sin(roll),.105*cos(roll)-.09*sin(roll))
			var hip_y=.686+.006*pow(sin(time*TAU),2)
			var down=hip_y-(contact+lift)
			# Express the ground target in the forward-leaning hip frame.
			var lz=z*cos(lean)+down*sin(lean)
			var ld=down*cos(lean)-z*sin(lean)
			var distance=clampf(Vector2(lz,ld).length(),0.08,0.599)
			var hip_angle=-atan2(lz,ld)-acos(clampf((0.32*0.32+distance*distance-0.28*0.28)/(2*0.32*distance),-1,1))
			var knee_angle=PI-acos(clampf((0.32*0.32+0.28*0.28-distance*distance)/(2*0.32*0.28),-1,1))
			hip_keys.append([time*WALK_CYCLE,Vector3(hip_angle,0,0)])
			knee_keys.append([time*WALK_CYCLE,Vector3(knee_angle,0,0)])
			ankle_keys.append([time*WALK_CYCLE,Vector3(-hip_angle-knee_angle-lean+roll,0,0)])
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
			arm_keys.append([time*WALK_CYCLE,Vector3(swing*.28-lean,0,.045 if side==1 else -.045)])
			elbow_keys.append([time*WALK_CYCLE,Vector3(-.14-.20*maxf(0,-swing),0,0)])
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
	for knee in [left_knee,right_knee]: animation_track(idle,knee,"rotation",[[0,Vector3.ZERO],[4.8,Vector3.ZERO]])
	animation_track(idle,left_arm,"rotation",[[0,Vector3(0.02,0,-0.05)],[1.2,Vector3(0.03,0,-0.07)],[2.4,Vector3(-0.02,0,-0.04)],[3.6,Vector3(0.01,0,-0.06)],[4.8,Vector3(0.02,0,-0.05)]])
	animation_track(idle,right_arm,"rotation",[[0,Vector3(-0.02,0,0.04)],[1.2,Vector3(0.01,0,0.06)],[2.4,Vector3(0.03,0,0.07)],[3.6,Vector3(-0.01,0,0.05)],[4.8,Vector3(-0.02,0,0.04)]])
	for elbow in [left_elbow,right_elbow]:
		animation_track(idle,elbow,"rotation",[[0,Vector3(-0.10,0,0)],[2.4,Vector3(-0.14,0,0)],[4.8,Vector3(-0.10,0,0)]])
	animation_track(idle,hips,"position:y",[[0,0.705],[1.2,0.707],[2.4,0.705],[3.6,0.704],[4.8,0.705]])
	animation_track(idle,hips,"position:x",[[0,0.006],[1.2,0.006],[2.4,-0.006],[3.6,-0.006],[4.8,0.006]])
	animation_track(idle,hips,"rotation",[[0,Vector3(0,0,-0.015)],[1.2,Vector3(0,0,-0.015)],[2.4,Vector3(0,0,0.015)],[3.6,Vector3(0,0,0.015)],[4.8,Vector3(0,0,-0.015)]])
	library.add_animation("idle",idle)
	var wave=Animation.new()
	wave.length=2.4
	animation_track(wave,right_arm,"rotation",[[0,Vector3.ZERO],[0.4,Vector3(0,0,2.2)],[0.8,Vector3(0.3,0,2.5)],[1.15,Vector3(-0.3,0,2.1)],[1.5,Vector3(0.3,0,2.5)],[2.0,Vector3(0,0,2.2)],[2.4,Vector3.ZERO]])
	animation_track(wave,right_elbow,"rotation",[[0,Vector3(-.12,0,0)],[.4,Vector3(-.65,0,0)],[2.0,Vector3(-.65,0,0)],[2.4,Vector3(-.12,0,0)]])
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
	animation_track(carry,right_arm,"rotation",[[0,Vector3(-0.22,0,-0.09)],[WALK_CYCLE,Vector3(-0.22,0,-0.09)]])
	animation_track(carry,right_elbow,"rotation",[[0,Vector3(-0.65,0,0)],[WALK_CYCLE,Vector3(-0.65,0,0)]])
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
	# A small stepping pivot replaces spinning on frozen idle feet at corners.
	var turn=Animation.new()
	turn.length=.8
	turn.loop_mode=Animation.LOOP_LINEAR
	for side in 2:
		var leg_keys=[];var knee_keys=[];var ankle_keys=[]
		for i in 33:
			var t=float(i)/32
			var lift=maxf(0,sin(TAU*(t+side*.5)))*.035
			var down=.60-lift
			var thigh=-acos(clampf((.32*.32+down*down-.28*.28)/(.64*down),-1,1))
			var knee=PI-acos(clampf((.32*.32+.28*.28-down*down)/(.64*.28),-1,1))
			leg_keys.append([t*.8,Vector3(thigh,0,0)])
			knee_keys.append([t*.8,Vector3(knee,0,0)])
			ankle_keys.append([t*.8,Vector3(-thigh-knee,0,0)])
		animation_track(turn,left_leg if side==0 else right_leg,"rotation",leg_keys,Animation.INTERPOLATION_LINEAR)
		animation_track(turn,left_knee if side==0 else right_knee,"rotation",knee_keys,Animation.INTERPOLATION_LINEAR)
		animation_track(turn,left_ankle if side==0 else right_ankle,"rotation",ankle_keys,Animation.INTERPOLATION_LINEAR)
	library.add_animation("turn",turn)
	var carry_turn=turn.duplicate() as Animation
	animation_track(carry_turn,right_arm,"rotation",[[0,Vector3(-.22,0,-.09)],[.8,Vector3(-.22,0,-.09)]])
	animation_track(carry_turn,right_elbow,"rotation",[[0,Vector3(-.65,0,0)],[.8,Vector3(-.65,0,0)]])
	animation_track(carry_turn,can,"rotation",[[0,Vector3(.87,0,.09)],[.8,Vector3(.87,0,.09)]])
	library.add_animation("carry_turn",carry_turn)
	# Every clip owns a complete pose. Transition directly, without a one-frame
	# idle reset or a knee/arm rotation leaking from the previous activity.
	for name in library.get_animation_list():
		var clip=library.get_animation(name)
		for joint in [left_leg,right_leg,left_knee,right_knee,left_ankle,right_ankle,left_arm,right_arm,left_elbow,right_elbow,can]:
			var neutral=Vector3.ZERO
			if joint==left_arm: neutral=Vector3(0,0,-.045)
			elif joint==right_arm: neutral=Vector3(0,0,.045)
			elif joint==left_elbow or joint==right_elbow: neutral=Vector3(-.12,0,0)
			ensure_pose_track(clip,joint,"rotation",neutral)
		ensure_pose_track(clip,hips,"rotation",Vector3.ZERO)
		ensure_pose_track(clip,hips,"position:x",0.0)
		ensure_pose_track(clip,hips,"position:y",.705)
	animator.add_animation_library("",library)
	animator.play("idle")
func ensure_pose_track(clip: Animation,node: Node3D,property: String,value):
	var path=NodePath(str(get_path_to(node))+":"+property)
	for i in clip.get_track_count():
		if clip.track_get_path(i)==path: return
	animation_track(clip,node,property,[[0,value],[clip.length,value]])
func pose_track(clip: Animation,node: Node3D,property: String,keys: Array):
	var path=NodePath(str(get_path_to(node))+":"+property)
	for i in range(clip.get_track_count()-1,-1,-1):
		if clip.track_get_path(i)==path: clip.remove_track(i)
	animation_track(clip,node,property,keys)
func set_motion(next: String,speed=1.0):
	if carrying_water and next in ["walk","idle","turn"]: next={"walk":"carry","idle":"hold","turn":"carry_turn"}[next]
	can.visible=next in ["water","fill","carry","hold","carry_turn"]
	reading_book.visible=next=="read"
	if mode!=next:
		if next=="read": read_clock=0.0
		animator.play(next,0.22)
		mode=next
		if reduced_motion and next not in ["walk","carry","turn","carry_turn"]:
			animator.advance(0.3)
			animator.seek(1.0 if next=="wave" else 0.25,true)
	# The planted-foot travel sets playback speed for the saved forward scale.
	var stride_speed=(2.0*STANCE_REACH/(STANCE_FRACTION*WALK_CYCLE))*[.86,1.0,1.17][appearance.build]
	animator.speed_scale=maxf(0.05,speed/stride_speed) if next in ["walk","carry"] else 1.0
	if next in ["turn","carry_turn"]: animator.speed_scale=clampf(speed/1.8,.5,1.3)
func _process(delta):
	if not reduced_motion: clock+=delta
	if animator and mode not in ["walk","carry","turn","carry_turn"]: animator.speed_scale=0.0 if reduced_motion else 1.0
	var height_scale=[0.9,1.0,1.12][appearance.height]
	position.y=lerpf(position.y,(.60 if mode=="read" else .65)*(1.0-height_scale) if mode in ["sit","read"] else 0.0,minf(1,delta*12))
	if skirt_material:
		cloth_seated=lerpf(cloth_seated,1.0 if mode in ["sit","read"] else 0.0,minf(1,delta*8))
		skirt_material.set_shader_parameter("seated",cloth_seated)
		skirt_material.set_shader_parameter("moving",1.0 if mode in ["walk","carry"] and not reduced_motion else 0.0)
		skirt_material.set_shader_parameter("gait_phase",animator.current_animation_position*TAU/maxf(animator.current_animation_length,.1))
		skirt_material.set_shader_parameter("left_knee",hips.to_local(left_knee.global_position))
		skirt_material.set_shader_parameter("right_knee",hips.to_local(right_knee.global_position))
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
		glance_target=Vector2(look_rng.randf_range(-0.22,0.22),look_rng.randf_range(-0.06,0.08)) if look_rng.randf()>0.3 else Vector2.ZERO
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
	HomesteadChildCraft.attach(hair_root,("HatHair%d" if appearance.hat>0 else "Hair%d")%style)
	hair_style=style
	hair_under_cap=appearance.hat>0
func apply_appearance(raw: Dictionary):
	var normalized=HomesteadAppearance.normalize(raw)
	if head==null: return
	if appearance_applied and normalized==appearance: return
	appearance=normalized
	appearance_applied=true
	if hair_style!=appearance.hair or hair_under_cap!=(appearance.hat>0): build_hair(appearance.hair)
	var skin=HomesteadAppearance.SKINS[appearance.skin]
	var hair=HomesteadAppearance.HAIR_COLORS[appearance.hair_color]
	var top=HomesteadAppearance.TOPS[appearance.top]
	var bottom=HomesteadAppearance.BOTTOMS[appearance.bottom]
	var shoe=HomesteadAppearance.SHOES[appearance.shoes]
	var scarf=HomesteadAppearance.SCARVES[appearance.scarf]
	var palette={"e1b68f":skin,"dfb38c":skin,"d9af88":skin,"d6a482":Color(skin).darkened(0.04).to_html(false),"d6a17d":Color(skin).darkened(0.02).to_html(false),"83a89a":top,"729587":Color(top).darkened(.16).to_html(false),"b59562":skin if appearance.outfit==2 else bottom,"c3a36c":bottom,"695440":hair,"75604a":Color(hair).lightened(0.05).to_html(false),"975f48":shoe,"c58462":scarf,"4c443b":HomesteadAppearance.EYES[appearance.eye_color]}
	palette["d3987f"]=Color(skin).lerp(Color("d48772"),0.23).to_html(false)
	palette["8c604f"]=Color(skin).darkened(0.45).to_html(false)
	palette["9f7156"]=Color(skin).darkened(0.28).to_html(false)
	recolor(self,palette)
	skirt.visible=appearance.outfit==2
	for sleeve in long_sleeves: sleeve.visible=appearance.outfit in [1,5]
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

func cloth_surface(root: Node3D,color: String,is_skirt=false) -> ShaderMaterial:
	var material=ShaderMaterial.new()
	material.shader=preload("res://shaders/resident_cloth.gdshader")
	material.set_shader_parameter("cloth_color",Color(color))
	material.set_shader_parameter("trouser_color",Color(HomesteadAppearance.BOTTOMS[appearance.bottom]))
	material.set_shader_parameter("pattern",appearance.pattern)
	material.set_shader_parameter("outfit",appearance.outfit)
	material.set_shader_parameter("skirt",is_skirt)
	for surface in root.find_children("*","MeshInstance3D",true,false):
		surface.material_override=material
	return material

func update_wardrobe():
	for root in [wardrobe,headwear]:
		for child in root.get_children():
			root.remove_child(child)
			child.queue_free()
	var color=HomesteadAppearance.TOPS[appearance.top]
	cloth_material=cloth_surface(shirt_root,color)
	skirt_material=cloth_surface(skirt,HomesteadAppearance.BOTTOMS[appearance.bottom],true)
	if appearance.outfit==1:
		# A folded cowl sits behind the neckline instead of a vertical donut
		# crossing the face or a long hairstyle.
		var hood=garment(wardrobe,[[.48,.12,.085],[.54,.165,.12],[.63,.16,.105],[.67,.115,.065]],color)
		hood.position.z=-.10
	if appearance.outfit in [3,5]: HomesteadChildCraft.attach(wardrobe,"PoloCollar")
	if appearance.hat>0:
		HomesteadChildCraft.attach(headwear,"CapForward" if appearance.hat==1 else "CapBackward")
		recolor(headwear,{"83a89a":color,"729587":Color(color).darkened(.16).to_html(false)})
