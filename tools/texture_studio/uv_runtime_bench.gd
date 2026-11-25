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
    var grid_comparison: Dictionary = {}
    if variant=="face":
        var old_start: int = Time.get_ticks_usec()
        var previous: Dictionary = UV.build(source,density,true,true,true,true,false)
        var old_us: int = Time.get_ticks_usec()-old_start
        if previous.has("error"):
            push_error(str(previous.error))
            quit(2)
            return
        grid_comparison = {"previous":_measure_grid(previous.triangles,previous.image.get_size()),"current":_measure_grid(tris,result.image.get_size()),"previous_charts":previous.charts,"current_charts":result.charts,"previous_atlas":previous.image.get_width(),"current_atlas":result.image.get_width(),"previous_us":old_us,"current_ms":elapsed,"version":result.unwrap_version,"report":result.affine_report}
        var grid_prefix: String = dest.get_basename()+"-grid"
        var old_ok: bool = _export_footprint_mesh(previous.triangles,grid_prefix+"-v28",{})
        var new_ok: bool = _export_footprint_mesh(tris,grid_prefix+"-current",{})
        var old_atlas: Image = previous.image
        var new_atlas: Image = result.image
        grid_comparison.artifact_ok = old_ok and new_ok and old_atlas.save_png(grid_prefix+"-v28.png")==OK and new_atlas.save_png(grid_prefix+"-current.png")==OK
        print("GRID_V29 ",JSON.stringify(grid_comparison))
        var v29_start: int = Time.get_ticks_usec()
        var v29: Dictionary = UV.build(source,density,true,true,true,true,true,false)
        var v29_us: int = Time.get_ticks_usec()-v29_start
        if v29.has("error"):
            push_error(str(v29.error))
            quit(2)
            return
        var previous_grid: Dictionary = _measure_grid(v29.triangles,v29.image.get_size())
        var v29_image: Image = v29.image
        var v29_mesh_ok: bool = _export_footprint_mesh(v29.triangles,grid_prefix+"-previous-v29",{})
        var v30_mesh_ok: bool = _export_footprint_mesh(tris,grid_prefix+"-v30",{})
        grid_comparison.v30_comparison = {"previous":previous_grid,"current":grid_comparison.current,"previous_charts":v29.charts,"current_charts":result.charts,"previous_atlas":v29_image.get_width(),"current_atlas":result.image.get_width(),"previous_us":v29_us,"current_ms":elapsed,"version":result.unwrap_version,"report":result.affine_report,"artifact_ok":v29_mesh_ok and v30_mesh_ok and v29_image.save_png(grid_prefix+"-previous-v29.png")==OK and new_atlas.save_png(grid_prefix+"-v30.png")==OK}
        print("GRID_V30 ",JSON.stringify(grid_comparison.v30_comparison))
        var v30_start: int = Time.get_ticks_usec()
        var v30: Dictionary = UV.build(source,density,true,true,true,true,true,true,false)
        var v30_us: int = Time.get_ticks_usec()-v30_start
        if v30.has("error"):
            push_error(str(v30.error))
            quit(2)
            return
        var v30_image: Image = v30.image
        var reference_grid: Dictionary = _measure_grid(v30.triangles,v30_image.get_size())
        var reference_ok: bool = _export_footprint_mesh(v30.triangles,grid_prefix+"-previous-v30",{})
        var candidate_ok: bool = _export_footprint_mesh(tris,grid_prefix+"-v31",{})
        var identical: bool = v30_image.get_size()==new_atlas.get_size() and v30.triangles.size()==tris.size()
        if identical:
            for i in range(tris.size()):
                if v30.triangles[i].uv!=tris[i].uv or int(v30.triangles[i].chart)!=int(tris[i].chart):
                    identical = false
                    break
        grid_comparison.v31_comparison = {"previous":reference_grid,"current":grid_comparison.current,"previous_charts":v30.charts,"current_charts":result.charts,"previous_atlas":v30_image.get_width(),"current_atlas":new_atlas.get_width(),"previous_us":v30_us,"current_ms":elapsed,"identical_uv":identical,"version":result.unwrap_version,"report":result.affine_report,"artifact_ok":reference_ok and candidate_ok and v30_image.save_png(grid_prefix+"-previous-v30.png")==OK and new_atlas.save_png(grid_prefix+"-v31.png")==OK}
        # Existing V31 report measures V30 against the current candidate.
        print("GRID_V31 ",JSON.stringify(grid_comparison.v31_comparison))
        var v31_start: int = Time.get_ticks_usec()
        var v31: Dictionary = UV.build(source,density,true,true,true,true,true,true,true,false)
        var v31_us: int = Time.get_ticks_usec()-v31_start
        if v31.has("error"):
            push_error(str(v31.error))
            quit(2)
            return
        var v31_image: Image = v31.image
        var v31_grid: Dictionary = _measure_grid(v31.triangles,v31_image.get_size())
        var v31_mesh_ok: bool = _export_footprint_mesh(v31.triangles,grid_prefix+"-previous-v31",{})
        var v32_mesh_ok: bool = _export_footprint_mesh(tris,grid_prefix+"-v32",{})
        var same_uv: bool = v31_image.get_size()==new_atlas.get_size() and v31.triangles.size()==tris.size()
        if same_uv:
            for i in range(tris.size()):
                if v31.triangles[i].uv!=tris[i].uv or int(v31.triangles[i].chart)!=int(tris[i].chart):
                    same_uv = false
                    break
        grid_comparison.v32_comparison = {"previous":v31_grid,"current":grid_comparison.current,"previous_charts":v31.charts,"current_charts":result.charts,"previous_atlas":v31_image.get_width(),"current_atlas":new_atlas.get_width(),"previous_us":v31_us,"current_ms":elapsed,"identical_uv":same_uv,"version":result.unwrap_version,"report":result.affine_report,"artifact_ok":v31_mesh_ok and v32_mesh_ok and v31_image.save_png(grid_prefix+"-previous-v31.png")==OK and new_atlas.save_png(grid_prefix+"-v32.png")==OK}
        print("GRID_V32 ",JSON.stringify(grid_comparison.v32_comparison))
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
    var footprint_metrics: Dictionary = _measure_face_footprints(tris,atlas,density,dest) if variant=="face" else {}
    print("FACE_FOOTPRINTS ",JSON.stringify(footprint_metrics))
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
    var report: Dictionary = {"id":id,"density":density,"version":result.unwrap_version,"triangles":tris.size(),"charts":result.charts,"atlas":side.x,"physical_edges":counted,"island_edges":island_edges,"island_bad":island_bad,"island_severe":island_severe,"island_max":island_max,"island_sum_sq":island_sum,"bad":bad,"severe":severe,"max":max_res,"sum_sq":sum_sq,"invalid":invalid,"winding_signature":winding_signature.sha256_text(),"overlap_pairs":overlap_pairs,"overlap_unchecked":overlap_unchecked,"min_ratio":min_ratio,"max_ratio":max_ratio,"shape_max":distortion.x,"shape_mean":distortion.y,"area_max":distortion.z,"elapsed_ms":elapsed,"diagnostic":diagnostic.report,"solver":result.affine_report,"bridge_count":bridge_count,"bridge_ok":bridge_ok,"png_roundtrip":png_ok,"mesh_restore":restore_ok,"post_bake_ok":post_ok,"post_bake_side":post_side,"post_bake_moved":post_moved,"post_bake_fallback":post_fallback,"post_bake_samples":post_samples,"post_bake_mismatch":post_mismatch,"post_bake_error":str(post.get("error","")),"face_stroke_metrics":stroke_metrics,"face_footprint_metrics":footprint_metrics,"grid_comparison":grid_comparison}
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


# V26 review: a SINGLE dab from one side. Compare the actual studio
# method with chart omitted (V25-equivalent) and chart supplied (V26).
# The other side is never directly dabbed. Keep the representative
# maximum-gain case as actual RGBA atlas artifacts, not a mockup.
func _measure_face_footprints(tris: Array,atlas: Image,density: int,dest: String) -> Dictionary:
    var studio = Studio.new()
    studio.triangles = tris
    studio.img = atlas
    studio.original = atlas
    studio.atlas_density = density
    studio.atlas_face_paint = true
    var size: Vector2i = atlas.get_size()
    var started: int = Time.get_ticks_usec()
    studio.face_bridges = UV.face_bridge_index(tris)
    studio.seam_texels = UV.seam_pixels(tris,size)
    studio.face_brush_owners = UV.face_brush_owners(tris,size)
    studio.face_brush_edges = UV.face_brush_edges(tris,studio.face_bridges,size)
    studio.face_brush_samples = UV.face_brush_surface_samples(tris,size,studio.face_brush_owners)
    var v26 = Studio.new()
    v26.triangles = tris
    v26.img = atlas
    v26.original = atlas
    v26.atlas_density = density
    v26.atlas_face_paint = true
    v26.face_bridges = studio.face_bridges
    v26.seam_texels = studio.seam_texels
    v26.face_brush_owners = studio.face_brush_owners
    v26.face_brush_edges = studio.face_brush_edges
    v26.tool_picker = Studio.StudioChoice.new()
    v26.tool_picker.selected = 0
    v26.paint_color = Color8(231,57,103,255)
    var v26_ink := Image.create(size.x,size.y,false,Image.FORMAT_RGBA8)
    v26.layers.append(v26_ink)
    var v27 = Studio.new()
    v27.triangles = tris
    v27.img = atlas
    v27.original = atlas
    v27.atlas_density = density
    v27.atlas_face_paint = true
    v27.face_bridges = studio.face_bridges
    v27.seam_texels = studio.seam_texels
    v27.face_brush_owners = studio.face_brush_owners
    v27.face_brush_edges = studio.face_brush_edges
    v27.face_brush_samples = studio.face_brush_samples
    v27.face_brush_preserve_previous = false
    v27.tool_picker = Studio.StudioChoice.new()
    v27.tool_picker.selected = 0
    v27.paint_color = Color8(231,57,103,255)
    var v27_ink := Image.create(size.x,size.y,false,Image.FORMAT_RGBA8)
    v27.layers.append(v27_ink)
    var setup_us: int = Time.get_ticks_usec()-started
    studio.tool_picker = Studio.StudioChoice.new()
    studio.paint_color = Color8(231,57,103,255)
    var ink := Image.create(size.x,size.y,false,Image.FORMAT_RGBA8)
    studio.layers.append(ink)
    var links: Array = UV._seam_segments(tris)
    var count: int = mini(24,links.size())
    var metrics: Dictionary = {"seams_total":links.size(),"seams_sampled":count,"setup_us":setup_us,"owner_bytes":studio.face_brush_owners.size()*4,"surface_sample_bytes":studio.face_brush_samples.size()*4,"surface_gained_pixels":0,"surface_gained_area":0.0,"padding_gain_pixels":0,"attempted":0,"skipped_invalid_center":0,"gained_cases":0,"gained_neighbor_pixels":0,"unexpected_pixels":0,"missing_source_pixels":0,"erase_failures":0,"legacy_us":0,"v26_geometry_us":0,"v27_us":0,"v28_us":0,"surface_gain_vs_v27":0.0,"surface_loss_vs_v27":0.0,"v27_missing_vs_v26":0.0,"v27_restored_by_v28":0.0,"all_neighbor_loss_vs_v26":0.0,"all_neighbor_loss_vs_v27":0.0,"surface_gain_vs_v26":0.0,"surface_loss_vs_v26":0.0,"padding_removed_vs_v26":0,"surface_gain_cases_vs_v26":0,"surface_loss_cases_vs_v26":0,"artifact_ok":false,"widths":{}}
    var best_gain: int = -1
    var best_surface_area: float = -1.0
    var chart_tris: Dictionary = {}
    var area_cache: Dictionary = {}
    for t in tris:
        var chart_id: int = int(t.chart)
        if not chart_tris.has(chart_id):
            chart_tris[chart_id] = []
        (chart_tris[chart_id] as Array).append(t)
    var best_old: Image
    var best_new: Image
    var best_v26: Image
    var best_v27: Image
    var worst_v27_loss: float = -1.0
    var worst_case: Dictionary = {}
    var worst_v26: Image
    var worst_v27: Image
    var worst_v28: Image
    var best_erased: Image
    var best_case: Dictionary = {}
    for width in [1,3,5]:
        studio.brush_size = width
        v26.brush_size = width
        v27.brush_size = width
        var stats: Dictionary = {"attempted":0,"surface_gained_pixels":0,"surface_gained_area":0.0,"padding_gain_pixels":0,"gained_cases":0,"gained_neighbor_pixels":0,"unexpected_pixels":0,"missing_source_pixels":0,"erase_failures":0,"legacy_us":0,"v26_geometry_us":0,"v27_us":0,"v28_us":0,"surface_gain_vs_v27":0.0,"surface_loss_vs_v27":0.0,"v27_missing_vs_v26":0.0,"v27_restored_by_v28":0.0,"all_neighbor_loss_vs_v26":0.0,"all_neighbor_loss_vs_v27":0.0,"surface_gain_vs_v26":0.0,"surface_loss_vs_v26":0.0,"padding_removed_vs_v26":0,"surface_gain_cases_vs_v26":0,"surface_loss_cases_vs_v26":0}
        for i in range(count):
            var link: Dictionary = links[floori(float(i)*links.size()/count)]
            for reverse in [false,true]:
                var ti: int = int(link.tb if reverse else link.ta)
                var ni: int = int(link.ta if reverse else link.tb)
                var chart: int = int(tris[ti].chart)
                var neighbor: int = int(tris[ni].chart)
                var edge: int = int(link.eb if reverse else link.ea)
                var f0: float = float(link.b0 if reverse else link.a0)
                var f1: float = float(link.b1 if reverse else link.a1)
                var allowed: Dictionary = {chart:true}
                for entry in studio.face_brush_edges.get(chart,[]):
                    allowed[int(entry.dst.chart)] = true
                for f in [0.2,0.5,0.8]:
                    var hit: Dictionary = _stroke_sample(tris[ti],edge,lerpf(f0,f1,f),density,ti)
                    var q: Vector2i = Vector2i((Vector2(hit.uv)*Vector2(size)).floor()).clamp(Vector2i.ZERO,size-Vector2i.ONE)
                    if not studio._face_brush_owned(q,chart) or atlas.get_pixelv(q).a<0.5:
                        metrics.skipped_invalid_center += 1
                        continue
                    stats.attempted += 1
                    ink.fill(Color.TRANSPARENT)
                    studio.tool_picker.selected = 0
                    var tick: int = Time.get_ticks_usec()
                    studio._dab(q)
                    stats.legacy_us += Time.get_ticks_usec()-tick
                    var old: Image = ink.duplicate() as Image
                    v26_ink.fill(Color.TRANSPARENT)
                    tick = Time.get_ticks_usec()
                    v26._dab(q,chart)
                    stats.v26_geometry_us += Time.get_ticks_usec()-tick
                    v27_ink.fill(Color.TRANSPARENT)
                    tick = Time.get_ticks_usec()
                    v27._dab(q,chart)
                    stats.v27_us += Time.get_ticks_usec()-tick
                    ink.fill(Color.TRANSPARENT)
                    tick = Time.get_ticks_usec()
                    studio._dab(q,chart)
                    stats.v28_us += Time.get_ticks_usec()-tick
                    var bounds: Rect2i = old.get_used_rect().merge(ink.get_used_rect()).merge(v26_ink.get_used_rect()).merge(v27_ink.get_used_rect())
                    var gained: int = 0
                    var gained_area: float = 0.0
                    var added_area: float = 0.0
                    var lost_area: float = 0.0
                    var v27_loss: float = 0.0
                    var restored_area: float = 0.0
                    for y in range(bounds.position.y,bounds.end.y):
                        for x in range(bounds.position.x,bounds.end.x):
                            var p := Vector2i(x,y)
                            var owner: int = studio.face_brush_owners[y*size.x+x]
                            var was: bool = old.get_pixelv(p).a>0.5
                            var now: bool = ink.get_pixelv(p).a>0.5
                            if now and not allowed.has(owner):
                                stats.unexpected_pixels += 1
                            if was and not now and owner==chart:
                                stats.missing_source_pixels += 1
                            var was_v26: bool = v26_ink.get_pixelv(p).a>0.5
                            var was_v27: bool = v27_ink.get_pixelv(p).a>0.5
                            if owner!=chart and chart_tris.has(owner) and ((now and not was) or now!=was_v26 or now!=was_v27 or was_v26!=was_v27):
                                var area_key := Vector3i(x,y,owner)
                                if not area_cache.has(area_key):
                                    area_cache[area_key] = _footprint_surface_area(p,chart_tris[owner],size)
                                var real_area: float = area_cache[area_key]
                                if was_v26 and not now:
                                    stats.all_neighbor_loss_vs_v26 += real_area
                                if was_v27 and not now:
                                    stats.all_neighbor_loss_vs_v27 += real_area
                                if now and not was_v27:
                                    stats.surface_gain_vs_v27 += real_area
                                if was_v27 and not now:
                                    stats.surface_loss_vs_v27 += real_area
                                if was_v26 and not was_v27:
                                    v27_loss += real_area
                                    if now:
                                        restored_area += real_area
                            if owner==neighbor and ((now and not was) or now!=was_v26):
                                var key := Vector3i(x,y,neighbor)
                                if not area_cache.has(key):
                                    area_cache[key] = _footprint_surface_area(p,chart_tris[neighbor],size)
                                var covered_area: float = area_cache[key]
                                if now and not was:
                                    gained += 1
                                    if covered_area>0.0:
                                        gained_area += covered_area
                                        stats.surface_gained_pixels += 1
                                    else:
                                        stats.padding_gain_pixels += 1
                                if now and not was_v26:
                                    added_area += covered_area
                                elif was_v26 and not now:
                                    lost_area += covered_area
                                    if covered_area<=0.0:
                                        stats.padding_removed_vs_v26 += 1
                    if gained>0:
                        stats.gained_cases += 1
                        stats.gained_neighbor_pixels += gained
                    stats.v27_missing_vs_v26 += v27_loss
                    stats.v27_restored_by_v28 += restored_area
                    if width>1 and v27_loss>worst_v27_loss:
                        worst_v27_loss = v27_loss
                        worst_v26 = v26_ink.duplicate() as Image
                        worst_v27 = v27_ink.duplicate() as Image
                        worst_v28 = ink.duplicate() as Image
                        worst_case = {"width":width,"source_triangle":ti,"neighbor_triangle":ni,"source_chart":chart,"neighbor_chart":neighbor,"center":[q.x,q.y],"v27_loss_m2":v27_loss,"restored_m2":restored_area}
                    stats.surface_gained_area += gained_area
                    stats.surface_gain_vs_v26 += added_area
                    stats.surface_loss_vs_v26 += lost_area
                    if added_area>0.0:
                        stats.surface_gain_cases_vs_v26 += 1
                    if lost_area>0.0:
                        stats.surface_loss_cases_vs_v26 += 1
                    var score: float = added_area-lost_area
                    var keep: bool = width>1 and (best_gain<0 or score>best_surface_area or (is_equal_approx(score,best_surface_area) and gained>best_gain))
                    if keep:
                        best_surface_area = score
                        best_gain = gained
                        best_old = old
                        best_new = ink.duplicate() as Image
                        best_v26 = v26_ink.duplicate() as Image
                        best_v27 = v27_ink.duplicate() as Image
                        best_case = {"width":width,"source_triangle":ti,"neighbor_triangle":ni,"source_chart":chart,"neighbor_chart":neighbor,"center":[q.x,q.y],"gain":gained,"surface_gain_m2":gained_area,"gain_vs_v26_m2":added_area,"loss_vs_v26_m2":lost_area}
                    studio.tool_picker.selected = 1
                    studio._dab(q,chart)
                    if ink.get_used_rect().size!=Vector2i.ZERO:
                        stats.erase_failures += 1
                    if keep:
                        best_erased = ink.duplicate() as Image
        metrics.widths[str(width)] = stats
        for key in stats:
            metrics[key] += stats[key]
    if best_gain>=0:
        var prefix: String = dest.get_basename()+"-footprint"
        var old_view: Image = atlas.duplicate() as Image
        var new_view: Image = atlas.duplicate() as Image
        old_view.blend_rect(best_old,Rect2i(Vector2i.ZERO,size),Vector2i.ZERO)
        new_view.blend_rect(best_new,Rect2i(Vector2i.ZERO,size),Vector2i.ZERO)
        var ok_old: bool = old_view.save_png(prefix+"-legacy.png")==OK
        var v26_view: Image = atlas.duplicate() as Image
        v26_view.blend_rect(best_v26,Rect2i(Vector2i.ZERO,size),Vector2i.ZERO)
        var ok_v26: bool = v26_view.save_png(prefix+"-v26.png")==OK
        var v27_view: Image = atlas.duplicate() as Image
        v27_view.blend_rect(best_v27,Rect2i(Vector2i.ZERO,size),Vector2i.ZERO)
        var ok_v27: bool = v27_view.save_png(prefix+"-v27.png")==OK
        var ok_new: bool = new_view.save_png(prefix+"-v28.png")==OK
        var ok_mask: bool = best_new.save_png(prefix+"-ink.png")==OK
        var ok_erase: bool = best_erased.save_png(prefix+"-erased.png")==OK
        metrics.artifact_ok = ok_old and ok_v26 and ok_v27 and ok_new and ok_mask and ok_erase
        metrics.candidate = "V28"
        metrics.example = best_case
        metrics.mesh_artifact_ok = _export_footprint_mesh(tris,prefix,best_case)
    if worst_v27_loss>=0.0:
        var worst_prefix: String = dest.get_basename()+"-recovery"
        var recovery_ok: bool = true
        for pair in [[worst_v26,"v26"],[worst_v27,"v27"],[worst_v28,"v28"]]:
            var canvas: Image = atlas.duplicate() as Image
            canvas.blend_rect(pair[0],Rect2i(Vector2i.ZERO,size),Vector2i.ZERO)
            if canvas.save_png(worst_prefix+"-"+str(pair[1])+".png")!=OK:
                recovery_ok = false
        metrics.recovery_artifact_ok = recovery_ok and _export_footprint_mesh(tris,worst_prefix,worst_case)
        metrics.recovery_example = worst_case
    v27.tool_picker.free()
    v27.free()
    v26.tool_picker.free()
    v26.free()
    studio.tool_picker.free()
    studio.free()
    return metrics


# Export the actual mesh used for painting, not a rebuilt approximation.
# Non-JSON extension keeps the existing baseline/face report collector
# from interpreting this review asset as a metrics report.
func _export_footprint_mesh(tris: Array,prefix: String,example: Dictionary) -> bool:
    var mesh_triangles: Array = []
    for t in tris:
        var p: Array = []
        var n: Array = []
        var uv: Array = []
        for i in range(3):
            var pos: Vector3 = t.p[i]
            var normal: Vector3 = t.n[i]
            var texcoord: Vector2 = t.uv[i]
            p.append([pos.x,pos.y,pos.z])
            n.append([normal.x,normal.y,normal.z])
            uv.append([texcoord.x,texcoord.y])
        mesh_triangles.append({"p":p,"n":n,"uv":uv,"chart":int(t.chart),"cull":int(t.get("cull",0))})
    var file := FileAccess.open(prefix+"-mesh.txt",FileAccess.WRITE)
    if file == null:
        return false
    file.store_string(JSON.stringify({"triangles":mesh_triangles,"example":example,"uv_origin":"top-left","winding":"Godot clockwise"}))
    var ok: bool = file.get_error()==OK
    file.close()
    return ok


# Independently measure positive intersection area against the actual
# triangle UVs, converted back to model-space area. Do not consult the
# runtime representative-point cache for the quality metric.
func _footprint_surface_area(pixel: Vector2i,tris: Array,side: Vector2i) -> float:
    var total: float = 0.0
    var origin := Vector2(pixel)
    var cell := PackedVector2Array([Vector2.ZERO,Vector2.RIGHT,Vector2.ONE,Vector2.DOWN])
    for t in tris:
        var a: Vector2 = t.uv[0]*Vector2(side)-origin
        var b: Vector2 = t.uv[1]*Vector2(side)-origin
        var c: Vector2 = t.uv[2]*Vector2(side)-origin
        var lo: Vector2 = a.min(b).min(c)
        var hi: Vector2 = a.max(b).max(c)
        if hi.x<=0.0 or hi.y<=0.0 or lo.x>=1.0 or lo.y>=1.0:
            continue
        var uv_area: float = absf((b-a).cross(c-a))
        if uv_area<=0.00000001:
            continue
        var world_area: float = (Vector3(t.p[1])-Vector3(t.p[0])).cross(Vector3(t.p[2])-Vector3(t.p[0])).length()
        for poly in Geometry2D.intersect_polygons(PackedVector2Array([a,b,c]),cell):
            var twice_area: float = 0.0
            for i in range(poly.size()):
                twice_area += poly[i].cross(poly[(i+1)%poly.size()])
            if absf(twice_area)>0.00000001:
                total += absf(twice_area)*0.5*world_area/uv_area
    return total


# Evaluate both actual packed atlases over identical physical edges.
# Coplanar edges are reported separately from curvature/holonomy cuts.
func _measure_grid(tris: Array,side: Vector2i) -> Dictionary:
    var result: Dictionary = {"edges":0,"bad":0,"severe":0,"worst":0.0,"sum_sq":0.0,"angle_sum":0.0,"coplanar_edges":0,"coplanar_bad":0,"coplanar_worst":0.0,"coplanar_welded":0}
    for link in UV._seam_segments(tris,true):
        var metric: Dictionary = UV._diagnostic_edge_metrics(tris,link,Vector2(side))
        if metric.is_empty():
            continue
        var e: float = float(metric.residual)
        result.edges += 1
        result.bad += 1 if e>0.25 else 0
        result.severe += 1 if e>1.0 else 0
        result.worst = maxf(result.worst,e)
        result.sum_sq += e*e
        result.angle_sum += float(metric.angle)
        var a: Dictionary = tris[int(link.ta)]
        var b: Dictionary = tris[int(link.tb)]
        var na: Vector3 = a.face_normal
        var nb: Vector3 = b.face_normal
        if na.dot(nb)>0.0 and na.cross(nb).length_squared()<=0.0000000001 and absf(na.dot(Vector3(b.p[0])-Vector3(a.p[0])))<=0.00001:
            result.coplanar_edges += 1
            result.coplanar_bad += 1 if e>0.25 else 0
            result.coplanar_worst = maxf(result.coplanar_worst,e)
            result.coplanar_welded += 1 if int(a.chart)==int(b.chart) else 0
    return result
