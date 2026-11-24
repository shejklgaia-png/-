extends SceneTree
const UV = preload("res://scripts/sera_texture_uv.gd")
const Studio = preload("res://scripts/sera_texture_studio.gd")
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
    var variant: String = args[3] if args.size() > 3 else "face"
    var result: Dictionary = UV.build(source,density,true,true,true,variant=="face")
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
    var winding_signature: String = ""
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
        var winding: float = (uv[1]-uv[0]).cross(uv[2]-uv[0])
        winding_signature += "+" if winding>0.0 else "-"
        if absf(winding) < 0.000000000001:
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
    var bridge_index: Dictionary = UV.face_bridge_index(tris)
    var bridge_count: int = 0
    var bridge_ok: int = 0
    var painted: Image = atlas.duplicate() as Image
    var color := Color8(231,57,103,255)
    for link in UV._seam_segments(tris):
        var ta: Dictionary = tris[int(link.ta)]
        var tb: Dictionary = tris[int(link.tb)]
        var pa: PackedVector3Array = ta.p
        var pb: PackedVector3Array = tb.p
        var ea: int = int(link.ea)
        var eb: int = int(link.eb)
        var wa: Vector3 = pa[ea].lerp(pa[(ea+1)%3],(float(link.a0)+float(link.a1))*0.5)
        var wb: Vector3 = pb[eb].lerp(pb[(eb+1)%3],(float(link.b0)+float(link.b1))*0.5)
        var h1: Dictionary = {"triangle":int(link.ta),"chart":int(link.a),"position":wa.move_toward((pa[0]+pa[1]+pa[2])/3.0,0.2/float(density))}
        var h2: Dictionary = {"triangle":int(link.tb),"chart":int(link.b),"position":wb.move_toward((pb[0]+pb[1]+pb[2])/3.0,0.2/float(density))}
        bridge_count += 1
        var bridge: Dictionary = UV.face_bridge(tris,bridge_index,h1,h2,side,density)
        if bridge.is_empty() or atlas.get_pixelv(bridge.a).a<0.5 or atlas.get_pixelv(bridge.b).a<0.5:
            continue
        painted.set_pixelv(bridge.a,color)
        painted.set_pixelv(bridge.b,color)
        if painted.get_pixelv(bridge.a)==painted.get_pixelv(bridge.b):
            bridge_ok += 1
    var stroke_metrics: Dictionary = _measure_face_strokes(tris,atlas,density) if variant=="face" else {}
    print("FACE_STROKES ",JSON.stringify(stroke_metrics))
    var baked := Image.create(side.x,side.y,false,Image.FORMAT_RGBA8)
    baked.blit_rect(painted,Rect2i(Vector2i.ZERO,side),Vector2i.ZERO)
    var restored_image := Image.new()
    var png_ok: bool = restored_image.load_png_from_buffer(baked.save_png_to_buffer())==OK and restored_image.get_data()==painted.get_data()
    var chart_ids: Array = []
    var face_ids: Array = []
    for t in tris:
        chart_ids.append(int(t.chart))
        face_ids.append([int(t.surface),int(t.authored_face)])
    var mesh_roundtrip: Array = UV.restore_triangles(result.mesh,chart_ids,face_ids)
    var restore_ok: bool = mesh_roundtrip.size()==tris.size()
    if restore_ok:
        for i in range(tris.size()):
            if mesh_roundtrip[i].uv!=tris[i].uv or mesh_roundtrip[i].p!=tris[i].p or int(mesh_roundtrip[i].chart)!=int(tris[i].chart):
                restore_ok = false
                break
    var post: Dictionary = UV.face_bake(tris,result.mesh,[painted,atlas]) if variant=="face" else {}
    var post_ok: bool = not post.has("error") and bool(post.get("verified",false))
    var post_side: int = int(post.get("side",side.x))
    var post_moved: int = int(post.get("moved",0))
    var post_fallback: bool = bool(post.get("fallback",false))
    var post_samples: int = 0
    var post_mismatch: int = 0
    if variant=="face" and post_ok:
        var post_mesh: ArrayMesh = post.mesh
        var post_img: Image = post.images[0]
        var post_tris: Array = UV.restore_triangles(post_mesh,chart_ids,face_ids)
        if post_tris.size()!=tris.size():
            post_ok=false
        else:
            for i in range(tris.size()):
                var old: PackedVector2Array = tris[i].uv
                var fresh: PackedVector2Array = post_tris[i].uv
                # Interior samples compare identical texels on the same physical triangle.
                for weights in [Vector3(0.333333,0.333333,0.333334),Vector3(0.6,0.2,0.2),Vector3(0.2,0.6,0.2),Vector3(0.2,0.2,0.6)]:
                    var p: Vector2 = (old[0]*weights.x+old[1]*weights.y+old[2]*weights.z)*Vector2(side)
                    var q: Vector2 = (fresh[0]*weights.x+fresh[1]*weights.y+fresh[2]*weights.z)*float(post_side)
                    # Exact grid boundaries are excluded from nearest-sample comparison.
                    if absf(p.x-roundf(p.x))<0.0001 or absf(p.y-roundf(p.y))<0.0001:
                        continue
                    post_samples+=1
                    if painted.get_pixelv(Vector2i(p.floor()))!=post_img.get_pixelv(Vector2i(q.floor())):
                        post_mismatch+=1
    var distortion: Vector3 = UV._topology_distortion(tris,density)
    var diagnostic: Dictionary = UV.diagnostic_report(tris,side,density)
    var report: Dictionary = {"id":id,"density":density,"version":result.unwrap_version,"triangles":tris.size(),"charts":result.charts,"atlas":side.x,"physical_edges":counted,"island_edges":island_edges,"island_bad":island_bad,"island_severe":island_severe,"island_max":island_max,"island_sum_sq":island_sum,"bad":bad,"severe":severe,"max":max_res,"sum_sq":sum_sq,"invalid":invalid,"winding_signature":winding_signature.sha256_text(),"overlap_pairs":overlap_pairs,"overlap_unchecked":overlap_unchecked,"min_ratio":min_ratio,"max_ratio":max_ratio,"shape_max":distortion.x,"shape_mean":distortion.y,"area_max":distortion.z,"elapsed_ms":elapsed,"diagnostic":diagnostic.report,"solver":result.affine_report,"bridge_count":bridge_count,"bridge_ok":bridge_ok,"png_roundtrip":png_ok,"mesh_restore":restore_ok,"post_bake_ok":post_ok,"post_bake_side":post_side,"post_bake_moved":post_moved,"post_bake_fallback":post_fallback,"post_bake_samples":post_samples,"post_bake_mismatch":post_mismatch,"post_bake_error":str(post.get("error","")),"face_stroke_metrics":stroke_metrics}
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


# Run the same brush/eraser and bridge functions as the interactive studio,
# without screen raycasts or a physical Android device. Test several crossing
# positions on every seam, not just the midpoint.
func _stroke_sample(t: Dictionary,edge: int,f: float,density: int,idx: int) -> Dictionary:
    var p: PackedVector3Array = t.p
    var uv: PackedVector2Array = t.uv
    var w: Vector3 = p[edge].lerp(p[(edge+1)%3],f)
    var center: Vector3 = (p[0]+p[1]+p[2])/3.0
    var alpha: float = minf(0.5,0.9/float(density)/maxf(w.distance_to(center),0.000001))
    return {"triangle":idx,"chart":int(t.chart),"position":w.lerp(center,alpha),"uv":uv[edge].lerp(uv[(edge+1)%3],f).lerp((uv[0]+uv[1]+uv[2])/3.0,alpha)}

func _measure_face_strokes(tris: Array,atlas: Image,density: int) -> Dictionary:
    var studio = Studio.new()
    studio.triangles = tris
    studio.img = atlas
    studio.original = atlas
    studio.atlas_density = density
    studio.atlas_face_paint = true
    studio.face_bridges = UV.face_bridge_index(tris)
    studio.seam_texels = UV.seam_pixels(tris,atlas.get_size())
    studio.tool_picker = Studio.StudioChoice.new()
    studio.paint_color = Color8(231,57,103,255)
    var ink := Image.create(atlas.get_width(),atlas.get_height(),false,Image.FORMAT_RGBA8)
    studio.layers.append(ink)
    var output: Dictionary = {}
    var size: Vector2i = atlas.get_size()
    for width in [1,5]:
        studio.brush_size = width
        var attempted: int = 0
        var bridged: int = 0
        var covered: int = 0
        var erased: int = 0
        var eligible: int = 0
        var endpoints: int = 0
        var endpoint_covered: int = 0
        var begin: int = Time.get_ticks_usec()
        for link in UV._seam_segments(tris):
            var ia: int = int(link.ta)
            var ib: int = int(link.tb)
            for f in [0.2,0.5,0.8]:
                var a: Dictionary = _stroke_sample(tris[ia],int(link.ea),lerpf(float(link.a0),float(link.a1),f),density,ia)
                var b: Dictionary = _stroke_sample(tris[ib],int(link.eb),lerpf(float(link.b0),float(link.b1),f),density,ib)
                attempted += 1
                var bridge: Dictionary = UV.face_bridge(tris,studio.face_bridges,a,b,size,density)
                if bridge.is_empty():
                    continue
                ink.fill(Color.TRANSPARENT)
                studio.tool_picker.selected = 0
                if not studio._paint_face_bridge(a,b):
                    continue
                bridged += 1
                if ink.get_pixelv(bridge.a).a>0.5 and ink.get_pixelv(bridge.b).a>0.5:
                    covered += 1
                for hit in [a,b]:
                    var q: Vector2i = Vector2i((Vector2(hit.uv)*Vector2(size)).floor()).clamp(Vector2i.ZERO,size-Vector2i.ONE)
                    endpoints += 1
                    if atlas.get_pixelv(q).a>0.5:
                        eligible += 1
                        if ink.get_pixelv(q).a>0.5:
                            endpoint_covered += 1
                studio.tool_picker.selected = 1
                studio._paint_face_bridge(a,b)
                if ink.get_used_rect().size == Vector2i.ZERO:
                    erased += 1
        output[str(width)] = {"attempted":attempted,"bridged":bridged,"both_boundary_pixels_painted":covered,"endpoints":endpoints,"eligible_endpoints":eligible,"eligible_endpoints_painted":endpoint_covered,"fully_erased":erased,"elapsed_us":Time.get_ticks_usec()-begin}
    studio.tool_picker.free()
    studio.free()
    return output
