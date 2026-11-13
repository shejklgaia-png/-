extends SceneTree
## v302: the lock point is the center of the FULL leg frame. All attack
## impacts must flash only their locked module, never the BODY/other parts.
func _initialize() -> void:
    call_deferred("_run")


func _fail(reason: String) -> void:
    push_error("V302_LEG_CENTER_PART_FX_FAILED: " + reason)
    quit(1)


func _check_neutral(parts: Node3D, target_material: StandardMaterial3D,
        core_mesh: MeshInstance3D, label: String) -> bool:
    if target_material.albedo_color != Color("e53935"):
        _fail(label + ": BODY was flashed by a part strike")
        return false
    if core_mesh.position != Vector3.ZERO or absf(core_mesh.rotation_degrees.z) > 0.00001:
        _fail(label + ": parent BODY movement was applied to all limbs")
        return false
    var all: Dictionary = parts.get("parts")
    for id in ["head","leg_fl","leg_fr","leg_rl","leg_rr"]:
        var p: Dictionary=all[id]
        if float(p["hit_fx_remaining"])>0.0001:
            _fail(label + ": stale other-part timer " + id)
            return false
        for slot in ["shell","accent","frame","dark"]:
            var mat: StandardMaterial3D=p[slot]
            if mat.albedo_color != (p["rest_"+slot] as Color) or mat.emission_enabled:
                _fail(label+": stray material glow "+id+"/"+slot)
                return false
        if (p["node"] as Node3D).position != (p["rest_position"] as Vector3):
            _fail(label + ": unaffected part was displaced " + id)
            return false
    return true


func _run() -> void:
    var scene: PackedScene=load("res://scenes/main.tscn")
    if scene==null:
        _fail("main scene not found")
        return
    var game: Node3D=scene.instantiate()
    root.add_child(game)
    var target: Node3D=game.get("target")
    var parts: Node3D=game.get("target_parts")
    var player: CharacterBody3D=game.get("player")
    var core_mesh: MeshInstance3D=game.get("target_mesh")
    var mat: StandardMaterial3D=game.get("target_material")
    var camera: Camera3D=game.get("camera")
    var burst: Node3D=game.get("hit_burst")
    if target==null or parts==null or player==null or core_mesh==null or mat==null or camera==null or burst==null:
        _fail("combat nodes missing")
        return
    var all: Dictionary=parts.get("parts")
    # Check true 3D world and HUD-local aim against each leg's 2m frame
    # pivot, before and after yaw rotation.
    for yaw in [0.0, PI*0.5]:
        target.rotation.y=yaw
        for id in ["leg_fl","leg_fr","leg_rl","leg_rr"]:
            var p: Dictionary=all[id]
            var node: Node3D=p["node"]
            var aim: Vector3=parts.call("get_part_aim_world",id)
            var center: Vector3=parts.call("get_part_center",id)
            if aim.distance_to(center)>0.0001:
                _fail("lock aim is not mid-frame: "+id)
                return
            var local: Vector3=parts.call("get_part_local_aim",id)
            if local.distance_to(node.position)>0.0001:
                _fail("HUD marker not centered on leg "+id)
                return
            if absf(float((p["aim"] as Vector3).y))>0.0001:
                _fail("foot lock still vertical-offset")
                return
    target.rotation.y=0.0

    # All five separate parts have unique material objects.
    var material_ids: Dictionary={}
    for id in ["head","leg_fl","leg_fr","leg_rl","leg_rr"]:
        for slot in ["shell","accent","frame","dark"]:
            var material: StandardMaterial3D=all[id][slot]
            if material_ids.has(material.get_instance_id()):
                _fail("material shared between independent hit parts")
                return
            material_ids[material.get_instance_id()]=true

    for id in ["head","leg_fl","leg_fr","leg_rl","leg_rr"]:
        parts.call("reset_parts")
        game.set("target_hp",500)
        game.set("locked_target_part_id",id)
        game.set("combat_state",3) # combo-locked strike
        game.set("hit_flash_remaining",0.0)
        var response: Dictionary=game.call("_apply_target_part_damage",
            "melee",12,5.0,0.0,0.0)
        if int(response["applied_damage"])<=0:
            _fail(id+": damage no longer applies")
            return
        if absf(float(game.get("hit_flash_remaining")))>0.00001:
            _fail(id+": BODY hit flash was also activated")
            return
        if float(all[id]["hit_fx_remaining"])<=0.0:
            _fail(id+": own hit timer did not activate")
            return
        game.call("_advance_hit_fx",0.016)
        var own_shell: StandardMaterial3D=all[id]["shell"]
        if own_shell.albedo_color == (all[id]["rest_shell"] as Color) or not own_shell.emission_enabled:
            _fail(id+": own surface did not flash")
            return
        if mat.albedo_color != Color("e53935") or mat.emission_enabled:
            _fail(id+": core was flashed along with struck part")
            return
        if core_mesh.position != Vector3.ZERO or absf(core_mesh.rotation_degrees.z)>0.00001:
            _fail(id+": parent wobble shook entire boss")
            return
        for other_id in ["head","leg_fl","leg_fr","leg_rl","leg_rr"]:
            if other_id==id:
                continue
            var other: Dictionary=all[other_id]
            if float(other["hit_fx_remaining"])>0.0:
                _fail(id+": hit timer leaked to "+other_id)
                return
            var other_shell: StandardMaterial3D=other["shell"]
            if other_shell.albedo_color != (other["rest_shell"] as Color) or other_shell.emission_enabled:
                _fail(id+": hit flash leaked to "+other_id)
                return
            if (other["node"] as Node3D).position != (other["rest_position"] as Vector3):
                _fail(id+": wobble leaked to "+other_id)
                return
        game.call("_advance_hit_fx",0.25)
        if not _check_neutral(parts,mat,core_mesh,id+" recovery"):
            return

    # The BODY itself gets only the core flash, not limb highlights or
    # movement; hit-stop/particles are handled by the original combat path.
    parts.call("reset_parts")
    game.set("target_hp",500)
    game.set("locked_target_part_id","")
    game.set("hit_flash_remaining",0.0)
    game.call("_apply_target_part_damage","bash",12,0.0,0.0,0.0)
    if float(game.get("hit_flash_remaining"))<=0.0:
        _fail("BODY core flash was removed")
        return
    game.call("_advance_hit_fx",0.016)
    if mat.albedo_color == Color("e53935"):
        _fail("BODY core flash did not display")
        return
    if core_mesh.position != Vector3.ZERO or absf(core_mesh.rotation_degrees.z)>0.00001:
        _fail("BODY hit transformed parent and moved all limbs")
        return
    for id in ["head","leg_fl","leg_fr","leg_rl","leg_rr"]:
        if float(all[id]["hit_fx_remaining"])>0.0 or (all[id]["shell"] as StandardMaterial3D).emission_enabled:
            _fail("BODY hit accidentally flashed limb "+id)
            return
    game.call("_advance_hit_fx",0.25)
    if not _check_neutral(parts,mat,core_mesh,"BODY recovery"):
        return

    # Broken part is retained by an active combo. Its damage may be
    # resolved through BODY defense but its visual must stay limb-only.
    parts.call("reset_parts")
    game.set("combat_state",3)
    game.set("target_hp",500)
    game.set("locked_target_part_id","leg_fl")
    var broken: Dictionary=game.call("_apply_target_part_damage","melee",12,200.0,0.0,0.0)
    if not bool(broken["broken"]):
        _fail("setup did not break leg_fl")
        return
    game.call("_apply_target_part_damage","melee",12,1.0,0.0,0.0)
    if float(game.get("hit_flash_remaining"))>0.0:
        _fail("broken locked leg wrongly flashed BODY on next combo hit")
        return

    # Verify kick sparks actually spawn on the selected limb, with the
    # same origin forwarded to the new part-local depth projection.
    parts.call("reset_parts")
    game.set("target_hp",500)
    game.set("locked_target_part_id","leg_rr")
    game.call("_register_side_kick_hit")
    var hit_pos: Vector3=game.get("impact_origin")
    var burst_origin: Vector3=burst.get("origin")
    if hit_pos.distance_to(burst_origin)>0.0001:
        _fail("kick impact sparkle origin differs from the locked part")
        return
    var box: AABB=parts.call("get_part_aabb","leg_rr")
    if not box.grow(0.06).has_point(hit_pos):
        _fail("kick sparks were placed outside the struck leg")
        return
    if (hit_pos-target.global_position).length()<0.01:
        _fail("leg sparks were centered on the BODY")
        return
    if float(game.get("hit_flash_remaining"))>0.0:
        _fail("kick hit flashed BODY")
        return

    print("GODOT_V302_LEG_CENTER_PART_FX_PASS")
    quit(0)
