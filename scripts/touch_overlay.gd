extends Control
## v150: smooth per-frame finger/heading/charge visualization with rounded anti-aliased arrows.
## v149: finger-following 360° swipe heading arrow + directional BOOST charge (no analog circle).
## v72: Enlarge guide and visualize run vs outer-ring boost from main.gd.
## v73: Single translucent disc and center-to-finger line, v70 style;
## double outward chevrons live entirely OUTSIDE the disc.
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
var finger_point: Vector2 = Vector2.ZERO
var radius: float = 168.0
var swipe_heading: Vector2 = Vector2.ZERO  # Instant target from gameplay input.
var swipe_boost_progress: float = 0.0
# Visual-only state, updated every rendered frame rather than every touch event.
var visual_finger_point: Vector2 = Vector2.ZERO
var visual_heading_angle: float = 0.0
var visual_heading_initialized: bool = false
var visual_boost_progress: float = 0.0
const SWIPE_POSITION_FOLLOW_SECONDS: float = 0.040
const SWIPE_HEADING_FOLLOW_SECONDS: float = 0.052
const SWIPE_CHARGE_FOLLOW_SECONDS: float = 0.070
var melee_in_range: bool = false
# Screen coordinates supplied by Camera3D.unproject_position(target.global_position).
# A nonvisible/offscreen target does not leave a misleading marker at screen center.
var target_marker_position: Vector2 = Vector2.ZERO
var target_marker_visible: bool = false

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

# Two chevrons in each cardinal direction, placed beyond the outer rim.
# The RUN knob stays inside the 168px disc; the BOOST knob moves outside
# the 125% threshold line (even when hysteresis allows a shorter touch drag).
const CONTROLLER_CHEVRON_NEAR_RATIO: float = 1.13
const CONTROLLER_CHEVRON_FAR_RATIO: float = 1.27
const CONTROLLER_FINGER_DOT_RADIUS: float = 29.0
const CONTROLLER_BOOST_START_RADIUS_RATIO: float = 1.25
const CONTROLLER_BOOST_KNOB_RADIUS_RATIO: float = 1.48

const OPERATION_ZONE_TOP_RATIO: float = 0.75  # top of fade: 100% transparent
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
    # Reticle spin and active drag animate per frame; idle drawing stays event-driven.
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
    # The target reticle keeps its exact pre-v150 0.20s one-turn animation.
    if lock_anim_elapsed < LOCK_SPIN_DURATION:
        lock_anim_elapsed = minf(lock_anim_elapsed + maxf(delta, 0.0), LOCK_SPIN_DURATION)
        var progress: float = lock_anim_elapsed / LOCK_SPIN_DURATION
        lock_rotation = lock_anim_start_angle + lock_anim_spin_sign * TAU * LOCK_SPIN_TURNS * progress
        var eased: float = progress * progress * (3.0 - 2.0 * progress)
        lock_radius = lerpf(lock_anim_start_radius, lock_anim_end_radius, eased)
        if progress >= 1.0:
            lock_radius = lock_anim_end_radius
            lock_rotation = fposmod(lock_rotation, TAU)
    if dragging:
        # Exponential smoothing is frame-rate independent. Only the UI lags a
        # few tens of milliseconds; main.gd's 360-degree steering is untouched.
        var step: float = maxf(delta, 0.0)
        var position_alpha: float = 1.0 - exp(-step / SWIPE_POSITION_FOLLOW_SECONDS)
        var heading_alpha: float = 1.0 - exp(-step / SWIPE_HEADING_FOLLOW_SECONDS)
        var charge_alpha: float = 1.0 - exp(-step / SWIPE_CHARGE_FOLLOW_SECONDS)
        visual_finger_point = visual_finger_point.lerp(finger_point, position_alpha)
        if visual_heading_initialized and swipe_heading.length_squared() > 0.0001:
            # Interpolate the shortest angular arc, correctly crossing 0°/360°.
            visual_heading_angle = lerp_angle(
                visual_heading_angle, swipe_heading.angle(), heading_alpha)
        visual_boost_progress = lerpf(
            visual_boost_progress, swipe_boost_progress, charge_alpha)
    queue_redraw()
    if not dragging and lock_anim_elapsed >= LOCK_SPIN_DURATION:
        set_process(false)

func show_drag(origin: Vector2, pos: Vector2, max_radius: float) -> void:
    dragging = true
    anchor_point = origin
    finger_point = pos
    radius = max_radius
    visual_finger_point = pos
    swipe_heading = Vector2.ZERO
    swipe_boost_progress = 0.0
    visual_boost_progress = 0.0
    visual_heading_initialized = false
    set_process(true)
    queue_redraw()

func hide_drag() -> void:
    dragging = false
    movement_boost_active = false
    swipe_heading = Vector2.ZERO
    swipe_boost_progress = 0.0
    visual_boost_progress = 0.0
    visual_heading_initialized = false
    if lock_anim_elapsed >= LOCK_SPIN_DURATION:
        set_process(false)
    queue_redraw()

func set_swipe_motion(pos: Vector2, heading: Vector2,
        charge: float, boosted: bool) -> void:
    finger_point = pos
    swipe_heading = heading.normalized() if heading.length_squared() > 0.0001 else Vector2.ZERO
    swipe_boost_progress = clampf(charge, 0.0, 1.0)
    movement_boost_active = boosted
    # Make the first direction visible immediately; smooth all later turns.
    if not visual_heading_initialized and swipe_heading.length_squared() > 0.0001:
        visual_heading_angle = swipe_heading.angle()
        visual_heading_initialized = true
    if dragging:
        set_process(true)
    queue_redraw()

func set_movement_boost(value: bool) -> void:
    if movement_boost_active == value:
        return
    movement_boost_active = value
    queue_redraw()

func _draw() -> void:
    # A two-stage visual guide: 75%-92% fades from transparent to a muted medium gray;
    # 92%-100% keeps the same tone. No touch interception.
    var fade_top: float = size.y * OPERATION_ZONE_TOP_RATIO
    var solid_top: float = size.y * OPERATION_ZONE_SOLID_RATIO
    var fade_vertices := PackedVector2Array([
        Vector2(0.0, fade_top),
        Vector2(size.x, fade_top),
        Vector2(size.x, solid_top),
        Vector2(0.0, solid_top)
    ])
    var fade_colors := PackedColorArray([
        OPERATION_ZONE_COLOR_TOP,
        OPERATION_ZONE_COLOR_TOP,
        OPERATION_ZONE_COLOR_BOTTOM,
        OPERATION_ZONE_COLOR_BOTTOM
    ])
    draw_polygon(fade_vertices, fade_colors)
    draw_rect(Rect2(0.0, solid_top, size.x, size.y - solid_top), OPERATION_ZONE_COLOR_BOTTOM, true)

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

    if dragging:
        _draw_swipe_controller(accent, low)


# Small, mobile finger-following HUD, NOT a fixed-origin joystick.
# Arrow = immediate travel direction; short curved bar = long-drag BOOST
# progress. No four-way chevrons, drag radius or analog velocity knob.
func _draw_swipe_controller(accent: Color, low: Color) -> void:
    var center := Vector2(clampf(visual_finger_point.x, 70.0, size.x - 70.0),
        clampf(visual_finger_point.y - 63.0, 65.0, size.y - 65.0))
    var boosting: bool = movement_boost_active
    var bright := Color(0.27, 0.97, 1.0, 0.98) if boosting else accent
    draw_circle(center, 36.0, Color(0.10, 0.23, 0.31, 0.48))
    draw_arc(center, 35.0, 0.0, TAU, 48, low, 1.8, true)
    if not boosting:
        draw_arc(center, 35.0, -PI * 0.5,
            -PI * 0.5 + TAU * visual_boost_progress,
            40, bright, 4.0, true)
    else:
        draw_arc(center, 35.0, 0.0, TAU, 48, bright, 4.0, true)
    if visual_heading_initialized:
        var direction := Vector2(cos(visual_heading_angle), sin(visual_heading_angle))
        var side := Vector2(-direction.y, direction.x)
        # Rounded, anti-aliased vector arrow rather than a hard polygon that
        # appears jagged when rotated on a portrait Android display.
        var tail: Vector2 = center - direction * 14.0
        var tip: Vector2 = center + direction * 24.0
        draw_line(tail, tip, bright, 5.0, true)
        draw_circle(tail, 2.5, bright)
        draw_polyline(PackedVector2Array([
            tip - direction * 12.0 + side * 10.0,
            tip,
            tip - direction * 12.0 - side * 10.0]), bright, 5.0, true)
        draw_circle(tip, 2.5, bright)
        draw_line(center - direction * 21.0,
            center - direction * 37.0, low, 4.0, true)
        if boosting:
            for n in range(2):
                var chevron_tail := center - direction * (35.0 + n * 12.0)
                draw_polyline(PackedVector2Array([
                    chevron_tail + side * 7.0,
                    chevron_tail + direction * 8.0,
                    chevron_tail - side * 7.0]), bright, 2.5, true)
    else:
        draw_circle(center, 7.0, bright)
    var font: Font = get_theme_default_font()
    if font != null:
        var label: String = "BOOST  x1.5" if boosting else "RUN"
        draw_string(font, center + Vector2(-60.0, -48.0),
            label, HORIZONTAL_ALIGNMENT_CENTER, 120.0, 17, bright)
