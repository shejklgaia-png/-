extends SceneTree
## Godot real-scene checks: keep broken locks through combo, broken meshes
## persist, local FX matches central hit, and RUN resumes after Kick_b.
func _initialize() -> void:
    call_deferred("_run")


func _fail(why: String) -> void:
    push_error("V289_LOCK_PARTS_FX_RUN_FAILED: " + why)
    quit(1)


func _run() -> void:
    var packed: PackedScene = load("res://scenes/main.tscn")
    if packed == null:
        _fail("main scene missing")
        return
    var game: Node3D = packed.instantiate()
    root.add_child(game)
    var parts: Node3D = game.get("target_parts")
    var player: CharacterBody3D = game.get("player")
    var target: Node3D = game.get("target")
    var rig: Node3D = game.get("rig")
    if parts == null or player == null or target == null or rig == null:
        _fail("scene target parts, player or rig missing")
        return
    if not bool(rig.get("loading_ok")):
        _fail("authored rig missing")
        return

    # Break a front leg, then assert that the identical visual geometry
    # and movement collider remain. The old code removed it entirely.
    var all_parts: Dictionary = parts.get("parts")
    var leg: Dictionary = all_parts["leg_fl"]
    var leg_node: Node3D = leg["node"]
    game.set("target_hp",500)
    game.set("combat_state",3) # STRIKE
    game.set("locked_target_part_id","leg_fl")
    var hit: Dictionary = game.call("_apply_target_part_damage",
        "melee",26,200.0,0.0,0.0)
    if not bool(hit["broken"]) or bool(parts.call("is_targetable","leg_fl")):
        _fail("leg did not transition to broken")
        return
    if not bool(parts.call("has_part","leg_fl")) or not leg_node.visible:
        _fail("destroyed leg mesh disappeared")
        return
    if str(game.get("locked_target_part_id")) != "leg_fl":
        _fail("target lock cleared on the breaking hit")
        return
    if not bool(game.call("_locked_part_hit_volume_available")):
        _fail("broken lock hitbox disappeared mid-combo")
        return
    if float(leg["hit_fx_remaining"]) <= 0.0:
        _fail("breaking hit did not trigger part FX")
        return
    parts.call("advance_part_hit_fx",0.016)
    var shell: StandardMaterial3D = leg["shell"]
    if not shell.emission_enabled or shell.albedo_color == (leg["rest_shell"] as Color):
        _fail("broken limb did not use core-matched dark red impact flash")
        return
    parts.call("advance_part_hit_fx",0.20)
    if shell.emission_enabled or shell.albedo_color != (leg["rest_shell"] as Color):
        _fail("limb impact materials did not return to broken base palette")
        return
    if not leg_node.visible:
        _fail("flashed broken limb vanished after contact")
        return

    # Link window after Melee3 is still part of the same continuous combo.
    game.set("combat_state",0) # IDLE
    game.set("bash_followup_window_remaining",0.40)
    if not bool(game.call("_combo_lock_retention_active")):
        _fail("post-combo input link did not retain target")
        return
    if not bool(game.call("_locked_part_hit_volume_available")):
        _fail("broken ID is not addressable during input link window")
        return
    game.set("bash_followup_window_remaining",0.0)
    game.set("bash_loop_window_remaining",0.0)
    if bool(game.call("_combo_lock_retention_active")):
        _fail("lock did not release once combo ended")
        return
    game.call("_physics_process",0.016)
    if str(game.get("locked_target_part_id")) == "leg_fl":
        _fail("broken part remained selected after full combo ended")
        return
    var aim: Vector3 = Vector3(
        target.position.x-player.position.x,0.0,target.position.z-player.position.z)
    var candidate: String = str(parts.call("select_front_part",
        player.global_position + Vector3.UP*1.05,aim,"",game.call("_target_hit_aabb")))
    if not candidate.is_empty() and not bool(parts.call("is_targetable",candidate)):
        _fail("new lock selected another broken part")
        return

    # Reproduce the precise v288/v289 bug: BACK_KICK_TRACK used a melee
    # approach clip and left combat_playback=true after jump ended.
    rig.call("start_melee_approach")
    if not bool(rig.get("combat_playback")):
        _fail("back-kick tracker did not mark combat ownership")
        return
    if not bool(rig.call("start_back_somersault")):
        _fail("back kick could not enter somersault")
        return
    if bool(rig.get("combat_playback")):
        _fail("old tracker combat flag was retained in the somersault")
        return
    rig.call("start_landing",true)
    rig.call("finish_jump",true,false)
    if bool(rig.get("combat_playback")) or bool(rig.get("jump_playback")):
        _fail("landing left an animation playback gate active")
        return
    rig.call("set_moving",true,false,Vector2(0,1),false)
    if str(rig.get("current_clip")) != "run_front_original":
        _fail("RUN clip did not resume after somersault landing")
        return

    # A stationary held finger on touchdown must be read even if Android
    # sends no extra drag event after the 0.2s landing interval.
    rig.call("start_landing",true)
    game.set("landing_active",true)
    game.set("landing_from_somersault",true)
    game.set("landing_elapsed",0.19)
    game.set("gesture_active",true)
    game.set("pointer_origin",Vector2(100,100))
    game.set("pointer_location",Vector2(185,100))
    game.set("direction_input",Vector2.ZERO)
    game.call("_advance_landing",0.02)
    if bool(game.get("landing_active")):
        _fail("0.2s backflip landing never exited")
        return
    if (game.get("direction_input") as Vector2).length_squared()<0.001:
        _fail("held thumb was not restored for immediate RUN")
        return
    if str(rig.get("current_clip")) != "run_front_original":
        _fail("held RUN was blocked by old post-backflip rig state")
        return
    print("GODOT_V289_LOCK_PARTS_FX_RUN_PASS: persistent broken lock, local flash, whole-boss forward and RUN recovery")
    quit(0)
