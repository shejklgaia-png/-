extends SceneTree
## LABO reference composition regression test, 480x240 landscape crop.
## Source: user's Scene A / B / C upper-row artwork.
## Run: godot --headless --path . --script res://tests/test_labo_hero_scene.gd
## Update composition criteria before implementing visual changes.
const CrateModel = preload("res://scripts/sera_crate_model.gd")
const HeroScene = preload("res://scenes/labo_hero_stage.tscn")
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_check")

func _expect(ok: bool, reason: String) -> void:
    if not ok:
        failures.append(reason)
        push_error("LABO reference composition: " + reason)

func _project(camera: Camera3D, point: Vector3) -> Vector2:
    var pixel: Vector2 = camera.unproject_position(point)
    var extent: Vector2 = camera.get_viewport().get_visible_rect().size
    return Vector2(pixel.x / extent.x, pixel.y / extent.y)

func _visible(camera: Camera3D, point: Vector3) -> bool:
    if camera.is_position_behind(point):
        return false
    var p: Vector2 = _project(camera, point)
    return p.x > 0.03 and p.x < 0.97 and p.y > 0.08 and p.y < 0.95

func _check() -> void:
    var viewport := SubViewport.new()
    viewport.size = Vector2i(480, 240)
    viewport.own_world_3d = true
    viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    root.add_child(viewport)
    var stage: Node3D = HeroScene.instantiate() as Node3D
    viewport.add_child(stage)
    stage.set_process(false)
    var camera: Camera3D = stage.get_node_or_null("HeroCamera") as Camera3D
    var robot: Node3D = stage.get_node_or_null("CRATE") as Node3D
    var maker: Node3D = stage.get_node_or_null("PrinterScene") as Node3D
    var refinery: Node3D = stage.get_node_or_null("MaterialConversionScene") as Node3D
    var store: Node3D = stage.get_node_or_null("WarehouseScene") as Node3D
    _expect(camera != null and robot != null, "3D preview camera and CRATE present")
    _expect(maker != null and refinery != null and store != null, "3 independent stage roots")
    if camera == null or robot == null or maker == null or refinery == null or store == null:
        quit(1)
        return
    var crate_copy: Node3D = CrateModel.create_model()
    _expect(crate_copy.get_child_count() == robot.get_child_count(),
        "same CRATE 3D mesh factory as the base")
    crate_copy.free()

    # Reference A: large 3D printer on left; CRATE at right-middle,
    # diagnostic terminal right; no giant foreground loader or steep angle.
    stage.call("set_section", "LABO")
    var printer: Node3D = maker.get_node_or_null("Printer") as Node3D
    var terminal: Node3D = maker.get_node_or_null("PrinterInspectionStation") as Node3D
    _expect(printer != null and terminal != null, "A: printer and console roots")
    if printer != null and terminal != null:
        var printer_point: Vector2 = _project(camera,
            printer.to_global(Vector3(0, 1.55, 0)))
        var console_point: Vector2 = _project(camera,
            terminal.to_global(Vector3(0, 1.55, 0)))
        var crate_point: Vector2 = _project(camera, robot.to_global(Vector3(0, 0.65, 0)))
        _expect(printer_point.x < 0.47 and printer_point.x > 0.12,
            "A: printer clearly occupies left side")
        _expect(crate_point.x > printer_point.x + 0.24 and crate_point.x < 0.88,
            "A: CRATE fully visible on right side of printer")
        _expect(console_point.x > crate_point.x,
            "A: terminal placed on far right beyond CRATE")
        _expect(_visible(camera, printer.to_global(Vector3(0, 2.8, 0))),
            "A: large printer upper frame remains visible")
    _expect(not maker.has_node("PrinterForegroundLoader")
        and not maker.has_node("PrinterHangingHarness"),
        "A: remove oversized foreground obstruction")
    var nozzle: Node3D = maker.get_node_or_null("PrinterNozzle") as Node3D
    var nozzle_before: Vector3 = nozzle.position
    stage.call("_process", 0.5)
    _expect(nozzle.position != nozzle_before, "A: print motion preserved")

    # Reference B: orange/blue/purple tall tanks left-center in that order;
    # feedstock trays foreground; CRATE on right, wall monitor far right.
    stage.call("set_section", "SMELTER")
    var last_x: float = -1.0
    for index in range(3):
        var tank: Node3D = refinery.get_node_or_null(
            "RefineryVessel_%d" % index) as Node3D
        _expect(tank != null, "B: colored tank %d exists" % index)
        if tank != null:
            var tank_center: Vector2 = _project(camera,
                tank.to_global(Vector3(0, 1.5, 0)))
            _expect(tank_center.x > last_x and tank_center.x < 0.76,
                "B: three colored tanks ordered left to right")
            _expect(_visible(camera, tank.to_global(Vector3(0, 2.65, 0))),
                "B: vessel cap is fully visible")
            last_x = tank_center.x
    _expect(refinery.has_node("RefineryFeedstockTrays"),
        "B: several sorted mineral trays in the foreground")
    _expect(refinery.has_node("RefineryRecycleSign"),
        "B: illuminated recycling sign on far right wall")
    _expect(_project(camera, robot.to_global(Vector3(0, 0.65, 0))).x > last_x,
        "B: CRATE located right of vats")
    stage.call("_process", 0.5)
    _expect(stage.get_node("MaterialConversionScene/CrystalRotor_0").rotation.y > 0.01,
        "B: raw material processing animation preserved")
    stage.call("set_section", "RECYCLER")
    _expect(refinery.visible, "B: recycler uses same refining page")

    # Reference C: left H01/H02/A01 racks, right B01/B02/A02 racks,
    # central CRATE and angled monitor. Eye-level aisle, not bird's-eye view.
    stage.call("set_section", "STORAGE")
    var left: Node3D = store.get_node_or_null("RackBay_Left") as Node3D
    var right: Node3D = store.get_node_or_null("RackBay_Right") as Node3D
    var monitor: Node3D = store.get_node_or_null("WarehouseInventoryMonitor") as Node3D
    _expect(left != null and right != null and monitor != null,
        "C: two loaded racks and the central warehouse inventory monitor")
    if left != null and right != null:
        var left_p: Vector2 = _project(camera, left.to_global(Vector3(0, 1.7, 0)))
        var right_p: Vector2 = _project(camera, right.to_global(Vector3(0, 1.7, 0)))
        var crate_p: Vector2 = _project(camera, robot.to_global(Vector3(0, 0.65, 0)))
        _expect(left_p.x < crate_p.x and crate_p.x < right_p.x,
            "C: CRATE stands between left and right rack banks")
        _expect(left_p.x > 0.05 and right_p.x < 0.95,
            "C: both storage rack banks recognizable")
    _expect(store.has_node("WarehouseLeftStockLabels")
        and store.has_node("WarehouseRightStockLabels"),
        "C: H01/H02/A01 and B01/B02/A02 labels")
    _expect(camera.position.y < 2.5,
        "C: camera stays near eye level, without steep downward tilt")
    _expect(maker.visible == false and refinery.visible == false and store.visible,
        "C: only storage environment visible")
    viewport.queue_free()
    if failures.is_empty():
        print("PASS LABO reference A/B/C composition")
        quit(0)
    else:
        printerr("FAIL LABO reference layout: ", failures.size())
        quit(1)
