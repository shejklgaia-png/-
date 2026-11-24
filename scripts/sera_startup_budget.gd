extends RefCounted
## Continuous startup context. Checkpoints are intentionally synchronous.
## Keep the non-null context so builders do not enter legacy frame-yield paths.
var tree: SceneTree
var yields: int = 0

func _init(scene_tree: SceneTree) -> void:
    tree = scene_tree

func checkpoint(_label: String) -> void:
    pass

func yield_frame() -> void:
    # Only the initial presentation and final render initialization use this.
    yields += 1
    await tree.process_frame

func report() -> void:
    print("SERA_BOOT_BUDGET: continuous startup; presentation frames=", yields)
