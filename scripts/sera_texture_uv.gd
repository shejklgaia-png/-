extends RefCounted
## Metric planar charts; all distances are measured after instance scaling.
const MAX_TRIANGLES = 12000
const PADDING = 2

static func build(source: MeshInstance3D, density: int, preserve_shape: bool = true, balanced_shape: bool = false) -> Dictionary:
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
    charts = _edge_aligned_charts(tris,density,preserve_shape)
    charts = _split_overlapping_charts(tris,charts)
    var initial_chart_count: int = charts.size()
    var affine_report: String = ""
    if preserve_shape:
        charts = _choose_hinge_layout(tris,charts)
        if balanced_shape:
            affine_report = _relax_affine_islands(tris,charts)
            affine_report += " / "+_relax_uv_boundary_vertices(tris,charts)
    else:
        _match_rectified_edge_counts(tris,charts)
        _align_triangular_grids(tris,charts)
        _synchronize_chart_grids(tris,charts)
        _refine_residual_grids(tris,charts,density)
        _balance_rectified_groups(tris,charts,density)
        _refine_residual_grids(tris,charts,density,true)
        _finish_grid_refinement(tris,charts,density)
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
    return {"mesh":out,"image":img,"triangles":tris,"charts":charts.size(),"preserve_shape":preserve_shape,"balanced_shape":balanced_shape and preserve_shape,"affine_report":affine_report,"initial_charts":initial_chart_count,"unwrap_version":("shape-affine-v6" if balanced_shape else "shape-hinge-v2") if preserve_shape else "boundary-v1"}

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

static func _can_join(a: Dictionary,b: Dictionary,edge_a: int,edge_b: int,preserve_shape: bool = false) -> bool:
    var na: Vector3 = a.face_normal
    var nb: Vector3 = b.face_normal
    var dot: float = na.dot(nb)
    var fa: int = int(a.get("authored_face",-1))
    var fb: int = int(b.get("authored_face",-1))
    # Authored faces define the grid domain, not accidental coplanarity.
    # Keep every original quad intact even when its neighbor is coplanar.
    var both_authored: bool = fa >= 0 and fb >= 0
    if both_authored and (not preserve_shape or (int(a.surface) == int(b.surface) and fa == fb)):
        if not preserve_shape:
            return int(a.surface) == int(b.surface) and fa == fb and dot > 0.5
        # A genuinely warped quad is kept as a common projection only
        # when its bend is modest. Large folds are separate domains.
        return dot > 0.8660254
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
    if both_authored:
        return false
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

static func _edge_aligned_charts(tris: Array[Dictionary],density: int,preserve_shape: bool = false) -> Array[Dictionary]:
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
                if _can_join(t,tris[other],e,int(item.y),preserve_shape):
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
        if aligned_edge or preserve_shape:
            # Keep the chosen baseline on an integer texel boundary. The
            # bounding box may extend below it on a trapezoid or irregular face.
            var minimum: Vector2 = chart.min
            chart.min = minimum.floor()
        if not preserve_shape:
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
static func _synchronize_chart_grids(tris: Array[Dictionary],charts: Array[Dictionary],lock_baseline: bool = false) -> void:
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
            if lock_baseline:
                next[i] = Vector2(next[i].x,0.0)
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

## Refine the existing UVs against all incident edges, not just the
## edges used to construct a rectangle or triangle. Only small charts
## with known non-overlapping triangle topology are changed.
static func _refine_residual_grids(tris: Array[Dictionary],charts: Array[Dictionary],density: int,balanced: bool = false,fine: bool = false) -> void:
    var members: Array = []
    var adjacency: Array = []
    for i in range(charts.size()):
        members.append([])
        adjacency.append([])
    for i in range(tris.size()):
        (members[int(tris[i].chart)] as Array).append(i)
    for link in _seam_segments(tris):
        (adjacency[int(link.a)] as Array).append(link)
        (adjacency[int(link.b)] as Array).append(link)
    # The same small chart may be revisited after its neighbor changes.
    # Bound mobile work; skip charts with more than two triangles.
    for pass_index in range(3 if fine else 4):
        var priority: Array[Dictionary] = []
        for ci in range(charts.size()):
            if members[ci].size() < 1 or members[ci].size() > 2 or adjacency[ci].is_empty():
                continue
            var worst: float = 0.0
            for link in adjacency[ci]:
                worst = maxf(worst,_local_edge_residual(tris,link,-1,{},PackedVector2Array()))
            if worst > (1.0 if fine else (2.0 if balanced else 0.25)):
                priority.append({"chart":ci,"worst":worst})
        priority.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:
            return int(a.chart) < int(b.chart) if float(a.worst) == float(b.worst) else float(a.worst) > float(b.worst))
        var changed: bool = false
        for k in range(mini(128,priority.size())):
            var ci: int = int(priority[k].chart)
            if _refine_small_chart(tris,charts[ci],ci,members[ci],adjacency[ci],density,balanced,fine):
                changed = true
        if not changed:
            break

## Shape-priority alignment: a chart is a rigid 2D object. Rotation and
## translation cannot change its internal distances, angles, or winding.
## Solve periodic grid alignment against every incident boundary.
## Unfold neighboring charts through their actual shared edge before
## phase alignment. Every accepted join is a rigid transform, with
## matching endpoints, no positive-area overlap, and no inconsistent
## secondary seam inside the merged chart.
## Try a second cut topology on modest meshes. All trial UVs are
## isolated from the source and the old layout remains a fallback.
## Uniform affine changes per connected island, not individual vertex
## snapping. All triangles in an island receive the same invertible map.
static func _affine_grid_point(p: Vector2,pivot: Vector2,params: PackedFloat32Array) -> Vector2:
    var q: Vector2 = p-pivot
    var transformed := Vector2(q.x*(1.0+params[1])+q.y*params[3],q.y*(1.0+params[2])+q.x*params[4])
    return transformed.rotated(params[0])+pivot+Vector2(params[5],params[6])

static func _affine_link_error(link: Dictionary,params: Array,pivots: PackedVector2Array) -> float:
    var ca: int = int(link.a)
    var cb: int = int(link.b)
    var pa: PackedVector2Array = link.pa
    var pb: PackedVector2Array = link.pb
    var a0: Vector2 = _affine_grid_point(pa[0],pivots[ca],params[ca])
    var a1: Vector2 = _affine_grid_point(pa[1],pivots[ca],params[ca])
    var b0: Vector2 = _affine_grid_point(pb[0],pivots[cb],params[cb])
    var b1: Vector2 = _affine_grid_point(pb[1],pivots[cb],params[cb])
    var da: Vector2 = a1-a0
    var db: Vector2 = b1-b0
    var quarter: float = roundf(db.angle_to(da)/(PI*0.5))*(PI*0.5)
    var error: Vector2 = a0-b0.rotated(quarter)
    error -= error.round()
    return maxf(error.length(),(error+da-db.rotated(quarter)).length())

static func _affine_metrics(links: Array[Dictionary],params: Array,pivots: PackedVector2Array) -> Vector3:
    var score := Vector3.ZERO
    for link in links:
        var error: float = _affine_link_error(link,params,pivots)
        score.x = maxf(score.x,error)
        score.y += 1.0 if error > 0.25 else 0.0
        score.z += error*error
    return score

static func _affine_local_cost(ci: int,links: Array[Dictionary],incident: Array,params: Array,pivots: PackedVector2Array) -> float:
    var cost: float = 0.0
    for li in incident:
        var e: float = _affine_link_error(links[int(li)],params,pivots)
        cost += e*e + 0.15*maxf(0.0,e-0.25)
    var p: PackedFloat32Array = params[ci]
    # Small penalty toward the original metric grid.
    for k in range(1,5):
        cost += p[k]*p[k]*2.0
    return cost

static func _relax_affine_islands(tris: Array[Dictionary],charts: Array[Dictionary]) -> String:
    if charts.size() > 256 or tris.size() > 2000:
        return "対象規模上限超過"
    var links: Array[Dictionary] = []
    var adjacency: Array = []
    var pivots := PackedVector2Array()
    var params: Array = []
    for chart in charts:
        adjacency.append([])
        params.append(PackedFloat32Array([0,0,0,0,0,0,0]))
        var lo: Vector2 = chart.min
        var hi: Vector2 = chart.max
        pivots.append((lo+hi)*0.5)
    for link in _seam_segments(tris):
        var a: PackedVector2Array = _segment_uv(tris[link.ta],link.ea,link.a0,link.a1,"xy")
        var b: PackedVector2Array = _segment_uv(tris[link.tb],link.eb,link.b0,link.b1,"xy")
        if minf(a[0].distance_to(a[1]),b[0].distance_to(b[1])) < 0.00001:
            continue
        var li: int = links.size()
        links.append({"a":int(link.a),"b":int(link.b),"pa":a,"pb":b})
        (adjacency[int(link.a)] as Array).append(li)
        (adjacency[int(link.b)] as Array).append(li)
    if links.is_empty():
        return "共有辺なし"
    var baseline: Vector3 = _affine_metrics(links,params,pivots)
    var best_score: Vector3 = baseline
    var best_params: Array = params.duplicate()
    var accepted: int = 0
    var limits := PackedFloat32Array([0.2617994,0.1,0.1,0.12,0.12,0.5,0.5])
    var steps := PackedFloat32Array([0.0872665,0.05,0.05,0.06,0.06,0.25,0.25])
    for sweep in range(12):
        for i in range(charts.size()):
            var ci: int = i if sweep%2 == 0 else charts.size()-1-i
            if adjacency[ci].is_empty():
                continue
            var current: PackedFloat32Array = params[ci]
            var best: float = _affine_local_cost(ci,links,adjacency[ci],params,pivots)
            for k in range(7):
                var chosen: PackedFloat32Array = current
                var local_before: Vector3 = _affine_incident_metrics(links,adjacency[ci],params,pivots)
                var step: float = steps[k]*(0.25 if sweep >= 8 else (0.5 if sweep >= 4 else 1.0))
                for sign_value in [-1.0,1.0]:
                    var candidate: PackedFloat32Array = current.duplicate()
                    candidate[k] = clampf(current[k]+step*float(sign_value),-limits[k],limits[k])
                    params[ci] = candidate
                    var cost: float = _affine_local_cost(ci,links,adjacency[ci],params,pivots)
                    var local_after: Vector3 = _affine_incident_metrics(links,adjacency[ci],params,pivots)
                    if local_after.x <= maxf(baseline.x,local_before.x)+0.00001 and local_after.y <= local_before.y and local_after.z <= local_before.z+0.00001 and cost < best-0.000001:
                        best = cost
                        chosen = candidate
                if chosen != current:
                    accepted += 1
                current = chosen
                params[ci] = current
        var score: Vector3 = _affine_metrics(links,params,pivots)
        if score.x <= baseline.x+0.00001 and score.y <= baseline.y and score.z < best_score.z-0.00001:
            best_score = score
            best_params = params.duplicate()
    var v2_score: Vector3 = best_score
    var pair_params: Array = best_params.duplicate()
    var pair_count: int = _refine_affine_pairs(links,adjacency,pair_params,pivots,limits)
    var pair_score: Vector3 = _affine_metrics(links,pair_params,pivots)
    var pair_note: String = " / ペア補正 不採用 (%d候補)" % pair_count
    if pair_score.x <= best_score.x+0.00001 and pair_score.y <= best_score.y and pair_score.z < best_score.z-0.00001:
        var pair_bounds: Array[Dictionary] = _affine_candidate_bounds(tris,charts,pivots,pair_params)
        if _hinge_pack_side(pair_bounds) <= mini(1024,_hinge_pack_side(charts)*2):
            best_params = pair_params
            best_score = pair_score
            pair_note = " / ペア補正 %d採用・最大 %.3f→%.3fpx・問題辺 %d→%d" % [pair_count,v2_score.x,best_score.x,int(v2_score.y),int(best_score.y)]
        else:
            pair_note = " / ペア補正 容量超過・V2維持"
    var summary: String = "候補 %d / 問題辺 %d→%d / 最大 %.3f→%.3fpx / 二乗和 %.3f→%.3f" % [accepted,int(baseline.y),int(best_score.y),baseline.x,best_score.x,baseline.z,best_score.z]+pair_note
    if best_score.z >= baseline.z-0.00001:
        return "不採用（残差条件） / "+summary
    # Calculate proposed bounds before committing; keep atlas size.
    var next_charts: Array[Dictionary] = []
    for chart in charts:
        var c: Dictionary = chart.duplicate()
        c.min = Vector2(INF,INF)
        c.max = Vector2(-INF,-INF)
        next_charts.append(c)
    var next_xy: Array[PackedVector2Array] = []
    for t in tris:
        var ci: int = int(t.chart)
        var q := PackedVector2Array()
        var c: Dictionary = next_charts[ci]
        for point in t.xy:
            var v: Vector2 = _affine_grid_point(point,pivots[ci],best_params[ci])
            q.append(v)
            var lo: Vector2 = c.min
            var hi: Vector2 = c.max
            c.min = lo.min(v)
            c.max = hi.max(v)
        next_xy.append(q)
    for c in next_charts:
        var lo: Vector2 = c.min
        c.min = lo.floor()
    var old_side: int = _hinge_pack_side(charts)
    var new_side: int = _hinge_pack_side(next_charts)
    if new_side > mini(1024,old_side*2):
        return "不採用（容量条件 %d→%d） / " % [old_side,new_side]+summary
    for i in range(tris.size()):
        tris[i].xy = next_xy[i]
    for ci in range(charts.size()):
        charts[ci].min = next_charts[ci].min
        charts[ci].max = next_charts[ci].max
    return "採用 / 容量 %d→%d / " % [old_side,new_side]+summary


# Joint moves can improve a seam that cannot be improved by moving
# either island alone. Preserve the accepted V2 result as a fallback.

# Local UV refinement: only move boundary vertices, welding all copies
# of the same geometric vertex within a continuous UV island.
static func _relax_uv_boundary_vertices(tris: Array[Dictionary],charts: Array[Dictionary]) -> String:
    if charts.size() > 256 or tris.size() > 1000:
        return "頂点補正 対象規模上限超過"
    var original: Array[PackedVector2Array] = []
    var members: Array = []
    var node_groups: Dictionary = {}
    var nodes: Array[Dictionary] = []
    var corner_nodes: Array[PackedInt32Array] = []
    for ci in range(charts.size()):
        members.append([])
    for ti in range(tris.size()):
        var t: Dictionary = tris[ti]
        var xy: PackedVector2Array = t.xy
        original.append(xy.duplicate())
        var ci: int = int(t.chart)
        (members[ci] as Array).append(ti)
        var ids := PackedInt32Array()
        for k in range(3):
            var key: String = str(ci)+":"+_vertex_key(t.p[k])
            var group: Array = node_groups.get(key,[])
            var ni: int = -1
            for candidate in group:
                var origin: Vector2 = nodes[int(candidate)].origin
                if origin.distance_to(xy[k]) <= 0.005:
                    ni = int(candidate)
                    break
            if ni < 0:
                ni = nodes.size()
                group.append(ni)
                node_groups[key] = group
                nodes.append({"origin":xy[k],"chart":ci,"refs":[],"links":[],"shift":Vector2.ZERO})
            (nodes[ni].refs as Array).append(Vector2i(ti,k))
            ids.append(ni)
        corner_nodes.append(ids)
    var links: Array[Dictionary] = _seam_segments(tris)
    for li in range(links.size()):
        var link: Dictionary = links[li]
        for pair in [Vector2i(int(link.ta),int(link.ea)),Vector2i(int(link.tb),int(link.eb))]:
            for k in [pair.y,(pair.y+1)%3]:
                var ni: int = corner_nodes[pair.x][k]
                var incident: Array = nodes[ni].links
                if not incident.has(li):
                    incident.append(li)
    # A subdivided edge within an island may have a T-junction.
    # Keep its endpoints fixed rather than tear the interior seam.
    var locked: Dictionary = {}
    for link in _seam_segments(tris,true):
        if int(link.a) != int(link.b):
            continue
        if absf(float(link.a1)-float(link.a0)) >= 0.9999 and absf(float(link.b1)-float(link.b0)) >= 0.9999:
            continue
        for pair in [Vector2i(int(link.ta),int(link.ea)),Vector2i(int(link.tb),int(link.eb))]:
            locked[corner_nodes[pair.x][pair.y]] = true
            locked[corner_nodes[pair.x][(pair.y+1)%3]] = true
    var baseline: Vector3 = _hinge_layout_metrics(tris)
    var accepted: int = 0
    var tested: int = 0
    var best_score: Vector3 = baseline
    var best_xy: Array[PackedVector2Array] = original.duplicate()
    for sweep in range(5):
        var ranking: Array[int] = []
        var priority := PackedFloat32Array()
        for ni in range(nodes.size()):
            var worst: float = 0.0
            for li in nodes[ni].links:
                worst = maxf(worst,_local_uv_link_error(tris,links[int(li)]))
            priority.append(worst)
            if worst > 0.25 and not locked.has(ni):
                ranking.append(ni)
        ranking.sort_custom(func(a: int,b: int) -> bool:
            return priority[a] > priority[b] if absf(priority[a]-priority[b]) > 0.000001 else a < b)
        var step: float = 0.15 if sweep < 2 else (0.075 if sweep < 4 else 0.0375)
        for ri in range(mini(64,ranking.size())):
            var node: Dictionary = nodes[ranking[ri]]
            var incident: Array = node.links
            var refs: Array = node.refs
            var old_shift: Vector2 = node.shift
            var before: Vector3 = _local_uv_metrics(tris,links,incident)
            var chosen: Vector2 = old_shift
            var best: float = before.z+before.x*before.x*0.5
            var changed: Dictionary = {}
            for ref in refs:
                changed[int(ref.x)] = true
            for direction in [Vector2.RIGHT,Vector2.LEFT,Vector2.UP,Vector2.DOWN,Vector2(1,1).normalized(),Vector2(-1,1).normalized(),Vector2(1,-1).normalized(),Vector2(-1,-1).normalized()]:
                var candidate: Vector2 = (old_shift+direction*step).limit_length(0.5)
                if candidate.distance_squared_to(old_shift) < 0.0000001:
                    continue
                tested += 1
                _set_local_uv_shift(tris,original,refs,candidate)
                var after: Vector3 = _local_uv_metrics(tris,links,incident)
                var cost: float = after.z+after.x*after.x*0.5
                if after.x > maxf(before.x,baseline.x)+0.00001 or after.y > before.y or after.z >= before.z-0.000001 or cost >= best-0.000001:
                    continue
                if not _valid_local_uv_shift(tris,original,changed,members[int(node.chart)]):
                    continue
                best = cost
                chosen = candidate
            _set_local_uv_shift(tris,original,refs,chosen)
            if chosen.distance_squared_to(old_shift) > 0.0000001:
                node.shift = chosen
                accepted += 1
        var score: Vector3 = _hinge_layout_metrics(tris)
        if score.x <= baseline.x+0.00001 and score.y <= baseline.y and score.z < best_score.z-0.00001:
            best_score = score
            best_xy.clear()
            for t in tris:
                var xy: PackedVector2Array = t.xy
                best_xy.append(xy.duplicate())
    for i in range(tris.size()):
        tris[i].xy = best_xy[i]
    var note: String = "頂点補正 %d採用/%d試行・問題辺 %d→%d・最大 %.3f→%.3fpx・二乗和 %.3f→%.3f" % [accepted,tested,int(baseline.y),int(best_score.y),baseline.x,best_score.x,baseline.z,best_score.z]
    if best_score.z >= baseline.z-0.00001:
        return note+" / 不採用"
    var next_charts: Array[Dictionary] = []
    for ci in range(charts.size()):
        var chart: Dictionary = charts[ci].duplicate()
        var lo := Vector2(INF,INF)
        var hi := Vector2(-INF,-INF)
        for ti in members[ci]:
            for point in tris[int(ti)].xy:
                lo = lo.min(point)
                hi = hi.max(point)
        chart.min = lo.floor()
        chart.max = hi
        next_charts.append(chart)
    # V4 does not increase the atlas size accepted by V3.
    if _hinge_pack_side(next_charts) > _hinge_pack_side(charts):
        for i in range(tris.size()):
            tris[i].xy = original[i]
        return note+" / 容量超過・V3維持"
    for ci in range(charts.size()):
        charts[ci].min = next_charts[ci].min
        charts[ci].max = next_charts[ci].max
    var paired_report: String = _relax_paired_uv_endpoints(tris,charts,original,members,nodes,corner_nodes,links,locked)
    return note+" / 採用 / "+paired_report+" / "+_relax_global_uv_boundaries(tris,charts,original,members,nodes,corner_nodes,links,locked)


# Try simultaneous moves of corresponding endpoints on both sides of
# a seam. Keep the V4 layout as the fallback, and measure cumulative
# distortion against the pre-V4 coordinates, not the last candidate.
static func _relax_paired_uv_endpoints(tris: Array[Dictionary],charts: Array[Dictionary],original: Array[PackedVector2Array],members: Array,nodes: Array[Dictionary],corner_nodes: Array[PackedInt32Array],links: Array[Dictionary],locked: Dictionary) -> String:
    var saved: Array[PackedVector2Array] = []
    for t in tris:
        var xy: PackedVector2Array = t.xy
        saved.append(xy.duplicate())
    for node in nodes:
        var ref: Vector2i = node.refs[0]
        node.shift = saved[ref.x][ref.y]-original[ref.x][ref.y]
    var baseline: Vector3 = _hinge_layout_metrics(tris)
    var accepted: int = 0
    var tested: int = 0
    for sweep in range(4):
        var ranking: Array[int] = []
        var priority := PackedFloat32Array()
        for li in range(links.size()):
            var e: float = _local_uv_link_error(tris,links[li])
            priority.append(e)
            if e > 0.25:
                ranking.append(li)
        ranking.sort_custom(func(a: int,b: int) -> bool:
            return priority[a] > priority[b] if absf(priority[a]-priority[b]) > 0.000001 else a < b)
        for ri in range(mini(48,ranking.size())):
            var link: Dictionary = links[ranking[ri]]
            if absf(float(link.a0)) > 0.0001 or absf(float(link.a1)-1.0) > 0.0001:
                continue
            if absf(float(link.b0)-1.0) > 0.0001 or absf(float(link.b1)) > 0.0001:
                continue
            var ta: int = int(link.ta)
            var tb: int = int(link.tb)
            var ea: int = int(link.ea)
            var eb: int = int(link.eb)
            var ids := PackedInt32Array([corner_nodes[ta][ea],corner_nodes[tb][(eb+1)%3],corner_nodes[ta][(ea+1)%3],corner_nodes[tb][eb]])
            var a: PackedVector2Array = _segment_uv(tris[ta],ea,float(link.a0),float(link.a1),"xy")
            var b: PackedVector2Array = _segment_uv(tris[tb],eb,float(link.b0),float(link.b1),"xy")
            var da: Vector2 = a[1]-a[0]
            var db: Vector2 = b[1]-b[0]
            var quarter: float = roundf(db.angle_to(da)/(PI*0.5))*(PI*0.5)
            var e0: Vector2 = a[0]-b[0].rotated(quarter)
            e0 -= e0.round()
            var e1: Vector2 = e0+da-db.rotated(quarter)
            var deltas := PackedVector2Array([-e0*0.5,e0.rotated(-quarter)*0.5,-e1*0.5,e1.rotated(-quarter)*0.5])
            var old := PackedVector2Array()
            var incident: Array = []
            var changes_a: Dictionary = {}
            var changes_b: Dictionary = {}
            for k in range(4):
                var node: Dictionary = nodes[ids[k]]
                old.append(node.shift)
                for li in node.links:
                    if not incident.has(li):
                        incident.append(li)
                for ref in node.refs:
                    if k%2 == 0:
                        changes_a[int(ref.x)] = true
                    else:
                        changes_b[int(ref.x)] = true
            var before: Vector3 = _local_uv_metrics(tris,links,incident)
            var chosen: PackedVector2Array = old.duplicate()
            var best: float = before.z+before.x*before.x*0.5
            for mask in [1,2,3]:
                if ((int(mask)&1)!=0 and (locked.has(ids[0]) or locked.has(ids[1]))) or ((int(mask)&2)!=0 and (locked.has(ids[2]) or locked.has(ids[3]))):
                    continue
                for factor in [0.5,1.0]:
                    var candidate: PackedVector2Array = old.duplicate()
                    var moved: bool = false
                    for k in range(4):
                        if (int(mask)&(1<<(0 if k < 2 else 1))) != 0:
                            candidate[k] = (old[k]+(deltas[k]*float(factor)).limit_length(0.2)).limit_length(0.5)
                        moved = moved or candidate[k].distance_squared_to(old[k]) > 0.0000001
                        _set_local_uv_shift(tris,original,nodes[ids[k]].refs,candidate[k])
                    if not moved:
                        continue
                    tested += 1
                    var after: Vector3 = _local_uv_metrics(tris,links,incident)
                    var cost: float = after.z+after.x*after.x*0.5
                    if after.x > baseline.x+0.00001 or after.y > before.y or after.z >= before.z-0.000001 or cost >= best-0.000001:
                        continue
                    if not _valid_local_uv_shift(tris,original,changes_a,members[int(link.a)]) or not _valid_local_uv_shift(tris,original,changes_b,members[int(link.b)]):
                        continue
                    chosen = candidate
                    best = cost
            var improved: bool = false
            for k in range(4):
                _set_local_uv_shift(tris,original,nodes[ids[k]].refs,chosen[k])
                nodes[ids[k]].shift = chosen[k]
                improved = improved or chosen[k].distance_squared_to(old[k]) > 0.0000001
            if improved:
                accepted += 1
    var score: Vector3 = _hinge_layout_metrics(tris)
    var next_charts: Array[Dictionary] = []
    for ci in range(charts.size()):
        var chart: Dictionary = charts[ci].duplicate()
        var lo := Vector2(INF,INF)
        var hi := Vector2(-INF,-INF)
        for ti in members[ci]:
            for point in tris[int(ti)].xy:
                lo = lo.min(point)
                hi = hi.max(point)
        chart.min = lo.floor()
        chart.max = hi
        next_charts.append(chart)
    var note: String = "両端補正 %d採用/%d試行・問題辺 %d→%d・最大 %.3f→%.3fpx・二乗和 %.3f→%.3f" % [accepted,tested,int(baseline.y),int(score.y),baseline.x,score.x,baseline.z,score.z]
    if score.x > baseline.x+0.00001 or score.y > baseline.y or score.z >= baseline.z-0.00001 or _hinge_pack_side(next_charts) > _hinge_pack_side(charts):
        for i in range(tris.size()):
            tris[i].xy = saved[i]
        return note+" / 不採用・V4維持"
    for ci in range(charts.size()):
        charts[ci].min = next_charts[ci].min
        charts[ci].max = next_charts[ci].max
    return note+" / 採用"


# Jacobi-style coupled seam relaxation. A candidate is evaluated across
# all seams, so an individual edge may temporarily get worse without
# vetoing a useful globally valid move. Never change geometry.
static func _relax_global_uv_boundaries(tris: Array[Dictionary],charts: Array[Dictionary],original: Array[PackedVector2Array],members: Array,nodes: Array[Dictionary],corner_nodes: Array[PackedInt32Array],links: Array[Dictionary],locked: Dictionary) -> String:
    var all_links: Array = []
    for li in range(links.size()):
        all_links.append(li)
    var baseline: Vector3 = _local_uv_metrics(tris,links,all_links)
    var score: Vector3 = baseline
    var shifts := PackedVector2Array()
    var by_chart: Array = []
    for ci in range(charts.size()):
        by_chart.append([])
    for ni in range(nodes.size()):
        var ref: Vector2i = nodes[ni].refs[0]
        shifts.append(tris[ref.x].xy[ref.y]-original[ref.x][ref.y])
        (by_chart[int(nodes[ni].chart)] as Array).append(ni)
    var capacity: int = _hinge_pack_side(charts)
    var accepted: int = 0
    var tested: int = 0
    for sweep in range(8):
        var best_score: Vector3 = score
        var best: PackedVector2Array = shifts.duplicate()
        var found: bool = false
        for power in [1.0,3.0]:
            var sums := PackedVector2Array()
            var weights := PackedFloat32Array()
            sums.resize(nodes.size())
            weights.resize(nodes.size())
            # Always linearize at the last accepted layout.
            for ni in range(nodes.size()):
                _set_local_uv_shift(tris,original,nodes[ni].refs,shifts[ni])
            for link in links:
                var ta: int = int(link.ta)
                var tb: int = int(link.tb)
                var ea: int = int(link.ea)
                var eb: int = int(link.eb)
                var a: PackedVector2Array = _segment_uv(tris[ta],ea,float(link.a0),float(link.a1),"xy")
                var b: PackedVector2Array = _segment_uv(tris[tb],eb,float(link.b0),float(link.b1),"xy")
                var da: Vector2 = a[1]-a[0]
                var db: Vector2 = b[1]-b[0]
                var quarter: float = roundf(db.angle_to(da)/(PI*0.5))*(PI*0.5)
                var e0: Vector2 = a[0]-b[0].rotated(quarter)
                e0 -= e0.round()
                var e1: Vector2 = e0+da-db.rotated(quarter)
                var w: float = pow(maxf(0.25,maxf(e0.length(),e1.length())),float(power))
                var ids := PackedInt32Array([corner_nodes[ta][ea],corner_nodes[ta][(ea+1)%3],corner_nodes[tb][eb],corner_nodes[tb][(eb+1)%3]])
                for endpoint in range(2):
                    var err: Vector2 = e0 if endpoint == 0 else e1
                    var fa: float = float(link.a0) if endpoint == 0 else float(link.a1)
                    var fb: float = float(link.b0) if endpoint == 0 else float(link.b1)
                    var coefficients := PackedFloat32Array([1.0-fa,fa,1.0-fb,fb])
                    for k in range(4):
                        var ni: int = ids[k]
                        if locked.has(ni):
                            continue
                        var coef: float = coefficients[k]
                        var direction: Vector2 = -err if k < 2 else err.rotated(-quarter)
                        sums[ni] += direction*coef*w
                        weights[ni] += coef*coef*w
            for step in [0.5,0.25,0.125,0.0625]:
                var candidate: PackedVector2Array = shifts.duplicate()
                for ni in range(nodes.size()):
                    if weights[ni] > 0.000001 and not locked.has(ni):
                        var delta: Vector2 = (sums[ni]/weights[ni]*float(step)).limit_length(0.2)
                        candidate[ni] = (shifts[ni]+delta).limit_length(0.75)
                    _set_local_uv_shift(tris,original,nodes[ni].refs,candidate[ni])
                # Reject a whole island's candidate if any triangle fails.
                for ci in range(charts.size()):
                    var changed: Dictionary = {}
                    for ni in by_chart[ci]:
                        if candidate[int(ni)].distance_squared_to(shifts[int(ni)]) > 0.00000001:
                            for ref in nodes[int(ni)].refs:
                                changed[int(ref.x)] = true
                    if not changed.is_empty() and not _valid_local_uv_shift(tris,original,changed,members[ci]):
                        for ni in by_chart[ci]:
                            candidate[int(ni)] = shifts[int(ni)]
                            _set_local_uv_shift(tris,original,nodes[int(ni)].refs,shifts[int(ni)])
                tested += 1
                var next_score: Vector3 = _local_uv_metrics(tris,links,all_links)
                if next_score.x > score.x+0.000001 or next_score.y > score.y or next_score.z >= score.z-0.000001:
                    continue
                var improves_best: bool = next_score.x < best_score.x-0.000001 or (absf(next_score.x-best_score.x) <= 0.000001 and next_score.z < best_score.z-0.000001)
                if not improves_best:
                    continue
                var bounds: Array[Dictionary] = _global_uv_chart_bounds(tris,charts,members)
                if _hinge_pack_side(bounds) > capacity:
                    continue
                best = candidate
                best_score = next_score
                found = true
        shifts = best
        for ni in range(nodes.size()):
            _set_local_uv_shift(tris,original,nodes[ni].refs,shifts[ni])
        if not found:
            break
        score = best_score
        accepted += 1
    if accepted > 0:
        var bounds: Array[Dictionary] = _global_uv_chart_bounds(tris,charts,members)
        for ci in range(charts.size()):
            charts[ci].min = bounds[ci].min
            charts[ci].max = bounds[ci].max
    return "全境界補正 %d採用/%d試行・問題辺 %d→%d・最大 %.3f→%.3fpx・二乗和 %.3f→%.3f / %s" % [accepted,tested,int(baseline.y),int(score.y),baseline.x,score.x,baseline.z,score.z,"採用" if accepted > 0 else "不採用・V5維持"]

static func _global_uv_chart_bounds(tris: Array[Dictionary],charts: Array[Dictionary],members: Array) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for ci in range(charts.size()):
        var chart: Dictionary = charts[ci].duplicate()
        var lo := Vector2(INF,INF)
        var hi := Vector2(-INF,-INF)
        for ti in members[ci]:
            for point in tris[int(ti)].xy:
                lo = lo.min(point)
                hi = hi.max(point)
        chart.min = lo.floor()
        chart.max = hi
        result.append(chart)
    return result

static func _set_local_uv_shift(tris: Array[Dictionary],original: Array[PackedVector2Array],refs: Array,shift: Vector2) -> void:
    for ref in refs:
        var ti: int = int(ref.x)
        var k: int = int(ref.y)
        var xy: PackedVector2Array = tris[ti].xy
        xy[k] = original[ti][k]+shift
        tris[ti].xy = xy

static func _local_uv_link_error(tris: Array[Dictionary],link: Dictionary) -> float:
    var a: PackedVector2Array = _segment_uv(tris[int(link.ta)],int(link.ea),float(link.a0),float(link.a1),"xy")
    var b: PackedVector2Array = _segment_uv(tris[int(link.tb)],int(link.eb),float(link.b0),float(link.b1),"xy")
    var da: Vector2 = a[1]-a[0]
    var db: Vector2 = b[1]-b[0]
    var quarter: float = roundf(db.angle_to(da)/(PI*0.5))*(PI*0.5)
    var e: Vector2 = a[0]-b[0].rotated(quarter)
    e -= e.round()
    return maxf(e.length(),(e+da-db.rotated(quarter)).length())

static func _local_uv_metrics(tris: Array[Dictionary],links: Array[Dictionary],incident: Array) -> Vector3:
    var result := Vector3.ZERO
    for li in incident:
        var e: float = _local_uv_link_error(tris,links[int(li)])
        result.x = maxf(result.x,e)
        result.y += 1.0 if e > 0.25 else 0.0
        result.z += e*e
    return result

static func _valid_local_uv_shift(tris: Array[Dictionary],original: Array[PackedVector2Array],changed: Dictionary,members: Array) -> bool:
    for ti in changed:
        var a: PackedVector2Array = tris[int(ti)].xy
        var old: PackedVector2Array = original[int(ti)]
        var old_area: float = (old[1]-old[0]).cross(old[2]-old[0])
        var area: float = (a[1]-a[0]).cross(a[2]-a[0])
        if absf(old_area) < 0.000001:
            return false
        var ratio: float = area/old_area
        if ratio < 0.75 or ratio > 1.25:
            return false
        for k in range(3):
            var length: float = old[k].distance_to(old[(k+1)%3])
            if length < 0.000001:
                return false
            var edge_ratio: float = a[k].distance_to(a[(k+1)%3])/length
            if edge_ratio < 0.85 or edge_ratio > 1.18:
                return false
        var lo: Vector2 = a[0].min(a[1]).min(a[2])
        var hi: Vector2 = a[0].max(a[1]).max(a[2])
        for other in members:
            if int(other) == int(ti):
                continue
            var b: PackedVector2Array = tris[int(other)].xy
            var bl: Vector2 = b[0].min(b[1]).min(b[2])
            var bh: Vector2 = b[0].max(b[1]).max(b[2])
            if minf(hi.x,bh.x)-maxf(lo.x,bl.x) <= 0.0001 or minf(hi.y,bh.y)-maxf(lo.y,bl.y) <= 0.0001:
                continue
            if _overlaps(a,b):
                return false
    return true

static func _refine_affine_pairs(links: Array[Dictionary],adjacency: Array,params: Array,pivots: PackedVector2Array,limits: PackedFloat32Array) -> int:
    var count: int = 0
    for sweep in range(4):
        var ranking: Array[int] = []
        var errors := PackedFloat32Array()
        for i in range(links.size()):
            errors.append(_affine_link_error(links[i],params,pivots))
            ranking.append(i)
        ranking.sort_custom(func(a: int,b: int) -> bool: return errors[a] > errors[b])
        var peak: float = _affine_metrics(links,params,pivots).x
        var seen: Dictionary = {}
        for li in ranking:
            var link: Dictionary = links[li]
            if errors[li] < 0.5 or seen.size() >= 16:
                break
            var ca: int = int(link.a)
            var cb: int = int(link.b)
            var key := Vector2i(mini(ca,cb),maxi(ca,cb))
            if seen.has(key):
                continue
            seen[key] = true
            var incident: Array = adjacency[ca].duplicate()
            for other in adjacency[cb]:
                if not incident.has(other):
                    incident.append(other)
            var base_a: PackedFloat32Array = params[ca]
            var base_b: PackedFloat32Array = params[cb]
            var best_a: PackedFloat32Array = base_a
            var best_b: PackedFloat32Array = base_b
            var before: Vector3 = _affine_incident_metrics(links,incident,params,pivots)
            var best: float = before.z + before.x*before.x*0.5
            var accepted: bool = false
            var step: float = deg_to_rad(5.0 if sweep < 2 else 2.5)
            for da in [-2.0,-1.0,0.0,1.0,2.0]:
                for db in [-2.0,-1.0,0.0,1.0,2.0]:
                    var rot_a: PackedFloat32Array = base_a.duplicate()
                    var rot_b: PackedFloat32Array = base_b.duplicate()
                    rot_a[0] = clampf(base_a[0]+float(da)*step,-limits[0],limits[0])
                    rot_b[0] = clampf(base_b[0]+float(db)*step,-limits[0],limits[0])
                    var pa: PackedVector2Array = link.pa
                    var pb: PackedVector2Array = link.pb
                    var a0: Vector2 = _affine_grid_point(pa[0],pivots[ca],rot_a)
                    var a1: Vector2 = _affine_grid_point(pa[1],pivots[ca],rot_a)
                    var b0: Vector2 = _affine_grid_point(pb[0],pivots[cb],rot_b)
                    var b1: Vector2 = _affine_grid_point(pb[1],pivots[cb],rot_b)
                    var quarter: float = roundf((b1-b0).angle_to(a1-a0)/(PI*0.5))*(PI*0.5)
                    var delta: Vector2 = (a0+a1)*0.5-((b0+b1)*0.5).rotated(quarter)
                    delta -= delta.round()
                    for blend in [0.0,0.5,1.0]:
                        var a: PackedFloat32Array = rot_a.duplicate()
                        var b: PackedFloat32Array = rot_b.duplicate()
                        var ta: Vector2 = Vector2(a[5],a[6])-delta*0.5*float(blend)
                        var tb: Vector2 = Vector2(b[5],b[6])+delta.rotated(-quarter)*0.5*float(blend)
                        ta -= ta.round()
                        tb -= tb.round()
                        a[5] = ta.x
                        a[6] = ta.y
                        b[5] = tb.x
                        b[6] = tb.y
                        params[ca] = a
                        params[cb] = b
                        var after: Vector3 = _affine_incident_metrics(links,incident,params,pivots)
                        var cost: float = after.z+after.x*after.x*0.5
                        if after.x <= peak+0.00001 and after.y <= before.y and after.z < before.z-0.00001 and cost < best-0.00001:
                            best = cost
                            best_a = a
                            best_b = b
                            accepted = true
            params[ca] = best_a
            params[cb] = best_b
            if accepted:
                count += 1
    return count

static func _affine_candidate_bounds(tris: Array[Dictionary],charts: Array[Dictionary],pivots: PackedVector2Array,params: Array) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for chart in charts:
        var c: Dictionary = chart.duplicate()
        c.min = Vector2(INF,INF)
        c.max = Vector2(-INF,-INF)
        result.append(c)
    for t in tris:
        var ci: int = int(t.chart)
        var c: Dictionary = result[ci]
        for point in t.xy:
            var v: Vector2 = _affine_grid_point(point,pivots[ci],params[ci])
            var lo: Vector2 = c.min
            var hi: Vector2 = c.max
            c.min = lo.min(v)
            c.max = hi.max(v)
    for c in result:
        var lo: Vector2 = c.min
        c.min = lo.floor()
    return result

static func _affine_incident_metrics(links: Array[Dictionary],incident: Array,params: Array,pivots: PackedVector2Array) -> Vector3:
    var score := Vector3.ZERO
    for li in incident:
        var error: float = _affine_link_error(links[int(li)],params,pivots)
        score.x = maxf(score.x,error)
        score.y += 1.0 if error > 0.25 else 0.0
        score.z += error*error
    return score

static func _choose_hinge_layout(tris: Array[Dictionary],charts: Array[Dictionary]) -> Array[Dictionary]:
    var trial_tris: Array[Dictionary] = []
    var trial_charts: Array[Dictionary] = []
    if tris.size() <= 1000 and charts.size() > 1 and charts.size() <= 256:
        for t in tris:
            var copy: Dictionary = t.duplicate()
            var xy: PackedVector2Array = t.xy
            copy.xy = xy.duplicate()
            trial_tris.append(copy)
        for chart in charts:
            trial_charts.append(chart.duplicate())
    var baseline: Array[Dictionary] = _connect_hinge_charts(tris,charts)
    _synchronize_chart_grids(tris,baseline,true)
    _align_rigid_chart_grids(tris,baseline)
    if trial_tris.is_empty():
        return baseline
    trial_charts = _connect_hinge_charts(trial_tris,trial_charts,true)
    _synchronize_chart_grids(trial_tris,trial_charts,true)
    _align_rigid_chart_grids(trial_tris,trial_charts)
    var before: Vector3 = _hinge_layout_metrics(tris)
    var after: Vector3 = _hinge_layout_metrics(trial_tris)
    # Count the absolute number of offending physical seams, not a
    # percentage of the remaining cuts. Do not trade for a larger atlas.
    if after.x > before.x+0.00001 or after.y > before.y or after.z >= before.z-0.00001:
        return baseline
    if _hinge_pack_side(trial_charts) > _hinge_pack_side(baseline):
        return baseline
    for i in range(tris.size()):
        tris[i].xy = trial_tris[i].xy
        tris[i].chart = trial_tris[i].chart
    return trial_charts

static func _hinge_layout_metrics(tris: Array[Dictionary]) -> Vector3:
    var worst: float = 0.0
    var count: float = 0.0
    var squared: float = 0.0
    for link in _seam_segments(tris):
        var a: PackedVector2Array = _segment_uv(tris[int(link.ta)],int(link.ea),float(link.a0),float(link.a1),"xy")
        var b: PackedVector2Array = _segment_uv(tris[int(link.tb)],int(link.eb),float(link.b0),float(link.b1),"xy")
        var da: Vector2 = a[1]-a[0]
        var db: Vector2 = b[1]-b[0]
        var quarter: float = roundf(db.angle_to(da)/(PI*0.5))*(PI*0.5)
        var e0: Vector2 = a[0]-b[0].rotated(quarter)
        e0 -= e0.round()
        var residual: float = maxf(e0.length(),(e0+da-db.rotated(quarter)).length())
        worst = maxf(worst,residual)
        if residual > 0.25:
            count += 1.0
        squared += residual*residual
    return Vector3(worst,count,squared)

static func _hinge_pack_side(charts: Array[Dictionary]) -> int:
    var sizes: Array[Vector2i] = []
    var order: Array[int] = []
    for i in range(charts.size()):
        var c: Dictionary = charts[i]
        sizes.append(Vector2i(ceili(c.max.x-c.min.x),ceili(c.max.y-c.min.y))+Vector2i.ONE*(2*PADDING+2))
        order.append(i)
    order.sort_custom(func(a: int,b: int) -> bool: return sizes[a].y > sizes[b].y)
    var side: int = 64
    while side <= 1024:
        var x: int = 0
        var y: int = 0
        var row: int = 0
        var fits: bool = true
        for i in order:
            var sz: Vector2i = sizes[i]
            if x+sz.x > side:
                x = 0
                y += row
                row = 0
            if sz.x > side or y+sz.y > side:
                fits = false
                break
            x += sz.x
            row = maxi(row,sz.y)
        if fits:
            return side
        side *= 2
    return side

static func _connect_hinge_charts(tris: Array[Dictionary],charts: Array[Dictionary],alternate: bool = false) -> Array[Dictionary]:
    var members: Array = []
    var incident: Array = []
    for ci in range(charts.size()):
        members.append([])
        incident.append([])
    for ti in range(tris.size()):
        (members[int(tris[ti].chart)] as Array).append(ti)
    var links: Array[Dictionary] = _seam_segments(tris)
    var candidates: Array[Dictionary] = []
    for li in range(links.size()):
        var link: Dictionary = links[li]
        (incident[int(link.a)] as Array).append(li)
        (incident[int(link.b)] as Array).append(li)
        var a: Dictionary = tris[int(link.ta)]
        var b: Dictionary = tris[int(link.tb)]
        if int(a.surface) != int(b.surface):
            continue
        if absf(float(link.a1)-float(link.a0)) < 0.9999 or absf(float(link.b1)-float(link.b0)) < 0.9999:
            continue
        var na: Vector3 = a.face_normal
        var nb: Vector3 = b.face_normal
        var alignment: float = na.dot(nb)
        if alignment < (-0.1736482 if alternate else 0.4226183):
            continue
        var pa: PackedVector2Array = _segment_uv(a,link.ea,link.a0,link.a1,"xy")
        var pb: PackedVector2Array = _segment_uv(b,link.eb,link.b0,link.b1,"xy")
        var length: float = minf(pa[0].distance_to(pa[1]),pb[0].distance_to(pb[1]))
        if length < 0.00001 or absf(pa[0].distance_to(pa[1])-pb[0].distance_to(pb[1])) > 0.001:
            continue
        var weight: float = 3.0*alignment+0.3*minf(length,8.0) if alternate else length*(0.5+alignment)
        candidates.append({"id":li,"weight":weight})
    candidates.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:
        return int(a.id) < int(b.id) if float(a.weight) == float(b.weight) else float(a.weight) > float(b.weight))
    var budget: int = 180000
    for item in candidates:
        if budget <= 0:
            break
        var link: Dictionary = links[int(item.id)]
        var ta: int = int(link.ta)
        var tb: int = int(link.tb)
        var ca: int = int(tris[ta].chart)
        var cb: int = int(tris[tb].chart)
        if ca == cb or members[ca].size()+members[cb].size() > 96:
            continue
        # The larger domain retains its original grid orientation.
        var keep: int = ca
        var move: int = cb
        if members[cb].size() > members[ca].size() or (members[cb].size() == members[ca].size() and cb < ca):
            keep = cb
            move = ca
        var pa: PackedVector2Array = _segment_uv(tris[ta],link.ea,link.a0,link.a1,"xy")
        var pb: PackedVector2Array = _segment_uv(tris[tb],link.eb,link.b0,link.b1,"xy")
        var fixed_edge: PackedVector2Array = pa if keep == ca else pb
        var moving_edge: PackedVector2Array = pb if keep == ca else pa
        var da: Vector2 = fixed_edge[1]-fixed_edge[0]
        var db: Vector2 = moving_edge[1]-moving_edge[0]
        if minf(da.length(),db.length()) < 0.00001 or absf(da.length()-db.length()) > 0.001:
            continue
        var angle: float = db.angle_to(da)
        var offset: Vector2 = fixed_edge[0]-moving_edge[0].rotated(angle)
        # All additional common boundaries must already agree under this
        # exact transform. Otherwise retain a cut rather than hiding a
        # discontinuity in the same chart.
        var valid: bool = true
        var checked: Dictionary = {}
        for li in incident[move]:
            if checked.has(li):
                continue
            checked[li] = true
            var other: Dictionary = links[li]
            var oa: int = int(tris[int(other.ta)].chart)
            var ob: int = int(tris[int(other.tb)].chart)
            if not ((oa == keep and ob == move) or (oa == move and ob == keep)):
                continue
            var sa: PackedVector2Array = _segment_uv(tris[int(other.ta)],other.ea,other.a0,other.a1,"xy")
            var sb: PackedVector2Array = _segment_uv(tris[int(other.tb)],other.eb,other.b0,other.b1,"xy")
            for k in range(2):
                var av: Vector2 = sa[k].rotated(angle)+offset if oa == move else sa[k]
                var bv: Vector2 = sb[k].rotated(angle)+offset if ob == move else sb[k]
                if av.distance_to(bv) > 0.001:
                    valid = false
                    break
            if not valid:
                break
        if not valid:
            continue
        var projected: Dictionary = {}
        var lo := Vector2(INF,INF)
        var hi := Vector2(-INF,-INF)
        for ti in members[keep]:
            for point in tris[ti].xy:
                lo = lo.min(point)
                hi = hi.max(point)
        for ti in members[move]:
            var xy := PackedVector2Array()
            for point in tris[ti].xy:
                var v: Vector2 = point.rotated(angle)+offset
                xy.append(v)
                lo = lo.min(v)
                hi = hi.max(v)
            projected[ti] = xy
        var old_a: Vector2 = charts[keep].max-charts[keep].min
        var old_b: Vector2 = charts[move].max-charts[move].min
        var size: Vector2 = hi-lo
        var padded: Vector2 = Vector2.ONE*float(2*PADDING+2)
        var combined: Vector2 = size+padded
        var pad_a: Vector2 = old_a+padded
        var pad_b: Vector2 = old_b+padded
        # Prevent a long sparse net from consuming disproportionate atlas
        # space. Never scale the island merely to make packing fit.
        if combined.x*combined.y > (pad_a.x*pad_a.y+pad_b.x*pad_b.y)*1.6:
            continue
        for ti in members[move]:
            var a: PackedVector2Array = projected[ti]
            var alo: Vector2 = a[0].min(a[1]).min(a[2])
            var ahi: Vector2 = a[0].max(a[1]).max(a[2])
            for tj in members[keep]:
                budget -= 1
                if budget < 0:
                    valid = false
                    break
                var b: PackedVector2Array = tris[tj].xy
                var blo: Vector2 = b[0].min(b[1]).min(b[2])
                var bhi: Vector2 = b[0].max(b[1]).max(b[2])
                if minf(ahi.x,bhi.x)-maxf(alo.x,blo.x) <= 0.0001 or minf(ahi.y,bhi.y)-maxf(alo.y,blo.y) <= 0.0001:
                    continue
                if _overlaps(a,b):
                    valid = false
                    break
            if not valid:
                break
        if not valid:
            continue
        for ti in members[move]:
            tris[ti].xy = projected[ti]
            tris[ti].chart = keep
        (members[keep] as Array).append_array(members[move])
        members[move] = []
        (incident[keep] as Array).append_array(incident[move])
        incident[move] = []
        charts[keep].min = lo.floor()
        charts[keep].max = hi
        charts[keep].rectified = false
    var result: Array[Dictionary] = []
    for ci in range(charts.size()):
        if members[ci].is_empty():
            continue
        for ti in members[ci]:
            tris[ti].chart = result.size()
        result.append(charts[ci])
    return result

static func _align_rigid_chart_grids(tris: Array[Dictionary],charts: Array[Dictionary]) -> void:
    var links: Array[Dictionary] = []
    var adjacency: Array = []
    var pivots := PackedVector2Array()
    var angles := PackedFloat32Array()
    var shifts := PackedVector2Array()
    var extents := PackedFloat32Array()
    angles.resize(charts.size())
    shifts.resize(charts.size())
    for chart in charts:
        adjacency.append([])
        var lo: Vector2 = chart.min
        var hi: Vector2 = chart.max
        pivots.append((lo+hi)*0.5)
        extents.append(maxf(hi.x-lo.x,hi.y-lo.y))
    for link in _seam_segments(tris):
        var a: PackedVector2Array = _segment_uv(tris[link.ta],link.ea,link.a0,link.a1,"xy")
        var b: PackedVector2Array = _segment_uv(tris[link.tb],link.eb,link.b0,link.b1,"xy")
        var length: float = minf(a[0].distance_to(a[1]),b[0].distance_to(b[1]))
        if length < 0.00001:
            continue
        var record: Dictionary = {"a":int(link.a),"b":int(link.b),"pa":a,"pb":b,"weight":1.0+minf(2.0,length*0.15)}
        var li: int = links.size()
        links.append(record)
        (adjacency[int(link.a)] as Array).append(li)
        (adjacency[int(link.b)] as Array).append(li)
    if links.is_empty():
        return
    var priority: Array[Dictionary] = []
    for ci in range(charts.size()):
        if adjacency[ci].is_empty():
            continue
        var cost: float = _rigid_chart_cost(ci,0.0,Vector2.ZERO,links,adjacency[ci],pivots,angles,shifts,extents)
        if cost > 0.0001:
            priority.append({"id":ci,"cost":cost})
    priority.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:
        return int(a.id) < int(b.id) if float(a.cost) == float(b.cost) else float(a.cost) > float(b.cost))
    for sweep in range(5):
        var changed: bool = false
        for i in range(mini(256,priority.size())):
            var ci: int = int(priority[i].id)
            var best_angle: float = angles[ci]
            var best_shift: Vector2 = shifts[ci]
            var best: float = _rigid_chart_cost(ci,best_angle,best_shift,links,adjacency[ci],pivots,angles,shifts,extents)
            var start: float = best
            # Use the strongest neighboring boundaries as proposals, but
            # evaluate each proposal against ALL incident boundaries.
            var proposals: Array[Dictionary] = []
            for li in adjacency[ci]:
                var record: Dictionary = links[li]
                var own_a: bool = int(record.a) == ci
                var own: PackedVector2Array = record.pa if own_a else record.pb
                var other: PackedVector2Array = record.pb if own_a else record.pa
                var neighbor: int = int(record.b) if own_a else int(record.a)
                var other_a: Vector2 = _rigid_grid_point(other[0],pivots[neighbor],angles[neighbor],shifts[neighbor])
                var other_b: Vector2 = _rigid_grid_point(other[1],pivots[neighbor],angles[neighbor],shifts[neighbor])
                var angle: float = (own[1]-own[0]).angle_to(other_b-other_a)
                angle = _rigid_quarter_angle(angle)
                # Larger planar islands remain closer to their original
                # bottom alignment; very large charts are translation-only.
                if extents[ci] > 128.0:
                    angle = 0.0
                proposals.append({"own":own,"a":other_a,"b":other_b,"angle":angle,"weight":record.weight})
            proposals.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return float(a.weight) > float(b.weight))
            for j in range(mini(16,proposals.size())):
                var proposal: Dictionary = proposals[j]
                var own: PackedVector2Array = proposal.own
                var other_a: Vector2 = proposal.a
                var other_b: Vector2 = proposal.b
                var target: float = float(proposal.angle)
                for angle in [0.0,float(angles[ci]),target,_rigid_quarter_angle(float(angles[ci])+_rigid_quarter_angle(target-float(angles[ci]))*0.5)]:
                    var oa: Vector2 = _rigid_grid_point(own[0],pivots[ci],angle,Vector2.ZERO)
                    var ob: Vector2 = _rigid_grid_point(own[1],pivots[ci],angle,Vector2.ZERO)
                    var quarter: float = roundf((other_b-other_a).angle_to(ob-oa)/(PI*0.5))*(PI*0.5)
                    var d0: Vector2 = other_a.rotated(quarter)-oa
                    var d1: Vector2 = other_b.rotated(quarter)-ob
                    for offset in [Vector2.ZERO,shifts[ci],d0,d1,(d0+d1)*0.5]:
                        var shift: Vector2 = offset-offset.round()
                        var score: float = _rigid_chart_cost(ci,angle,shift,links,adjacency[ci],pivots,angles,shifts,extents)
                        if score < best-0.0001:
                            best = score
                            best_angle = angle
                            best_shift = shift
            if best < start-0.0001:
                angles[ci] = best_angle
                shifts[ci] = best_shift
                changed = true
        if not changed:
            break
    _refine_rigid_seam_quality(links,adjacency,pivots,angles,shifts,extents,priority)
    # Only rigid transforms are committed. Rebuild bounds using every
    # vertex; integer packing translations preserve the resulting phase.
    for chart in charts:
        chart.min = Vector2(INF,INF)
        chart.max = Vector2(-INF,-INF)
    for t in tris:
        var ci: int = int(t.chart)
        var q: PackedVector2Array = t.xy
        var chart: Dictionary = charts[ci]
        for k in range(q.size()):
            q[k] = _rigid_grid_point(q[k],pivots[ci],angles[ci],shifts[ci])
            var lo: Vector2 = chart.min
            var hi: Vector2 = chart.max
            chart.min = lo.min(q[k])
            chart.max = hi.max(q[k])
        t.xy = q
    for chart in charts:
        var lo: Vector2 = chart.min
        chart.min = lo.floor()

## A second bounded search prioritizes seam quality instead of bottom
## alignment. Keep the original rigid solution unless the complete
## seam network has a non-regressing max, count and squared residual.
static func _refine_rigid_seam_quality(links: Array[Dictionary],adjacency: Array,pivots: PackedVector2Array,angles: PackedFloat32Array,shifts: PackedVector2Array,extents: PackedFloat32Array,priority: Array[Dictionary]) -> void:
    var baseline: Vector3 = _rigid_network_metrics(links,pivots,angles,shifts)
    var best: Vector3 = baseline
    var saved_angles: PackedFloat32Array = angles.duplicate()
    var saved_shifts: PackedVector2Array = shifts.duplicate()
    for sweep in range(5):
        var changed: bool = false
        var angle_step: float = deg_to_rad(5.0 if sweep < 2 else 2.0)
        var phase_step: float = 0.25 if sweep < 2 else 0.125
        for i in range(mini(128,priority.size())):
            var ci: int = int(priority[i].id)
            var best_angle: float = angles[ci]
            var best_shift: Vector2 = shifts[ci]
            var cost: float = _rigid_chart_cost(ci,best_angle,best_shift,links,adjacency[ci],pivots,angles,shifts,extents,true)
            var start: float = cost
            var candidates: Array[float] = [best_angle]
            if extents[ci] <= 128.0:
                for delta in [-2.0,-1.0,1.0,2.0]:
                    candidates.append(_rigid_quarter_angle(best_angle+float(delta)*angle_step))
            for candidate_angle in candidates:
                for dx in [-1.0,0.0,1.0]:
                    for dy in [-1.0,0.0,1.0]:
                        var shift: Vector2 = shifts[ci]+Vector2(float(dx),float(dy))*phase_step
                        shift -= shift.round()
                        var trial: float = _rigid_chart_cost(ci,candidate_angle,shift,links,adjacency[ci],pivots,angles,shifts,extents,true)
                        if trial < cost-0.0001:
                            cost = trial
                            best_angle = candidate_angle
                            best_shift = shift
            if cost < start-0.0001:
                angles[ci] = best_angle
                shifts[ci] = best_shift
                changed = true
        var metrics: Vector3 = _rigid_network_metrics(links,pivots,angles,shifts)
        if metrics.x <= best.x+0.00001 and metrics.y <= best.y and metrics.z < best.z-0.00001:
            best = metrics
            saved_angles = angles.duplicate()
            saved_shifts = shifts.duplicate()
        if not changed:
            break
    for ci in range(angles.size()):
        angles[ci] = saved_angles[ci]
        shifts[ci] = saved_shifts[ci]

static func _rigid_network_metrics(links: Array[Dictionary],pivots: PackedVector2Array,angles: PackedFloat32Array,shifts: PackedVector2Array) -> Vector3:
    var worst: float = 0.0
    var count: float = 0.0
    var sum: float = 0.0
    for record in links:
        var ca: int = int(record.a)
        var cb: int = int(record.b)
        var pa: PackedVector2Array = record.pa
        var pb: PackedVector2Array = record.pb
        var a0: Vector2 = _rigid_grid_point(pa[0],pivots[ca],angles[ca],shifts[ca])
        var a1: Vector2 = _rigid_grid_point(pa[1],pivots[ca],angles[ca],shifts[ca])
        var b0: Vector2 = _rigid_grid_point(pb[0],pivots[cb],angles[cb],shifts[cb])
        var b1: Vector2 = _rigid_grid_point(pb[1],pivots[cb],angles[cb],shifts[cb])
        var da: Vector2 = a1-a0
        var db: Vector2 = b1-b0
        var quarter: float = roundf(db.angle_to(da)/(PI*0.5))*(PI*0.5)
        var e0: Vector2 = a0-b0.rotated(quarter)
        e0 -= e0.round()
        var e1: Vector2 = e0+da-db.rotated(quarter)
        var residual: float = maxf(e0.length(),e1.length())
        worst = maxf(worst,residual)
        if residual > 0.25:
            count += 1.0
        sum += residual*residual
    return Vector3(worst,count,sum)

static func _rigid_quarter_angle(angle: float) -> float:
    return angle-roundf(angle/(PI*0.5))*(PI*0.5)

static func _rigid_grid_point(p: Vector2,pivot: Vector2,angle: float,shift: Vector2) -> Vector2:
    return (p-pivot).rotated(angle)+pivot+shift

static func _rigid_chart_cost(ci: int,angle: float,shift: Vector2,links: Array[Dictionary],incident: Array,pivots: PackedVector2Array,angles: PackedFloat32Array,shifts: PackedVector2Array,extents: PackedFloat32Array,seam_priority: bool = false) -> float:
    var cost: float = 0.0
    for li in incident:
        var record: Dictionary = links[li]
        var ca: int = int(record.a)
        var cb: int = int(record.b)
        var aa: float = angle if ca == ci else angles[ca]
        var ab: float = angle if cb == ci else angles[cb]
        var sa: Vector2 = shift if ca == ci else shifts[ca]
        var sb: Vector2 = shift if cb == ci else shifts[cb]
        var pa: PackedVector2Array = record.pa
        var pb: PackedVector2Array = record.pb
        var a0: Vector2 = _rigid_grid_point(pa[0],pivots[ca],aa,sa)
        var a1: Vector2 = _rigid_grid_point(pa[1],pivots[ca],aa,sa)
        var b0: Vector2 = _rigid_grid_point(pb[0],pivots[cb],ab,sb)
        var b1: Vector2 = _rigid_grid_point(pb[1],pivots[cb],ab,sb)
        var da: Vector2 = a1-a0
        var db: Vector2 = b1-b0
        var quarter: float = roundf(db.angle_to(da)/(PI*0.5))*(PI*0.5)
        var e0: Vector2 = a0-b0.rotated(quarter)
        e0 -= e0.round()
        var e1: Vector2 = e0+da-db.rotated(quarter)
        cost += float(record.weight)*(maxf(e0.length_squared(),e1.length_squared())+0.2*(e0.length_squared()+e1.length_squared()))
        if seam_priority:
            var residual: float = maxf(e0.length(),e1.length())
            cost += 2.0*pow(maxf(0.0,residual-1.0),2.0)+0.4*clampf((residual-0.25)/0.15,0.0,1.0)
    # The original bottom edge remains a preference, not a hard
    # constraint when adjacent surface orientations are incompatible.
    var span: float = clampf(extents[ci],1.0,24.0)
    var orientation_weight: float = 0.005 if seam_priority else 0.15
    cost += orientation_weight*span*span*sin(angle)*sin(angle)+(0.02 if seam_priority else 0.2)*shift.y*shift.y
    return cost

static func _local_edge_residual(tris: Array[Dictionary],link: Dictionary,ci: int,indices: Dictionary,coords: PackedVector2Array) -> float:
    var segments: Array[PackedVector2Array] = []
    for side in [0,1]:
        var id: int = int(link.ta) if side == 0 else int(link.tb)
        var edge: int = int(link.ea) if side == 0 else int(link.eb)
        var start: float = float(link.a0) if side == 0 else float(link.b0)
        var finish: float = float(link.a1) if side == 0 else float(link.b1)
        var t: Dictionary = tris[id]
        if int(t.chart) == ci and indices.has(id):
            var ids: PackedInt32Array = indices[id]
            var a: Vector2 = coords[ids[edge]]
            var b: Vector2 = coords[ids[(edge+1)%3]]
            segments.append(PackedVector2Array([a.lerp(b,start),a.lerp(b,finish)]))
        else:
            segments.append(_segment_uv(t,edge,start,finish,"xy"))
    var a: PackedVector2Array = segments[0]
    var b: PackedVector2Array = segments[1]
    var da: Vector2 = a[1]-a[0]
    var db: Vector2 = b[1]-b[0]
    if minf(da.length_squared(),db.length_squared()) < 0.00000001:
        return 1000.0
    var rotation: float = roundf(db.angle_to(da)/(PI*0.5))*(PI*0.5)
    var delta: Vector2 = a[0]-b[0].rotated(rotation)
    delta -= delta.round()
    return maxf(delta.length(),(delta+da-db.rotated(rotation)).length())

static func _refine_small_chart(tris: Array[Dictionary],chart: Dictionary,ci: int,members: Array,links: Array,density: int,balanced: bool = false,fine: bool = false) -> bool:
    var indices: Dictionary = {}
    var vertices: Dictionary = {}
    var points := PackedVector2Array()
    var original_points := PackedVector3Array()
    for raw in members:
        var id: int = int(raw)
        var t: Dictionary = tris[id]
        var ids := PackedInt32Array()
        for k in range(3):
            var p: Vector3 = t.p[k]
            var key: String = _vertex_key(p)
            if not vertices.has(key):
                vertices[key] = points.size()
                points.append(t.xy[k])
                original_points.append(p)
            var index: int = int(vertices[key])
            if points[index].distance_squared_to(t.xy[k]) > 0.000001:
                return false
            ids.append(index)
        indices[id] = ids
    if points.size() != members.size()+2:
        return false
    if members.size() == 2:
        var first: PackedInt32Array = indices[int(members[0])]
        var second: PackedInt32Array = indices[int(members[1])]
        var shared: int = 0
        for id in first:
            if second.has(id):
                shared += 1
        if shared != 2:
            return false
    var baseline: Vector3 = _refinement_score(tris,ci,links,indices,points)
    if baseline.x <= 0.25:
        return false
    var candidates: Array[PackedVector2Array] = []
    var rectified: bool = bool(chart.get("rectified",false))
    var snapped: PackedVector2Array = points.duplicate()
    for i in range(snapped.size()):
        snapped[i] = snapped[i].round()
    candidates.append(snapped)
    if rectified:
        # Retain rectangular boundaries, but allow different integer
        # widths and heights when the earlier group constraints conflict.
        var lo: Vector2 = chart.min
        var hi: Vector2 = chart.max
        for axis in range(2):
            for shift in [-2,-1,1,2]:
                if hi[axis]-lo[axis]+float(shift) < 1.0:
                    continue
                var q: PackedVector2Array = points.duplicate()
                for i in range(q.size()):
                    if absf(q[i][axis]-hi[axis]) < 0.001:
                        var v: Vector2 = q[i]
                        v[axis] += float(shift)
                        q[i] = v
                candidates.append(q)
    else:
        # Try matching each boundary to its neighbor (including phase).
        # A concave quad can remain concave while its long edge is aligned.
        for link in links:
            var own_a: bool = int(link.a) == ci
            var own_id: int = int(link.ta) if own_a else int(link.tb)
            var edge: int = int(link.ea) if own_a else int(link.eb)
            if not indices.has(own_id):
                continue
            var own_start: float = float(link.a0) if own_a else float(link.b0)
            var own_end: float = float(link.a1) if own_a else float(link.b1)
            if absf(own_end-own_start) < 0.9999:
                continue
            var ids: PackedInt32Array = indices[own_id]
            var v0: Vector2 = points[ids[edge]]
            var v1: Vector2 = points[ids[(edge+1)%3]]
            var own: Vector2 = (v1-v0)*(own_end-own_start)
            var other: PackedVector2Array
            if own_a:
                other = _segment_uv(tris[link.tb],link.eb,link.b0,link.b1,"xy")
            else:
                other = _segment_uv(tris[link.ta],link.ea,link.a0,link.a1,"xy")
            var target: Vector2 = other[1]-other[0]
            if minf(own.length(),target.length()) < 0.00001:
                continue
            var quarter: float = roundf(target.angle_to(own)/(PI*0.5))*(PI*0.5)
            target = target.rotated(quarter)
            var origin: Vector2 = other[0].rotated(quarter)
            origin -= origin.floor()
            var angle: float = own.angle_to(target)
            var ratio: float = clampf(target.length()/own.length(),0.45,2.0)
            var start: Vector2 = v0.lerp(v1,own_start)
            for quantize in [false,true]:
                var q := PackedVector2Array()
                for point in points:
                    var v: Vector2 = (point-start).rotated(angle)*ratio+origin
                    q.append(v.round() if quantize else v)
                candidates.append(q)
                # Reconstruct a single triangle's third corner using the
                # actual 3D edge distances, instead of its distorted UV.
                if points.size() == 3:
                    var k: int = ids[(edge+2)%3]
                    var i0: int = ids[edge]
                    var i1: int = ids[(edge+1)%3]
                    var d0: float = original_points[k].distance_to(original_points[i0])*density
                    var d1: float = original_points[k].distance_to(original_points[i1])*density
                    var base: Vector2 = q[i1]-q[i0]
                    var length: float = base.length()
                    if length > 0.00001:
                        var along: float = (d0*d0-d1*d1+length*length)/(2.0*length)
                        var altitude: float = sqrt(maxf(0.0,d0*d0-along*along))
                        if altitude > 0.00001:
                            var orientation: float = signf(base.cross(q[k]-q[i0]))
                            var tri: PackedVector2Array = q.duplicate()
                            var axis: Vector2 = base.normalized()
                            var perpendicular := Vector2(-axis.y,axis.x)
                            var v: Vector2 = q[i0]+axis*along+perpendicular*altitude*orientation
                            tri[k] = v.round() if quantize else v
                            candidates.append(tri)
                            if balanced and quantize:
                                # Search the nearby integer lattice with
                                # one edge anchored, allowing the other
                                # two edges to share the mismatch.
                                for dx in range(-3,4):
                                    for dy in range(-3,4):
                                        var trial: PackedVector2Array = tri.duplicate()
                                        trial[k] += Vector2(dx,dy)
                                        candidates.append(trial)
        # Small lattice moves can improve conflicting edges without
        # rotating the entire island away from its neighboring faces.
        for i in range(points.size()):
            for offset in [Vector2(-2,0),Vector2(-1,0),Vector2(1,0),Vector2(2,0),Vector2(0,-2),Vector2(0,-1),Vector2(0,1),Vector2(0,2),Vector2(-1,-1),Vector2(-1,1),Vector2(1,-1),Vector2(1,1)]:
                var q: PackedVector2Array = points.duplicate()
                q[i] += offset
                candidates.append(q)
        if fine:
            for i in range(points.size()):
                for offset in [Vector2(-0.5,0),Vector2(0.5,0),Vector2(0,-0.5),Vector2(0,0.5),Vector2(-0.5,-0.5),Vector2(0.5,0.5),Vector2(-0.5,0.5),Vector2(0.5,-0.5)]:
                    var q: PackedVector2Array = points.duplicate()
                    q[i] += offset
                    candidates.append(q)
    var best: PackedVector2Array = points
    var best_score: Vector3 = baseline
    var base_density_cost: float = _grid_density_cost(members,indices,original_points,points,density) if fine else 0.0
    var best_cost: float = baseline.z+base_density_cost*0.5
    for q in candidates:
        if not _refinement_valid(members,indices,original_points,points,q,density):
            continue
        var score: Vector3 = _refinement_score(tris,ci,links,indices,q)
        # Never trade a worse maximum or more bad edges for a local win.
        var accepted: bool = _accept_balanced_score(baseline,score,balanced)
        if fine:
            accepted = score.x <= baseline.x+0.0001 and (score.y <= baseline.y or (score.y <= baseline.y+1.0 and score.x <= baseline.x-0.20))
        if not accepted or score.z > baseline.z+0.0001:
            continue
        var density_cost: float = _grid_density_cost(members,indices,original_points,q,density) if fine else 0.0
        if fine and density_cost > base_density_cost+0.10:
            continue
        var cost: float = score.z+density_cost*0.5
        if cost < best_cost-0.0001:
            best = q
            best_score = score
            best_cost = cost
    if best_cost >= baseline.z+base_density_cost*0.5-0.0001:
        return false
    var lo: Vector2 = best[0]
    var hi: Vector2 = best[0]
    for point in best:
        lo = lo.min(point)
        hi = hi.max(point)
    for id in members:
        var ids: PackedInt32Array = indices[id]
        tris[id].xy = PackedVector2Array([best[ids[0]],best[ids[1]],best[ids[2]]])
    chart.min = lo.floor()
    chart.max = hi
    return true

## In the second pass a severe error may be traded for at most two
## smaller mismatches, but never for a worse maximum or larger total cost.
static func _accept_balanced_score(before: Vector3,after: Vector3,balanced: bool) -> bool:
    if after.x > before.x+0.0001:
        return false
    if after.y <= before.y:
        return true
    return balanced and before.x > 2.0 and after.x <= before.x-0.35 and after.y <= before.y+2.0

## The exact rectangle seams form dimension-equivalence groups. Adjust
## an entire group together so a good seam does not need to be broken
## before an incompatible 5/8px seam can be improved.
static func _balance_rectified_groups(tris: Array[Dictionary],charts: Array[Dictionary],density: int) -> void:
    var links: Array[Dictionary] = _seam_segments(tris)
    var parent := PackedInt32Array()
    parent.resize(charts.size()*2)
    var members: Array = []
    var adjacency: Array = []
    for ci in range(charts.size()):
        members.append([])
        adjacency.append([])
        parent[ci*2] = ci*2
        parent[ci*2+1] = ci*2+1
    for i in range(tris.size()):
        (members[int(tris[i].chart)] as Array).append(i)
    var mismatches: Array[Dictionary] = []
    for i in range(links.size()):
        var link: Dictionary = links[i]
        var ca: int = int(link.a)
        var cb: int = int(link.b)
        (adjacency[ca] as Array).append(i)
        (adjacency[cb] as Array).append(i)
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
        var aa: int = 0 if da.x > da.y else 1
        var ab: int = 0 if db.x > db.y else 1
        var sa: Vector2 = charts[ca].max-charts[ca].min
        var sb: Vector2 = charts[cb].max-charts[cb].min
        if absf(da[aa]-sa[aa]) > 0.001 or absf(db[ab]-sb[ab]) > 0.001:
            continue
        var diff: float = absf(da[aa]-db[ab])
        if diff < 0.001:
            _join(parent,ca*2+aa,cb*2+ab)
        elif diff > 0.25:
            mismatches.append({"a":ca*2+aa,"b":cb*2+ab,"diff":diff})
    var groups: Dictionary = {}
    for ci in range(charts.size()):
        if not bool(charts[ci].get("rectified",false)):
            continue
        for axis in range(2):
            var id: int = ci*2+axis
            var root: int = _root(parent,id)
            if not groups.has(root):
                groups[root] = []
            (groups[root] as Array).append(id)
    mismatches.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:
        return int(a.a) < int(b.a) if float(a.diff) == float(b.diff) else float(a.diff) > float(b.diff))
    for n in range(mini(64,mismatches.size())):
        var item: Dictionary = mismatches[n]
        var root_a: int = _root(parent,int(item.a))
        var root_b: int = _root(parent,int(item.b))
        if root_a == root_b:
            continue
        var group_a: Array = groups[root_a]
        var group_b: Array = groups[root_b]
        if group_a.size()+group_b.size() > 96:
            continue
        var first_a: int = int(group_a[0])
        var first_b: int = int(group_b[0])
        var size_a: Vector2 = charts[first_a/2].max-charts[first_a/2].min
        var size_b: Vector2 = charts[first_b/2].max-charts[first_b/2].min
        var old_a: int = roundi(size_a[first_a%2])
        var old_b: int = roundi(size_b[first_b%2])
        if old_a == old_b or mini(old_a,old_b) < 1:
            continue
        var affected: Dictionary = {}
        for id in group_a+group_b:
            affected[int(id)/2] = true
        var local_ids: Dictionary = {}
        var original: Dictionary = {}
        for ci in affected:
            for li in adjacency[ci]:
                local_ids[li] = true
            for ti in members[ci]:
                original[ti] = (tris[ti].xy as PackedVector2Array).duplicate()
        var local: Array = []
        for li in local_ids:
            local.append(links[li])
        var before: Vector3 = _refinement_score(tris,-1,local,{},PackedVector2Array())
        var best_score: Vector3 = before
        var best: int = -1
        # Candidate common sizes around the midpoint and both endpoints.
        var choices: Array[int] = [old_a,old_b,floori((old_a+old_b)*0.5),ceili((old_a+old_b)*0.5)]
        for target in choices:
            if target < 1:
                continue
            var scales: Dictionary = {}
            for id in group_a+group_b:
                var ci: int = int(id)/2
                var axis: int = int(id)%2
                var scale: Vector2 = scales.get(ci,Vector2.ONE)
                var dim: Vector2 = charts[ci].max-charts[ci].min
                scale[axis] = float(target)/maxf(1.0,dim[axis])
                scales[ci] = scale
            var valid: bool = true
            for ci in affected:
                var scale: Vector2 = scales[ci]
                var lo: Vector2 = charts[ci].min
                for ti in members[ci]:
                    var old: PackedVector2Array = original[ti]
                    var q := PackedVector2Array()
                    for point in old:
                        q.append((point-lo)*scale+lo)
                    var t: Dictionary = tris[ti]
                    var index_map: Dictionary = {}
                    index_map[ti] = PackedInt32Array([0,1,2])
                    if not _refinement_valid([ti],index_map,t.p,old,q,density):
                        valid = false
                    t.xy = q
            if valid:
                var score: Vector3 = _refinement_score(tris,-1,local,{},PackedVector2Array())
                if _accept_balanced_score(before,score,true) and score.z < best_score.z-0.0001:
                    best = target
                    best_score = score
            for ti in original:
                tris[ti].xy = original[ti]
        if best < 1:
            continue
        var final_scales: Dictionary = {}
        for id in group_a+group_b:
            var ci: int = int(id)/2
            var axis: int = int(id)%2
            var scale: Vector2 = final_scales.get(ci,Vector2.ONE)
            var dim: Vector2 = charts[ci].max-charts[ci].min
            scale[axis] = float(best)/maxf(1.0,dim[axis])
            final_scales[ci] = scale
        for ci in affected:
            var lo: Vector2 = charts[ci].min
            var scale: Vector2 = final_scales[ci]
            for ti in members[ci]:
                var old: PackedVector2Array = original[ti]
                var q := PackedVector2Array()
                for point in old:
                    q.append((point-lo)*scale+lo)
                tris[ti].xy = q
            charts[ci].max = lo+(charts[ci].max-lo)*scale
        # All boundaries in the two accepted groups now agree. Reuse
        # the union on subsequent mismatches without breaking them.
        _join(parent,root_a,root_b)
        var root: int = _root(parent,root_a)
        groups[root] = group_a+group_b

## Penalize metric stretch in both directions. Count each triangle edge
## once per incident triangle, as in the original face density report.
static func _grid_density_cost(members: Array,indices: Dictionary,world: PackedVector3Array,points: PackedVector2Array,density: int) -> float:
    var cost: float = 0.0
    for id in members:
        var ids: PackedInt32Array = indices[id]
        for k in range(3):
            var i: int = ids[k]
            var j: int = ids[(k+1)%3]
            var length: float = world[i].distance_to(world[j])*density
            var ratio: float = points[i].distance_to(points[j])/maxf(0.000001,length)
            var error: float = log(maxf(0.000001,ratio))
            cost += error*error
    return cost

static func _mirror_grid_point(p: Vector3,axis_x: float) -> Vector3:
    return Vector3(2.0*axis_x-p.x,p.y,p.z)

static func _grid_chart_signature(tris: Array[Dictionary],members: Array,axis_x: float,mirror: bool) -> String:
    var keys: PackedStringArray = []
    for id in members:
        var triangle: PackedStringArray = []
        for p in tris[id].p:
            triangle.append(_vertex_key(_mirror_grid_point(p,axis_x) if mirror else p))
        triangle.sort()
        keys.append(";".join(triangle))
    keys.sort()
    return "|".join(keys)

## Only exact geometric mirror counterparts (including triangulation)
## qualify. Copy a candidate UV shape with the correct winding, and keep
## it only if it does not worsen the combined incident seam metrics or
## density. Do not force asymmetric parts into artificial symmetry.
static func _match_mirrored_grid_shapes(tris: Array[Dictionary],charts: Array[Dictionary],density: int) -> void:
    var members: Array = []
    var adjacency: Array = []
    var lo_x: float = INF
    var hi_x: float = -INF
    for ci in range(charts.size()):
        members.append([])
        adjacency.append([])
    for i in range(tris.size()):
        (members[int(tris[i].chart)] as Array).append(i)
        for p in tris[i].p:
            lo_x = minf(lo_x,p.x)
            hi_x = maxf(hi_x,p.x)
    var axis_x: float = (lo_x+hi_x)*0.5
    var links: Array[Dictionary] = _seam_segments(tris)
    for i in range(links.size()):
        (adjacency[int(links[i].a)] as Array).append(i)
        (adjacency[int(links[i].b)] as Array).append(i)
    var lookup: Dictionary = {}
    for ci in range(charts.size()):
        if members[ci].size() < 1 or members[ci].size() > 2:
            continue
        var signature: String = _grid_chart_signature(tris,members[ci],axis_x,false)
        if lookup.has(signature):
            lookup[signature] = -1
        else:
            lookup[signature] = ci
    var budget: int = 128
    for ca in range(charts.size()):
        if budget <= 0:
            break
        if members[ca].size() < 1 or members[ca].size() > 2:
            continue
        var signature: String = _grid_chart_signature(tris,members[ca],axis_x,true)
        var cb: int = int(lookup.get(signature,-1))
        if cb <= ca or members[cb].size() != members[ca].size():
            continue
        if int(lookup.get(_grid_chart_signature(tris,members[ca],axis_x,false),-1)) != ca:
            continue
        if bool(charts[ca].get("rectified",false)) != bool(charts[cb].get("rectified",false)):
            continue
        var local_ids: Dictionary = {}
        for li in adjacency[ca]+adjacency[cb]:
            local_ids[li] = true
        var local: Array = []
        for li in local_ids:
            local.append(links[li])
        if local.is_empty():
            continue
        var baseline: Vector3 = _refinement_score(tris,-1,local,{},PackedVector2Array())
        if baseline.x <= 0.25:
            continue
        budget -= 1
        var best: Dictionary = {}
        var best_chart: int = -1
        var best_cost: float = INF
        for source_chart in [ca,cb]:
            var dest: int = cb if source_chart == ca else ca
            var source_uv: Dictionary = {}
            var consistent: bool = true
            for ti in members[source_chart]:
                var t: Dictionary = tris[ti]
                for k in range(3):
                    var key: String = _vertex_key(_mirror_grid_point(t.p[k],axis_x))
                    if source_uv.has(key) and (source_uv[key] as Vector2).distance_squared_to(t.xy[k]) > 0.000001:
                        consistent = false
                    source_uv[key] = t.xy[k]
            if not consistent:
                continue
            var original: Dictionary = {}
            var base_density: float = 0.0
            for ti in members[dest]:
                var t: Dictionary = tris[ti]
                original[ti] = (t.xy as PackedVector2Array).duplicate()
                var index_map: Dictionary = {}
                index_map[ti] = PackedInt32Array([0,1,2])
                base_density += _grid_density_cost([ti],index_map,t.p,t.xy,density)
            for reflected in [false,true]:
                for quarter in range(4):
                    var candidate: Dictionary = {}
                    var cost_density: float = 0.0
                    var valid: bool = true
                    for ti in members[dest]:
                        var t: Dictionary = tris[ti]
                        var old: PackedVector2Array = original[ti]
                        var q := PackedVector2Array()
                        for k in range(3):
                            var key: String = _vertex_key(t.p[k])
                            if not source_uv.has(key):
                                valid = false
                                break
                            var uv: Vector2 = source_uv[key]
                            if reflected:
                                uv.x = -uv.x
                            # Integer quarter rotations avoid floating phase drift.
                            for step in range(quarter):
                                uv = Vector2(-uv.y,uv.x)
                            q.append(uv)
                        if q.size() != 3:
                            valid = false
                            break
                        var index_map: Dictionary = {}
                        index_map[ti] = PackedInt32Array([0,1,2])
                        if not _refinement_valid([ti],index_map,t.p,old,q,density):
                            valid = false
                            break
                        cost_density += _grid_density_cost([ti],index_map,t.p,q,density)
                        candidate[ti] = q
                        t.xy = q
                    if valid and cost_density <= base_density+0.0001:
                        var score: Vector3 = _refinement_score(tris,-1,local,{},PackedVector2Array())
                        var cost: float = score.z+cost_density*0.5
                        if score.x <= baseline.x+0.0001 and score.y <= baseline.y and score.z <= baseline.z+0.0001 and cost < best_cost:
                            best_cost = cost
                            best = candidate
                            best_chart = dest
                    for ti in original:
                        tris[ti].xy = original[ti]
        if best_chart < 0:
            continue
        var lo := Vector2(INF,INF)
        var hi := Vector2(-INF,-INF)
        for ti in best:
            tris[ti].xy = best[ti]
            for uv in best[ti]:
                lo = lo.min(uv)
                hi = hi.max(uv)
        charts[best_chart].min = lo.floor()
        charts[best_chart].max = hi

## Compare the final candidate against the previous stable pipeline.
## A fine pass may improve some islands but must not accumulate more
## threshold failures while leaving the worst residual unchanged.
static func _finish_grid_refinement(tris: Array[Dictionary],charts: Array[Dictionary],density: int) -> void:
    var links: Array[Dictionary] = _seam_segments(tris)
    var baseline: Vector3 = _refinement_score(tris,-1,links,{},PackedVector2Array())
    var saved: Array[PackedVector2Array] = []
    for t in tris:
        saved.append((t.xy as PackedVector2Array).duplicate())
    var old_charts: Array[Dictionary] = charts.duplicate(true)
    _refine_residual_grids(tris,charts,density,true,true)
    _match_mirrored_grid_shapes(tris,charts,density)
    var trial: Vector3 = _refinement_score(tris,-1,links,{},PackedVector2Array())
    if trial.x > baseline.x+0.0001 or trial.y > baseline.y or trial.z > baseline.z+0.0001:
        for i in range(tris.size()):
            tris[i].xy = saved[i]
        for i in range(charts.size()):
            charts[i] = old_charts[i]
    _adapt_quad_boundaries(tris,charts,links,density)
    _refine_paired_seams(tris,charts,links,density)
    _relax_grid_network(tris,charts,links,density)

## Prefer rectangles, but do not require equal opposite edge lengths
## on every face. A one-corner shift creates a trapezoidal UV without
## changing the mesh, preserves three axis-aligned sides, and can match
## tapered geometry where an integer rectangle forces a mismatch.
static func _adapt_quad_boundaries(tris: Array[Dictionary],charts: Array[Dictionary],links: Array[Dictionary],density: int) -> void:
    var members: Array = []
    var adjacency: Array = []
    for ci in range(charts.size()):
        members.append([])
        adjacency.append([])
    for i in range(tris.size()):
        (members[int(tris[i].chart)] as Array).append(i)
    for link in links:
        (adjacency[int(link.a)] as Array).append(link)
        (adjacency[int(link.b)] as Array).append(link)
    for pass_index in range(3):
        var priority: Array[Dictionary] = []
        for ci in range(charts.size()):
            if not bool(charts[ci].get("rectified",false)) or members[ci].size() != 2:
                continue
            var score: Vector3 = _refinement_score(tris,-1,adjacency[ci],{},PackedVector2Array())
            if score.x > 1.0:
                priority.append({"chart":ci,"worst":score.x})
        priority.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:
            return int(a.chart) < int(b.chart) if float(a.worst) == float(b.worst) else float(a.worst) > float(b.worst))
        var changed: bool = false
        for i in range(mini(64,priority.size())):
            var ci: int = int(priority[i].chart)
            if _adapt_one_quad(tris,charts[ci],ci,members[ci],adjacency[ci],density):
                changed = true
        if not changed:
            break

static func _adapt_one_quad(tris: Array[Dictionary],chart: Dictionary,ci: int,members: Array,links: Array,density: int) -> bool:
    var ids_by_triangle: Dictionary = {}
    var unique: Dictionary = {}
    var points := PackedVector2Array()
    var world := PackedVector3Array()
    for ti in members:
        var t: Dictionary = tris[ti]
        var ids := PackedInt32Array()
        for k in range(3):
            var key: String = _vertex_key(t.p[k])
            if not unique.has(key):
                unique[key] = points.size()
                points.append(t.xy[k])
                world.append(t.p[k])
            var index: int = int(unique[key])
            if points[index].distance_squared_to(t.xy[k]) > 0.000001:
                return false
            ids.append(index)
        ids_by_triangle[ti] = ids
    if points.size() != 4:
        return false
    var lo: Vector2 = points[0]
    var hi: Vector2 = points[0]
    for point in points:
        lo = lo.min(point)
        hi = hi.max(point)
    for point in points:
        if minf(absf(point.x-lo.x),absf(point.x-hi.x)) > 0.001 or minf(absf(point.y-lo.y),absf(point.y-hi.y)) > 0.001:
            return false
    var before: Vector3 = _refinement_score(tris,ci,links,ids_by_triangle,points)
    if before.x <= 1.0:
        return false
    var density_before: float = _grid_density_cost(members,ids_by_triangle,world,points,density)
    var best: PackedVector2Array = points
    var best_cost: float = before.z+density_before*0.5
    # Preserve the existing integer grid phase. Evaluate half-texel and
    # integer tapers; each moves just one corner along one boundary.
    for k in range(4):
        for axis in range(2):
            for step in [-2.0,-1.5,-1.0,-0.5,0.5,1.0,1.5,2.0]:
                var q: PackedVector2Array = points.duplicate()
                var v: Vector2 = q[k]
                v[axis] += step
                q[k] = v
                # Do not cross or collapse an axis-aligned boundary.
                var opposite: float = hi[axis] if absf(points[k][axis]-lo[axis]) < 0.001 else lo[axis]
                if (v[axis]-opposite)*(points[k][axis]-opposite) <= 0.25:
                    continue
                if not _refinement_valid(members,ids_by_triangle,world,points,q,density):
                    continue
                var density_cost: float = _grid_density_cost(members,ids_by_triangle,world,q,density)
                if density_cost > density_before+0.10:
                    continue
                var score: Vector3 = _refinement_score(tris,ci,links,ids_by_triangle,q)
                if score.x > before.x+0.0001 or score.y > before.y or score.z > before.z+0.0001:
                    continue
                var cost: float = score.z+density_cost*0.5
                if cost < best_cost-0.0001:
                    best = q
                    best_cost = cost
    if best_cost >= before.z+density_before*0.5-0.0001:
        return false
    lo = best[0]
    hi = best[0]
    for point in best:
        lo = lo.min(point)
        hi = hi.max(point)
    for ti in members:
        var ids: PackedInt32Array = ids_by_triangle[ti]
        tris[ti].xy = PackedVector2Array([best[ids[0]],best[ids[1]],best[ids[2]]])
    chart.min = lo.floor()
    chart.max = hi
    chart.rectified = false
    return true

## Solve a shared boundary on both UV islands at once. The target is
## expressed in the first island's texel coordinates modulo a quarter
## rotation and integer translation; no geometric vertex is moved.
static func _refine_paired_seams(tris: Array[Dictionary],charts: Array[Dictionary],links: Array[Dictionary],density: int) -> void:
    var members: Array = []
    var adjacency: Array = []
    for ci in range(charts.size()):
        members.append([])
        adjacency.append([])
    for ti in range(tris.size()):
        (members[int(tris[ti].chart)] as Array).append(ti)
    for li in range(links.size()):
        var link: Dictionary = links[li]
        (adjacency[int(link.a)] as Array).append(li)
        (adjacency[int(link.b)] as Array).append(li)
    for sweep in range(3):
        var priority: Array[Dictionary] = []
        for li in range(links.size()):
            var link: Dictionary = links[li]
            if members[int(link.a)].size() > 2 or members[int(link.b)].size() > 2:
                continue
            if absf(float(link.a1)-float(link.a0)) < 0.9999 or absf(float(link.b1)-float(link.b0)) < 0.9999:
                continue
            var residual: float = _local_edge_residual(tris,link,-1,{},PackedVector2Array())
            if residual > 1.0:
                priority.append({"id":li,"residual":residual})
        priority.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:
            return int(a.id) < int(b.id) if float(a.residual) == float(b.residual) else float(a.residual) > float(b.residual))
        var changed: bool = false
        for i in range(mini(48,priority.size())):
            var link: Dictionary = links[int(priority[i].id)]
            var ca: int = int(link.a)
            var cb: int = int(link.b)
            if _local_edge_residual(tris,link,-1,{},PackedVector2Array()) <= 1.0:
                continue
            var local_ids: Dictionary = {}
            for li in adjacency[ca]+adjacency[cb]:
                local_ids[li] = true
            var local: Array = []
            for li in local_ids:
                local.append(links[li])
            if _try_paired_seam(tris,charts,link,members[ca],members[cb],local,density):
                changed = true
        if not changed:
            break

static func _paired_chart_data(tris: Array[Dictionary],members: Array) -> Dictionary:
    var points := PackedVector2Array()
    var world := PackedVector3Array()
    var unique: Dictionary = {}
    var indices: Dictionary = {}
    for ti in members:
        var t: Dictionary = tris[ti]
        var ids := PackedInt32Array()
        for k in range(3):
            var key: String = _vertex_key(t.p[k])
            if not unique.has(key):
                unique[key] = points.size()
                points.append(t.xy[k])
                world.append(t.p[k])
            var idx: int = int(unique[key])
            if points[idx].distance_squared_to(t.xy[k]) > 0.000001:
                return {}
            ids.append(idx)
        indices[ti] = ids
    if points.size() != members.size()+2:
        return {}
    if members.size() == 2:
        var first: PackedInt32Array = indices[members[0]]
        var second: PackedInt32Array = indices[members[1]]
        var count: int = 0
        for idx in first:
            if second.has(idx):
                count += 1
        if count != 2:
            return {}
    return {"points":points,"world":world,"indices":indices}

static func _paired_move(points: PackedVector2Array,i0: int,i1: int,d0: Vector2,d1: Vector2,spread: bool) -> PackedVector2Array:
    var q: PackedVector2Array = points.duplicate()
    var edge: Vector2 = points[i1]-points[i0]
    if spread and edge.length_squared() > 0.000001:
        for k in range(points.size()):
            var t: float = clampf((points[k]-points[i0]).dot(edge)/edge.length_squared(),0.0,1.0)
            q[k] += d0.lerp(d1,t)
    q[i0] = points[i0]+d0
    q[i1] = points[i1]+d1
    return q

static func _paired_write(tris: Array[Dictionary],members: Array,indices: Dictionary,q: PackedVector2Array) -> void:
    for ti in members:
        var ids: PackedInt32Array = indices[ti]
        tris[ti].xy = PackedVector2Array([q[ids[0]],q[ids[1]],q[ids[2]]])

static func _paired_bounds(chart: Dictionary,q: PackedVector2Array) -> void:
    var lo: Vector2 = q[0]
    var hi: Vector2 = q[0]
    for point in q:
        lo = lo.min(point)
        hi = hi.max(point)
    chart.min = lo.floor()
    chart.max = hi
    if bool(chart.get("rectified",false)):
        for point in q:
            if minf(absf(point.x-lo.x),absf(point.x-hi.x)) > 0.001 or minf(absf(point.y-lo.y),absf(point.y-hi.y)) > 0.001:
                chart.rectified = false
                break

static func _try_paired_seam(tris: Array[Dictionary],charts: Array[Dictionary],link: Dictionary,ma: Array,mb: Array,local: Array,density: int) -> bool:
    var a: Dictionary = _paired_chart_data(tris,ma)
    var b: Dictionary = _paired_chart_data(tris,mb)
    if a.is_empty() or b.is_empty():
        return false
    var pa: PackedVector2Array = a.points
    var pb: PackedVector2Array = b.points
    var ia: PackedInt32Array = a.indices[int(link.ta)]
    var ib: PackedInt32Array = b.indices[int(link.tb)]
    var ea: int = int(link.ea)
    var eb: int = int(link.eb)
    var a0: int = ia[ea] if float(link.a0) < float(link.a1) else ia[(ea+1)%3]
    var a1: int = ia[(ea+1)%3] if float(link.a0) < float(link.a1) else ia[ea]
    var b0: int = ib[eb] if float(link.b0) < float(link.b1) else ib[(eb+1)%3]
    var b1: int = ib[(eb+1)%3] if float(link.b0) < float(link.b1) else ib[eb]
    var da: Vector2 = pa[a1]-pa[a0]
    var db: Vector2 = pb[b1]-pb[b0]
    if minf(da.length(),db.length()) < 0.00001:
        return false
    var quarter: float = roundf(db.angle_to(da)/(PI*0.5))*(PI*0.5)
    var d0: Vector2 = pa[a0]-pb[b0].rotated(quarter)
    d0 -= d0.round()
    var d1: Vector2 = d0+da-db.rotated(quarter)
    var before: Vector3 = _refinement_score(tris,-1,local,{},PackedVector2Array())
    var density_before: float = _grid_density_cost(ma,a.indices,a.world,pa,density)+_grid_density_cost(mb,b.indices,b.world,pb,density)
    var best_cost: float = before.z+density_before*0.5
    var best_a: PackedVector2Array = pa
    var best_b: PackedVector2Array = pb
    var best_error: float = maxf(d0.length(),d1.length())
    for weight in [0.0,0.25,0.5,0.75,1.0]:
        for strength in [0.5,1.0]:
            for spread in [false,true]:
                var qa: PackedVector2Array = _paired_move(pa,a0,a1,-d0*float(weight)*float(strength),-d1*float(weight)*float(strength),spread)
                var qb: PackedVector2Array = _paired_move(pb,b0,b1,d0.rotated(-quarter)*(1.0-float(weight))*float(strength),d1.rotated(-quarter)*(1.0-float(weight))*float(strength),spread)
                if not _refinement_valid(ma,a.indices,a.world,pa,qa,density) or not _refinement_valid(mb,b.indices,b.world,pb,qb,density):
                    continue
                var density_cost: float = _grid_density_cost(ma,a.indices,a.world,qa,density)+_grid_density_cost(mb,b.indices,b.world,qb,density)
                if density_cost > density_before+0.15:
                    continue
                _paired_write(tris,ma,a.indices,qa)
                _paired_write(tris,mb,b.indices,qb)
                var score: Vector3 = _refinement_score(tris,-1,local,{},PackedVector2Array())
                var error: float = _local_edge_residual(tris,link,-1,{},PackedVector2Array())
                var cost: float = score.z+density_cost*0.5
                if score.x <= before.x+0.0001 and score.y <= before.y and score.z <= before.z+0.0001 and error < best_error-0.0001 and cost < best_cost-0.0001:
                    best_a = qa
                    best_b = qb
                    best_cost = cost
                    best_error = error
                _paired_write(tris,ma,a.indices,pa)
                _paired_write(tris,mb,b.indices,pb)
    if best_cost >= before.z+density_before*0.5-0.0001:
        return false
    _paired_write(tris,ma,a.indices,best_a)
    _paired_write(tris,mb,b.indices,best_b)
    _paired_bounds(charts[int(link.a)],best_a)
    _paired_bounds(charts[int(link.b)],best_b)
    return true

## Joint relaxation of a network of small charts. Each iteration reads
## the same UV state, accumulates all incident seam endpoint equations,
## then applies the proposed displacements simultaneously. Intermediate
## states may be worse; only the best globally non-regressing state is
## committed. This avoids moving a mismatch around a closed loop.
static func _relax_grid_network(tris: Array[Dictionary],charts: Array[Dictionary],links: Array[Dictionary],density: int) -> void:
    var members: Array = []
    for ci in range(charts.size()):
        members.append([])
    for ti in range(tris.size()):
        (members[int(tris[ti].chart)] as Array).append(ti)
    var active: Dictionary = {}
    var priority: Array[Dictionary] = []
    for li in range(links.size()):
        var link: Dictionary = links[li]
        var residual: float = _local_edge_residual(tris,link,-1,{},PackedVector2Array())
        if residual > 1.0:
            priority.append({"id":li,"residual":residual})
    priority.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:
        return int(a.id) < int(b.id) if float(a.residual) == float(b.residual) else float(a.residual) > float(b.residual))
    for item in priority:
        var link: Dictionary = links[int(item.id)]
        for ci in [int(link.a),int(link.b)]:
            if active.size() >= 96:
                break
            if members[ci].size() >= 1 and members[ci].size() <= 2 and not active.has(ci):
                var data: Dictionary = _paired_chart_data(tris,members[ci])
                if not data.is_empty():
                    active[ci] = data
    var seeds: Dictionary = active.duplicate()
    for link in links:
        if active.size() >= 96:
            break
        var ca: int = int(link.a)
        var cb: int = int(link.b)
        if seeds.has(ca) == seeds.has(cb):
            continue
        var ci: int = cb if seeds.has(ca) else ca
        if not active.has(ci) and members[ci].size() >= 1 and members[ci].size() <= 2:
            var data: Dictionary = _paired_chart_data(tris,members[ci])
            if not data.is_empty():
                active[ci] = data
    if active.is_empty():
        return
    var relevant: Array[Dictionary] = []
    for link in links:
        if active.has(int(link.a)) or active.has(int(link.b)):
            relevant.append(link)
    var baseline: Vector3 = _refinement_score(tris,-1,relevant,{},PackedVector2Array())
    var baseline_severe: int = _network_severe_count(tris,relevant)
    var baseline_density: float = 0.0
    var current: Dictionary = {}
    var best: Dictionary = {}
    for ci in active:
        var data: Dictionary = active[ci]
        current[ci] = data.points
        best[ci] = data.points
        baseline_density += _grid_density_cost(members[ci],data.indices,data.world,data.points,density)
    var best_cost: float = baseline.z+baseline_density*0.5+float(baseline_severe)*2.0
    # Try two regularization levels from the same initial solution.
    # Bound work independent of the total number of original faces.
    for regularization in [0.35,0.8]:
        for ci in active:
            var data: Dictionary = active[ci]
            current[ci] = data.points
            _paired_write(tris,members[ci],data.indices,data.points)
        for iteration in range(28):
            var gradients: Dictionary = {}
            var weights: Dictionary = {}
            for ci in active:
                var data: Dictionary = active[ci]
                var q: PackedVector2Array = current[ci]
                var old: PackedVector2Array = data.points
                var g := PackedVector2Array()
                var w := PackedFloat32Array()
                for k in range(q.size()):
                    g.append((old[k]-q[k])*float(regularization))
                    w.append(float(regularization))
                gradients[ci] = g
                weights[ci] = w
            for link in relevant:
                var a: PackedVector2Array = _segment_uv(tris[link.ta],link.ea,link.a0,link.a1,"xy")
                var b: PackedVector2Array = _segment_uv(tris[link.tb],link.eb,link.b0,link.b1,"xy")
                var da: Vector2 = a[1]-a[0]
                var db: Vector2 = b[1]-b[0]
                if minf(da.length_squared(),db.length_squared()) < 0.00000001:
                    continue
                var quarter: float = roundf(db.angle_to(da)/(PI*0.5))*(PI*0.5)
                var e0: Vector2 = a[0]-b[0].rotated(quarter)
                e0 -= e0.round()
                var e1: Vector2 = e0+da-db.rotated(quarter)
                var severity: float = maxf(e0.length(),e1.length())
                var weight: float = 1.0+minf(4.0,severity*severity)
                for endpoint in range(2):
                    var error: Vector2 = e0 if endpoint == 0 else e1
                    for side in range(2):
                        var ci: int = int(link.a) if side == 0 else int(link.b)
                        if not active.has(ci):
                            continue
                        var ti: int = int(link.ta) if side == 0 else int(link.tb)
                        var edge: int = int(link.ea) if side == 0 else int(link.eb)
                        var fraction: float = float(link.a0 if endpoint == 0 else link.a1) if side == 0 else float(link.b0 if endpoint == 0 else link.b1)
                        var correction: Vector2 = -error if side == 0 else error.rotated(-quarter)
                        var data: Dictionary = active[ci]
                        var ids: PackedInt32Array = data.indices[ti]
                        var g: PackedVector2Array = gradients[ci]
                        var w: PackedFloat32Array = weights[ci]
                        for k in range(2):
                            var idx: int = ids[(edge+k)%3]
                            var factor: float = (1.0-fraction) if k == 0 else fraction
                            g[idx] += correction*factor*weight
                            w[idx] += factor*factor*weight
                        gradients[ci] = g
                        weights[ci] = w
            for ci in active:
                var data: Dictionary = active[ci]
                var q: PackedVector2Array = current[ci]
                var original: PackedVector2Array = data.points
                var g: PackedVector2Array = gradients[ci]
                var w: PackedFloat32Array = weights[ci]
                for step in [0.35,0.15]:
                    var candidate: PackedVector2Array = q.duplicate()
                    for k in range(q.size()):
                        var v: Vector2 = q[k]+g[k]/maxf(0.0001,w[k])*float(step)
                        candidate[k] = original[k]+(v-original[k]).limit_length(1.5)
                    if not _refinement_valid(members[ci],data.indices,data.world,original,candidate,density):
                        continue
                    if members[ci].size() == 2:
                        var ia: PackedInt32Array = data.indices[members[ci][0]]
                        var ib: PackedInt32Array = data.indices[members[ci][1]]
                        if _overlaps(PackedVector2Array([candidate[ia[0]],candidate[ia[1]],candidate[ia[2]]]),PackedVector2Array([candidate[ib[0]],candidate[ib[1]],candidate[ib[2]]])):
                            continue
                    current[ci] = candidate
                    break
            for ci in active:
                var data: Dictionary = active[ci]
                _paired_write(tris,members[ci],data.indices,current[ci])
            if iteration%4 != 3:
                continue
            var score: Vector3 = _refinement_score(tris,-1,relevant,{},PackedVector2Array())
            var severe: int = _network_severe_count(tris,relevant)
            if score.x > baseline.x+0.0001 or score.y > baseline.y or severe > baseline_severe or score.z > baseline.z+0.0001:
                continue
            var density_cost: float = 0.0
            for ci in active:
                var data: Dictionary = active[ci]
                density_cost += _grid_density_cost(members[ci],data.indices,data.world,current[ci],density)
            if density_cost > baseline_density+0.05*float(active.size()):
                continue
            var cost: float = score.z+density_cost*0.5+float(severe)*2.0
            if cost < best_cost-0.0001:
                best_cost = cost
                best = current.duplicate()
    for ci in active:
        var data: Dictionary = active[ci]
        var q: PackedVector2Array = best[ci]
        _paired_write(tris,members[ci],data.indices,q)
        if q != data.points:
            _paired_bounds(charts[ci],q)

static func _network_severe_count(tris: Array[Dictionary],links: Array[Dictionary]) -> int:
    var count: int = 0
    for link in links:
        if _local_edge_residual(tris,link,-1,{},PackedVector2Array()) > 1.0:
            count += 1
    return count

static func _refinement_score(tris: Array[Dictionary],ci: int,links: Array,indices: Dictionary,points: PackedVector2Array) -> Vector3:
    var worst: float = 0.0
    var bad: float = 0.0
    var sum: float = 0.0
    for link in links:
        var residual: float = _local_edge_residual(tris,link,ci,indices,points)
        worst = maxf(worst,residual)
        if residual > 0.25:
            bad += 1.0
        sum += residual*residual
    return Vector3(worst,bad,sum+worst*worst+bad*0.25)

static func _refinement_valid(members: Array,indices: Dictionary,world: PackedVector3Array,old: PackedVector2Array,q: PackedVector2Array,density: int) -> bool:
    for id in members:
        var ids: PackedInt32Array = indices[id]
        var a: int = ids[0]
        var b: int = ids[1]
        var c: int = ids[2]
        var before: float = (old[b]-old[a]).cross(old[c]-old[a])
        var after: float = (q[b]-q[a]).cross(q[c]-q[a])
        var metric_area: float = (world[b]-world[a]).cross(world[c]-world[a]).length()*density*density
        if before*after <= 0.00000001 or metric_area < 0.000001:
            return false
        var area_ratio: float = absf(after)/metric_area
        var before_ratio: float = absf(before)/metric_area
        if area_ratio < minf(0.25,before_ratio) or area_ratio > maxf(3.0,before_ratio):
            return false
        for k in range(3):
            var i: int = ids[k]
            var j: int = ids[(k+1)%3]
            var metric: float = world[i].distance_to(world[j])*density
            if metric < 0.000001:
                return false
            var ratio: float = q[i].distance_to(q[j])/metric
            var prior: float = old[i].distance_to(old[j])/metric
            if ratio < minf(0.35,prior) or ratio > maxf(2.0,prior):
                return false
    return true

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
        # Partition the shared 3D edge at every texel grid crossing on
        # either UV island. A midpoint of each interval identifies the
        # exact pair sampled by nearest filtering, even for unequal or
        # diagonal edges. A tiny perpendicular inset avoids rounding
        # outward into atlas padding along integer-aligned edges.
        var aa: Vector2 = sa[0]*size
        var ab: Vector2 = sa[1]*size
        var ba: Vector2 = sb[0]*size
        var bb: Vector2 = sb[1]*size
        var inset_a: Vector2 = _seam_pixel_inset(aa,ab,ca)
        var inset_b: Vector2 = _seam_pixel_inset(ba,bb,cb)
        aa += inset_a
        ab += inset_a
        ba += inset_b
        bb += inset_b
        var cuts: Array[float] = [0.0,1.0]
        _append_texel_cuts(cuts,aa,ab)
        _append_texel_cuts(cuts,ba,bb)
        cuts.sort()
        for i in range(cuts.size()-1):
            if cuts[i+1]-cuts[i] <= 0.0000001:
                continue
            var f: float = (cuts[i]+cuts[i+1])*0.5
            var pa: Vector2i = Vector2i(aa.lerp(ab,f).floor()).clamp(Vector2i.ZERO,atlas_size-Vector2i.ONE)
            var pb: Vector2i = Vector2i(ba.lerp(bb,f).floor()).clamp(Vector2i.ZERO,atlas_size-Vector2i.ONE)
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

static func _seam_pixel_inset(a: Vector2,b: Vector2,center: Vector2) -> Vector2:
    var edge: Vector2 = b-a
    if edge.length_squared() < 0.00000001:
        return Vector2.ZERO
    var normal := Vector2(-edge.y,edge.x).normalized()
    var height: float = (center-a).dot(normal)
    return normal*signf(height)*minf(0.002,absf(height)*0.1)

static func _append_texel_cuts(cuts: Array[float],a: Vector2,b: Vector2) -> void:
    for axis in range(2):
        var delta: float = b[axis]-a[axis]
        if absf(delta) < 0.0000001:
            continue
        var lo: int = floori(minf(a[axis],b[axis]))+1
        var hi: int = ceili(maxf(a[axis],b[axis]))
        for grid in range(lo,hi):
            var t: float = (float(grid)-a[axis])/delta
            if t > 0.0 and t < 1.0:
                cuts.append(t)

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
