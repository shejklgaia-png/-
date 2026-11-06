#!/usr/bin/env python3
"""v92 static + numerical smoke tests for damage/boost gesture recovery."""
from pathlib import Path
import hashlib, json, math, re, zipfile
root = Path(__file__).resolve().parents[1]
ref = Path('/mnt/data/sera_portrait_godot_melee_v91_enemy_attack_debug.zip')
main = (root/'scripts/main.gd').read_text()
rig = (root/'scripts/sera_rig.gd').read_text()
ui = (root/'scripts/touch_overlay.gd').read_text()
proj = (root/'project.godot').read_text()
total=0

def check(name, condition):
    global total
    assert condition, name
    total += 1
    print('PASS', name)

def number(label):
    m = re.search(r'const '+label+r': float = ([0-9.]+)', main)
    assert m, label
    return float(m.group(1))

check('v92 title updated', 'SERA v92 | Boost recovery after damage' in proj)
check('boost gate uses active damage, not latched release suppression',
      'if not gesture_active or damage_reaction_active:' in main and
      'if not gesture_active or gesture_suppressed_from_damage:' not in main)
check('boost gate called on physics ticks',
      'func _physics_process(delta: float) -> void:' in main and
      '_update_boost_gesture(delta)' in main)
check('boost suppression set on impact',
      'if gesture_active:\n        gesture_suppressed_from_damage = true' in main)
check('boost suppression initialized on new press',
      'gesture_suppressed_from_damage = damage_reaction_active' in main)
check('latched suppression observed on release',
      'var suppress_release_action: bool = gesture_suppressed_from_damage' in main and
      'if damage_reaction_active or suppress_release_action:' in main)
check('latched release suppression cleared on release only',
      main.count('gesture_suppressed_from_damage = false')==1)
check('damage completion remains tied to rig and knockback',
      'damage_knockback_elapsed >= DAMAGE_KNOCKBACK_DURATION' in main and
      'bool(rig.call("damage_finished"))' in main and
      'damage_reaction_active = false' in main and
      'rig.call("finish_damage",' in main)
check('bootstrap 1.5x remains', number('MOVEMENT_BOOST_MULTIPLIER')==1.5)
check('entry threshold 125% remains', number('BOOST_START_RADIUS_RATIO')==1.25)
check('exit threshold 110% remains', number('BOOST_EXIT_RADIUS_RATIO')==1.10)
check('entry confirmation 0.10 seconds remains', number('BOOST_CONFIRM_SECONDS')==.1)
check('0.15 seconds acceleration remains', number('BOOST_ACCELERATION_SECONDS')==.15)
check('controller radius unchanged', number('DRAG_RADIUS')==168.0)
check('rear step distance remains 4m', number('BACK_STEP_DISTANCE')==4.0)
check('strike damage unchanged', 'const STRIKE_DAMAGE = [12, 12, 26]' in main)
check('Boost_front animation still present', 'const BOOST_CLIP: String = "Boost_front"' in rig)
check('DEBUG enemy attack four types present', all(s in (root/'scripts/enemy_shooter.gd').read_text() for s in ('AIM','LEAD','SHOCK','ARC')))
check('UI threshold guide still linked', 'CONTROLLER_BOOST_START_RADIUS_RATIO: float = 1.25' in ui)

# Mirror the state transitions. These scenario tests exercise the behavior that
# was wrong in v91 (a continuing touch was blocked after damage recovery).
class Gesture:
    def __init__(self):
        self.active=False;self.hit=False;self.damage=False;self.boost=False
        self.timer=0.;self.speed=1.;self.ever=False;self.end_action=None
        self.radius=0.
    def press(self, during_damage=False):
        self.active=True;self.damage=during_damage;self.hit=during_damage
        self.boost=False;self.timer=0.;self.speed=1.;self.ever=False;self.radius=0.
    def move(self, radius):
        self.radius=radius
        self.tick(0)
    def tick(self, dt):
        if not self.active or self.damage:
            self.timer=0.
            self.boost=False
        elif self.boost:
            if self.radius < 168*1.10:
                self.boost=False; self.timer=0.
        elif self.radius >= 168*1.25:
            self.timer+=max(dt,0.)
            if self.timer >= .1:
                self.boost=True; self.ever=True
        else:
            self.timer=0.
        target=1.5 if self.boost else 1.0
        dv=.5*dt/.15
        self.speed=min(target,self.speed+dv) if self.speed<target else max(target,self.speed-dv)
    def impact(self):
        self.damage=True
        if self.active:self.hit=True
    def recovered(self):
        self.damage=False
    def release(self, flick=False, tap=False):
        self.active=False
        self.end_action='blocked' if self.damage or self.hit else ('step' if flick and not self.ever else ('attack' if tap else 'none'))
        self.hit=False;self.boost=False;self.timer=0.;self.speed=1.;self.ever=False
        return self.end_action

x=Gesture();x.press();x.move(220)
for _ in range(7):x.tick(.016)
check('hold over 125% confirms boost',x.boost)
x.impact();x.tick(.016)
check('hit immediately cancels boost',not x.boost and x.hit)
for _ in range(25):x.tick(.016)
check('same finger cannot boost during damage',not x.boost and x.timer==0.)
x.recovered()
for _ in range(6):x.tick(.016)
check('boost cannot start 96ms after damage',not x.boost)
x.tick(.016)
check('boost resumes same finger at >=0.10s',x.boost and x.hit)
check('release of damaged gesture cannot trigger STEP', x.release(flick=True)=='blocked')
x.press();x.move(220)
for _ in range(7):x.tick(.016)
check('fresh undamaged gesture still boosts',x.boost)
x.move(184.8);x.tick(.016)
check('hysteresis remains active at 110%',x.boost)
x.move(180);x.tick(.016)
check('below 110% drops boost',not x.boost)
x.release();x.press(during_damage=True);x.move(230)
for _ in range(30):x.tick(.016)
check('press during damage cannot boost',not x.boost)
x.recovered()
for _ in range(7):x.tick(.016)
check('press during damage can boost after recovery without release',x.boost)
check('release after press-during-damage remains blocked',x.release(flick=True)=='blocked')
x.press();x.move(50)
check('uninterrupted normal tap still triggers attack',x.release(tap=True)=='attack')
x.press();x.move(100)
check('uninterrupted flick still triggers step',x.release(flick=True)=='step')

if ref.is_file():
    with zipfile.ZipFile(ref) as z:
        old={f.filename.split('/',1)[1]:z.read(f) for f in z.infolist() if not f.is_dir() and '/' in f.filename}
    new={p.relative_to(root).as_posix():p.read_bytes() for p in root.rglob('*') if p.is_file()}
    changed={name for name in old.keys() & new.keys() if old[name]!=new[name]}
    added=set(new)-set(old); removed=set(old)-set(new)
    check('original files retained',not removed)
    check('only intended files edited', changed=={'scripts/main.gd','project.godot','DEVELOPMENT.md'})
    check('only v92 docs/test added',added=={'README_v92_ja.md','tools/v92_boost_damage_regression.py'})
    old_main=old['scripts/main.gd'].decode()
    check('main.gd only changes boost gate and comments', old_main.replace(
        '## v90: RUN edge snap, 125%/110% BOOST hysteresis, 0.10s confirm and 0.15s acceleration.',
        '## v90: RUN edge snap, 125%/110% BOOST hysteresis, 0.10s confirm and 0.15s acceleration.\n## v92: Restore BOOST eligibility after damage without requiring touch release.').replace(
        'func _update_boost_gesture(delta: float) -> void:\n    if not gesture_active or gesture_suppressed_from_damage:\n        boost_confirm_elapsed = 0.0',
        'func _update_boost_gesture(delta: float) -> void:\n    # Gate BOOST only while the damage reaction is actually in progress.\n    # gesture_suppressed_from_damage is deliberately latched until release to\n    # prevent a damaged hold from triggering a phantom STEP or tap attack;\n    # it must NOT block BOOST after the damage reaction finishes.\n    if not gesture_active or damage_reaction_active:\n        boost_confirm_elapsed = 0.0') == main)
    check('v91 source ZIP is present for diff',len(old)>0)
print(f'OK: {total} checks')
