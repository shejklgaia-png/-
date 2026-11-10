extends RefCounted
## SERA transparent 3D rendering contract. Never scatter priority literals.
## Godot draws transparent surfaces by priority; depth testing is independent.
## Values are STABLE visual layering roles, not chronological feature numbers.
## Read docs/RENDER_PIPELINE_POLICY_ja.md before adding any 3D effect.
##
## Opaque meshes use the engine's default depth buffer, not these priorities.
## These priorities apply only to transparent/overlay passes.
const AFTERIMAGE: int = -20             # Low-priority temporal ghosts.
const SLASH_VOLUME: int = 100            # Cutout slash volume/lens.
const SLASH_SURFACE: int = 105           # Sword's visible cutting arc.
const SLASH_PARTICLES: int = 110         # Small bright micro-particles.
const CHARACTER_FOREGROUND: int = 126  # Intentional slash-only, depthless SERA pass.
const DEPTH_TESTED_EMISSIVE: int = 127  # Flames/trails in front of overlay, still depth-tested.
## Godot's render_priority upper bound is +127. Don't increment these
## numbers for a new feature: choose the existing role or redesign the pass.
