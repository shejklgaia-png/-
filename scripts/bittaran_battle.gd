extends "res://scripts/main.gd"
## Dedicated Bittaran battle. Reuse proven SERA controls/combat/camera/HP,
## but replace the red training dummy with the authored quadruped.
const BittaranRig = preload("res://scripts/bittaran_rig.gd")
const BittaranAI = preload("res://scripts/bittaran_ai.gd")
const BittaranFootIK = preload("res://scripts/bittaran_foot_ik.gd")
const NAME_TEXT: String = "BITTARAN  /  ビットタラン"

var bittaran_rig: Node3D
var bittaran_ai: RefCounted
var bittaran_foot_ik: RefCounted
var bittaran_motion: String = "Idle"
var boss_name_label: Label
var victory_label: Label

func _ready() -> void:
    super._ready()
    # Dedicated boss locomotion is not controlled by training-room settings.
    target_move_enabled = true
    if move_target_button != null:
        move_target_button.visible = false
    var layer := CanvasLayer.new()
    layer.name = "BittaranBattleLabels"
    layer.layer = 30
    add_child(layer)
    boss_name_label = _make_boss_label(layer, NAME_TEXT, 115.0, 22)
    victory_label = _make_boss_label(layer, "BITTARAN DEFEATED", 176.0, 26)
    victory_label.visible = false

func _make_boss_label(parent: CanvasLayer, caption: String,
        y: float, font_size: int) -> Label:
    var label := Label.new()
    label.name = "BittaranName" if y < 150.0 else "BittaranVictory"
    label.text = caption
    label.set_anchors_preset(Control.PRESET_TOP_WIDE)
    label.offset_top = y
    label.offset_bottom = y + 34.0
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    label.add_theme_font_size_override("font_size", font_size)
    label.add_theme_color_override("font_color", Color("#c8ebff"))
    parent.add_child(label)
    return label

func _build_target() -> void:
    # Retain combat HP, five targetable parts, lock volumes and physical
    # collision; hide their old training-only red geometry.
    super._build_target()
    target_mesh.visible = false
    bittaran_rig = BittaranRig.new()
    bittaran_rig.name = "BittaranRig"
    # The authored head faces -Z; SERA's target-space forward is +Z.
    # Only the model turns 180 degrees here; AI owns the root yaw.
    bittaran_rig.rotation.y = PI
    bittaran_rig.position.y = -1.12
    target.add_child(bittaran_rig)
    bittaran_ai = BittaranAI.new()
    bittaran_ai.call("reset")
    bittaran_foot_ik = BittaranFootIK.new()
    if not bool(bittaran_foot_ik.call("setup", bittaran_rig)):
        push_error("Bittaran: four-leg IK setup failed")

func _build_enemy_shooter() -> void:
    # Bittaran's requested initial moveset is movement only, not the
    # unrelated training cube's automatic bullet/ARC attacks.
    super._build_enemy_shooter()
    if enemy_shooter != null:
        enemy_shooter.set("auto_fire_enabled", false)

func _advance_target_motion(delta: float) -> void:
    if target == null or player == null or bittaran_ai == null:
        return
    var frozen: bool = (
        not target_move_enabled or target_hp <= 0
        or stagger_remaining > 0.0 or part_break_remaining > 0.0
        or down_remaining > 0.0 or training_ko_remaining > 0.0)
    var result: Dictionary = bittaran_ai.call("advance", delta,
        target.position, target.rotation.y, player.position, frozen)
    target.position = result["position"]
    target.rotation.y = float(result["yaw"])
    bittaran_motion = str(result["motion"])
    if bittaran_rig != null:
        bittaran_rig.call("set_motion", bittaran_motion, delta)
    if target_floor_mark != null:
        target_floor_mark.position = Vector3(
            target.position.x, -0.026, target.position.z)

func _physics_process(delta: float) -> void:
    # main.gd advances root motion and finishes the vertical boss bob first.
    # Solve contact IK last, in world space, against the final interpolated root.
    super._physics_process(delta)
    if bittaran_foot_ik != null and target != null and target_hp > 0:
        bittaran_foot_ik.call("advance_ik", delta, bittaran_motion)

func _tick_target_respawn(_delta: float) -> void:
    # Defeating a named boss ends the encounter, rather than repeatedly
    # auto-respawning it like the TRAINING ROOM target.
    pass

func _reset_target_after_respawn() -> void:
    # A player KO starts a fresh encounter with the same full boss HP.
    super._reset_target_after_respawn()
    if bittaran_ai != null:
        bittaran_ai.call("reset")
    if target != null:
        target.rotation.y = 0.0
    if bittaran_foot_ik != null:
        bittaran_foot_ik.call("reset")

func _process(delta: float) -> void:
    super._process(delta)
    if victory_label != null:
        victory_label.visible = target_hp <= 0
