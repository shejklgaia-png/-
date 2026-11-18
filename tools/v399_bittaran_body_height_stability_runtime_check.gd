extends SceneTree
## v399: repeated attacks must not ratchet the chassis downward.
## The v398 attack-stance preparation runs with an empty attack pose,
## so the end-of-tick ground reconciliation used to treat the
## intentionally lifted diagonal pair (and a pair still frozen at its
## interrupted gait-step height) as planted contacts and drag the
## body toward them, accumulating the error in the persistent ground
## correction. Drive full attacks back to back and require the rig
## height, the persistent correction and the planted soles to return
## to their neutral values after every single attack.
const ATTACKS = preload("res://scripts/bittaran_attacks.gd")
const DT: float = 1.0 / 60.0
const MAX_CORRECTION_WORLD: float = 0.02
const MAX_RIG_DRIFT_LOCAL: float = 0.01
const MAX_SOLE_ERROR: float = 0.01


func _initialize() -> void:
    call_deferred("_run")


func _fail(why: String) -> void:
    push_error("V399_BITTARAN_BODY_HEIGHT_FAIL: " + why)
    quit(1)


func _run() -> void:
    var battle: Node3D = load(
        "res://scenes/bittaran_battle.tscn").instantiate()
    root.add_child(battle)
    battle.set_process(false)
    battle.set_physics_process(false)
    var brain: RefCounted = battle.get("bittaran_attacks")
    var ik: RefCounted = battle.get("bittaran_foot_ik")
    var rig: Node3D = battle.get("bittaran_rig")
    var boss: Node3D = battle.get("target")
    var player: CharacterBody3D = battle.get("player")
    if brain == null or ik == null or rig == null or player == null:
        _fail("missing live boss / IK / attack director")
        return
    battle.call("_reset_target_after_respawn")
    battle.set("target_move_enabled", true)
    var rest_y: float = float(ik.get("rest_actor_local_y"))
    if absf(rig.position.y - rest_y) > MAX_RIG_DRIFT_LOCAL:
        _fail("rig does not start at its rest height")
        return
    var cases: Array = []
    for id in ATTACKS.LEG_IDS:
        for kind in ATTACKS.ATTACK_KINDS:
            # The newer Bittaran source has no rear KICK animation.
            # Its absence is explicitly enforced by the attack
            # director; test all 10 authored combinations instead.
            if id.begins_with("leg_r") and kind == "kick":
                continue
            cases.append([id, kind])
    var completed: int = 0
    for round in range(2):
        for c in cases:
            var id: String = c[0]
            var kind: String = c[1]
            player.global_position = boss.global_position + Vector3(
                12.0, 0.0, 10.0)
            if not bool(brain.call("force_start_with_stance", id, kind)):
                _fail("unable to start " + id + "/" + kind)
                return
            var empty_streak: int = 0
            var finished: bool = false
            for tick in range(60 * 20):
                battle.call("_advance_target_motion", DT)
                battle.call("_finalize_target_pose", DT)
                var frame: Dictionary = battle.get(
                    "bittaran_attack_frame")
                if frame.is_empty() and not bool(brain.call("is_active")):
                    empty_streak += 1
                    if empty_streak > 90:
                        finished = true
                        break
                else:
                    empty_streak = 0
            if not finished:
                _fail(id + "/" + kind + " never completed")
                return
            # v401: at this point the boss may legitimately be walking
            # toward the far-away player, and locomotion now carries an
            # intentional gait dip/lean. Freeze the AI/director (skip
            # _advance_target_motion) and let the IK settle, so the
            # samples below measure only PERSISTENT attack-induced
            # height error — the ratchet this check exists to catch.
            # The ground-correction assertion is unaffected: a real
            # ratchet leaves it at -1.337m per attack, settled or not.
            # Settle = no pair stepping for 30 straight ticks (both
            # pairs may need one last replant under the frozen chassis,
            # ~0.58s each, before the gait terms can decay).
            var settled_streak: int = 0
            for settle in range(300):
                battle.call("_finalize_target_pose", DT)
                if int(ik.get("stepping_pair")) == -1:
                    settled_streak += 1
                    if settled_streak >= 30:
                        break
                else:
                    settled_streak = 0
            completed += 1
            var correction: float = absf(float(
                ik.get("ground_correction_world")))
            if correction > MAX_CORRECTION_WORLD:
                _fail(id + "/" + kind + " left a persistent ground "
                    + "correction of " + str(correction) + "m")
                return
            var drift: float = absf(rig.position.y - rest_y)
            if drift > MAX_RIG_DRIFT_LOCAL:
                _fail(id + "/" + kind + " left the rig "
                    + str(drift) + " below/above its rest height")
                return
            var legs: Array = ik.get("legs")
            for leg in legs:
                if bool(leg["stepping"]):
                    continue
                var foot: Node3D = leg["foot"]
                var sole: Vector3 = foot.to_global(leg["sole_local"])
                if absf(sole.y) > MAX_SOLE_ERROR:
                    _fail(id + "/" + kind + " left a planted sole at y="
                        + str(sole.y))
                    return
    if completed != cases.size() * 2:
        _fail("expected 20 completed legal attacks, got " + str(completed))
        return
    print("GODOT_V399_BITTARAN_BODY_HEIGHT_PASS: 20 back-to-back "
        + "attacks, rig height / persistent ground correction / "
        + "planted soles return to neutral after every attack")
    quit(0)
