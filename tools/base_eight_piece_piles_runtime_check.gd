extends SceneTree
## Confirm all 32 sheet and 32 scrap model options are real batched 3D meshes.
const Models = preload("res://scripts/sera_base_pile_models.gd")
const Arch = preload("res://scripts/sera_base_architecture.gd")
const Junk = preload("res://scripts/sera_base_junk_geometry.gd")
const Clutter = preload("res://scripts/sera_base_clutter.gd")
const Layout = preload("res://scripts/sera_base_layout_preview.gd")

const KEYS = [
    "NEXUS", "LABO", "SCRAP_COLLECTOR", "SMELTER",
    "RECYCLER", "GENERATOR", "STORAGE", "BUILD_TERMINAL",
]

func _initialize() -> void:
    call_deferred("_run")

func _fail(why: String) -> void:
    push_error("SERA_BASE_EIGHT_PIECE_PILES_FAIL: " + why)
    quit(1)

func _mesh_parts(batch: Variant) -> int:
    var result: int = 0
    for key in batch.entries:
        result += (batch.entries[key] as Array).size()
    return result

func _run() -> void:
    var forms: Dictionary = {}
    var offsets: Dictionary = {}
    for amount in range(1, 9):
        for pattern in range(4):
            var parts: Array[Dictionary] = Models.model_for(amount, pattern)
            var rows: Array[int] = Models.rows_for(amount, pattern)
            if parts.size() != amount:
                _fail("requested major part count not honored")
                return
            var row_total: int = 0
            for n in rows:
                row_total += n
            if row_total != amount or rows.size() > 3:
                _fail("invalid two or three row distribution")
                return
            if amount >= 5 and (rows.size() < 2 or rows[0] <= rows[-1]):
                _fail("broad foundation and sparse upper layer absent")
                return
            for part in parts:
                var at: Vector2 = part["position"]
                var size: Vector2 = part["size"]
                if absf(at.x) > 0.4 or absf(at.y) > 0.4 or (
                        size.x < 0.12 or size.y < 0.12):
                    _fail("invalid normalized stock dimensions/placement")
                    return
                forms[str(part["form"])] = true
            offsets[str(pattern) + "/" + str(amount)] = str(parts[0]["position"])
            var host := Node3D.new()
            var batch := Arch.Batch.new(host)
            Junk.panel_stack(batch, Vector2.ZERO, 1.0,
                pattern, amount, pattern)
            if _mesh_parts(batch) < amount or host.get_child_count() > 0:
                _fail("steel pieces missing or unbatched")
                return
            var rust_batch := Arch.Batch.new(host)
            Junk.loose_scrap_pile(rust_batch, Vector2.ZERO, 1.0,
                pattern, amount, pattern, "scrap_gears")
            if _mesh_parts(rust_batch) < amount or host.get_child_count() > 0:
                _fail("scrap fragments missing or unbatched")
                return
            host.free()
    if forms.size() < 6 or offsets.size() != 32:
        _fail("not all six metal silhouettes or 32 arrangements exist")
        return

    var piles: int = 0
    var pattern_variants: Dictionary = {}
    var items: Dictionary = {}
    for key in KEYS:
        var props: Array[Dictionary] = Clutter.default_props_for(key)
        items[key] = props
        for part in props:
            if not Clutter.is_loose_pile(str(part["kind"])):
                continue
            var number: int = int(part.get("stack", 0))
            var kind_pattern: int = int(part.get("pattern", -1))
            if number < 1 or number > 8 or (
                    kind_pattern < 0 or kind_pattern >= Models.PATTERNS):
                _fail("invalid live sheet/scrap pile count or pattern")
                return
            piles += 1
            pattern_variants[kind_pattern] = true
    if piles < 12 or pattern_variants.size() < 2:
        _fail("not enough varied metal/scrap piles in the actual eight sites")
        return
    var salvage: Array[Dictionary] = []
    for i in range(16):
        salvage.append({
            "index": i, "x": float(i), "z": 0.0,
            "yaw_deg": 0.0, "scale": 1.12,
            "profile": i % Junk.SCRAP_PROFILES,
            "stack": i % 8 + 1,
            "pattern": i % Models.PATTERNS,
        })
    var raw: String = Layout.export_text(items, salvage, 1, 713)
    var json: Dictionary = JSON.parse_string(raw)
    if json.is_empty() or str(json.get("format", "")) != Layout.FORMAT:
        _fail("cannot hand off 1–8-piece layout JSON")
        return
    for site in json["sites"]:
        for part in site["items"]:
            if not part.has("stack") or not part.has("pattern"):
                _fail("facility pile settings omitted from copied layout")
                return
    var distinct: Dictionary = {}
    for pile in json["scrap"]:
        if not pile.has("stack") or not pile.has("pattern"):
            _fail("scrap pile settings omitted from copied layout")
            return
        distinct[int(pile["stack"])] = true
    if distinct.size() != 8:
        _fail("all eight pile sizes must be serializable")
        return
    print("SERA_BASE_EIGHT_PIECE_PILES_RUNTIME_PASS: 32 patterns per model type, " +
        str(piles) + " facility piles and all 8 serialized scrap counts")
    quit(0)
