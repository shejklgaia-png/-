extends RefCounted
## V107 sampled RUN playback; native target tracking and planted turn controller.
const Bank = preload("res://assets/sera_v107_motion_data.gd")
const FRAME_BYTES: int = 158
const FLOOR_OFFSET: float = -0.03556323
var data: PackedByteArray = Marshalls.base64_to_raw(Bank.DATA)
var indices: Dictionary = {}
var enabled: bool = false
var initialized: bool = false
var heading: float = 0.0
var velocity: Vector3 = Vector3.ZERO
var running: bool = false
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
    turn_stage = 0
    over = 0.0
    cooldown = 0.0
    twist = Vector3.ZERO
    target_ready = false
    current_feet.clear()

func motion_velocity(wanted: Vector3, max_speed: float, delta: float) -> Vector3:
    if turn_stage != 0:
        velocity = Vector3.ZERO
    else:
        var seconds: float = 0.30 if wanted.length_squared() > 0.0001 else 0.19
        velocity = velocity.move_toward(wanted, max_speed * delta / seconds)
    running = velocity.length_squared() > 0.0025
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
    rest = [chain[2].global_transform, chain[5].global_transform]
    planted = rest.duplicate()
    current_feet = rest.duplicate()
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
    if is_run:
        turn_stage = 0
        over = 0.0
        var limit: float = 1.6 if velocity.length() < 1.4 else 3.2
        heading += clampf(err*7.0, -limit, limit)*dt
    elif chain.size() == 6:
        if turn_stage == 0:
            over = over+dt if absf(err) > deg_to_rad(55.0) else 0.0
            if over >= 0.045 and cooldown <= 0.0:
                _start_turn(rig, predicted, chain)
                over = 0.0
        if turn_stage != 0:
            _advance_turn(dt, predicted)
    rig.rotation.y = _wrap(heading-target_yaw)
    if turn_stage != 0 and chain.size() == 6:
        var waist: Node3D = rig.get_node_or_null("Waist") as Node3D
        if waist != null:
            var lift: float = 0.105 * _ease(rise_clock/0.14)
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
