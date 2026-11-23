extends Control
## Canonical completed-frame renderer for the BASE and NEXUS scenes.
## Same structure as Bittaran: the live scene, shared RGB-ID compositor,
## transparent effects and HUD are rendered into ONE SubViewport. The
## window sees only the completed color texture, never separate layers.
const DisplayProfile = preload("res://scripts/sera_display_profile.gd")


func _enter_tree() -> void:
    # The live world must see the final Android/legacy window aspect before
    # it reads its SubViewport size and creates cameras/GUI.
    DisplayProfile.apply(get_window())
