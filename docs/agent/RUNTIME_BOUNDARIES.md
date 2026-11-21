# SERA エージェント — 実行時モジュール責務（原本から分離）

## v317 main.gd split contracts
Keep `main.gd` live state, inputs, collisions, scene effects, HUD priority and tick ordering. Extract presentation/math only without changing numeric thresholds. Require full post-merge main CI; verify Android visuals separately.

- **Gesture/locomotion:** `sera_input_gestures.gd`, `sera_movement_math.gd` own pure input and XZ transforms. Main owns touch, player and camera.
- **Lock:** `sera_lock_management.gd` owns paired-ray AUTO, manual screen-X wrap, facing and reticle geometry; main owns modes, combo lock and buttons. BODY ID is `""`; no delayed acquisition.
- **Combat:** `sera_combat_flow.gd` owns guard/combo gates, timing, clips and homing slices. Main owns strikes, queued input, EN, collision and authored animation. Normal 3-hit/Katana 2-hit and combo locks remain.
- **Camera:** `sera_camera_framing.gd` owns pure fit and STEP yaw; main owns physical camera, framing, zoom and collision.
- **BOOST:** `sera_boost_state.gd` owns finger hysteresis and 0.20s speed smoothstep. Main owns active touch, EN, equipment, visual pose and reversal continuity.
- **EN/SH:** `sera_resource_rules.gd` owns EN spending and recovery. Main owns HUD, KO and final BOOST sliver. Preserve 24/16 per-second rates, 0.25s spend pause, epsilon 0.0001 and 60% unlock.
- **Combat timers:** `sera_combat_timers.gd` owns countdown/stagger math. Main owns KO, UI, stagger/fire ordering and damage completion.
- **Hit FX:** `sera_hit_fx_presentation.gd` updates passed overlay/material/labels only. Main owns timers, hit-stop, parts, FX order and respawn.
- **Target:** `sera_target_lifecycle.gd` decides movement, firing and respawn. Main owns parts, 0.01s combo retry, locks, resets, KO teleport and HUD.
- **Physics frame:** `sera_physics_frame_rules.gd` owns pose grace, flight movement, real velocity, jet and burst gates. Main owns physics, rig/FX and input order; stationary melee retains exhaust.
- **Motion/nozzle:** `sera_motion_direction.gd` computes RUN/jet heading; `sera_nozzle_steering.gd` computes rear/left bias; `sera_thruster_presentation.gd` owns BOOST cache and final FX call. Main retains camera, movement, collision, EN and rig controls. Nozzle articulation limits stay ±80° yaw/up 1°/down 90°.
- **HUD:** `sera_combat_hud_text.gd` owns action text; `sera_numeric_hud.gd` owns numerical text; `sera_hud_layout.gd` builds panel, vitals and STEP nodes. Main keeps priority, resources, buttons, callbacks and input exclusion.

See `docs/SERA_DEVELOPMENT_FASTPATH_ja.md` and `DEVELOPMENT.md` for details.
