class_name HomesteadWorkbench
extends CanvasLayer
# Foreground furniture only. Native Tuvlo stages ingredients and commits jobs.
signal layout_ready(payload: Dictionary)
signal redraw_requested
var identity=""
var viewport=SubViewport.new()
var container=SubViewportContainer.new()
var world=Node3D.new()
var camera=Camera3D.new()
var furniture=Node3D.new()
var tokens={}
var token_data=[]
var rings: Array[MeshInstance3D]=[]
var satchel=Node3D.new()
var anvil_surface: MeshInstance3D
var logical_size=Vector2.ZERO
var point_scale=50.0
var slot_spacing=1.25
var back_lift=0.0
var anvil_width=3.1
var lever=Node3D.new()
var press=Node3D.new()
var heat=ColorRect.new()
var sparks: Array[MeshInstance3D]=[]
var flash=OmniLight3D.new()
var result=Node3D.new()
var reduced_motion=false
var burst=0.0
var pull=0.0
var last_size=Vector2i.ZERO
var last_layout=""
var drag_key=""

func _ready():
 layer=5
 var shade=ColorRect.new()
 shade.color=Color(0.035,0.045,0.035,0.38)
 shade.mouse_filter=Control.MOUSE_FILTER_IGNORE
 add_child(shade)
 get_viewport().size_changed.connect(func():
  shade.size=get_viewport().get_visible_rect().size
  resize()
  if visible: redraw_requested.emit())
 shade.size=get_viewport().get_visible_rect().size
 container.mouse_filter=Control.MOUSE_FILTER_IGNORE
 container.stretch=true
 add_child(container)
 viewport.own_world_3d=true
 viewport.transparent_bg=true
 viewport.msaa_3d=Viewport.MSAA_2X
 container.add_child(viewport)
 viewport.size_changed.connect(publish_layout)
 viewport.add_child(world)
 world.add_child(furniture)
 world.add_child(result)
 result.position=Vector3(0,2.07,0); result.scale=Vector3.ONE*1.45
 world.add_child(camera)
 camera.projection=Camera3D.PROJECTION_ORTHOGONAL
 camera.position=Vector3(0,7.8,11)
 camera.look_at(Vector3(0,0.8,0))
 camera.current=true
 var environment=WorldEnvironment.new()
 var settings=Environment.new()
 settings.background_mode=Environment.BG_COLOR
 settings.background_color=Color(0,0,0,0)
 settings.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
 settings.ambient_light_color=Color("f2dfbd")
 settings.ambient_light_energy=0.65
 environment.environment=settings
 world.add_child(environment)
 for spec in [[Vector3(-55,-25,0),Color("fff0d0"),1.0],[Vector3(-25,140,0),Color("b7d8d8"),0.45]]:
  var light=DirectionalLight3D.new()
  light.rotation_degrees=spec[0]; light.light_color=spec[1]; light.light_energy=spec[2]
  light.shadow_enabled=true
  world.add_child(light)
 build_furniture()
 flash.position=Vector3(0,2,0)
 flash.light_color=Color("ffb34f")
 flash.omni_range=5
 world.add_child(flash)
 heat.mouse_filter=Control.MOUSE_FILTER_IGNORE
 var shader=ShaderMaterial.new()
 shader.shader=preload("res://scripts/workbench_heat.gdshader")
 heat.material=shader
 add_child(heat)
 close()

func metal(node: MeshInstance3D) -> MeshInstance3D:
 var material=node.material_override.duplicate()
 material.metallic=0.72; material.roughness=0.31
 node.material_override=material
 return node

func build_furniture():
 # Rounded oak, forged iron and small brass fixings share the valley's warmth.
 HomesteadMesh.box(furniture,Vector3(0,0.68,0),Vector3(9.2,0.38,3.3),"866044",0.15)
 HomesteadMesh.box(furniture,Vector3(0,0.9,0),Vector3(9.35,0.12,3.4),"b68d61",0.09)
 for x in [-3.7,3.7]:
  for z in [-1.0,1.0]:
   HomesteadMesh.box(furniture,Vector3(x,-0.15,z),Vector3(0.42,1.55,0.42),"6d4b35",0.08)
   metal(HomesteadMesh.box(furniture,Vector3(x,0.5,z),Vector3(0.46,0.12,0.46),"575e59",0.025))
 for z in [-1.25,-0.65,0.1,0.8,1.4]:
  HomesteadMesh.box(furniture,Vector3(0,0.969,z),Vector3(9.0,0.008,0.016),"79553c",0)
 for x in [-4.3,4.3]:
  for z in [-1.35,1.35]: metal(HomesteadMesh.cylinder(furniture,Vector3(x,0.98,z),0.065,0.035,"b99d63"))
 # Central anvil; the horn and heel remain distinct from the ingredient slots.
 HomesteadMesh.box(furniture,Vector3(0,1.04,0),Vector3(2.35,0.18,1.35),"4d5759",0.08)
 metal(HomesteadMesh.box(furniture,Vector3(0,1.43,0),Vector3(0.95,0.7,0.78),"677371",0.11))
 anvil_surface=metal(HomesteadMesh.box(furniture,Vector3(0,1.87,0),Vector3(3.1,0.22,1.1),"aab8b4",0.08))
 for x in [-1.15,1.15]: metal(HomesteadMesh.box(furniture,Vector3(x,2.05,-0.9),Vector3(0.17,2.15,0.2),"66716a",0.04))
 metal(HomesteadMesh.box(furniture,Vector3(0,3.17,-0.5),Vector3(2.65,0.22,1.15),"78847a",0.07))
 furniture.add_child(press); press.position=Vector3(0,3.1,0)
 metal(HomesteadMesh.cylinder(press,Vector3(0,0.35,0),0.13,0.8,"b7ab80"))
 metal(HomesteadMesh.box(press,Vector3.ZERO,Vector3(1.05,0.38,0.75),"b49a62",0.06))
 var horn=metal(HomesteadMesh.cylinder(furniture,Vector3(-1.8,1.84,0),0.39,1.25,"9aa8a5",0.045))
 horn.rotation.z=-PI/2
 for x in [-0.72,0,0.72]:
  var ring=HomesteadMesh.torus(furniture,Vector3(x,2.004,0),0.23,0.016,"d6b76c")
  ring.scale=Vector3(1,0.5,1)
  rings.append(ring)
 # Open satchel: substantial leather sides, rolled lip and an arched strap.
 furniture.add_child(satchel)
 HomesteadMesh.box(satchel,Vector3(-3.1,1.2,0.45),Vector3(1.95,0.58,2.4),"8c6041",0.22)
 HomesteadMesh.box(satchel,Vector3(-3.1,1.52,0.45),Vector3(1.75,0.12,2.17),"c49b65",0.17)
 HomesteadMesh.box(satchel,Vector3(-3.1,1.59,0.45),Vector3(1.49,0.06,1.95),"493c30",0.12)
 for z in [-0.72,1.62]:
  HomesteadMesh.box(satchel,Vector3(-3.1,1.3,z),Vector3(0.21,0.55,0.07),"cba773",0.04)
  metal(HomesteadMesh.box(satchel,Vector3(-3.1,1.28,z+0.01),Vector3(0.27,0.19,0.06),"d0b06b",0.025))
 var previous=Vector3(-3.95,1.3,-0.45)
 for i in range(1,13):
  var angle=PI-float(i)*PI/12
  var point=Vector3(-3.1+cos(angle)*0.85,1.3+sin(angle)*1.25,-0.45)
  HomesteadMesh.rod(satchel,previous,point,0.07,"674633")
  previous=point
 # A real pivot and grip; a pull rotates the entire linkage rather than a flat icon.
 HomesteadMesh.box(furniture,Vector3(3.25,1.15,0),Vector3(0.75,0.4,1.0),"4d5a58",0.1)
 furniture.add_child(lever); lever.position=Vector3(3.25,1.34,0)
 metal(HomesteadMesh.cylinder(lever,Vector3.ZERO,0.23,0.85,"c5ac73")).rotation.z=PI/2
 metal(HomesteadMesh.rod(lever,Vector3.ZERO,Vector3(0,1.6,0),0.09,"c0b58f"))
 HomesteadMesh.ellipsoid(lever,Vector3(0,1.72,0),Vector3(0.3,0.24,0.26),"b46b45")
 metal(HomesteadMesh.rod(furniture,Vector3(3.25,1.34,0),Vector3(1.15,1.34,-0.9),0.08,"a88d59"))
 for i in 18:
  var spark=HomesteadMesh.ellipsoid(world,Vector3.ZERO,Vector3.ONE*0.035,"ffcf75")
  var material=spark.material_override.duplicate()
  material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
  spark.material_override=material; spark.visible=false; sparks.append(spark)

func open(payload: Dictionary):
 var next_id=str(payload.get("id",""))
 if next_id.is_empty(): return
 var display=Vector2(float(payload.get("displayWidth",0)),float(payload.get("displayHeight",0)))
 if display.is_finite() and display.x>0 and display.y>0 and display!=logical_size:
  logical_size=display; last_size=Vector2i.ZERO
 if identity!=next_id:
  identity=next_id; burst=0; pull=0; drag_key=""; last_layout=""
 visible=true
 reduced_motion=payload.get("reducedMotion",false)==true
 if reduced_motion: burst=0
 var next_tokens=payload.get("tokens",[]).slice(0,4)
 if next_tokens.size()!=token_data.size(): last_size=Vector2i.ZERO
 token_data=next_tokens
 for i in rings.size():
  rings[i].visible=i<token_data.size()
  rings[i].position.x=(float(i)-(token_data.size()-1)*0.5)*slot_spacing
 drag_key=""
 var output=str(payload.get("output","bread"))
 if result.get_meta("good","")!=output:
  for child in result.get_children(): result.remove_child(child); child.queue_free()
  resource_token(result,output); result.set_meta("good",output)
 result.visible=int(payload.get("state",0))==2
 var alive={}
 for index in token_data.size():
  var data: Dictionary=token_data[index]
  var key=str(data.get("key","")); alive[key]=true
  if not tokens.has(key):
   var token=Node3D.new(); world.add_child(token); tokens[key]=token
   resource_token(token,str(data.get("good","wheat")))
  var node: Node3D=tokens[key]
  node.position=token_position(index,data.get("loaded",false)==true)
  node.scale=Vector3.ONE*(1.0 if data.get("available",false)==true else 0.65)
  node.visible=int(payload.get("state",0))==0
 for key in tokens.keys():
  if not alive.has(key): tokens[key].queue_free(); tokens.erase(key)
 set_pull(float(payload.get("pull",0)))
 resize()
 publish_layout()

func token_position(index: int,loaded: bool) -> Vector3:
 if loaded: return Vector3((float(index)-(token_data.size()-1)*0.5)*slot_spacing,2.13,0)
 return Vector3(-3.1+satchel.position.x+(float(index%2)-0.5)*slot_spacing,1.78+(back_lift if index<2 else 0.0),-0.5+float(index/2)*2.2)

func resource_token(root: Node3D,good: String):
 HomesteadMesh.cylinder(root,Vector3(0,0.02,0),0.29,0.08,"c2a46b")
 match good:
  "wood":
   for point in [Vector3(-0.03,0.13,-0.11),Vector3(0.03,0.13,0.11),Vector3(0,0.3,0)]:
    var log_piece=HomesteadMesh.cylinder(root,point,0.105,0.5,"886044")
    log_piece.rotation.z=PI/2
    var end=HomesteadMesh.cylinder(root,point+Vector3(0.255,0,0),0.083,0.012,"d4b37d")
    end.rotation.z=PI/2
  "stone":
   for spec in [[Vector3(-0.12,0.12,0),Vector3(0.18,0.13,0.17)],[Vector3(0.12,0.14,0.08),Vector3(0.2,0.15,0.18)],[Vector3(0,0.3,0),Vector3(0.14,0.13,0.13)]]:
    HomesteadMesh.ellipsoid(root,spec[0],spec[1],"919b91")
  "food":
   HomesteadMesh.box(root,Vector3(0,0.17,0),Vector3(0.45,0.28,0.36),"9c906b",0.08)
   HomesteadMesh.rod(root,Vector3(-0.24,0.33,0),Vector3(0.24,0.33,0),0.02,"ebd7aa")
   HomesteadMesh.ellipsoid(root,Vector3(0,0.35,0.08),Vector3(0.2,0.09,0.1),"c99459")
  "wheat":
   for i in 3:
    var x=(i-1)*0.12
    HomesteadMesh.rod(root,Vector3(x,0.07,0),Vector3(x,0.64,0),0.017,"a98746")
    for j in 3:
     for side in [-1,1]: HomesteadMesh.ellipsoid(root,Vector3(x+side*0.055,0.36+j*0.08,0),Vector3(0.07,0.085,0.05),"edcb7c")
  "flour":
   HomesteadMesh.ellipsoid(root,Vector3(0,0.27,0),Vector3(0.25,0.26,0.22),"eddbb6")
   HomesteadMesh.cylinder(root,Vector3(0,0.5,0),0.15,0.08,"a1b586")
   HomesteadMesh.ellipsoid(root,Vector3(0,0.56,0),Vector3(0.17,0.08,0.15),"fff0ce")
  "bread":
   HomesteadMesh.ellipsoid(root,Vector3(0,0.2,0),Vector3(0.29,0.18,0.23),"bc7e3d")
   for x in [-0.12,0,0.12]: HomesteadMesh.rod(root,Vector3(x-0.04,0.34,-0.08),Vector3(x+0.04,0.36,0.08),0.018,"f6daa1")
  "fruit":
   for point in [Vector3(-0.1,0.19,0),Vector3(0.1,0.2,0.05)]:
    HomesteadMesh.ellipsoid(root,point,Vector3.ONE*0.17,"ba7052")
    HomesteadMesh.ellipsoid(root,point+Vector3(0.05,0.16,0),Vector3(0.1,0.03,0.06),"718d66")
  "tart":
   HomesteadMesh.cylinder(root,Vector3(0,0.15,0),0.25,0.15,"d1a261")
   HomesteadMesh.cylinder(root,Vector3(0,0.24,0),0.21,0.035,"b9654b")
   for x in [-0.1,0,0.1]: HomesteadMesh.rod(root,Vector3(x,0.27,-0.15),Vector3(x,0.27,0.15),0.018,"f3dca4")
  _:
   HomesteadMesh.box(root,Vector3(0,0.2,0),Vector3(0.42,0.3,0.36),"bda47a",0.09)
   HomesteadMesh.rod(root,Vector3(-0.23,0.37,0),Vector3(0.23,0.37,0),0.018,"e9d9b2")

func set_pull(value: float):
 if not is_finite(value): return
 pull=clampf(value,0,1)
 lever.rotation.x=lerpf(-0.15,1.25,pull)
 press.position.y=3.1-pull*0.8

func drag(payload: Dictionary):
 var key=str(payload.get("key",""))
 if not tokens.has(key): return
 if not is_finite(float(payload.get("x",0))) or not is_finite(float(payload.get("y",0))): return
 drag_key=key
 var point=Vector2(clampf(float(payload.get("x",0)),0,1),clampf(float(payload.get("y",0)),0,1))*Vector2(viewport.size)
 var origin=camera.project_ray_origin(point)
 var direction=camera.project_ray_normal(point)
 var intersection=Plane(Vector3.UP,2.25).intersects_ray(origin,direction)
 if intersection!=null: tokens[key].position=intersection

func celebrate():
 drag_key=""; pull=0; set_pull(0)
 burst=0.95 if not reduced_motion else 0.0

func close():
 visible=false; identity=""; burst=0; drag_key=""; pull=0
 if is_instance_valid(heat): heat.visible=false
 for spark in sparks: spark.visible=false
 flash.light_energy=0

func cancel_motion():
 burst=0; drag_key=""; set_pull(0)
 heat.visible=false; flash.light_energy=0
 for spark in sparks: spark.visible=false

func needs_frames() -> bool: return visible and (burst>0 or not drag_key.is_empty() or pull>0)

func advance(delta: float):
 if not visible: return
 resize()
 burst=maxf(0,burst-delta)
 var t=1.0-burst/0.95
 var glow=sin(t*PI)*0.65 if burst>0 and not reduced_motion else 0.0
 if burst>0 and not reduced_motion: press.position.y=3.1-0.8*(1.0-smoothstep(0,0.24,t))
 flash.light_energy=glow
 heat.visible=glow>0.001
 if heat.visible:
  heat.material.set_shader_parameter("phase",t)
  heat.material.set_shader_parameter("strength",glow)
  heat.material.set_shader_parameter("center",camera.unproject_position(Vector3(0,2.4,0))/Vector2(viewport.size))
  heat.material.set_shader_parameter("extent",Vector2(1.6,1.0)*Vector2(viewport.size.x,viewport.size.x)/camera.size/Vector2(viewport.size))
  heat.material.set_shader_parameter("distortion",Vector2.ONE*1.5/(logical_size if logical_size.x>0 else Vector2(viewport.size)))
 for i in sparks.size():
  var spark=sparks[i]
  spark.visible=burst>0 and not reduced_motion
  var angle=i*2.39996
  spark.position=Vector3(cos(angle)*t*(0.6+float(i%3)*0.3),2.05+sin(t*PI)*(.7+float(i%5)*0.12),sin(angle)*t*0.6)
  spark.scale=Vector3.ONE*0.035*maxf(0.01,1.0-t)

func resize():
 var size=Vector2i(get_viewport().get_visible_rect().size)
 if size==last_size: return
 last_size=size; container.size=Vector2(size); heat.size=Vector2(size)
 camera.keep_aspect=Camera3D.KEEP_WIDTH
 # Fit in logical points, not Retina pixels or a constant screen fraction.
 # Large iPads retain map context; small phones retain usable manipulation.
 var display=logical_size if logical_size.x>0 else Vector2(size)
 var width_limit=minf(display.x*0.52,480.0)
 point_scale=maxf(12.0,minf(width_limit/9.35,maxf(1.0,display.y-192.0)/4.85))
 camera.size=display.x/point_scale
 camera.v_offset=0.375-32.0/point_scale
 slot_spacing=maxf(1.25,50.0/point_scale)
 back_lift=maxf(0,(50.0/point_scale-2.2*0.536)/0.844)
 var left_slot=-(maxi(1,token_data.size())-1)*slot_spacing*0.5
 satchel.position.x=minf(0,left_slot-maxf(1.0,56.0/point_scale)-slot_spacing*0.5+3.1)
 anvil_width=maxf(3.1,(token_data.size()-1)*slot_spacing+0.6)
 if is_instance_valid(anvil_surface): anvil_surface.scale.x=anvil_width/3.1
 for i in rings.size(): rings[i].position.x=(float(i)-(token_data.size()-1)*0.5)*slot_spacing
 for i in token_data.size():
  var key=str(token_data[i].key)
  if tokens.has(key) and key!=drag_key: tokens[key].position=token_position(i,token_data[i].get("loaded",false)==true)
 publish_layout()

func publish_layout():
 if identity.is_empty() or viewport.size.x<2: return
 var rects={}
 rects["bench"]=anchor(Vector3(0,1.245,0),Vector2(9.35,4.85))
 rects["anvil"]=anchor(Vector3(0,2.0,0),Vector2(anvil_width+0.2,1.2))
 rects["lever"]=anchor(Vector3(3.25,2.3,0),Vector2(1.0,1.8))
 for i in token_data.size():
  var data: Dictionary=token_data[i]
  rects[str(data.key)]=anchor(token_position(i,data.get("loaded",false)==true),Vector2(0.68,0.68))
 var payload={"id":identity,"rects":rects}
 var signature=JSON.stringify(payload)
 if signature!=last_layout: last_layout=signature; layout_ready.emit(payload)

func anchor(point: Vector3,size: Vector2) -> Dictionary:
 var center=camera.unproject_position(point)/Vector2(viewport.size)
 var scale=Vector2(viewport.size.x,viewport.size.x)/camera.size
 var dimensions=size*scale/Vector2(viewport.size)
 return {"x":center.x-dimensions.x/2,"y":center.y-dimensions.y/2,"w":dimensions.x,"h":dimensions.y}
