extends SceneTree
# Authoring-only: one sharp, anti-aliased still of each production model for menus.
func _initialize(): call_deferred("run")
func bounds(node: Node3D, parent_transform=Transform3D.IDENTITY) -> AABB:
 var transform=parent_transform*node.transform
 var result=AABB()
 if node is MeshInstance3D and node.mesh: result=transform*node.get_aabb()
 for child in node.get_children():
  if child is Node3D:
   var child_bounds=bounds(child,transform)
   if child_bounds.size.length()>0: result=child_bounds if result.size.length()==0 else result.merge(child_bounds)
 return result
func run():
 var args=OS.get_cmdline_user_args()
 if args.is_empty(): quit(1); return
 var directory=args[0]
 DirAccess.make_dir_recursive_absolute(directory)
 root.transparent_bg=true; root.size=Vector2i(640,640); root.msaa_3d=Viewport.MSAA_8X; root.screen_space_aa=Viewport.SCREEN_SPACE_AA_FXAA
 var stage=Node3D.new(); root.add_child(stage)
 var light=DirectionalLight3D.new(); light.rotation_degrees=Vector3(-45,-35,0); light.light_energy=1.05; light.shadow_enabled=true; stage.add_child(light)
 var environment=WorldEnvironment.new(); var settings=Environment.new()
 settings.background_mode=Environment.BG_CLEAR_COLOR
 settings.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR; settings.ambient_light_color=Color("fff1db"); settings.ambient_light_energy=0.72
 environment.environment=settings; stage.add_child(environment)
 var camera=Camera3D.new(); camera.projection=Camera3D.PROJECTION_ORTHOGONAL; stage.add_child(camera)
 var builder=HomesteadPresentation.new(); stage.add_child(builder); builder.data=HomesteadWorldData.new(); builder.set_process(false)
 var entries: Array=HomesteadItems.DEFINITIONS.keys()
 # House attachments are scenes of their own, not catalogue kinds.
 entries.append_array(["house/kitchen_bench","house/front_porch","oven/cozy_outdoor_oven"])
 for key in entries:
  var model: Node3D
  if str(key).contains("/"):
   model=load("res://assets/"+str(key)+".glb").instantiate()
  else: model=builder.make_item(key,0)
  stage.add_child(model)
  var box=bounds(model); var center=box.get_center()
  camera.size=maxf(box.size.x,maxf(box.size.z,box.size.y))*1.5
  camera.position=center+Vector3(5,4,7); camera.look_at(center)
  for i in range(3): await process_frame
  await RenderingServer.frame_post_draw
  var image=root.get_texture().get_image(); image.convert(Image.FORMAT_RGBA8)
  var hero_name={"oven/cozy_outdoor_oven":"oven"}.get(str(key),str(key).get_file())
  image.save_png(directory+"/WorldPlace_"+hero_name+"_Hero.png")
  model.queue_free(); await process_frame
 print("PLACE_HEROES_RENDERED")
 quit()
