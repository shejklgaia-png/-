extends RefCounted
## Explicit visual updates for existing battle hit FX nodes.
## Main owns the timers, effects order, body/part selection and respawn.
## No scene lookup, persistent state, or allocation of visual nodes.

static func present_projectile_hit(overlay: ColorRect, remaining: float,
        duration: float) -> void:
    var intensity: float = remaining / duration
    overlay.color = Color(1.0, 0.26, 0.15, 0.13 * intensity)
    overlay.visible = remaining > 0.0


static func present_target_body_flash(material: StandardMaterial3D,
        remaining: float, duration: float) -> void:
    var ratio: float = remaining / duration
    # The BODY itself flashes only on BODY hits. Per-part color/pose is owned
    # by TargetBreakableParts and must never be applied to the parent mesh.
    material.albedo_color = Color("e53935").lerp(Color("632535"), ratio * 0.78)
    material.emission_energy_multiplier = lerpf(0.08, 0.03, ratio)
    material.emission = Color("a92724").lerp(Color("6b1727"), ratio)


static func present_damage_popup(label: Label, view_camera: Camera3D,
        impact_origin: Vector3, remaining: float) -> void:
    var screen_pt: Vector2 = view_camera.unproject_position(impact_origin + Vector3.UP * 0.28)
    var lift: float = (0.58 - remaining) * 75.0
    label.position = screen_pt - Vector2(26.0, 30.0 + lift)
    label.modulate.a = minf(1.0, remaining / 0.17)


static func present_incoming_damage_popup(label: Label,
        remaining: float) -> void:
    label.modulate.a = minf(1.0, remaining / 0.18)
    if remaining <= 0.0:
        label.visible = false
