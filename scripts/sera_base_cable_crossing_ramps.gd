extends Node3D
## Seven fixed industrial crossing ramps. Their geometry and height are
## determined by the authored crossing schedule, not road/cable proximity.
const FLOOR: float = -0.005
const FixedLayout = preload("res://scripts/sera_base_authored_layout.gd")
const HASH_SIZE: float = 1.5
var _sections: Array[Dictionary] = []
var _index: Dictionary = {}


func _xz(v: Vector3) -> Vector2:
    return Vector2(v.x, v.z)


func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
    for p in [a, b, c, a, c, d]:
        st.add_vertex(p)


func _key(p: Vector2) -> Vector2i:
    return Vector2i(floori(p.x / HASH_SIZE), floori(p.y / HASH_SIZE))


func _record(pa: PackedVector3Array, pb: PackedVector3Array) -> void:
    var bounds := Rect2(_xz(pa[0]), Vector2.ZERO)
    for p in pa:
        bounds = bounds.expand(_xz(p))
    for p in pb:
        bounds = bounds.expand(_xz(p))
    var id: int = _sections.size()
    _sections.append({"bounds": bounds, "pa": pa, "pb": pb})
    var low: Vector2i = _key(bounds.position)
    var high: Vector2i = _key(bounds.end)
    for x in range(low.x, high.x + 1):
        for z in range(low.y, high.y + 1):
            var k := Vector2i(x, z)
            if not _index.has(k):
                _index[k] = []
            (_index[k] as Array).append(id)


# Each protector is a single manufactured part, with its straight hollow
# cable channel and two opposing slopes perpendicular to the cable.
func _fixed_profile(center: Vector2, wire: Vector2, edge: float,
        radius: float, cable_y: float) -> PackedVector3Array:
    var normal := Vector2(-wire.y,wire.x)
    var at: Vector2 = center + wire * edge
    var top: float = cable_y + radius + 0.035
    var half_top: float = radius + 0.065
    var slope: float = 0.38 if radius > 0.10 else 0.27
    var row := PackedVector3Array()
    for offset in [-half_top-slope,-half_top,half_top,half_top+slope]:
        var p: Vector2 = at + normal * float(offset)
        var y: float = top if absf(float(offset)) <= half_top + 0.001 else FLOOR
        row.append(Vector3(p.x,y,p.y))
    return row


func _emit_fixed(deck: SurfaceTool, trim: SurfaceTool, crossing: Dictionary) -> void:
    var center: Vector2 = crossing["at"]
    var wire: Vector2 = crossing["wire"]
    var radius: float = float(crossing["radius"])
    var y: float = float(crossing["y"])
    # Fixed 1.68m span for the widened 1.13m vehicle; no automatic growth.
    var pa: PackedVector3Array = _fixed_profile(center,wire,-0.84,radius,y)
    var pb: PackedVector3Array = _fixed_profile(center,wire,0.84,radius,y)
    for j in range(3):
        _quad(deck,pa[j],pb[j],pb[j+1],pa[j+1])
    # Short yellow edge caps on each end; dark steel in the main tread.
    var up := Vector3.UP * 0.008
    for j in range(3):
        _quad(trim,pa[j]+up,pa[j].lerp(pb[j],0.055)+up,
            pa[j+1].lerp(pb[j+1],0.055)+up,pa[j+1]+up)
        _quad(trim,pb[j].lerp(pa[j],0.055)+up,pb[j]+up,
            pb[j+1]+up,pb[j+1].lerp(pa[j+1],0.055)+up)
    _record(pa,pb)


func build(_paths: Array[Dictionary], _logistics: Node3D) -> void:
    var deck := SurfaceTool.new()
    deck.begin(Mesh.PRIMITIVE_TRIANGLES)
    var trim := SurfaceTool.new()
    trim.begin(Mesh.PRIMITIVE_TRIANGLES)
    for crossing in FixedLayout.CROSSINGS:
        _emit_fixed(deck,trim,crossing)
    _finish(deck,"CableProtectorSteelDeck",Color("#41494f"))
    _finish(trim,"CableProtectorSafetyEdges",Color("#b99b47"))


func build_budgeted(_paths: Array[Dictionary], _logistics: Node3D, budget: Variant) -> void:
    var deck := SurfaceTool.new()
    deck.begin(Mesh.PRIMITIVE_TRIANGLES)
    var trim := SurfaceTool.new()
    trim.begin(Mesh.PRIMITIVE_TRIANGLES)
    for crossing in FixedLayout.CROSSINGS:
        if budget != null:
            await budget.checkpoint("authored cable protector")
        _emit_fixed(deck,trim,crossing)
    _finish(deck,"CableProtectorSteelDeck",Color("#41494f"))
    if budget != null:
        await budget.checkpoint("authored protector deck")
    _finish(trim,"CableProtectorSafetyEdges",Color("#b99b47"))


func placement_bounds() -> Array[Rect2]:
    var result: Array[Rect2] = []
    for section in _sections:
        result.append(section["bounds"])
    return result


func _finish(st: SurfaceTool, label: String, tint: Color) -> void:
    st.generate_normals()
    var material := StandardMaterial3D.new()
    material.albedo_color = tint
    material.metallic = 0.24
    material.roughness = 0.88
    material.cull_mode = BaseMaterial3D.CULL_DISABLED
    var draw := MeshInstance3D.new()
    draw.name = label
    draw.mesh = st.commit()
    draw.material_override = material
    draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    draw.set_meta("sera_outline_role", "clutter")
    draw.set_meta("sera_preserve_authored_material", true)
    add_child(draw)


# Interpolate the exact generated triangles rather than guessing a separate
# rectangular height map. This also handles turns and intersecting protectors.
func _triangle_height(p: Vector2, a: Vector3, b: Vector3, c: Vector3) -> float:
    var aa: Vector2 = _xz(a)
    var ab: Vector2 = _xz(b) - aa
    var ac: Vector2 = _xz(c) - aa
    var relative: Vector2 = p - aa
    var det: float = ab.cross(ac)
    if absf(det) < 0.000001:
        return 0.0
    var u: float = relative.cross(ac) / det
    var v: float = ab.cross(relative) / det
    if u < -0.0001 or v < -0.0001 or u + v > 1.0001:
        return 0.0
    return a.y + (b.y - a.y) * u + (c.y - a.y) * v


func height_at(p: Vector2) -> float:
    var y: float = 0.0
    for id in _index.get(_key(p), []):
        var section: Dictionary = _sections[int(id)]
        var bounds: Rect2 = section["bounds"]
        if not bounds.grow(0.001).has_point(p):
            continue
        var pa: PackedVector3Array = section["pa"]
        var pb: PackedVector3Array = section["pb"]
        for j in range(3):
            y = maxf(y, _triangle_height(p, pa[j], pb[j], pb[j + 1]))
            y = maxf(y, _triangle_height(p, pa[j], pb[j + 1], pa[j + 1]))
    return y
