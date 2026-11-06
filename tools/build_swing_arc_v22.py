#!/usr/bin/env python3
"""Bake the existing v20 crescent's colors onto the authored melee1 sword-tip arc.

The output is a complete pre-rendered curved PNG and a matching reveal-time PNG.
Godot displays the PNG on exactly ONE flat QuadMesh; no ribbon, particles,
procedural arc geometry, or camera-facing billboard is involved.

Optional authoring dependencies: numpy, scipy, opencv-python, Pillow.
These are not used at runtime by Godot.
"""
from __future__ import annotations
import json
from pathlib import Path
import cv2
import numpy as np
from PIL import Image
from scipy.spatial.transform import Rotation as R, Slerp

ROOT = Path(__file__).resolve().parent.parent
UNIT = 0.065
START = 0.08333333
END = 0.21500000
WIDTH_PX = 1024
HEIGHT_PX = 1536
SUPERSAMPLE = 2
# Thickness near the blade tip: ~11cm of external glow and ~30cm inside.
OUTSIDE = -0.11
INSIDE = 0.30


def v3(raw):
    return np.array([float(x) for x in raw], dtype=np.float64)


def quaternion(values):
    ang = (v3(values) + 180.0) % 360.0 - 180.0
    return R.from_euler('ZYX', [ang[2], ang[1], ang[0]], degrees=True)


class AuthoringPose:
    def __init__(self):
        data = json.loads((ROOT / 'assets/sera_source.json').read_text('utf-8'))
        self.groups = {g['uuid']: g for g in data['groups']}
        clip = next(anim for anim in data['animations'] if anim['name'] == 'melee1')
        self.animators = clip['animators']
        self.chain = []

        def descend(items, parents=()):
            for item in items:
                if isinstance(item, dict):
                    chain = (*parents, item['uuid'])
                    if self.groups[item['uuid']]['name'] == 'Sword':
                        self.chain = list(chain)
                    descend(item['children'], chain)
        descend(data['outliner'])
        assert self.chain, 'Sword bone not found'
        self.channels = {}
        for uid in self.chain:
            channels = {'position': [], 'rotation': []}
            for key in self.animators.get(uid, {}).get('keyframes', []):
                ch = key.get('channel')
                if ch in channels:
                    raw = key['data_points'][0]
                    channels[ch].append((float(key['time']), v3([raw['x'], raw['y'], raw['z']])))
            for ch in channels:
                channels[ch].sort(key=lambda k: k[0])
            self.channels[uid] = channels

    def _channel_value(self, uid, channel, t):
        keys = self.channels[uid][channel]
        if not keys:
            return np.zeros(3) if channel == 'position' else quaternion(self.groups[uid].get('rotation', [0, 0, 0]))
        if t <= keys[0][0]:
            return keys[0][1] if channel == 'position' else quaternion(keys[0][1])
        for i in range(1, len(keys)):
            if t <= keys[i][0]:
                t0, a = keys[i - 1]
                t1, b = keys[i]
                w = (t - t0) / (t1 - t0)
                if channel == 'position':
                    return a * (1 - w) + b * w
                return Slerp([0, 1], R.concatenate([quaternion(a), quaternion(b)]))(w)
        return keys[-1][1] if channel == 'position' else quaternion(keys[-1][1])

    def blade_at(self, t):
        root_parent = np.zeros(3)
        parent_rotation = R.identity()
        pos = np.zeros(3)
        for uid in self.chain:
            group = self.groups[uid]
            origin = v3(group['origin'])
            extra = self._channel_value(uid, 'position', t)
            pos += parent_rotation.apply((origin - root_parent + extra) * UNIT)
            parent_rotation = parent_rotation * self._channel_value(uid, 'rotation', t)
            root_parent = origin
        # Identical to sera_rig.gd:get_blade_world_segment(), but rig-local.
        base = pos + parent_rotation.apply(v3([0, 4 * UNIT, 7.5 * UNIT]))
        tip = pos + parent_rotation.apply(v3([0, 4 * UNIT, -7.5 * UNIT]))
        return base, tip


def gd_vec(v):
    return 'Vector3(%.8f, %.8f, %.8f)' % tuple(v)


def bake():
    author = AuthoringPose()
    times = np.linspace(START, END, 251)
    poses = [author.blade_at(float(t)) for t in times]
    bases = np.array([pose[0] for pose in poses])
    tips = np.array([pose[1] for pose in poses])

    # Orthogonal least-squares plane, derived from the ENTIRE original swing.
    mean = np.mean(tips, axis=0)
    _, _, right_vectors = np.linalg.svd(tips - mean, full_matrices=False)
    up = right_vectors[0]
    right = right_vectors[1]
    normal = np.cross(right, up)
    # Make the normal face Godot's forward-facing (-Z) hemisphere consistently.
    if normal[2] > 0:
        right = -right
        normal = -normal
    assert abs(right @ up) < 1e-7
    # Leave the initial actual sword tip on the rendered plane; other samples
    # are represented by their best-fit projections in that same fixed plane.
    origin = mean + normal * ((tips[0] - mean) @ normal)
    tip_xy = np.column_stack(((tips - origin) @ right, (tips - origin) @ up))
    base_xy = np.column_stack(((bases - origin) @ right, (bases - origin) @ up))

    # Include the entire 250ms path + thickness, not just the tip's endpoints.
    margin = 0.23
    xmin, ymin = np.min(tip_xy, axis=0)
    xmax, ymax = np.max(tip_xy, axis=0)
    xmin -= (INSIDE + margin)
    xmax += (INSIDE + margin)
    ymin -= (INSIDE + margin)
    ymax += (INSIDE + margin)
    # Aspect ratio matches the authored PNG, no stretching of the plane.
    meters_per_px = max((xmax - xmin) / WIDTH_PX, (ymax - ymin) / HEIGHT_PX)
    world_width = meters_per_px * WIDTH_PX
    world_height = meters_per_px * HEIGHT_PX
    center_x = 0.5 * (xmin + xmax)
    center_y = 0.5 * (ymin + ymax)
    center_local = origin + right * center_x + up * center_y

    W, H = WIDTH_PX * SUPERSAMPLE, HEIGHT_PX * SUPERSAMPLE
    pixels_per_meter = SUPERSAMPLE / meters_per_px
    def to_pixels(coords):
        return np.stack([
            (coords[:, 0] - center_x) * pixels_per_meter + W * .5,
            (center_y - coords[:, 1]) * pixels_per_meter + H * .5,
        ], axis=1)

    # Keep the blue body *inside* the curve, perpendicular to the real tip
    # tangent; raw blade-root vectors shear and create squared-off ends.
    velocity = np.gradient(tip_xy, times, axis=0)
    inward = np.column_stack((-velocity[:, 1], velocity[:, 0]))
    inward /= np.maximum(np.linalg.norm(inward, axis=1, keepdims=True), 1e-7)
    if np.median(np.sum(inward * (base_xy - tip_xy), axis=1)) < 0:
        inward *= -1
    cumulative = np.concatenate(([0.0], np.cumsum(np.linalg.norm(np.diff(tip_xy, axis=0), axis=1))))
    distance_frac = cumulative / max(cumulative[-1], 1e-7)

    # This is an IMAGE: the curved shape lives in the pixels, not in the mesh.
    artwork = np.zeros((H, W, 4), dtype=np.uint8)
    timing = np.zeros((H, W), dtype=np.uint8)
    original = np.asarray(Image.open(ROOT / 'assets/slash_arc_1024.png').convert('RGBA'))
    # Reuse the actual original full-color cross-section, retaining the finely
    # drawn white rim, bright cyan, translucent blue and soft inner feather.
    palette = original[332:450, 512, :]
    band_count = 88
    for k in range(band_count - 1, -1, -1):
        s0 = OUTSIDE + (INSIDE - OUTSIDE) * k / band_count
        s1 = OUTSIDE + (INSIDE - OUTSIDE) * (k + 1) / band_count
        sr = 0.5 * (k + (k+1)) / band_count
        palette_row = min(len(palette) - 1, round(sr * (len(palette) - 1)))
        rgba = palette[palette_row].copy()
        if rgba[3] < 2:
            continue
        for i in range(len(times) - 1):
            # Width fades to a sharp point at either end of the entire arc.
            ts = distance_frac[[i, i+1]]
            taper = np.minimum(1.0, np.minimum(ts / .09, (1 - ts) / .15))
            taper = np.maximum(0.001, taper) ** 0.80
            a = tip_xy[[i, i+1]] + inward[[i, i+1]] * (s0 * taper)[:, None]
            b = tip_xy[[i, i+1]] + inward[[i, i+1]] * (s1 * taper)[:, None]
            polygon = to_pixels(np.stack([a[0], a[1], b[1], b[0]], axis=0))
            polygon = np.round(polygon).astype(np.int32)
            cv2.fillConvexPoly(artwork, polygon, tuple(int(x) for x in rgba), cv2.LINE_AA)
            cv2.fillConvexPoly(timing, polygon, int(round(255.0 * (i + .5) / (len(times) - 1))), cv2.LINE_AA)

    # Alpha feather and the white highlight are preserved after antialiasing.
    artwork = cv2.resize(artwork, (WIDTH_PX, HEIGHT_PX), interpolation=cv2.INTER_AREA)
    timing = cv2.resize(timing, (WIDTH_PX, HEIGHT_PX), interpolation=cv2.INTER_AREA)
    # White RGB everywhere timing is undefined: alpha of artwork handles it.
    Image.fromarray(artwork, 'RGBA').save(ROOT / 'assets/slash_arc_swing_v22.png', optimize=True)
    Image.fromarray(timing, 'L').save(ROOT / 'assets/slash_arc_swing_reveal_v22.png', optimize=True)

    # Parameters used by ONE QuadMesh in sword_trail.gd. These are copied into
    # the runtime script; no scientific Python libs are required to play.
    constants = {
        'START_TIP_LOCAL': gd_vec(tips[0]),
        'PLANE_CENTER_LOCAL': gd_vec(center_local),
        'PLANE_RIGHT_LOCAL': gd_vec(right),
        'PLANE_UP_LOCAL': gd_vec(up),
        'PLANE_WIDTH': '%.8f' % world_width,
        'PLANE_HEIGHT': '%.8f' % world_height,
    }
    (ROOT / 'tools/slash_v22_geometry.json').write_text(json.dumps({
        'sweep_start': START, 'sweep_end': END,
        'reveal_png_size': [WIDTH_PX, HEIGHT_PX],
        'constants': constants,
        'maximum_plane_deviation_m': float(np.max(np.abs((tips - origin) @ normal))),
    }, indent=2, ensure_ascii=False), encoding='utf-8')
    print(json.dumps(constants, indent=2))
    print('Max plane residual in 3D:', float(np.max(np.abs((tips - origin) @ normal))))


if __name__ == '__main__':
    bake()
