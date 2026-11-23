extends Control
## Shared Bittaran/training completed-frame screen. The live world,
## depth-resolved mesh-ID pass, contour composite, VFX and battle HUD are
## rendered into one SubViewport; the window sees only that finished image.
const DisplayProfile = preload("res://scripts/sera_display_profile.gd")

@onready var battle_viewport: SubViewport = (
    $CompletedFrameContainer/CompletedBattleFrame)


func _enter_tree() -> void:
    # Set the actual tall/legacy window aspect before the nested 3D battle
    # initializes its camera or reads get_viewport().get_visible_rect().
    DisplayProfile.apply(get_window())


func _ready() -> void:
    # Stretch=true keeps the offscreen render target at the same logical
    # size as the destination. FOV is recomputed only when its size changes,
    # avoiding a different framing from the former window-owned battle.
    battle_viewport.size_changed.connect(_sync_battle_fov)
    _sync_battle_fov.call_deferred()


func _sync_battle_fov() -> void:
    if not is_instance_valid(battle_viewport) or (
            not is_inside_tree()):
        return
    var battle_camera: Camera3D = battle_viewport.get_camera_3d()
    if not is_instance_valid(battle_camera):
        return
    var source_size: Vector2 = battle_viewport.get_visible_rect().size
    if source_size.x <= 1.0 or source_size.y <= 1.0:
        return
    var desired_fov: float = DisplayProfile.vertical_fov(
        61.0, source_size)
    if not is_equal_approx(battle_camera.fov, desired_fov):
        battle_camera.fov = desired_fov
