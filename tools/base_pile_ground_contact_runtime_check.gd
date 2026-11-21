extends SceneTree
## Reject sheet/metal corners sinking through the actual BASE deck.
## Includes non-1x facility props and scaled independent scrap piles.
const Junk = preload("res://scripts/sera_base_junk_geometry.gd")
const Arch = preload("res://scripts/sera_base_architecture.gd")

func _initialize() -> void:
    call_deferred("_run")

func _fail(reason: String) -> void:
    push_error("SERA_BASE_PILE_GROUND_CONTACT_FAIL: " + reason)
    quit(1)

func _verify(batch: Variant, context: String) -> bool:
    var grounded: bool = false
    var visible_top: float = -INF
    var surfaces: int = 0
    for key in batch.entries:
        if not str(key).begins_with("cube|"):
            continue
        for raw in batch.entries[key]:
            var pose: Transform3D = raw
            var half_height: float = 0.5 * (
                absf(pose.basis.x.y) +
                absf(pose.basis.y.y) +
                absf(pose.basis.z.y))
            var bottom: float = pose.origin.y - half_height
            var top: float = pose.origin.y + half_height
            if bottom < Junk.BASE_DECK_SURFACE_Y - 0.0015:
                _fail(context + ": piece below deck by " +
                    str(Junk.BASE_DECK_SURFACE_Y - bottom))
                return false
            if bottom <= Junk.BASE_DECK_SURFACE_Y + 0.003:
                grounded = true
            visible_top = maxf(visible_top, top)
            surfaces += 1
    if not grounded or surfaces == 0:
        _fail(context + ": missing deck contact")
        return false
    if visible_top < Junk.BASE_DECK_SURFACE_Y + 0.09:
        _fail(context + ": metal is flush with / invisible under deck")
        return false
    return true

func _run() -> void:
    var cases: int = 0
    for amount in range(1, 9):
        for style in range(4):
            for ratio_variant in [0.72, 1.0, 1.26]:
                var ratio: float = float(ratio_variant)
                var host := Node3D.new()
                var panel := Arch.Batch.new(host)
                Junk.panel_stack(panel, Vector2.ZERO, ratio,
                    amount + style, amount, style)
                if not _verify(panel, "PANEL %d/%d %.2f" % [
                        amount, style, ratio]):
                    return
                var scrap := Arch.Batch.new(host)
                Junk.loose_scrap_pile(scrap, Vector2.ZERO, ratio,
                    amount + style, amount, style, "scrap_gears")
                if not _verify(scrap, "SCRAP %d/%d %.2f" % [
                        amount, style, ratio]):
                    return
                host.free()
                cases += 1

    for i in range(16):
        var host := Node3D.new()
        var heap := Arch.Batch.new(host)
        var anchor: Vector3 = Vector3(float(i % 4) * 3.0, 0.0,
            float(i / 4) * 3.0)
        heap.pivot = Vector3(anchor.x, Junk.BASE_DECK_SURFACE_Y, anchor.z)
        heap.detail_scale = 1.12 if i % 3 == 0 else (
            1.20 if i % 3 == 1 else 1.26)
        heap.yaw = deg_to_rad(float((i * 23) % 45))
        Junk.scrap_heap(heap, anchor, i, 1 + i % 8, i % 4)
        if not _verify(heap, "INDEPENDENT SCRAP " + str(i)):
            return
        host.free()
    print("SERA_BASE_PILE_GROUND_CONTACT_RUNTIME_PASS: ",
        cases, " board/scrap scale cases and 16 independent piles")
    quit(0)
