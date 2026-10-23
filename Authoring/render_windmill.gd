extends SceneTree
# Authoring-only: catalogue art comes from the same model as the live scene.
func _initialize(): call_deferred("render")
func render():
 var output=OS.get_cmdline_user_args()[0]
 DirAccess.make_dir_recursive_absolute(output)
 root.transparent_bg=true
 var stage=Node3D.new()
 root.add_child(stage)
 var env=WorldEnvironment.new()
 var settings=Environment.new()
 settings.background_mode=Environment.BG_CLEAR_COLOR
 settings.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
 settings.ambient_light_color=Color("fff5df")
 settings.ambient_light_energy=0.6
 env.environment=settings
 stage.add_child(env)
 var light=DirectionalLight3D.new()
 light.rotation_degrees=Vector3(-42,-30,0)
 light.light_energy=0.8
 stage.add_child(light)
 var camera=Camera3D.new()
 camera.projection=Camera3D.PROJECTION_ORTHOGONAL
 camera.size=4.8
 camera.position=Vector3(5,4.2,7)
 stage.add_child(camera)
 camera.look_at(Vector3(0,1.8,0))
 var builder=HomesteadPresentation.new()
 stage.add_child(builder)
 for style in 2:
  var model=builder.make_item("windmill",0,true,style)
  stage.add_child(model)
  for frame in 5: await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(output+"/windmill-%d.png"%style)
  model.queue_free()
  await process_frame
 quit()
