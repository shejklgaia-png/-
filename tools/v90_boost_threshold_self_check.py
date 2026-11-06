#!/usr/bin/env python3
"""Static regression and independent numeric behavior checks for SERA v90."""
from pathlib import Path
import base64, hashlib, json, math, re, zipfile
ROOT=Path(__file__).resolve().parents[1]
BASE=Path('/mnt/data/sera_portrait_godot_melee_v89_boost_front_motion.zip')
main=(ROOT/'scripts/main.gd').read_text()
ui=(ROOT/'scripts/touch_overlay.gd').read_text()
rig=(ROOT/'scripts/sera_rig.gd').read_text()
project=(ROOT/'project.godot').read_text()
checks=0

def ok(label, value):
    global checks
    assert value, label
    checks += 1
    print('PASS', label)

def fconst(source,name):
    m=re.search(r'const '+re.escape(name)+r': float = ([0-9.]+)',source)
    assert m, name
    return float(m.group(1))

ok('project is v90', 'SERA v90' in project)
ok('renderer maintained GL compatibility', 'gl_compatibility' in project)
ok('full input radius remains 168', fconst(main,'DRAG_RADIUS')==168.0)
ok('enter ratio 125%', fconst(main,'BOOST_START_RADIUS_RATIO')==1.25)
ok('exit ratio 110%', fconst(main,'BOOST_EXIT_RADIUS_RATIO')==1.10)
ok('entry hold 0.10s', fconst(main,'BOOST_CONFIRM_SECONDS')==0.10)
ok('speed ramp 0.15s', fconst(main,'BOOST_ACCELERATION_SECONDS')==0.15)
ok('boost multiplier 1.5x', fconst(main,'MOVEMENT_BOOST_MULTIPLIER')==1.5)
ok('base run speed unchanged', fconst(main,'MOVE_SPEED')==3.25)
ok('run input clamps to 100% radius', 'direction_input = delta.limit_length(1.0)' in main)
ok('movement continues at rim without speed overflow', 'player.velocity = world_move * MOVE_SPEED * boost_speed_multiplier' in main)
ok('boost only confirms above start and dwell',
    'finger_distance >= DRAG_RADIUS * BOOST_START_RADIUS_RATIO' in main and
    'boost_confirm_elapsed += maxf(delta, 0.0)' in main and
    'if boost_confirm_elapsed >= BOOST_CONFIRM_SECONDS:' in main)
ok('boost remains active until below exit', 'if finger_distance < DRAG_RADIUS * BOOST_EXIT_RADIUS_RATIO:' in main)
ok('interrupted confirmation timer reset',
    '# Even a very short dip below 125% restarts entry confirmation.' in main and
    main.count('boost_confirm_elapsed = 0.0')>=4)
ok('still thumb triggers dwell via physics',
    'func _physics_process(delta: float) -> void:\n    # Sample' in main and
    '_update_boost_gesture(delta)' in main)
ok('exit updates on actual drag event', '_update_boost_gesture(0.0)' in main)
ok('linear accel and decel uses move_toward',
    'boost_speed_multiplier = move_toward(boost_speed_multiplier, boost_speed_target,' in main)
ok('release and new press reset boost speed', main.count('boost_speed_multiplier = 1.0') == 2)
ok('flick reserved until boost first confirms',
    '0 if boost_has_activated_this_gesture else _classify_step_flick' in main and
    'boost_has_activated_this_gesture = true' in main)
ok('backstep distance stays 4m', fconst(main,'BACK_STEP_DISTANCE')==4.0)
ok('flick direction timings unchanged',fconst(main,'STEP_FLICK_MAX_SECONDS')==0.24)
ok('three strikes unchanged', 'const STRIKE_DAMAGE = [12, 12, 26]' in main)
ok('boost pose unchanged', 'const BOOST_CLIP: String = "Boost_front"' in rig)
ok('rig 0.16s blend unchanged', 'const BLEND_SECONDS: float = 0.16' in rig)
ok('UI knob clamped to rim', 'knob_center: Vector2 = anchor_point + (finger_point - anchor_point).limit_length(radius)' in ui)
ok('UI entry guide matches runtime threshold', fconst(ui,'CONTROLLER_BOOST_START_RADIUS_RATIO')==fconst(main,'BOOST_START_RADIUS_RATIO'))
ok('guide visible only for rim overtravel before boost',
    'if finger_vector.length_squared() > radius * radius and not movement_boost_active:' in ui)
ok('pass-through touch UI', 'touch_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE' in main)
ok('normal and boost modes labeled', 'BOOST  1.5x' in ui and 'RUN  1.0x' in ui)
ok('original scene resource preserved', (ROOT/'scenes/main.tscn').is_file())
ok('source and embedded model identical', base64.b64decode(''.join(re.findall(r'^    "([A-Za-z0-9+/=]+)",$',(ROOT/'assets/sera_data.gd').read_text(),flags=re.M)))==(ROOT/'assets/sera_source.json').read_bytes())

# Independent numeric state-machine check mirrors the specification, not just the constants.
enter=fconst(main,'BOOST_START_RADIUS_RATIO')*fconst(main,'DRAG_RADIUS')
leave=fconst(main,'BOOST_EXIT_RADIUS_RATIO')*fconst(main,'DRAG_RADIUS')
class Controller:
    def __init__(self): self.boost=False; self.timer=0.; self.speed=1.; self.ever=False
    def tick(self,r,dt):
        if self.boost:
            if r < leave: self.boost=False; self.timer=0.
        elif r >= enter:
            self.timer += dt
            if self.timer >= .1: self.boost=True; self.ever=True
        else: self.timer=0.
        self.speed=min(1.5,self.speed+(.5*dt/.15)) if self.boost else max(1.,self.speed-(.5*dt/.15))

c=Controller()
for _ in range(100): c.tick(enter-0.1,.016)
ok('124.94% forever remains RUN', not c.boost and c.timer==0.0)
for _ in range(6): c.tick(enter,.016)
ok('96ms at 125% remains RUN', not c.boost and abs(c.timer-.096)<1e-9)
c.tick(enter,.016)
ok('112ms at 125% confirms BOOST', c.boost and c.ever)
ok('acceleration not instantly full', 1<c.speed<1.5)
for _ in range(10): c.tick(190,.016)
ok('inside hysteresis band retains BOOST', c.boost and abs(c.speed-1.5)<1e-9)
c.tick(leave-0.01,.016)
ok('below 110% immediately deactivates', not c.boost)
ok('decelerates rather than snaps speed', 1<c.speed<1.5)
for _ in range(15): c.tick(0,.016)
ok('return to normal speed within 0.15s', c.speed==1.0)
c=Controller()
for _ in range(5): c.tick(enter+2,.016)
c.tick(enter-1,.016)
for _ in range(3): c.tick(enter+2,.016)
ok('interrupted hold cannot activate BOOST',not c.boost and c.timer<.1)
for label, r in [('100% RUN',168),('110% RUN',184.8),('125% pending',210)]:
    cc=Controller(); cc.tick(r,.016)
    ok(label,not cc.boost)

if BASE.exists():
    with zipfile.ZipFile(BASE) as archive:
        # v89 is packed in a root folder; compare by entry suffix.
        members={p.split('/',1)[1]:archive.read(p) for p in archive.namelist() if '/' in p and not p.endswith('/')}
    now={p.relative_to(ROOT).as_posix():p.read_bytes() for p in ROOT.rglob('*') if p.is_file()}
    missing=set(members)-set(now)
    changed={n for n in members.keys() & now.keys() if members[n]!=now[n]}
    added=set(now)-set(members)
    ok('no baseline files removed',not missing)
    ok('only controller, project and history modified', changed=={'scripts/main.gd','scripts/touch_overlay.gd','project.godot','DEVELOPMENT.md'})
    ok('only v90 README and check script added',added=={'README_v90_ja.md','tools/v90_boost_threshold_self_check.py'})
    ok('all other resources, BB models and animation data byte-identical', all(members[n]==now[n] for n in members if n not in changed))
else:
    print('WARN baseline archive not present; byte-for-byte diff unavailable')
print(f'v90 static/behavior checks: {checks} passed; Godot/Android runtime not tested')
