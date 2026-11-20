extends SceneTree
## Run: godot --headless --path . --script res://tests/test_labo_hero_scene.gd
## Updated expectations: independent background sets and page-specific motion,
## with the identical canonical CRATE mesh used by the roaming hub robot.
const CrateModel = preload("res://scripts/sera_crate_model.gd")
const HERO = preload("res://scenes/labo_hero_stage.tscn")
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run_checks")

func _verify(ok: bool, label: String) -> void:
    if not ok:
        failures.append(label)
        push_error("LABO visual contract failed: " + label)

func _run_checks() -> void:
    var stage: Node3D = HERO.instantiate() as Node3D
    root.add_child(stage)
    stage.set_process(false)
    var maker: Node3D = stage.get_node_or_null("PrinterScene") as Node3D
    var refinery: Node3D = stage.get_node_or_null("MaterialConversionScene") as Node3D
    var warehouse: Node3D = stage.get_node_or_null("WarehouseScene") as Node3D
    var robot: Node3D = stage.get_node_or_null("CRATE") as Node3D
    var camera: Camera3D = stage.get_node_or_null("HeroCamera") as Camera3D
    _verify(maker != null and refinery != null and warehouse != null,
        "three separately instantiated 3D locations")
    _verify(robot != null and camera != null, "shared robot and scene camera")
    if maker == null or refinery == null or warehouse == null or robot == null or camera == null:
        quit(1)
        return
    _verify(maker.get_node_or_null("PrinterLeftWall") != null,
        "unique industrial printing-hall scenery")
    _verify(refinery.get_node_or_null("RefineryCatwalk") != null,
        "unique refinery background and pipes")
    _verify(warehouse.get_node_or_null("StorageAisleFloor") != null,
        "unique warehouse background and storage aisle")
    _verify(robot.get_node_or_null("HeadPivot") != null
        and robot.get_node_or_null("RightArmPivot") != null
        and robot.get_node_or_null("LeftArmPivot") != null,
        "canonical joint pivot compatibility")
    var sample: Node3D = CrateModel.create_model()
    _verify(robot.get_child_count() == sample.get_child_count(),
        "outdoor and indoor CRATE built from same mesh factory")
    sample.free()
    stage.call("set_section", "LABO")
    _verify(maker.visible and not refinery.visible and not warehouse.visible,
        "manufacturing-only background active")
    var print_pos: Vector3 = camera.position
    var nozzle: Node3D = stage.get_node("PrinterScene/PrinterNozzle") as Node3D
    var nozzle_before: Vector3 = nozzle.position
    stage.call("_process", 0.50)
    _verify(nozzle.position != nozzle_before, "manufacturing-only gantry animation")
    stage.call("set_section", "SMELTER")
    _verify(refinery.visible and not maker.visible and not warehouse.visible,
        "refinery-only background active")
    var refine_pos: Vector3 = camera.position
    var rotor: Node3D = stage.get_node("MaterialConversionScene/CrystalRotor_0") as Node3D
    stage.call("_process", 0.50)
    _verify(absf(rotor.rotation.y) > 0.01, "refinery-only chamber animation")
    stage.call("set_section", "RECYCLER")
    _verify(refinery.visible and not maker.visible and not warehouse.visible,
        "recycler correctly maps to the materials page")
    stage.call("set_section", "STORAGE")
    _verify(warehouse.visible and not refinery.visible and not maker.visible,
        "warehouse-only background active")
    var storage_pos: Vector3 = camera.position
    var scanner: Node3D = stage.get_node("WarehouseScene/TravelingInventoryScanner") as Node3D
    var scan_before: Vector3 = scanner.position
    stage.call("_process", 0.50)
    _verify(scanner.position != scan_before, "warehouse-only scanner animation")
    _verify(print_pos != refine_pos and print_pos != storage_pos
        and refine_pos != storage_pos, "unique camera framing for all three rooms")
    stage.free()
    if failures.is_empty():
        print("PASS: LABO 3D interiors, visual isolation, CRATE and motion")
        quit(0)
    else:
        printerr("FAIL: ", failures.size(), " LABO assertions")
        quit(1)
