extends RefCounted
## Cooperative main-thread startup. Never used in normal gameplay.
## At the existing 10 FPS loading cap, leave ~40 ms of the nominal frame
## for display, engine work and scheduling. A single atomic operation may
## exceed this target; log it rather than claiming a guaranteed frame time.
const SLICE_USEC: int = 60000
var tree: SceneTree
var yields: int = 0
var _started: int
var _last_checkpoint: int
var _frame: int
var worst_slice_usec: int = 0
var worst_atomic_usec: int = 0
var worst_atomic_label: String = ""

func _init(scene_tree: SceneTree) -> void:
    tree = scene_tree
    _reset()

func _reset() -> void:
    _frame = Engine.get_process_frames()
    _started = Time.get_ticks_usec()
    _last_checkpoint = _started

func checkpoint(label: String) -> void:
    var now: int = Time.get_ticks_usec()
    if _frame != Engine.get_process_frames():
        _reset()
        return
    var atomic_usec: int = now - _last_checkpoint
    _last_checkpoint = now
    if atomic_usec > worst_atomic_usec:
        worst_atomic_usec = atomic_usec
        worst_atomic_label = label
    if atomic_usec > SLICE_USEC:
        print("SERA_BOOT_BUDGET: atomic ", label, " ", atomic_usec / 1000.0, "ms")
    var used: int = now - _started
    worst_slice_usec = maxi(worst_slice_usec, used)
    if used >= SLICE_USEC:
        await yield_frame()

func yield_frame() -> void:
    yields += 1
    await tree.process_frame
    _reset()

func report() -> void:
    print("SERA_BOOT_BUDGET: yields=", yields, " worst_slice_ms=", worst_slice_usec / 1000.0,
        " worst_atomic_ms=", worst_atomic_usec / 1000.0, " at=", worst_atomic_label)
