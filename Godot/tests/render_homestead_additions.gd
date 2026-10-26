extends SceneTree
# Real model thumbnails; no separate illustrative representation.
func _initialize(): call_deferred("run")
func run():
	var args=OS.get_cmdline_user_args()
	if args.is_empty(): quit(1); return
	var directory=args[0]
	DirAccess.make_dir_recursive_absolute(directory)
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
	for kind in ["barn","doghouse","grill"]:
		var model=builder.make_item(kind,0)
		stage.add_child(model)
		var center=Vector3(0,1.1 if kind=="barn" else 0.55,0)
		camera.size=5.1 if kind=="barn" else 2.6
		camera.position=center+Vector3(5,4,7)
		camera.look_at(center)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(directory+"/WorldPlace_"+kind+".png")
		stage.remove_child(model)
		model.queue_free()
	builder.set_process(false)
	print("HOMESTEAD_ADDITIONS_THUMBNAILS count=3")
	quit()
