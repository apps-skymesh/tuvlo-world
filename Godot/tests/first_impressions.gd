extends SceneTree
# Read-only scene storyboard: no accounts, prices, claims or saved-family data.
var world
var output="/private/tmp/tuvlo-first-impressions/storyboard"
func _initialize(): call_deferred("run")
func run():
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
 DirAccess.make_dir_recursive_absolute(output)
 world=load("res://scenes/homestead.tscn").instantiate()
 root.add_child(world)
 await process_frame
 var cottage={"id":"cottage","kind":"cottage","cell":{"x":3,"z":2},"rotation":0}
 var tree={"id":"tree","kind":"tree","cell":{"x":12,"z":2},"rotation":0}
 var garden={"id":"garden","kind":"garden","cell":{"x":2,"z":10},"rotation":0}
 var mill={"id":"mill","kind":"windmill","cell":{"x":10,"z":10},"rotation":0}
 var items=[]
 for stage in 6:
  if stage==1: items.append(cottage)
  if stage==2:
   items.append_array([tree,garden])
   for z in range(5,11): items.append({"id":"path:%d"%z,"kind":"path","cell":{"x":5,"z":z},"rotation":0})
  if stage==3: items.append(mill)
  var payload={"items":items,"land":[],"reducedMotion":true,"ovenRevealed":stage>=4,"approvedWins":0 if stage<3 else 6,"edges":stage>=2,"growthTreeID":"tree","appearance":{"hair":3,"outfit":0},"farmStages":[0,0] if stage<3 else [4,4]}
  world.receive_host_json(JSON.stringify({"version":1,"session":"opening-storyboard","type":"snapshot","payload":payload}))
  world.receive_host_json(JSON.stringify({"version":1,"session":"opening-storyboard","type":"camera","payload":{"mode":"arrival","resetZoom":true}}))
  world.set_paused(false)
  await process_frame
  world._process(0.1)
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(output+"/stage-%d.png"%stage)
  if stage==2:
   world.receive_host_json(JSON.stringify({"version":1,"session":"opening-storyboard","type":"camera","payload":{"mode":"overview","resetZoom":true}}))
   await process_frame
   world._process(0.1)
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png(output+"/overview.png")
 print("WORLD_OPENING_STORYBOARD stages=6 source=actual-Godot-models persistence=none")
 quit()
