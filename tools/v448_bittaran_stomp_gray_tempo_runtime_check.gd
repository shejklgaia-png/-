extends SceneTree
## v448: physical source-key retiming, grounded stop and neutral-grey FX.
const ATTACKS = preload("res://scripts/bittaran_attacks.gd")
const FX = preload("res://scripts/bittaran_dirt_fx.gd")


func _initialize() -> void:
    call_deferred("_run")


func _fail(message: String) -> void:
    push_error("V448_STOMP_GRAY_TEMPO_FAIL " + message)
    quit(1)


func _near(a: float, b: float, tolerance: float = 0.0001) -> bool:
    return absf(a - b) <= tolerance


func _is_gray(color: Color) -> bool:
    return _near(color.r, color.g, 0.00001) and (
        _near(color.g, color.b, 0.00001))


func _run() -> void:
    var checked: int = 0
    for id in ATTACKS.LEG_IDS:
        var lift: float = ATTACKS.stomp_raise_seconds(id)
        var drop: float = ATTACKS.stomp_drop_seconds(id)
        var apex: float = ATTACKS.stomp_apex_source_seconds(id)
        var landed: float = ATTACKS.stomp_landing_source_seconds(id)
        if not (_near(ATTACKS.source_clip_time("stomp", 0.0, id), 0.0)
                and _near(ATTACKS.source_clip_time("stomp", lift, id),
                    apex)
                and _near(ATTACKS.source_clip_time("stomp",
                    lift + drop, id), landed)
                and _near(ATTACKS.source_play_seconds("stomp", id),
                    lift + drop)):
            _fail("stomp key boundaries differ: " + id)
            return
        var previous: float = -0.001
        for i in range(241):
            var elapsed: float = (lift + drop) * float(i) / 240.0
            var source: float = ATTACKS.source_clip_time(
                "stomp", elapsed, id)
            if source < previous - 0.000001 or (
                    source > landed + 0.000001):
                _fail("source time reversed or overran contact: " + id)
                return
            previous = source
        if not (ATTACKS.source_playback_speed("stomp",
                lift * 0.1, id) > ATTACKS.source_playback_speed(
                "stomp", lift * 0.8, id)
                and ATTACKS.source_playback_speed(
                "stomp", lift + drop * 0.2, id) <
                ATTACKS.source_playback_speed(
                "stomp", lift + drop * 0.8, id)
                and _near(ATTACKS.source_playback_speed(
                "stomp", lift + drop, id), 0.0)
                and ATTACKS.source_hold_seconds("stomp") > 0.0):
            _fail("lift must brake into apex; drop must accelerate to stop")
            return
        var director = ATTACKS.new()
        if not director.force_start(id, "stomp"):
            _fail("cannot start " + id)
            return
        var entry: float = ATTACKS.source_entry_seconds("stomp")
        var frame: Dictionary = director.advance(
            entry + lift + drop * 0.72, Vector3.ZERO, {}, true)
        var contact_t: float = float(frame.get("authored_time", -1.0))
        if not (contact_t > apex and contact_t < landed
                and director.register_stomp_contact(id, contact_t)):
            _fail("ground contact not latched during descent: " + id)
            return
        var frozen: Dictionary = director.advance(
            0.015, Vector3.ZERO, {}, true)
        if not (_near(float(frozen.get("authored_time", -1.0)),
                contact_t) and _near(float(frozen.get(
                "authored_playback_speed", -1.0)), 0.0)):
            _fail("foot advanced after touch-down: " + id)
            return
        checked += 1

    var fx: Node3D = FX.new()
    get_root().add_child(fx)
    for name in ["stomp_core", "stomp_dust", "stomp_ground",
            "stomp_fines", "stomp_chunks", "stomp_grit",
            "kick_dust", "kick_forward_dust", "kick_trailing_dust",
            "kick_chunks", "kick_grit", "sweep_dust", "sweep_chunks"]:
        var emitter: CPUParticles3D = fx.get(name) as CPUParticles3D
        if emitter == null or not _is_gray(emitter.color):
            _fail("colored emitter: " + name)
            return
        if emitter.mesh is BoxMesh:
            var material: StandardMaterial3D = (
                emitter.mesh.material as StandardMaterial3D)
            if material == null or not _is_gray(material.albedo_color):
                _fail("colored debris: " + name)
                return
    var mesh: QuadMesh = fx.get("dust_sprite_mesh") as QuadMesh
    var material: StandardMaterial3D = (
        mesh.material as StandardMaterial3D)
    var texel: Color = material.albedo_texture.get_image().get_pixel(48, 48)
    if not _is_gray(texel):
        _fail("sprite texture still tinted brown")
        return
    # Same-kind consecutive stomps must restart the one-shot emitters.
    fx.set("last_kind", "stomp")
    fx.set("last_attack_elapsed", 3.0)
    fx.set("stomped_this_attack", true)
    fx.call("advance_attack", {
        "kind": "stomp", "time": 0.05,
        "windup": 1.0, "strike": 0.2
    }, Vector3.ZERO, Vector3.ZERO, 0.016, false)
    if bool(fx.get("stomped_this_attack")):
        _fail("same-kind second hit was not rearmed")
        return
    fx.queue_free()
    print("GODOT_V448_STOMP_GRAY_TEMPO_PASS legs=", checked,
        " lift=fast_to_braked_apex",
        " drop=slow_to_accelerated_contact",
        " ground_contact=immediate_pose_stop",
        " particles=neutral_gray")
    quit(0)
