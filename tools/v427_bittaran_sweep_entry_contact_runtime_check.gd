extends SceneTree
## SERA v427: SWEEP Wait->key0, conditional touchdown and gradual torso descent.
const IK = preload("res://scripts/bittaran_foot_ik.gd")
const RIG = preload("res://scripts/bittaran_rig.gd")
const DT: float = 0.05

func _initialize() -> void:
    call_deferred("_run")

func _fail(msg: String) -> void:
    push_error("V427_SWEEP_ENTRY_FAIL: " + msg)
    quit(1)

func _run() -> void:
    var rig: Node3D = RIG.new()
    root.add_child(rig)
    if not bool(rig.get("loading_ok")):
        _fail("model failed")
        return
    # Key zero must NOT snap in the same frame as the neutral pose.
    for id in ["leg_fl", "leg_fr"]:
        var clip: String = "なぎ払い" if id == "leg_fl" else "なぎ払い_R"
        var names: Array[String] = ["Body"]
        for raw in RIG.ATTACK_LEG_BONES[id]:
            names.append(str(raw))
        for t in [0.0, 0.16, 0.32]:
            rig.call("apply_pose", "Wait", 0.0)
            rig.call("apply_authored_attack_pose", {
                "id": id, "kind": "sweep", "time": t,
                "authored_time": 0.0, "windup": 0.7, "strike": 1.0,
                "hold": 0.0, "recovery": 0.6, "direct_front_test": true
            })
            var fraction: float = clampf(t / RIG.FRONT_SWEEP_ENTRY_SECONDS,
                0.0, 1.0)
            var smooth: float = fraction * fraction * (3.0 - 2.0 * fraction)
            for name in names:
                var node: Node3D = rig.find_child(name, true, false)
                var neutral: Quaternion = rig.call(
                    "_authored_key_rotation", "Wait", name, 0.0)
                var key0: Quaternion = rig.call(
                    "_authored_key_rotation", clip, name, 0.0)
                var expected: Quaternion = neutral.slerp(key0, smooth)
                if node == null or node.quaternion.angle_to(expected) > 0.004:
                    _fail("not a smooth Wait->key0 slerp: " + id
                        + "/" + name + " t=" + str(t))
                    return
    var scene: PackedScene = load("res://scenes/bittaran_battle.tscn")
    var battle: Node3D = scene.instantiate()
    root.add_child(battle)
    var foot_ik: RefCounted = battle.get("bittaran_foot_ik")
    var director: RefCounted = battle.get("bittaran_attacks")
    var target: Node3D = battle.get("target")
    var player: CharacterBody3D = battle.get("player")
    for id in ["leg_fl", "leg_fr"]:
        battle.call("_reset_target_after_respawn")
        player.global_position = target.global_position + Vector3(0.0, 0.0, 7.0)
        if not bool(director.call("force_start", id, "sweep")):
            _fail("cannot start sweep: " + id)
            return
        var index: int = IK.LEG_PART_IDS.find(id)
        var leg: Dictionary = foot_ik.get("legs")[index]
        var last_drop: float = 0.0
        var ever_contact: bool = false
        var first_touch: float = -1.0
        var max_contact_error: float = 0.0
        var previous: bool = false
        for step in range(110):
            battle.call("_advance_target_motion", DT)
            var frame: Dictionary = battle.get("bittaran_attack_frame")
            if frame.is_empty():
                break
            battle.call("_finalize_target_pose", DT)
            var t: float = float(frame.get("time", 0.0))
            var drop: float = float(foot_ik.get("front_attack_drop_world"))
            if drop > 0.00001 or drop < -IK.FRONT_SWEEP_MAX_DROP_METERS - 0.001:
                _fail("BODY descent out of range")
                return
            if last_drop - drop > (
                    IK.FRONT_BODY_DESCENT_SPEED_METERS_PER_SECOND * DT + 0.003):
                _fail("BODY/arm drop teleported: " + str([t, last_drop, drop]))
                return
            last_drop = drop
            var touching: bool = bool(leg.get("front_sweep_contact", false))
            if touching and not previous:
                first_touch = t
                ever_contact = true
            if touching and t < IK.FRONT_SWEEP_ENTRY_SECONDS - 0.001:
                _fail("touchdown preceded completed key0 blend")
                return
            if previous and not touching:
                _fail("source contact latch lost mid-attack")
                return
            previous = touching
            if touching and t >= float(frame.get("windup", 0.7)) + 0.10:
                var sole: float = float(foot_ik.call(
                    "_foot_mesh_lowest_y", leg["foot"]))
                max_contact_error = maxf(max_contact_error, absf(sole))
                if absf(sole) > 0.028:
                    _fail("grounded source toe off floor " + str([id,t,sole]))
                    return
        if not ever_contact:
            _fail("authored sweep never touched ground: " + id)
            return
        print("V427_SWEEP_CONTACT: ", id, " first_touch=", first_touch,
            " max_contact_error=", max_contact_error)
        # The legacy forced-contact flag and previous shoulder heights
        # MUST NOT survive the staged home-leg/raise-BODY recovery.
        for step in range(40):
            battle.call("_advance_target_motion", DT)
            battle.call("_finalize_target_pose", DT)
        if leg.has("front_sweep_contact"):
            _fail("sweep contact flag leaked across attacks")
            return
    print("GODOT_V427_SWEEP_ENTRY_PASS: Wait->0 slerp, actual ground switch, arms follow bounded BODY drop")
    quit(0)
