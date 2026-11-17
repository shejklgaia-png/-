extends SceneTree
## v432: Every mesh is eligible, but ground snapping is permitted ONLY
## inside the precomputed Blockbench-authored contact time windows.
## Verify all 10 clips (7 source + 3 locomotion), every key and 60Hz.
const RIG = preload("res://scripts/bittaran_rig.gd")
const GROUND = preload("res://assets/bittaran_ground_contacts.gd")
const FRAME_STEP: float = 1.0 / 60.0
const POSITION_TOLERANCE: float = 0.002

func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    push_error("V432_ALL_MESH_GROUND_FAIL: " + message)
    quit(1)

func _active(spans: Array, t: float) -> bool:
    for w in spans:
        if t >= float(w[0]) - 0.00001 and t <= float(w[1]) + 0.00001:
            return true
    return false

func _run() -> void:
    var scene: PackedScene = load("res://scenes/bittaran_battle.tscn")
    if scene == null:
        _fail("could not load real Bittaran battle")
        return
    var battle: Node3D = scene.instantiate()
    root.add_child(battle)
    var rig: Node3D = battle.get("bittaran_rig")
    if rig == null or not bool(rig.get("loading_ok")):
        _fail("Bittaran rig not ready")
        return
    var mesh_nodes: Dictionary = rig.get("mesh_nodes_by_uuid")
    var bind_positions: Dictionary = rig.get("mesh_base_positions_by_uuid")
    var bones: Dictionary = rig.get("bones")
    var animations: Dictionary = rig.get("animations")
    var timeline: Dictionary = GROUND.DATA["clips"]
    if mesh_nodes.size() != 18 or timeline.size() != 10:
        _fail("expected 18 meshes and 10 authored/locomotion clips")
        return
    rig.set("blend_elapsed", 1.0)
    var frames_checked: int = 0
    var ground_frames: int = 0
    for clip_name in timeline.keys():
        if not animations.has(clip_name):
            _fail("missing animation " + clip_name)
            return
        var clip: Dictionary = animations[clip_name]
        var duration: float = float(clip.get("length", 0.0))
        if absf(duration - float(timeline[clip_name]["length"])) > 0.00001:
            _fail("contact timeline duration mismatch: " + clip_name)
            return
        var samples: Array[float] = [0.0]
        for track in (clip.get("animators", {}) as Dictionary).values():
            for key in track.get("keyframes", []):
                var t: float = float(key.get("time", 0.0))
                if t < duration - 0.00001 and t >= 0.0:
                    samples.append(t)
        for i in range(1, ceili(duration / FRAME_STEP) + 1):
            samples.append(minf(maxf(duration - 0.0001, 0.0),
                float(i) * FRAME_STEP))
        samples.sort()
        for t in samples:
            # This is the literal authored pose; no dynamic IK/head
            # targeting should contaminate the catalog validation.
            rig.call("apply_pose", str(clip_name), t)
            var before: Dictionary = {}
            for uid in bones.keys():
                var joint: Node3D = bones[uid]
                before[uid] = [joint.position, joint.quaternion]
            rig.call("apply_blockbench_ground_contacts",
                str(clip_name), t)
            var corrected: Dictionary = rig.get("ground_mesh_offsets_by_uuid")
            var contact_map: Dictionary = timeline[clip_name]["meshes"]
            for uid in mesh_nodes.keys():
                var active: bool = (
                    contact_map.has(uid)
                    and _active(contact_map[uid], t))
                var mesh: MeshInstance3D = mesh_nodes[uid]
                if active:
                    if not corrected.has(uid):
                        _fail("missing grounded mesh: "
                            + str([clip_name, t, uid]))
                        return
                    var lowest: float = float(rig.call(
                        "_ground_mesh_lowest_world_y", str(uid)))
                    if absf(lowest) > POSITION_TOLERANCE:
                        _fail("grounded mesh not on floor: "
                            + str([clip_name, t, uid, lowest]))
                        return
                    ground_frames += 1
                else:
                    if corrected.has(uid):
                        _fail("airborne mesh was modified: "
                            + str([clip_name, t, uid]))
                        return
                    if mesh.position.distance_to(
                            bind_positions[uid]) > 0.00001:
                        _fail("airborne mesh pose differs from original: "
                            + str([clip_name, t, uid]))
                        return
            for uid in bones.keys():
                var joint: Node3D = bones[uid]
                if joint.position.distance_to(before[uid][0]) > 0.00001:
                    _fail("ground snap changed joint pivot: "
                        + str([clip_name, t, uid]))
                    return
                if joint.quaternion.angle_to(before[uid][1]) > 0.00001:
                    _fail("ground snap changed authored joint rotation: "
                        + str([clip_name, t, uid]))
                    return
            frames_checked += 1
    if frames_checked < 850 or ground_frames < 1000:
        _fail("sampling did not cover enough frames or contacts: "
            + str([frames_checked, ground_frames]))
        return
    print("GODOT_V432_ALL_MESH_GROUND_PASS clips=10 meshes=18 frames=",
        frames_checked, " ground_contacts=", ground_frames)
    quit(0)
