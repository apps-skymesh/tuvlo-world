extends "res://tests/mac_playground.gd"
# Interactive art workbench only; uses the real resident and disposable world.
var avatar_look=HomesteadAppearance.DEFAULT.duplicate()
var avatar_pose="idle"
var walk_target=0
var walk_wait=0.0
var review_frame_path=""
var force_review_frames=false

func run():
    var args=OS.get_cmdline_user_args()
    for i in args.size():
        if args[i]=="--avatar-look" and i+1<args.size():
            for pair in args[i+1].split(","):
                var entry=pair.split("=")
                if entry.size()==2 and avatar_look.has(entry[0]): avatar_look[entry[0]]=int(entry[1])
        if args[i]=="--avatar-pose" and i+1<args.size(): avatar_pose=args[i+1]
        if args[i]=="--avatar-frame" and i+1<args.size(): review_frame_path=args[i+1]
        if args[i]=="--avatar-force-frames": force_review_frames=true
    avatar_look=HomesteadAppearance.normalize(avatar_look)
    super.run()
    root.always_on_top=true
    root.grab_focus()
    world.resident.position=HomesteadItems.cell_center(Vector2i(9,8))
    world.resident.facing=.35
    world.resident.rotation.y=.35
    world.resident.desired_facing=.35
    world.resident.model.apply_appearance(avatar_look)
    world.pan_focus=world.resident.position+Vector3(0,.9,0)
    world.pan_size=2.8
    send("camera",{"mode":"pan","resetZoom":true})
    choose_pose(avatar_pose)
    world._process(1.0/60.0)
    if review_frame_path!="": call_deferred("save_review_frame")

func draw_review_frame():
    RenderingServer.force_draw(false,1.0/24.0)

func save_review_frame():
    # A single requested viewport render, after the camera has settled. This is
    # an art artifact, not a timed capture, movement test or physical screenshot.
    for frame in 6: await process_frame
    if avatar_pose in ["sit","read"]: await create_timer(1.2).timeout
    RenderingServer.force_draw()
    root.get_texture().get_image().save_png(review_frame_path)
    print("Avatar review frame saved: ",review_frame_path)

func build_controls():
    var layer=CanvasLayer.new()
    root.add_child(layer)
    var panel=PanelContainer.new()
    panel.position=Vector2(14,14)
    layer.add_child(panel)
    var column=VBoxContainer.new()
    column.add_theme_constant_override("separation",6)
    panel.add_child(column)
    var heading=Label.new()
    heading.text="Avatar fit · disposable"
    column.add_child(heading)
    for field in ["hair","hat","outfit","pattern","face","height","build","glasses","accessory"]:
        var row=HBoxContainer.new()
        column.add_child(row)
        var label=Label.new()
        label.text=field.capitalize()
        label.custom_minimum_size.x=70
        row.add_child(label)
        var choice=OptionButton.new()
        choice.custom_minimum_size.x=140
        for value in HomesteadAppearance.FIELDS[field].options: choice.add_item(value)
        choice.select(avatar_look[field])
        choice.item_selected.connect(func(index):
            world.reset_press()
            avatar_look[field]=index
            world.resident.model.apply_appearance(avatar_look))
        row.add_child(choice)
    var motions=HBoxContainer.new()
    column.add_child(motions)
    for pose in ["idle","walk","water"]:
        button(motions,pose.capitalize(),func(): choose_pose(pose))
    var activities=HBoxContainer.new()
    column.add_child(activities)
    for pose in ["sit","read","wave"]:
        button(activities,pose.capitalize(),func(): choose_pose(pose))
    button(column,"Turn view",func():
        world.resident.facing+=PI/4
        world.resident.desired_facing=world.resident.facing
        world.resident.rotation.y=world.resident.facing)
    activity_label=Label.new()
    column.add_child(activity_label)

func choose_pose(pose: String):
    avatar_pose=pose
    var actor=world.resident
    actor.state="pause"
    actor.timer=3600
    actor.fetching_water=false
    actor.carrying_water=false
    actor.model.carrying_water=false
    actor.model.set_motion("idle" if pose=="walk" else pose)
    walk_wait=0.5

func _process(delta):
    if world==null or world.resident.model==null: return false
    var actor=world.resident
    if avatar_pose=="walk":
        if actor.state!="walking":
            actor.state="pause"
            actor.timer=3600
            walk_wait-=delta
            if walk_wait<=0:
                var cell=Vector2i(7 if walk_target==0 else 12,8)
                actor.walk_to(HomesteadItems.cell_center(cell))
                actor.pace=1.0
                walk_target=1-walk_target
                walk_wait=.7
    else:
        actor.state="pause"
        actor.timer=3600
        actor.model.set_motion(avatar_pose)
    world.pan_focus=actor.position+Vector3(0,.9,0)
    activity_label.text=actor.model.mode
    # Offline art recording must draw each simulation frame even when the OS
    # compositor throttles the window. Never enable this in the shipping World.
    if force_review_frames: call_deferred("draw_review_frame")
    return false
