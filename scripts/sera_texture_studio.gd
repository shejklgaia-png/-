extends Control
signal closed
const UV = preload("res://scripts/sera_texture_uv.gd")
const SAVE_DIR := "user://texture_studio"
var candidates: Array[MeshInstance3D] = []
var external_root: Node3D
var picker: OptionButton
var density_picker: OptionButton
var tool_picker: OptionButton
var color_picker: ColorPickerButton
var status: Label
var host: SubViewportContainer
var view: SubViewport
var pivot: Node3D
var camera: Camera3D
var preview: MeshInstance3D
var atlas_preview: TextureRect
var img: Image
var original: Image
var tex: ImageTexture
var triangles: Array = []
var undo_stack: Array[Image] = []
var redo_stack: Array[Image] = []
var points: Dictionary = {}
var last_point := Vector2.ZERO
var last_hit := Vector2i(-1,-1)
var last_chart := -1
var stroke := false
var rotation_mode := false
var multi_gesture := false
var yaw := 0.65
var pitch := -0.25
var zoom := 3.0
var radius := 1.0
var center := Vector3.ZERO
var source: MeshInstance3D
var file_dialog: FileDialog
var tools: Array[String] = ["ペン","消しゴム","スポイト","面塗り","明るく","暗く","ノイズ"]

func configure(roots: Array) -> void:
    for root in roots:
        if is_instance_valid(root):
            _collect(root)
    _build_ui()
    _refresh_picker()
    if not candidates.is_empty():
        _select_model(0)

func _collect(node: Node) -> void:
    if node is MeshInstance3D and node.mesh != null and node.skin == null and not candidates.has(node):
        candidates.append(node)
    for child in node.get_children():
        if not child is SubViewport:
            _collect(child)

func _button(parent: Container, label: String, callback: Callable) -> Button:
    var btn := Button.new()
    btn.text = label
    btn.custom_minimum_size = Vector2(0,54)
    btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    btn.add_theme_font_size_override("font_size",20)
    btn.pressed.connect(callback)
    parent.add_child(btn)
    return btn

func _row(parent: Container) -> HBoxContainer:
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation",6)
    parent.add_child(row)
    return row

func _build_ui() -> void:
    name = "TextureStudio"
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_STOP
    var backdrop := ColorRect.new()
    backdrop.color = Color("#101d28")
    backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(backdrop)
    var margin := MarginContainer.new()
    margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    for edge in ["left","right","top","bottom"]:
        margin.add_theme_constant_override("margin_"+edge,12)
    add_child(margin)
    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation",8)
    margin.add_child(box)
    var title := Label.new()
    title.text = "TEXTURE STUDIO / テクスタ"
    title.add_theme_font_size_override("font_size",25)
    box.add_child(title)
    var row := _row(box)
    picker = OptionButton.new()
    picker.custom_minimum_size.y = 54
    picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    picker.clip_text = true
    picker.item_selected.connect(_select_model)
    row.add_child(picker)
    _button(row,"GLB読込",_open_file)
    row = _row(box)
    density_picker = OptionButton.new()
    for d in [8,16,32,64]:
        density_picker.add_item("%d px/m"%d,d)
    density_picker.select(2)
    density_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(density_picker)
    _button(row,"UV再展開",_rebuild)
    host = SubViewportContainer.new()
    host.name = "TexturePaintView"
    host.stretch = true
    host.size_flags_vertical = Control.SIZE_EXPAND_FILL
    host.custom_minimum_size.y = 300
    host.mouse_filter = Control.MOUSE_FILTER_STOP
    host.gui_input.connect(_view_input)
    box.add_child(host)
    view = SubViewport.new()
    view.own_world_3d = true
    view.size = Vector2i(600,600)
    view.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
    view.gui_disable_input = true
    host.add_child(view)
    var world := WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color("#263747")
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color.WHITE
    env.ambient_light_energy = 1.0
    world.environment = env
    view.add_child(world)
    pivot = Node3D.new()
    view.add_child(pivot)
    preview = MeshInstance3D.new()
    pivot.add_child(preview)
    camera = Camera3D.new()
    camera.current = true
    camera.near = 0.001
    view.add_child(camera)
    row = _row(box)
    tool_picker = OptionButton.new()
    tool_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    for name_text in tools:
        tool_picker.add_item(name_text)
    row.add_child(tool_picker)
    color_picker = ColorPickerButton.new()
    color_picker.color = Color("#8daebd")
    color_picker.edit_alpha = false
    color_picker.custom_minimum_size = Vector2(88,54)
    row.add_child(color_picker)
    var mode := _button(row,"回転 / 描画",func(): rotation_mode = not rotation_mode; _show_status("回転モード" if rotation_mode else "描画モード"))
    mode.toggle_mode = true
    row = _row(box)
    _button(row,"Undo",_undo)
    _button(row,"Redo",_redo)
    _button(row,"UV表示",_toggle_atlas)
    _button(row,"保存",_save)
    atlas_preview = TextureRect.new()
    atlas_preview.custom_minimum_size.y = 160
    atlas_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    atlas_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    atlas_preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    atlas_preview.visible = false
    box.add_child(atlas_preview)
    status = Label.new()
    status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    status.custom_minimum_size.y = 46
    status.text = "モデルを選択してください"
    box.add_child(status)
    _button(box,"‹ LABOへ戻る",request_close)
    _camera_pose()

func _refresh_picker() -> void:
    picker.clear()
    for item in candidates:
        picker.add_item(str(item.name)+" / "+str(item.get_parent().name if item.get_parent()!=null else "GLB"))

func _select_model(index: int) -> void:
    if index < 0 or index >= candidates.size():
        return
    source = candidates[index]
    _rebuild()

func _rebuild() -> void:
    if not is_instance_valid(source):
        return
    var result: Dictionary = UV.build(source,density_picker.get_selected_id())
    if result.has("error"):
        preview.mesh = null
        img = null
        triangles.clear()
        atlas_preview.texture = null
        _show_status(str(result.error))
        return
    triangles = result.triangles
    img = result.image
    original = img.duplicate() as Image
    undo_stack.clear()
    redo_stack.clear()
    tex = ImageTexture.create_from_image(img)
    preview.mesh = result.mesh
    var material := StandardMaterial3D.new()
    material.albedo_texture = tex
    material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.cull_mode = BaseMaterial3D.CULL_DISABLED
    preview.material_override = material
    atlas_preview.texture = tex
    var bounds := preview.mesh.get_aabb()
    center = bounds.get_center()
    preview.position = -center
    radius = maxf(0.01,bounds.size.length()*0.5)
    zoom = radius*3.0
    _camera_pose()
    _show_status("%d×%d px / UV島 %d / %s" % [img.get_width(),img.get_height(),result.charts,source.name])

func _camera_pose() -> void:
    if not is_instance_valid(camera):
        return
    camera.position = Vector3(sin(yaw)*cos(pitch),sin(pitch),cos(yaw)*cos(pitch))*zoom
    camera.look_at(Vector3.ZERO,Vector3.UP)
    camera.far = maxf(100.0,zoom*10.0)

func _rotate(delta: Vector2) -> void:
    yaw -= delta.x*0.008
    pitch = clampf(pitch+delta.y*0.008,-1.48,1.48)
    _camera_pose()

func _zoom(ratio: float) -> void:
    zoom = clampf(zoom*ratio,radius*0.4,radius*12.0)
    _camera_pose()

func _view_input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        if event.pressed:
            points[event.index] = event.position
            if points.size() == 1:
                multi_gesture = false
                last_point = event.position
                # Delay the initial dot until release/drag so the first finger
                # of a two-finger orbit cannot accidentally paint.
                stroke = false
            else:
                multi_gesture = true
                _end_stroke()
        else:
            if points.size() == 1 and not multi_gesture and not rotation_mode and not stroke:
                _begin_stroke()
                _paint(event.position)
            points.erase(event.index)
            if points.is_empty():
                _end_stroke()
        accept_event()
    elif event is InputEventScreenDrag:
        if not points.has(event.index):
            return
        var before: Vector2 = points[event.index]
        if points.size() >= 2:
            for id in points:
                if id != event.index:
                    var other: Vector2 = points[id]
                    var old_distance := maxf(1.0,before.distance_to(other))
                    var new_distance := maxf(1.0,event.position.distance_to(other))
                    _zoom(old_distance/new_distance)
                    _rotate(event.relative*0.5)
                    break
        elif not multi_gesture:
            if rotation_mode:
                _rotate(event.relative)
            else:
                if not stroke:
                    _begin_stroke()
                    _paint(before)
                _paint(event.position)
        points[event.index] = event.position
        accept_event()
    elif event is InputEventMouseButton:
        if not points.is_empty():
            return
        if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
            _zoom(0.87)
        elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
            _zoom(1.15)
        elif event.button_index == MOUSE_BUTTON_LEFT:
            if event.pressed and not rotation_mode:
                _begin_stroke()
                _paint(event.position)
            elif not event.pressed:
                _end_stroke()
        accept_event()
    elif event is InputEventMouseMotion and points.is_empty():
        if event.button_mask & MOUSE_BUTTON_MASK_RIGHT or (rotation_mode and event.button_mask & MOUSE_BUTTON_MASK_LEFT):
            _rotate(event.relative)
        elif stroke and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
            _paint(event.position)
        accept_event()

func _begin_stroke() -> void:
    if img == null:
        return
    stroke = true
    last_hit = Vector2i(-1,-1)
    last_chart = -1
    if tool_picker.selected != 2:
        undo_stack.append(img.duplicate() as Image)
        if undo_stack.size() > 12:
            undo_stack.pop_front()
        redo_stack.clear()

func _end_stroke() -> void:
    stroke = false
    last_hit = Vector2i(-1,-1)
    last_chart = -1

func _paint(at: Vector2) -> void:
    if img == null or not stroke or host.size.x <= 0 or host.size.y <= 0:
        return
    var pt := at / host.size * Vector2(view.size)
    var hit: Dictionary = UV.hit(triangles,camera.project_ray_origin(pt)+center,camera.project_ray_normal(pt))
    if hit.is_empty():
        last_hit = Vector2i(-1,-1)
        return
    var uv: Vector2 = hit.uv
    var p := Vector2i(clampi(floori(uv.x*img.get_width()),0,img.get_width()-1),clampi(floori(uv.y*img.get_height()),0,img.get_height()-1))
    var chart: int = hit.chart
    if tool_picker.selected == 2:
        color_picker.color = img.get_pixelv(p)
    elif tool_picker.selected == 3:
        _fill_chart(chart)
    else:
        if last_chart == chart and last_hit.x >= 0:
            var steps := maxi(absi(p.x-last_hit.x),absi(p.y-last_hit.y))
            for i in range(steps+1):
                var q := Vector2i(Vector2(last_hit).lerp(Vector2(p),float(i)/maxf(1.0,steps)).round())
                _dab(q)
        else:
            _dab(p)
    last_hit = p
    last_chart = chart
    tex.update(img)

func _dab(p: Vector2i) -> void:
    if not Rect2i(Vector2i.ZERO,img.get_size()).has_point(p):
        return
    var old := img.get_pixelv(p)
    if original.get_pixelv(p).a < 0.5:
        return
    var color := color_picker.color
    match tool_picker.selected:
        1: color = original.get_pixelv(p)
        4: color = old.lightened(0.12)
        5: color = old.darkened(0.12)
        6: color = old.lightened(randf_range(0.0,0.16)) if randf() > 0.5 else old.darkened(randf_range(0.0,0.16))
    img.set_pixelv(p,Color(color.r,color.g,color.b,1.0))

func _fill_chart(chart: int) -> void:
    for t in triangles:
        if t.chart != chart:
            continue
        var filled: Dictionary = t.duplicate()
        filled.base = color_picker.color
        filled.tex = null
        UV._bake_triangle(img,filled)

func _undo() -> void:
    if undo_stack.is_empty():
        return
    redo_stack.append(img.duplicate() as Image)
    img = undo_stack.pop_back()
    tex.update(img)

func _redo() -> void:
    if redo_stack.is_empty():
        return
    undo_stack.append(img.duplicate() as Image)
    img = redo_stack.pop_back()
    tex.update(img)

func _toggle_atlas() -> void:
    atlas_preview.visible = not atlas_preview.visible

func _show_status(message: String) -> void:
    status.text = message

func _open_file() -> void:
    if not is_instance_valid(file_dialog):
        file_dialog = FileDialog.new()
        file_dialog.access = FileDialog.ACCESS_FILESYSTEM
        file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
        file_dialog.add_filter("*.glb","GLBモデル")
        file_dialog.file_selected.connect(_load_glb)
        add_child(file_dialog)
    file_dialog.popup_centered_ratio(0.9)

func _load_glb(path: String) -> void:
    var doc := GLTFDocument.new()
    var state := GLTFState.new()
    if doc.append_from_file(path,state) != OK:
        _show_status("GLBを読み込めません")
        return
    var root := doc.generate_scene(state) as Node3D
    if root == null:
        _show_status("モデルがありません")
        return
    if is_instance_valid(external_root):
        for i in range(candidates.size()-1,-1,-1):
            if external_root == candidates[i] or external_root.is_ancestor_of(candidates[i]):
                candidates.remove_at(i)
        external_root.free()
    external_root = root
    external_root.visible = false
    pivot.add_child(external_root)
    var first := candidates.size()
    _collect(external_root)
    _refresh_picker()
    if candidates.size() > first:
        picker.select(first)
        _select_model(first)
    else:
        _show_status("対応メッシュがありません")

func _save() -> void:
    if img == null or preview.mesh == null:
        return
    if DirAccess.make_dir_recursive_absolute(SAVE_DIR) != OK and not DirAccess.dir_exists_absolute(SAVE_DIR):
        _show_status("保存フォルダを作成できません")
        return
    var stem := str(source.name).validate_filename()+"_"+str(Time.get_unix_time_from_system()).replace(".","_")
    var png := SAVE_DIR+"/"+stem+".png"
    var mesh_path := SAVE_DIR+"/"+stem+".res"
    var baked := img.duplicate() as Image
    # Two-pixel RGB dilation into unused atlas padding prevents dark seams.
    for pass_index in range(2):
        var prior := baked.duplicate() as Image
        for y in range(baked.get_height()):
            for x in range(baked.get_width()):
                if prior.get_pixel(x,y).a > 0.0:
                    continue
                for offset in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
                    var q: Vector2i = Vector2i(x,y)+offset
                    if Rect2i(Vector2i.ZERO,baked.get_size()).has_point(q) and prior.get_pixelv(q).a > 0.0:
                        baked.set_pixel(x,y,prior.get_pixelv(q))
                        break
    if baked.save_png(png) != OK:
        _show_status("PNG保存失敗")
        return
    baked.generate_mipmaps()
    var saved_mesh := preview.mesh.duplicate() as ArrayMesh
    var mat := StandardMaterial3D.new()
    mat.albedo_texture = ImageTexture.create_from_image(baked)
    mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
    saved_mesh.surface_set_material(0,mat)
    if ResourceSaver.save(saved_mesh,mesh_path) != OK:
        _show_status("PNG保存済み・メッシュ保存失敗")
        return
    _show_status("保存済み: "+png+" / .res")

func request_close() -> void:
    if is_instance_valid(file_dialog) and file_dialog.visible:
        file_dialog.hide()
        return
    closed.emit()
    queue_free()
