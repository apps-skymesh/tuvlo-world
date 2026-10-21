extends SceneTree
var output="/tmp/tuvlo-homestead-character-renders"
var failures=0
func _initialize(): call_deferred("run")
func run():
 if OS.get_cmdline_user_args().size()>0: output=OS.get_cmdline_user_args()[0]
 DirAccess.make_dir_recursive_absolute(output)
 var stage=Node3D.new()
 root.add_child(stage)
 var environment=WorldEnvironment.new()
 var settings=Environment.new()
 settings.background_mode=Environment.BG_COLOR
 settings.background_color=Color("e5e2d4")
 settings.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
 settings.ambient_light_color=Color("fff7ec")
 settings.ambient_light_energy=0.4
 environment.environment=settings
 stage.add_child(environment)
 var light=DirectionalLight3D.new()
 light.rotation_degrees=Vector3(-40,-35,0)
 light.light_energy=0.7
 stage.add_child(light)
 var camera=Camera3D.new()
 camera.projection=Camera3D.PROJECTION_ORTHOGONAL
 camera.size=2.8
 camera.position=Vector3(2.4,1.8,4.7)
 stage.add_child(camera)
 camera.look_at(Vector3(0,0.92,0))
 var model=HomesteadResidentModel.new()
 stage.add_child(model)
 await process_frame
 HomesteadMesh.cylinder(stage,Vector3(0,-0.04,0),1.0,0.07,"b8c79e")
 var cases=[]
 for hair in 13: cases.append({"name":"hair-%02d"%hair,"appearance":{"hair":hair,"outfit":0,"skin":hair%6,"hair_color":hair%5},"motion":"idle"})
 for outfit in 6: cases.append({"name":"outfit-%02d"%outfit,"appearance":{"hair":10,"outfit":outfit,"top":outfit,"accessory":1,"pattern":outfit%5},"motion":"idle"})
 for motion in ["walk","sit","water","wave"]:
  for outfit in 6: cases.append({"name":"motion-"+motion+"-outfit-%02d"%outfit,"appearance":{"hair":8,"outfit":outfit},"motion":motion})
 model.animator.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
 var bench=Node3D.new()
 stage.add_child(bench)
 var builder=HomesteadPresentation.new()
 builder.bench(bench)
 builder.free()
 var rig=model.rig
 for sample in cases:
  bench.visible=sample.motion=="sit"
  model.apply_appearance(sample.appearance)
  model.set_motion(sample.motion)
  model.animator.advance(0.5)
  model.animator.seek(1.0 if sample.motion=="wave" else 0.25,true)
  model.clock=0
  model.head.rotation=Vector3.ZERO
  for frame in 30: model._process(1.0/60.0)
  await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(output+"/"+sample.name+".png")
  if model.rig!=rig:
   failures+=1
   push_error("Character rig replaced")
 var manifest={"harnessSHA256":FileAccess.get_sha256("res://tests/render_matrix.gd"),"sceneSHA256":FileAccess.get_sha256("res://scripts/homestead.gd"),"engine":Engine.get_version_info(),"platform":OS.get_name(),"renderer":RenderingServer.get_video_adapter_name(),"cases":cases,"rigFailures":failures,"sourceHashes":{}}
 for name in ["resident_model","appearance","mesh_factory","presentation"]:
  manifest.sourceHashes[name]=FileAccess.get_sha256("res://scripts/"+name+".gd")
 var file=FileAccess.open(output+"/manifest.json",FileAccess.WRITE)
 file.store_string(JSON.stringify(manifest,"  "))
 print("HOMESTEAD_RENDER_MATRIX count=",cases.size()," failures=",failures," output=",output)
 stage.queue_free()
 await process_frame
 quit(0 if failures==0 else 1)
