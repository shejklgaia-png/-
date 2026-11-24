# Texture Studio V24 face paint experiment

Ptex-inspired logical face patches, packed into a working atlas without global
grid deformation. Strict authored face separation (coplanar fallback for
unlabelled geometry). Existing V20 modes remain available. Experimental mode is
selected by cycling the UV mode button and explicitly rebuilding.

Local stroke crossing unfolds only two physically adjacent triangles, solves
the crossing parameter along their shared 3D edge, and draws independently
into both texel grids. Existing physical-edge pixel correspondence remains.
For ordinary pen/eraser, bounded 3D sample history is saved alongside layers;
the raster layers remain authoritative. Full vector replay/repacking and
history-aware undo are not implemented yet. History is marked incomplete after
unsupported tools, undo/redo/deletion, or limits. Save exports the normal
atlas and mesh; integer copying and existing padding are used, not resampling.
Working atlas is a storage optimization, not native .ptex format.

References:
- https://disneyanimation.com/open-source/ptex/
- https://www.cemyuksel.com/research/meshcolors/
- https://3dcoat.com/documentation/manual/workspaces-rooms/paint/texture-painting-and-modes/ptex-painting/
- https://docs.godotengine.org/en/stable/classes/class_image.html
- https://docs.godotengine.org/en/stable/classes/class_imagetexture.html

Validation: actual catalog mesh on Linux Godot, compare V20 and V24, actual
packed UV overlap/winding/physical coverage, midpoint bridge and PNG byte
round-trip, restore triangles from mesh. This does not certify arbitrary
cross-face brush paths, visual seam quality, independent post-paint repacking,
or Android hardware. Keep V20 as default until checked.
