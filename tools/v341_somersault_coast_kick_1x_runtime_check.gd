extends SceneTree
## v341 end-to-end authored flight/grounded coast plus 1x side-kick speed.
func _initialize() -> void:
    call_deferred("_run")
func _fail(reason: String) -> void:
    push_error("V341_COAST_FAILED: " + reason)
    quit(1)
func _run() -> void:
    var scene: PackedScene=load("res://scenes/main.tscn")
    if scene==null:
        _fail("missing main scene")
        return
    var game: Node3D=scene.instantiate()
    root.add_child(game)
    var player: CharacterBody3D=game.get("player")
    var target: Node3D=game.get("target")
    var rig: Node3D=game.get("rig")
    if player==null or target==null or rig==null or not bool(rig.get("loading_ok")):
        _fail("rig unavailable")
        return
    var constants: Dictionary=game.get_script().get_script_constant_map()
    if absf(float(constants["SIDE_KICK_MOTION_TIME_MULTIPLIER"])-(8.0/3.0))>.0001:
        _fail("side kicks are not 0.80s at the baseline speed")
        return
    target.position=Vector3.ZERO
    player.position=Vector3(0.0,0.0,-5.5)
    game.set("target_hp",500)
    game.set("energy",100.0)
    game.set("locked_target_part_id","")
    if not bool(game.call("_start_back_somersault")):
        _fail("Kick_b refused")
        return
    game.call("_advance_back_somersault",0.80)
    if not bool(game.get("back_somersault_launched")):
        _fail("backwards flight not launched")
        return
    var direction: Vector3=game.get("back_somersault_direction")
    rig.call("_process",0.07)
    game.call("_advance_back_somersault",0.016)
    if not bool(game.get("landing_active")):
        _fail("grounded landing missing")
        return
    var touchdown: Vector3=player.position
    game.call("_advance_landing",0.05)
    var a: float=(player.position-touchdown).dot(direction)
    game.call("_advance_landing",0.05)
    var b: float=(player.position-touchdown).dot(direction)
    game.call("_advance_landing",0.05)
    var c: float=(player.position-touchdown).dot(direction)
    if not a>0.0 or not b>a or not c>b:
        _fail("rear motion stopped before landing ended")
        return
    game.call("_advance_landing",0.05)
    if bool(game.get("landing_active")):
        _fail("landing animation lengthened")
        return
    if absf((player.position-touchdown).dot(direction)-0.30)>0.04:
        _fail("landing coast is not 0.30m")
        return
    if player.position.y>0.0001:
        _fail("grounded slide lifted the actor")
        return
    print("GODOT_V341_COAST_PASS: sustained Kick_b rear movement, 0.80s lateral kicks")
    quit(0)
