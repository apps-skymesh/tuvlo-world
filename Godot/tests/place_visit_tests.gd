extends RefCounted

static func fixture(scene,rotation=0,quiet=false) -> Dictionary:
 scene.clear_host_session()
 var payload={"items":[
  {"id":"nook","kind":"nook","cell":{"x":3,"z":8},"rotation":rotation},
  {"id":"treehouse","kind":"treehouse","cell":{"x":10,"z":5},"rotation":rotation},
  {"id":"cottage","kind":"cottage","cell":{"x":3,"z":2},"rotation":0}],
  "land":[],"appearance":{"hair":3},"approvedWins":21,"reducedMotion":quiet}
 snapshot(scene,payload)
 return payload

static func snapshot(scene,payload: Dictionary,session="place-audit"):
 scene.receive_host_json(JSON.stringify({"version":1,"session":session,"type":"snapshot","payload":payload}))

static func start(scene,kind: String):
 var actor=scene.resident
 actor.position=scene.navigation.approach(scene.data.find(kind))
 actor.visit(kind)

static func tick(actor):
 actor._physics_process(.05)
 actor.model.animator.advance(.05)
 actor.model._process(.05)

static func until(actor,phase: String,limit=800) -> bool:
 for i in limit:
  if (actor.place_visit.phase if actor.place_visit!=null else actor.state)==phase: return true
  tick(actor)
 return false

static func run(scene,expect: Callable):
 var actor=scene.resident
 for rotation in 4:
  for kind in ["nook","treehouse"]:
   fixture(scene,rotation)
   start(scene,kind)
   var ground=actor.position
   expect.call(until(actor,"reading" if kind=="nook" else "deck"),"Place visit reaches authored activity at rotation "+str(rotation)+": "+kind)
   var original=actor.place_visit
   if original==null: continue
   var position=actor.position
   scene.set_paused(true,true)
   expect.call(not actor.is_physics_processing(),"Native menu pauses authored interaction")
   expect.call(actor.position==position and actor.place_visit==original,"Menu pause retains exact interaction phase and position")
   scene.set_paused(false)
   actor.world_changed()
   expect.call(actor.place_visit==original and actor.position==position,"Unrelated world update preserves seated/elevated occupancy")
   if kind=="nook":
    tick(actor)
    scene.presentation.set_reading_place("nook")
    var book=scene.presentation.nodes.nook.get_meta("seat_book")
    expect.call(actor.model.reading_book.visible and not book.visible,"Reading replaces resting book without hiding the nook")
   else:
    expect.call(is_equal_approx(actor.position.y,2.17),"Treehouse greeting stays on the authored deck")
   expect.call(until(actor,"pause"),"Place visit exits completely: "+kind)
   expect.call(actor.position.is_equal_approx(ground) and scene.navigation.open(HomesteadItems.cell_at(actor.position)),"Normal exit returns to original walkable approach")
   expect.call(not actor.model.reading_book.visible and actor.model.foot_shadow.visible,"Exit restores idle props and ground shadow")
 # A blocked authored front must not turn a side approach into wall traversal.
 for rotation in 4:
  var payload=fixture(scene,rotation)
  var target=scene.data.find("treehouse")
  var angle=rotation*PI/2
  for x in [-1,0,1]:
   var cell=HomesteadItems.cell_at(HomesteadItems.item_center(target)+Vector3(x,0,1.85).rotated(Vector3.UP,angle))
   payload.items.append({"id":"block"+str(x),"kind":"rocks","cell":{"x":cell.x,"z":cell.y},"rotation":0})
  snapshot(scene,payload)
  start(scene,"treehouse")
  expect.call(until(actor,"look") and actor.place_visit==null and is_zero_approx(actor.position.y),"Blocked ladder front keeps a ground visit at rotation "+str(rotation))
 # Requesting another place midway through ascent descends before rerouting.
 fixture(scene)
 start(scene,"treehouse")
 expect.call(until(actor,"climb"),"Interrupt fixture reaches climb")
 for i in 28: tick(actor)
 expect.call(actor.position.y>0,"Interrupt fixture is elevated")
 actor.visit("nook")
 expect.call(actor.target_id=="treehouse" and actor.place_visit!=null,"A new tap cannot start ground walking in midair")
 expect.call(until(actor,"walking"),"Queued visit resumes after ladder return")
 expect.call(is_zero_approx(actor.position.y) and actor.target_id=="nook","Queued ground route begins only after descent")
 # Moving, rotating, storing/deleting, or starting construction invalidates play.
 for change in ["move","rotate","remove","construction"]:
  var payload=fixture(scene)
  start(scene,"treehouse")
  expect.call(until(actor,"deck"),"Changed-place fixture reaches deck")
  if change=="move": payload.items[1].cell={"x":13,"z":5}
  elif change=="rotate": payload.items[1].rotation=1
  elif change=="remove": payload.items.remove_at(1)
  else: payload.construction=[{"placeID":"treehouse","kind":"treehouse","progress":.2,"remaining":20}]
  snapshot(scene,payload)
  expect.call(actor.place_visit==null and is_zero_approx(actor.position.y) and scene.navigation.open(HomesteadItems.cell_at(actor.position)),"Changed or unavailable place safely cancels elevated visit: "+change)
 # Session switching and teardown must never keep a child above another world.
 var child_payload=fixture(scene)
 start(scene,"treehouse")
 until(actor,"deck")
 snapshot(scene,child_payload,"other-child")
 expect.call(actor.place_visit==null and is_zero_approx(actor.position.y),"Changing child clears elevated activity")
 fixture(scene)
 start(scene,"nook")
 until(actor,"reading")
 scene.clear_host_session()
 expect.call(actor.place_visit==null and not actor.model.reading_book.visible,"Session teardown clears held book and activity")
 # Reduce Motion quiets reading and avoids starting a new decorative climb.
 fixture(scene,0,true)
 start(scene,"treehouse")
 expect.call(until(actor,"look") and actor.place_visit==null,"Reduce Motion uses a ground treehouse visit")
 start(scene,"nook")
 expect.call(until(actor,"reading"),"Reduce Motion retains seated reading")
 actor.model.blink_left=.1
 tick(actor)
 expect.call(actor.model.eye_glints[0].visible,"Reduce Motion cannot freeze the reader's eyes shut")
 expect.call(not actor.model.turning_page.visible and actor.model.head.rotation.x>.3,"Quiet reading retains book attention without page animation")
 fixture(scene)
 start(scene,"treehouse")
 until(actor,"climb")
 for i in 20: tick(actor)
 actor.reduced_motion=true
 expect.call(until(actor,"pause") and is_zero_approx(actor.position.y),"Reduce Motion enabled during ascent returns to ground")
 # Every saved height/build keeps a seated drape with its waist attached.
 # Cloth now deforms on its surface; rotating the whole skirt detaches the waist.
 fixture(scene)
 for height in 3:
  for build in 3:
   actor.model.apply_appearance({"height":height,"build":build,"outfit":2})
   actor.model.set_motion("read")
   for i in 20:
    actor.model.animator.advance(.05)
    actor.model._process(.05)
   expect.call(actor.model.skirt.position.is_zero_approx() and actor.model.skirt.rotation.is_zero_approx() and actor.model.skirt_material.get_shader_parameter("seated")>.95,"Seated reading drapes the cloth while keeping its waist attached")
 scene.clear_host_session()
