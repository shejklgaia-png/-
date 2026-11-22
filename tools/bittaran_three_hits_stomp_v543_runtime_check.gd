extends SceneTree
## v543: real boss-damage path, queued STOMP priority, front/rear sole
## reach, attack interruption, reset and audible event gain.
const ATTACKS = preload("res://scripts/bittaran_attacks.gd")
const DT: float = 1.0 / 60.0

func _initialize() -> void:
    call_deferred("_run")

func _fail(msg: String) -> void:
    push_error("BITTARAN_V543_FAIL: " + msg)
    quit(1)

func _hit(scene: Node3D) -> void:
    scene.set("locked_target_part_id", "leg_fr")
    scene.call("_apply_target_part_damage", "melee", 12, 0.0, 0.0, 0.0)

func _run() -> void:
    var battle: Node3D = load("res://scenes/bittaran_battle.tscn").instantiate()
    root.add_child(battle)
    battle.set_process(false)
    battle.set_physics_process(false)
    var director: RefCounted = battle.get("bittaran_attacks")
    if director == null:
        _fail("real boss attack director missing")
        return
    var sfx: Dictionary = battle.get("bittaran_sfx_players")
    var attack_sfx: AudioStreamPlayer = sfx.get("arm")
    var music: AudioStreamPlayer = battle.get("bittaran_bgm")
    if attack_sfx == null or attack_sfx.stream == null:
        _fail("source arm audio not playable")
        return
    if music == null or music.stream == null:
        _fail("battle music channel not playable")
        return
    if absf(attack_sfx.volume_db - 4.0) > 0.001 or (
            absf(music.volume_db - (-8.0)) > 0.001):
        _fail("attack must be clearly louder than background")
        return
    # Only a real successful Bittaran damage operation counts as one hit.
    for n in range(3):
        _hit(battle)
        if int(director.get("received_hit_count")) != mini(n + 1, 3):
            _fail("actual boss hit did not increment one time " + str(n))
            return
        if bool(director.get("guaranteed_stomp_pending")) != (n == 2):
            _fail("queued stomp armed too early or late")
            return
    # More damage during a queued reaction must not drop the guarantee.
    _hit(battle)
    if not bool(director.get("guaranteed_stomp_pending")) or (
            int(director.get("received_hit_count")) != 3):
        _fail("queued stomp lost to extra hits")
        return
    director.set("last_kind", "stomp")
    var far: Dictionary = {"leg_fr": Vector3.ZERO}
    var too_far: Dictionary = director.call("advance", DT,
        Vector3(0, 0, 4.0), far, true)
    if not too_far.is_empty() or (
            not bool(director.get("guaranteed_stomp_pending"))):
        _fail("should approach player instead of attacking outside range")
        return
    var valid: Dictionary = director.call("advance", DT,
        Vector3(0, 0, 3.5), far, true)
    if str(valid.get("kind", "")) != "stomp" or (
            str(valid.get("id", "")) != "leg_fr"):
        _fail("next valid attack was not guaranteed front STOMP " + str(valid))
        return
    if bool(director.get("guaranteed_stomp_pending")) or (
            int(director.get("received_hit_count")) != 0):
        _fail("guarantee not consumed exactly at attack selection")
        return
    director.call("cancel")
    # Once consumed, ordinary kind variation returns; 2 hits do not force.
    for n in range(2):
        _hit(battle)
    director.set("last_kind", "stomp")
    var ordinary: String = str(director.call(
        "_choose_nonrepeating_kind", Vector3(0, 0, 3.5), far, 0.0))
    if ordinary != "kick":
        _fail("ordinary attack variation broken without third hit")
        return
    # Also allow rear STOMP when only a rear foot is available.
    _hit(battle)
    director.set("last_kind", "stomp")
    var rear: Dictionary = {"leg_rr": Vector3.ZERO}
    if str(director.call("_choose_nonrepeating_kind",
            Vector3(0, 0, 2.7), rear, 0.0)) != "stomp":
        _fail("rear guaranteed stomp unavailable")
        return
    # A broken/disabled attack may cancel but must not clear the pending hit.
    director.call("cancel")
    if not bool(director.get("guaranteed_stomp_pending")):
        _fail("cancel cleared guaranteed move")
        return
    battle.call("_reset_target_after_respawn")
    if bool(director.get("guaranteed_stomp_pending")) or (
            int(director.get("received_hit_count")) != 0):
        _fail("guarantee leaked into a new boss encounter")
        return
    print("GODOT_BITTARAN_V543_PASS three_real_hits=true next_stomp=true range_safe=true sfx_volume=true")
    quit(0)
