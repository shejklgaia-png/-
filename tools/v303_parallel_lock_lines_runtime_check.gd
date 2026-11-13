extends SceneTree
## v303: two SERA-origin parallel rays, AND intersection, 0.22s debouncing
## and actual touch-button visibility toggling (all in the training scene).
func _initialize() -> void:
    call_deferred("_run")


func _fail(message: String) -> void:
    push_error("V303_PARALLEL_LOCK_LINES_FAILED: " + message)
    quit(1)


func _run() -> void:
    var scene: PackedScene = load("res://scenes/main.tscn")
    if scene == null:
        _fail("missing training scene")
        return
    var game: Node3D = scene.instantiate()
    root.add_child(game)
    var parts: Node3D = game.get("target_parts")
    var player: CharacterBody3D = game.get("player")
    var target: Node3D = game.get("target")
    var camera: Camera3D = game.get("camera")
    var button: Button = game.get("lock_lines_button")
    var root_lines: Node3D = game.get("lock_line_root")
    var visuals: Array = game.get("lock_line_meshes")
    if parts == null or player == null or target == null or camera == null \
            or button == null or root_lines == null or visuals.size() != 2:
        _fail("scene nodes, debug button or both line meshes unavailable")
        return
    var center: Vector3 = target.global_position
    var front: Vector3 = center + Vector3(0.0,-1.53,9.0)
    var rear: Vector3 = center + Vector3(0.0,-1.53,-9.0)
    player.global_position = front
    var lines: PackedVector3Array = parts.call(
        "get_actor_parallel_lock_segments", front, center)
    if lines.size()!=4:
        _fail("dual line endpoint array not exactly two segments")
        return
    if absf(lines[0].distance_to(lines[2])-0.5)>0.0001 or \
            absf(lines[1].distance_to(lines[3])-0.5)>0.0001:
        _fail("two lines are not separated by 0.50m")
        return
    var a: Vector3 = lines[1]-lines[0]
    var b: Vector3 = lines[3]-lines[2]
    if a.normalized().dot(b.normalized())<0.99999:
        _fail("dual rays are not parallel")
        return
    var left_shift: Vector3 = lines[0]-front
    if absf(left_shift.y)>0.00001:
        _fail("parallel offset tilted vertically")
        return
    var part_id: String = "head"
    if not bool(parts.call("actor_parallel_lines_hits_part",front,center,part_id)):
        _fail("both normal frontal lines should intersect HEAD")
        return
    if str(parts.call("select_actor_parallel_lines_part",front,center)) != part_id:
        _fail("HEAD failed dual-ray selection from SERA front")
        return
    if str(parts.call("select_actor_parallel_lines_part",rear,center)) != "":
        _fail("rear SERA dual rays should select BODY")
        return

    # A narrow artificial probe intersects ONE ray only, despite a valid
    # real mesh. This reproduces gaps between large leg plates reliably.
    var model: Dictionary = parts.get("parts")
    var leg: Node3D = model["leg_fl"]["node"]
    var hidden: Array[MeshInstance3D] = []
    for child in leg.get_children():
        if child is MeshInstance3D and (child as MeshInstance3D).visible:
            hidden.append(child)
            (child as MeshInstance3D).visible = false
    var probe: MeshInstance3D = MeshInstance3D.new()
    probe.name = "SingleRayOnlyTestProbe"
    var probe_box: BoxMesh = BoxMesh.new()
    probe_box.size = Vector3(0.09,0.4,0.25)
    probe.mesh = probe_box
    leg.add_child(probe)
    var sample: Vector3 = lines[2].lerp(lines[3],0.45)
    probe.global_position = sample
    var first: float = float(parts.call("_camera_center_line_part_distance",
        lines[0],lines[1],"leg_fl"))
    var second: float = float(parts.call("_camera_center_line_part_distance",
        lines[2],lines[3],"leg_fl"))
    if first != INF or second == INF:
        _fail("single-line synthetic leg test missed its intended ray")
        return
    if bool(parts.call("actor_parallel_lines_hits_part",front,center,"leg_fl")):
        _fail("one-line-only leg was accepted for AUTO")
        return
    if str(parts.call("select_actor_parallel_lines_part",front,center)) != "head":
        _fail("one-line-only leg overrode the fully intersected HEAD")
        return
    probe.queue_free()
    for child in hidden:
        child.visible = true

    game.set("auto_lock_enabled",true)
    game.set("manual_part_lock_active",false)
    game.set("auto_lock_initialized",false)
    game.set("locked_target_part_id","")
    game.call("_acquire_stable_camera_part",0.016,false)
    if str(game.get("locked_target_part_id"))!="head":
        _fail("AUTO did not use SERA frontal dual rays")
        return
    player.global_position=rear
    camera.global_position=center+Vector3(7.0,3.0,7.0)
    camera.look_at(center,Vector3.UP)
    game.call("_acquire_stable_camera_part",0.016,false)
    if str(game.get("locked_target_part_id"))!="head":
        _fail("temporary one-sided loss instantly changed lock")
        return
    player.global_position=front
    game.call("_acquire_stable_camera_part",0.05,false)
    if str(game.get("locked_target_part_id"))!="head" \
            or str(game.get("auto_lock_pending_part"))!="":
        _fail("candidate recovered but pending switch did not reset")
        return
    player.global_position=rear
    game.call("_acquire_stable_camera_part",0.016,false)
    game.call("_acquire_stable_camera_part",0.10,false)
    if str(game.get("locked_target_part_id"))!="head":
        _fail("single hit confirmed a premature switch")
        return
    game.call("_acquire_stable_camera_part",0.13,false)
    if not str(game.get("locked_target_part_id")).is_empty():
        _fail("stable BODY candidate failed to replace HEAD")
        return
    # Moving only the camera is irrelevant to this geometric decision.
    player.global_position=rear
    for shift in [Vector3(12,9,0),Vector3(-12,2,1),Vector3(0,4,-12)]:
        camera.global_position=center+shift
        camera.look_at(center,Vector3.UP)
        game.call("_acquire_stable_camera_part",0.25,false)
        if not str(game.get("locked_target_part_id")).is_empty():
            _fail("moving camera alone changed SERA-only lock")
            return

    # Both debug beam meshes use exactly the pair-selector endpoints.
    if root_lines.visible or button.text!="LINES OFF" or bool(game.get("lock_lines_visible")):
        _fail("debug beams are not hidden by default")
        return
    game.set("camera_player_render_position",front)
    game.set("camera_target_render_position",center)
    game.call("_toggle_lock_lines")
    if not root_lines.visible or button.text!="LINES ON":
        _fail("visibility toggle did not show both beams")
        return
    game.call("_update_lock_line_visuals")
    for i in range(2):
        var mesh: MeshInstance3D=visuals[i]
        if not mesh.visible or not mesh.mesh is CylinderMesh:
            _fail("enabled debug line is not a visible cylinder")
            return
        var start: Vector3=lines[i*2]
        var finish: Vector3=lines[i*2+1]
        if mesh.global_position.distance_to((start+finish)*0.5)>0.0001:
            _fail("debug beam center differs from the actual collision ray")
            return
        if absf(mesh.scale.y-start.distance_to(finish))>0.0001:
            _fail("beam length does not match its corresponding lock segment")
            return
        var material: StandardMaterial3D=mesh.material_override
        if material.no_depth_test:
            _fail("visual beam ignores occlusion / 3D depth")
            return
    var tap: InputEventScreenTouch=InputEventScreenTouch.new()
    tap.index=6
    tap.pressed=true
    tap.position=button.get_global_rect().get_center()
    game.call("_input",tap)
    if root_lines.visible or button.text!="LINES OFF":
        _fail("Android touch did not hide debug rays")
        return
    if int(game.get("current_touch"))==6 or int(game.get("step_hud_touch"))!=6:
        _fail("debug button press leaked into movement controls")
        return
    tap.pressed=false
    game.call("_input",tap)
    if int(game.get("step_hud_touch"))!=-1:
        _fail("debug button release stayed captured")
        return
    print("GODOT_V303_PARALLEL_LOCK_LINES_PASS")
    quit(0)
