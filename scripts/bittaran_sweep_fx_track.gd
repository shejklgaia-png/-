extends RefCounted
## Pre-bake the four canonical Blockbench SWEEP clips to a fixed
## source-time -> local-foot-contact trajectory. This runs ONCE before
## any sweep dust is emitted, not in the per-frame VFX renderer.
## The real battle foot, damage, source animation and IK are untouched.
const ATTACKS = preload("res://scripts/bittaran_attacks.gd")
const RIG = preload("res://scripts/bittaran_rig.gd")
const SAMPLE_SPACING_SECONDS: float = 0.045

static func bake_from_authored_clips(
        battle: Node3D, rig: Node3D, boss: Node3D) -> Dictionary:
    if battle == null or rig == null or boss == null or (
            not bool(rig.get("loading_ok"))):
        return {}
    var all_bones: Dictionary = rig.get("bones")
    if all_bones.is_empty():
        return {}
    # Preserve EVERY joint transform. Source clip sampling changes the
    # rig temporarily, but must not disturb the live already-solved pose.
    var original: Dictionary = {}
    for uid in all_bones.keys():
        original[uid] = (all_bones[uid] as Node3D).transform
    var tracks: Dictionary = {}
    for id in ATTACKS.LEG_IDS:
        var lookup: Dictionary = RIG.SOURCE_ATTACK_CLIPS.get(id, {})
        var clip_name: String = str(lookup.get("sweep", ""))
        var begin: float = ATTACKS.source_hit_start_seconds("sweep", id)
        var finish: float = (
            ATTACKS.SWEEP_REAR_FIRST_STROKE_END_KEY_SECONDS
            if id.begins_with("leg_r")
            else ATTACKS.SWEEP_FRONT_FIRST_STROKE_END_KEY_SECONDS)
        if clip_name.is_empty() or not (rig.get("animations") as Dictionary).has(
                clip_name) or not is_finite(begin) or finish <= begin:
            continue
        var count: int = maxi(1,
            int(ceil((finish - begin) / SAMPLE_SPACING_SECONDS)))
        var trajectory: Array[Dictionary] = []
        for index in range(count + 1):
            # Include BOTH exact Blockbench first/last scrape keys.
            var t: float = lerpf(begin, finish,
                float(index) / float(count))
            rig.call("apply_source_clip_exact", clip_name, t)
            var contact: Vector3 = battle.call(
                "_bittaran_ground_fx_contact", id)
            if not is_finite(contact.x) or not is_finite(contact.z):
                trajectory.clear()
                break
            trajectory.append({
                "time": t,
                "point": boss.to_local(
                    Vector3(contact.x, 0.0, contact.z))
            })
        if trajectory.size() > 1:
            tracks[id] = trajectory
    # Guaranteed restore, including the BODY that the source clip
    # changes before interpreting all four leg rotations.
    for uid in original.keys():
        (all_bones[uid] as Node3D).transform = original[uid]
    return tracks


static func interpolate_local(
        track: Array, source_t: float) -> Vector3:
    if track.is_empty():
        return Vector3.ZERO
    if source_t <= float(track[0]["time"]):
        return track[0]["point"]
    for i in range(1, track.size()):
        var after: float = float(track[i]["time"])
        if source_t <= after:
            var before: float = float(track[i - 1]["time"])
            var alpha: float = clampf((source_t - before)
                / maxf(after - before, 0.000001), 0.0, 1.0)
            return (track[i - 1]["point"] as Vector3).lerp(
                track[i]["point"] as Vector3, alpha)
    return track[-1]["point"]
