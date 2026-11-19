extends SceneTree
## v488: actual scene changes from 3D NEXUS building to static menus and back.
func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    push_error("SERA_BASE_NEXUS_ROUTE_FAIL: " + message)
    quit(1)

func _run() -> void:
    var scene: PackedScene = load("res://scenes/base_exploration.tscn")
    if scene == null:
        _fail("hub scene missing")
        return
    var hub: Node3D = scene.instantiate()
    root.add_child(hub)
    current_scene = hub
    await process_frame
    if current_scene == null or current_scene.name != "BaseExploration":
        _fail("hub is not the current active scene")
        return
    var camera: Camera3D = hub.get("cam") as Camera3D
    var building: Node3D = hub.get_node("NEXUSBuilding") as Node3D
    if not bool(hub.call("_nexus_hit",
            camera.unproject_position(building.global_position + Vector3(0, 2.5, 0)))):
        _fail("NEXUS building touch target not projected")
        return
    hub.call("_enter_nexus")
    await process_frame
    await process_frame
    var nexus: Node = current_scene
    if nexus == null or nexus.name != "CommandNexus":
        _fail("tapping building did not enter CommandNexus")
        return
    if nexus.get_node_or_null("CRATE") != null:
        _fail("outdoor CRATE wrongly copied into the non-walkable Nexus")
        return
    var exit_button: Panel = nexus.get("explore_panel") as Panel
    if exit_button == null or not exit_button.visible:
        _fail("NEXUS exit-to-base action not available")
        return
    nexus.call("_enter_base")
    await process_frame
    await process_frame
    if current_scene == null or current_scene.name != "BaseExploration":
        _fail("NEXUS exit did not return to base hub")
        return
    print("SERA_BASE_NEXUS_ROUTE_PASS")
    quit(0)
