extends SceneTree
const UV = preload("res://scripts/sera_texture_uv.gd")
const Source = preload("res://scripts/sera_texture_part_source.gd")
const Catalog = preload("res://scripts/sera_prototype_catalog.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var args := OS.get_cmdline_user_args()
    var id: String = args[0] if args.size() > 0 else "H02"
    var dest: String = args[1] if args.size() > 1 else "user://uv-report.json"
    var density: int = int(args[2]) if args.size() > 2 else 32
    var host := Node3D.new()
    root.add_child(host)
    var rig := Source.create_rig(host)
    if rig == null:
        push_error("UV benchmark: equipment rig failed")
        quit(2)
        return
    var snapshot: Dictionary = Source.snapshot(rig,id)
    if snapshot.has("error"):
        push_error(str(snapshot.error))
        quit(2)
        return
    var source: MeshInstance3D = snapshot.source
    host.add_child(source)
    var begin := Time.get_ticks_msec()
    var result: Dictionary = UV.build(source,density,true,true)
    var elapsed := Time.get_ticks_msec()-begin
    if result.has("error"):
        push_error(str(result.error))
        quit(2)
        return
    var tris: Array = result.triangles
    var atlas: Image = result.image
    var side := atlas.get_size()
    var max_res: float = 0.0
    var sum_sq: float = 0.0
    var bad: int = 0
    var severe: int = 0
    var counted: int = 0
    var invalid: int = 0
    var island_edges: int = 0
    var island_bad: int = 0
    var island_severe: int = 0
    var island_max: float = 0.0
    var island_sum: float = 0.0
    var min_ratio: float = INF
    var max_ratio: float = 0.0
    var physical: Array = UV._seam_segments(tris,true)
    for link in physical:
        var m: Dictionary = UV._diagnostic_edge_metrics(tris,link,Vector2(side))
        if m.is_empty() or not is_finite(float(m.get("residual",INF))):
            invalid += 1
            continue
        var r: float = float(m.residual)
        counted += 1
        if int(link.a) != int(link.b):
            island_edges += 1
            island_bad += 1 if r > 0.25 else 0
            island_severe += 1 if r > 1.0 else 0
            island_max = maxf(island_max,r)
            island_sum += r*r
        max_res = maxf(max_res,r)
        sum_sq += r*r
        if r > 0.25:
            bad += 1
        if r > 1.0:
            severe += 1
    for t in tris:
        var p: PackedVector3Array = t.p
        var uv: PackedVector2Array = t.uv
        for i in range(3):
            if not uv[i].is_finite() or uv[i].x < 0.0 or uv[i].x > 1.0 or uv[i].y < 0.0 or uv[i].y > 1.0:
                invalid += 1
            var length: float = p[i].distance_to(p[(i+1)%3])*density
            if length > 0.000001:
                var ratio: float = ((uv[i]-uv[(i+1)%3])*Vector2(side)).length()/length
                min_ratio = minf(min_ratio,ratio)
                max_ratio = maxf(max_ratio,ratio)
        if absf((uv[1]-uv[0]).cross(uv[2]-uv[0])) < 0.000000000001:
            invalid += 1
    # Validate positive-area overlap on the actual packed output, all islands.
    var entries: Array[Dictionary] = []
    for t in tris:
        var uv: PackedVector2Array = t.uv
        var pixel := PackedVector2Array()
        for q in uv:
            pixel.append(q*Vector2(side))
        entries.append({"uv":pixel,"lo":pixel[0].min(pixel[1]).min(pixel[2]),"hi":pixel[0].max(pixel[1]).max(pixel[2])})
    entries.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.lo.x < b.lo.x)
    var overlap_pairs: int = 0
    var overlap_checks: int = 0
    var overlap_unchecked: bool = false
    for i in range(entries.size()):
        if overlap_unchecked:
            break
        var a: Dictionary = entries[i]
        for j in range(i+1,entries.size()):
            var b: Dictionary = entries[j]
            if b.lo.x >= a.hi.x-0.0001:
                break
            if minf(a.hi.y,b.hi.y)-maxf(a.lo.y,b.lo.y)<=0.0001:
                continue
            overlap_checks += 1
            if overlap_checks>1000000:
                overlap_unchecked = true
                break
            if UV._overlaps(a.uv,b.uv):
                overlap_pairs += 1
    var distortion: Vector3 = UV._topology_distortion(tris,density)
    var diagnostic: Dictionary = UV.diagnostic_report(tris,side,density)
    var report: Dictionary = {"id":id,"density":density,"version":result.unwrap_version,"triangles":tris.size(),"charts":result.charts,"atlas":side.x,"physical_edges":counted,"island_edges":island_edges,"island_bad":island_bad,"island_severe":island_severe,"island_max":island_max,"island_sum_sq":island_sum,"bad":bad,"severe":severe,"max":max_res,"sum_sq":sum_sq,"invalid":invalid,"overlap_pairs":overlap_pairs,"overlap_unchecked":overlap_unchecked,"min_ratio":min_ratio,"max_ratio":max_ratio,"shape_max":distortion.x,"shape_mean":distortion.y,"area_max":distortion.z,"elapsed_ms":elapsed,"diagnostic":diagnostic.report,"solver":result.affine_report}
    var file := FileAccess.open(dest,FileAccess.WRITE)
    if file == null:
        push_error("Cannot write UV report")
        quit(2)
        return
    file.store_string(JSON.stringify(report,"  "))
    file.close()
    if atlas.save_png(dest.get_basename()+".png") != OK:
        push_error("Cannot save generated atlas")
        quit(2)
        return
    print("UV_BENCH ",JSON.stringify(report))
    # Remove the source rig while the viewport-owned outline registry still has a tree.
    host.free()
    await process_frame
    quit(0 if invalid == 0 and counted > 0 else 3)
