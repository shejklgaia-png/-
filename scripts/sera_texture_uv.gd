extends RefCounted
## Metric planar charts; all distances are measured after instance scaling.
const MAX_TRIANGLES = 12000
const PADDING = 2

static func build(source: MeshInstance3D, density: int) -> Dictionary:
    var tris: Array[Dictionary] = []
    var charts: Array[Dictionary] = []
    var lookup: Dictionary = {}
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
        var ids: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
        var count: int = ids.size() if not ids.is_empty() else vs.size()
        var mat := source.get_active_material(s) as StandardMaterial3D
        if source.get_active_material(s) != null and mat == null:
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
            var dist := n.dot(p[0])
            var key := "%d/%d/%d/%d/%d" % [s, roundi(n.x*10000), roundi(n.y*10000), roundi(n.z*10000), roundi(dist*10000)]
            var ci: int
            if lookup.has(key):
                ci = int(lookup[key])
            else:
                ci = charts.size()
                lookup[key] = ci
                var axis := Vector3.UP if absf(n.y) < 0.95 else Vector3.RIGHT
                var u := axis.cross(n).normalized()
                charts.append({"u":u,"v":n.cross(u),"min":Vector2(INF,INF),"max":Vector2(-INF,-INF)})
            var chart: Dictionary = charts[ci]
            var xy := PackedVector2Array()
            var normals := PackedVector3Array()
            var prior := PackedVector2Array()
            for k in range(3):
                var q := Vector2(p[k].dot(chart.u), p[k].dot(chart.v))*density
                xy.append(q)
                chart.min = Vector2(minf(chart.min.x,q.x),minf(chart.min.y,q.y))
                chart.max = Vector2(maxf(chart.max.x,q.x),maxf(chart.max.y,q.y))
                var nn := -n
                if ns.size() == vs.size():
                    nn = (ns[ix[k]] / metric.max(Vector3(0.00001,0.00001,0.00001))).normalized()
                normals.append(nn)
                prior.append(old_uv[ix[k]] if old_uv.size() == vs.size() else Vector2.ZERO)
            tris.append({"p":p,"n":normals,"xy":xy,"chart":ci,"base":base,"tex":tex,"prior":prior})
    if tris.is_empty():
        return {"error":"描画可能な三角形がありません"}
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
    var vertices := PackedVector3Array()
    var normals_out := PackedVector3Array()
    var uvs := PackedVector2Array()
    for t in tris:
        var c: Dictionary = charts[t.chart]
        var uv := PackedVector2Array()
        for k in range(3):
            var q: Vector2 = t.xy[k]-c.min+c.at
            uv.append(q/float(side))
            vertices.append(t.p[k])
            normals_out.append(t.n[k])
            uvs.append(uv[k])
        t.uv = uv
        _bake_triangle(img,t)
    var arrays: Array = []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = vertices
    arrays[Mesh.ARRAY_NORMAL] = normals_out
    arrays[Mesh.ARRAY_TEX_UV] = uvs
    var out := ArrayMesh.new()
    out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
    return {"mesh":out,"image":img,"triangles":tris,"charts":charts.size()}

static func _bake_triangle(img: Image,t: Dictionary) -> void:
    var side := float(img.get_width())
    var a: Vector2 = t.uv[0]*side
    var b: Vector2 = t.uv[1]*side
    var c: Vector2 = t.uv[2]*side
    var d := (b-a).cross(c-a)
    if absf(d) < 0.0000001:
        return
    var lo := Vector2i(floori(minf(a.x,minf(b.x,c.x))),floori(minf(a.y,minf(b.y,c.y))))
    var hi := Vector2i(ceili(maxf(a.x,maxf(b.x,c.x))),ceili(maxf(a.y,maxf(b.y,c.y))))
    var tex: Image = t.tex
    for y in range(maxi(0,lo.y),mini(img.get_height(),hi.y+1)):
        for x in range(maxi(0,lo.x),mini(img.get_width(),hi.x+1)):
            var p := Vector2(x+0.5,y+0.5)
            var v := (p-a).cross(c-a)/d
            var w := (b-a).cross(p-a)/d
            if v < -0.0001 or w < -0.0001 or v+w > 1.0001:
                continue
            var color: Color = t.base
            if tex != null and not tex.is_empty():
                var old: Vector2 = t.prior[0]*(1-v-w)+t.prior[1]*v+t.prior[2]*w
                var tx := clampi(floori(fposmod(old.x,1.0)*tex.get_width()),0,tex.get_width()-1)
                var ty := clampi(floori(fposmod(old.y,1.0)*tex.get_height()),0,tex.get_height()-1)
                color *= tex.get_pixel(tx,ty)
            img.set_pixel(x,y,Color(color.r,color.g,color.b,1.0))

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
            result = {"uv":t.uv[0]*(1-u-v)+t.uv[1]*u+t.uv[2]*v,"chart":t.chart}
    return result
