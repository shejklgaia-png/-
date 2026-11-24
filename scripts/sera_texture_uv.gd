extends RefCounted
## Metric planar charts; all distances are measured after instance scaling.
const MAX_TRIANGLES = 12000
const PADDING = 2

static func build(source: MeshInstance3D, density: int) -> Dictionary:
    var tris: Array[Dictionary] = []
    var charts: Array[Dictionary] = []
    var scale_basis: Basis = source.global_transform.basis if source.is_inside_tree() else source.transform.basis
    var metric := Vector3(scale_basis.x.length(), scale_basis.y.length(), scale_basis.z.length())
    if source.mesh == null or source.skin != null:
        return {"error": "静的メッシュを選択してください"}
    var authored_by_surface: Dictionary = source.get_meta("texture_studio_authored_by_surface",{})
    for s in range(source.mesh.get_surface_count()):
        if source.mesh is ArrayMesh and (source.mesh as ArrayMesh).surface_get_primitive_type(s) != Mesh.PRIMITIVE_TRIANGLES:
            continue
        var arr: Array = source.mesh.surface_get_arrays(s)
        var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
        var ns: PackedVector3Array = arr[Mesh.ARRAY_NORMAL] if arr[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
        var old_uv: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV] if arr[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
        var vertex_colors: PackedColorArray = arr[Mesh.ARRAY_COLOR] if arr[Mesh.ARRAY_COLOR] != null else PackedColorArray()
        var ids: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
        var count: int = ids.size() if not ids.is_empty() else vs.size()
        var face_ids: PackedInt32Array = authored_by_surface.get(s,PackedInt32Array())
        var active: Material = source.get_active_material(s)
        var mat: StandardMaterial3D = active as StandardMaterial3D
        var encoded_culling: bool = false
        if active is ShaderMaterial:
            var shader_mat: ShaderMaterial = active as ShaderMaterial
            if shader_mat.shader != null and shader_mat.shader.resource_path == "res://shaders/sera_texture_studio_preview.gdshader":
                mat = StandardMaterial3D.new()
                mat.albedo_texture = shader_mat.get_shader_parameter("source_texture") as Texture2D
                mat.texture_repeat = false
                encoded_culling = true
        if active != null and mat == null:
            return {"error": "特殊マテリアルは未対応です"}
        var base := Color.WHITE if mat == null else mat.albedo_color
        var tex: Image = null
        if mat != null and mat.albedo_texture != null:
            tex = mat.albedo_texture.get_image()
            if tex != null and tex.is_compressed() and tex.decompress() != OK:
                tex = null
        for i in range(0, count - 2, 3):
            if tris.size() >= MAX_TRIANGLES:
                return {"error": "三角形数の上限を超えています"}
            var ix := PackedInt32Array([i, i+1, i+2]) if ids.is_empty() else PackedInt32Array([ids[i], ids[i+1], ids[i+2]])
            var p := PackedVector3Array([vs[ix[0]]*metric, vs[ix[1]]*metric, vs[ix[2]]*metric])
            var cross := (p[1]-p[0]).cross(p[2]-p[0])
            if cross.length_squared() < 0.000000000001:
                continue
            var n := cross.normalized()
            var normals := PackedVector3Array()
            var prior := PackedVector2Array()
            var colors := PackedColorArray()
            for k in range(3):
                var nn := -n
                if ns.size() == vs.size():
                    nn = (ns[ix[k]] / metric.max(Vector3(0.00001,0.00001,0.00001))).normalized()
                normals.append(nn)
                prior.append(old_uv[ix[k]] if old_uv.size() == vs.size() else Vector2.ZERO)
                colors.append(vertex_colors[ix[k]] if mat != null and mat.vertex_color_use_as_albedo and vertex_colors.size() == vs.size() else Color.WHITE)
            var cull: int = BaseMaterial3D.CULL_DISABLED if mat == null else mat.cull_mode
            if encoded_culling and vertex_colors.size() == vs.size():
                cull = _decode_cull(vertex_colors[ix[0]])
            var face_id: int = face_ids[i/3] if face_ids.size()*3 == count else -1
            tris.append({"p":p,"n":normals,"face_normal":n,"surface":s,"authored_face":face_id,"base":base,"tex":tex,"prior":prior,"colors":colors,"repeat":mat == null or mat.texture_repeat,"cull":cull})
    if tris.is_empty():
        return {"error":"描画可能な三角形がありません"}
    charts = _edge_aligned_charts(tris,density)
    charts = _split_overlapping_charts(tris,charts)
    _match_rectified_edge_counts(tris,charts)
    _align_triangular_grids(tris,charts)
    _synchronize_chart_grids(tris,charts)
    var order: Array[int] = []
    for i in range(charts.size()):
        var c: Dictionary = charts[i]
        c.size = Vector2i(ceili(c.max.x-c.min.x),ceili(c.max.y-c.min.y))+Vector2i.ONE*(2*PADDING+2)
        order.append(i)
    order.sort_custom(func(a: int,b: int) -> bool: return charts[a].size.y > charts[b].size.y)
    var side := 64
    var fits := false
    while side <= 1024:
        var x := 0
        var y := 0
        var row := 0
        fits = true
        for id in order:
            var c: Dictionary = charts[id]
            var sz: Vector2i = c.size
            if x+sz.x > side:
                x = 0
                y += row
                row = 0
            if sz.x > side or y+sz.y > side:
                fits = false
                break
            c.at = Vector2(x+PADDING,y+PADDING)
            x += sz.x
            row = maxi(row,sz.y)
        if fits:
            break
        side *= 2
    if not fits:
        return {"error":"1024pxに収まりません。密度を下げてください"}
    var img := Image.create(side,side,false,Image.FORMAT_RGBA8)
    img.fill(Color.TRANSPARENT)
    # A texel can be sampled by a real surface even if its centre is
    # outside the triangle. Keep the nearest source point per texel;
    # interior coverage always wins over fringe coverage.
    var distances := PackedFloat32Array()
    distances.resize(side*side)
    distances.fill(INF)
    var vertices := PackedVector3Array()
    var normals_out := PackedVector3Array()
    var uvs := PackedVector2Array()
    var flags := PackedColorArray()
    var diagnostic_uv := PackedVector2Array()
    assign_diagnostic_faces(tris)
    for t in tris:
        var c: Dictionary = charts[t.chart]
        var uv := PackedVector2Array()
        for k in range(3):
            var q: Vector2 = t.xy[k]-c.min+c.at
            uv.append(q/float(side))
            vertices.append(t.p[k])
            normals_out.append(t.n[k])
            uvs.append(uv[k])
            flags.append(_encode_cull(int(t.cull)))
            diagnostic_uv.append(Vector2(1.0 if bool(c.get("rectified",false)) else 0.5,float(int(t.diagnostic_face)+1)))
        t.uv = uv
        _bake_triangle(img,t,distances)
    var arrays: Array = []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = vertices
    arrays[Mesh.ARRAY_NORMAL] = normals_out
    arrays[Mesh.ARRAY_TEX_UV] = uvs
    arrays[Mesh.ARRAY_COLOR] = flags
    arrays[Mesh.ARRAY_TEX_UV2] = diagnostic_uv
    var out := ArrayMesh.new()
    out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
    return {"mesh":out,"image":img,"triangles":tris,"charts":charts.size()}

## Group connected coplanar triangles, and the two halves of slightly
## warped authored quads. Never use an internal triangulation diagonal
## as the pixel-grid reference. All axes stay fixed in model space.
static func _vertex_key(p: Vector3) -> String:
    return "%d,%d,%d" % [roundi(p.x*100000.0),roundi(p.y*100000.0),roundi(p.z*100000.0)]

static func _edge_key(a: Vector3,b: Vector3) -> String:
    var ka: String = _vertex_key(a)
    var kb: String = _vertex_key(b)
    return ka+"|"+kb if ka < kb else kb+"|"+ka

static func _root(parent: PackedInt32Array,i: int) -> int:
    while parent[i] != i:
        i = parent[i]
    return i

static func _join(parent: PackedInt32Array,a: int,b: int) -> void:
    var ra: int = _root(parent,a)
    var rb: int = _root(parent,b)
    if ra != rb:
        parent[maxi(ra,rb)] = mini(ra,rb)

static func _authored_flat(t: Dictionary) -> bool:
    var ns: PackedVector3Array = t.n
    return ns[0].dot(ns[1]) > 0.9999 and ns[0].dot(ns[2]) > 0.9999

static func _shared_uv(a: Dictionary,b: Dictionary,edge_a: int,edge_b: int) -> bool:
    var pa: PackedVector3Array = a.p
    var pb: PackedVector3Array = b.p
    var ua: PackedVector2Array = a.prior
    var ub: PackedVector2Array = b.prior
    var next_a: int = (edge_a+1)%3
    var next_b: int = (edge_b+1)%3
    if _vertex_key(pa[edge_a]) == _vertex_key(pb[edge_b]):
        return ua[edge_a].distance_squared_to(ub[edge_b]) < 0.00000001 and ua[next_a].distance_squared_to(ub[next_b]) < 0.00000001
    return ua[edge_a].distance_squared_to(ub[next_b]) < 0.00000001 and ua[next_a].distance_squared_to(ub[edge_b]) < 0.00000001

static func _can_join(a: Dictionary,b: Dictionary,edge_a: int,edge_b: int) -> bool:
    var na: Vector3 = a.face_normal
    var nb: Vector3 = b.face_normal
    var dot: float = na.dot(nb)
    var fa: int = int(a.get("authored_face",-1))
    var fb: int = int(b.get("authored_face",-1))
    # Authored faces define the grid domain, not accidental coplanarity.
    # Keep every original quad intact even when its neighbor is coplanar.
    if fa >= 0 and fb >= 0:
        return int(a.surface) == int(b.surface) and fa == fb and dot > 0.5
    if dot > 0.999999:
        var pa: PackedVector3Array = a.p
        var pb: PackedVector3Array = b.p
        if absf(na.dot(pb[0]-pa[0])) < 0.00001:
            # Adjacent coplanar faces may belong to different original
            # MeshInstances/materials (e.g. the two Iris forehead halves).
            # Only join opposite sides of the common edge; coincident
            # stacked faces must not acquire overlapping UVs.
            var edge: Vector3 = (pa[(edge_a+1)%3]-pa[edge_a]).normalized()
            var side_a: float = edge.cross(pa[(edge_a+2)%3]-pa[edge_a]).dot(na)
            var side_b: float = edge.cross(pb[(edge_b+2)%3]-pa[edge_a]).dot(na)
            if side_a*side_b < 0.0:
                return true
    if int(a.surface) != int(b.surface):
        return false
    # SeraRig gives both triangles of an authored quad the same flat
    # normal. A UV-continuous shared edge identifies the original polygon.
    # Limit the permitted bend so real creases remain separate islands.
    if dot < 0.9781476 or not _authored_flat(a) or not _authored_flat(b):
        return false
    var an: PackedVector3Array = a.n
    var bn: PackedVector3Array = b.n
    return an[0].dot(bn[0]) > 0.9999 and _shared_uv(a,b,edge_a,edge_b)

static func _edge_aligned_charts(tris: Array[Dictionary],density: int) -> Array[Dictionary]:
    var parent := PackedInt32Array()
    parent.resize(tris.size())
    var edges: Dictionary = {}
    for i in range(tris.size()):
        parent[i] = i
        var t: Dictionary = tris[i]
        var p: PackedVector3Array = t.p
        for e in range(3):
            var key: String = _edge_key(p[e],p[(e+1)%3])
            if not edges.has(key):
                edges[key] = []
            var incidents: Array = edges[key]
            for item in incidents:
                var other: int = int(item.x)
                if _can_join(t,tris[other],e,int(item.y)):
                    _join(parent,i,other)
            incidents.append(Vector2i(i,e))
    var groups: Dictionary = {}
    for i in range(tris.size()):
        var root: int = _root(parent,i)
        if not groups.has(root):
            groups[root] = []
        (groups[root] as Array).append(i)
    var charts: Array[Dictionary] = []
    for root in groups:
        var members: Array = groups[root]
        var normal := Vector3.ZERO
        var outline: Dictionary = {}
        for id in members:
            var t: Dictionary = tris[id]
            var p: PackedVector3Array = t.p
            normal += (p[1]-p[0]).cross(p[2]-p[0])
            for e in range(3):
                var a: Vector3 = p[e]
                var b: Vector3 = p[(e+1)%3]
                var key: String = _edge_key(a,b)
                if outline.has(key):
                    var existing: Dictionary = outline[key]
                    existing.count = int(existing.count)+1
                else:
                    outline[key] = {"a":a,"b":b,"count":1}
        if normal.length_squared() < 0.000000000001:
            normal = tris[members[0]].face_normal
        normal = normal.normalized()
        # Up is projected into the plane. For a nearly horizontal plane,
        # model forward is the stable fallback (never the camera angle).
        var up: Vector3 = Vector3.UP-normal*normal.dot(Vector3.UP)
        if up.length_squared() < 0.04:
            up = Vector3.FORWARD-normal*normal.dot(Vector3.FORWARD)
        up = up.normalized()
        var u: Vector3 = up.cross(normal).normalized()
        var v: Vector3 = normal.cross(u).normalized()
        var low: float = INF
        var high: float = -INF
        var longest: float = 0.0
        for item in outline.values():
            if int(item.count) != 1:
                continue
            var a: Vector3 = item.a
            var b: Vector3 = item.b
            low = minf(low,minf(a.dot(up),b.dot(up)))
            high = maxf(high,maxf(a.dot(up),b.dot(up)))
            var edge: Vector3 = b-a
            edge -= normal*edge.dot(normal)
            longest = maxf(longest,edge.length())
        # Where one straight lower edge is split by a mesh boundary,
        # score the full collinear run rather than separate short segments.
        var perimeter: Array[Dictionary] = []
        for item in outline.values():
            if int(item.count) == 1:
                perimeter.append(item)
        var merged: bool = true
        while merged:
            merged = false
            for i in range(perimeter.size()):
                if merged:
                    break
                for j in range(i+1,perimeter.size()):
                    var first: Dictionary = perimeter[i]
                    var second: Dictionary = perimeter[j]
                    var common := Vector3.ZERO
                    var outer_a := Vector3.ZERO
                    var outer_b := Vector3.ZERO
                    var connected: bool = false
                    for endpoint_a in ["a","b"]:
                        for endpoint_b in ["a","b"]:
                            var point_a: Vector3 = first[endpoint_a]
                            var point_b: Vector3 = second[endpoint_b]
                            if _vertex_key(point_a) == _vertex_key(point_b):
                                common = point_a
                                outer_a = first["b" if endpoint_a == "a" else "a"]
                                outer_b = second["b" if endpoint_b == "a" else "a"]
                                connected = true
                    if not connected:
                        continue
                    var da: Vector3 = (outer_a-common).normalized()
                    var db: Vector3 = (outer_b-common).normalized()
                    if da.dot(db) > -0.99999:
                        continue
                    perimeter[i] = {"a":outer_a,"b":outer_b,"count":1}
                    perimeter.remove_at(j)
                    merged = true
                    break
        for item in perimeter:
            var a: Vector3 = item.a
            var b: Vector3 = item.b
            var edge: Vector3 = b-a
            edge -= normal*edge.dot(normal)
            longest = maxf(longest,edge.length())
        var best: float = -INF
        var anchor: Vector3 = Vector3.ZERO
        var aligned_edge: bool = false
        for item in perimeter:
            var a: Vector3 = item.a
            var b: Vector3 = item.b
            var edge: Vector3 = b-a
            edge -= normal*edge.dot(normal)
            var length: float = edge.length()
            if length < maxf(0.000001,longest*0.12):
                continue
            var direction: Vector3 = edge/length
            var horizontal: float = absf(direction.dot(u))
            # Prefer the lowest substantial non-vertical perimeter edge.
            # Midpoint height wins over longest-edge-only or diagonal rules.
            if horizontal < 0.25:
                continue
            var height: float = clampf(((a+b)*0.5).dot(up)-low,0.0,maxf(0.0,high-low))/maxf(0.000001,high-low)
            var score: float = (1.0-height)*3.0+horizontal*0.75+length/maxf(longest,0.000001)*0.65
            if score > best:
                best = score
                # Keep the grid handedness and up direction consistent.
                var aligned: Vector3 = direction if direction.dot(u) >= 0.0 else -direction
                v = normal.cross(aligned).normalized()
                anchor = a if direction.dot(u) >= 0.0 else b
                aligned_edge = true
                # Save selected horizontal axis separately: scoring must
                # always use the original model-space horizontal reference.
        u = v.cross(normal).normalized()
        var ci: int = charts.size()
        var chart: Dictionary = {"u":u,"v":v,"min":Vector2(INF,INF),"max":Vector2(-INF,-INF)}
        for id in members:
            var t: Dictionary = tris[id]
            var p: PackedVector3Array = t.p
            var xy := PackedVector2Array()
            for point in p:
                var relative: Vector3 = point-anchor
                var q := Vector2(relative.dot(u),relative.dot(v))*density
                xy.append(q)
                var minimum: Vector2 = chart.min
                var maximum: Vector2 = chart.max
                chart.min = minimum.min(q)
                chart.max = maximum.max(q)
            t.xy = xy
            t.chart = ci
        if aligned_edge:
            # Keep the chosen baseline on an integer texel boundary. The
            # bounding box may extend below it on a trapezoid or irregular face.
            var minimum: Vector2 = chart.min
            chart.min = minimum.floor()
        _rectify_quad(tris,members,perimeter,chart,anchor,u,v,density)
        charts.append(chart)
    return charts

## Reconstruct convex four-corner boundaries, including collinear
## subdivided sides. Keep the mesh itself unchanged. Accept a rectangular
## pixel grid only if every projected triangle keeps its orientation and
## its local length/area distortion stays inside the limits.
static func _rectify_quad(tris: Array[Dictionary], members: Array, perimeter: Array[Dictionary], chart: Dictionary, anchor: Vector3, u: Vector3, v: Vector3, density: int) -> void:
    if perimeter.size() != 4:
        return
    var unique: Dictionary = {}
    for edge in perimeter:
        for endpoint in ["a","b"]:
            var p: Vector3 = edge[endpoint]
            var relative: Vector3 = p-anchor
            unique[_vertex_key(p)] = Vector2(relative.dot(u),relative.dot(v))*density
    if unique.size() != 4:
        return
    var corners: Array[Vector2] = []
    var mid := Vector2.ZERO
    for point in unique.values():
        corners.append(point)
        mid += point
    mid /= 4.0
    corners.sort_custom(func(a: Vector2,b: Vector2) -> bool: return (a-mid).angle() < (b-mid).angle())
    for i in range(4):
        var edge_a: Vector2 = corners[(i+1)%4]-corners[i]
        var edge_b: Vector2 = corners[(i+2)%4]-corners[(i+1)%4]
        if edge_a.cross(edge_b) <= 0.00001:
            return
    # Bottom edge should point in the chart's positive U direction.
    var bottom: int = -1
    var best: float = INF
    for i in range(4):
        var direction: Vector2 = corners[(i+1)%4]-corners[i]
        if direction.x <= 0.000001:
            continue
        # Prefer the bottom-facing edge, but do not reject tilted quads
        # just because their lowest edge is not almost horizontal.
        var score: float = (corners[i].y+corners[(i+1)%4].y)*0.5 + absf(direction.y)*0.25
        if score < best:
            bottom = i
            best = score
    if bottom < 0:
        return
    var q0: Vector2 = corners[bottom]
    var q1: Vector2 = corners[(bottom+1)%4]
    var q2: Vector2 = corners[(bottom+2)%4]
    var q3: Vector2 = corners[(bottom+3)%4]
    var width: float = maxf(1.0,roundf((q0.distance_to(q1)+q2.distance_to(q3))*0.5))
    var height: float = maxf(1.0,roundf((q0.distance_to(q3)+q1.distance_to(q2))*0.5))
    var proposed: Array[PackedVector2Array] = []
    var local_corners: Array[Vector2] = [q0,q1,q2,q3]
    var grid_corners: Array[Vector2] = [Vector2.ZERO,Vector2(width,0),Vector2(width,height),Vector2(0,height)]
    var short_face: bool = minf(width,height) <= 4.0
    for id in members:
        var t: Dictionary = tris[id]
        var old: PackedVector2Array = t.xy
        var mapped := PackedVector2Array()
        for point in old:
            var corner_index: int = -1
            for k in range(4):
                if point.distance_squared_to(local_corners[k]) <= 0.00000001:
                    corner_index = k
                    break
            if corner_index >= 0:
                mapped.append(grid_corners[corner_index])
            else:
                var st: Vector2 = _quad_coordinates(point,q0,q1,q2,q3)
                if st.x < -0.001 or st.x > 1.001 or st.y < -0.001 or st.y > 1.001:
                    return
                mapped.append(st.clamp(Vector2.ZERO,Vector2.ONE)*Vector2(width,height))
        var old_area: float = (old[1]-old[0]).cross(old[2]-old[0])
        var new_area: float = (mapped[1]-mapped[0]).cross(mapped[2]-mapped[0])
        if absf(old_area) < 0.000001:
            return
        var area_ratio: float = new_area/old_area
        if area_ratio < (0.20 if short_face else 0.35) or area_ratio > (3.0 if short_face else 2.3):
            return
        for k in range(3):
            var ratio: float = mapped[k].distance_to(mapped[(k+1)%3])/maxf(0.000001,old[k].distance_to(old[(k+1)%3]))
            if ratio < (0.35 if short_face else 0.50) or ratio > (2.5 if short_face else 1.75):
                return
        proposed.append(mapped)
    for i in range(members.size()):
        var t: Dictionary = tris[members[i]]
        t.xy = proposed[i]
    chart.min = Vector2.ZERO
    chart.max = Vector2(width,height)
    chart.rectified = true

static func _quad_coordinates(p: Vector2,a: Vector2,b: Vector2,c: Vector2,d: Vector2) -> Vector2:
    # Invert the bilinear quad map; corners and all points along any
    # original boundary retain their fractional position on that side.
    var e: Vector2 = b-a
    var f: Vector2 = d-a
    var g: Vector2 = a-b+c-d
    var st := Vector2(0.5,0.5)
    for i in range(10):
        var residual: Vector2 = a+e*st.x+f*st.y+g*st.x*st.y-p
        if residual.length_squared() < 0.00000001:
            break
        var ds: Vector2 = e+g*st.y
        var dt: Vector2 = f+g*st.x
        var det: float = ds.cross(dt)
        if absf(det) < 0.00000001:
            return Vector2(-100,-100)
        st -= Vector2(residual.cross(dt),ds.cross(residual))/det
    return st

## Positive-area triangle overlap in the same chart is not allowed.
## Shared boundaries are legal. A bounded sweep prevents pathological
## meshes from freezing the mobile editor; ambiguous charts split safely.
static func _overlaps(a: PackedVector2Array,b: PackedVector2Array) -> bool:
    for shape in [a,b]:
        for e in range(3):
            var edge: Vector2 = shape[(e+1)%3]-shape[e]
            if edge.length_squared() < 0.00000001:
                continue
            var axis: Vector2 = Vector2(-edge.y,edge.x).normalized()
            var lo_a: float = INF
            var hi_a: float = -INF
            var lo_b: float = INF
            var hi_b: float = -INF
            for k in range(3):
                lo_a = minf(lo_a,a[k].dot(axis))
                hi_a = maxf(hi_a,a[k].dot(axis))
                lo_b = minf(lo_b,b[k].dot(axis))
                hi_b = maxf(hi_b,b[k].dot(axis))
            if minf(hi_a,hi_b)-maxf(lo_a,lo_b) <= 0.0001:
                return false
    return true

static func _split_overlapping_charts(tris: Array[Dictionary],charts: Array[Dictionary]) -> Array[Dictionary]:
    var members: Array = []
    for i in range(charts.size()):
        members.append([])
    for i in range(tris.size()):
        var t: Dictionary = tris[i]
        var xy: PackedVector2Array = t.xy
        var lo: Vector2 = xy[0].min(xy[1]).min(xy[2])
        var hi: Vector2 = xy[0].max(xy[1]).max(xy[2])
        (members[int(t.chart)] as Array).append({"id":i,"lo":lo,"hi":hi})
    var output: Array[Dictionary] = []
    for ci in range(charts.size()):
        var entries: Array = members[ci]
        entries.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.lo.x < b.lo.x)
        var invalid: bool = false
        var comparisons: int = 0
        for i in range(entries.size()):
            if invalid:
                break
            var a: Dictionary = entries[i]
            for j in range(i+1,entries.size()):
                var b: Dictionary = entries[j]
                if b.lo.x >= a.hi.x-0.0001:
                    break
                comparisons += 1
                if comparisons > 100000:
                    invalid = true
                    break
                if minf(a.hi.y,b.hi.y)-maxf(a.lo.y,b.lo.y) <= 0.0001:
                    continue
                if _overlaps(tris[a.id].xy,tris[b.id].xy):
                    invalid = true
                    break
        if not invalid:
            for entry in entries:
                tris[entry.id].chart = output.size()
            output.append(charts[ci])
            continue
        for entry in entries:
            var t: Dictionary = tris[entry.id]
            t.chart = output.size()
            var lo: Vector2 = entry.lo
            output.append({"min":lo.floor(),"max":entry.hi})
    return output

## Return compatible seam segments from actual mesh boundaries. Exact
## two-sided edges first; subdivided edges sharing an endpoint can also
## match their overlapping interval. Ambiguous/non-manifold exact edges
## are excluded, and no seam links are made to parallel stacked faces.
static func _seam_segments(tris: Array, include_same_chart: bool = false) -> Array[Dictionary]:
    var edges: Dictionary = {}
    var result: Array[Dictionary] = []
    for i in range(tris.size()):
        var t: Dictionary = tris[i]
        var p: PackedVector3Array = t.p
        for e in range(3):
            var key: String = _edge_key(p[e],p[(e+1)%3])
            if not edges.has(key):
                edges[key] = []
            (edges[key] as Array).append(Vector2i(i,e))
    var endpoints: Dictionary = {}
    for group in edges.values():
        if group.size() == 2:
            var link: Dictionary = _make_seam(tris,group[0],group[1],include_same_chart)
            if not link.is_empty():
                result.append(link)
        elif group.size() == 1:
            var edge: Vector2i = group[0]
            var points: PackedVector3Array = tris[edge.x].p
            for k in [edge.y,(edge.y+1)%3]:
                var key: String = _vertex_key(points[k])
                if not endpoints.has(key):
                    endpoints[key] = []
                (endpoints[key] as Array).append(edge)
    var used: Dictionary = {}
    for group in endpoints.values():
        # Cap pathological fans. Normal authored mesh junctions are small.
        if group.size() > 24:
            continue
        for i in range(group.size()):
            for j in range(i+1,group.size()):
                var a: Vector2i = group[i]
                var b: Vector2i = group[j]
                var key: String = str(a)+":"+str(b) if a.x < b.x else str(b)+":"+str(a)
                if used.has(key):
                    continue
                used[key] = true
                var link: Dictionary = _make_seam(tris,a,b,include_same_chart)
                if not link.is_empty():
                    result.append(link)
    return result

static func _make_seam(tris: Array,ia: Vector2i,ib: Vector2i,include_same_chart: bool = false) -> Dictionary:
    var a: Dictionary = tris[ia.x]
    var b: Dictionary = tris[ib.x]
    if int(a.chart) == int(b.chart) and not include_same_chart:
        return {}
    var pa: PackedVector3Array = a.p
    var pb: PackedVector3Array = b.p
    var a0: Vector3 = pa[ia.y]
    var a1: Vector3 = pa[(ia.y+1)%3]
    var b0: Vector3 = pb[ib.y]
    var b1: Vector3 = pb[(ib.y+1)%3]
    var da: Vector3 = a1-a0
    var db: Vector3 = b1-b0
    var la: float = da.length()
    var lb: float = db.length()
    if minf(la,lb) < 0.00001 or da.dot(db)/(la*lb) > -0.9999:
        return {}
    var axis: Vector3 = da/la
    var offset: Vector3 = b0-a0
    if (offset-axis*offset.dot(axis)).length() > 0.00002:
        return {}
    var lo: float = maxf(0.0,(b1-a0).dot(axis))
    var hi: float = minf(la,(b0-a0).dot(axis))
    if hi-lo < 0.00002:
        return {}
    var na: Vector3 = (pa[1]-pa[0]).cross(pa[2]-pa[0]).normalized()
    var nb: Vector3 = (pb[1]-pb[0]).cross(pb[2]-pb[0]).normalized()
    if na.dot(nb) < -0.5:
        return {}
    if na.dot(nb) > 0.9999:
        var side_a: float = axis.cross(pa[(ia.y+2)%3]-a0).dot(na)
        var side_b: float = axis.cross(pb[(ib.y+2)%3]-a0).dot(na)
        if side_a*side_b >= 0.0:
            return {}
    return {"ta":ia.x,"tb":ib.x,"ea":ia.y,"eb":ib.y,"a":int(a.chart),"b":int(b.chart),
        "a0":lo/la,"a1":hi/la,"b0":clampf((a0+axis*lo-b0).dot(db)/(lb*lb),0,1),
        "b1":clampf((a0+axis*hi-b0).dot(db)/(lb*lb),0,1),"weight":hi-lo}

static func _segment_uv(t: Dictionary, edge: int, start: float, finish: float, field: String) -> PackedVector2Array:
    var coords: PackedVector2Array = t[field]
    var a: Vector2 = coords[edge]
    var b: Vector2 = coords[(edge+1)%3]
    return PackedVector2Array([a.lerp(b,start),a.lerp(b,finish)])

## A rectangular face has two independent integer edge counts. Connect
## equal physical edges in the same constraint group (including opposite
## sides of each rectangle), then choose one count for the entire group.
## Reject excessive stretching instead of sacrificing the original shape.
static func _match_rectified_edge_counts(tris: Array[Dictionary],charts: Array[Dictionary]) -> void:
    var parent := PackedInt32Array()
    parent.resize(charts.size()*2)
    var lower := PackedInt32Array()
    var upper := PackedInt32Array()
    var totals := PackedFloat32Array()
    var counts := PackedInt32Array()
    lower.resize(parent.size())
    upper.resize(parent.size())
    totals.resize(parent.size())
    counts.resize(parent.size())
    for i in range(parent.size()):
        parent[i] = i
        var chart: Dictionary = charts[i/2]
        if bool(chart.get("rectified",false)):
            var size: Vector2 = chart.max
            var old: float = size[i%2]
            # A one-pixel rounding tolerance is essential for 1–4px faces.
            lower[i] = maxi(1,ceili(minf(old*0.75,old-1.0)))
            upper[i] = maxi(lower[i],floori(maxf(old*1.33,old+1.0)))
            totals[i] = old
            counts[i] = 1
    var constraints: Array[Dictionary] = []
    for link in _seam_segments(tris):
        var ca: int = int(link.a)
        var cb: int = int(link.b)
        if not bool(charts[ca].get("rectified",false)) or not bool(charts[cb].get("rectified",false)):
            continue
        if absf(float(link.a1)-float(link.a0)) < 0.9999 or absf(float(link.b1)-float(link.b0)) < 0.9999:
            continue
        var a: PackedVector2Array = _segment_uv(tris[link.ta],link.ea,link.a0,link.a1,"xy")
        var b: PackedVector2Array = _segment_uv(tris[link.tb],link.eb,link.b0,link.b1,"xy")
        var da: Vector2 = (a[1]-a[0]).abs()
        var db: Vector2 = (b[1]-b[0]).abs()
        if minf(da.x,da.y) > 0.001 or minf(db.x,db.y) > 0.001:
            continue
        var axis_a: int = 0 if da.x > da.y else 1
        var axis_b: int = 0 if db.x > db.y else 1
        var size_a: Vector2 = charts[ca].max
        var size_b: Vector2 = charts[cb].max
        if absf(da[axis_a]-size_a[axis_a]) > 0.001 or absf(db[axis_b]-size_b[axis_b]) > 0.001:
            continue
        constraints.append({"a":ca*2+axis_a,"b":cb*2+axis_b,"weight":float(link.weight)})
    constraints.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:
        if not is_equal_approx(float(a.weight),float(b.weight)):
            return float(a.weight) > float(b.weight)
        if int(a.a) != int(b.a):
            return int(a.a) < int(b.a)
        return int(a.b) < int(b.b))
    # Merge only feasible groups, never discard all of a good component
    # just because a later edge introduces an incompatible dimension.
    for pair in constraints:
        var ra: int = _root(parent,int(pair.a))
        var rb: int = _root(parent,int(pair.b))
        if ra == rb:
            continue
        var lo: int = maxi(lower[ra],lower[rb])
        var hi: int = mini(upper[ra],upper[rb])
        if lo > hi:
            continue
        var sum_value: float = totals[ra]+totals[rb]
        var sum_count: int = counts[ra]+counts[rb]
        _join(parent,ra,rb)
        var root: int = _root(parent,ra)
        lower[root] = lo
        upper[root] = hi
        totals[root] = sum_value
        counts[root] = sum_count
    var scales := PackedVector2Array()
    scales.resize(charts.size())
    for i in range(charts.size()):
        scales[i] = Vector2.ONE
        if not bool(charts[i].get("rectified",false)):
            continue
        var old: Vector2 = charts[i].max
        var target: Vector2 = old
        for axis in range(2):
            var root: int = _root(parent,i*2+axis)
            target[axis] = float(clampi(roundi(totals[root]/maxi(1,counts[root])),lower[root],upper[root]))
        scales[i] = target/old.max(Vector2.ONE)
        charts[i].max = target
    for t in tris:
        var coords: PackedVector2Array = t.xy
        var scale: Vector2 = scales[int(t.chart)]
        for k in range(coords.size()):
            coords[k] *= scale
        t.xy = coords

## A triangular face cannot have all three edges axis-aligned. Fit its
## longest adjacent rectified edge exactly; if a second rectified edge
## meets it at a corner, try both integer axes and retain a valid fit.
static func _align_triangular_grids(tris: Array[Dictionary],charts: Array[Dictionary]) -> void:
    var members: Array = []
    var targets: Array = []
    for i in range(charts.size()):
        members.append([])
        targets.append([])
    for i in range(tris.size()):
        (members[int(tris[i].chart)] as Array).append(i)
    for link in _seam_segments(tris):
        if absf(float(link.a1)-float(link.a0)) < 0.9999 or absf(float(link.b1)-float(link.b0)) < 0.9999:
            continue
        var ca: int = int(link.a)
        var cb: int = int(link.b)
        var a_rect: bool = bool(charts[ca].get("rectified",false))
        var b_rect: bool = bool(charts[cb].get("rectified",false))
        if a_rect == b_rect:
            continue
        var ci: int = cb if a_rect else ca
        if members[ci].size() != 1:
            continue
        var rect_index: int = int(link.ta) if a_rect else int(link.tb)
        var rect_edge: int = int(link.ea) if a_rect else int(link.eb)
        var tri_edge: int = int(link.eb) if a_rect else int(link.ea)
        var uv: PackedVector2Array = tris[rect_index].xy
        var d: Vector2 = (uv[(rect_edge+1)%3]-uv[rect_edge]).abs()
        if minf(d.x,d.y) > 0.001:
            continue
        var length: float = maxf(d.x,d.y)
        if length >= 1.0:
            (targets[ci] as Array).append({"edge":tri_edge,"length":length})
    for ci in range(charts.size()):
        if members[ci].size() != 1 or targets[ci].is_empty():
            continue
        var t: Dictionary = tris[members[ci][0]]
        var old: PackedVector2Array = t.xy
        var old_area: float = (old[1]-old[0]).cross(old[2]-old[0])
        if absf(old_area) < 0.000001:
            continue
        var best: PackedVector2Array = PackedVector2Array()
        var best_score: float = -INF
        for target in targets[ci]:
            var e: int = int(target.edge)
            var n: int = (e+1)%3
            var k: int = (e+2)%3
            var d: Vector2 = old[n]-old[e]
            if d.length() < 0.000001:
                continue
            var direction: Vector2 = Vector2.RIGHT if absf(d.x) >= absf(d.y) else Vector2.DOWN
            if direction.dot(d) < 0:
                direction = -direction
            var base: Vector2 = direction*float(target.length)
            var third: Vector2 = (old[k]-old[e]).rotated(d.angle_to(base))*base.length()/d.length()
            var candidates: Array[Vector2] = [third.round()]
            for other in targets[ci]:
                var oe: int = int(other.edge)
                if oe == e:
                    continue
                var origin: Vector2 = Vector2.ZERO if oe == k else base
                var perpendicular: Vector2 = direction.orthogonal()*signf(old_area)
                if perpendicular.dot(third-origin) < 0:
                    perpendicular = -perpendicular
                candidates.append(origin+perpendicular*float(other.length))
            for q in candidates:
                var mapped := PackedVector2Array([Vector2.ZERO,Vector2.ZERO,Vector2.ZERO])
                mapped[e] = Vector2.ZERO
                mapped[n] = base
                mapped[k] = q
                var area: float = (mapped[1]-mapped[0]).cross(mapped[2]-mapped[0])/old_area
                if area < 0.25 or area > 3.0:
                    continue
                var distortion: float = 0.0
                var valid: bool = true
                for j in range(3):
                    var ratio: float = mapped[j].distance_to(mapped[(j+1)%3])/maxf(0.000001,old[j].distance_to(old[(j+1)%3]))
                    if ratio < 0.35 or ratio > 2.5:
                        valid = false
                        break
                    distortion += absf(log(ratio))
                if not valid:
                    continue
                var matched: float = 0.0
                for other in targets[ci]:
                    var j: int = int(other.edge)
                    var v: Vector2 = (mapped[j]-mapped[(j+1)%3]).abs()
                    if minf(v.x,v.y) < 0.001 and absf(maxf(v.x,v.y)-float(other.length)) < 0.001:
                        matched += float(other.length)
                var score: float = matched*4.0-distortion
                if score > best_score:
                    best_score = score
                    best = mapped
        if best.is_empty():
            continue
        var lo: Vector2 = best[0].min(best[1]).min(best[2])
        var hi: Vector2 = best[0].max(best[1]).max(best[2])
        t.xy = best
        charts[ci].min = lo.floor()
        charts[ci].max = hi
        charts[ci].grid_fixed = true

## Global phase relaxation includes non-tree links. Preserve the
## face-aligned axes rather than rotating a rectangle away from its edges.
## For incompatible rotations/edge lengths, brush seam correspondence
## handles the residual instead of forcing heavily distorted charts.
static func _synchronize_chart_grids(tris: Array[Dictionary],charts: Array[Dictionary]) -> void:
    var links: Array[Dictionary] = _seam_segments(tris)
    var adjacency: Array = []
    var phase := PackedVector2Array()
    phase.resize(charts.size())
    for i in range(charts.size()):
        adjacency.append([])
    for link in links:
        var a: PackedVector2Array = _segment_uv(tris[link.ta],link.ea,link.a0,link.a1,"xy")
        var b: PackedVector2Array = _segment_uv(tris[link.tb],link.eb,link.b0,link.b1,"xy")
        var da: Vector2 = a[1]-a[0]
        var db: Vector2 = b[1]-b[0]
        if minf(da.length(),db.length()) < 0.00001:
            continue
        var angle: float = db.angle_to(da)
        var quarter: float = roundf(angle/(PI*0.5))*(PI*0.5)
        if absf(angle-quarter) > deg_to_rad(12.0):
            continue
        link.rotation = quarter
        link.delta = (a[0]+a[1])*0.5-((b[0]+b[1])*0.5).rotated(quarter)
        link.weight = maxf(0.1,minf(da.length(),db.length()))
        (adjacency[link.a] as Array).append(link)
        (adjacency[link.b] as Array).append(link)
    # Circular residuals account for the integer-periodic texel grid.
    # Retain a weak zero-phase preference (stronger for rectified quads).
    for pass_index in range(20):
        var next: PackedVector2Array = phase.duplicate()
        for i in range(charts.size()):
            var total := Vector2.ZERO
            if bool(charts[i].get("rectified",false)) or bool(charts[i].get("grid_fixed",false)):
                # Its integer boundaries already lie on integer grid lines.
                # A fractional phase shift would move every boundary off-grid.
                next[i] = Vector2.ZERO
                continue
            var weight: float = 0.5
            var current: Vector2 = phase[i]
            total -= (current-current.round())*weight
            for link in adjacency[i]:
                var target: Vector2
                var delta: Vector2 = link.delta
                if int(link.a) == i:
                    target = phase[int(link.b)].rotated(float(link.rotation))-delta
                else:
                    target = (phase[int(link.a)]+delta).rotated(-float(link.rotation))
                var diff: Vector2 = target-current
                diff -= diff.round()
                total += diff*float(link.weight)
                weight += float(link.weight)
            next[i] = current+total/maxf(weight,0.001)*0.5
            next[i] -= next[i].round()
        phase = next
    for i in range(charts.size()):
        var chart: Dictionary = charts[i]
        var lo: Vector2 = chart.min
        var hi: Vector2 = chart.max
        chart.min = (lo+phase[i]).floor()
        chart.max = hi+phase[i]
    for t in tris:
        var coords: PackedVector2Array = t.xy
        var shift: Vector2 = phase[int(t.chart)]
        for k in range(3):
            coords[k] += shift
        t.xy = coords

## Precompute boundary texel correspondences after packing, also on
## restored projects. Only direct neighbors are returned, never a flood
## across multiple folds. Brush tools can mirror exact boundary samples.
static func seam_pixels(tris: Array, atlas_size: Vector2i) -> Dictionary:
    var result: Dictionary = {}
    var size: Vector2 = Vector2(atlas_size)
    for link in _seam_segments(tris):
        var a: Dictionary = tris[link.ta]
        var b: Dictionary = tris[link.tb]
        var sa: PackedVector2Array = _segment_uv(a,link.ea,link.a0,link.a1,"uv")
        var sb: PackedVector2Array = _segment_uv(b,link.eb,link.b0,link.b1,"uv")
        var ua: PackedVector2Array = a.uv
        var ub: PackedVector2Array = b.uv
        var ca: Vector2 = (ua[0]+ua[1]+ua[2])*size/3.0
        var cb: Vector2 = (ub[0]+ub[1]+ub[2])*size/3.0
        var steps: int = clampi(ceili(maxf(((sa[1]-sa[0])*size).length(),((sb[1]-sb[0])*size).length())*2.0),1,2048)
        for i in range(steps+1):
            var f: float = float(i)/float(steps)
            var qa: Vector2 = sa[0].lerp(sa[1],f)*size
            var qb: Vector2 = sb[0].lerp(sb[1],f)*size
            var pa: Vector2i = Vector2i((qa+(ca-qa).normalized()*0.12).floor()).clamp(Vector2i.ZERO,atlas_size-Vector2i.ONE)
            var pb: Vector2i = Vector2i((qb+(cb-qb).normalized()*0.12).floor()).clamp(Vector2i.ZERO,atlas_size-Vector2i.ONE)
            if pa == pb:
                continue
            if not result.has(pa):
                result[pa] = []
            if not result.has(pb):
                result[pb] = []
            if not (result[pa] as Array).has(pb):
                (result[pa] as Array).append(pb)
            if not (result[pb] as Array).has(pa):
                (result[pb] as Array).append(pa)
    return result

## Return barycentric weights at the nearest point on a triangle edge.
## The conservative half-diagonal fringe covers all nearest-filter texels
## touched by the surface, including subpixel and diagonal triangles.
static func _nearest_weights(p: Vector2,a: Vector2,b: Vector2,c: Vector2) -> Vector3:
    var ab: Vector2 = b-a
    var bc: Vector2 = c-b
    var ca: Vector2 = a-c
    var t0: float = clampf((p-a).dot(ab)/maxf(ab.length_squared(),0.000000001),0.0,1.0)
    var t1: float = clampf((p-b).dot(bc)/maxf(bc.length_squared(),0.000000001),0.0,1.0)
    var t2: float = clampf((p-c).dot(ca)/maxf(ca.length_squared(),0.000000001),0.0,1.0)
    var d0: float = p.distance_squared_to(a+ab*t0)
    var d1: float = p.distance_squared_to(b+bc*t1)
    var d2: float = p.distance_squared_to(c+ca*t2)
    if d0 <= d1 and d0 <= d2:
        return Vector3(1.0-t0,t0,0.0)
    if d1 <= d2:
        return Vector3(0.0,1.0-t1,t1)
    return Vector3(t2,0.0,1.0-t2)

static func _bake_triangle(img: Image,t: Dictionary, distances: PackedFloat32Array = PackedFloat32Array()) -> void:
    var side: float = float(img.get_width())
    var a: Vector2 = t.uv[0]*side
    var b: Vector2 = t.uv[1]*side
    var c: Vector2 = t.uv[2]*side
    var d: float = (b-a).cross(c-a)
    if absf(d) < 0.0000001:
        return
    var lo := Vector2i(floori(minf(a.x,minf(b.x,c.x))-1.0),floori(minf(a.y,minf(b.y,c.y))-1.0))
    var hi := Vector2i(ceili(maxf(a.x,maxf(b.x,c.x))+1.0),ceili(maxf(a.y,maxf(b.y,c.y))+1.0))
    var tex: Image = t.tex
    var colors: PackedColorArray = t.get("colors",PackedColorArray([Color.WHITE,Color.WHITE,Color.WHITE]))
    var use_distance: bool = distances.size() == img.get_width()*img.get_height()
    for y in range(maxi(0,lo.y),mini(img.get_height(),hi.y+1)):
        for x in range(maxi(0,lo.x),mini(img.get_width(),hi.x+1)):
            var p := Vector2(x+0.5,y+0.5)
            var v: float = (p-a).cross(c-a)/d
            var w: float = (b-a).cross(p-a)/d
            var weights := Vector3(1.0-v-w,v,w)
            var dist: float = 0.0
            if weights.x < -0.000001 or weights.y < -0.000001 or weights.z < -0.000001:
                weights = _nearest_weights(p,a,b,c)
                dist = p.distance_squared_to(a*weights.x+b*weights.y+c*weights.z)
                if dist > 0.50001:
                    continue
            var pixel_index: int = y*img.get_width()+x
            if use_distance:
                if dist >= distances[pixel_index]:
                    continue
                distances[pixel_index] = dist
            var color: Color = t.base
            if tex != null and not tex.is_empty():
                # Move boundary samples very slightly inward in the original
                # palette UVs to avoid crossing into an adjacent face colour.
                var sample_weights: Vector3 = weights.lerp(Vector3.ONE/3.0,0.0001)
                var old: Vector2 = t.prior[0]*sample_weights.x+t.prior[1]*sample_weights.y+t.prior[2]*sample_weights.z
                if bool(t.get("repeat",true)):
                    old = Vector2(fposmod(old.x,1.0),fposmod(old.y,1.0))
                var tx: int = clampi(floori(old.x*tex.get_width()),0,tex.get_width()-1)
                var ty: int = clampi(floori(old.y*tex.get_height()),0,tex.get_height()-1)
                color *= tex.get_pixel(tx,ty)
            color *= colors[0]*weights.x+colors[1]*weights.y+colors[2]*weights.z
            img.set_pixel(x,y,Color(color.r,color.g,color.b,1.0))

static func _encode_cull(mode: int) -> Color:
    if mode == BaseMaterial3D.CULL_FRONT:
        return Color(1.0,0.0,0.0,1.0)
    if mode == BaseMaterial3D.CULL_BACK:
        return Color(0.0,1.0,0.0,1.0)
    return Color.WHITE

static func _decode_cull(flag: Color) -> int:
    if flag.b < 0.5:
        if flag.r > 0.5:
            return BaseMaterial3D.CULL_FRONT
        return BaseMaterial3D.CULL_BACK
    return BaseMaterial3D.CULL_DISABLED

static func hit(tris: Array,origin: Vector3,direction: Vector3) -> Dictionary:
    var nearest := INF
    var result: Dictionary = {}
    for triangle_index in range(tris.size()):
        var t: Dictionary = tris[triangle_index]
        var p: PackedVector3Array = t.p
        var e1 := p[1]-p[0]
        var e2 := p[2]-p[0]
        var h := direction.cross(e2)
        var det := e1.dot(h)
        if absf(det) < 0.0000001:
            continue
        # Godot front faces use clockwise winding; the picking side must
        # match the visible side of the preview shader.
        var cull: int = int(t.get("cull",BaseMaterial3D.CULL_DISABLED))
        if (cull == BaseMaterial3D.CULL_FRONT and det < 0.0) or (cull == BaseMaterial3D.CULL_BACK and det > 0.0):
            continue
        var q := origin-p[0]
        var u := q.dot(h)/det
        if u < 0.0 or u > 1.0:
            continue
        var v := direction.dot(q.cross(e1))/det
        if v < 0.0 or u+v > 1.0:
            continue
        var depth := e2.dot(q.cross(e1))/det
        if depth > 0.0 and depth < nearest:
            nearest = depth
            result = {"uv":t.uv[0]*(1-u-v)+t.uv[1]*u+t.uv[2]*v,"chart":t.chart,"position":origin+direction*depth,"triangle":triangle_index}
    return result

## Inspect the actual packed atlas rather than the original palette UV.
## Reports distinguish geometry, UV distortion and incompatible seams.
static func diagnostic_report(tris: Array, side: Vector2i, density: int, selected: int = -1) -> Dictionary:
    var chosen: Dictionary = {}
    if selected >= 0 and selected < tris.size():
        chosen[int(tris[selected].get("diagnostic_face",selected))] = true
    return diagnostic_report_faces(tris,side,density,chosen)

## One pass over the mesh and shared edges, independent of selection size.
## Include edges between different selected original faces even when both
## belong to the same UV island. Keep the model-wide seam metric unchanged.
## Same residual definition for the report and heatmap. A shared edge
## is compared modulo quarter-turns and integer texel translations.
static func _diagnostic_edge_metrics(tris: Array, link: Dictionary, dimensions: Vector2) -> Dictionary:
    var a: PackedVector2Array = _segment_uv(tris[link.ta],link.ea,link.a0,link.a1,"uv")
    var b: PackedVector2Array = _segment_uv(tris[link.tb],link.eb,link.b0,link.b1,"uv")
    var da: Vector2 = (a[1]-a[0])*dimensions
    var db: Vector2 = (b[1]-b[0])*dimensions
    if minf(da.length(),db.length()) < 0.00001:
        return {}
    var angle: float = db.angle_to(da)
    var quarter: float = roundf(angle/(PI*0.5))*(PI*0.5)
    var error0: Vector2 = a[0]*dimensions-(b[0]*dimensions).rotated(quarter)
    error0 -= error0.round()
    var error1: Vector2 = error0+da-db.rotated(quarter)
    return {"residual":maxf(error0.length(),error1.length()),"length_a":da.length(),"length_b":db.length(),"angle":absf(rad_to_deg(angle-quarter))}

## Per original face, use the maximum of its measured inter-island
## residuals. Unmeasured faces are absent (not classified as passing).
static func diagnostic_face_residuals(tris: Array, side: Vector2i) -> Dictionary:
    var result: Dictionary = {}
    var dimensions: Vector2 = Vector2(side)
    for link in _seam_segments(tris):
        var metric: Dictionary = _diagnostic_edge_metrics(tris,link,dimensions)
        if metric.is_empty():
            continue
        for id in [int(link.ta),int(link.tb)]:
            var face: int = int(tris[id].get("diagnostic_face",id))
            result[face] = maxf(float(result.get(face,0.0)),float(metric.residual))
    return result

static func diagnostic_report_faces(tris: Array, side: Vector2i, density: int, chosen: Dictionary) -> Dictionary:
    var charts: Dictionary = {}
    var members: Dictionary = {}
    for i in range(tris.size()):
        var t: Dictionary = tris[i]
        charts[int(t.chart)] = true
        var id: int = int(t.get("diagnostic_face",i))
        if chosen.has(id):
            if not members.has(id):
                members[id] = []
            (members[id] as Array).append(i)
    var seam_count: int = 0
    var unmatched: int = 0
    var worst: float = 0.0
    var internal: Array[Dictionary] = []
    var external: Array[Dictionary] = []
    var face_worst: Dictionary = {}
    var dimensions: Vector2 = Vector2(side)
    for link in _seam_segments(tris,not members.is_empty()):
        var ta: int = int(link.ta)
        var tb: int = int(link.tb)
        var fa: int = int(tris[ta].get("diagnostic_face",ta))
        var fb: int = int(tris[tb].get("diagnostic_face",tb))
        var metric: Dictionary = _diagnostic_edge_metrics(tris,link,dimensions)
        if metric.is_empty():
            continue
        var residual: float = float(metric.residual)
        if int(link.a) != int(link.b):
            seam_count += 1
            worst = maxf(worst,residual)
            if residual > 0.25:
                unmatched += 1
            face_worst[fa] = maxf(float(face_worst.get(fa,0.0)),residual)
            face_worst[fb] = maxf(float(face_worst.get(fb,0.0)),residual)
        if fa == fb:
            continue
        var selected_a: bool = members.has(fa)
        var selected_b: bool = members.has(fb)
        if not selected_a and not selected_b:
            continue
        var entry: Dictionary = {"residual":residual,"text":"面ID%d↔%d triangle=%d:%d↔%d:%d 島%d↔%d 長さ %.2f/%.2fpx 角度差 %.1f° 残差 %.2fpx" % [fa,fb,ta,link.ea,tb,link.eb,link.a,link.b,float(metric.length_a),float(metric.length_b),float(metric.angle),residual]}
        if selected_a and selected_b:
            internal.append(entry)
        else:
            external.append(entry)
    var summary: String = "UV島 %d / 共有辺 %d / 残差>0.25px %d / 最大 %.2fpx" % [charts.size(),seam_count,unmatched,worst]
    var lines: PackedStringArray = PackedStringArray([summary,"atlas=%dx%d density=%d" % [side.x,side.y,density]])
    if not members.is_empty():
        summary = "選択 %d面 / 選択面間共有辺 %d" % [members.size(),internal.size()]
        lines.append(summary)
        var ids: Array = members.keys()
        ids.sort_custom(func(a: int,b: int) -> bool:
            var va: float = float(face_worst.get(a,-1.0))
            var vb: float = float(face_worst.get(b,-1.0))
            return a < b if va == vb else va > vb)
        for face_id in ids:
            var face_members: Array = members[face_id]
            var selected: int = int(face_members[0])
            var t: Dictionary = tris[selected]
            var p: PackedVector3Array = t.p
            var normal: Vector3 = (p[1]-p[0]).cross(p[2]-p[0]).normalized()
            var face_charts: Dictionary = {}
            var max_bend: float = 0.0
            var max_plane: float = 0.0
            var lo_ratio: float = INF
            var hi_ratio: float = 0.0
            for id in face_members:
                var part: Dictionary = tris[id]
                face_charts[int(part.chart)] = true
                var pp: PackedVector3Array = part.p
                var uv: PackedVector2Array = part.uv
                var n: Vector3 = (pp[1]-pp[0]).cross(pp[2]-pp[0]).normalized()
                max_bend = maxf(max_bend,rad_to_deg(acos(clampf(normal.dot(n),-1,1))))
                for k in range(3):
                    max_plane = maxf(max_plane,absf((pp[k]-p[0]).dot(normal)))
                    var world_length: float = pp[k].distance_to(pp[(k+1)%3])
                    if world_length > 0.000001:
                        var ratio: float = ((uv[k]-uv[(k+1)%3])*dimensions).length()/maxf(0.000001,world_length*density)
                        lo_ratio = minf(lo_ratio,ratio)
                        hi_ratio = maxf(hi_ratio,ratio)
            var face_label: String = "原面%d" % int(t.authored_face) if int(t.get("authored_face",-1)) >= 0 else "三角形%d（原面不明）" % selected
            lines.append("")
            var residual_label: String = "%.2fpx" % float(face_worst[face_id]) if face_worst.has(face_id) else "未測定"
            lines.append("面ID%d / %s / surface=%d / 最大残差 %s / 曲がり %.1f° / 密度比 %.2f–%.2f / plane deviation=%.3f mm" % [face_id,face_label,int(t.get("surface",-1)),residual_label,max_bend,lo_ratio,hi_ratio,max_plane*1000.0])
            lines.append("UV islands="+str(face_charts.keys()))
            for id in face_members:
                var part: Dictionary = tris[id]
                lines.append("triangle=%d geometry=%s / atlasUV=%s" % [id,str(part.p),str(part.uv)])
        lines.append("")
        var ranked: Array[Dictionary] = internal.duplicate()
        ranked.append_array(external)
        ranked.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:
            return str(a.text) < str(b.text) if float(a.residual) == float(b.residual) else float(a.residual) > float(b.residual))
        lines.append("共有辺残差ランキング（選択面間%d / 選択面外%d）" % [internal.size(),external.size()])
        for entry in ranked:
            lines.append(str(entry.text))
    return {"summary":summary,"report":"\n".join(lines)}

## Restore the exact saved atlas, without repartitioning or resampling.
static func restore_triangles(mesh: ArrayMesh, chart_ids: Array, face_sources: Array = []) -> Array:
    var result: Array = []
    if mesh == null or mesh.get_surface_count() != 1:
        return result
    var a: Array = mesh.surface_get_arrays(0)
    var vertices: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
    var uv: PackedVector2Array = a[Mesh.ARRAY_TEX_UV]
    var flags: PackedColorArray = a[Mesh.ARRAY_COLOR] if a[Mesh.ARRAY_COLOR] != null else PackedColorArray()
    if vertices.size() != uv.size() or vertices.size() % 3 != 0 or chart_ids.size()*3 != vertices.size() or chart_ids.size() > MAX_TRIANGLES:
        return result
    for i in range(0,vertices.size(),3):
        var t: Dictionary = {"p":PackedVector3Array([vertices[i],vertices[i+1],vertices[i+2]]),"uv":PackedVector2Array([uv[i],uv[i+1],uv[i+2]]),"chart":int(chart_ids[i/3]),"cull":_decode_cull(flags[i]) if flags.size() == vertices.size() else BaseMaterial3D.CULL_DISABLED}
        if face_sources.size() == chart_ids.size():
            var record: Variant = face_sources[i/3]
            if record is Array and record.size() == 2 and (record[0] is int or record[0] is float) and (record[1] is int or record[1] is float):
                t.surface = int(record[0])
                t.authored_face = int(record[1])
        result.append(t)
    return result

static func mirror_hit(tris: Array, origin: Vector3, direction: Vector3, hit_position: Vector3, axis_x: float, tolerance: float) -> Dictionary:
    var o := Vector3(2.0*axis_x-origin.x,origin.y,origin.z)
    var d := Vector3(-direction.x,direction.y,direction.z)
    var target := Vector3(2.0*axis_x-hit_position.x,hit_position.y,hit_position.z)
    var found := hit(tris,o,d)
    if found.is_empty():
        return {}
    var actual: Vector3 = found.position
    if actual.distance_to(target) > tolerance:
        return {}
    return found

## Assign a stable selection identifier per authored polygon. The surface
## is part of the key because face numbers restart in every source mesh.
## Without provenance, use a single triangle rather than guessing a face
## from an unrelated UV island.
static func assign_diagnostic_faces(tris: Array) -> void:
    var groups: Dictionary = {}
    var next_id: int = 0
    for i in range(tris.size()):
        var t: Dictionary = tris[i]
        var surface: int = int(t.get("surface",-1))
        var face: int = int(t.get("authored_face",-1))
        if surface >= 0 and face >= 0:
            var key := Vector2i(surface,face)
            if not groups.has(key):
                groups[key] = next_id
                next_id += 1
            t.diagnostic_face = int(groups[key])
        else:
            t.diagnostic_face = next_id
            next_id += 1

## Upgrade old mesh diagnostic flags to original face IDs in UV2.y.
## Keep positions, UVs, normals, colors and diagnostic classification.
static func with_diagnostic_ids(mesh: ArrayMesh, tris: Array) -> ArrayMesh:
    if mesh == null or mesh.get_surface_count() != 1:
        return mesh
    var arrays: Array = mesh.surface_get_arrays(0)
    var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
    if vertices.size() != tris.size()*3:
        return mesh
    assign_diagnostic_faces(tris)
    var old: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2] if arrays[Mesh.ARRAY_TEX_UV2] != null else PackedVector2Array()
    var complete: bool = old.size() == vertices.size()
    if complete:
        for i in range(tris.size()):
            if absf(old[i*3].y-float(int(tris[i].diagnostic_face)+1)) > 0.25:
                complete = false
                break
    if complete:
        return mesh
    var flags := PackedVector2Array()
    flags.resize(vertices.size())
    for i in range(tris.size()):
        for k in range(3):
            var index: int = i*3+k
            flags[index] = Vector2(old[index].x if old.size() == vertices.size() else 0.0,float(int(tris[i].diagnostic_face)+1))
    arrays[Mesh.ARRAY_TEX_UV2] = flags
    var updated := ArrayMesh.new()
    updated.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
    updated.surface_set_material(0,mesh.surface_get_material(0))
    return updated
