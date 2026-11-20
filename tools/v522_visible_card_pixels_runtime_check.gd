extends SceneTree
## Real OpenGL framebuffer test, NOT a headless node-tree assertion.
## CI runs this with xvfb-run, and uploads screenshots for diagnostics.
func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    push_error("SERA_V522_CARD_PIXEL_RENDER_FAIL: " + message)
    quit(1)

func _capture(fac: Node3D, group: String, card_id: String) -> bool:
    await process_frame
    await process_frame
    await RenderingServer.frame_post_draw
    var image: Image = root.get_texture().get_image()
    if image == null or image.is_empty():
        _fail("no actual framebuffer image; CI must use a real software GL display")
        return false
    var dir: String = OS.get_environment("SERA_UI_RENDER_DIR")
    if dir.is_empty():
        dir = "/tmp"
    var saved: Error = image.save_png(dir.path_join("sera_card_" + group + ".png"))
    if saved != OK:
        _fail("failed to capture rendered screenshot of " + group)
        return false
    var actions: VBoxContainer = fac.get("modal_actions") as VBoxContainer
    var card: Button = (fac.get("item_layer") as Control).find_child(card_id, true, false) as Button
    if card == null or not card.is_visible_in_tree():
        _fail("expected native card is absent: " + card_id)
        return false
    var view: Vector2 = root.get_visible_rect().size
    var scale := Vector2(float(image.get_width()) / view.x, float(image.get_height()) / view.y)
    var area := card.get_global_rect()
    var rect := Rect2(area.position * scale, area.size * scale)
    var colored: int = 0
    var samples: int = 0
    var bx: int = maxi(0, int(rect.position.x))
    var by: int = maxi(0, int(rect.position.y))
    var ex: int = mini(image.get_width(), int(rect.end.x))
    var ey: int = mini(image.get_height(), int(rect.end.y))
    if ex <= bx + 30 or ey <= by + 30:
        _fail("native card has no framebuffer-sized rectangle: " + card_id)
        return false
    for y in range(by, ey, 2):
        for x in range(bx, ex, 2):
            samples += 1
            var c: Color = image.get_pixel(x, y)
            if c.g > 0.36 and c.b > 0.47 and c.g > c.r + 0.11 and c.b > c.r + 0.12:
                colored += 1
    print("SERA_V522_PIXEL_REGION " + group + ": card=" + str(rect) +
        " cyan=" + str(colored) + " sample=" + str(samples))
    if colored < 12:
        _fail("item tree exists but its actual card pixels are missing: " + group)
        return false
    return true

func _run() -> void:
    var hub: Node3D = load("res://scenes/base_exploration.tscn").instantiate()
    root.add_child(hub)
    await process_frame
    await process_frame
    var fac: Node3D = hub.get_node("BaseFacilities") as Node3D
    fac.call("_switch_section", "craft")
    if not await _capture(fac, "craft", "PrototypeIcon_H01"):
        return
    fac.call("_switch_section", "materials")
    if not await _capture(fac, "materials", "MaterialIcon_scrap_low"):
        return
    fac.call("_switch_section", "warehouse")
    if not await _capture(fac, "warehouse", "MaterialIcon_scrap_low"):
        return
    print("SERA_V522_CARD_PIXEL_RENDER_PASS: real pixels in LABO, refiner and warehouse")
    quit(0)
