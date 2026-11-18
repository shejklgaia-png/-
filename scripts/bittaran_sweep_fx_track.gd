extends RefCounted
## v456: SWEEP FX trajectory is baked OFFLINE from the real playable
## Blockbench clip + attack-leg ground IK, then shipped as a small
## constant dataset in the APK. Sampling the live rig at runtime
## caused >0.8m divergence from the mesh actually rendered after IK.
const BAKED = preload("res://scripts/bittaran_sweep_fx_baked_data.gd")

static func bake_from_authored_clips(
        battle: Node3D, rig: Node3D, boss: Node3D) -> Dictionary:
    if battle == null or rig == null or boss == null or (
            not bool(rig.get("loading_ok"))):
        return {}
    # No bone transform modification, no scene instance, no procedural
    # IK prediction. All 4 trajectories are already checked in.
    return BAKED.tracks()


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
