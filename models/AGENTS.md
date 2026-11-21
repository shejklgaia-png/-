# Model directory agent instructions
**Read `../docs/MODEL_PART_WORKFLOW_ja.md` and `../AGENTS.md` before model changes.** WORKFLOW_ID: SERA_MODEL_PARTS_V1
User files may have Japanese and arbitrary names; agent copies and renames groups into canonical skeletal hierarchy, preserves pivots/UUID uniqueness and A animation, and registers the result in the actual Godot loader. Mesh count per group is free. Run the matching embedded asset rebuild. If ambiguous, do not guess. Model PR: `MODEL_GUIDE_READ: YES`.

Every new wearable part must first have its canonical original .bbmodel and embedded texture packaged into a self-contained HTML using `../tools/icon_studio/build_sera_icon_studio.py`, and delivered to the user before game implementation. The user must never have to manually import the model into the icon tool. PNG exports retain source/blueprint/preset metadata for cross-chat import. See `../tools/icon_studio/README.md`.

For every new equipable part, also register a unique LAB crafting blueprint with the correct real rig set, icon, recipe, inventory and save/equip integration, plus regression tests. NEXUS-only registration is incomplete. See the mandatory integration checklist in `../docs/MODEL_PART_WORKFLOW_ja.md`.
