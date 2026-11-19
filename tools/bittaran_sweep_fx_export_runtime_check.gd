extends SceneTree
## Deterministic FX-track authoring/export: sample the LIVE rendered
## source clip + the SAME ground IK and toe mesh as the game, at 60Hz.
## Logs one JSON record that can be turned into a checked-in GDScript
## constant. This generator is never run on Android.
const ATTACKS = preload("res://scripts/bittaran_attacks.gd")
const TRACK = preload("res://scripts/bittaran_sweep_fx_track.gd")
const BAKED = preload("res://scripts/bittaran_sweep_fx_baked_data.gd")
const DT: float = 1.0 / 60.0

func _initialize() -> void:
    call_deferred("_run")


func _fail(why: String) -> void:
    push_error("EXPORT_SWEEP_FX_FAIL " + why)
    quit(1)


func _run() -> void:
    var battle: Node3D = load(
        "res://scenes/bittaran_battle.tscn").instantiate()
    root.add_child(battle)
    battle.set_process(false)
    battle.set_physics_process(false)
    var boss: Node3D = battle.get("target")
    var player: CharacterBody3D = battle.get("player")
    var attacks: RefCounted = battle.get("bittaran_attacks")
    if boss == null or player == null or attacks == null:
        _fail("combat scene dependencies unavailable")
        return
    var output: Dictionary = {}
    for id in ATTACKS.LEG_IDS:
        battle.call("_reset_target_after_respawn")
        battle.set("player_hp", 99999.0)
        player.global_position = (
            boss.global_position + Vector3(0.0, 0.0, 25.0))
        if not bool(attacks.call("force_start", id, "sweep")):
            _fail("missing source clip " + id)
            return
        var rows: Array = []
        var begin: float = ATTACKS.source_hit_start_seconds("sweep", id)
        var end: float = (
            ATTACKS.SWEEP_REAR_FIRST_STROKE_END_KEY_SECONDS
            if id.begins_with("leg_r")
            else ATTACKS.SWEEP_FRONT_FIRST_STROKE_END_KEY_SECONDS)
        for tick in range(300):
            battle.call("_advance_target_motion", DT)
            var frame: Dictionary = battle.get("bittaran_attack_frame")
            if frame.is_empty():
                break
            battle.call("_finalize_target_pose", DT)
            if str(frame.get("phase", "")) != "strike":
                continue
            var t: float = float(frame.get("authored_time", -INF))
            if t < begin - 0.00001 or t > end + 0.00001:
                continue
            var hit: Vector3 = battle.call(
                "_bittaran_ground_fx_contact", id)
            var local: Vector3 = boss.to_local(
                Vector3(hit.x, 0.0, hit.z))
            rows.append([t, local.x, local.z])
        if rows.size() < 24:
            _fail("incomplete real source/IK contact curve " +
                str([id, rows.size()]))
            return
        output[id] = rows
        # The static source track is still the animation's untracked
        # REFERENCE, but battle steering now rotates/translates its
        # entire arc dynamically. Comparing the raw old curve to a
        # player-aimed attack is invalid: the tracked toe MUST differ.
        # Verify finite, continuous actual 60Hz contact samples, and
        # that the stored authored base trajectory remains available.
        var curve: Array = BAKED.tracks().get(id, [])
        if curve.size() != BAKED.SAMPLE_COUNT_PER_LEG:
            _fail("missing authored sweep reference " + id)
            return
        var max_source_delta: float = 0.0
        var max_frame_step: float = 0.0
        var prior: Vector3 = Vector3.INF
        for row in rows:
            var actual: Vector3 = Vector3(
                float(row[1]), 0.0, float(row[2]))
            if not actual.is_finite():
                _fail("nonfinite tracked sweep contact " + id)
                return
            var authored: Vector3 = TRACK.interpolate_local(
                curve, float(row[0]))
            max_source_delta = maxf(max_source_delta,
                actual.distance_to(authored))
            if prior != Vector3.INF:
                max_frame_step = maxf(max_frame_step,
                    actual.distance_to(prior))
            prior = actual
        if max_frame_step > 1.6 or max_source_delta > 6.0:
            _fail("tracked sweep trajectory discontinuity " +
                str([id, max_frame_step, max_source_delta]))
            return
        print("SOURCE_IK_SWEEP_EXPORT_LEG ", id,
            " frames=", rows.size(), " start=", begin,
            " end=", end, " max_live_delta_from_base=",
            max_source_delta, " max_frame_step=", max_frame_step)
    print("SOURCE_IK_SWEEP_BAKE_DATA=" + JSON.stringify(output))
    print("GODOT_SOURCE_IK_SWEEP_EXPORT_PASS four_source_tracks=true ",
        "actual_post_ik_toe_sampled_60hz=true")
    quit(0)
