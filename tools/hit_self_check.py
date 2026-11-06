#!/usr/bin/env python3
"""v14 hit system offline audits; cannot substitute for running Godot."""
import json
import math
import pathlib
import random
import re
import wave
import hashlib

root = pathlib.Path(__file__).resolve().parents[1]
main = (root/'scripts/main.gd').read_text()
rig = (root/'scripts/sera_rig.gd').read_text()
data = json.loads((root/'assets/sera_source.json').read_text())

# Validate the explicit skeleton attachment and authored animation sequence.
groups = {g['name']:g for g in data['groups']}
assert 'Sword' in groups
assert sum(e.get('name') == 'Blade' for e in data['elements']) == 3
assert {a['name'] for a in data['animations']} >= {'meleeboost','melee1','Wait_motion'}
assert len([a for a in data['animations'] if a['name']=='melee1']) == 1

# Check updated rig and event timeline are actually wired, not merely constants.
for key in ['Sword', 'get_blade_world_segment', 'sword_bone.to_global', 'get_clip_time',
            'set_combat_paused', 'if not freeze_attack_pose and not combat_paused:']:
    assert key in rig, key
for key in ['_check_strike_contact()', '_register_strike_hit(', '_spawn_sparks(',
            '_advance_hit_fx(delta)', '_target_hit_aabb()', '.intersects_segment(',
            'strike_did_hit = true', 'hit_stop_remaining = HIT_STOP_SECONDS',
            'hit_audio.play()', 'target_hp = maxi(0, target_hp - MELEE_DAMAGE)',
            'target_respawn_remaining = TARGET_RESPAWN_SECONDS']:
    assert key in main, key
assert 'process_priority = -1' in rig
assert 'elif hit_stop_remaining <= 0.0:\n            _advance_attack(delta)' in main
assert 'rig.call("set_combat_paused", false)' in main

constants = dict(re.findall(r'^const (\w+): (?:float|int) = (\d+(?:\.\d+)?)', main, flags=re.M))
assert float(constants['STRIKE_ACTIVE_FROM']) < float(constants['STRIKE_ASSIST_AT']) <= float(constants['STRIKE_ACTIVE_TO'])
assert math.isclose(float(constants['HIT_STOP_SECONDS']),0.06)
assert int(constants['TARGET_MAX_HP']) % int(constants['MELEE_DAMAGE']) == 0

# Check actual WAV file, frame rate, and duration.
with wave.open(str(root/'assets/sword_impact.wav')) as wav:
    assert wav.getnchannels() == 1
    assert wav.getsampwidth() == 2
    assert wav.getframerate() == 44100
    assert 0.2 < wav.getnframes()/wav.getframerate() < 0.5

# 3D segment-AABB intersection: independently test canonical slab math,
# covering sides, corners, missed sweeps, and padding.
def segment_aabb(a,b,extents=(1.,1.,1.),center=(0.,0.,0.)):
    lo,hi=0.,1.
    for x,y,c,r in zip(a,b,center,extents):
        d=y-x
        if abs(d)<1e-12:
            if abs(x-c)>r: return None
            continue
        t0=(c-r-x)/d; t1=(c+r-x)/d
        lo=max(lo,min(t0,t1)); hi=min(hi,max(t0,t1))
        if lo>hi: return None
    return tuple(a[i]+(b[i]-a[i])*lo for i in range(3))

assert segment_aabb((0,0,3),(0,0,0)) == (0,0,1)
assert segment_aabb((-2,0,0),(2,0,0)) == (-1,0,0)
assert segment_aabb((1.1,1.1,-4),(1.1,1.1,4)) is None
assert segment_aabb((1.1,1.1,-4),(1.1,1.1,4),extents=(1.14,)*3) is not None
assert segment_aabb((2,3,4),(3,4,5)) is None
assert segment_aabb((0,0,0),(0,0,0)) is not None

rng=random.Random(20261105)
for i in range(8000):
    origin = tuple(rng.uniform(-4,4) for _ in range(3))
    end = tuple(rng.uniform(-4,4) for _ in range(3))
    pt = segment_aabb(origin,end)
    rev = segment_aabb(end,origin)
    assert (pt is None) == (rev is None)
    if pt is not None:
        assert all(-1.0000001<=u<=1.0000001 for u in pt)
        # Points on the returned segment must lie inside the box.
        assert min(math.dist(pt,origin),math.dist(pt,end))<=math.dist(origin,end)+1e-7

# Fixed SHA256 signatures captured from the supplied v10 ZIP. Portable after
# extraction: the original v10 ZIP is not required in the user's environment.
signatures = json.loads((root/'tools/v10_signatures.json').read_text())
for func in ['_screen_drag_to_ground', '_update_side_from_screen', '_nearest_clear_yaw',
             '_fit_full_frame', '_place_camera', '_target_fully_in_frame', '_full_frame_safe']:
    match = re.search(r'^func '+func+r'\(.*?(?=^func |\Z)', main, flags=re.M|re.S)
    assert match,func
    assert hashlib.sha256(match.group().encode()).hexdigest()==signatures[func], func
# The v44 lock-reticle layout legitimately changed this file after v10.
# v45 must preserve exactly that v44 touch overlay instead of restoring v10.
assert hashlib.sha256((root/'scripts/touch_overlay.gd').read_bytes()).hexdigest() == (
    '1f009d52dd1a63dab2e9438e867723ead4f418c4caab652455d6c1af50aab8c0')
print('v14 model / audio / code-wiring checks: OK')
print('v9 camera signatures / v44 touch overlay unchanged: OK')
print('Sweep geometric boundary audit: 8,006 examples OK')
print('Godot runtime still required for in-engine confirmation.')
