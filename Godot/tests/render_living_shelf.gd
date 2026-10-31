extends SceneTree
# Authoring-only: fixed light/camera, actual production models, twelve baked poses.
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
 root.transparent_bg=true; root.size=Vector2i(192,192)
 var stage=Node3D.new(); root.add_child(stage)
 var light=DirectionalLight3D.new(); light.rotation_degrees=Vector3(-45,-35,0); light.light_energy=1.0; stage.add_child(light)
 var environment=WorldEnvironment.new(); var settings=Environment.new()
 settings.background_mode=Environment.BG_CLEAR_COLOR
 settings.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR; settings.ambient_light_color=Color("fff1db"); settings.ambient_light_energy=0.75
 environment.environment=settings; stage.add_child(environment)
 var camera=Camera3D.new(); camera.projection=Camera3D.PROJECTION_ORTHOGONAL; stage.add_child(camera)
 var builder=HomesteadPresentation.new(); stage.add_child(builder); builder.data=HomesteadWorldData.new(); builder.set_process(false)
 var entries=HomesteadItems.DEFINITIONS.keys()
 entries.append_array(["land_west","land_east","land_north"])
 for key in entries:
  var model: Node3D
  var asset="WorldPlace_"+key
  if str(key).begins_with("land_"):
   model=Node3D.new(); stage.add_child(model)
   builder.terrain_surface(model,HomesteadMesh.rounded_outline(12,12,0.14),true)
   match key:
    "land_west": builder.future_meadow(model)
    "land_east": builder.beach_cove(model,true)
    "land_north": builder.mountain_ridge(model)
   asset="WorldLand_"+str(key).trim_prefix("land_")
  else:
   model=builder.make_item(key,0); stage.add_child(model)
  var box=bounds(model); var center=box.get_center()
  camera.size=maxf(box.size.x,maxf(box.size.z,box.size.y))*1.65
  camera.position=center+Vector3(5,4,7); camera.look_at(center)
  var atlas=Image.create(768,576,false,Image.FORMAT_RGBA8)
  for frame in range(12):
   # A small reversible pose keeps every silhouette recognizable; no menu 3D.
   model.rotation.y=sin(frame*TAU/12.0)*0.065
   await process_frame; await RenderingServer.frame_post_draw
   var image=root.get_texture().get_image(); image.convert(Image.FORMAT_RGBA8)
   atlas.blit_rect(image,Rect2i(0,0,192,192),Vector2i((frame%4)*192,(frame/4)*192))
  atlas.save_png(directory+"/"+asset+"_Loop.png")
  model.queue_free(); await process_frame
 print("LIVING_SHELF_RENDERED count=",entries.size()," frames=12")
 quit()
