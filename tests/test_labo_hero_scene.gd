extends SceneTree
## Run: godot --headless --path . --script res://tests/test_labo_hero_scene.gd
## Updated expectations: object-filled hero framing with deliberate crop,
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
    var printer_rig: Node3D = maker.get_node_or_null("Printer") as Node3D
    _verify(printer_rig != null and absf(printer_rig.rotation.y) > 0.20,
        "printer workcell rotated to make a strong three-quarter composition")
    _verify(printer_rig != null and printer_rig.position.z > 0.10,
        "printer pulled into foreground, clear of the wall")
    _verify(maker.get_node_or_null("PrinterForegroundLoader") != null,
        "printer giant loader overlaps foreground and continues beyond the frame")
    var print_harness: Node3D = maker.get_node_or_null("PrinterHangingHarness") as Node3D
    _verify(print_harness != null,
        "printer mechanical harness exists in the overhead foreground")
    if print_harness != null:
        _verify(_outside_camera_frame(camera,
            print_harness.to_global(Vector3(0, 1.1, 0))),
            "printer harness is intentionally cropped by upper viewport")
    var print_pos: Vector3 = camera.position
    _verify(print_pos.distance_to(Vector3(-2.30, 1.45, 0.28)) < 5.5
        and camera.fov <= 55.0, "printer framed close rather than whole room")
    var print_direction: Vector3 = -camera.global_transform.basis.z
    var nozzle: Node3D = stage.get_node("PrinterScene/PrinterNozzle") as Node3D
    var nozzle_before: Vector3 = nozzle.position
    stage.call("_process", 0.50)
    _verify(nozzle.position != nozzle_before, "manufacturing-only gantry animation")
    stage.call("set_section", "SMELTER")
    _verify(refinery.visible and not maker.visible and not warehouse.visible,
        "refinery-only background active")
    _verify(refinery.get_node_or_null("RefineryForegroundManifold") != null,
        "refinery oversized foreground manifold enters from out of frame")
    var refinery_pipes: Node3D = refinery.get_node_or_null("RefineryHangingPipes") as Node3D
    _verify(refinery_pipes != null,
        "refinery large pipework fills the top of the image")
    if refinery_pipes != null:
        _verify(_outside_camera_frame(camera,
            refinery_pipes.to_global(Vector3(0, 1.30, 0))),
            "refinery pipework deliberately exceeds top frame")
    var refine_pos: Vector3 = camera.position
    _verify(refine_pos.distance_to(Vector3(-2.75, 1.35, 0.10)) < 4.5
        and camera.fov <= 55.0, "refinery tightly crops nearest tank")
    var refine_direction: Vector3 = -camera.global_transform.basis.z
    var vessel_a: Node3D = refinery.get_node_or_null("CrystalRotor_0") as Node3D
    var vessel_c: Node3D = refinery.get_node_or_null("CrystalRotor_2") as Node3D
    _verify(vessel_a != null and vessel_c != null
        and absf(vessel_a.position.z - vessel_c.position.z) > 1.4
        and absf(vessel_a.position.x - vessel_c.position.x) > 2.0,
        "refinery chambers form a diagonal foreground-to-background sequence")
    var rotor: Node3D = stage.get_node("MaterialConversionScene/CrystalRotor_0") as Node3D
    stage.call("_process", 0.50)
    _verify(absf(rotor.rotation.y) > 0.01, "refinery-only chamber animation")
    stage.call("set_section", "RECYCLER")
    _verify(refinery.visible and not maker.visible and not warehouse.visible,
        "recycler correctly maps to the materials page")
    stage.call("set_section", "STORAGE")
    _verify(warehouse.visible and not refinery.visible and not maker.visible,
        "warehouse-only background active")
    var close_tower: Node3D = warehouse.get_node_or_null("WarehouseNearRackExtension") as Node3D
    _verify(close_tower != null,
        "warehouse racks continue beyond frame rather than ending inside it")
    if close_tower != null:
        _verify(_outside_camera_frame(camera,
            close_tower.to_global(Vector3(1.10, 5.30, 0))),
            "oversized near rack extends outside warehouse viewport")
    _verify(warehouse.get_node_or_null("WarehouseForegroundPallets") != null,
        "warehouse loading clutter fills near-camera floor")
    var storage_pos: Vector3 = camera.position
    _verify(storage_pos.distance_to(Vector3(0.20, 1.6, -0.60)) < 5.0
        and camera.fov <= 55.0, "warehouse camera frames tight loaded aisle")
    var storage_direction: Vector3 = -camera.global_transform.basis.z
    var left_rack: Node3D = warehouse.get_node_or_null("RackBay_Left") as Node3D
    var right_rack: Node3D = warehouse.get_node_or_null("RackBay_Right") as Node3D
    _verify(left_rack != null and right_rack != null
        and absf(left_rack.position.z - right_rack.position.z) > 1.3,
        "warehouse rack bays deliberately staggered in depth")
    _verify(left_rack != null and right_rack != null
        and absf(left_rack.rotation.y - right_rack.rotation.y) > 0.2,
        "warehouse rack bays face different three-quarter orientations")
    var scanner: Node3D = stage.get_node("WarehouseScene/TravelingInventoryScanner") as Node3D
    var scan_before: Vector3 = scanner.position
    stage.call("_process", 0.50)
    _verify(scanner.position != scan_before, "warehouse-only scanner animation")
    _verify(print_pos != refine_pos and print_pos != storage_pos
        and refine_pos != storage_pos, "unique camera framing for all three rooms")
    _verify(print_pos.x > 0.5 and refine_pos.x < -0.5
        and storage_pos.y > print_pos.y + 0.7,
        "close low-right print, elevated left refinery, high loaded aisle")
    _verify(print_direction.distance_to(refine_direction) > 0.30
        and refine_direction.distance_to(storage_direction) > 0.30
        and print_direction.distance_to(storage_direction) > 0.22,
        "view directions strongly differ in all three rooms")
    stage.free()
    if failures.is_empty():
        print("PASS: LABO 3D interiors, visual isolation, CRATE and motion")
        quit(0)
    else:
        printerr("FAIL: ", failures.size(), " LABO assertions")
        quit(1)
