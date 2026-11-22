extends RefCounted
## Runtime inspection of canonical Blockbench free meshes.
## Correct winding across connected closed shells, rather than guessing from
## face-center vs. a global centroid (which breaks concave IRIS/HEAD C parts).
## Opaque source geometry stays unmodified; only generated triangles change.

const POSITION_PRECISION: float = 10000.0
const MIN_VOLUME: float = 0.000001

static func _v3(raw: Variant) -> Vector3:
    if raw is Array and raw.size() >= 3:
        return Vector3(float(raw[0]), float(raw[1]), float(raw[2]))
    return Vector3.ZERO

static func _position_key(raw: Variant) -> String:
    var p: Vector3 = _v3(raw)
    return "%d:%d:%d" % [
        roundi(p.x * POSITION_PRECISION),
        roundi(p.y * POSITION_PRECISION),
        roundi(p.z * POSITION_PRECISION)]

static func inspect_element(element: Dictionary) -> Dictionary:
    var vertex_map: Dictionary = element.get("vertices", {})
    var face_map: Dictionary = element.get("faces", {})
    var ids: Array = face_map.keys()
    var surface_edges: Dictionary = {}
    var adjacent: Array = []
    adjacent.resize(ids.size())
    var rejected_faces: int = 0
    for idx in range(ids.size()):
        adjacent[idx] = []
        var face: Dictionary = face_map[ids[idx]]
        var verts: Array = face.get("vertices", [])
        if verts.size() < 3:
            rejected_faces += 1
            continue
        var valid := true
        for key in verts:
            if not vertex_map.has(key):
                valid = false
                break
        if not valid:
            rejected_faces += 1
            continue
        # Don't trust Blockbench vertex IDs: UV-split vertices can occupy
        # the same position. Connect faces using quantized coordinates.
        for j in range(verts.size()):
            var start: String = _position_key(vertex_map[verts[j]])
            var finish: String = _position_key(vertex_map[verts[(j + 1) % verts.size()]])
            if start == finish:
                rejected_faces += 1
                continue
            var key: String = start + "|" + finish if start < finish else finish + "|" + start
            var refs: Array = surface_edges.get(key, [])
            refs.append({"face": idx, "forward": start < finish})
            surface_edges[key] = refs

    var boundary_count: int = 0
    var nonmanifold_count: int = 0
    var winding_conflict: bool = false
    for refs_value in surface_edges.values():
        var refs: Array = refs_value
        if refs.size() == 1:
            boundary_count += 1
        elif refs.size() != 2:
            nonmanifold_count += 1
        else:
            var left: Dictionary = refs[0]
            var right: Dictionary = refs[1]
            var l: int = int(left["face"])
            var r: int = int(right["face"])
            # A correctly oriented shared edge has opposite directions.
            var same_direction: bool = bool(left["forward"]) == bool(right["forward"])
            (adjacent[l] as Array).append([r, same_direction])
            (adjacent[r] as Array).append([l, same_direction])

    # Build connected face components and solve parity constraints by BFS.
    var flips: Dictionary = {}
    var components: Array = []
    for start_idx in range(ids.size()):
        if flips.has(start_idx):
            continue
        var queue: Array[int] = [start_idx]
        var head: int = 0
        var group: Array = []
        flips[start_idx] = false
        while head < queue.size():
            var idx: int = queue[head]
            head += 1
            group.append(idx)
            for link in (adjacent[idx] as Array):
                var neighbor: int = int(link[0])
                var want_flip: bool = bool(flips[idx]) != bool(link[1])
                if flips.has(neighbor):
                    if bool(flips[neighbor]) != want_flip:
                        winding_conflict = true
                else:
                    flips[neighbor] = want_flip
                    queue.append(neighbor)
        components.append(group)

    var signed_volume: float = 0.0
    var component_volumes: Array[float] = []
    for group in components:
        var component_volume: float = 0.0
        for face_index in group:
            var f: Dictionary = face_map[ids[int(face_index)]]
            var vk: Array = f.get("vertices", [])
            if vk.size() < 3:
                continue
            var p0: Vector3 = _v3(vertex_map[vk[0]])
            for j in range(1, vk.size() - 1):
                var p1: Vector3 = _v3(vertex_map[vk[j]])
                var p2: Vector3 = _v3(vertex_map[vk[j + 1]])
                var contribution: float = p0.dot(p1.cross(p2)) / 6.0
                component_volume += -contribution if bool(flips[int(face_index)]) else contribution
        component_volumes.append(component_volume)
        signed_volume += absf(component_volume)

    var safe_closed: bool = (
        rejected_faces == 0 and boundary_count == 0 and
        nonmanifold_count == 0 and not winding_conflict and
        not components.is_empty())
    for vol in component_volumes:
        if absf(float(vol)) <= MIN_VOLUME:
            safe_closed = false

    var reverse_faces: Dictionary = {}
    if safe_closed:
        # Closed shell orientation must produce positive signed volume.
        # Correct negative-volume components as a WHOLE, preserving seams.
        for k in range(components.size()):
            var global_reverse: bool = component_volumes[k] < 0.0
            for fi in components[k]:
                if bool(flips[int(fi)]) != global_reverse:
                    reverse_faces[ids[int(fi)]] = true

    return {
        "cull_back": safe_closed,
        "reverse_faces": reverse_faces,
        "boundary_count": boundary_count,
        "nonmanifold_count": nonmanifold_count,
        "winding_conflict": winding_conflict,
        "rejected_faces": rejected_faces,
        "signed_volume": signed_volume,
        "face_count": ids.size(),
    }
