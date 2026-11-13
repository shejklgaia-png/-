extends SceneTree
## v304 camera AUTO volumes are 115% of each reference envelope, remain
## separate from visible meshes, attacks and all physics collision layers.
func _initialize() -> void:
    call_deferred("_run")


func _fail(message: String) -> void:
    push_error("V304_CAMERA_LOCK_HITBOX_FAILED: " + message)
    quit(1)


func _run() -> void:
    var scene: PackedScene = load("res://scenes/main.tscn")
    if scene == null:
        _fail("missing training scene")
        return
    var game: Node3D = scene.instantiate()
    root.add_child(game)
    var target: Node3D = game.get("target")
    var parts: Node3D = game.get("target_parts")
    var player: CharacterBody3D = game.get("player")
    var core_mesh: MeshInstance3D = game.get("target_mesh")
    var collider: AnimatableBody3D = game.get("target_collider")
    if target == null or parts == null or player == null or core_mesh == null or collider == null:
        _fail("target/part/physics scene nodes unavailable")
        return
    var model: Dictionary = parts.get("parts")
    var ids: Array[String]=["", "head", "leg_fl", "leg_fr", "leg_rl", "leg_rr"]
    var areas: Array[Area3D] = []
    for id in ids:
        var reference_size: Vector3 = (core_mesh.mesh as BoxMesh).size
        var offset: Vector3 = Vector3.ZERO
        if not id.is_empty():
            reference_size = model[id]["size"]
        var extra: Vector3 = Vector3.ZERO
        if id == "head":
            extra = Vector3(0.0,1.0,0.85)
            offset = Vector3(0.0,0.5,0.425)
        var area: Area3D = parts.get("core_camera_lock_area") if id.is_empty() \
            else model[id]["camera_lock_area"]
        if area == null or not area.is_inside_tree():
            _fail("separate CAMERA hitbox missing for "+id)
            return
        areas.append(area)
        if area.collision_layer != 0 or area.collision_mask != 0 \
                or area.monitoring or area.monitorable:
            _fail("camera-only shape registered into physics contacts "+id)
            return
        if (area.position-offset).length()>0.0001:
            _fail("camera volume center offset wrong for "+id)
            return
        if area.get_child_count()!=1 or not area.get_child(0) is CollisionShape3D:
            _fail("camera area must own exactly one BoxShape3D "+id)
            return
        var collision: CollisionShape3D = area.get_child(0)
        if collision.name!="CameraOnlyBox" or not collision.shape is BoxShape3D:
            _fail("camera volume shape absent for "+id)
            return
        var box: BoxShape3D = collision.shape
        var expected: Vector3 = (reference_size+extra)*1.15
        if (box.size-expected).length()>0.0001:
            _fail("camera box not 115% of original envelope "+id)
            return
        if box.size.x <= reference_size.x or box.size.y <= reference_size.y \
                or box.size.z <= reference_size.z:
            _fail("not enlarged along all three axes "+id)
            return
        # Trace through the newly padded outermost 15% rim in X.
        # The old rendered/virtual envelope does not touch this ray.
        var x: float = (reference_size.x*0.5+expected.x*0.5)*0.5
        var origin: Vector3 = area.to_global(Vector3(x,0.0,expected.z*2.0))
        var finish: Vector3 = area.to_global(Vector3(x,0.0,-expected.z*2.0))
        var camera_hit: float = float(parts.call("_camera_lock_body_volume_distance",
            origin, finish)) if id.is_empty() else float(parts.call(
            "_camera_lock_part_volume_distance", origin, finish, id))
        if camera_hit==INF:
            _fail("newly padded edge is not lockable for "+id)
            return
        var legacy: float = float(parts.call("_camera_center_line_body_distance",
            origin, finish)) if id.is_empty() else float(parts.call(
            "_camera_center_line_part_distance", origin, finish, id))
        if legacy!=INF:
            _fail("camera padding was not outside the original mesh for "+id)
            return

    # Every hitbox follows the boss's yaw and its own part pivot. Their
    # BoxShape3Ds are never inserted into the movement solid body.
    for angle in [0.0, PI*0.5, PI]:
        target.rotation.y=angle
        for id in ids:
            var area: Area3D = areas[ids.find(id)]
            var inside: Vector3 = area.to_global(Vector3.ZERO)
            var approach: Vector3 = area.to_global(Vector3(0,0,10.0))
            var distance: float = float(parts.call(
                "_camera_lock_body_volume_distance",approach,inside)) \
                if id.is_empty() else float(parts.call(
                "_camera_lock_part_volume_distance",approach,inside,id))
            if distance==INF:
                _fail("expanded camera box does not follow target yaw "+id)
                return
    target.rotation.y=0.0

    # The actual attack / movement shapes remain exactly their old sizes.
    var physical: CollisionShape3D = collider.get_node("TargetBoxCollision")
    if not physical.shape is BoxShape3D or (physical.shape as BoxShape3D).size != Vector3(2.0,2.0,3.4):
        _fail("BODY movement physics collision was resized")
        return
    for id in ids:
        if id.is_empty():
            continue
        var expected_part: Vector3=model[id]["size"]
        var part_hit: AABB=parts.call("get_part_aabb",id)
        if part_hit.size!=expected_part:
            _fail("melee hitbox was enlarged for "+id)
            return
    # Normal frontal and rear paired-ray selection is still valid, with
    # HEAD's original cap extended and then 15% padding around it.
    var center: Vector3=target.global_position
    var front: Vector3=center+Vector3(0,-1.53,9)
    var rear: Vector3=center+Vector3(0,-1.53,-9)
    if str(parts.call("select_actor_parallel_lines_part",front,center))!="head":
        _fail("frontal HEAD was lost after adding camera boxes")
        return
    if str(parts.call("select_actor_parallel_lines_part",rear,center))!="":
        _fail("rear BODY was lost after adding camera boxes")
        return
    # Destroyed parts retain their AUTO selection and enlarged camera box
    # as long as the ray truly intersects it.
    model["head"]["broken"]=true
    if not bool(parts.call("actor_parallel_lines_hits_part",front,center,"head")):
        _fail("broken HEAD lost its retained ray hitbox")
        return
    model["head"]["broken"]=false
    print("GODOT_V304_CAMERA_LOCK_HITBOX_PASS")
    quit(0)
