extends SceneTree
## Real SERA runtime check, not a fake mesh/HTML parser.
const Preview = preload("res://tools/equipment_intake/godot_preview.gd")

func _initialize() -> void:
    call_deferred("_check")

func _fail(msg: String) -> void:
    push_error("SERA_GODOT_INTAKE_FAIL: " + msg)
    quit(1)

func _check() -> void:
    var preview: Node3D = Preview.new()
    root.add_child(preview)
    for i in range(8):
        await process_frame
    if not bool(preview.get("ready_for_commands")):
        _fail("Real rig failed startup")
        return
    var rig: Node3D = preview.get("rig")
    if rig==null or not bool(rig.get("loading_ok")):
        _fail("Canonical SeraRig not active")
        return
    if rig.get_script().resource_path!="res://scripts/sera_rig.gd":
        _fail("Preview uses a substituted rig")
        return
    var ink: Node = rig.get_node_or_null("ViewEdges")
    if ink==null or ink.get_script().resource_path!="res://scripts/sera_view_edges.gd":
        _fail("Game ViewEdges are not shared")
        return
    var handler: RefCounted = preview.get("handler")
    if handler==null or handler.get_script().resource_path!="res://scripts/sera_equipment.gd":
        _fail("Not the real SeraEquipment handler")
        return
    var head_options: Array = handler.call("options_for","head")
    if not head_options.has("D") or not head_options.has("C"):
        _fail("Current HEAD D/C equipment missing")
        return
    preview.call("_apply_command", {"mode":"body",
        "editing_slot":"head",
        "selected":{"head":"D","torso":"A","arms":"A","legs":"C",
            "booster":"B","weapon_r":"K","weapon_l":"A"},
        "size":1.0, "keep_aspect":false,
        "camera":{"yaw":154.0,"pitch":-16.0,"outlinePx":3.0},
        "seq":12})
    await process_frame
    if str(handler.call("current_for","head"))!="D" or (
            str(handler.call("current_for","legs"))!="C" or
            str(handler.call("current_for","weapon_r"))!="K"):
        _fail("Game equipment selection did not execute")
        return
    var shield: Array = (handler.get("available") as Dictionary).get("A",{}).get("weapon_l",[])
    if shield.is_empty():
        _fail("Regular shield source missing")
        return
    for part in shield:
        if part is MeshInstance3D and part.visible:
            _fail("Two-hand Katana failed to suppress the shield")
            return
    if preview.get("camera")==null:
        _fail("No Godot Camera3D")
        return
    var effects: Dictionary = handler.get("available")
    var source_head: Array = (effects.get("D",{}) as Dictionary).get("head",[])
    if source_head.size()!=6:
        _fail("Canonical camera eye lost its six meshes")
        return
    for piece in source_head:
        if piece is MeshInstance3D and piece.material_override==null:
            _fail("Godot game material missing")
            return
    print("SERA_GODOT_INTAKE_RUNTIME_OK real_rig=true material=game outline=game")
    quit(0)
