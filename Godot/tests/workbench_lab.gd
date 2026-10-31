extends "res://tests/mac_playground.gd"
# Disposable visual host. No family, inventory journal, recipe timer or save.
var loaded=[]
var pointer_key=""
var start_point=Vector2.ZERO
var lab_id="mac-workbench"
var lab_quiet=false
var building_lab=false
var resource_keys=["flour-0","fruit-0","fruit-1"]
func run():
 await super.run()
 capture_times=[]; duration=0.0
 root.always_on_top=true; root.grab_focus()
 root.window_input.connect(_lab_input)
 if "--building" in OS.get_cmdline_user_args():
  building_lab=true; resource_keys=["material-food-0"]
 if "--empty-building" in OS.get_cmdline_user_args():
  building_lab=true; resource_keys=[]
 if "--loaded" in OS.get_cmdline_user_args(): loaded=resource_keys.duplicate()
 send("lifecycle",{"paused":true,"previewing":true})
 bench_state()
 var layer=CanvasLayer.new(); layer.layer=10; root.add_child(layer)
 var bar=HBoxContainer.new(); bar.position=Vector2(16,62); layer.add_child(bar)
 button(bar,"Load",func(): loaded=resource_keys.duplicate(); bench_state())
 button(bar,"Pull",preview_craft)
 button(bar,"Reset",func(): loaded=[]; bench_state())
 button(bar,"Capture",func(): save_bench())
 if "--review" in OS.get_cmdline_user_args():
  await create_timer(1.0).timeout
  await save_bench("satchel")
  loaded=resource_keys.duplicate(); bench_state()
  await create_timer(1.0).timeout
  await save_bench("loaded")
  preview_craft()
  await create_timer(0.22).timeout
  await save_bench("press")
  lab_quiet=true; bench_state(); preview_craft()
  await create_timer(0.3).timeout
  var quiet=world.workbench.burst==0 and not world.workbench.heat.visible and world.workbench.flash.light_energy==0
  for spark in world.workbench.sparks: quiet=quiet and not spark.visible
  print("WORKBENCH_REVIEW reduceMotionQuiet=",quiet)
  await save_bench("reduce-motion")
  root.size=Vector2i(900,500)
  await create_timer(0.5).timeout
  var refitted=world.workbench.last_size==Vector2i(root.get_visible_rect().size)
  print("WORKBENCH_REVIEW resized=",refitted)
  await save_bench("window")
  await create_timer(14.5).timeout
  quit(0 if quiet and refitted else 1)
  return
 if output!="":
  await create_timer(1.0).timeout
  save_bench()

func bench_state():
 var ingredients=[]
 for key in resource_keys:
  ingredients.append({"key":key,"good":key.trim_prefix("material-").get_slice("-",0),"loaded":key in loaded,"available":true,"quantity":3 if building_lab else 1})
 send("workbench",{"id":lab_id,"recipe":"nook" if building_lab else "tart","output":"plan" if building_lab else "tart","state":0,"tokens":ingredients,"reducedMotion":lab_quiet})
func preview_craft():
 if loaded.size()!=resource_keys.size(): return
 send("workbenchCelebrate",{"id":lab_id,"at":Time.get_unix_time_from_system()})
func save_bench(label="workbench"):
 if output=="": return
 world.wake_workbench()
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(output+"/"+label+".png")
func _lab_input(event):
 if world==null or not world.workbench.visible: return
 if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
  if event.pressed:
   start_point=event.position
   var point=event.position/Vector2(root.size)
   for key in world.workbench.tokens:
    var i=world.workbench.token_data.find(world.workbench.token_data.filter(func(data): return data.key==key)[0])
    var rect=world.workbench.anchor(world.workbench.token_position(i,key in loaded),Vector2(.72,.72))
    if Rect2(rect.x,rect.y,rect.w,rect.h).has_point(point): pointer_key=key; return
   var rect=world.workbench.anchor(Vector3(3.25,2.3,0),Vector2(1,1.8))
   if Rect2(rect.x,rect.y,rect.w,rect.h).has_point(point): pointer_key="lever"
  else:
   if pointer_key=="lever" and event.position.y-start_point.y>=40: preview_craft()
   elif not pointer_key.is_empty():
    var rect=world.workbench.anchor(Vector3(0,2,0),Vector2(3.3,1.2))
    if Rect2(rect.x,rect.y,rect.w,rect.h).has_point(event.position/Vector2(root.size)) and not pointer_key in loaded: loaded.append(pointer_key)
   pointer_key=""; bench_state()
 if event is InputEventMouseMotion and not pointer_key.is_empty():
  if pointer_key=="lever": send("workbenchPull",{"id":lab_id,"pull":clampf((event.position.y-start_point.y)/54.0,0,1)})
  else: send("workbenchDrag",{"id":lab_id,"key":pointer_key,"x":event.position.x/root.size.x,"y":event.position.y/root.size.y})
