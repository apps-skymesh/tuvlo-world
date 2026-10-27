extends SceneTree
var failures=0
func check(value: bool,message: String):
 if not value:
  failures+=1
  push_error(message)
func _initialize(): call_deferred("run")
func run():
 var scene=load("res://scenes/homestead.tscn").instantiate()
 root.add_child(scene)
 await process_frame
 var items=[
  {"id":"cottage","kind":"cottage","cell":{"x":3,"z":2},"rotation":0},
  {"id":"garden","kind":"garden","cell":{"x":2,"z":10},"rotation":0},
  {"id":"bench","kind":"bench","cell":{"x":8,"z":10},"rotation":0},
  {"id":"pond","kind":"pond","cell":{"x":11,"z":7},"rotation":0}
 ]
 var payload={"items":items,"land":[],"appearance":{"hair":3},"approvedWins":21,"discovered":false}
 var packet={"version":1,"session":"test-child-session","type":"snapshot","payload":payload}
 scene.receive_host_json(JSON.stringify(packet))
 check(scene.data.items.size()==4,"Host snapshot must replace empty scene")
 # Imported child surfaces retain every saved choice and independent palettes.
 var child_model=scene.resident.model
 for style in 13:
  child_model.apply_appearance({"hair":style,"outfit":style%6,"skin":4,"hair_color":2,"top":3,"bottom":4,"shoes":2})
  var hair_surfaces=child_model.hair_root.find_children("*","MeshInstance3D",true,false)
  check(not hair_surfaces.is_empty() and hair_surfaces.size()<=2,"Every saved hairstyle has fitted, consolidated art")
  for surface in hair_surfaces:
   check(surface.material_override.albedo_color.is_equal_approx(Color(HomesteadAppearance.HAIR_COLORS[2])),"Imported hair follows saved color after switching styles")
   check(surface.material_override.vertex_color_use_as_albedo,"Recoloring preserves authored vertex paint")
  check(child_model.outfit_details.visible==(style%6==4) and child_model.skirt.visible==(style%6==2),"All six outfits retain their saved visibility rules")
 var guest_model=HomesteadResidentModel.new()
 root.add_child(guest_model)
 guest_model.apply_appearance({"hair":12,"hair_color":0,"skin":0})
 var first_hair=child_model.hair_root.find_children("*","MeshInstance3D",true,false)[0]
 check(first_hair.material_override.albedo_color.is_equal_approx(Color(HomesteadAppearance.HAIR_COLORS[2])),"A second resident cannot recolor shared cached child geometry")
 check(child_model.can.get_parent()==child_model.right_elbow,"Imported hands preserve the watering-can joint")
 for surface in child_model.find_children("*","MeshInstance3D",true,false):
  if surface.get_meta("original_color","")=="e1b68f":
   check(surface.material_override.albedo_color.is_equal_approx(Color(HomesteadAppearance.SKINS[4])),"Sculpted face follows saved skin color independently of guests")
 guest_model.free()
 child_model.apply_appearance(payload.appearance)
 # Animal buildings use real footprints and validated, distinct producer links.
 var animal_payload=payload.duplicate(true)
 animal_payload.items.append_array([
  {"id":"barn","kind":"barn","cell":{"x":14,"z":1},"rotation":0},
  {"id":"doghouse","kind":"doghouse","cell":{"x":15,"z":6},"rotation":0},
  {"id":"grill","kind":"grill","cell":{"x":15,"z":10},"rotation":0}])
 animal_payload.production=[{"placeID":"barn","station":"barn","good":"meat","state":1,"remaining":90,"progress":0.0},{"placeID":"grill","station":"grill","good":"meal","state":0,"remaining":0,"progress":0.0}]
 var animal_data=HomesteadWorldData.new()
 check(animal_data.apply_snapshot(animal_payload),"Barn and grill accept their own production links")
 var wrong_animal=animal_payload.duplicate(true)
 wrong_animal.production[0].placeID="doghouse"
 check(not HomesteadWorldData.new().apply_snapshot(wrong_animal),"Dog house cannot impersonate meat production")
 scene.receive_host_json(JSON.stringify({"version":1,"session":"test-child-session","type":"snapshot","payload":animal_payload}))
 check(scene.presentation.pet_parts.size()>=4,"Saved barn and dog house contain live animal parts")
 var dog_art=scene.presentation.nodes.doghouse
 scene.receive_host_json(JSON.stringify({"version":1,"session":"test-child-session","type":"snapshot","payload":animal_payload}))
 check(scene.presentation.nodes.doghouse==dog_art,"Timer updates retain animal artwork and animation pivots")
 var flock=scene.presentation.pet_parts.filter(func(part): return part.get_meta("livestock",false))
 check(flock.size()==1,"The barn contains one renewable livestock flock")
 if flock.size()==1:
  var young_size=flock[0].scale.x
  var grown=animal_payload.duplicate(true)
  grown.production[0].state=2
  grown.production[0].remaining=0
  grown.production[0].progress=1.0
  scene.reduced_motion=true
  scene.receive_host_json(JSON.stringify({"version":1,"session":"test-child-session","type":"snapshot","payload":grown}))
  check(flock[0].scale.x>young_size,"Ready livestock is visibly grown even without animation frames")
  grown.production[0].state=0
  grown.production[0].progress=0.0
  scene.receive_host_json(JSON.stringify({"version":1,"session":"test-child-session","type":"snapshot","payload":grown}))
  check(is_equal_approx(flock[0].scale.x,young_size),"Collecting starts the next young flock")
  scene.reduced_motion=false

 # Woods and quarry share the mainland turf, without becoming free building land.
 var connected=payload.duplicate(true)
 connected.edges=true
 scene.receive_host_json(JSON.stringify({"version":1,"session":"test-child-session","type":"snapshot","payload":connected}))
 var mainland=scene.presentation.land_root.get_node("StartingLand")
 var connected_lawns=[]
 for part in mainland.get_children():
  if part.has_meta("ground_outline"): connected_lawns.append(part.get_meta("ground_outline"))
 check(connected_lawns.size()==1,"Resource terrain must be one continuous mainland surface")
 if connected_lawns.size()==1:
  for point in [Vector2(-14.2,8),Vector2(16.2,8),Vector2(-9.6,8),Vector2(11.6,8)]:
   check(Geometry2D.is_point_in_polygon(point,connected_lawns[0]),"Resource roots and their necks are joined to the mainland")
 check(not scene.data.buildable(Vector2i(-1,16)),"A scenic resource neck does not grant extra buildable land")
 check(scene.presentation.land_root.get_node("Land_north/FutureMountainRidge")!=null,"Locked north hints at a mountain journey")
 check(scene.presentation.land_root.get_node("Land_east/BeachCove")!=null,"The east region includes a beach cove")
 # Display-only production validation, cached markers and lifecycle contract.
 var production_payload=payload.duplicate(true)
 production_payload.items.append({"id":"mill","kind":"windmill","cell":{"x":13,"z":13},"rotation":0})
 production_payload.production=[{"placeID":"mill","station":"mill","good":"flour","state":1,"remaining":45,"progress":0.0}]
 var production_data=HomesteadWorldData.new()
 check(production_data.apply_snapshot(production_payload),"Placed mill accepts display-only flour status")
 check(HomesteadWorldData.new().apply_snapshot(JSON.parse_string(JSON.stringify(production_payload))),"Production accepts host JSON numeric types")
 var invalid_production=production_payload.duplicate(true)
 invalid_production.production[0].placeID="garden"
 check(not production_data.apply_snapshot(invalid_production),"A production marker cannot impersonate another kind of place")
 invalid_production=production_payload.duplicate(true)
 invalid_production.production[0].good="meal"
 check(not production_data.apply_snapshot(invalid_production),"Mill output must be flour")
 invalid_production=production_payload.duplicate(true)
 invalid_production.production[0].progress=2.0
 check(not production_data.apply_snapshot(invalid_production),"Invalid progress is rejected")
 scene.receive_host_json(JSON.stringify({"version":1,"session":"test-child-session","type":"snapshot","payload":production_payload}))
 var mill_badge=scene.presentation.production_nodes.mill
 var timer_navigation_revision=scene.navigation.revision
 var mill_art=scene.presentation.nodes.mill
 check(mill_badge.get_meta("label").text=="45s","Production countdown omits repeated product names")
 var sail=scene.presentation.sails[0]
 scene.camera.global_position=scene.presentation.nodes.mill.global_position+Vector3(0,10,15)
 scene.camera.look_at(sail.global_position)
 var sail_angle=sail.rotation.z
 scene.presentation._process(1.0)
 check(sail.rotation.z>sail_angle,"An active mill visibly works")
 production_payload.production[0].remaining=22
 production_payload.production[0].progress=0.5
 scene.receive_host_json(JSON.stringify({"version":1,"session":"test-child-session","type":"snapshot","payload":production_payload}))
 check(scene.presentation.production_nodes.mill==mill_badge and scene.presentation.nodes.mill==mill_art,"Timer ticks reuse badge and building resources")
 check(scene.navigation.revision==timer_navigation_revision,"Timer ticks retain the walking grid")
 production_payload.farmStages=[3,3]
 scene.receive_host_json(JSON.stringify({"version":1,"session":"test-child-session","type":"snapshot","payload":production_payload}))
 var crop_recoveries=scene.resident.recoveries
 production_payload.farmStages=[4,4]
 scene.receive_host_json(JSON.stringify({"version":1,"session":"test-child-session","type":"snapshot","payload":production_payload}))
 check(scene.navigation.revision==timer_navigation_revision and scene.resident.recoveries==crop_recoveries,"Crop growth does not rebuild routes or interrupt a resident")
 # The rasterized grid retains the canonical overlap, path and locked-land rules.
 for z in range(HomesteadItems.WORLD_BOUNDS.position.y,HomesteadItems.WORLD_BOUNDS.end.y):
  for x in range(HomesteadItems.WORLD_BOUNDS.position.x,HomesteadItems.WORLD_BOUNDS.end.x):
   var cell=Vector2i(x,z)
   var occupied=scene.data.item_at(cell)
   var blocked=not scene.data.buildable(cell) or (not occupied.is_empty() and HomesteadItems.DEFINITIONS[occupied.kind].blocks)
   var utility=scene.navigation.well_center.is_finite() and Rect2i(scene.navigation.well_cell,HomesteadItems.WELL_SIZE).has_point(cell)
   check(scene.navigation.open(cell)==not (blocked or utility),"Walking boundaries retain saved obstacles, locked land and the visible well")
 scene.set_paused(true,true)
 check(scene.production_preview_active() and scene.presentation.is_processing() and not scene.resident.is_physics_processing(),"Menu keeps production moving while residents stay paused")
 scene.reduced_motion=true
 scene.set_paused(true,true)
 check(not scene.production_preview_active() and not scene.presentation.is_processing(),"Reduce Motion uses static production states")
 scene.reduced_motion=false
 production_payload.production[0].state=2
 production_payload.production[0].remaining=0
 production_payload.production[0].progress=1.0
 scene.receive_host_json(JSON.stringify({"version":1,"session":"test-child-session","type":"snapshot","payload":production_payload}))
 sail_angle=sail.rotation.z
 scene.presentation._process(1.0)
 check(sail.rotation.z==sail_angle,"A ready mill stops turning until another batch starts")
 scene.set_paused(true,false)
 check(not RenderingServer.render_loop_enabled,"Background always stops production rendering")
 scene.receive_host_json(JSON.stringify(packet))
 scene.set_paused(false)
 check(scene.presentation.production_nodes.is_empty(),"Family snapshots remove disposable production markers")
 # A construction site is presentation-only; the host owns its receipt clock.
 var building_payload=production_payload.duplicate(true)
 building_payload.production=[]
 building_payload.construction=[{"placeID":"mill","remaining":40,"progress":0.1}]
 check(HomesteadWorldData.new().apply_snapshot(JSON.parse_string(JSON.stringify(building_payload))),"Construction validates JSON timestamps/progress")
 var invalid_building=building_payload.duplicate(true)
 invalid_building.construction[0].placeID="missing"
 check(not HomesteadWorldData.new().apply_snapshot(invalid_building),"Construction requires a real placed object")
 scene.receive_host_json(JSON.stringify({"version":1,"session":"test-child-session","type":"snapshot","payload":building_payload}))
 var foundation=scene.presentation.nodes.mill
 var build_badge=scene.presentation.construction_nodes.mill
 check(foundation.get_meta("building",false),"New construction renders a foundation, not an idle finished mill")
 check(build_badge.get_meta("label").text=="40s","Construction clock has no repeated title")
 building_payload.construction[0].remaining=39
 building_payload.construction[0].progress=0.12
 scene.receive_host_json(JSON.stringify({"version":1,"session":"test-child-session","type":"snapshot","payload":building_payload}))
 check(scene.presentation.nodes.mill==foundation and scene.presentation.construction_nodes.mill==build_badge,"Clock ticks reuse construction artwork and badges")
 building_payload.construction[0].progress=0.5
 scene.receive_host_json(JSON.stringify({"version":1,"session":"test-child-session","type":"snapshot","payload":building_payload}))
 check(scene.presentation.nodes.mill!=foundation,"Construction advances to its timber frame")
 var timber=scene.presentation.nodes.mill
 building_payload.construction[0].progress=0.9
 scene.receive_host_json(JSON.stringify({"version":1,"session":"test-child-session","type":"snapshot","payload":building_payload}))
 check(scene.presentation.nodes.mill!=timber and scene.presentation.nodes.mill.get_meta("building",false),"The last step shows the building before the clock ends")
 building_payload.construction=[]
 scene.receive_host_json(JSON.stringify({"version":1,"session":"test-child-session","type":"snapshot","payload":building_payload}))
 check(not scene.presentation.nodes.mill.get_meta("building",false) and scene.presentation.construction_nodes.is_empty(),"Completion reveals the structure and removes the work marker")
 scene.receive_host_json(JSON.stringify(packet))
 var original_cottage=scene.presentation.nodes.cottage
 var original_island=scene.presentation.land_root.get_child(0)
 scene.data.items[1].cell.x+=1
 scene.presentation.rebuild()
 check(scene.presentation.nodes.cottage==original_cottage,"Moving a garden must reuse unchanged cottage artwork")
 check(scene.presentation.land_root.get_child(0)==original_island,"Moving objects must not rebuild the island")
 scene.data.items[1].cell.x-=1
 scene.presentation.rebuild()
 var first_highlight=null
 for n in 12:
  scene.presentation.highlight(Vector2i(2+n%2,10),Vector2i(3,3),n%2==0)
  if n==0: first_highlight=scene.presentation.preview_node
  check(scene.presentation.preview_node==first_highlight,"Dragging and host verdicts reuse the same highlight resources")
 scene.presentation.highlight(Vector2i(3,10),Vector2i(3,3),false)
 check(scene.presentation.highlight_fill.albedo_color.r>scene.presentation.highlight_fill.albedo_color.g,"Intersections use a red ground verdict")
 scene.presentation.highlight(Vector2i(3,10),Vector2i(3,3),true)
 check(scene.presentation.highlight_fill.albedo_color.g>scene.presentation.highlight_fill.albedo_color.r,"Valid placement uses a green ground verdict")
 scene.presentation.clear_preview()
 var garden=scene.data.find("garden")
 scene.navigation.view_direction=Vector3.BACK
 var garden_spot=scene.navigation.approach(garden,HomesteadItems.cell_center(Vector2i(4,8)))
 var garden_facing=(HomesteadItems.item_center(garden)-garden_spot).normalized()
 check(garden_facing.dot(Vector3.BACK)>0.4,"Reachable gardening approaches show the child's face while facing the plants")
 check(scene.navigation.open(HomesteadItems.cell_at(garden_spot)),"Activity approaches stay on walkable owned land")
 var bench_spot=scene.navigation.approach(scene.data.find("bench"))
 scene.navigation.view_direction=Vector3.FORWARD
 check(scene.navigation.approach(scene.data.find("bench"))==bench_spot,"Camera preference must not reverse a bench's authored seating approach")
 scene.navigation.view_direction=Vector3(sin(0.25),0,cos(0.25))

 scene.data.land_sides.append("east")
 scene.data.inventory["edge-flower"]={"id":"edge-flower","kind":"flowers","cell":Vector2i(30,11),"rotation":0,"style":0}
 scene.receive_host_json(JSON.stringify({"version":1,"session":"test-child-session","type":"select","payload":{"id":"edge-flower"}}))
 scene.receive_host_json(JSON.stringify({"version":1,"session":"test-child-session","type":"nudge","payload":{"x":1}}))
 check(scene.preview_cell==Vector2i(31,11) and scene.data.placement_error("flowers",scene.preview_cell,0)=="","Nudging reaches the last usable square of the expanded waterside")
 scene._process(1.0/60)
 scene.point_at(scene.camera.unproject_position(HomesteadItems.cell_center(Vector2i(40,11))))
 check(scene.preview_cell==Vector2i(31,11),"Dragging beyond the map keeps the preview within the host's accepted coordinate range")
 scene.receive_host_json(JSON.stringify({"version":1,"session":"test-child-session","type":"cancel","payload":{}}))
 scene.data.inventory.erase("edge-flower")
 scene.data.land_sides.erase("east")
 check(HomesteadItems.BASE_BOUNDS.size==Vector2i(20,20),"The starter has 4x4 five-square plots")
 for side in HomesteadItems.LAND_BOUNDS:
  var bounds: Rect2i=HomesteadItems.LAND_BOUNDS[side]
  check(bounds.size==Vector2i(12,12),"Every expansion contains twelve by twelve usable squares")
  check(not scene.data.buildable(bounds.position),"Merely displaying a large extension grants no land")
 check(scene.unowned_land_at(Vector2i(8,-8))=="north","The future northern plot is inspectable on the map")
 # Rendering future terrain must never make it navigable or placeable.
 for side in HomesteadItems.LAND_CENTERS:
  var patch=scene.presentation.land_root.get_node_or_null("Land_"+side)
  check(patch!=null and not patch.get_meta("available",true),"Every inactive plot must remain visibly represented")
 for cell in [Vector2i(-2,7),Vector2i(21,7),Vector2i(8,-2)]:
  check(not scene.navigation.open(cell),"Inactive land cannot be used by residents")
  check(scene.data.placement_error("flowers",cell,0)=="outside-land","Visible inactive land cannot accept placement")
 check(scene.unowned_land_at(Vector2i(21,7))=="east","Tapping locked waterside requests its host preview")
 scene.receive_host_json(JSON.stringify({"version":1,"session":"test-child-session","type":"landPreview","payload":{"side":"east"}}))
 check(scene.land_preview,"East preview highlights its actual cells")
 check(not scene.navigation.open(Vector2i(21,7)),"Preview must never open navigation")
 check(scene.data.placement_error("flowers",Vector2i(21,7),0)=="outside-land","Preview must never grant placement")
 scene.receive_host_json(JSON.stringify({"version":1,"session":"test-child-session","type":"landPreview","payload":{"side":""}}))
 check(not scene.land_preview,"Closing preview clears its highlight")
 scene.data.land_sides.append("east")
 scene.presentation.rebuild()
 scene.navigation.rebuild(scene.data)
 check(scene.presentation.land_root.get_node("Land_east").get_meta("available")==true,"An authoritative activation updates its visual state")
 check(scene.navigation.open(Vector2i(21,7)),"Only an authoritative active plot becomes navigable")
 check(scene.unowned_land_at(Vector2i(21,7))=="","Owned waterside is no longer a purchase target")
 var lawns=scene.presentation.land_root.get_node("StartingLand").get_children().filter(func(node): return node.get_meta("continuous_grass",false))
 check(lawns.size()==1,"Purchased land joins the clearing as one continuous grass surface")
 if lawns.size()==1:
  var outline: PackedVector2Array=lawns[0].get_meta("ground_outline")
  for square in [Vector2i(0,0),Vector2i(19,19),Vector2i(20,0),Vector2i(31,11)]:
   var point=HomesteadItems.cell_center(square)
   check(Geometry2D.is_point_in_polygon(Vector2(point.x,point.z),outline),"The joined turf covers every owned corner without a grass seam or hole")
  var locked=HomesteadItems.cell_center(Vector2i(8,-2))
  check(not Geometry2D.is_point_in_polygon(Vector2(locked.x,locked.z),outline),"Unbought North remains outside the active grass surface")
 check(scene.presentation.land_root.get_node_or_null("Land_east/WatersideStream")!=null,"Owned waterside reveals its authored stream")
 for x in range(20,32):
  for z in range(0,12):
   check(scene.navigation.open(Vector2i(x,z)),"The whole dry bank stays usable")
 check(not scene.navigation.path(HomesteadItems.cell_center(Vector2i(17,7)),HomesteadItems.cell_center(Vector2i(21,7))).is_empty(),"Residents can reach the bank from the original clearing")
 check(not scene.navigation.open(Vector2i(8,-2)),"Waterside never opens north")
 scene.data.land_sides.clear()
 scene.presentation.rebuild()
 scene.navigation.rebuild(scene.data)
 # The host may preview a future meadow without granting land. A committed
 # west-only snapshot opens west cells while leaving east and north blocked.
 scene.receive_host_json(JSON.stringify({"version":1,"session":"test-child-session","type":"landPreview","payload":{"west":true}}))
 check(not scene.navigation.open(Vector2i(-2,7)),"A meadow preview must never grant land")
 scene.receive_host_json(JSON.stringify({"version":1,"session":"test-child-session","type":"landPreview","payload":{"west":false}}))
 scene.data.land_sides.append("west")
 scene.presentation.rebuild()
 scene.navigation.rebuild(scene.data)
 check(scene.navigation.open(Vector2i(-2,7)),"Committed west meadow becomes walkable")
 check(not scene.navigation.open(Vector2i(21,7)),"Meadow purchase cannot unlock east")
 check(HomesteadItems.footprint("workshop",0)==Vector2i(3,3),"Workshop native and runtime footprints must match")
 check(HomesteadItems.footprint("windmill",0)==Vector2i(3,3),"Mill footprint matches native 3x3")
 var mill=scene.presentation.make_item("windmill",0,false,1)
 root.add_child(mill)
 var pivot=scene.presentation.sails.back()
 var angle=pivot.rotation.z
 scene.presentation.reduced_motion=true
 scene.presentation._process(1.0)
 check(pivot.rotation.z==angle,"Reduce Motion stops mill sails")
 HomesteadStaticBatcher.consolidate(mill,scene.presentation.sails)
 check(is_instance_valid(pivot) and pivot.get_child_count()>0,"Batching keeps the sail pivot intact")
 mill.free()
 var stored_mill=HomesteadWorldData.new()
 check(stored_mill.apply_snapshot({"items":[{"id":"mill","kind":"windmill","cell":null,"rotation":1,"style":1}],"land":[]}),"Stored mill retains its free look")
 check(stored_mill.inventory["mill"].style==1,"Mill look survives storage")
 check(scene.data.placement_error("windmill",Vector2i(13,11),0)=="","Mill fits original clearing without a land purchase")
 var workshop=scene.presentation.make_item("workshop",0)
 check(workshop.get_child(0).get_child_count()>30,"Workshop has its own authored joinery and workbench")
 workshop.free()
 check(HomesteadItems.footprint("greenhouse",0)==Vector2i(3,2),"Greenhouse uses the shared compact footprint")
 var greenhouse=scene.presentation.make_item("greenhouse",0)
 check(greenhouse.get_child(0).get_child_count()>40,"Greenhouse has authored glass, joinery, hanging leaves and pots")
 greenhouse.free()
 var stored_greenhouse=HomesteadWorldData.new()
 check(stored_greenhouse.apply_snapshot({"items":[{"id":"stored-greenhouse","kind":"greenhouse","cell":null,"rotation":1}],"land":["west"]}),"Stored greenhouse remains owned inventory")
 var stored=stored_greenhouse.inventory["stored-greenhouse"]
 check(stored_greenhouse.placement_error(stored.kind,stored.cell,stored.rotation)=="","Stored greenhouse starts its rotated replacement preview in the meadow")
 check(scene.data.placement_error("greenhouse",Vector2i(-3,7),0)=="","Greenhouse fits inside owned west meadow")
 check(scene.data.placement_error("greenhouse",Vector2i(-3,7),1)=="","Rotated greenhouse fits inside owned west meadow")
 check(scene.data.placement_error("greenhouse",Vector2i(8,11),0)=="outside-land","Greenhouse remains a west-meadow building")
 var orchard=scene.presentation.make_item("orchard",0,false,2)
 check(orchard.get_child(0).get_child_count()>60,"Orchard has authored trees, fruit and a woven basket")
 orchard.free()
 check(HomesteadItems.footprint("orchard",0)==Vector2i(2,2),"Orchard shares the compact native footprint")
 check(scene.data.placement_error("orchard",Vector2i(-2,6),0)=="","Orchard fits the owned west meadow")
 check(scene.data.placement_error("orchard",Vector2i(8,11),0)=="outside-land","Orchard cannot be placed in the clearing")
 var stored_orchard=HomesteadWorldData.new()
 check(stored_orchard.apply_snapshot({"items":[{"id":"stored-orchard","kind":"orchard","cell":null,"rotation":1,"style":2}],"land":["west"]}),"Stored orchard is retained")
 var fruit_trees=stored_orchard.inventory["stored-orchard"]
 check(stored_orchard.placement_error(fruit_trees.kind,fruit_trees.cell,fruit_trees.rotation)=="","Stored orchard replacement starts in the meadow")
 check(fruit_trees.style==2,"Stored orchard preserves its chosen variety")
 scene.data.land_sides.clear()
 scene.presentation.rebuild()
 scene.navigation.rebuild(scene.data)
 # Fit the complete terrain and actual roof extents through a full orbit and
 # tablet/phone landscape aspects, not just the initial attractive angle.
 for aspect in [1.3,1.8,2.5,3.0]:
  for turn in 8:
   scene.yaw=turn*PI/4
   var fit=scene.overview_fit(aspect)
   var right=Vector3(cos(scene.yaw),0,-sin(scene.yaw))
   var up=Vector3(-sin(scene.yaw)*sin(scene.OVERVIEW_PITCH),cos(scene.OVERVIEW_PITCH),-cos(scene.yaw)*sin(scene.OVERVIEW_PITCH))
   for point in scene.overview_points():
    var offset=point-fit.focus
    check(absf(right.dot(offset))<fit.size*aspect/2,"All terrain must fit horizontally with margin at every camera rotation")
    check(absf(up.dot(offset))<fit.size/2,"All terrain must fit vertically with margin at every camera rotation")
 scene.yaw=0.25
 scene.receive_host_json(JSON.stringify({"version":1,"session":"test-child-session","type":"camera","payload":{"mode":"overview","zoom":0.01}}))
 check(scene.camera_mode=="pan" and is_equal_approx(scene.camera_base_size()*scene.zoom,scene.MIN_CAMERA_SIZE),"Zooming Overview enters a free view with a safe absolute close limit")
 scene.receive_host_json(JSON.stringify({"version":1,"session":"test-child-session","type":"camera","payload":{"mode":"follow","zoom":0.01}}))
 check(is_equal_approx(scene.camera_base_size()*scene.zoom,scene.MIN_CAMERA_SIZE),"Follow shares the same close zoom limit")
 scene.zoom_camera(1000)
 check(scene.camera_mode=="follow" and scene.camera_base_size()*scene.zoom>scene.overview_size(2.5),"Follow can zoom out far enough to see every expansion")
 # At the furthest zoom, even following a resident at an expansion's edge must
 # leave enough field of view for the other plots, across landscape aspects.
 for aspect in [1.3,1.8,2.5,3.0]:
  var fit=scene.overview_fit(aspect,scene.FIXED_YAW)
  var right=Vector3(cos(scene.FIXED_YAW),0,-sin(scene.FIXED_YAW))
  var up=Vector3(-sin(scene.FIXED_YAW)*sin(scene.OVERVIEW_PITCH),cos(scene.OVERVIEW_PITCH),-cos(scene.FIXED_YAW)*sin(scene.OVERVIEW_PITCH))
  for bounds in [HomesteadItems.BASE_BOUNDS,HomesteadItems.LAND_BOUNDS.west,HomesteadItems.LAND_BOUNDS.east]:
   for cell in [bounds.position,bounds.end-Vector2i.ONE,Vector2i(bounds.position.x,bounds.end.y-1),Vector2i(bounds.end.x-1,bounds.position.y)]:
    var focus=HomesteadItems.cell_center(cell)+Vector3(0,1,0)
    for point in scene.overview_points():
     check(absf(right.dot(point-focus))<fit.size*aspect,"Maximum Follow zoom fits the full map from an owned plot edge horizontally")
     check(absf(up.dot(point-focus))<fit.size,"Maximum Follow zoom fits the full map from an owned plot edge vertically")
 var finite_zoom=scene.zoom
 scene.zoom_camera(NAN)
 scene.zoom_camera(-1)
 check(scene.zoom==finite_zoom,"Invalid zoom input cannot corrupt the camera")
 scene.receive_host_json(JSON.stringify({"version":1,"session":"test-child-session","type":"camera","payload":{"rotation":PI}}))
 scene._process(1.0)
 check(scene.yaw==scene.FIXED_YAW and scene.orbit_yaw==scene.FIXED_YAW,"Legacy rotation commands cannot rotate the world")
 var following_from=scene.orbit_focus
 scene.resident.position+=Vector3(1,0,1)
 scene._process(1.0/60.0)
 check(scene.orbit_focus.distance_to(following_from)>0.1,"Follow responds in the first frame of resident movement")
 scene._process(1.0)
 check(scene.orbit_focus.distance_to(scene.resident.position+Vector3(0,1,0))<0.001,"Follow settles on the moving resident")
 scene.receive_host_json(JSON.stringify({"version":1,"session":"test-child-session","type":"camera","payload":{"mode":"overview","resetZoom":true}}))
 var rig=scene.resident.model.rig
 scene.resident.set_physics_process(false)
 # Exercise the real schedule and navigation without waiting for wall-clock time.
 for i in 12000: scene.resident._physics_process(1.0/60.0)
 check(scene.resident.distance_walked>10,"Resident should walk purposefully")
 check(scene.resident.arrivals.get("garden",0)>0,"Resident must reach and water garden")
 check(scene.resident.arrivals.get("bench",0)>0,"Resident must reach and sit on bench")
 check(scene.resident.blocked_samples==0,"Resident must not walk through obstacles")
 # Keep moving through a straight tile boundary and face the direction of travel.
 var walker=scene.resident
 walker.position=HomesteadItems.cell_center(Vector2i(7,7))
 walker.facing=0
 walker.desired_facing=0
 walker.speed=1.2
 walker.state="walking"
 walker.route=PackedVector3Array([walker.position+Vector3(0,0,0.01),walker.position+Vector3(0,0,1),walker.position+Vector3(0,0,2)])
 var before=walker.position
 walker._physics_process(1.0/60.0)
 check(walker.position.distance_to(before)>0.019,"Straight waypoint must consume the remaining frame distance without a tile pause")
 walker.route=PackedVector3Array([walker.position+Vector3(0,0,-2)])
 walker.facing=0
 walker.speed=0
 before=walker.position
 walker._physics_process(1.0/60.0)
 check(walker.position==before,"Resident must turn before walking in the opposite direction")
 # A starter world has no bench or pond to visit; choose the next owned destination.
 var complete_items=scene.data.items.duplicate(true)
 scene.data.items=scene.data.items.filter(func(item): return item.kind in ["garden","cottage"])
 scene.navigation.rebuild(scene.data)
 walker.schedule_index=0
 walker.choose_destination()
 check(walker.destination_kind=="cottage" and walker.target_id=="cottage","Schedule must skip places that do not exist")
 scene.data.items=complete_items
 scene.navigation.rebuild(scene.data)
 # Ground contact is the contract; knee angles may change with a better gait.
 var model=walker.model
 model.set_motion("walk")
 model.animator.advance(0.3)
 for sample in 13:
  model.animator.seek(float(sample)*0.04,true)
  var sole=model.left_ankle.to_global(Vector3(0,-0.105,0)).y
  check(absf(sole-walker.position.y)<0.015,"Planted sole must remain on the ground throughout stance")
 model.animator.seek(0.2,true)
 var left_sole=model.left_ankle.to_global(Vector3(0,-0.105,0)).y
 var right_sole=model.right_ankle.to_global(Vector3(0,-0.105,0)).y
 check(right_sole-left_sole>0.04,"Swing foot must clear the ground while the other foot stays planted")
 # Camera safety is independent of zoom and angle: all modes keep the lens
 # outside the entire scene envelope, including intermediate opposite turns.
 for view in ["overview","home","follow","detail"]:
  scene.camera_mode=view
  for turn in 16:
   scene.yaw=turn*PI/4
   for frame in 8:
    scene._process(1.0/30.0)
    var horizontal=Vector2(scene.camera.position.x,scene.camera.position.z).length()
    check(horizontal>scene.scenery_radius+1.0,"Camera lens must remain outside all scenery through orbit transitions")
    check(scene.camera.position.y>6.0,"Camera must remain above roofs rather than moving inside them")
    if view=="overview":
     var viewport=scene.get_viewport().get_visible_rect()
     for point in scene.overview_points():
      check(viewport.has_point(scene.camera.unproject_position(point)),"Overview must keep every plot and roof visible during rotation")
 scene.camera_mode="overview"
 scene.yaw=0.25
 # Every rounded route segment retains the resident's swept-body clearance.
 var smooth_route=scene.navigation.path(HomesteadItems.cell_center(Vector2i(7,7)),scene.navigation.approach(scene.data.find("cottage")))
 for segment in range(1,smooth_route.size()):
  check(scene.navigation.corridor_clear(smooth_route[segment-1],smooth_route[segment]),"Rounded routes must not clip obstacles or inactive land")
 scene.zoom=1.0
 scene.camera_initialized=false
 scene._process(1.0/60)
 var screen_low=Vector2(INF,INF)
 var screen_high=Vector2(-INF,-INF)
 for point in scene.overview_points():
  var screen=scene.camera.unproject_position(point)
  screen_low=screen_low.min(screen)
  screen_high=screen_high.max(screen)
 var screen_size=scene.get_viewport().get_visible_rect().size
 var fill=(screen_high-screen_low)/screen_size
 check(maxf(fill.x,fill.y)>0.85 and maxf(fill.x,fill.y)<1.0,"Overview fits the expanded world tightly without cropping terrain or mountains")
 check(scene.overview_size(0.5)>scene.overview_size(2.5),"Portrait overview must still fit the full island width")
 var position=scene.resident.position
 var activity=scene.resident.state
 payload.appearance={"hair":4,"skin":5,"height":2,"build":2}
 scene.receive_host_json(JSON.stringify(packet))
 check(scene.resident.model.rig==rig,"Appearance updates must preserve active rig")
 check(scene.resident.position==position and scene.resident.state==activity,"Appearance updates must preserve activity")
 check(scene.resident.model.appearance.hair==4,"Appearance should update")
 var target=scene.data.find(scene.resident.target_id)
 if not target.is_empty():
  payload.items=items.filter(func(item): return item.id!=target.id)
  scene.receive_host_json(JSON.stringify(packet))
  check(scene.resident.state=="pause","Removed destination must safely recover")
 # Restore the complete fixture after the deliberate destination-removal case.
 payload.items=items
 scene.receive_host_json(JSON.stringify(packet))
 var messages=[]
 scene.host_message.connect(func(raw): messages.append(JSON.parse_string(raw)))
 scene._process(1.0)
 await physics_frame
 var touch=InputEventScreenTouch.new()
 touch.pressed=true
 touch.position=Vector2(-20,-20)
 scene._input(touch)
 check(scene.pending_pick==null,"Touches outside the embedded viewport cannot select world objects")
 touch.position=scene.camera.unproject_position(HomesteadItems.item_center(scene.data.find("cottage"))+Vector3(0,2,0))
 var cottage_point=touch.position
 scene._input(touch)
 scene._physics_process(0.1)
 check(not messages.any(func(message): return message.type=="selected"),"A quick touch must not start editing")
 touch.pressed=false
 scene._input(touch)
 scene._physics_process(0.016)
 check(messages.any(func(message): return message.type=="visited" and message.payload.id=="cottage"),"A tap visits the visible cottage")
 check(not messages.any(func(message): return message.type=="selected"),"Visiting does not enter edit mode")
 scene.receive_host_json(JSON.stringify({"version":1,"session":"test-child-session","type":"visit","payload":{"id":"cottage"}}))
 check(scene.resident.target_id=="cottage","Tap visit uses the existing resident navigation")
 check(scene.selected_id=="" and scene.data.items.size()==4,"Visiting never edits the world")
 messages.clear()
 touch.pressed=true
 scene._input(touch)
 scene._physics_process(0.3)
 check(not messages.any(func(message): return message.type=="selected"),"Holding waits for the deliberate threshold")
 scene._physics_process(0.2)
 scene._physics_process(0.2)
 check(messages.filter(func(message): return message.type=="selected" and message.payload.id=="cottage").size()==1,"A completed hold selects exactly once")
 var command={"version":1,"session":"test-child-session","type":"select","payload":{"id":"cottage","fromHold":true}}
 scene.receive_host_json(JSON.stringify(command))
 check(not scene.resident.is_physics_processing(),"Residents pause while a piece is being edited")
 var anchor=scene.preview_cell
 scene.move_press(cottage_point)
 check(scene.preview_cell==anchor,"A held piece keeps its grab point without jumping")
 scene.end_press(cottage_point)
 var standing=scene.preview_cell
 var open_ground=scene.camera.unproject_position(HomesteadItems.cell_center(standing+Vector2i(6,6)))
 scene.begin_press(open_ground,-2)
 scene.move_press(open_ground+Vector2(48,0))
 check(scene.preview_cell==standing and scene.camera_mode=="pan","A drag on open ground pans and leaves the building where it stands")
 check(not messages.any(func(message): return message.type=="placementIntent"),"Panning during placement does not buy or save")
 scene.end_press(open_ground+Vector2(48,0))
 var on_building=scene.camera.unproject_position(HomesteadItems.cell_center(standing+Vector2i(1,0)))
 scene.begin_press(on_building,-2)
 var shifted=scene.camera.unproject_position(HomesteadItems.cell_center(standing+Vector2i(3,0)))
 scene.move_press(shifted)
 check(scene.preview_cell==standing+Vector2i(2,0),"A drag on the building moves it from its current spot")
 scene.end_press(shifted)
 scene.receive_host_json(JSON.stringify({"version":1,"session":"test-child-session","type":"cancel","payload":{}}))
 check(scene.resident.is_physics_processing(),"Cancel resumes World life")
 messages.clear()
 scene._input(touch)
 scene._physics_process(0.1)
 var camera_yaw=scene.yaw
 var pan_before=scene.orbit_focus
 var motion=InputEventScreenDrag.new()
 motion.position=cottage_point+Vector2(28,0)
 motion.relative=Vector2(28,0)
 scene._input(motion)
 scene._physics_process(0.6)
 check(scene.yaw==camera_yaw and scene.camera_mode=="pan","Dragging the map pans without rotating")
 check(scene.pan_focus.distance_to(pan_before)>0.1,"Horizontal finger travel moves the map")
 var horizontal_pan=scene.pan_focus
 scene.move_press(cottage_point+Vector2(28,35))
 check(scene.pan_focus.distance_to(horizontal_pan)>0.1,"Vertical finger travel also moves the map")
 check(not messages.any(func(message): return message.type=="selected"),"A map drag cancels the hold")
 scene.reset_press()
 scene._input(touch)
 scene._physics_process(0.2)
 var second_touch=InputEventScreenTouch.new()
 second_touch.index=1
 second_touch.pressed=true
 second_touch.position=cottage_point+Vector2(30,0)
 scene._input(second_touch)
 scene._physics_process(0.6)
 check(not scene.pointer_down and not messages.any(func(message): return message.type=="selected"),"A second finger cancels object pickup")
 var pinch_start_zoom=scene.camera_base_size()*scene.zoom
 var pinch_drag=InputEventScreenDrag.new()
 pinch_drag.index=1
 pinch_drag.position=second_touch.position+Vector2(90,0)
 scene._input(pinch_drag)
 check(scene.camera_base_size()*scene.zoom<pinch_start_zoom,"Spreading two fingers zooms in")
 scene._process(1.0/60.0)
 check(scene.yaw==camera_yaw,"Pinch never rotates the world")
 var third_touch=InputEventScreenTouch.new()
 third_touch.index=2
 third_touch.position=cottage_point+Vector2(0,100)
 third_touch.pressed=true
 scene._input(third_touch)
 var three_finger_zoom=scene.zoom
 scene._input(pinch_drag)
 check(scene.zoom==three_finger_zoom,"A third finger suspends the pinch")
 third_touch.pressed=false
 scene._input(third_touch)
 scene._input(pinch_drag)
 check(scene.zoom==three_finger_zoom,"Returning to two fingers resets the pinch baseline without jumping")
 second_touch.pressed=false
 scene._input(second_touch)
 scene._input(motion)
 touch.pressed=false
 scene._input(touch)
 scene._physics_process(0.016)
 check(not messages.any(func(message): return message.type in ["selected","visited","placementIntent"]),"The remaining pinch finger cannot visit, pick up or place")
 scene.receive_host_json(JSON.stringify(command))
 var draft_before_pinch=scene.preview_cell
 touch.pressed=true
 scene._input(touch)
 second_touch.pressed=true
 scene._input(second_touch)
 scene._input(pinch_drag)
 second_touch.pressed=false
 scene._input(second_touch)
 touch.pressed=false
 scene._input(touch)
 check(scene.preview_cell==draft_before_pinch,"Pinching with a selected piece never moves its draft")
 var home_before=scene.data.find("cottage").cell
 check(is_instance_valid(scene.presentation.preview_item),"Selection shows the actual moving piece")
 check(not scene.presentation.nodes.cottage.visible,"Only one visible cottage during placement")
 scene.preview_cell=Vector2i(6,2)
 scene.update_preview()
 check(scene.presentation.preview_item.position==HomesteadItems.center(Vector2i(6,2),HomesteadItems.footprint("cottage",0))+Vector3(0,0.32,0),"Piece floats above its draft location")
 check(scene.data.find("cottage").cell==home_before,"Dragging never changes committed data")
 scene.receive_host_json(JSON.stringify({"version":1,"session":"test-child-session","type":"cancel","payload":{}}))
 check(scene.presentation.preview_item==null and scene.presentation.nodes.cottage.visible,"Cancel restores original artwork")
 scene.receive_host_json(JSON.stringify(command))
 command.type="confirm"
 command.payload={}
 scene.receive_host_json(JSON.stringify(command))
 scene.receive_host_json(JSON.stringify(command))
 var intents=messages.filter(func(message): return message.type=="placementIntent")
 check(intents.size()==2,"Confirm should emit a bounded host intent")
 if intents.size()==2:
  check(intents[0].payload.commandID==intents[1].payload.commandID,"Retry must retain command identity")
  check(intents[0].payload.commandID.length()==36,"Command identity must be UUID-shaped")
 packet.payload={"items":items,"land":[],"appearance":{"hair":8,"outfit":2},"reducedMotion":true}
 scene.receive_host_json(JSON.stringify(packet))
 scene._process(1.0/60.0)
 scene.resident._physics_process(1.0/60.0)
 scene.resident.model.set_motion("wave")
 scene.resident.model._process(1.0/60.0)
 check(scene.resident.model.animator.speed_scale==0,"Reduced motion freezes nonessential waving")
 check(scene.presentation.reduced_motion,"Reduced motion stops ambient scenery")
 packet.payload=payload
 var old_count=scene.data.items.size()
 payload.items=[{"id":"invalid","kind":"currency-grant","cell":{"x":0,"z":0}}]
 scene.receive_host_json(JSON.stringify(packet))
 check(scene.data.items.size()==old_count,"Malformed snapshots must leave committed state intact")
 scene.reduced_motion=false
 scene.receive_host_json(JSON.stringify({"version":1,"session":"test-child-session","type":"camera","payload":{"mode":"follow","resetZoom":true}}))
 scene._process(1.0/60.0)
 scene.receive_host_json(JSON.stringify({"version":1,"session":"test-child-session","type":"lifecycle","payload":{"paused":true}}))
 check(scene.paused and not scene.resident.is_physics_processing(),"Background must pause simulation")
 check(scene.touches.is_empty() and not scene.multitouch and not scene.pointer_down,"Pausing releases every gesture so reopening cannot resume a stale drag")
 var held_transform=scene.camera.transform
 var held_size=scene.camera.size
 var held_focus=scene.orbit_focus
 scene.receive_host_json(JSON.stringify({"version":1,"session":"test-child-session","type":"lifecycle","payload":{"paused":true,"previewing":true}}))
 for frame in 30: scene._process(1.0/60.0)
 check(scene.camera.transform==held_transform and scene.camera.size==held_size and scene.orbit_focus==held_focus,"Opening a menu holds even an in-progress Follow transition without changing map position, zoom or focus")
 var preview_position=scene.resident.position
 var preview_rig=scene.resident.model.rig
 scene.reduced_motion=true
 scene.receive_host_json(JSON.stringify({"version":1,"session":"test-child-session","type":"camera","payload":{"mode":"detail","framing":0.22}}))
 check(scene.process_mode==Node.PROCESS_MODE_INHERIT and RenderingServer.render_loop_enabled,"An on-map editor must render its preview while simulation stays paused")
 scene._process(1.0/60.0)
 check(is_equal_approx(scene.camera.size,3.8/0.78) and scene.camera.h_offset==0.0 and scene.camera.v_offset<0.0,"Editor reserves bottom space and keeps the character above the horizontal panel")
 var visible_character=scene.camera.unproject_position(scene.resident.position+Vector3(0,1,0))
 check(visible_character.y<scene.get_viewport().get_visible_rect().size.y*0.5,"Character stays in the exposed upper map")
 check(scene.resident.position==preview_position and not scene.resident.is_physics_processing() and scene.resident.model.rig==preview_rig,"Preview must not move residents or replace the rig")
 check(scene.resident.process_mode==Node.PROCESS_MODE_DISABLED and scene.presentation.process_mode==Node.PROCESS_MODE_DISABLED,"Preview must freeze descendant animations as well as simulation")
 scene.camera_preview_frames=0
 scene._process(1.0/60.0)
 check(scene.process_mode==Node.PROCESS_MODE_DISABLED and not RenderingServer.render_loop_enabled,"A settled editor preview must stop rendering")
 scene.receive_host_json(JSON.stringify({"version":1,"session":"test-child-session","type":"camera","payload":{"mode":"place","id":"cottage","framing":0.22}}))
 check(RenderingServer.render_loop_enabled,"Another preview camera change wakes the render loop")
 scene.receive_host_json(JSON.stringify({"version":1,"session":"test-child-session","type":"lifecycle","payload":{"paused":true}}))
 check(not scene.panel_preview and not RenderingServer.render_loop_enabled,"Backgrounding an editor must stop preview rendering")
 scene.receive_host_json(JSON.stringify({"version":1,"session":"wrong-child","type":"lifecycle","payload":{"paused":false}}))
 check(scene.paused,"Stale child session must not control scene")
 var retained_rig=scene.resident.model.rig
 scene.clear_host_session()
 check(scene.session=="" and scene.data.items.is_empty() and scene.data.inventory.is_empty(),"Native teardown releases child identifiers and owned objects")
 check(scene.paused and scene.selected_id=="" and scene.resident.target_id=="","Native teardown stops previews and activities")
 scene.receive_host_json(JSON.stringify({"version":1,"session":"next-child","type":"snapshot","payload":{"items":items,"land":[],"appearance":{"hair":3},"approvedWins":2}}))
 scene.receive_host_json(JSON.stringify({"version":1,"session":"next-child","type":"lifecycle","payload":{"paused":false}}))
 check(scene.session=="next-child" and not scene.paused and scene.data.items.size()==items.size(),"The same native engine can reopen for another child")
 check(scene.resident.model.rig==retained_rig,"Native reopening retains the active rig")
 scene.receive_host_json(JSON.stringify({"version":1,"session":"next-child","type":"sunrise","payload":{}}))
 check(scene.sunrise_remaining==3.6 and scene.resident.activity=="A sunny day","A new approval asks the valley to notice")
 scene._process(1.8)
 check(scene.sun.light_energy>0.92,"The sun lifts while the sunny day plays")
 scene.reduced_motion=true
 scene._process(0.1)
 check(scene.sunrise_remaining==0 and is_equal_approx(scene.sun.light_energy,0.92),"Reduce Motion returns the sun immediately")
 scene.receive_host_json(JSON.stringify({"version":1,"session":"test-child-session","type":"select","payload":{"id":"cottage"}}))
 check(scene.selected_id=="","Prior child callbacks cannot mutate the reopened scene")
 var tree_items=[{"id":"cottage","kind":"cottage","cell":{"x":3,"z":2},"rotation":0},{"id":"garden","kind":"garden","cell":{"x":2,"z":10},"rotation":0},{"id":"path","kind":"path","cell":{"x":5,"z":5},"rotation":0},{"id":"tree","kind":"tree","cell":{"x":12,"z":2},"rotation":0}]
 scene.receive_host_json(JSON.stringify({"version":1,"session":"next-child","type":"snapshot","payload":{"items":tree_items,"land":[],"appearance":{"hair":3},"approvedWins":0,"growthTreeID":"tree"}}))
 var seedling=scene.presentation.nodes.tree.get_child(0)
 check(seedling.get_meta("growth_stage",-1)==0 and seedling.get_meta("canopy_radius",9.0)<=0.5,"The mission tree starts as its own seedling")
 scene.receive_host_json(JSON.stringify({"version":1,"session":"next-child","type":"snapshot","payload":{"items":tree_items,"land":[],"appearance":{"hair":3},"approvedWins":13,"growthTreeID":"tree"}}))
 var mature=scene.presentation.nodes.tree.get_child(0)
 check(mature.get_meta("growth_stage",-1)==2 and mature.get_meta("canopy_radius",9.0)<=2.0 and is_equal_approx(mature.scale.x,1.0),"The grown mission tree keeps its own form inside its plot")
 scene.reduced_motion=false
 messages.clear()
 scene.receive_host_json(JSON.stringify({"version":1,"session":"next-child","type":"waterTree","payload":{"count":2}}))
 check(scene.resident.watering_remaining==2 and scene.resident.target_id=="tree" and scene.presentation.pending_tree_growth==2,"New approvals walk the child to water the mission tree")
 check(scene.navigation.well_center.is_finite() and scene.resident.fetching_water,"Mission watering first visits the free well")
 check(not scene.data.items.any(func(item): return item.kind=="well"),"The well adds no saved placement or purchase")
 var well_box=Rect2i(scene.navigation.well_cell,HomesteadItems.WELL_SIZE)
 for item in scene.data.items:
  check(not well_box.intersects(Rect2i(item.cell,HomesteadItems.footprint(item.kind,item.rotation))),"The well never displaces saved places or paths")
 check(scene.presentation.nodes.tree.get_child(0).get_meta("growth_stage",-1)==1,"The tree waits at the earlier form until each watering finishes")
 check(not messages.any(func(message): return message.type=="placementIntent"),"Watering the tree does not buy or move it")
 if scene.resident.fetching_water:
  scene.resident.state="fill"
  scene.resident.finish_activity()
  check(scene.resident.carrying_water and not scene.resident.fetching_water,"Refilling at the well starts the loaded return trip")
 scene.resident.state="water"
 scene.resident.finish_activity()
 check(scene.presentation.pending_tree_growth==1 and scene.resident.watering_remaining==1 and scene.resident.state=="water","One watering grows the tree by one mission")
 scene.resident.finish_activity()
 check(scene.presentation.pending_tree_growth==0 and scene.resident.watering_remaining==0 and scene.presentation.nodes.tree.get_child(0).get_meta("growth_stage",-1)==2,"The child stops once every new mission is watered")
 var growing_tree=scene.presentation.nodes.tree.get_child(0).get_node("MissionTree")
 scene.receive_host_json(JSON.stringify({"version":1,"session":"next-child","type":"treeLeaves","payload":{"yellow":true}}))
 var thirsty=scene.presentation.nodes.tree.get_child(0)
 check(thirsty.get_node("MissionTree")==growing_tree and scene.data.approvals==13,"Thirst updates the living tree in place without changing earned wins")
 check(thirsty.get_meta("yellow_leaves",false) and thirsty.get_meta("growth_stage",-1)==2 and thirsty.get_meta("canopy_radius",9.0)<=2.0,"A missed day yellows a few leaves without shrinking the earned tree")
 scene.receive_host_json(JSON.stringify({"version":1,"session":"next-child","type":"waterTree","payload":{"count":1}}))
 if scene.resident.fetching_water:
  scene.resident.state="fill"
  scene.resident.finish_activity()
  check(scene.resident.carrying_water and not scene.resident.fetching_water,"Refilling at the well starts the loaded return trip")
 scene.resident.state="water"
 scene.resident.finish_activity()
 check(not scene.presentation.nodes.tree.get_child(0).get_meta("yellow_leaves",true) and scene.presentation.nodes.tree.get_child(0).get_meta("growth_stage",-1)==2,"Watering clears the yellow leaves and keeps the earned tree")
 scene.receive_host_json(JSON.stringify({"version":1,"session":"next-child","type":"treeLeaves","payload":{"yellow":true}}))
 scene.receive_host_json(JSON.stringify({"version":1,"session":"next-child","type":"waterTree","payload":{"count":1}}))
 scene.receive_host_json(JSON.stringify({"version":1,"session":"next-child","type":"treeLeaves","payload":{"yellow":false}}))
 check(scene.presentation.yellow_leaves,"Host approval waits for the queued watering before the canopy recovers")
 scene.receive_host_json(JSON.stringify({"version":1,"session":"third-child","type":"snapshot","payload":{"items":tree_items,"land":[],"appearance":{"hair":3},"approvedWins":0,"growthTreeID":"tree"}}))
 check(scene.presentation.pending_tree_growth==0 and not scene.presentation.yellow_leaves and scene.resident.watering_remaining==0,"Changing children clears the previous child's watering and cosmetic thirst")
 var new_seed=scene.presentation.nodes.tree.get_child(0).get_node("MissionTree")
 check(new_seed.wins==0 and new_seed.thirst==0.0 and new_seed.fallen.is_empty(),"A new child's planted seed inherits neither growth nor thirst animation")
 var quiet_tree_payload={"items":tree_items,"land":[],"appearance":{"hair":3},"approvedWins":1,"growthTreeID":"tree","reducedMotion":true}
 var quiet_navigation=scene.navigation.revision
 scene.receive_host_json(JSON.stringify({"version":1,"session":"third-child","type":"snapshot","payload":quiet_tree_payload}))
 var first_quiet_size=scene.presentation.nodes.tree.get_child(0).get_node("MissionTree").body.scale.y
 quiet_tree_payload.approvedWins=2
 scene.receive_host_json(JSON.stringify({"version":1,"session":"third-child","type":"snapshot","payload":quiet_tree_payload}))
 var quiet_seedling=scene.presentation.nodes.tree.get_child(0).get_node("MissionTree")
 check(quiet_seedling.wins==2 and quiet_seedling.body.scale.y>first_quiet_size,"Reduce Motion still grows the seedling on every approved mission within a stage")
 check(scene.navigation.revision==quiet_navigation,"Earned tree growth does not rebuild navigation")
 quiet_tree_payload.approvedWins=3
 quiet_tree_payload.reducedMotion=false
 scene.receive_host_json(JSON.stringify({"version":1,"session":"third-child","type":"snapshot","payload":quiet_tree_payload}))
 scene.receive_host_json(JSON.stringify({"version":1,"session":"third-child","type":"waterTree","payload":{"count":1}}))
 check(scene.presentation.pending_tree_growth==1,"A new approval can queue its watering presentation")
 quiet_tree_payload.reducedMotion=true
 scene.receive_host_json(JSON.stringify({"version":1,"session":"third-child","type":"snapshot","payload":quiet_tree_payload}))
 check(scene.presentation.pending_tree_growth==0 and scene.resident.watering_remaining==0 and not scene.resident.fetching_water,"Enabling Reduce Motion during a trip clears animation deferral")
 check(scene.presentation.nodes.tree.get_child(0).get_node("MissionTree").wins==3,"Cancelled animation immediately shows the earned young tree")
 quiet_tree_payload.reducedMotion=false
 quiet_tree_payload.approvedWins=4
 scene.receive_host_json(JSON.stringify({"version":1,"session":"third-child","type":"snapshot","payload":quiet_tree_payload}))
 scene.receive_host_json(JSON.stringify({"version":1,"session":"third-child","type":"waterTree","payload":{"count":1}}))
 quiet_tree_payload.items=tree_items.filter(func(item): return item.id!="tree")
 quiet_tree_payload.growthTreeID=""
 scene.receive_host_json(JSON.stringify({"version":1,"session":"third-child","type":"snapshot","payload":quiet_tree_payload}))
 check(scene.presentation.pending_tree_growth==0 and scene.resident.watering_remaining==0 and scene.data.approvals==4,"Removing the target cancels only the water trip, preserving approved wins")
 var crowded_items=[{"id":"dense-garden","kind":"garden","cell":{"x":8,"z":8},"rotation":0}]
 for z in 20:
  for x in 20:
   if Rect2i(8,8,3,2).has_point(Vector2i(x,z)): continue
   crowded_items.append({"id":"floor-%d-%d"%[x,z],"kind":"path","cell":{"x":x,"z":z},"rotation":0})
 var crowded_data=HomesteadWorldData.new()
 check(crowded_data.apply_snapshot({"items":crowded_items,"land":[],"approvedWins":0}),"Crowded saved layouts remain valid")
 var crowded_nav=HomesteadNavigation.new()
 crowded_nav.rebuild(crowded_data)
 var crowded_child=HomesteadResident.new()
 scene.add_child(crowded_child)
 crowded_child.setup(crowded_data,crowded_nav)
 crowded_child.visit("dense-garden")
 check(not crowded_nav.well_center.is_finite() and not crowded_child.fetching_water and crowded_child.target_id=="dense-garden","A full saved layout skips the well detour and keeps gardening available")
 # Visibility is presentation-only: no saved place moves to clear a sightline.
 var clear_data=HomesteadWorldData.new()
 clear_data.apply_snapshot({"items":[{"id":"clear-cottage","kind":"cottage","cell":{"x":7,"z":3},"rotation":0},{"id":"clear-tree","kind":"tree","cell":{"x":12,"z":7},"rotation":0},{"id":"clear-garden","kind":"garden","cell":{"x":4,"z":8},"rotation":0}],"land":[],"approvedWins":13})
 var saved_layout=JSON.stringify(clear_data.items)
 var clear_nav=HomesteadNavigation.new()
 clear_nav.rebuild(clear_data)
 var well_outline=HomesteadVisibility.projected_box(clear_nav.well_center,Vector3(1.05,HomesteadItems.WELL_HEIGHT,0.95),clear_nav.view_direction)
 for place in clear_data.items:
  check(HomesteadVisibility.overlap(well_outline,HomesteadVisibility.item_bounds(place,clear_nav.view_direction))<0.01,"The sparse clearing gives the well a separate projected silhouette")
 check(JSON.stringify(clear_data.items)==saved_layout,"Sightline planning never rewrites saved coordinates")
 var badge_one=scene.presentation.make_status_bubble()
 var badge_two=scene.presentation.make_status_bubble()
 var field=scene.data.find("garden")
 var badge_anchor=HomesteadItems.item_center(field)+Vector3(0,1.65,0)
 for badge in [badge_one,badge_two]:
  badge.set_meta("marker_anchor",badge_anchor)
  badge.set_meta("marker_place_id",field.id)
  badge.get_meta("body").set_meta("production_station","field")
 badge_one.set_meta("marker_role","material")
 badge_two.set_meta("marker_role","field")
 var marker_study=HomesteadVisibility.new()
 marker_study.markers([badge_one,badge_two],scene.data.items)
 var material_slot=badge_one.global_position
 var product_slot=badge_two.global_position
 scene.resident.position+=Vector3(3,0,2)
 scene.camera.size*=1.2
 badge_two.get_meta("label").text="0:30"
 marker_study.markers([badge_two],scene.data.items)
 check(badge_two.global_position.is_equal_approx(product_slot),"The product marker keeps its fixed world slot through walking, zoom, timer changes and absent neighbours")
 marker_study.markers([badge_two,badge_one],scene.data.items)
 check(badge_one.global_position.is_equal_approx(material_slot) and badge_two.global_position.is_equal_approx(product_slot),"Marker order does not rearrange the reserved slots")
 for badge in [badge_one,badge_two]:
  check(badge.get_meta("body").global_position.is_equal_approx(badge.global_position) and badge.get_meta("body").get_meta("production_station")=="field","The fixed badge preserves its original tap action")
 check(material_slot.distance_to(product_slot)>1.2,"The fixed material and product slots retain separate hit areas")
 scene.queue_free()
 await process_frame
 print("HOMESTEAD_RUNTIME_TESTS failures=",failures)
 quit(0 if failures==0 else 1)
