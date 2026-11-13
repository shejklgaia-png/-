extends SceneTree
## Real main-scene EN/SH state regression; no change to user-approved values.
const RULES = preload("res://scripts/sera_resource_rules.gd")

func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    push_error("SERA_RESOURCE_RUNTIME_FAIL: " + message)
    quit(1)

func _near(actual: float, expected: float) -> bool:
    return absf(actual - expected) <= 0.00002

func _run() -> void:
    var scene: PackedScene = load("res://scenes/main.tscn")
    if scene == null:
        _fail("training scene missing")
        return
    var game: Node3D = scene.instantiate()
    root.add_child(game)
    var c: Dictionary = game.get_script().get_script_constant_map()
    var en_max: float = float(c["TEST_EN_MAX"])
    var sh_max: float = float(c["TEST_SH_MAX"])
    var unlock_ratio: float = float(c["EN_RECOVERY_UNLOCK_RATIO"])
    if not _near(en_max, 100.0) or not _near(sh_max, 100.0) or not _near(unlock_ratio, 0.60):
        _fail("resource caps/unlock ratio changed")
        return

    # Zero-cost actions stay available even while positive EN is locked.
    game.set("energy", 0.0)
    game.set("energy_exhausted", true)
    if not bool(game.call("_spend_energy", 0.0))             or bool(game.call("_spend_energy", 1.0)):
        _fail("exhaustion lock blocked free action or allowed paid action")
        return
    game.set("energy_exhausted", false)
    game.set("energy", 12.0)
    if bool(game.call("_spend_energy", 13.0)) or not _near(float(game.get("energy")), 12.0):
        _fail("insufficient EN was deducted")
        return
    if bool(game.get("energy_exhausted")):
        _fail("nonzero insufficient EN unexpectedly forced exhaustion")
        return
    game.set("energy_recovery_pause", 0.0)
    if not bool(game.call("_spend_energy", 12.0))             or not _near(float(game.get("energy")), 0.0)             or not bool(game.get("energy_exhausted"))             or not _near(float(game.get("energy_recovery_pause")), 0.25):
        _fail("exact EN spend did not lock and set recovery pause")
        return
    game.set("energy_exhausted", false)
    if bool(game.call("_spend_energy", 1.0)) or not bool(game.get("energy_exhausted")):
        _fail("zero EN failed to enter exhaustion on rejected spend")
        return

    # Exactly reaching the unlock threshold is sufficient, not 59.99%.
    game.set("energy", en_max * unlock_ratio - 0.24)
    game.set("energy_exhausted", true)
    game.set("energy_recovery_pause", 0.0)
    game.set("shield", 30.0)
    game.set("shield_recovery_pause", 0.0)
    game.set("guard_break_remaining", 0.0)
    game.set("down_remaining", 0.0)
    game.call("_tick_resources", 0.01)
    if not _near(float(game.get("energy")), en_max * unlock_ratio)             or bool(game.get("energy_exhausted")):
        _fail("exact 60% recovery did not unlock")
        return
    if not _near(float(game.get("shield")), 30.16):
        _fail("shield recovery rate changed")
        return
    if not bool(game.call("_spend_energy", 10.0)):
        _fail("positive EN still blocked after 60% unlock")
        return

    # Pause decrements before recovery and resumes in that same frame.
    game.set("energy", 20.0)
    game.set("energy_exhausted", false)
    game.set("energy_recovery_pause", 0.10)
    game.set("shield_recovery_pause", 0.10)
    game.set("shield", 20.0)
    game.call("_tick_resources", 0.10)
    if not _near(float(game.get("energy")), 22.4)             or not _near(float(game.get("shield")), 21.6):
        _fail("recovery pause boundary or rates changed")
        return

    # Recovery must stop while an active guard break or damage down remains.
    for block in ["guard_break_remaining", "down_remaining"]:
        game.set("guard_break_remaining", 0.0)
        game.set("down_remaining", 0.0)
        game.set(block, 0.50)
        game.set("shield", 45.0)
        game.set("shield_recovery_pause", 0.0)
        game.call("_tick_resources", 0.10)
        if not _near(float(game.get("shield")), 45.0):
            _fail("shield recovered despite " + block)
            return
    game.set("guard_break_remaining", 0.0)
    game.set("down_remaining", 0.0)

    # Caps are applied after the delta; pure functions must not mutate scene.
    game.set("energy", en_max - 0.01)
    game.set("shield", sh_max - 0.01)
    game.set("energy_recovery_pause", 0.0)
    game.set("shield_recovery_pause", 0.0)
    game.call("_tick_resources", 0.1)
    if not _near(float(game.get("energy")), en_max)             or not _near(float(game.get("shield")), sh_max):
        _fail("resource cap changed")
        return
    if not _near(RULES.next_recovery_pause(0.2, 0.1), 0.1)             or not _near(RULES.recovered_energy(13.0, 0.2, 0.1, en_max, 24.0), 13.0)             or not _near(RULES.recovered_shield(13.0, 0.0, 1.0, 0.0, 0.1, sh_max, 16.0), 13.0):
        _fail("pure rules changed pauses or shield gating")
        return
    var zero: Dictionary = RULES.energy_spend(0.0, true, 0.0, 0.0001)
    if not bool(zero["allowed"]) or bool(zero["paid"]):
        _fail("pure free action changed")
        return
    print("SERA_RESOURCE_RULES_RUNTIME_PASS: EN spend, 60% unlock, SH gates, regen caps")
    quit(0)
