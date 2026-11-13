extends SceneTree
## Godot 4.7.2 real-scene integration for persistent nozzle FX cache.
class ProbeRig extends Node:
    var calls: int = 0
    var enabled: bool = false
    var direction: Vector3 = Vector3.ZERO
    var dt: float = 0.0
    var backward: float = -1.0
    var left_sector: Vector3 = Vector3.ZERO
    var burst: bool = false
    var sustained: bool = false

    func update_back_thruster_fx(active: bool, exhaust_world: Vector3,
            delta: float, backstroke_weight: float,
            left_sector_world: Vector3, acceleration_burst: bool,
            melee_sustain: bool) -> void:
        calls += 1
        enabled = active
        direction = exhaust_world
        dt = delta
        backward = backstroke_weight
        left_sector = left_sector_world
        burst = acceleration_burst
        sustained = melee_sustain

func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    push_error("SERA_THRUSTER_PRESENTATION_RUNTIME_FAIL: " + message)
    quit(1)

func _near(a: float, b: float) -> bool:
    return absf(a - b) < 0.00002

func _vector_near(a: Vector3, b: Vector3) -> bool:
    return a.distance_to(b) < 0.00002

func _run() -> void:
    var scene: PackedScene = load("res://scenes/main.tscn")
    if scene == null:
        _fail("training scene missing")
        return
    var game: Node3D = scene.instantiate()
    root.add_child(game)
    var output: Variant = game.get("thruster_presentation")
    if output == null:
        _fail("main scene lacks persistent output helper")
        return
    var fake: ProbeRig = ProbeRig.new()
    root.add_child(fake)
    var left_sector: Vector3 = Vector3.DOWN.slerp(Vector3.RIGHT, 0.35).normalized()

    # Active BOOST stores the exact values sent to the rig (direction
    # normalized, actor backstroke weight, camera-space LEFT sector).
    output.update(fake, true, Vector3(3.0, 0.0, 4.0), 0.016,
        0.65, left_sector, true, false, true, true, true)
    if fake.calls != 1 or not fake.enabled or not fake.burst or fake.sustained \
            or not _near(fake.dt, 0.016) \
            or not _vector_near(fake.direction, Vector3(0.6, 0.0, 0.8)) \
            or not _near(fake.backward, 0.65) \
            or not _vector_near(fake.left_sector, left_sector) \
            or not _vector_near(output.get("held_boost_exhaust_direction"), fake.direction) \
            or not _near(float(output.get("held_boost_backstroke_weight")), 0.65) \
            or not _vector_near(output.get("held_boost_left_sector_world"), left_sector):
        _fail("running BOOST did not latch and forward all three nozzle values")
        return

    # Neutral thumb does not overwrite cached direction/weights; preserve the
    # left/down nozzle even if the fresh frame has no screen-left input.
    output.update(fake, true, Vector3(3.0, 0.0, 4.0), 0.016,
        0.0, Vector3.ZERO, false, false, true, false, false)
    if fake.calls != 2 or not _near(fake.backward, 0.65) \
            or not _vector_near(fake.left_sector, left_sector) \
            or not _vector_near(output.get("held_boost_exhaust_direction"),
                Vector3(0.6, 0.0, 0.8)):
        _fail("neutral BOOST thumb lost cached backstroke/left sector")
        return

    # New RUN input updates cache with reversal immediately, no hysteresis.
    output.update(fake, true, Vector3(-1.0, 0.0, 0.0), 0.02,
        0.1, Vector3.DOWN, false, false, true, true, true)
    if fake.calls != 3 or not _vector_near(
            output.get("held_boost_exhaust_direction"), Vector3.LEFT) \
            or not _near(float(output.get("held_boost_backstroke_weight")), 0.1) \
            or not _vector_near(output.get("held_boost_left_sector_world"), Vector3.DOWN):
        _fail("direction reversal did not replace old cache")
        return

    # If actual BOOST remains active while visual grace is off, retain the
    # cache unchanged but apply the incoming frame's live nozzle controls.
    output.update(fake, false, Vector3.BACK, 0.03,
        0.4, Vector3.RIGHT, false, true, false, false, true)
    if fake.calls != 4 or fake.enabled or not fake.sustained \
            or not _near(fake.backward, 0.4) \
            or not _vector_near(fake.left_sector, Vector3.RIGHT) \
            or not _vector_near(output.get("held_boost_exhaust_direction"), Vector3.LEFT):
        _fail("actual BOOST alone unexpectedly cleared the held pose cache")
        return

    # Both BOOST and visible BOOST pose ended: clear state and STILL update rig.
    output.update(fake, false, Vector3.BACK, 0.01,
        0.0, Vector3.ZERO, false, false, false, false, false)
    if fake.calls != 5 \
            or not _vector_near(output.get("held_boost_exhaust_direction"), Vector3.ZERO) \
            or not _near(float(output.get("held_boost_backstroke_weight")), 0.0) \
            or not _vector_near(output.get("held_boost_left_sector_world"), Vector3.ZERO):
        _fail("idle frame failed to clear all three cached nozzle values")
        return

    # A fresh neutral pose with no prior cache must NOT copy a false value
    # into the helper; pass this frame's nozzle directions unchanged.
    output.update(fake, true, Vector3.BACK, 0.0,
        0.3, Vector3.DOWN, false, false, true, false, false)
    if fake.calls != 6 or not _near(fake.backward, 0.3) \
            or not _vector_near(fake.left_sector, Vector3.DOWN) \
            or not _vector_near(output.get("held_boost_exhaust_direction"), Vector3.ZERO):
        _fail("new neutral pose fabricated previous-BOOST state")
        return

    # Probe the actual main-scene helper without changing nozzle pivots.
    var real_rig: Variant = game.get("rig")
    if real_rig == null or not real_rig.has_method("update_back_thruster_fx"):
        _fail("real rig FX update method unavailable")
        return
    print("SERA_THRUSTER_PRESENTATION_RUNTIME_PASS: cache, neutral, reversal, effect dispatch")
    quit(0)
