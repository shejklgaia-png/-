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
            var colors := PackedColorArray()
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
                colors.append(vertex_colors[ix[k]] if mat != null and mat.vertex_color_use_as_albedo and vertex_colors.size() == vs.size() else Color.WHITE)
            var cull: int = BaseMaterial3D.CULL_DISABLED if mat == null else mat.cull_mode
            if encoded_culling and vertex_colors.size() == vs.size():
                cull = _decode_cull(vertex_colors[ix[0]])
            tris.append({"p":p,"n":normals,"xy":xy,"chart":ci,"base":base,"tex":tex,"prior":prior,"colors":colors,"repeat":mat == null or mat.texture_repeat,"cull":cull})
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
