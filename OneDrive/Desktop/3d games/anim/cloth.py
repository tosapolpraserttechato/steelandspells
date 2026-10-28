"""Cloth panels for a fused character mesh: skirts, coats, capes and wings get their own bone chains.

Why: a Hunyuan character is one mesh. Weighting a long skirt to the two leg bones tears it open when the legs move,
and a cape weighted to the arms stretches. Here every cloth part is cut out *by weights*, not by cutting the mesh:

  1. a panel decides how cloth-like each vertex is (membership 0..1): below the waist, away from the legs and arms,
     inside an optional box, minus exclusion boxes, minus the hair;
  2. the panel gets columns of bones hanging from an anchor bone (the hips, the spine, ...). Columns run round the body
     for skirts (ring), across the back for capes (lateral) or out sideways for wings (limb);
  3. a vertex's weights depend only on its position (height along the chain and angle to the neighbouring columns), so
     the surface changes smoothly and cannot tear;
  4. in every clip the chains swing: a small Verlet spring simulation (inertia, spring back to the rigid pose, neighbour
     columns kept together, legs push the cloth out of the way) is baked into the animation.

This file only needs numpy and mathutils; rig_character.py does the Blender work.

Panel settings (anim/classes.json, "cloth": [ ... ]):
  name, kind ring|lateral|limb, anchor (bone), cols, segs
  z_top, z_fade, z_bottom        fractions of the body height H (z_top: where the cloth starts hanging)
  leg_clear [a, b] / arm_clear   distance to legs/arms in bone radii where membership fades in (null = ignore)
  box [x0, x1, y0, y1]           metres from the body axis; +y is behind the character (it faces -Y)
  exclude [[x0,x1,y0,y1,z0,z1]]  metres, vertices inside are never cloth (weapons, props)
  arc [a0, a1]                   ring only: part of the circle, degrees (0 = behind, 90 = its left, 180 = front)
  limb: root [dx, dy, z metres above the floor], dir [x, y, z], length (metres)
  stiff [top, bottom]            spring back to the rigid pose, larger = stiffer (default 0.30, 0.14)
  collide                        legs push the cloth out (default true)
"""
import math

import numpy as np

LEG_BONES = ("DEF-thigh.L", "DEF-shin.L", "DEF-thigh.R", "DEF-shin.R")
ARM_BONES = ("DEF-upper_arm.L", "DEF-forearm.L", "DEF-hand.L", "DEF-upper_arm.R", "DEF-forearm.R", "DEF-hand.R")
DEBUG_COLOURS = ((1.0, 0.1, 0.1), (0.1, 0.35, 1.0), (0.1, 0.8, 0.2), (1.0, 0.8, 0.0), (0.8, 0.1, 0.9), (0.0, 0.8, 0.9))


def smooth(x):
    x = np.clip(x, 0.0, 1.0)
    return x * x * (3.0 - 2.0 * x)


def seg_dist(P, a, b):
    a, b = np.asarray(a, float), np.asarray(b, float)
    ab = b - a
    t = np.clip(((P - a) @ ab) / max(float(ab @ ab), 1e-9), 0.0, 1.0)
    return np.linalg.norm(P - (a + t[:, None] * ab), axis=1)


def body_distance(P, bones, names, radii):
    """Smallest distance to any of the named bones, in units of that bone's radius."""
    best = np.full(len(P), 1e6)
    for n in names:
        b = bones[n]
        best = np.minimum(best, seg_dist(P, b["head"], b["tail"]) / radii[n])
    return best


def column_weights(theta, n, circular, a0=0.0, a1=0.0):
    """Linear (hat) weights of each vertex on n columns. Returns (len(theta), n)."""
    W = np.zeros((len(theta), n))
    if n == 1:
        W[:, 0] = 1.0
        return W
    if circular:
        step = 2 * math.pi / n
        centres = -math.pi + (np.arange(n) + 0.5) * step
        for i, c in enumerate(centres):
            d = np.abs((theta - c + math.pi) % (2 * math.pi) - math.pi)
            W[:, i] = np.clip(1.0 - d / step, 0.0, 1.0)
    else:
        lo, hi = min(a0, a1), max(a0, a1)
        centres = np.linspace(lo, hi, n)
        step = centres[1] - centres[0]
        for i, cc in enumerate(centres):
            W[:, i] = np.clip(1.0 - np.abs(theta - cc) / step, 0.0, 1.0)
        W[theta <= centres[0], 0] = 1.0
        W[theta >= centres[-1], n - 1] = 1.0
    s = W.sum(1, keepdims=True)
    return W / np.maximum(s, 1e-9)


def build_panels(P, lm, radii, hair_mask, configs, rng_seed=0):
    """Work out every panel: membership, columns, rest points of the chains and the new bones.

    P: (n, 3) rest vertices (character faces -Y, feet at z = 0).  lm: landmarks (bones, H).  Returns a list of panel dicts."""
    bones = lm["bones"]
    H = lm.get("H", 1.7)
    xc, yc = bones["root"]["head"][0], bones["root"]["head"][1]
    rel = P - np.array([xc, yc, 0.0])
    theta = np.arctan2(rel[:, 0], rel[:, 1])                      # 0 = behind (+y), +90 = the character's left (+x), +-180 = front
    dleg = body_distance(P, bones, LEG_BONES, radii)
    darm = body_distance(P, bones, ARM_BONES, radii)
    remaining = np.ones(len(P))
    panels = []
    for pi, cfg in enumerate(configs):
        kind = cfg.get("kind", "ring")
        name = cfg["name"]
        anchor = cfg.get("anchor", "DEF-hips")
        cols, segs = (1 if kind == "limb" else cfg.get("cols", 6)), cfg.get("segs", 4)
        m = np.ones(len(P))
        le = cfg.get("leg_clear", [1.8, 3.2] if kind == "ring" else None)
        if le:
            m *= smooth((dleg - le[0]) / max(le[1] - le[0], 1e-6))
        ae = cfg.get("arm_clear", [1.4, 2.4])
        if ae:
            m *= smooth((darm - ae[0]) / max(ae[1] - ae[0], 1e-6))
        if "box" in cfg:
            x0, x1, y0, y1 = cfg["box"]
            f = 0.04
            m *= smooth((rel[:, 0] - x0) / f) * smooth((x1 - rel[:, 0]) / f) * smooth((rel[:, 1] - y0) / f) * smooth((y1 - rel[:, 1]) / f)
        for ex in cfg.get("exclude", []):
            x0, x1, y0, y1, z0, z1 = ex
            inside = (rel[:, 0] > x0) & (rel[:, 0] < x1) & (rel[:, 1] > y0) & (rel[:, 1] < y1) & (P[:, 2] > z0) & (P[:, 2] < z1)
            m[inside] = 0.0
        if "arc" in cfg and kind == "ring":
            a0, a1 = [math.radians(v) for v in cfg["arc"]]
            lo, hi = min(a0, a1), max(a0, a1)
            m *= smooth((theta - lo) / 0.15 + 0.5) * smooth((hi - theta) / 0.15 + 0.5)
        m[hair_mask] = 0.0
        z_top = cfg.get("z_top", 0.52) * H
        z_fade = cfg.get("z_fade", 0.04) * H
        m_base = m.copy()                                          # without the fade at the top: used to place the chains
        if kind != "limb":
            m = m * smooth((z_top - P[:, 2]) / max(z_fade, 1e-6))
        if "z_min" in cfg:
            m = m * smooth((P[:, 2] - cfg["z_min"] * H) / (0.03 * H) + 0.5)
        eff = m * remaining
        remaining = remaining - eff
        core = eff > 0.5
        if core.sum() < 30:
            print("CLOTH", name, "has only", int(core.sum()), "core vertices: check its settings")
        panel = {"name": name, "kind": kind, "anchor": anchor, "cols": cols, "segs": segs, "cw": eff, "cfg": cfg}
        pts = np.zeros((cols, segs + 1, 3))
        if kind in ("ring", "lateral"):
            z_bot = cfg["z_bottom"] * H if "z_bottom" in cfg else max(float(np.percentile(P[core, 2], 1.5)) if core.any() else 0.1 * H, 0.03 * H)
            panel["z_top"], panel["z_bot"] = z_top, z_bot
            if kind == "ring":
                circ = "arc" not in cfg
                a0, a1 = (math.radians(cfg["arc"][0]), math.radians(cfg["arc"][1])) if not circ else (0.0, 0.0)
                coord = theta
            else:
                x0, x1 = cfg.get("span", [-0.4, 0.4])
                circ, a0, a1 = False, x0, x1
                coord = rel[:, 0]
            CW = column_weights(coord, cols, circ, a0, a1)
            panel.update({"colw": CW, "circular": circ})
            dz = (z_top - z_bot) / segs
            for j in range(segs + 1):
                zj = z_top - dz * j
                h = np.clip(1.0 - np.abs(P[:, 2] - zj) / (1.2 * dz), 0.0, 1.0)
                if j == 0:
                    h = h * (P[:, 2] <= z_top + 0.4 * dz)
                for c in range(cols):
                    w = h * CW[:, c] * m_base * (m_base > 0.05)
                    if w.sum() > 1e-6:
                        pts[c, j, :2] = (w[:, None] * P[:, :2]).sum(0) / w.sum()
                        pts[c, j, 2] = zj
                    else:
                        pts[c, j] = np.array([np.nan, np.nan, zj])
        else:                                                     # limb: a single chain from a root along a direction
            root = np.array([xc + cfg["root"][0], yc + cfg["root"][1], cfg["root"][2]])        # z in metres above the floor
            d = np.array(cfg["dir"], float)
            d /= np.linalg.norm(d)
            L = cfg["length"]
            along = (P - root) @ d
            u = along / L * segs
            panel.update({"root": root, "dir": d, "L": L, "u_coord": u, "colw": np.ones((len(P), 1)), "circular": False})
            for j in range(segs + 1):
                h = np.clip(1.0 - np.abs(u - j), 0.0, 1.0)
                w = h * m_base * (m_base > 0.05)
                lateral = (P - root) - along[:, None] * d
                if w.sum() > 1e-6:
                    off = (w[:, None] * lateral).sum(0) / w.sum()
                else:
                    off = np.zeros(3)
                pts[0, j] = root + d * (L * j / segs) + off
        for c in range(cols):                                      # fill empty levels from their neighbours
            for j in range(segs + 1):
                if np.isnan(pts[c, j, 0]):
                    k = j - 1
                    while k >= 0 and np.isnan(pts[c, k, 0]):
                        k -= 1
                    if k < 0:
                        k = j + 1
                        while k <= segs and np.isnan(pts[c, k, 0]):
                            k += 1
                    pts[c, j, :2] = pts[c, k, :2] if 0 <= k <= segs else (xc, yc)
        for c in range(cols):                                      # no two points on top of each other
            for j in range(1, segs + 1):
                if np.linalg.norm(pts[c, j] - pts[c, j - 1]) < 0.02:
                    pts[c, j] = pts[c, j - 1] + np.array([0.0, 0.0, -0.02])
        panel["pts"] = pts
        new = {}
        names = []
        for c in range(cols):
            col_names = []
            for j in range(segs):
                bn = f"cloth_{name}_{c}_{j + 1}"
                new[bn] = {"parent": anchor if j == 0 else f"cloth_{name}_{c}_{j}", "head": [round(float(v), 4) for v in pts[c, j]], "tail": [round(float(v), 4) for v in pts[c, j + 1]]}
                col_names.append(bn)
            names.append(col_names)
        panel["bones"], panel["bone_names"] = new, names
        panel["stiff"] = cfg.get("stiff", [0.30, 0.14] if kind != "limb" else [0.12, 0.06])
        panel["collide"] = cfg.get("collide", kind != "limb")
        # clearance of every rest point from the legs, so the legs only push the cloth when they come closer than it rests
        clear = np.full((cols, segs + 1), 9.0)
        for n in LEG_BONES:
            b = bones[n]
            for c in range(cols):
                clear[c] = np.minimum(clear[c], seg_dist(pts[c], b["head"], b["tail"]))
        panel["clearance"] = np.minimum(clear * 0.9, 0.35)
        panels.append(panel)
        print("CLOTH", name, kind, "members", int(core.sum()), "weight", round(float(eff.sum()), 1), "z", round(float(P[core, 2].min()), 2) if core.any() else None)
    return panels


def apply_weights(W, names, P, panel):
    """Blend the cloth chains into the weight matrix W (n_vertices x n_names), in place. Returns W."""
    cw = panel["cw"]
    idx = np.nonzero(cw > 1e-4)[0]
    if not len(idx):
        return W
    cols, segs = panel["cols"], panel["segs"]
    Wc = np.zeros((len(idx), W.shape[1]))
    if panel["kind"] == "limb":
        u = panel["u_coord"][idx]
    else:
        zt, zb = panel["z_top"], panel["z_bot"]
        u = (zt - P[idx, 2]) / max(zt - zb, 1e-6) * segs
    CW = panel["colw"][idx]
    anchor_w = np.clip(0.5 - u, 0.0, 1.0)
    Wc[:, names.index(panel["anchor"])] = anchor_w
    for c in range(cols):
        for j in range(1, segs + 1):
            w = np.clip(1.0 - np.abs(u - (j - 0.5)), 0.0, 1.0)
            if j == segs:
                w = np.where(u >= j - 0.5, 1.0, w)
            Wc[:, names.index(panel["bone_names"][c][j - 1])] = w * CW[:, c]
    Wc /= np.maximum(Wc.sum(1, keepdims=True), 1e-9)
    a = cw[idx][:, None]
    W[idx] = W[idx] * (1.0 - a) + Wc * a
    return W


def simulate(panel, rest_t, body_by_frame, frames, fps, leg_names=LEG_BONES):
    """Bake the swing of a panel. Returns {frame: {bone: 4x4 armature-space matrix as a numpy array}}.

    rest_t: {bone: rest matrix (mathutils or numpy)}; body_by_frame[f][bone]: posed matrices of the body."""
    cols, segs = panel["cols"], panel["segs"]
    anchor = panel["anchor"]
    rest_pts = panel["pts"]                                        # (cols, segs+1, 3)
    anchor_inv = np.linalg.inv(np.array(rest_t[anchor]))
    rest_bone = np.array([[np.array(rest_t[panel["bone_names"][c][j]]) for j in range(segs)] for c in range(cols)])   # (cols, segs, 4, 4)
    seglen = np.linalg.norm(rest_pts[:, 1:] - rest_pts[:, :-1], axis=2)                                               # (cols, segs)
    s_top, s_bot = panel["stiff"]
    stiff = (s_top + (s_bot - s_top) * np.arange(segs + 1) / segs)[None, :, None]
    damp = 0.86
    circular = panel["circular"]
    pairs = [(c, (c + 1) % cols) for c in range(cols)] if circular and cols > 2 else [(c, c + 1) for c in range(cols - 1)]
    rest_gap = {p: np.linalg.norm(rest_pts[p[0]] - rest_pts[p[1]], axis=1) for p in pairs}
    clear = panel["clearance"]
    out = {}
    P = Pp = None
    for pass_no in (0, 1):
        for f in frames:
            A = np.array(body_by_frame[f][anchor]) @ anchor_inv
            rigid = rest_pts @ A[:3, :3].T + A[:3, 3]
            if P is None:
                P, Pp = rigid.copy(), rigid.copy()
            t = f / fps
            breeze = np.array([0.003 * math.sin(2.0 * t), 0.002 * math.sin(1.6 * t + 0.7), 0.0])
            vel = (P - Pp) * damp
            Pp = P.copy()
            P = P + vel + (rigid - P) * stiff + breeze * (np.arange(segs + 1)[None, :, None] / segs)
            P[:, 0] = rigid[:, 0]
            for _ in range(2):
                if panel["collide"]:
                    for a_n, b_n in (("DEF-thigh.L", "DEF-shin.L"), ("DEF-thigh.R", "DEF-shin.R")):
                        ha = np.array(body_by_frame[f][a_n])[:3, 3]
                        hb = np.array(body_by_frame[f][b_n])[:3, 3]
                        kb = {"DEF-shin.L": "DEF-foot.L", "DEF-shin.R": "DEF-foot.R"}[b_n]
                        hc = np.array(body_by_frame[f][kb])[:3, 3]
                        for s0, s1 in ((ha, hb), (hb, hc)):
                            ab = s1 - s0
                            tt = np.clip(((P - s0) @ ab) / max(float(ab @ ab), 1e-9), 0.0, 1.0)
                            diff = P - (s0 + tt[..., None] * ab)
                            dist = np.linalg.norm(diff, axis=2)
                            push = np.clip(clear - dist, 0.0, None)
                            P += diff / np.maximum(dist, 1e-6)[..., None] * push[..., None]
                for (c0, c1) in pairs:
                    d = P[c1] - P[c0]
                    dist = np.linalg.norm(d, axis=1)
                    corr = (dist - rest_gap[(c0, c1)]) * 0.45 / np.maximum(dist, 1e-6)
                    P[c0] += d * corr[:, None]
                    P[c1] -= d * corr[:, None]
                for j in range(1, segs + 1):
                    d = P[:, j] - P[:, j - 1]
                    dist = np.maximum(np.linalg.norm(d, axis=1), 1e-6)
                    P[:, j] = P[:, j - 1] + d / dist[:, None] * seglen[:, j - 1][:, None]
                P[:, 0] = rigid[:, 0]
            if pass_no == 1:
                rb = A @ rest_bone                                 # (cols, segs, 4, 4) the bones if the cloth were stiff
                res = {}
                for c in range(cols):
                    for j in range(segs):
                        m = rb[c, j].copy()
                        d_rigid = m[:3, 1] / max(np.linalg.norm(m[:3, 1]), 1e-9)
                        d_now = P[c, j + 1] - P[c, j]
                        d_now = d_now / max(np.linalg.norm(d_now), 1e-9)
                        res[panel["bone_names"][c][j]] = (P[c, j].copy(), d_rigid, d_now, m[:3, :3].copy())
                out[f] = res
    return out
