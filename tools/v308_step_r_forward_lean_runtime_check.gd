extends SceneTree
## v308: right STEP must use Step_R and display forward + right torso pitch/roll.
func _initialize() -> void:
    call_deferred("_run")

func _fail(reason: String) -> void:
    push_error("V308_STEP_R_LEAN_FAILED: " + reason)
    quit(1)

func _run() -> void:
    var scene: PackedScene = load("res://scenes/main.tscn")
    if scene == null:
        _fail("main scene missing")
        return
    var game: Node3D = scene.instantiate()
    root.add_child(game)
    var rig: Node3D = game.get("rig")
    var player: CharacterBody3D = game.get("player")
    var target: Node3D = game.get("target")
    if rig == null or player == null or target == null or not bool(rig.get("loading_ok")):
        _fail("actors or clips unavailable")
        return
    player.position = Vector3(0.0,0.0,9.0)
    game.set("target_move_enabled",false)
    game.set("auto_lock_enabled",false)
    game.set("manual_part_lock_active",true)
    game.set("locked_target_part_id","head")
    game.set("target_hp",500)
    game.set("camera_yaw",0.0)
    game.call("_place_camera")
    game.set("energy",100.0)
    if not bool(game.call("_start_omni_step",Vector2.RIGHT)):
        _fail("screen RIGHT flick refused")
        return
    if str(rig.get("current_clip")) != "Step_R":
        _fail("right STEP did not start same-named Step_R")
        return
    if (rig.get("directional_step_vector") as Vector2).distance_to(Vector2.RIGHT)>0.001:
        _fail("right input selected another pose")
        return
    rig.set("blending_for",0.12)
    rig.call("_apply_animation",0.0)
    var bones: Dictionary=rig.get("bones")
    var waist: Node3D=bones["67435cb7-b6af-23e4-10f1-3cd13d8429fa"]
    var front: Vector3=waist.quaternion*Vector3.FORWARD
    var up: Vector3=waist.quaternion*Vector3.UP
    # Lock yaw compensation leaves the authored forward pitch/right lean intact.
    if front.y > -0.40:
        _fail("right STEP does not pitch forward: "+str(front))
        return
    if up.x < 0.20:
        _fail("right STEP does not lean to the right: "+str(up))
        return
    if Vector2(front.x,front.z).normalized().dot(Vector2(0,-1)) < 0.995:
        _fail("right STEP breaks locked facing: "+str(front))
        return
    var animations: Dictionary=rig.get("animations")
    var step_clip: Dictionary=animations["Step_R"]
    var tracks: Dictionary=step_clip["tracks"]
    if not tracks.has("67435cb7-b6af-23e4-10f1-3cd13d8429fa"):
        _fail("authored Waist track missing")
        return
    if absf(float(game.get("step_arc_length"))-3.0)>0.0001:
        _fail("right step distance changed")
        return
    game.call("_finish_side_step",false)
    print("GODOT_V308_RIGHT_FORWARD_LEAN_PASS")
    quit(0)
