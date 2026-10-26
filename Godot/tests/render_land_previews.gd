extends SceneTree
# The Land menu shows the same authored terrain as the map.
func _initialize(): call_deferred("run")
func run():
	var args=OS.get_cmdline_user_args()
	if args.is_empty(): quit(1); return
	DirAccess.make_dir_recursive_absolute(args[0])
	root.transparent_bg=true
	root.size=Vector2i(384,384)
	var stage=Node3D.new()
	root.add_child(stage)
	var light=DirectionalLight3D.new()
	light.rotation_degrees=Vector3(-45,-35,0)
	light.light_energy=1.0
	stage.add_child(light)
	var environment=WorldEnvironment.new()
	var settings=Environment.new()
	settings.background_mode=Environment.BG_CLEAR_COLOR
	settings.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color=Color("fff1db")
	settings.ambient_light_energy=0.75
	environment.environment=settings
	stage.add_child(environment)
	var camera=Camera3D.new()
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	stage.add_child(camera)
	var builder=HomesteadPresentation.new()
	stage.add_child(builder)
	builder.set_process(false)
	for side in ["west","east","north"]:
		var model=Node3D.new()
		stage.add_child(model)
		builder.terrain_surface(model,HomesteadMesh.rounded_outline(12,12,0.14),true)
		match side:
			"west": builder.future_meadow(model)
			"east": builder.beach_cove(model,true)
			"north": builder.mountain_ridge(model)
		var center=Vector3(2 if side=="east" else 0,1.3 if side=="north" else 0,0)
		camera.size=20 if side=="east" else 18
		camera.position=center+Vector3(10,12,16)
		camera.look_at(center)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(args[0]+"/WorldLand_"+side+".png")
		stage.remove_child(model)
		model.queue_free()
	print("HOMESTEAD_LAND_THUMBNAILS count=3")
	quit()
