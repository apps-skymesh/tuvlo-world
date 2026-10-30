extends "res://tests/mac_playground.gd"
# Disposable, repeatable turf views using the production scene and materials.
func run():
 await super.run()
 root.always_on_top=true
 root.grab_focus()
 # A compositor that stops drawing must fail rather than hang the review.
 create_timer(45.0).timeout.connect(func():
  push_error("Turf review exceeded 45 seconds")
  quit(1))
 capture_times=[]
 duration=0.0
 payload.land=["west"]
 payload.reducedMotion="--reduce-motion" in OS.get_cmdline_user_args()
 snapshot()
 world.resident.set_physics_process(false)
 camera("overview")
 await save_view("overview")
 send("camera",{"mode":"place","id":"cottage"})
 await save_view("close-up")
 send("select",{"id":"cottage"})
 await save_view("draft")
 send("cancel")
 world.pan_focus=Vector3(-9.0,0.0,1.0)
 world.pan_size=12.0
 send("camera",{"mode":"pan","resetZoom":true})
 await save_view("owned-seam")
 var report={"engine":Engine.get_version_info(),"platform":OS.get_name(),
  "renderer":RenderingServer.get_video_adapter_name(),"viewport":str(root.size),
  "reducedMotion":world.reduced_motion,
  "meadowSHA256":FileAccess.get_sha256("res://scripts/meadow.gdshader"),
  "valleySHA256":FileAccess.get_sha256("res://scripts/valley.gdshader")}
 var file=FileAccess.open(output+"/turf-manifest.json",FileAccess.WRITE)
 file.store_string(JSON.stringify(report,"  "))
 print("TURF_REVIEW_COMPLETE")
 quit()

func save_view(label: String):
 await create_timer(2.0).timeout
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(output+"/"+label+".png")
