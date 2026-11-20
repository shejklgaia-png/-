extends SceneTree
## Reproduces the Android LABO failure: Button STOP consumes GUI drag,
## while an input-level touch drag must still scroll the parent.
const TouchScroll = preload("res://scripts/sera_labo_touch_scroll.gd")

func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    push_error("SERA_V537_LABO_TOUCH_SCROLL_FAIL: " + message)
    quit(1)

func _touch(index: int, pressed: bool, position: Vector2) -> InputEventScreenTouch:
    var event := InputEventScreenTouch.new()
    event.index = index
    event.pressed = pressed
    event.position = position
    return event

func _drag(index: int, position: Vector2, relative: Vector2) -> InputEventScreenDrag:
    var event := InputEventScreenDrag.new()
    event.index = index
    event.position = position
    event.relative = relative
    return event

func _run() -> void:
    var parent := Control.new()
    parent.size = Vector2(400, 400)
    root.add_child(parent)
    var scroll: ScrollContainer = TouchScroll.new()
    scroll.position = Vector2(20, 20)
    scroll.size = Vector2(320, 190)
    parent.add_child(scroll)
    var column := VBoxContainer.new()
    column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.add_child(column)
    for index in range(20):
        var button := Button.new()
        button.text = "Card %d" % index
        button.custom_minimum_size.y = 52
        button.mouse_filter = Control.MOUSE_FILTER_STOP
        column.add_child(button)
    await process_frame
    await process_frame
    if scroll.get_v_scroll_bar().max_value <= scroll.get_v_scroll_bar().page:
        _fail("fixture content does not overflow")
        return
    var point: Vector2 = scroll.get_global_rect().position + Vector2(100, 120)
    scroll.call("_input", _touch(0, true, point))
    scroll.call("_input", _drag(0, point + Vector2(0, -5), Vector2(0, -5)))
    if scroll.scroll_vertical != 0:
        _fail("a tap-sized gesture moved the list")
        return
    scroll.call("_input", _drag(0, point + Vector2(0, -95), Vector2(0, -90)))
    if scroll.scroll_vertical < 70:
        _fail("upward finger drag did not scroll down the card list")
        return
    var after_drag: int = scroll.scroll_vertical
    scroll.call("_input", _touch(0, false, point + Vector2(0, -95)))
    if not scroll.call("touch_drag_consumed"):
        _fail("released drag could activate a card")
        return
    scroll.call("_input", _touch(0, true, point))
    if scroll.call("touch_drag_consumed"):
        _fail("new tap remained blocked after previous drag")
        return
    scroll.call("_input", _touch(0, false, point))
    scroll.call("_input", _touch(1, true, point))
    scroll.call("_input", _drag(1, point + Vector2(0, 60), Vector2(0, 60)))
    if scroll.scroll_vertical >= after_drag:
        _fail("downward finger drag did not scroll up")
        return
    scroll.call("_input", _touch(1, false, point + Vector2(0, 60)))
    var after_down_drag: int = scroll.scroll_vertical
    scroll.call("set_touch_scroll_enabled", false)
    scroll.call("_input", _touch(2, true, point))
    scroll.call("_input", _drag(2, point + Vector2(0, -80), Vector2(0, -80)))
    if scroll.scroll_vertical != after_down_drag:
        _fail("covered background list scrolled through a confirmation dialog")
        return
    scroll.call("_input", _touch(2, false, point + Vector2(0, -80)))
    scroll.call("set_touch_scroll_enabled", true)
    print("SERA_V537_LABO_TOUCH_SCROLL_RUNTIME_PASS")
    quit(0)
