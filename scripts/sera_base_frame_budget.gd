extends RefCounted
## BASE-only frame pacing. The engine's logic/input loop remains at 60 Hz,
## while the root viewport is drawn at 30 Hz outside GRID edit zoom.
## This intentionally throttles visuals, not _input() event processing.
const BASE_RENDER_FPS: int = 30
const INPUT_LOOP_FPS: int = 60
const BASE_RENDER_INTERVAL: float = 1.0 / float(BASE_RENDER_FPS)

var _viewport_rid: RID
var _started: bool = false
var _grid_zoomed: bool = false
var _render_clock: float = 0.0
var _previous_max_fps: int = 0
var _previous_physics_fps: int = 60
var _previous_input_accumulation: bool = true
var _previous_update_mode: int = RenderingServer.VIEWPORT_UPDATE_WHEN_VISIBLE


func start(viewport: Viewport) -> void:
    if _started or viewport == null:
        return
    _viewport_rid = viewport.get_viewport_rid()
    if not _viewport_rid.is_valid():
        return
    _previous_max_fps = Engine.max_fps
    _previous_physics_fps = Engine.physics_ticks_per_second
    _previous_input_accumulation = Input.use_accumulated_input
    _previous_update_mode = RenderingServer.viewport_get_update_mode(_viewport_rid)
    _started = true
    _grid_zoomed = false
    # Start with a visible frame; subsequent 60 Hz cycles alternate draw/skip.
    _render_clock = BASE_RENDER_INTERVAL * 0.5
    Engine.max_fps = INPUT_LOOP_FPS
    Engine.physics_ticks_per_second = INPUT_LOOP_FPS
    Input.use_accumulated_input = false
    RenderingServer.viewport_set_update_mode(
        _viewport_rid, RenderingServer.VIEWPORT_UPDATE_ONCE)


func advance(delta: float) -> void:
    if not _started or _grid_zoomed:
        return
    # Keep the full 60 Hz main loop for touch events. Render every 1/30 s.
    # Avoid a catch-up burst after resume/slow frames.
    _render_clock = minf(BASE_RENDER_INTERVAL,
        _render_clock + maxf(delta, 0.0))
    if _render_clock + 0.000001 >= BASE_RENDER_INTERVAL:
        _render_clock = 0.0
        RenderingServer.viewport_set_update_mode(
            _viewport_rid, RenderingServer.VIEWPORT_UPDATE_ONCE)
    else:
        RenderingServer.viewport_set_update_mode(
            _viewport_rid, RenderingServer.VIEWPORT_UPDATE_DISABLED)


func set_grid_zoomed(enabled: bool) -> void:
    if not _started or _grid_zoomed == enabled:
        return
    _grid_zoomed = enabled
    _render_clock = BASE_RENDER_INTERVAL * 0.5
    if enabled:
        RenderingServer.viewport_set_update_mode(
            _viewport_rid, RenderingServer.VIEWPORT_UPDATE_ALWAYS)
    else:
        RenderingServer.viewport_set_update_mode(
            _viewport_rid, RenderingServer.VIEWPORT_UPDATE_ONCE)


func stop() -> void:
    if not _started:
        return
    _started = false
    _grid_zoomed = false
    # Restore the exact pre-BASE settings so NEXUS and combat are untouched.
    RenderingServer.viewport_set_update_mode(_viewport_rid, _previous_update_mode)
    Input.use_accumulated_input = _previous_input_accumulation
    Engine.physics_ticks_per_second = _previous_physics_fps
    Engine.max_fps = _previous_max_fps
