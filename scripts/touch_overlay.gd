extends Control
## v71: In-project vector-rendered two-part radial controller (no image dependency).
## v72: Enlarge guide and visualize run vs outer-ring boost from main.gd.
## v73: Single translucent disc and center-to-finger line, v70 style;
## double outward chevrons live entirely OUTSIDE the disc.
## Preserve v70 joystick color/alpha palette. Input stays in main.gd.
## v90: 100% rim snap and subtle 125% entry guide on rim overtravel.
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
# Restored v70-style directional line ends at the finger position, clamped to
# this 168px disc for readability even when BOOST is active.
const CONTROLLER_CHEVRON_NEAR_RATIO: float = 1.13
const CONTROLLER_CHEVRON_FAR_RATIO: float = 1.27
const CONTROLLER_FINGER_DOT_RADIUS: float = 29.0
const CONTROLLER_BOOST_START_RADIUS_RATIO: float = 1.25

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
        set_process(false)
    queue_redraw()

func show_drag(origin: Vector2, pos: Vector2, max_radius: float) -> void:
    dragging = true
    anchor_point = origin
    finger_point = pos
    radius = max_radius
    queue_redraw()

func hide_drag() -> void:
    dragging = false
    movement_boost_active = false
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
        _draw_radial_controller(accent, low)


func _draw_radial_controller(accent: Color, low: Color) -> void:
    # One uninterrupted translucent disc, covering v72's full outer radius.
    # Reuse v70's exact base color/alpha instead of adding an image or a ring.
    draw_circle(anchor_point, radius, Color(0.15, 0.60, 0.68, 0.08))
    var rim_color: Color = accent if movement_boost_active else low
    draw_arc(anchor_point, radius, 0.0, TAU, 96, rim_color, 3.0, true)

    # Only while over-running the RUN rim, show a short, faint threshold
    # arc in the drag direction. The ordinary controller remains uncluttered.
    # The guide is drawn from the actual finger position, NOT the snapped knob.
    var finger_vector: Vector2 = finger_point - anchor_point
    if finger_vector.length_squared() > radius * radius and not movement_boost_active:
        var heading: float = finger_vector.angle()
        var guide_color: Color = Color(0.21, 0.85, 0.93, 0.26)
        draw_arc(anchor_point, radius * CONTROLLER_BOOST_START_RADIUS_RATIO,
            heading - 0.38, heading + 0.38, 18, guide_color, 2.0, true)

    # v70 joystick direction line. The finger dot travels over the whole disc,
    # stopping visually at the rim if the real finger extends beyond it.
    # The BOOST state and outside arrows indicate that extra travel.
    var knob_center: Vector2 = anchor_point + (finger_point - anchor_point).limit_length(radius)
    draw_line(anchor_point, knob_center, low, 5.0, true)
    draw_circle(knob_center, CONTROLLER_FINGER_DOT_RADIUS, Color(0.13, 0.54, 0.61, 0.45))
    draw_arc(knob_center, CONTROLLER_FINGER_DOT_RADIUS, 0.0, TAU, 42, accent, 2.0, true)

    # All eight chevrons lie outside the circle. BOOST makes both the rim
    # and direction guide brighter, preserving the existing cyan RGBA palette.
    for direction in [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]:
        _draw_chevron(anchor_point, direction, radius * CONTROLLER_CHEVRON_NEAR_RATIO,
            radius * 0.068, radius * 0.065, rim_color, 3.5)
        _draw_chevron(anchor_point, direction, radius * CONTROLLER_CHEVRON_FAR_RATIO,
            radius * 0.068, radius * 0.065, rim_color, 3.5)
    _draw_move_mode_indicator(accent, rim_color)


func _draw_move_mode_indicator(accent: Color, rim_color: Color) -> void:
    # Place this pill beyond the uppermost outside arrow. It updates together
    # with the rim and chevrons as the finger crosses the visible boundary.
    var mode_label: String = "BOOST  1.5x" if movement_boost_active else "RUN  1.0x"
    var label_width: float = 166.0
    var label_height: float = 34.0
    var rect := Rect2(anchor_point.x - label_width * 0.5,
        anchor_point.y - radius - label_height - 74.0,
        label_width, label_height)
    draw_rect(rect, Color(0.13, 0.54, 0.61, 0.45), true)
    draw_rect(rect, rim_color, false, 2.0, true)
    var font: Font = get_theme_default_font()
    if font != null:
        draw_string(font, Vector2(rect.position.x, rect.position.y + 24.0),
            mode_label, HORIZONTAL_ALIGNMENT_CENTER, label_width, 18, accent)


func _draw_chevron(center: Vector2, direction: Vector2, offset: float,
        half_width: float, half_length: float, tint: Color, stroke: float) -> void:
    # Each arrow is two clean, anti-aliased straight strokes with rounded ends.
    var outward_tip: Vector2 = center + direction * (offset + half_length * 0.5)
    var tail_center: Vector2 = center + direction * (offset - half_length * 0.5)
    var perpendicular: Vector2 = Vector2(-direction.y, direction.x)
    var first: Vector2 = tail_center + perpendicular * half_width
    var last: Vector2 = tail_center - perpendicular * half_width
    draw_polyline(PackedVector2Array([first, outward_tip, last]), tint, stroke, true)
    draw_circle(first, stroke * 0.5, tint)
    draw_circle(outward_tip, stroke * 0.5, tint)
    draw_circle(last, stroke * 0.5, tint)
