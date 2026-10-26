extends SceneTree
# Bounded CPU workload, not a device FPS or thermal benchmark.
func _initialize(): call_deferred("run")
func run():
 var data=HomesteadWorldData.new()
 data.land_sides.assign(["west","east"])
 for z in range(20):
  for x in range(20):
   data.items.append({"id":"path-%d-%d"%[x,z],"kind":"path","cell":Vector2i(x,z),"rotation":0})
 var nav=HomesteadNavigation.new()
 nav.rebuild(data)
 var reference=AStarGrid2D.new()
 reference.region=HomesteadItems.WORLD_BOUNDS
 reference.cell_size=Vector2.ONE
 reference.update()
 var samples=[]
 var optimized=[]
 for iteration in 7:
  var start=Time.get_ticks_usec()
  for z in range(HomesteadItems.WORLD_BOUNDS.position.y,HomesteadItems.WORLD_BOUNDS.end.y):
   for x in range(HomesteadItems.WORLD_BOUNDS.position.x,HomesteadItems.WORLD_BOUNDS.end.x):
    var cell=Vector2i(x,z)
    var occupied=data.item_at(cell)
    var blocked=not data.buildable(cell) or (not occupied.is_empty() and HomesteadItems.DEFINITIONS[occupied.kind].blocks)
    reference.set_point_solid(cell,blocked)
    reference.set_point_weight_scale(cell,0.8 if not occupied.is_empty() and occupied.kind=="path" else 1.0)
  samples.append(Time.get_ticks_usec()-start)
  start=Time.get_ticks_usec()
  nav.rebuild(data)
  optimized.append(Time.get_ticks_usec()-start)
 for cell in reference.get_point_path(Vector2i(0,0),Vector2i(19,19)):
  if not nav.open(Vector2i(cell)):
   push_error("Rasterized grid differs from reference")
   quit(1)
   return
 samples.sort()
 optimized.sort()
 print("WORLD_NAVIGATION_CPU_BENCHMARK items=400 samples=7 reference_median_us=%d rasterized_median_us=%d"%[samples[3],optimized[3]])
 quit()
