extends SceneTree
## v489 startup is the base hub; retain v438's real Bittaran scene/IK smoke
## even though the boss is now launched from NEXUS instead of app startup.
const EXPECTED_SCENE: String = "res://scenes/base_exploration.tscn"
const BATTLE_SCENE: String = "res://scenes/bittaran_battle.tscn"
const BOSS = preload("res://scripts/bittaran_battle.gd")

func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    push_error("V438_BITTARAN_BOOT_FAIL: " + message)
    quit(1)

func _run() -> void:
    var configured: String = str(
        ProjectSettings.get_setting("application/run/main_scene", ""))
    if configured != EXPECTED_SCENE:
        _fail("wrong boot scene " + configured)
        return
    var hub_scene: PackedScene = load(configured)
    if hub_scene == null:
        _fail("cannot load hub boot scene")
        return
    var hub: Node = hub_scene.instantiate()
    root.add_child(hub)
    if hub.name != "BaseExploration" or hub.get_node_or_null("NEXUSBuilding") == null:
        _fail("hub startup did not create NEXUS building")
        return
    root.remove_child(hub)
    hub.free()
    var scene: PackedScene = load(BATTLE_SCENE)
    if scene == null:
        _fail("Bittaran battle scene no longer available from NEXUS")
        return
    var battle: Node = scene.instantiate()
    if battle == null or not battle is Node3D:
        _fail("Bittaran deployment scene did not instantiate BittaranBattle")
        return
    root.add_child(battle)
    if battle.get_script() != BOSS:
        _fail("wrong deployment scene script, expected Bittaran")
        return
    var rig: Node3D = battle.get("bittaran_rig")
    var ik: RefCounted = battle.get("bittaran_foot_ik")
    var director: RefCounted = battle.get("bittaran_attacks")
    if rig == null or ik == null or director == null:
        _fail("startup battle missing boss, skeletal IK, or attack director")
        return
    if not bool(rig.get("loading_ok")):
        _fail("startup Bittaran rig failed to load")
        return
    if not bool(ik.get("source_ik_enabled")):
        _fail("startup IK not activated")
        return
    if absf(BOSS.BOSS_WORLD_SCALE - 2.0) > 0.001:
        _fail("booted scene lost expected Bittaran scale")
        return
    print("GODOT_V438_BITTARAN_BOOT_PASS startup=", configured,
        " deployment=", BATTLE_SCENE, " rig_ready=true source_ik_enabled=true")
    quit(0)
