extends Control
## v71: In-project vector-rendered two-part radial controller (no image dependency).
## v72: Enlarge guide and visualize run vs outer-ring boost from main.gd.
## v73: Legacy floating analog disc (retired in v157).
## v157: Former fixed 8-way digital pad.
## v170: Accepted flick gestures draw a curved V-shaped boat wake behind the released finger.
## v169: Tap-attack ripple while released; any new press cancels it before the normal RUN controller.
## v158: Compact fixed-center continuous 360-degree RUN ring and directional
## indicator; the BOOST guide tracks the v161 184.8px entry boundary.
## Preserve v70 joystick color/alpha palette. Input stays in main.gd.
## v90: 100% RUN rim and 125% BOOST entry threshold guide.
## v115: While boosting, move the drawn knob fully beyond the 125% line.
## v62: Screen bottom 15% deep gray, preceding 10% transparent-to-gray gradient.
## v63: Brighten the neutral gray slightly; retain 90% opacity and region.
## Screen-space joystick + camera-projected 3D target reticle; no input interception.
## v54: The reticle is drawn over the projected target instead of screen center.
## v55: Instruction text moved into the compact top HUD; lower 25% stays empty.
## v64: Replace operation-zone gray with white, retain v63 fade and alpha.
## v65: Recommended operation-zone tone: blue-leaning medium gray with longer fade and shorter solid area.
## v57: Add a subtle bright gradient to hint that the lower 25% is an input space.
## v60: Gradually darken the lower 25% with a muted blue-gray overlay (0% to 40% opacity).
## v58: Make the operation-space gradient stronger and less blue, with a brighter grayish tint.
## v59: Make the top edge fully transparent while retaining the bottom intensity.

## v61: Deepen the bottom operation-area fade to neutral charcoal gray (72% max opacity).
var dragging: bool = false
var movement_boost_active: bool = false
var anchor_point: Vector2 = Vector2.ZERO
var radius: float = 70.0
var boost_base_radius: float = 105.0
var analog_direction: Vector2 = Vector2.ZERO
var melee_in_range: bool = false
# Screen coordinates supplied by Camera3D.unproject_position(target.global_position).
# A nonvisible/offscreen target does not leave a misleading marker at screen center.
var target_marker_position: Vector2 = Vector2.ZERO
var target_marker_visible: bool = false
# A brief visual acknowledgment of an accepted melee tap. Independent of the
# target lock ring; only the attack-release path starts this animation.
var attack_ripple_active: bool = false
var attack_ripple_elapsed: float = 0.0
var attack_ripple_position: Vector2 = Vector2.ZERO
# A recognized directional flick leaves three pairs of spreading wave crests.
var flick_wake_active: bool = false
var flick_wake_elapsed: float = 0.0
var flick_wake_tip: Vector2 = Vector2.ZERO
var flick_wake_forward: Vector2 = Vector2.UP
var flick_wake_length: float = 105.0
var flick_wake_half_width: float = 50.0

# v43: The four arcs spin once per transition; the target-following crosshair does not rotate.
# Each state transition is exactly one full turn in 0.20 seconds.
# Rotation: positive angles are clockwise in screen-space CanvasItem coordinates.
const LOCK_SPIN_DURATION: float = 0.20
const LOCK_SPIN_TURNS: float = 1.0
const LOCK_RADIUS_NORMAL: float = 62.0
const LOCK_RADIUS_MELEE: float = 42.0
const LOCK_RING_WIDTH_NORMAL: float = 2.0
const LOCK_RING_WIDTH_MELEE: float = 5.0
# 4 arcs are centered exactly on the horizontal/vertical axes at rest.
const LOCK_ARC_SWEEP: float = 0.70

# v245: RUN 70px, BOOST entry 105*1.10=115.5px.
const CONTROLLER_RUN_RADIUS: float = 70.0
const CONTROLLER_BOOST_START_RADIUS_RATIO: float = 1.10
const CONTROLLER_HUB_RADIUS_RATIO: float = 0.24
# v160: visual-only propulsion shell OUTSIDE the original BOOST boundary.
const BOOST_SHELL_RADIUS_RATIO: float = 1.19
const BOOST_SHELL_SEGMENT_HALF_ARC: float = 0.17
const BOOST_SHELL_SEGMENT_WIDTH: float = 3.125
const BOOST_CHEVRON_INNER_RATIO: float = 1.25
const BOOST_CHEVRON_OUTER_RATIO: float = 1.35
const BOOST_CHEVRON_HALF_WIDTH: float = 5.625
const BOOST_SHELL_INACTIVE_ALPHA_SCALE: float = 0.55
# v169: 2D-only, non-glowing cyan waves, centered on the released tap.
const ATTACK_RIPPLE_DURATION: float = 0.46
const ATTACK_RIPPLE_RING_COUNT: int = 3
const ATTACK_RIPPLE_RING_DELAY: float = 0.075
const ATTACK_RIPPLE_START_RADIUS: float = 12.0
const ATTACK_RIPPLE_END_RADIUS: float = 86.0
# Three shallow curved V bands, separated in time: no textures or glow.
const FLICK_WAKE_DURATION: float = 0.43
const FLICK_WAKE_BANDS: int = 3
const FLICK_WAKE_BAND_DELAY: float = 0.060
const FLICK_WAKE_CURVE_STEPS: int = 12

const CONTROLLER_FRAME_START_RATIO: float = 0.50  # Gradient left edge only; no input boundary
const OPERATION_ZONE_TOP_RATIO: float = 0.50  # frame top; 100% transparent
const OPERATION_ZONE_SOLID_RATIO: float = 0.92  # bottom 8% is a uniform medium gray
const OPERATION_ZONE_COLOR_TOP: Color = Color(0.494, 0.510, 0.533, 0.0)
const OPERATION_ZONE_COLOR_BOTTOM: Color = Color(0.494, 0.510, 0.533, 0.85)

var lock_rotation: float = 0.0
var lock_radius: float = LOCK_RADIUS_NORMAL
var lock_anim_elapsed: float = LOCK_SPIN_DURATION
var lock_anim_start_angle: float = 0.0
var lock_anim_start_radius: float = LOCK_RADIUS_NORMAL
var lock_anim_end_radius: float = LOCK_RADIUS_NORMAL
var lock_anim_spin_sign: float = 1.0

func _ready() -> void:
    # Only spend per-frame CPU time when the ring is animating.
    set_process(false)

func set_target_marker_projection(screen_position: Vector2, is_visible: bool) -> void:
    # Reproject whenever the target OR the camera moves; this remains independent
    # from the 0.20-second lock-on ring animation and never intercepts touch.
    if target_marker_visible == is_visible and (not is_visible or target_marker_position.is_equal_approx(screen_position)):
        return
    target_marker_position = screen_position
    target_marker_visible = is_visible
    queue_redraw()

func set_melee_in_range(value: bool) -> void:
    if melee_in_range == value:
        return
    melee_in_range = value
    # On reversal, continue from the current onscreen size and angle.
    # The new transition starts one whole turn in the opposite direction.
    lock_anim_start_angle = lock_rotation
    lock_anim_start_radius = lock_radius
    lock_anim_end_radius = LOCK_RADIUS_MELEE if value else LOCK_RADIUS_NORMAL
    lock_anim_spin_sign = 1.0 if value else -1.0
    lock_anim_elapsed = 0.0
    set_process(true)
    # Color and thickness change immediately with the melee state.
    queue_redraw()

func _process(delta: float) -> void:
    lock_anim_elapsed = minf(lock_anim_elapsed + maxf(delta, 0.0), LOCK_SPIN_DURATION)
    var progress: float = lock_anim_elapsed / LOCK_SPIN_DURATION
    lock_rotation = lock_anim_start_angle + lock_anim_spin_sign * TAU * LOCK_SPIN_TURNS * progress
    # Smooth shrinking/expanding radius, while the rotation stays fast and constant.
    var eased: float = progress * progress * (3.0 - 2.0 * progress)
    lock_radius = lerpf(lock_anim_start_radius, lock_anim_end_radius, eased)
    if progress >= 1.0:
        lock_radius = lock_anim_end_radius
        lock_rotation = fposmod(lock_rotation, TAU)
    if attack_ripple_active:
        attack_ripple_elapsed = minf(
            attack_ripple_elapsed + maxf(delta, 0.0), ATTACK_RIPPLE_DURATION)
        if attack_ripple_elapsed >= ATTACK_RIPPLE_DURATION:
            attack_ripple_active = false
    if flick_wake_active:
        flick_wake_elapsed = minf(
            flick_wake_elapsed + maxf(delta, 0.0), FLICK_WAKE_DURATION)
        if flick_wake_elapsed >= FLICK_WAKE_DURATION:
            flick_wake_active = false
    # Lock spin, tap ripple and flick wake share one frame loop: finishing
    # one effect must not prematurely stop either of the other two.
    if progress >= 1.0 and not attack_ripple_active and not flick_wake_active:
        set_process(false)
    queue_redraw()

func show_attack_ripple(screen_point: Vector2) -> void:
    # Attack has been accepted on release; do not cover an active joystick.
    if dragging:
        return
    cancel_flick_wake()
    attack_ripple_position = screen_point
    attack_ripple_elapsed = 0.0
    attack_ripple_active = true
    set_process(true)
    queue_redraw()

func cancel_attack_ripple() -> void:
    if not attack_ripple_active:
        return
    attack_ripple_active = false
    attack_ripple_elapsed = 0.0
    if lock_anim_elapsed >= LOCK_SPIN_DURATION and not flick_wake_active:
        set_process(false)
    queue_redraw()

func show_flick_wake(start_point: Vector2, end_point: Vector2) -> void:
    # Called only after the released swipe actually starts or queues its action.
    # The wake's forward axis follows the finger, independently of camera yaw.
    var displacement: Vector2 = end_point - start_point
    if dragging or displacement.length_squared() < 144.0:
        return
    cancel_attack_ripple()
    flick_wake_tip = end_point
    flick_wake_forward = displacement.normalized()
    flick_wake_length = clampf(displacement.length() * 0.95, 78.0, 145.0)
    flick_wake_half_width = clampf(displacement.length() * 0.48, 33.0, 64.0)
    flick_wake_elapsed = 0.0
    flick_wake_active = true
    set_process(true)
    queue_redraw()

func cancel_flick_wake() -> void:
    if not flick_wake_active:
        return
    flick_wake_active = false
    flick_wake_elapsed = 0.0
    if lock_anim_elapsed >= LOCK_SPIN_DURATION and not attack_ripple_active:
        set_process(false)
    queue_redraw()

func cancel_gesture_effects() -> void:
    # New touch/joystick takes priority; eliminate both release feedback types.
    cancel_attack_ripple()
    cancel_flick_wake()

func show_drag(origin: Vector2, _pos: Vector2, max_radius: float) -> void:
    # New touch immediately restores the familiar RUN/BOOST ring.
    cancel_gesture_effects()
    # Spawn only once per touch. The center is never dragged or reanchored.
    if dragging:
        return
    dragging = true
    anchor_point = origin
    radius = CONTROLLER_RUN_RADIUS
    boost_base_radius = max_radius
    analog_direction = Vector2.ZERO
    queue_redraw()

func set_analog_direction(value: Vector2) -> void:
    var next_direction: Vector2 = value.limit_length(1.0)
    if analog_direction.is_equal_approx(next_direction):
        return
    analog_direction = next_direction
    queue_redraw()

func hide_drag() -> void:
    dragging = false
    movement_boost_active = false
    analog_direction = Vector2.ZERO
    queue_redraw()

func set_movement_boost(value: bool) -> void:
    if movement_boost_active == value:
        return
    movement_boost_active = value
    queue_redraw()

func _draw() -> void:
    # v246: Keep the existing lower-right gray gradient as decoration.
    # The former border/corner strokes are removed; controller circles
    # can appear at any screen touch not reserved for an actual UI button.
    var frame_left: float = size.x * CONTROLLER_FRAME_START_RATIO
    var fade_top: float = size.y * OPERATION_ZONE_TOP_RATIO
    var solid_top: float = size.y * OPERATION_ZONE_SOLID_RATIO
    var fade_vertices := PackedVector2Array([
        Vector2(frame_left, fade_top),
        Vector2(size.x, fade_top),
        Vector2(size.x, solid_top),
        Vector2(frame_left, solid_top)
    ])
    var fade_colors := PackedColorArray([
        OPERATION_ZONE_COLOR_TOP,
        OPERATION_ZONE_COLOR_TOP,
        OPERATION_ZONE_COLOR_BOTTOM,
        OPERATION_ZONE_COLOR_BOTTOM
    ])
    draw_polygon(fade_vertices, fade_colors)
    draw_rect(Rect2(frame_left, solid_top, size.x - frame_left,
        size.y - solid_top), OPERATION_ZONE_COLOR_BOTTOM, true)

    var accent := Color(0.21, 0.85, 0.93, 0.87)
    var low := Color(0.21, 0.85, 0.93, 0.30)
    var reticle_color := Color(1.0, 0.22, 0.26, 0.98) if melee_in_range else accent
    var reticle_outer_width: float = LOCK_RING_WIDTH_MELEE if melee_in_range else LOCK_RING_WIDTH_NORMAL
    if target_marker_visible:
        var mark: Vector2 = target_marker_position
        for segment in range(4):
            # Four arcs orbit the TARGET's projected screen center.
            var center_angle: float = float(segment) * PI * 0.5 + lock_rotation
            var start: float = center_angle - LOCK_ARC_SWEEP * 0.5
            draw_arc(mark, lock_radius, start, start + LOCK_ARC_SWEEP, 25, reticle_color, reticle_outer_width, true)
        draw_line(mark + Vector2(-13, 0), mark + Vector2(-4, 0), reticle_color, 2.0)
        draw_line(mark + Vector2(4, 0), mark + Vector2(13, 0), reticle_color, 2.0)
        draw_line(mark + Vector2(0, -13), mark + Vector2(0, -4), reticle_color, 2.0)
        draw_line(mark + Vector2(0, 4), mark + Vector2(0, 13), reticle_color, 2.0)

    if attack_ripple_active:
        _draw_attack_ripple()
    if flick_wake_active:
        _draw_flick_wake()
    if dragging:
        _draw_analog_controller(accent, low)


func _draw_attack_ripple() -> void:
    # Three staggered, expanding circular outlines. No blur, glow or textures.
    # Each wave becomes thinner and transparent, then the idle HUD resumes.
    for ring_index in range(ATTACK_RIPPLE_RING_COUNT):
        var delay: float = float(ring_index) * ATTACK_RIPPLE_RING_DELAY
        var age: float = attack_ripple_elapsed - delay
        if age < 0.0:
            continue
        var progress: float = clampf(
            age / maxf(0.01, ATTACK_RIPPLE_DURATION - delay), 0.0, 1.0)
        var ease_out: float = 1.0 - pow(1.0 - progress, 2.0)
        var wave_radius: float = lerpf(
            ATTACK_RIPPLE_START_RADIUS, ATTACK_RIPPLE_END_RADIUS, ease_out)
        var opacity: float = pow(1.0 - progress, 2.0) * (
            0.78 - 0.14 * float(ring_index))
        var stroke_width: float = lerpf(3.2, 1.0, progress)
        draw_arc(attack_ripple_position, wave_radius, 0.0, TAU, 64,
            Color(0.21, 0.85, 0.93, opacity), stroke_width, true)


func _draw_flick_wake() -> void:
    # The release point is the boat's bow. Water-like V crests expand and
    # fade behind it in screen space, following any recognized flick direction.
    var sideways := Vector2(-flick_wake_forward.y, flick_wake_forward.x)
    for band in range(FLICK_WAKE_BANDS):
        var delay: float = float(band) * FLICK_WAKE_BAND_DELAY
        var age: float = flick_wake_elapsed - delay
        if age < 0.0:
            continue
        var progress: float = clampf(
            age / maxf(0.01, FLICK_WAKE_DURATION - delay), 0.0, 1.0)
        var fade: float = pow(1.0 - progress, 2.0)
        var back_distance: float = lerpf(8.0, flick_wake_length, progress)
        var spread: float = lerpf(13.0, flick_wake_half_width, progress)
        var stroke: Color = Color(
            0.21, 0.85, 0.93, fade * (0.84 - 0.14 * float(band)))
        for side in [-1.0, 1.0]:
            var points := PackedVector2Array()
            for sample in range(FLICK_WAKE_CURVE_STEPS + 1):
                var t: float = float(sample) / float(FLICK_WAKE_CURVE_STEPS)
                # Each crest is curved, not a straight arrow or radial ring.
                var back: float = back_distance + t * (
                    20.0 + 30.0 * progress) + sin(t * PI) * 7.0 * progress
                var lateral: float = side * (
                    2.0 + spread * pow(t, 1.25))
                points.append(flick_wake_tip
                    - flick_wake_forward * back + sideways * lateral)
            draw_polyline(points, stroke, lerpf(3.1, 1.0, progress), true)


func _draw_analog_controller(accent: Color, low: Color) -> void:
    # The RUN disc stays fixed at the initial touch point; its radius is
    # shorter, while BOOST begins at the v245 115.5px boundary.
    draw_circle(anchor_point, radius, Color(0.15, 0.60, 0.68, 0.08))
    var rim_color: Color = accent if movement_boost_active else low
    draw_arc(anchor_point, radius, 0.0, TAU, 96, rim_color, 1.875, true)
    var boost_guide: Color = Color(0.21, 0.85, 0.93, 0.60) if movement_boost_active else Color(0.21, 0.85, 0.93, 0.15)
    draw_arc(anchor_point, boost_base_radius * CONTROLLER_BOOST_START_RADIUS_RATIO,
        0.0, TAU, 96, boost_guide, 1.25, true)
    # Fixed propulsion shell moves inward alongside the 115.5px entry ring.
    _draw_boost_outer_shell(accent)
    draw_circle(anchor_point, radius * CONTROLLER_HUB_RADIUS_RATIO,
        Color(0.13, 0.54, 0.61, 0.22))
    draw_arc(anchor_point, radius * CONTROLLER_HUB_RADIUS_RATIO,
        0.0, TAU, 48, low, 1.25, true)
    # A rotating angular marker (not a finger-tracking knob) communicates
    # any of 360 degrees; brightness also reflects analog RUN strength.
    var strength: float = analog_direction.length()
    if strength > 0.00001:
        var heading: Vector2 = analog_direction / strength
        var angle: float = heading.angle()
        var indicator_color: Color = Color(
            0.21, 0.85, 0.93, lerpf(0.38, 0.98, strength))
        draw_arc(anchor_point, radius * 0.88,
            angle - 0.26, angle + 0.26, 20, indicator_color, 4.375, true)
        var sideways: Vector2 = Vector2(-heading.y, heading.x)
        var tip: Vector2 = anchor_point + heading * radius * 0.69
        var base: Vector2 = anchor_point + heading * radius * 0.39
        draw_colored_polygon(PackedVector2Array([
            tip, base + sideways * 5.625, base - sideways * 5.625
        ]), indicator_color)
    _draw_move_mode_indicator(accent, rim_color)


func _draw_boost_outer_shell(accent: Color) -> void:
    # Eight fixed armor arcs and outward thrust arrows; no finger tracking.
    # v245: all geometry follows the 105px BOOST baseline, 125% of v244.
    # Shell/chevron proportions remain aligned with the actual input radius.
    var alpha_scale: float = 1.0 if movement_boost_active else BOOST_SHELL_INACTIVE_ALPHA_SCALE
    var shell_color: Color = Color(accent.r, accent.g, accent.b, 0.34 * alpha_scale)
    var arrow_color: Color = Color(accent.r, accent.g, accent.b, 0.28 * alpha_scale)
    var shell_radius: float = boost_base_radius * BOOST_SHELL_RADIUS_RATIO
    for segment in range(8):
        var angle: float = TAU * float(segment) / 8.0
        # Segmented industrial outer housing, distinct from the 125% guide.
        draw_arc(anchor_point, shell_radius,
            angle - BOOST_SHELL_SEGMENT_HALF_ARC,
            angle + BOOST_SHELL_SEGMENT_HALF_ARC,
            14, shell_color, BOOST_SHELL_SEGMENT_WIDTH, true)
        var outward: Vector2 = Vector2.RIGHT.rotated(angle)
        var sideways: Vector2 = Vector2(-outward.y, outward.x)
        var tip: Vector2 = anchor_point + outward * (boost_base_radius * BOOST_CHEVRON_OUTER_RATIO)
        var base: Vector2 = anchor_point + outward * (boost_base_radius * BOOST_CHEVRON_INNER_RATIO)
        draw_colored_polygon(PackedVector2Array([
            tip,
            base + sideways * BOOST_CHEVRON_HALF_WIDTH,
            base - sideways * BOOST_CHEVRON_HALF_WIDTH
        ]), arrow_color)


func _draw_move_mode_indicator(accent: Color, rim_color: Color) -> void:
    # Keep the RUN/BOOST label above the NEW outermost arrows; otherwise the
    # label at the 115.5px rim would overlap the 141.75px thrust tips.
    var mode_label: String = "BOOST  1.5x" if movement_boost_active else "RUN  1.0x"
    var label_width: float = 103.75
    var label_height: float = 21.25
    var rect := Rect2(anchor_point.x - label_width * 0.5,
        anchor_point.y - boost_base_radius * BOOST_CHEVRON_OUTER_RATIO - label_height - 10.0,
        label_width, label_height)
    draw_rect(rect, Color(0.13, 0.54, 0.61, 0.45), true)
    draw_rect(rect, rim_color, false, 1.25, true)
    var font: Font = get_theme_default_font()
    if font != null:
        draw_string(font, Vector2(rect.position.x, rect.position.y + 15.0),
            mode_label, HORIZONTAL_ALIGNMENT_CENTER, label_width, 11, accent)
