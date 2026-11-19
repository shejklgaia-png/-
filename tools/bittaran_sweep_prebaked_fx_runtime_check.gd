extends SceneTree
## v456: four actual Blockbench SWEEP clips are sampled ONCE into
## a local foot-contact timeline; FX follows source time, not noisy IK.
const ATTACKS = preload("res://scripts/bittaran_attacks.gd")
const DT: float = 1.0 / 60.0

func _initialize() -> void:
    call_deferred("_run")


func _fail(message: String) -> void:
    push_error("BITTARAN_PREBAKED_SWEEP_FX_FAIL " + message)
    quit(1)


func _run() -> void:
    var battle: Node3D = load(
        "res://scenes/bittaran_battle.tscn").instantiate()
    root.add_child(battle)
    battle.set_process(false)
    battle.set_physics_process(false)
    var director: RefCounted = battle.get("bittaran_attacks")
    var fx: Node3D = battle.get("bittaran_dirt_fx")
    var rig: Node3D = battle.get("bittaran_rig")
    var boss: Node3D = battle.get("target")
    var player: CharacterBody3D = battle.get("player")
    if fx == null or director == null or rig == null or (
            boss == null or player == null):
        _fail("missing live scene dependencies")
        return
    var checked: int = 0
    for id in ATTACKS.LEG_IDS:
        battle.call("_reset_target_after_respawn")
        if int(fx.get("sweep_burst_count")) != 0:
            _fail("old encounter's emitted sweep FX survived reset " + id)
            return
        player.global_position = boss.global_position + Vector3(
            0.0, 0.0, 25.0)
        if not bool(director.call("force_start", id, "sweep")):
            _fail("cannot force authored " + id)
            return
        var first_fx: bool = false
        var previous_puffs: int = 0
        var saw_baked_path: bool = false
        var no_live_chase: bool = false
        var finish: float = (
            ATTACKS.SWEEP_REAR_FX_FIRST_STROKE_END_KEY_SECONDS
            if id.begins_with("leg_r")
            else ATTACKS.SWEEP_FRONT_FX_FIRST_STROKE_END_KEY_SECONDS)
        for tick in range(250):
            battle.call("_advance_target_motion", DT)
            var frame: Dictionary = battle.get("bittaran_attack_frame")
            if frame.is_empty():
                break
            battle.call("_finalize_target_pose", DT)
            if not bool(battle.get("bittaran_sweep_fx_baked")):
                _fail("source trajectory not prepared before attack " + id)
                return
            var tracks: Dictionary = fx.get("prebaked_sweep_tracks")
            if tracks.size() != 4:
                _fail("not all four source clips were baked " + str(
                    tracks.keys()))
                return
            var track: Array = tracks.get(id, [])
            if track.size() < 10 or track.size() > 16:
                _fail("bad source track length " + str([id, track.size()]))
                return
            if not saw_baked_path:
                var min_width: float = INF
                var first: Vector3 = track[0]["point"]
                var last: Vector3 = track[-1]["point"]
                min_width = Vector2(first.x - last.x,
                    first.z - last.z).length()
                if min_width < 0.035 or not is_finite(min_width):
                    _fail("authored trajectory is stationary " +
                        str([id, first, last]))
                    return
                saw_baked_path = true
            var current: int = int(fx.get("sweep_burst_count"))
            if current > previous_puffs:
                first_fx = true
                if not bool(fx.get("prebaked_sweep_started")):
                    _fail("original foot puff used non-baked FX " + id)
                    return
                var last: Vector3 = fx.get("last_sweep_fx_origin")
                var bounds: AABB = battle.call(
                    "_bittaran_attack_foot_bounds", id)
                # The authored source track has post-IK grounding
                # correction, but no visual puff may escape the
                # real foot's rough footprint by metres.
                if bounds.has_volume() and (
                        last.x < bounds.position.x - 0.55 or
                        last.x > bounds.end.x + 0.55 or
                        last.z < bounds.position.z - 0.55 or
                        last.z > bounds.end.z + 0.55):
                    _fail("prebaked track detached from live foot " +
                        str([id, last, bounds,
                            frame.get("authored_time")]))
                    return
            previous_puffs = current
        if not saw_baked_path or not first_fx or previous_puffs < 4 or (
                int(fx.get("sweep_dropped_bursts")) != 0):
            _fail("incomplete original sweep effects " +
                str([id, saw_baked_path, first_fx,
                    previous_puffs, fx.get("sweep_dropped_bursts")]))
            return
        if int(fx.get("prebaked_sweep_emissions")) < 4:
            _fail("source-time-only emission not used " + id)
            return
        checked += 1
        print("PREBAKED_SWEEP_CASE ", id,
            " puffs=", previous_puffs, " expected_end=", finish)
    # Even when the live foot jumps 100 metres after the FIRST ground
    # event, the precommitted dust should continue from its static
    # source curve, not teleport to that new foot position.
    var templates: Dictionary = fx.get("prebaked_sweep_tracks")
    fx.call("reset")
    var owner: Node3D = boss
    fx.call("configure_prebaked_sweeps", templates, owner)
    var src: Array = templates["leg_fl"]
    var t0: float = float(src[0]["time"])
    var sample0: Vector3 = boss.to_global(src[0]["point"])
    var test_frame: Dictionary = {
        "kind":"sweep", "id":"leg_fl", "phase":"strike",
        "hit_window":true, "windup":0.32, "strike":1.5,
        "time":0.32 + t0, "authored_time":t0
    }
    fx.call("advance_attack", test_frame,
        sample0, sample0, DT, true)
    if int(fx.get("prebaked_sweep_emissions")) < 1:
        _fail("first source-time puff not generated")
        return
    for i in range(1, 8):
        test_frame["time"] = 0.32 + t0 + float(i) * 0.045
        test_frame["authored_time"] = t0 + float(i) * 0.045
        fx.call("advance_attack", test_frame,
            Vector3(100.0, 0.0, 120.0),
            Vector3(-100.0, 0.0, -120.0), 0.045, false)
        var stamp: Vector3 = fx.get("last_sweep_fx_origin")
        if Vector2(stamp.x - sample0.x,
                stamp.z - sample0.z).length() > 7.0:
            _fail("planned dust teleported with live IK " + str(stamp))
            return
    if int(fx.get("prebaked_sweep_emissions")) < 7:
        _fail("planned source-time FX depended on live ground check")
        return
    print("GODOT_BITTARAN_PREBAKED_SWEEP_FX_PASS ",
        "clips=", checked, " dust_clock=authored_source_time",
        " no_realtime_foot_chase=true",
        " all_four_leg_source_tracks=true")
    quit(0)
