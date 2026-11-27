extends RefCounted
## V111 sampled RUN playback; retain V107 native target tracking and planted turn controller.
const Bank = preload("res://assets/sera_v111_motion_data.gd")
const FRAME_BYTES: int = 158
const FLOOR_OFFSET: float = -0.03556323
var data: PackedByteArray = Marshalls.base64_to_raw(Bank.DATA)
var indices: Dictionary = {}
var enabled: bool = false
var initialized: bool = false
var heading: float = 0.0
var velocity: Vector3 = Vector3.ZERO
var running: bool = false
var speed_ratio: float = 0.0
var over: float = 0.0
var cooldown: float = 0.0
var twist: Vector3 = Vector3.ZERO
var turn_stage: int = 0
var timer: float = 0.0
var duration: float = 0.0
var base_yaw: float = 0.0
var goal_yaw: float = 0.0
var stage_yaw: float = 0.0
var swing: int = 0
var plans: int = 0
var plan_timer: float = 0.0
var foot_start: Array[Transform3D] = []
var foot_goal: Array[Transform3D] = []
var planted: Array[Transform3D] = []
var current_feet: Array[Transform3D] = []
var rest: Array[Transform3D] = []
var origin: Vector3 = Vector3.ZERO
var rise_clock: float = 0.0
var previous_target: float = 0.0
var target_ready: bool = false
var target_rate: float = 0.0

# V111's steady gait bank is unchanged. These presentation states restore
# the missing authored start/brake timing independently of physical velocity.
const START_SECONDS: float = 0.35
const STOP_SECONDS: float = 0.62
const START_LOAD: float = 0.105
const START_TOE_OFF: float = 0.124
const WAIT_NAME: String = "Wait_motion"
var transition: int = 0 # 0 steady, 1 drive, 2 brake/recover
var transition_time: float = 0.0
var requested: bool = false
var action_direction: Vector3 = Vector3.FORWARD
var action_feet: Array[Transform3D] = []
var action_pose: Dictionary = {}
var action_match: float = 0.0
var action_lead: int = 0
var action_end: Vector3 = Vector3.ZERO
var action_reach: float = 0.10
var action_settled: bool = false
var action_load: float = 1.0
var action_lift: float = 0.015
var action_brake_goal: Transform3D = Transform3D.IDENTITY

func _s5(u: float) -> float:
    var x: float = clampf(u, 0.0, 1.0)
    return x*x*x*(10.0+x*(-15.0+6.0*x))

func _capture_action(rig: Node3D, chain: Array[Node3D]) -> void:
    action_feet.assign([chain[2].global_transform, chain[5].global_transform])
    action_pose.clear()
    var bones: Dictionary = rig.get("bones")
    for uid in Bank.UUIDS:
        var node: Node3D = bones[uid]
        action_pose[uid] = Transform3D(node.basis, node.position)
    transition_time = 0.0

# Local rigid-chain FK, using the same UUIDs, bind positions and sampled
# rotations as the renderer. No mutation of the live rig during phase choice.
func _foot_local(rig: Node3D, side: int, angle: float, phase: float, idle: bool) -> Transform3D:
    var bind: Dictionary = rig.get("bind_positions")
    var f := Transform3D.IDENTITY
    for i in [0, 13+side*3, 14+side*3, 15+side*3]:
        var uid: String = Bank.UUIDS[i]
        var p: Dictionary
        if idle:
            p = rig.call("_sample_step_clip_pose", WAIT_NAME, uid, 0.0)
        else:
            p = sample(uid, angle, phase)
        var offset: Vector3 = p["position"]
        var q: Quaternion = p["rotation"]
        f = f * Transform3D(Basis(q), (bind[uid] as Vector3)+offset)
    return f

func _choose_start(rig: Node3D, direction: Vector3) -> float:
    var local: Vector3 = rig.global_basis.orthonormalized().inverse() * direction
    var angle: float = atan2(local.x, -local.z)
    var best: float = -INF
    var result: float = 95.0/120.0 if action_lead == 0 else 35.0/120.0
    if local.z < -0.68:
        return result
    for i in range(Bank.PHASES):
        var phase: float = float(i)/float(Bank.PHASES)
        var a: Transform3D = _foot_local(rig, action_lead, angle, phase, false)
        var b: Transform3D = _foot_local(rig, 1-action_lead, angle, phase, false)
        var advance: float = (a.origin-b.origin).dot(local)
        if advance <= 0.0:
            continue
        var score: float = advance + (0.5 if a.origin.y < b.origin.y else 0.0) \
            - 3.0*maxf(0.0, a.origin.y-b.origin.y)
        if score > best:
            best = score
            result = phase
    return result

# Called before the physics body moves, so the foot anchors belong to the
# actually displayed preceding frame. Re-input interrupts STOP immediately.
func prepare_transition(rig: Node3D, wanted: Vector3, is_run: bool, is_wait: bool,
        max_speed: float, physics_delta: float) -> void:
    if not is_run and not is_wait:
        requested = false
        transition = 0
        return
    if turn_stage != 0:
        requested = false
        return
    var active: bool = wanted.length_squared() > 0.0001
    if active and not requested and (is_wait or transition == 2):
        var chain: Array[Node3D] = _chains(rig)
        if chain.size() == 6:
            action_direction = wanted.normalized()
            _capture_action(rig, chain)
            action_lead = 0 if (action_feet[0].origin-action_feet[1].origin).dot(action_direction) > 0.0 else 1
            action_match = _choose_start(rig, action_direction)
            action_load = 1.0-clampf(speed_ratio, 0.0, 1.0)
            transition = 1
    elif not active and requested:
        if is_run and velocity.length() > 0.12:
            var chain: Array[Node3D] = _chains(rig)
            if chain.size() == 6:
                action_direction = velocity.normalized()
                _capture_action(rig, chain)
                var front: int = 0 if (action_feet[0].origin-action_feet[1].origin).dot(action_direction) > 0.0 else 1
                # Use the lower displayed sole when available, not a gait
                # reset or a hard-coded left/right braking foot.
                var equipment: RefCounted = rig.get("equipment_handler")
                var heights: Dictionary = equipment.call("get_active_foot_heights")
                var left: float = float(heights.get("L", action_feet[0].origin.y))
                var right: float = float(heights.get("R", action_feet[1].origin.y))
                var front_low: bool = (left <= right+0.035) if front == 0 else (right <= left+0.035)
                action_lead = 1-front if front_low else front
                var lead_low: bool = (left <= right+0.035) if action_lead == 0 else (right <= left+0.035)
                action_lift = 0.085 if lead_low else 0.015
                action_reach = 0.145 if front_low else 0.10
                # Match the discrete move_toward deceleration integral.
                # Keep the brake foot target fixed even if collision changes
                # the actual stopping point; rebase only the recovery stance.
                var step: float = maxf(0.00001, max_speed*physics_delta/0.19)
                var ticks: float = maxf(0.0, ceilf(velocity.length()/step)-1.0)
                var travel: float = maxf(0.0, physics_delta*(ticks*velocity.length()
                    - step*ticks*(ticks+1.0)*0.5))
                action_end = rig.global_position+action_direction*travel
                var end_frame: Transform3D = rig.global_transform
                end_frame.origin = action_end
                action_brake_goal = end_frame*_foot_local(rig, action_lead, 0.0, 0.0, true)
                var forward_offset: float = (action_brake_goal.origin-action_end).dot(action_direction)
                action_brake_goal.origin += action_direction*((0.27 if front_low else 0.34)-forward_offset)
                action_settled = false
                transition = 2
        elif transition == 1:
            transition = 0
    requested = active

func advance_transition(delta: float) -> void:
    if transition != 0:
        transition_time = minf(START_SECONDS if transition == 1 else STOP_SECONDS,
            transition_time+maxf(0.0, delta))

func start_phase() -> float:
    return fposmod(action_match-(START_SECONDS-transition_time)*1.875, 1.0)

func _step_target(a: Transform3D, b: Transform3D, u: float, lift: float) -> Transform3D:
    var x: float = clampf(u, 0.0, 1.0)
    var f: Transform3D = a.interpolate_with(b, _s5(x))
    f.origin.y += lift*sin(PI*x)
    return f

# Lower the visual waist within a bounded range to give the planted foot
# reach; preserve physical player/capsule, and solve the existing rigid legs.
func _fit_action(rig: Node3D, chain: Array[Node3D], goals: Array[Transform3D], support: int) -> void:
    var waist: Node3D = rig.get_node_or_null("Waist") as Node3D
    if waist == null:
        return
    var j: int = support*3
    var hip: Vector3 = chain[j].global_position
    var reach: float = hip.distance_to(chain[j+1].global_position) \
        + chain[j+1].global_position.distance_to(chain[j+2].global_position)-0.004
    var d: Vector3 = goals[support].origin-hip
    var flat: float = d.x*d.x+d.z*d.z
    var lower: float = minf(0.0, d.y+sqrt(maxf(0.0, reach*reach-flat)))
    waist.position.y += maxf(-0.18, lower)
    for i in range(2):
        _solve(chain[i*3], chain[i*3+1], chain[i*3+2], goals[i])

# Called AFTER target-facing yaw and the normal RUN sample are applied.
# Capture/release blends use local rotations, while support goals are world
# transforms. This is the native recreation of V111's drive83/pose76 beats.
func apply_transition(rig: Node3D) -> void:
    if transition == 0 or action_feet.size() != 2:
        return
    var chain: Array[Node3D] = _chains(rig)
    if chain.size() != 6:
        transition = 0
        return
    var t: float = transition_time
    var starting: bool = transition == 1
    var u: float = clampf(t/(START_SECONDS if starting else STOP_SECONDS), 0.0, 1.0)
    var bones: Dictionary = rig.get("bones")
    var bind: Dictionary = rig.get("bind_positions")
    var goal: Array[Transform3D] = []
    var live_feet: Array[Transform3D] = []
    var local_dir: Vector3 = rig.global_basis.orthonormalized().inverse()*action_direction
    var angle: float = atan2(local_dir.x, -local_dir.z)
    if starting:
        live_feet.assign([chain[2].global_transform, chain[5].global_transform])
        for i in range(2):
            goal.append(rig.global_transform*_foot_local(rig, i, angle, action_match, false))
    else:
        if not action_settled and velocity.length_squared() < 0.000001:
            action_end = rig.global_position
            action_settled = true
        var end_frame: Transform3D = rig.global_transform
        end_frame.origin = action_end
        for i in range(2):
            goal.append(end_frame*_foot_local(rig, i, 0.0, 0.0, true))
    var blend: float = _s5((t-START_LOAD)/(START_SECONDS-START_LOAD)) if starting else _ease(t/0.55)
    var join: float = _s5((t-0.253)/(START_SECONDS-0.253)) if starting else _ease((t-0.52)/0.10)
    for uid in Bank.UUIDS:
        if not action_pose.has(uid):
            continue
        var node: Node3D = bones[uid]
        var initial: Transform3D = action_pose[uid]
        var target: Transform3D = node.transform
        if starting:
            # One planned endpoint during load/drive; blend to the live
            # gait only at handoff instead of chasing its bob throughout.
            var planned: Dictionary = sample(uid, angle, action_match)
            var planned_q: Quaternion = planned["rotation"]
            var planned_pos: Vector3 = planned["position"]
            var fixed: Transform3D = Transform3D(Basis(planned_q), (bind[uid] as Vector3)+planned_pos)
            target = fixed.interpolate_with(target, join)
        else:
            var p: Dictionary = rig.call("_sample_step_clip_pose", WAIT_NAME, uid, 0.0)
            var idle_q: Quaternion = p["rotation"]
            target = Transform3D(Basis(idle_q), (bind[uid] as Vector3)+(p["position"] as Vector3))
        node.transform = initial.interpolate_with(target, blend)
    var waist: Node3D = bones[Bank.UUIDS[0]]
    var load: float = _ease(t/START_LOAD)*(1.0-_s5((t-START_LOAD)/(START_SECONDS-START_LOAD))) if starting else \
        _ease(t/action_reach)*(1.0-_ease((t-0.21)/0.27))
    load *= action_load if starting else 1.0
    waist.position.y -= (0.125 if starting else 0.095)*load
    var tilt_axis: Vector3 = Vector3.UP.cross(local_dir)
    if tilt_axis.length_squared() > 0.0001:
        waist.quaternion = (Quaternion(tilt_axis.normalized(), (0.10 if starting else -0.12)*load)*waist.quaternion).normalized()
    var k: int = action_lead
    var o: int = 1-k
    var targets: Array[Transform3D] = []
    targets.assign(action_feet)
    if starting:
        # Rear support stays in world space through toe-off; both feet
        # converge to the actual chosen RUN sample, not phase zero.
        targets[k] = _step_target(action_feet[k], goal[k], (t-0.025)/0.235, 0.075)
        targets[o] = _step_target(action_feet[o], goal[o], (t-START_TOE_OFF)/(0.29-START_TOE_OFF), 0.06)
        for i in range(2):
            targets[i] = targets[i].interpolate_with(live_feet[i], join)
    else:
        var ahead: Transform3D = action_brake_goal
        # Freeze the planned brake plant at predicted stop position; collect
        # the other foot, then return the braking foot to the idle stance.
        targets[k] = _step_target(action_feet[k], ahead, t/action_reach, action_lift) if t < action_reach else \
            _step_target(ahead, goal[k], (t-0.28)/0.24, 0.07)
        targets[o] = _step_target(action_feet[o], goal[o], (t-minf(action_reach, 0.06))/(0.28-minf(action_reach, 0.06)), 0.075)
        for i in range(2):
            targets[i] = targets[i].interpolate_with(goal[i], join)
    if u < 0.99999:
        _fit_action(rig, chain, targets, o if starting and t < START_TOE_OFF else (k if not starting and t >= action_reach and t < 0.28 else o))
    # Exact endpoint already is the corresponding local RUN/WAIT sample.
    if u >= 0.99999:
        transition = 0
        action_pose.clear()
        action_feet.clear()


func _init() -> void:
    for i in range(Bank.UUIDS.size()):
        indices[Bank.UUIDS[i]] = i

func valid() -> bool:
    return data.size() == Bank.DIRECTIONS * Bank.PHASES * FRAME_BYTES

func has_bone(uid: String) -> bool:
    return indices.has(uid)

func _frame(d: int, p: int) -> int:
    return (posmod(d, Bank.DIRECTIONS) * Bank.PHASES + posmod(p, Bank.PHASES)) * FRAME_BYTES

func _quat(offset: int) -> Quaternion:
    return Quaternion(float(data.decode_s16(offset)), float(data.decode_s16(offset + 2)),
        float(data.decode_s16(offset + 4)), float(data.decode_s16(offset + 6))).normalized()

func _root(offset: int) -> Vector3:
    return Vector3(data.decode_s16(offset + 152), data.decode_s16(offset + 154),
        data.decode_s16(offset + 156)) * 0.001

func sample(uid: String, angle: float, phase: float) -> Dictionary:
    var d: float = fposmod(angle / TAU, 1.0) * Bank.DIRECTIONS
    var p: float = fposmod(phase, 1.0) * Bank.PHASES
    var di: int = floori(d)
    var pi: int = floori(p)
    var da: float = d - di
    var pa: float = p - pi
    var offset: int = int(indices[uid]) * 8
    var a: int = _frame(di, pi)
    var b: int = _frame(di, pi + 1)
    var c: int = _frame(di + 1, pi)
    var e: int = _frame(di + 1, pi + 1)
    var q: Quaternion = _quat(a + offset).slerp(_quat(b + offset), pa).slerp(
        _quat(c + offset).slerp(_quat(e + offset), pa), da).normalized()
    var pos: Vector3 = Vector3.ZERO
    if offset == 0:
        pos = _root(a).lerp(_root(b), pa).lerp(_root(c).lerp(_root(e), pa), da)
    return {"rotation": q, "position": pos, "scale": Vector3.ONE}

func cancel() -> void:
    initialized = false
    velocity = Vector3.ZERO
    running = false
    speed_ratio = 0.0
    turn_stage = 0
    over = 0.0
    cooldown = 0.0
    twist = Vector3.ZERO
    target_ready = false
    current_feet.clear()
    transition = 0
    transition_time = 0.0
    requested = false
    action_feet.clear()
    action_pose.clear()

func motion_velocity(wanted: Vector3, max_speed: float, delta: float) -> Vector3:
    if turn_stage != 0:
        velocity = Vector3.ZERO
    else:
        var seconds: float = 0.30 if wanted.length_squared() > 0.0001 else 0.19
        velocity = velocity.move_toward(wanted, max_speed * delta / seconds)
    running = velocity.length_squared() > 0.0025
    speed_ratio = clampf(velocity.length() / maxf(max_speed, 0.001), 0.0, 1.0)
    return velocity

func _wrap(a: float) -> float:
    return wrapf(a, -PI, PI)

func _ease(t: float) -> float:
    var x: float = clampf(t, 0.0, 1.0)
    return x * x * (3.0 - 2.0 * x)

func _rotate_foot(t: Transform3D, angle: float) -> Transform3D:
    var b := Basis(Vector3.UP, angle)
    return Transform3D(b * t.basis, origin + b * (t.origin - origin))

func _chains(rig: Node3D) -> Array[Node3D]:
    var out: Array[Node3D] = []
    for side in ["L", "R"]:
        var hip: Node3D = rig.get_node_or_null("Waist/Thigh_" + side) as Node3D
        if hip == null:
            return []
        var knee: Node3D = hip.get_node_or_null("LowerLeg_" + side) as Node3D
        if knee == null:
            return []
        var foot: Node3D = knee.get_node_or_null("Foot_" + side) as Node3D
        if foot == null:
            return []
        out.append_array([hip, knee, foot])
    return out

func _solve(hip: Node3D, knee: Node3D, foot: Node3D, goal: Transform3D) -> void:
    var h: Vector3 = hip.global_position
    var k: Vector3 = knee.global_position
    var a: Vector3 = foot.global_position
    var l1: float = h.distance_to(k)
    var l2: float = k.distance_to(a)
    var v: Vector3 = goal.origin - h
    if v.length_squared() < 0.000001 or l1 < 0.01 or l2 < 0.01:
        return
    var axis: Vector3 = v.normalized()
    var d: float = clampf(v.length(), absf(l1 - l2) + 0.003, l1 + l2 - 0.003)
    var pole: Vector3 = k - h - axis * (k - h).dot(axis)
    if pole.length_squared() < 0.000001:
        pole = -hip.global_basis.z
        pole -= axis * pole.dot(axis)
    if pole.length_squared() < 0.000001:
        return
    var x: float = (l1*l1 + d*d - l2*l2) / (2.0*d)
    var desired: Vector3 = h + axis*x + pole.normalized()*sqrt(maxf(0.0,l1*l1-x*x))
    hip.global_basis = Basis(Quaternion((k-h).normalized(), (desired-h).normalized())) * hip.global_basis
    var k2: Vector3 = knee.global_position
    var src: Vector3 = foot.global_position - k2
    var dst: Vector3 = h + axis*d - k2
    if src.length_squared() > 0.000001 and dst.length_squared() > 0.000001:
        knee.global_basis = Basis(Quaternion(src.normalized(), dst.normalized())) * knee.global_basis
    foot.global_basis = goal.basis

func _start_turn(rig: Node3D, target: float, chain: Array[Node3D]) -> void:
    turn_stage = 1
    timer = 0.0
    rise_clock = 0.0
    plans = 0
    plan_timer = 0.0
    base_yaw = heading
    goal_yaw = base_yaw + clampf(_wrap(target-base_yaw), -deg_to_rad(75.0), deg_to_rad(75.0))
    origin = rig.global_position
    # Plan toward the actual authored idle stance, not a rotated arbitrary
    # last frame of a crossfade. Start from the displayed contacts.
    rest.assign([rig.global_transform*_foot_local(rig, 0, 0.0, 0.0, true),
        rig.global_transform*_foot_local(rig, 1, 0.0, 0.0, true)])
    planted.assign([chain[2].global_transform, chain[5].global_transform])
    current_feet = planted.duplicate()
    # Positive Godot yaw turns left. Move the inside foot first.
    swing = 0 if goal_yaw > base_yaw else 1
    _plan_step()

func _plan_step() -> void:
    foot_start = current_feet.duplicate()
    foot_goal = planted.duplicate()
    foot_goal[swing] = _rotate_foot(rest[swing], goal_yaw - base_yaw)
    duration = 0.19 + absf(rad_to_deg(_wrap(goal_yaw - heading))) * 0.0012 if turn_stage == 1 else 0.19
    stage_yaw = heading

func _advance_turn(dt: float, target: float) -> void:
    timer += dt
    rise_clock += dt
    plan_timer += dt
    var u: float = clampf((timer - 0.025) / duration, 0.0, 1.0)
    if turn_stage == 1 and plans < 2 and plan_timer > 0.075 and u < 0.84:
        var requested: float = base_yaw + clampf(_wrap(target-base_yaw), -deg_to_rad(75.0), deg_to_rad(75.0))
        var flip: bool = (requested-base_yaw)*(goal_yaw-base_yaw) < 0.0
        if absf(_wrap(requested-goal_yaw)) > deg_to_rad(12.0 if flip else 15.0) and (flip or u < 0.55):
            goal_yaw = requested
            foot_start = current_feet.duplicate()
            foot_goal[swing] = _rotate_foot(rest[swing], goal_yaw-base_yaw)
            duration = maxf(0.12, duration*(1.0-u))
            timer = 0.025
            u = 0.0
            stage_yaw = heading
            plans += 1
            plan_timer = 0.0
    var alpha: float = _ease(u)
    var foot_pose: Transform3D = foot_start[swing].interpolate_with(foot_goal[swing], alpha)
    var toe_alpha: float = _ease((u - 0.08) / 0.62)
    foot_pose.basis = foot_start[swing].basis.slerp(foot_goal[swing].basis, toe_alpha)
    foot_pose.origin.y += 0.075 * sin(PI*u)
    current_feet[swing] = foot_pose
    var goal_heading: float = lerpf(base_yaw, goal_yaw, 0.68) if turn_stage == 1 else goal_yaw
    heading = lerpf(stage_yaw, goal_heading, alpha)
    if u >= 1.0:
        planted[swing] = foot_goal[swing]
        current_feet[swing] = foot_goal[swing]
        if turn_stage == 1:
            turn_stage = 2
            swing = 1-swing
            timer = 0.025
            _plan_step()
        else:
            turn_stage = 0
            heading = goal_yaw
            cooldown = 0.06

func present(rig: Node3D, delta: float, is_run: bool, target_yaw: float) -> void:
    var dt: float = clampf(delta, 0.0, 0.10)
    if not initialized:
        heading = target_yaw
        initialized = true
    var predicted: float = target_yaw
    if target_ready and dt > 0.0:
        var raw: float = _wrap(target_yaw-previous_target)/dt
        target_rate = lerpf(target_rate, clampf(raw, -8.0, 8.0), 1.0-exp(-15.0*dt))
        predicted += target_rate * 0.12
    previous_target = target_yaw
    target_ready = true
    var err: float = _wrap(target_yaw-heading)
    var chain: Array[Node3D] = _chains(rig)
    cooldown = maxf(0.0, cooldown-dt)
    # The physical body keeps its existing lock and collision transform.
    rig.rotation.y = _wrap(heading-target_yaw)
    var was_turning: bool = turn_stage != 0
    if is_run:
        turn_stage = 0
        over = 0.0
        var limit: float = 1.6 if velocity.length() < 1.4 else 3.2
        if transition != 2:
            heading += clampf(err*7.0, -limit, limit)*dt
    elif chain.size() == 6:
        if turn_stage == 0 and not requested and float(rig.get("blending_for")) >= float(rig.get("blend_duration")):
            over = over+dt if absf(err) > deg_to_rad(55.0) else 0.0
            if over >= 0.045 and cooldown <= 0.0:
                var turn_target: float = predicted if _wrap(predicted-heading)*err > 0.0 else target_yaw
                _start_turn(rig, turn_target, chain)
                over = 0.0
        if turn_stage != 0:
            _advance_turn(dt, predicted)
    rig.rotation.y = _wrap(heading-target_yaw)
    if (turn_stage != 0 or (was_turning and not is_run)) and chain.size() == 6:
        var waist: Node3D = rig.get_node_or_null("Waist") as Node3D
        if waist != null:
            var lift: float = 0.105 * _ease(rise_clock/0.14) if turn_stage != 0 else 0.0
            if turn_stage == 2:
                lift *= 1.0-_ease(timer/duration)
            # Respect reach of both rigid chains before raising the pelvis.
            for i in range(2):
                var hip: Node3D = chain[i*3]
                var knee: Node3D = chain[i*3+1]
                var foot: Node3D = chain[i*3+2]
                var reach: float = hip.global_position.distance_to(knee.global_position) + knee.global_position.distance_to(foot.global_position)-0.005
                var v: Vector3 = current_feet[i].origin-hip.global_position
                var flat: float = v.x*v.x+v.z*v.z
                lift = minf(lift, v.y+sqrt(maxf(0.0,reach*reach-flat)))
            waist.position.y += maxf(0.0,lift)
        for i in range(2):
            _solve(chain[i*3], chain[i*3+1], chain[i*3+2], current_feet[i])
    var e: float = clampf(rad_to_deg(_wrap(target_yaw-heading)), -60.0, 60.0)
    var m: float = absf(e)
    var w: float = signf(e)*minf(12.0,maxf(0.0,m-20.0)*0.30)
    var c: float = signf(e)*minf(20.0,maxf(0.0,m-8.0)*0.40)
    var h: float = clampf(e-w-c,-28.0,28.0)
    var dest := Vector3(w,c,h)
    for i in range(3):
        var rate: float = [10.0,15.0,24.0][i]
        var cap: float = [100.0,180.0,300.0][i]*dt
        twist[i] += clampf((dest[i]-twist[i])*(1.0-exp(-rate*dt)),-cap,cap)
    for i in range(3):
        var uid: String = Bank.UUIDS[[1,2,4][i]]
        var bones: Dictionary = rig.get("bones")
        var bone: Node3D = bones.get(uid) as Node3D
        if bone != null:
            bone.quaternion = (Quaternion(Vector3.UP,deg_to_rad(twist[i]))*bone.quaternion).normalized()

    # RUN already includes V111's approved sword-arm poses in the bank.
    # On WAIT, the native turn still uses the authored idle arm chain:
    # reproduce V111's wrist extension in rig space after target twist.
    if not is_run:
        _present_v111_idle_blade(rig)

# Standard A blade axis is local -Z. These idle references and conservative
# local sword bounds are recovered from Standard.bbmodel / approved V111.
const V111_IDLE_CHEST := Quaternion(-0.13002907, -0.25660526, -0.01137679, 0.95766213)
const V111_IDLE_HAND := Quaternion(-0.02280013, -0.18007302, -0.52144305, 0.83375716)
const V111_BLADE_MIN := Vector3(-0.13031, -0.065, -1.50918)
const V111_BLADE_MAX := Vector3(0.38969, 0.065, 0.31082)

func _v111_blade_height(q: Quaternion, wrist: Vector3) -> float:
    # Conservative eight-corner bound; no per-frame mesh reads.
    var low: float = INF
    for x in [V111_BLADE_MIN.x, V111_BLADE_MAX.x]:
        for y in [V111_BLADE_MIN.y, V111_BLADE_MAX.y]:
            for z in [V111_BLADE_MIN.z, V111_BLADE_MAX.z]:
                low = minf(low, (wrist + q * Vector3(x, y, z)).y)
    return low

func _present_v111_idle_blade(rig: Node3D) -> void:
    if str(rig.call("get_equipment_selection", "weapon_r")) != "A":
        return
    var blocker: Dictionary = rig.call("get_equipment_two_handed_blocker", "weapon_r")
    if not blocker.is_empty():
        return
    var bones: Dictionary = rig.get("bones")
    var chest: Node3D = bones.get(Bank.UUIDS[2]) as Node3D
    var forearm: Node3D = bones.get(Bank.UUIDS[11]) as Node3D
    var hand: Node3D = bones.get(Bank.UUIDS[12]) as Node3D
    if chest == null or forearm == null or hand == null:
        return
    var rb: Basis = rig.global_basis.orthonormalized()
    var chest_q: Quaternion = (rb.inverse() * chest.global_basis.orthonormalized()).get_rotation_quaternion()
    var chest_delta: Quaternion = (chest_q * V111_IDLE_CHEST.normalized().inverse()).normalized()
    var chest_forward: Vector3 = chest_delta * Vector3.FORWARD
    var yaw: float = atan2(-chest_forward.x, -chest_forward.z)
    var base: Quaternion = (Quaternion(Vector3.UP, yaw * 0.45) *
        Quaternion(Vector3.RIGHT, deg_to_rad(8.0)) * V111_IDLE_HAND.normalized()).normalized()
    var wrist: Vector3 = rig.to_local(hand.global_position)
    var arm_axis: Vector3 = wrist - rig.to_local(forearm.global_position)
    if arm_axis.length_squared() < 0.000001:
        return
    var blade: Vector3 = base * Vector3.FORWARD
    var turn := Quaternion(blade.normalized(), arm_axis.normalized())
    var angle: float = blade.normalized().angle_to(arm_axis.normalized())
    var amount: float = minf(0.22, deg_to_rad(12.0) / maxf(angle, 0.000001))
    var floor_y: float = -rig.position.y + 0.06
    if _v111_blade_height(base, wrist) < floor_y:
        return
    var q: Quaternion = (Quaternion.IDENTITY.slerp(turn, amount) * base).normalized()
    if _v111_blade_height(q, wrist) < floor_y:
        var lo: float = 0.0
        var hi: float = amount
        for i in range(16):
            var mid: float = (lo + hi) * 0.5
            var candidate: Quaternion = (Quaternion.IDENTITY.slerp(turn, mid) * base).normalized()
            if _v111_blade_height(candidate, wrist) >= floor_y:
                lo = mid
            else:
                hi = mid
        q = (Quaternion.IDENTITY.slerp(turn, lo) * base).normalized()
    var blend: float = _ease(float(rig.get("blending_for")) /
        maxf(0.00001, float(rig.get("blend_duration"))))
    var current: Quaternion = (rb.inverse() * hand.global_basis.orthonormalized()).get_rotation_quaternion()
    hand.global_basis = rb * Basis(current.slerp(q, blend).normalized())
