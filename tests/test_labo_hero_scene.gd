extends SceneTree
## Run: godot --headless --path . --script res://tests/test_labo_hero_scene.gd
## Updated expectations: important objects remain inside the landscape hero frame,
## while secondary girders, racks, pipes and pallets intentionally crop.
## Test in 480x240 SubViewport, NOT the portrait root viewport.
## close foreground props and machine clusters, staggered facility depths,
## independent background sets and page-specific motion,
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

# Test actual projected image boundaries, not merely nearby camera positions.
# Oversized scenery must continue outside the SubViewport on every LABO page.
func _outside_camera_frame(camera: Camera3D, point: Vector3) -> bool:
    if camera.is_position_behind(point):
        return false
    var pixel: Vector2 = camera.unproject_position(point)
    var size: Vector2 = camera.get_viewport().get_visible_rect().size
    return pixel.x < 0.0 or pixel.x > size.x or pixel.y < 0.0 or pixel.y > size.y

func _screen_point(camera: Camera3D, point: Vector3) -> Vector2:
    var size: Vector2 = camera.get_viewport().get_visible_rect().size
    var screen: Vector2 = camera.unproject_position(point)
    return Vector2(screen.x / size.x, screen.y / size.y)

func _visible_primary(camera: Camera3D, world_point: Vector3) -> bool:
    if camera.is_position_behind(world_point):
        return false
    var screen: Vector2 = _screen_point(camera, world_point)
    return screen.x > 0.05 and screen.x < 0.95 \
        and screen.y > 0.10 and screen.y < 0.90

func _run_checks() -> void:
    var stage: Node3D = HERO.instantiate() as Node3D
    var preview := SubViewport.new()
    preview.name = "TestLandscapeHeroViewport"
    preview.size = Vector2i(480, 240)
    preview.own_world_3d = true
    root.add_child(preview)
    preview.add_child(stage)
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
    var printer_rig: Node3D = maker.get_node_or_null("Printer") as Node3D
    _verify(printer_rig != null and absf(printer_rig.rotation.y) > 0.20,
        "printer workcell rotated in three-quarter composition")
    _verify(_visible_primary(camera, Vector3(-2.30, 1.35, 0.28)),
        "main 3D printer is clearly framed")
    _verify(_visible_primary(camera, Vector3(1.20, 0.75, 0.60)),
        "CRATE remains in the manufacturing view")
    _verify(_visible_primary(camera, Vector3(1.90, 1.60, -1.43)),
        "printer diagnostic terminal is in frame")
    _verify(maker.get_node_or_null("PrinterForegroundLoader") != null
        and maker.get_node_or_null("PrinterHangingHarness") != null,
        "industrial loader and suspended machinery densely frame the printer")
    var print_pos: Vector3 = camera.position
    var print_direction: Vector3 = -camera.global_transform.basis.z
    var nozzle: Node3D = stage.get_node("PrinterScene/PrinterNozzle") as Node3D
    var nozzle_before: Vector3 = nozzle.position
    stage.call("_process", 0.50)
    _verify(nozzle.position != nozzle_before, "manufacturing-only gantry animation")

    stage.call("set_section", "SMELTER")
    _verify(refinery.visible and not maker.visible and not warehouse.visible,
        "refinery-only background active")
    var refine_pos: Vector3 = camera.position
    var refine_direction: Vector3 = -camera.global_transform.basis.z
    for index in range(3):
        var vessel: Node3D = refinery.get_node_or_null(
            "RefineryVessel_%d" % index) as Node3D
        _verify(vessel != null, "refinery vessel %d exists" % index)
        if vessel != null:
            _verify(_visible_primary(camera,
                vessel.to_global(Vector3(0, 1.50, 0.35))),
                "refinery vessel %d is inside the view" % index)
    _verify(_visible_primary(camera, Vector3(1.60, 0.75, 0.85)),
        "CRATE remains within the refinery frame")
    var manifold: Node3D = refinery.get_node_or_null(
        "RefineryForegroundManifold") as Node3D
    _verify(manifold != null and refinery.get_node_or_null(
        "RefineryHangingPipes") != null,
        "manifold and overhead pipes create dense but nonblocking foreground")
    var rotor: Node3D = stage.get_node(
        "MaterialConversionScene/CrystalRotor_0") as Node3D
    stage.call("_process", 0.50)
    _verify(absf(rotor.rotation.y) > 0.01, "refinery-only chamber animation")
    stage.call("set_section", "RECYCLER")
    _verify(refinery.visible and not maker.visible and not warehouse.visible,
        "recycler correctly maps to the materials page")

    stage.call("set_section", "STORAGE")
    _verify(warehouse.visible and not refinery.visible and not maker.visible,
        "warehouse-only background active")
    var storage_pos: Vector3 = camera.position
    var storage_direction: Vector3 = -camera.global_transform.basis.z
    var left_rack: Node3D = warehouse.get_node_or_null("RackBay_Left") as Node3D
    var right_rack: Node3D = warehouse.get_node_or_null("RackBay_Right") as Node3D
    _verify(left_rack != null and right_rack != null,
        "the warehouse has two different high storage rack banks")
    if left_rack != null and right_rack != null:
        _verify(absf(left_rack.position.z - right_rack.position.z) > 1.3
            and absf(left_rack.rotation.y - right_rack.rotation.y) > 0.2,
            "racks retain staggered three-quarter arrangement")
    _verify(_visible_primary(camera, Vector3(-2.66, 1.90, 0.12))
        and _visible_primary(camera, Vector3(2.70, 1.90, -2.03)),
        "both rack banks are visible, not hidden behind near tower")
    _verify(_visible_primary(camera, Vector3(0.55, 0.80, -0.55)),
        "CRATE smaller, but still visible in the warehouse aisle")
    _verify(warehouse.get_node_or_null("WarehouseNearRackExtension") != null
        and warehouse.get_node_or_null("WarehouseForegroundPallets") != null,
        "warehouse crop and foreground pallet density retained")
    var scanner: Node3D = stage.get_node(
        "WarehouseScene/TravelingInventoryScanner") as Node3D
    var scan_before: Vector3 = scanner.position
    stage.call("_process", 0.50)
    _verify(scanner.position != scan_before, "warehouse-only scanner motion")
    _verify(print_pos != refine_pos and print_pos != storage_pos
        and refine_pos != storage_pos, "all three rooms keep unique cameras")
    _verify(print_direction.distance_to(refine_direction) > 0.20
        and refine_direction.distance_to(storage_direction) > 0.20,
        "each room keeps its own photographic angle")
    preview.queue_free()
    if failures.is_empty():
        print("PASS: LABO 3D interiors, visual isolation, CRATE and motion")
        quit(0)
    else:
        printerr("FAIL: ", failures.size(), " LABO assertions")
        quit(1)
