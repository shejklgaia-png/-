extends RefCounted
## BASE-only frame pacing. Use the native engine FPS limiter rather than
## rendering only every other 60 Hz frame. Animation, Tween and world timers
## continue to use their unmodified real-time delta.
const BASE_RENDER_FPS: int = 30
const INPUT_LOOP_FPS: int = 60

var _started: bool = false
var _grid_zoomed: bool = false
var _previous_max_fps: int = 0
var _previous_physics_fps: int = 60
var _previous_input_accumulation: bool = true


func start(_viewport: Viewport) -> void:
    if _started:
        return
    _previous_max_fps = Engine.max_fps
    _previous_physics_fps = Engine.physics_ticks_per_second
    _previous_input_accumulation = Input.use_accumulated_input
    _started = true
    _grid_zoomed = false
    # Limit actual frames per second instead of skipping visual output while
    # the scene, animations and camera continue advancing at twice that rate.
    Engine.max_fps = BASE_RENDER_FPS
    # Preserve the existing 60 Hz physics cadence and immediate _input events;
    # input delivery is still governed by the platform and engine main loop.
    Engine.physics_ticks_per_second = INPUT_LOOP_FPS
    Input.use_accumulated_input = false


func set_grid_zoomed(enabled: bool) -> void:
    if not _started or _grid_zoomed == enabled:
        return
    _grid_zoomed = enabled
    # Only the close-up GRID edit (including its exit tween) runs at 60 FPS.
    Engine.max_fps = INPUT_LOOP_FPS if enabled else BASE_RENDER_FPS


func stop() -> void:
    if not _started:
        return
    _started = false
    _grid_zoomed = false
    # BASE FPS settings must not leak into NEXUS or combat.
    Input.use_accumulated_input = _previous_input_accumulation
    Engine.physics_ticks_per_second = _previous_physics_fps
    Engine.max_fps = _previous_max_fps
