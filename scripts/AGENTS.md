# Model-related scripts directory agent instructions
For editing the 3D skeleton, Blockbench import, equipment, animation connections or mesh transforms, **read `../docs/MODEL_PART_WORKFLOW_ja.md` and `../AGENTS.md` first**. WORKFLOW_ID: SERA_MODEL_PARTS_V1
User supplies single-part models; the agent handles copy/renaming, pivot and skeleton mapping, conversions, equipment selection and preservation of current gameplay. Do not claim that cross-skeleton animation is already supported. Model-related PR: `MODEL_GUIDE_READ: YES`.

Before adding/editing 3D rendering, materials, overlays, trails, thruster effects or animation-linked visuals, read `../docs/RENDER_PIPELINE_POLICY_ja.md` and use `render_order_policy.gd`. Check transparent drawing priority and depth independently, plus final animated pivot positions; run `../tools/render_policy_self_check.py`.
