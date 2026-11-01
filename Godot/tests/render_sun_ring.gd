extends SceneTree
func _initialize(): call_deferred("run")
func run():
 var args=OS.get_cmdline_user_args()
 if args.is_empty(): quit(1); return
 root.size=Vector2i(800,300)
 var env=WorldEnvironment.new();var settings=Environment.new()
 settings.background_mode=Environment.BG_COLOR;settings.background_color=Color("f3ebd6");env.environment=settings;root.add_child(env)
 var stage=Node3D.new();root.add_child(stage)
 var camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=3.8;camera.position=Vector3(1.25,3.4,5);stage.add_child(camera);camera.look_at(Vector3.ZERO)
 var builder=HomesteadPresentation.new();builder.data=HomesteadWorldData.new();stage.add_child(builder)
 builder.production_root=Node3D.new();builder.add_child(builder.production_root);builder.set_process(false)
 for index in 3:
  var bubble=builder.make_status_bubble();bubble.position=Vector3((index-1)*1.25,0,0)
  var material: ShaderMaterial=bubble.get_meta("material")
  material.set_shader_parameter("production_state",index)
  material.set_shader_parameter("progress",0.42)
  material.set_shader_parameter("smooth_progress",false)
  bubble.get_meta("label").text="0:18" if index==1 else ""
 await process_frame;await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(args[0])
 print("SUN_RING_RENDERED states=3")
 quit()
