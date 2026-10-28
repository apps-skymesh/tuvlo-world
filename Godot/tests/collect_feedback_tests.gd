extends SceneTree
var failures=0
func check(v: bool,m: String):
 if not v:
  failures+=1
  push_error(m)
func _initialize(): call_deferred("run")
func snap(scene,harvest,rm=false):
 var items=[{"id":"cottage","kind":"cottage","cell":{"x":3,"z":2},"rotation":0},{"id":"garden","kind":"garden","cell":{"x":2,"z":10},"rotation":0}]
 var payload={"items":items,"land":[],"appearance":{"hair":3},"approvedWins":21,"discovered":false,"harvest":harvest,"edges":true,"reducedMotion":rm}
 scene.receive_host_json(JSON.stringify({"version":1,"session":"probe","type":"snapshot","payload":payload}))
func run():
 var scene=load("res://scenes/homestead.tscn").instantiate()
 root.add_child(scene)
 await process_frame
 snap(scene,{"woods":"wood","garden":"food"})
 for i in 3: await process_frame
 var p=scene.presentation
 check(p.bubbles.size()==2,"two bubbles: %d"%p.bubbles.size())
 var face=p.bubbles[0].get_child(0)
 check(face.scale.is_equal_approx(Vector3.ONE),"first snapshot has no pop-in")
 p.mark_collecting("woods")
 snap(scene,{"garden":"food","quarry":"stone"})
 await process_frame
 check(p.bubbles.size()==2,"bubbles rebuilt: %d"%p.bubbles.size())
 var flying=p.harvest_root.get_children().filter(func(n): return not p.bubbles.has(n) and not n.is_queued_for_deletion())
 check(flying.size()==1,"one bubble flies: %d"%flying.size())
 var newface=null
 for b in p.bubbles:
  if b.get_meta("producer_key")=="quarry": newface=b.get_child(0)
 check(newface!=null and newface.scale.x<0.5,"new bubble pops in")
 var start=flying[0].global_position
 for i in 20: await create_timer(0.05).timeout
 check(newface.scale.is_equal_approx(Vector3.ONE),"pop-in settles")
 check(not is_instance_valid(flying[0]) or flying[0].is_queued_for_deletion(),"flight frees itself")
 # garden visit without collection: tap pulse settles back
 p.mark_collecting("garden")
 snap(scene,{"garden":"food","quarry":"stone"})
 for i in 40: await create_timer(0.05).timeout
 for b in p.bubbles:
  check(b.get_child(0).scale.is_equal_approx(Vector3.ONE),"tap pulse settles")
 # reduced motion: removed bubble is freed at once
 snap(scene,{"garden":"food","quarry":"stone"},true)
 await process_frame
 p.mark_collecting("quarry")
 snap(scene,{"garden":"food"},true)
 await process_frame
 var left=p.harvest_root.get_children().filter(func(n): return not n.is_queued_for_deletion())
 check(left.size()==1,"reduced motion frees at once: %d"%left.size())
 print("COLLECT_FEEDBACK_TESTS failures=%d"%failures)
 quit()
