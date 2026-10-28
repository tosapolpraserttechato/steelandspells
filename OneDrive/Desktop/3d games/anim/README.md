# Character rigs and animations

All body clips are **CC0** (Quaternius Universal Animation Library and Universal Animation Library 2, in `../anim_src/`). Hair movement is a small spring simulation written for this project and baked into each clip. No game code lives here: these are Blender helper scripts.

## What you get

`out/class_<id>_rigged.glb` for each class: the Hunyuan mesh, a skeleton and 30 clips.

| Group | Clips |
|---|---|
| Movement | Idle, Run, Sprint, JumpStart, JumpLoop, JumpLand, SlideStart, SlideLoop, SlideExit |
| Spells | CastEnter, CastIdle, CastShoot, CastExit |
| Melee | Attack, MeleeA, MeleeB, MeleeC, MeleeCombo, Hook, Block, Throw |
| Reactions | HitChest, HitHead, Knockback, Death, Revive |
| Items and emotes | Consume (drink a potion), ChestOpen, EmoteYes, EmoteNo |

Hair bones (`hair_back_N`) exist on the long-haired classes; the hair moves as one mass in every clip. Its skin weights depend only on height along the strand (head, then each hair bone, blended linearly), so the thin hair shell cannot tear open (an earlier version weighted each side lock separately and gaps appeared).

## Cloth (done 2026-10-21)

Skirts, coats, capes and wings are cut out **by skin weights**, not by cutting the mesh (`cloth.py`, settings per class in `classes.json` under `cloth`). Each part (a panel) gets columns of bones hanging from the hips or spine; a vertex's weights depend only on its position, so the surface cannot tear. In every clip a small spring simulation (inertia, spring back, neighbouring columns held together, legs push the cloth aside) is baked into the animation. `bash anim/cloth_debug.sh <id>` colours the vertices each panel claims (pictures in `cloth_debug/<id>/`).

Panels so far: Arcanist (back cape + skirt), Celestial Mage (two wings + robe), Frost Mage (cape + skirt), Desert Assassin, Pirate Captain, Flame Lord, Necromancer, Poison Brewer, Sea King, Thunder God, Time Mage, Druid (skirt/coat tails); GM Ravn has none. Hair is separate (see above).

## How a class is rigged

1. `fit_class.py` reads `classes.json` (body height without hats, how far the arms hang out, stance), centres the skeleton on the character and writes `fit/<id>_landmarks.json` plus overlay pictures (`fit/<id>_overlay_*.png`, bones drawn through the mesh) to check the fit by eye.
2. `rig_character.py` builds the skeleton from the landmarks (same bone names as the library), skins the mesh, retargets all clips and bakes the hair, then writes `out/class_<id>_rigged.glb` and preview frames in `previews/<id>/`.
3. `rig_all.sh [id ...]` runs step 2 for every class (or the ids you name).

Skinning is by distance to each bone (Blender's automatic weights fail on these fused meshes). The mesh keeps its pose from the reference picture (for example the Druid's bent knee); bones listed in `straighten` animate from a straight leg.

## Known limits

- Weapons, hats and props are still part of the single Hunyuan mesh and follow the nearest body part. Cloth belts and straps below the waist sometimes get picked up by the skirt panel and look like loose strips.
- Dynamic or wind-blown poses (Necromancer, Desert Assassin, Sea King, Thunder God) fit the skeleton less well than the standing ones.
- The free CC0 libraries have one simple spell cast, no bow or staff attacks and no strafe or backwards running; the sword combos drift forward.
- No finger bones.

## Other tools

| File | What it does |
|---|---|
| `render_views.py`, `render_orient.py` | Orthographic pictures of a model, to judge facing and measure joints. |
| `render_clip_frames.py` | Opens a rigged GLB and renders frames of a clip (also proves the clips are in the file). |
| `slice_mesh.py`, `find_hair.py` | Measuring helpers used for the Druid. |
| `inspect_ual.py`, `dump_rig.py` | List the clips and bones of an animation library. |
| `make_class_sheets.js` | Collects each class's preview frames for the contact sheets in `../previews/`. |
