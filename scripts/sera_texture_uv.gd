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
            tris.append({"p":p,"n":normals,"face_normal":n,"surface":s,"base":base,"tex":tex,"prior":prior,"colors":colors,"repeat":mat == null or mat.texture_repeat,"cull":cull})
    if tris.is_empty():
        return {"error":"描画可能な三角形がありません"}
    charts = _edge_aligned_charts(tris,density)
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
        t.uv = uv
        _bake_triangle(img,t,distances)
    var arrays: Array = []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = vertices
    arrays[Mesh.ARRAY_NORMAL] = normals_out
    arrays[Mesh.ARRAY_TEX_UV] = uvs
    arrays[Mesh.ARRAY_COLOR] = flags
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
    if dot > 0.999999:
        var pa: PackedVector3Array = a.p
        var pb: PackedVector3Array = b.p
        if absf(na.dot(pb[0]-pa[0])) < 0.00001:
            return true
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
            var key: String = str(t.surface)+":"+_edge_key(p[e],p[(e+1)%3])
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
        var best: float = -INF
        var anchor: Vector3 = Vector3.ZERO
        var aligned_edge: bool = false
        for item in outline.values():
            if int(item.count) != 1:
                continue
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
        charts.append(chart)
    return charts

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
    for t in tris:
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
            result = {"uv":t.uv[0]*(1-u-v)+t.uv[1]*u+t.uv[2]*v,"chart":t.chart,"position":origin+direction*depth}
    return result

## Restore the exact saved atlas, without repartitioning or resampling.
static func restore_triangles(mesh: ArrayMesh, chart_ids: Array) -> Array:
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
        result.append({"p":PackedVector3Array([vertices[i],vertices[i+1],vertices[i+2]]),"uv":PackedVector2Array([uv[i],uv[i+1],uv[i+2]]),"chart":int(chart_ids[i/3]),"cull":_decode_cull(flags[i]) if flags.size() == vertices.size() else BaseMaterial3D.CULL_DISABLED})
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
