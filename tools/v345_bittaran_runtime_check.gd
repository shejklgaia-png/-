extends SceneTree
## v345: compile and exercise the actual boss rig, FOV/locomotion policy and scene.
const AI = preload("res://scripts/bittaran_ai.gd")
const RIG = preload("res://scripts/bittaran_rig.gd")

func _initialize() -> void:
    call_deferred("_run")

func _fail(why: String) -> void:
    push_error("V345_BITTARAN_FAIL: " + why)
    quit(1)

func _run() -> void:
    var rig: Node3D = RIG.new()
    root.add_child(rig)
    if not bool(rig.get("loading_ok")):
        _fail("Bittaran source/Android embed missing")
        return
    var names: Array[String] = rig.call("bone_names")
    if names.size() != 14 or not names.has("FrontFoot_R") or not names.has("RearFoot_L"):
        _fail("14 authored bone hierarchy with four feet not loaded")
        return
    var clips: Dictionary = rig.get("animations")
    for name in ["Wait", "Idle", "Turn", "Approach"]:
        if not clips.has(name):
            _fail("missing authored " + name)
            return
        rig.call("apply_pose", name, 0.3)
    rig.call("set_motion", "Turn", 0.25)
    if str(rig.get("current_clip")) != "Turn":
        _fail("turn clip did not start")
        return
    rig.call("set_motion", "Approach", 0.8)
    if str(rig.get("current_clip")) != "Approach":
        _fail("walking clip did not start")
        return
    var brain: RefCounted = AI.new()
    var origin := Vector3(0.0, 1.53, -12.0)
    var approaching: Dictionary = brain.call(
        "advance", 0.5, origin, 0.0, Vector3.ZERO, false)
    if approaching["motion"] != "Approach" or (approaching["position"] as Vector3).z <= -8.0:
        _fail("forward target not approached")
        return
    brain.call("reset")
    var behind: Dictionary = brain.call(
        "advance", 0.5, origin, 0.0, Vector3(0, 0, -22), false)
    if behind["motion"] != "Turn" or (
            (behind["position"] as Vector3).distance_to(origin) > 0.000001):
        _fail("boss advanced toward player outside 100-degree view")
        return
    brain.call("reset")
    var angled: Dictionary = brain.call(
        "advance", 0.5, origin, 0.0,
        origin + Vector3(6.43, 0.0, 7.66), false)
    if angled["motion"] != "Approach" or absf(float(angled["yaw"])) < 0.001:
        _fail("boss did not steer while approaching inside view")
        return
    var halted: Dictionary = brain.call(
        "advance", 0.5, origin, 0.0, Vector3.ZERO, true)
    if halted["motion"] != "Idle" or (
            (halted["position"] as Vector3).distance_to(origin) > 0.000001):
        _fail("freeze did not stop boss")
        return
    var packed: PackedScene = load("res://scenes/bittaran_battle.tscn")
    if packed == null:
        _fail("deployment battle destination is not loadable")
        return
    var battle: Node3D = packed.instantiate()
    root.add_child(battle)
    var boss_rig: Node3D = battle.get("bittaran_rig")
    var target: Node3D = battle.get("target")
    var dummy: MeshInstance3D = battle.get("target_mesh")
    if boss_rig == null or target == null or dummy == null:
        _fail("combat scene lost rig, target or base combat state")
        return
    if not bool(boss_rig.get("loading_ok")) or dummy.visible:
        _fail("authored boss not displayed instead of training cube")
        return
    if bool(battle.get("enemy_shooter").get("auto_fire_enabled")):
        _fail("training attacks leaked into movement-only boss")
        return
    battle.set("target_hp", 0)
    battle.call("_tick_target_respawn", 5.0)
    if int(battle.get("target_hp")) != 0:
        _fail("defeated boss respawned like training dummy")
        return
    print("GODOT_V345_BITTARAN_PASS: 14 bones, clips, 100-degree AI, battle scene")
    quit(0)
