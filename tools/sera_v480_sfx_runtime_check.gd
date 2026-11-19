extends SceneTree
## SERA v480: verify actual uploaded sounds in the live player and boss.
## Charge and beam audio must be keyed to the railgun phase (no timer
## duplicate), and the laser must sustain seamlessly until emission ends.
const DT: float = 1.0 / 60.0

func _initialize() -> void:
    call_deferred("_run")

func _fail(reason: String) -> void:
    push_error("SERA_V480_SOUND_FAIL: " + reason)
    quit(1)

func _run() -> void:
    var game: Node3D = load(
        "res://scenes/bittaran_battle.tscn").instantiate()
    root.add_child(game)
    game.set_process(false)
    game.set_physics_process(false)
    var foot: AudioStreamPlayer = game.get("footstep_audio")
    if foot == null or not foot.stream is AudioStreamOggVorbis:
        _fail("player footsteps did not load the uploaded robot-hit Ogg")
        return
    if foot.stream.get_length() < 0.9 or (
            foot.stream.get_length() > 1.1):
        _fail("player metal-footstep source duration changed")
        return
    var player: CharacterBody3D = game.get("player")
    player.position.y = 0.0
    game.call("_on_foot_contact", "L")
    if not foot.playing or absf(foot.pitch_scale - 0.96) > 0.0001:
        _fail("left foot did not trigger creator's metal-hit source")
        return
    game.call("_on_foot_contact", "R")
    if not foot.playing or absf(foot.pitch_scale - 1.03) > 0.0001:
        _fail("right foot trigger/pitch source changed")
        return
    foot.stop()
    player.position.y = 0.5
    game.call("_on_foot_contact", "L")
    if foot.playing:
        _fail("airborne foot contact triggered unwanted sound")
        return
    player.position.y = 0.0

    var gun: Node3D = game.get("bittaran_railgun")
    var audio: Node = gun.get("railgun_audio")
    if audio == null or not bool(audio.get("sound_ready")):
        _fail("Bittaran 3 submitted SFX did not load")
        return
    var charge: AudioStreamPlayer = audio.get("charge")
    var attack: AudioStreamPlayer = audio.get("laser_attack")
    var loop: AudioStreamPlayer = audio.get("laser_loop")
    if charge == null or attack == null or loop == null or (
            not charge.stream is AudioStreamOggVorbis) or (
            not attack.stream is AudioStreamOggVorbis) or (
            not loop.stream is AudioStreamOggVorbis):
        _fail("laser/charge streams must be Ogg Vorbis for Android")
        return
    if absf(charge.stream.get_length() - 2.015) > 0.08 or (
            absf(attack.stream.get_length() - 0.36) > 0.04) or (
            absf(loop.stream.get_length() - 0.59) > 0.06):
        _fail("supplied and timeline-prepared sample durations changed")
        return
    if (loop.stream as AudioStreamOggVorbis).loop != true or (
            (charge.stream as AudioStreamOggVorbis).loop) or (
            (attack.stream as AudioStreamOggVorbis).loop):
        _fail("laser sustain must loop; gravity and laser onset must not")
        return
    for path in [
        "res://assets/sera_player_footstep_v480.ogg",
        "res://assets/bittaran_charge_v480.ogg",
        "res://assets/bittaran_laser_attack_v480.ogg",
        "res://assets/bittaran_laser_sustain_loop_v480.ogg",
    ]:
        if FileAccess.get_file_as_bytes(path).size() < 4000:
            _fail("Android GitSync cannot access physical Ogg: " + path)
            return

    gun.call("reset")
    var target: Vector3 = player.global_position
    gun.call("advance", 9.99, target, true)
    if charge.playing or attack.playing or loop.playing:
        _fail("charge/laser SFX played during the first 10s fill")
        return
    gun.call("advance", 0.02, target, true)
    if not charge.playing or attack.playing or loop.playing or (
            int(audio.get("charge_started")) != 1):
        _fail("gravity source must start exactly once at t=10 sphere")
        return
    gun.call("advance", 1.0, target, true)
    if int(audio.get("charge_started")) != 1 or not charge.playing:
        _fail("gravity source restarted as sphere began shrinking at t=11")
        return
    gun.call("advance", 0.99, target, true)
    if charge.playing or not attack.playing or not loop.playing or (
            int(audio.get("laser_started")) != 1):
        _fail("laser onset/loop must start together, charge stop at t=12")
        return
    var start_position: float = loop.get_playback_position()
    gun.call("advance", 0.45, target, true)
    if not loop.playing or (
            int(audio.get("laser_started")) != 1) or (
            loop.get_playback_position() + 0.02 < start_position):
        _fail("continuous laser playback restarted during active emission")
        return
    gun.call("advance", 1.535, target, true)
    if not loop.playing or float(
            audio.get("laser_fade_remaining")) <= 0.0:
        _fail("laser loop must fade on emission end, not hard-stop")
        return
    gun.call("advance", 0.18, target, true)
    if loop.playing or charge.playing or attack.playing:
        _fail("laser sustain did not stop after release fade")
        return
    gun.call("reset")
    if loop.playing or charge.playing or attack.playing:
        _fail("boss reset leaked old charge or laser sound")
        return
    print("SERA_V480_SFX_PASS creator_footstep_contact=true ",
        "original_metal_ogg=true airborne_silent=true ",
        "gravity_charge_t10_only=true laser_attack_t12_once=true ",
        "laser_sustain_loop=true no_frame_restart=true ",
        "laser_end_fade=true reset_silences_all=true ",
        "android_direct_ogg_sources_present=true")
    quit(0)
