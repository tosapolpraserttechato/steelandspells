"""Build the skeleton landmarks (joint positions) of a standing humanoid character from a few numbers.

The Druid's hand-measured skeleton gave the proportions (as fractions of the head-top height H). A class only has to
say how tall its body is (head top, hats and horns left out), how far its arms hang out and how wide it stands;
the character's centre comes from the mesh.

Axes: the character faces -Y, its left side is +X, z is up, feet at z = 0 (a base under the feet is cut off by floor_z).
"""
import math


def v(x, y, z):
    return [round(x, 4), round(y, 4), round(z, 4)]


def build(cfg, xc, yc):
    """cfg: H (head-top height above the feet), arms=(upper_angle, lower_angle) degrees from straight down (outwards),
    arm_fwd=(left, right) degrees forwards of that, stance=(hip, knee, ankle) half widths as fractions of H, knee_fwd
    (fraction of H), floor_z, hair={length, width} or None. Returns the landmarks dict used by rig_character.py."""
    H = cfg["H"]
    f0 = cfg.get("floor_z", 0.0)
    z = lambda frac: f0 + frac * H
    a1, a2 = math.radians(cfg.get("arms", (6, 4))[0]), math.radians(cfg.get("arms", (6, 4))[1])
    fwd = cfg.get("arm_fwd", (0, 0))
    hip_w, knee_w, ankle_w = cfg.get("stance", (0.037, 0.045, 0.055))
    knee_fwd = cfg.get("knee_fwd", 0.0) * H
    sh_w = cfg.get("shoulder_half", 0.068) * H
    up_len, fo_len, hand_len = cfg.get("arm_len", (0.115, 0.120, 0.06))
    up_len, fo_len, hand_len = up_len * H, fo_len * H, hand_len * H
    B = {}

    def bone(name, parent, head, tail):
        B[name] = {"parent": parent, "head": head, "tail": tail}

    bone("root", None, v(xc, yc, f0), v(xc, yc + 0.25 * H / 1.7, f0))
    bone("DEF-hips", "root", v(xc, yc, z(0.529)), v(xc, yc, z(0.588)))
    bone("DEF-spine.001", "DEF-hips", v(xc, yc, z(0.600)), v(xc, yc, z(0.659)))
    bone("DEF-spine.002", "DEF-spine.001", v(xc, yc, z(0.659)), v(xc, yc, z(0.724)))
    bone("DEF-spine.003", "DEF-spine.002", v(xc, yc, z(0.724)), v(xc, yc, z(0.806)))
    bone("DEF-neck", "DEF-spine.003", v(xc, yc + 0.01, z(0.812)), v(xc, yc + 0.02, z(0.876)))
    bone("DEF-head", "DEF-neck", v(xc, yc + 0.02, z(0.876)), v(xc, yc + 0.04, z(1.006)))
    hair = cfg.get("hair")
    for side, sgn, fw in (("L", 1, fwd[0]), ("R", -1, fwd[1])):
        sh = (xc + sgn * sh_w, yc + 0.01, z(0.765))
        fy = -math.sin(math.radians(fw))                 # arms swing forward (towards -Y)
        el = (sh[0] + sgn * up_len * math.sin(a1), sh[1] + up_len * math.cos(a1) * 0 + fy * up_len * 0.7, sh[2] - up_len * math.cos(a1))
        wr = (el[0] + sgn * fo_len * math.sin(a2), el[1] + fy * fo_len * 0.7, el[2] - fo_len * math.cos(a2))
        tip = (wr[0] + sgn * hand_len * math.sin(a2), wr[1] + fy * hand_len * 0.7, wr[2] - hand_len * math.cos(a2))
        bone(f"DEF-shoulder.{side}", "DEF-spine.003", v(xc + sgn * 0.01 * H, yc + 0.01, z(0.788)), v(*sh))
        bone(f"DEF-upper_arm.{side}", f"DEF-shoulder.{side}", v(*sh), v(*el))
        bone(f"DEF-forearm.{side}", f"DEF-upper_arm.{side}", v(*el), v(*wr))
        bone(f"DEF-hand.{side}", f"DEF-forearm.{side}", v(*wr), v(*tip))
    for side, sgn in (("L", 1), ("R", -1)):
        hip = (xc + sgn * hip_w * H, yc, z(0.515))
        knee = (xc + sgn * knee_w * H, yc - knee_fwd, z(0.318))
        ankle = (xc + sgn * ankle_w * H, yc + 0.02, z(0.085))
        ball = (ankle[0], yc - 0.055 * H, z(0.025))
        toe = (ankle[0], yc - 0.10 * H, z(0.018))
        bone(f"DEF-thigh.{side}", "DEF-hips", v(*hip), v(*knee))
        bone(f"DEF-shin.{side}", f"DEF-thigh.{side}", v(*knee), v(*ankle))
        bone(f"DEF-foot.{side}", f"DEF-shin.{side}", v(*ankle), v(*ball))
        bone(f"DEF-toe.{side}", f"DEF-foot.{side}", v(*ball), v(*toe))
    out = {"name": cfg["name"], "yaw": cfg["yaw"], "H": H, "floor_z": f0, "bones": B}
    if hair:                                             # a back strand of hair hanging from the head, in segments
        n = hair.get("segments", 5)
        top, bottom = z(0.98), z(0.98) - hair["length"] * H
        pts = []
        for i in range(n):
            t = i / (n - 1)
            pts.append(v(xc, yc + 0.075 * H + 0.03 * H * t, top + (bottom - top) * t))
        hb = {}
        for i in range(n - 1):
            hb[f"hair_back_{i + 1}"] = {"parent": "DEF-head" if i == 0 else f"hair_back_{i}", "head": pts[i], "tail": pts[i + 1]}
        out["hair_bones"] = hb
        out["hair_geom"] = {"min_z": bottom - 0.02, "behind_y": yc + 0.02, "half_width": hair.get("width", 0.22), "xc": xc}
    if cfg.get("hang_arms") is not None:                  # a mesh that stands with its arms out (A-pose): pose the clips from arms hanging this many degrees out
        out["hang_arms"] = cfg["hang_arms"]
        out["hang_fwd"] = cfg.get("hang_fwd", [0, 0])
        out["arm_smooth"] = cfg.get("arm_smooth", 40)
    if cfg.get("leg_sides") is not None:
        out["leg_sides"] = cfg["leg_sides"]
    if cfg.get("straighten"):
        out["straighten"] = ["DEF-thigh.L", "DEF-shin.L", "DEF-thigh.R", "DEF-shin.R"]
    return out
