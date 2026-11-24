extends Node
## APK sandbox -> local Termux receiver. Only placement previews, never saves.
## Read the committed file, not live drag data; asynchronous and no frame polling.
const PATH := "user://.sera-placement/preview.json"
const ENDPOINT := "http://127.0.0.1:18743/sera-placement/v1"
var request: HTTPRequest
var timer: Timer
var acknowledged := ""
var in_flight := ""
var sync_status := "not_started"

func _ready() -> void:
    if not OS.has_feature("android") or OS.has_feature("editor"):
        return
    request = HTTPRequest.new()
    request.timeout = 5.0
    add_child(request)
    request.request_completed.connect(_completed)
    timer = Timer.new()
    timer.wait_time = 5.0
    add_child(timer)
    timer.timeout.connect(_check)
    timer.start()
    _check()

func _check() -> void:
    if not in_flight.is_empty() or not FileAccess.file_exists(PATH):
        return
    var file := FileAccess.open(PATH, FileAccess.READ)
    if file == null:
        return
    var body := file.get_as_text()
    file.close()
    if body.is_empty() or body == acknowledged:
        return
    var data: Variant = JSON.parse_string(body)
    if not (data is Dictionary) or data.get("schema") != 1 or not (data.get("records") is Dictionary) or data["records"].is_empty():
        return
    in_flight = body
    var err := request.request(ENDPOINT, PackedStringArray(["Content-Type: application/json"]), HTTPClient.METHOD_POST, body)
    if err != OK:
        _retry()
    else:
        sync_status = "sending"

func _retry() -> void:
    in_flight = ""
    if sync_status != "waiting_for_termux":
        print("SERA placement: waiting for local Termux receiver; saved data retained")
    sync_status = "waiting_for_termux"
    timer.start(30.0)

func _completed(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
    if result == HTTPRequest.RESULT_SUCCESS and code == 200:
        acknowledged = in_flight
        in_flight = ""
        sync_status = "received_by_termux"
        print("SERA placement: local receiver accepted preview; GitHub sync is separate")
        timer.start(5.0)
    else:
        _retry()
