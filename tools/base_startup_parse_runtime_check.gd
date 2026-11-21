extends SceneTree
## Detect unparsed BASE and facility scripts before rendering/UI tests can hang.
func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    push_error("SERA_BASE_STARTUP_PARSE_FAIL: " + message)
    quit(1)

func _run() -> void:
    # NEXUS is loaded when entered, not on BASE startup. Check its script
    # explicitly so an undefined UI layout identifier cannot ship unnoticed.
    var nexus_resource: Resource = load("res://scripts/command_nexus.gd")
    if not (nexus_resource is Script) or not (
            nexus_resource as Script).can_instantiate():
        _fail("NEXUS command_nexus.gd does not compile")
        return
    var nexus_packed: Resource = load("res://scenes/command_nexus.tscn")
    if not (nexus_packed is PackedScene):
        _fail("NEXUS command_nexus.tscn cannot be loaded")
        return
    var nexus_instance: Node3D = (
        nexus_packed as PackedScene).instantiate() as Node3D
    if nexus_instance == null or nexus_instance.get_script() == null:
        _fail("NEXUS root scene script cannot instantiate")
        return
    nexus_instance.free()
    var fac: Resource = load("res://scripts/base_facility_system.gd")
    if not (fac is Script) or not (fac as Script).can_instantiate():
        _fail("base_facility_system.gd does not compile")
        return
    var scene_res: Resource = load("res://scenes/base_exploration.tscn")
    if not (scene_res is PackedScene):
        _fail("base_exploration.tscn not loadable")
        return
    var scene: Node3D = (scene_res as PackedScene).instantiate() as Node3D
    if scene == null or scene.get_script() == null:
        _fail("BASE root script failed to parse/instantiate")
        return
    root.add_child(scene)
    # The boot path reserves the first frames for an overlay; assert that
    # the actual world and GUI are constructed after their initial yield.
    # Boot now yields between heavy phases so the animated loader repaints.
    # Wait for completion, not a fixed 4-frame assumption.
    for frame in range(24):
        await process_frame
        if scene.get_node_or_null("BaseStartupOverlay") == null:
            break
    if scene.get_node_or_null("BaseFacilities") == null:
        _fail("no BASE facilities after boot")
        return
    if scene.get_node_or_null("BaseHUDLayer") == null:
        _fail("no BASE HUD after boot")
        return
    if scene.get_node_or_null("BaseOverheadCamera") == null:
        _fail("no BASE camera after boot")
        return
    if scene.get_node_or_null("BaseStartupOverlay") != null:
        _fail("loader not dismissed after full BASE initialization")
        return
    print("SERA_BASE_STARTUP_PARSE_RUNTIME_PASS")
    quit(0)
