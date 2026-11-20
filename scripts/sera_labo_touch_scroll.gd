extends ScrollContainer
## LABO-only touch scrolling for Android's native Button lists.
## The project intentionally disables emulate_mouse_from_touch for battle input.
## Read screen touches before GUI Buttons with MOUSE_FILTER_STOP consume them.
## Keep built-in wheel and scrollbar scrolling unchanged.

const DRAG_DEADZONE: float = 10.0

var _finger_index: int = -1
var _finger_origin: Vector2 = Vector2.ZERO
var _start_scroll: float = 0.0
var _drag_consumed: bool = false


func touch_drag_consumed() -> bool:
    # Stays true through touch release so Button.pressed can discard the swipe.
    # A new touch press or mouse press resets it for the next genuine tap.
    return _drag_consumed


func _input(event: InputEvent) -> void:
    if not is_visible_in_tree():
        _finger_index = -1
        return
    if event is InputEventScreenTouch:
        if event.pressed:
            if _finger_index != -1 or not get_global_rect().has_point(event.position):
                return
            var scrollbar: VScrollBar = get_v_scroll_bar()
            if scrollbar.max_value <= scrollbar.page + 0.5:
                return
            _finger_index = event.index
            _finger_origin = event.position
            _start_scroll = float(scroll_vertical)
            _drag_consumed = false
        elif event.index == _finger_index:
            _finger_index = -1
        return
    if event is InputEventScreenDrag:
        if event.index != _finger_index:
            return
        var travel: Vector2 = event.position - _finger_origin
        if not _drag_consumed:
            if absf(travel.y) < DRAG_DEADZONE or absf(travel.y) <= absf(travel.x):
                return
            _drag_consumed = true
        var scrollbar: VScrollBar = get_v_scroll_bar()
        var maximum: int = maxi(0, floori(scrollbar.max_value - scrollbar.page))
        scroll_vertical = clampi(roundi(_start_scroll - travel.y), 0, maximum)
        get_viewport().set_input_as_handled()
        return
    if event is InputEventMouseButton and event.pressed and (
            event.button_index == MOUSE_BUTTON_LEFT):
        _drag_consumed = false
