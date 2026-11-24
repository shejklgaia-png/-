extends RefCounted
## BASE infrastructure drawing, world X/Z in metres.
## This is the authored layout, NOT a navigation search. All three systems
## read the same crossing schedule. Changing a facility requires editing it.
const FLOOR_Y: float = 0.115
const DEVICES = {
    "GENERATOR": [Vector2(11.25, -5.25), 180.0],
    "NEXUS": [Vector2(-6.0, -19.5), 0.0],
    "LABO": [Vector2(10.5, 1.5), 0.0],
    "SCRAP_COLLECTOR": [Vector2(7.5, 18.75), 180.0],
    "SMELTER": [Vector2(-15.75, -3.0), 0.0],
    "RECYCLER": [Vector2(3.0, -14.25), 0.0],
    "STORAGE": [Vector2(0.0, 8.25), 0.0],
    "BUILD_TERMINAL": [Vector2(23.5, 12.0), 0.0]
}
# Entries: dock centre, rack direction, truck forward direction.
const DOCKS = {
    "SCRAP_COLLECTOR": [Vector2(13.5, 22.5), Vector2.RIGHT, Vector2.UP],
    "LABO": [Vector2(7.5, 12.0), Vector2.DOWN, Vector2.LEFT],
    "SMELTER": [Vector2(-9.0, -3.75), Vector2.LEFT, Vector2.UP],
    "RECYCLER": [Vector2(-1.5, -10.5), Vector2.DOWN, Vector2.LEFT],
    "STORAGE": [Vector2(-6.75, 3.75), Vector2.LEFT, Vector2.DOWN]
}
const HOMES = [
    Vector2(17.25, 23.25), Vector2(19.5, 23.25),
    Vector2(21.75, 23.25), Vector2(24.0, 23.25),
    Vector2(26.25, 23.25), Vector2(28.5, 23.25)
]
# The cable is straight through each of these points. "wire" is its
# horizontal axis; vehicle motion and the ramp slope axis are perpendicular.
# No automatic rectangle expansion, overlap merging or crossing inference.
const CROSSINGS = [
    {"key":"GRID", "at":Vector2(13.5,-1.0), "wire":Vector2.RIGHT, "radius":0.145, "y":0.15},
    {"key":"NEXUS", "at":Vector2(-5.0,-10.5), "wire":Vector2.DOWN, "radius":0.070, "y":FLOOR_Y},
    {"key":"RECYCLER", "at":Vector2(3.75,-10.5), "wire":Vector2.DOWN, "radius":0.070, "y":FLOOR_Y},
    {"key":"SMELTER", "at":Vector2(-6.75,-1.5), "wire":Vector2.RIGHT, "radius":0.070, "y":FLOOR_Y},
    {"key":"SCRAP_COLLECTOR", "at":Vector2(11.25,12.0), "wire":Vector2.DOWN, "radius":0.070, "y":FLOOR_Y},
    {"key":"SCRAP_COLLECTOR", "at":Vector2(11.25,16.5), "wire":Vector2.DOWN, "radius":0.070, "y":FLOOR_Y},
    {"key":"BUILD_TERMINAL", "at":Vector2(13.5,4.5), "wire":Vector2.RIGHT, "radius":0.070, "y":FLOOR_Y}
]
# Feed cable control vertices. Separate the service branches and keep bends
# away from the straight crossing spans. End gates are the actual sockets.
const FEEDS = {
    "NEXUS": [Vector2(9.6,-7.2),Vector2(5.3,-7.2),Vector2(-5.0,-7.2),Vector2(-5.0,-13.0),Vector2(-6.4,-16.5)],
    "RECYCLER": [Vector2(9.8,-7.8),Vector2(3.75,-7.8),Vector2(3.75,-12.2)],
    "SMELTER": [Vector2(9.8,-8.25),Vector2(-4.75,-8.25),Vector2(-4.75,-1.5),Vector2(-15.8,-1.5)],
    "STORAGE": [Vector2(9.8,-8.8),Vector2(1.5,-8.8),Vector2(1.5,7.4),Vector2(1.2,9.65)],
    "LABO": [Vector2(12.15,-7.65),Vector2(12.15,2.9)],
    "SCRAP_COLLECTOR": [Vector2(12.55,-8.15),Vector2(12.55,5.75),Vector2(11.25,10.0),Vector2(11.25,18.1),Vector2(8.45,18.1)],
    "BUILD_TERMINAL": [Vector2(12.0,-9.0),Vector2(12.0,4.5),Vector2(16.0,4.5),Vector2(23.5,9.0),Vector2(24.5,13.4)]
}
const DELIVERIES = {
    "NEXUS": [Vector2(-6.7,-17.5),Vector2(-7.5,-18.2)],
    "RECYCLER": [Vector2(4.35,-13.0),Vector2(4.35,-15.5)],
    "SMELTER": [Vector2(-14.2,-1.9),Vector2(-14.1,-3.4)],
    "STORAGE": [Vector2(-0.9,9.4),Vector2(-1.5,8.3)],
    "LABO": [],
    "SCRAP_COLLECTOR": [Vector2(6.4,17.6),Vector2(6.3,19.2),Vector2(8.1,19.2)],
    "BUILD_TERMINAL": []
}


static func device_pose(key: String) -> Dictionary:
    var spec: Array = DEVICES[key]
    var p: Vector2 = spec[0]
    return {"at":Vector3(p.x,0.0,p.y), "yaw":deg_to_rad(float(spec[1]))}


static func crossing_centers(key: String) -> Array[Vector2]:
    var result: Array[Vector2] = []
    for crossing in CROSSINGS:
        if crossing["key"] == key:
            result.append(crossing["at"])
    return result


static func _append(result: Array[Vector2], p: Vector2) -> void:
    if result.is_empty() or result[-1].distance_squared_to(p) > 0.000001:
        result.append(p)


static func _line(result: Array[Vector2], end: Vector2, sway: float, locks: Array[Vector2]) -> void:
    var start: Vector2 = result[-1]
    var delta: Vector2 = end - start
    var length: float = delta.length()
    if length < 0.001:
        return
    if sway <= 0.0:
        _append(result, end)
        return
    var amplitude: float = minf(sway, length * 0.045) if length > 2.5 else 0.0
    for p in locks:
        if Geometry2D.get_closest_point_to_segment(p, start, end).distance_to(p) < 0.03:
            amplitude = 0.0
            break
    var normal := Vector2(-delta.y, delta.x).normalized()
    var steps: int = maxi(1, ceili(length / 0.24))
    for i in range(1, steps + 1):
        var t: float = float(i) / float(steps)
        var envelope: float = sin(PI * t)
        _append(result, start.lerp(end,t) + normal * amplitude * sin(TAU*t) * envelope * envelope)


static func curve(points: Array, radius: float, sway: float = 0.0, locks: Array[Vector2] = []) -> Array[Vector2]:
    var clean: Array[Vector2] = []
    for value in points:
        var p: Vector2 = value
        _append(clean,p)
    if clean.size() < 2:
        return clean
    var result: Array[Vector2] = [clean[0]]
    for i in range(1, clean.size()-1):
        var prev: Vector2 = clean[i-1]
        var p: Vector2 = clean[i]
        var next: Vector2 = clean[i+1]
        var incoming: Vector2 = (p-prev).normalized()
        var outgoing: Vector2 = (next-p).normalized()
        if incoming.dot(outgoing) > 0.998 or incoming.dot(outgoing) < -0.98:
            _line(result,p,sway,locks)
            continue
        var cut: float = minf(radius,minf(p.distance_to(prev),p.distance_to(next))*0.34)
        var entry: Vector2 = p-incoming*cut
        var exit: Vector2 = p+outgoing*cut
        _line(result,entry,sway,locks)
        var count: int = maxi(5,ceili(cut*2.0/0.16))
        for j in range(1,count+1):
            var t: float = float(j)/float(count)
            _append(result,entry.lerp(p,t).lerp(p.lerp(exit,t),t))
    _line(result,clean[-1],sway,locks)
    return result


static func road_legs(destination: String, index: int) -> Array:
    var home: Vector2 = HOMES[index]
    var source: Vector2 = DOCKS["SCRAP_COLLECTOR"][0]
    var target: Vector2 = DOCKS[destination][0]
    var warehouse: Vector2 = DOCKS["STORAGE"][0]
    var approach: Array = [home,Vector2(home.x,26.25),Vector2(13.5,26.25),source]
    var loaded: Array = [source]
    var finished: Array = [target]
    match destination:
        "LABO":
            loaded.append(Vector2(13.5,12.0))
            finished.append(Vector2(-6.75,12.0))
        "RECYCLER":
            loaded.append(Vector2(13.5,-10.5))
            finished.append(Vector2(-6.75,-10.5))
        "SMELTER":
            loaded.append_array([Vector2(13.5,-10.5),Vector2(-6.75,-10.5),Vector2(-6.75,-3.75)])
            finished.append(Vector2(-6.75,-3.75))
    loaded.append(target)
    finished.append(warehouse)
    var empty: Array = [warehouse,Vector2(-6.75,16.5),Vector2(15.75,16.5),
        Vector2(15.75,20.25),Vector2(home.x,20.25),home]
    return [curve(approach,0.90),curve(loaded,0.90),curve(finished,0.90),curve(empty,0.90)]


static func _cubic(a: Vector3,b: Vector3,c: Vector3,d: Vector3,t: float) -> Vector3:
    var u: float = 1.0-t
    return a*u*u*u + b*3.0*u*u*t + c*3.0*u*t*t + d*t*t*t


static func board_point(t: float) -> Vector3:
    # Four fixed pieces; the second is strictly horizontal under GRID ramp.
    var start := Vector3(10.05,0.23,-2.2)
    var entry := Vector3(12.0,0.15,-1.0)
    var exit := Vector3(15.0,0.15,-1.0)
    var bend := Vector3(22.0,0.20,-10.0)
    var finish := Vector3(29.24,0.29,-20.0)
    if t <= 0.25:
        return _cubic(start,Vector3(10.8,0.23,-2.2),Vector3(11.3,0.15,-1.0),entry,t*4.0)
    if t <= 0.50:
        return entry.lerp(exit,(t-0.25)*4.0)
    if t <= 0.75:
        return _cubic(exit,Vector3(17.0,0.15,-1.0),Vector3(18.8,0.20,-7.0),bend,(t-0.5)*4.0)
    return _cubic(bend,Vector3(25.2,0.20,-13.0),Vector3(26.0,0.29,-20.0),finish,(t-0.75)*4.0)
