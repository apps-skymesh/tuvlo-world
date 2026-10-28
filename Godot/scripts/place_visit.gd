class_name HomesteadPlaceVisit
extends RefCounted

# Read-only activity choreography inside an owned place's existing footprint.
# Ground routing remains authoritative; only authored seats/ladders enter it.
var kind=""
var phase=""
var elapsed=0.0
var ground=Vector3.ZERO
var origin=Vector3.ZERO
var start=Vector3.ZERO
var rotation=0.0
var exiting=false
var pending_id=""

func point(local: Vector3) -> Vector3:
 return origin+local.rotated(Vector3.UP,rotation)

func begin(actor,target: Dictionary) -> bool:
 kind=target.kind
 origin=HomesteadItems.item_center(target)
 rotation=target.rotation*PI/2
 var entry=point(Vector3(0,0,1.3 if kind=="nook" else 1.85))
 var local=(actor.position-origin).rotated(Vector3.UP,-rotation)
 if local.z<1.0 or absf(local.x)>.8 or actor.position.distance_to(entry)>1.1 or not actor.navigation.open(HomesteadItems.cell_at(entry)): return false
 ground=actor.position
 actor.state="place_activity"
 actor.route.clear()
 actor.speed=0
 advance(actor,"seat_approach" if kind=="nook" else "ladder_approach")
 actor.announce("Finding a book" if kind=="nook" else "Climbing to the treehouse")
 return true

func advance(actor,next: String):
 phase=next
 elapsed=0
 start=actor.position

func leave(actor,id=""):
 exiting=true
 pending_id=id
 if kind=="nook":
  if phase in ["seat_approach","seat_turn"]: advance(actor,"seat_leave")
  elif phase in ["sit","reading"]: advance(actor,"stand")
 else:
  if phase=="ladder_approach": advance(actor,"ladder_leave")
  elif phase=="climb": advance(actor,"descend")
  elif phase in ["step_on","deck"]: advance(actor,"deck_return")

func move(actor,destination: Vector3,seconds: float,motion: String) -> bool:
 var amount=clampf(elapsed/seconds,0,1)
 actor.position=start.lerp(destination,smoothstep(0,1,amount))
 actor.model.set_motion(motion,.6)
 if motion=="walk" and destination.distance_to(start)>.01:
  var direction=destination-start
  actor.desired_facing=atan2(direction.x,direction.z)
 return amount>=1

func finish(actor) -> bool:
 actor.position=ground if actor.navigation.open(HomesteadItems.cell_at(ground)) else HomesteadItems.cell_center(actor.navigation.closest(actor.position))
 actor.model.set_motion("idle")
 actor.model.foot_shadow.visible=true
 actor.state="pause"
 actor.timer=1.0
 return true

func tick(actor,delta: float) -> bool:
 elapsed+=delta
 actor.model.foot_shadow.visible=phase not in ["climb","descend","ladder_turn"]
 match phase:
  "seat_approach":
   if move(actor,point(Vector3(-.25,0,.58)),1.35,"walk"): advance(actor,"seat_turn")
  "seat_turn":
   actor.desired_facing=rotation
   actor.model.set_motion("idle")
   if elapsed>=.65: advance(actor,"sit")
  "sit":
   actor.desired_facing=rotation
   if move(actor,point(Vector3(-.25,0,.025)),.65,"read"):
    advance(actor,"reading")
    actor.announce("Reading a favorite book")
  "reading":
   actor.model.set_motion("read")
   if elapsed>=6.0*actor.activity_scale or exiting: advance(actor,"stand")
  "stand":
   if move(actor,point(Vector3(-.25,0,.58)),.7,"idle"): advance(actor,"seat_leave")
  "seat_leave":
   if move(actor,ground,1.3,"walk"): return finish(actor)
  "ladder_approach":
   if move(actor,point(Vector3(0,0,1.64)),.8,"walk"): advance(actor,"climb")
  "climb":
   actor.desired_facing=rotation+PI
   if move(actor,point(Vector3(0,2.17,1.38)),3.6,"climb"): advance(actor,"step_on")
  "step_on":
   if move(actor,point(Vector3(0,2.17,.98)),.75,"walk"): advance(actor,"deck")
  "deck":
   actor.desired_facing=rotation
   actor.model.set_motion("wave" if elapsed<2.4 else "idle")
   if elapsed>=3.6*actor.activity_scale or exiting:
    actor.announce("Heading back down")
    advance(actor,"deck_return")
  "deck_return":
   if move(actor,point(Vector3(0,2.17,1.38)),.8,"walk"): advance(actor,"ladder_turn")
  "ladder_turn":
   actor.desired_facing=rotation+PI
   actor.model.set_motion("idle")
   if elapsed>=.65: advance(actor,"descend")
  "descend":
   actor.desired_facing=rotation+PI
   if move(actor,point(Vector3(0,0,1.64)),3.6,"climb"): advance(actor,"ladder_leave")
  "ladder_leave":
   if move(actor,ground,.8,"walk"): return finish(actor)
 return false
