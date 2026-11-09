extends Control
## v71: In-project vector-rendered two-part radial controller (no image dependency).
## v72: Enlarge guide and visualize run vs outer-ring boost from main.gd.
## v73: Legacy floating analog disc (retired in v157).
## v157: Fixed-in-gesture digital 8-way pad with eight static arrow glyphs;
## only the selected direction lights up; no finger-following knob.
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
var radius: float = 168.0
var digital_direction_sector: int = -1
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

# The pad and arrows stay fixed for the whole gesture; BOOST retains the
# original 125%/110% distance thresholds, drawn as a stationary outer guide.
const CONTROLLER_BOOST_START_RADIUS_RATIO: float = 1.25
const CONTROLLER_ARROW_RADIUS_RATIO: float = 0.67
const CONTROLLER_HUB_RADIUS_RATIO: float = 0.19

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

func show_drag(origin: Vector2, _pos: Vector2, max_radius: float) -> void:
    # Spawn at the initial touch once. Subsequent finger motion never moves it.
    if dragging:
        return
    dragging = true
    anchor_point = origin
    radius = max_radius
    digital_direction_sector = -1
    queue_redraw()

func set_digital_direction(sector: int) -> void:
    var selected: int = sector if sector >= 0 and sector < 8 else -1
    if digital_direction_sector == selected:
        return
    digital_direction_sector = selected
    queue_redraw()

func hide_drag() -> void:
    dragging = false
    movement_boost_active = false
    digital_direction_sector = -1
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
        _draw_digital_controller(accent, low)


func _draw_digital_controller(accent: Color, low: Color) -> void:
    # The pad never follows the finger. All direction arrows remain fixed
    # inside the rim; only the selected sector is highlighted.
    draw_circle(anchor_point, radius, Color(0.15, 0.60, 0.68, 0.08))
    var rim_color: Color = accent if movement_boost_active else low
    draw_arc(anchor_point, radius, 0.0, TAU, 96, rim_color, 3.0, true)
    # The BOOST entry guide is a full static ring, not a finger-tracking arc.
    var boost_guide: Color = Color(0.21, 0.85, 0.93, 0.60) if movement_boost_active else Color(0.21, 0.85, 0.93, 0.15)
    draw_arc(anchor_point, radius * CONTROLLER_BOOST_START_RADIUS_RATIO,
        0.0, TAU, 96, boost_guide, 2.0, true)
    draw_circle(anchor_point, radius * CONTROLLER_HUB_RADIUS_RATIO,
        Color(0.13, 0.54, 0.61, 0.22))
    draw_arc(anchor_point, radius * CONTROLLER_HUB_RADIUS_RATIO,
        0.0, TAU, 48, low, 2.0, true)
    for sector in range(8):
        var angle: float = float(sector) * PI * 0.25
        var pointing: Vector2 = Vector2.RIGHT.rotated(angle)
        var selected: bool = sector == digital_direction_sector
        var center: Vector2 = anchor_point + pointing * radius * CONTROLLER_ARROW_RADIUS_RATIO
        var sideways: Vector2 = Vector2(-pointing.y, pointing.x)
        var tip: Vector2 = center + pointing * 15.0
        var tail: Vector2 = center - pointing * 10.0
        var triangle := PackedVector2Array([
            tip, tail + sideways * 11.0, tail - sideways * 11.0
        ])
        if selected:
            # Fixed sector highlight: instant feedback without a moving knob.
            draw_arc(anchor_point, radius * 0.89,
                angle - PI * 0.115, angle + PI * 0.115,
                16, accent, 8.0, true)
        draw_colored_polygon(triangle,
            accent if selected else Color(0.21, 0.85, 0.93, 0.28))
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
