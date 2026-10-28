# Making every asset on Hunyuan (plan, 2026-10-27)

The rule (yours): every asset is made on Hunyuan (image-to-3D on the website), and what was not made there gets remade. This is what in the game is NOT from Hunyuan today, and how many Hunyuan models each needs.

| Group | Today | Models to make | Notes |
|---|---|---|---|
| Sniper perches | procedural (`PerchDress.gd`) | 12 (one per map that has them) | the ledge, rails and supports as one model per map; the ladder and stair slabs can reuse one small model each |
| Loot chests (6 rarities) + air-drop crate | procedural (`Chest.gd`) | 6 (+1 parachute crate) | the lid must be a separate piece to open: ask Hunyuan for the closed chest, and I open it with a hinge cut, or we use a "lid" and a "body" picture each |
| Weapons | 74 CC0 pack files (Quaternius, KayKit, Cardinal Zebra) + placeholders for the 30 new ones | 85 | the biggest single job that is certain to work: a weapon is one solid object |
| Armor | procedural (`ArmorKit.gd`) | 85 sets x 5 pieces = 425 if every piece is its own model | see "armor" below |
| Decor (flowers, ferns, mushrooms, rocks, crystals, shells, bones, graves...) | about 35 procedural shapes (`DecorMesh.gd`) | about 35-60 (one per shape, in the map's style) | placed thousands of times by MultiMesh, so each model must be low-poly |
| Animals | 15 procedural species (`CritterMesh.gd`) | 15 (static; the wings, legs, tails are moved by the game, so they need to be built as parts) | the hard group: a static Hunyuan model will not hop or fly unless it is rigged |
| Necromancer | Craiyon picture -> Hunyuan, mis-rigged; now on the GM Ravn body | 1 (a new picture, then the rig) | |
| Small things (flags, doors, pressure plates, jump pads, living chess pieces) | procedural | about 10 | |

Total: about 590 models. Hunyuan gives about 20 generations a day per signed-in account (you have 2), so roughly 15 days of generating, and every one needs a reference picture you approve first.

## Armor: the real problem

Hunyuan makes one static mesh. A static helmet, shield or boot can be fastened to a bone and works. A chestplate or leggings made as a static mesh cannot bend with the body, and it will clip when the character moves. Options:

1. **Hunyuan for the hero pieces only**: helmet and shield (85 + 85 = 170 models), shoulder pauldrons (one pair per set = 85 more), and the procedural chest, legs and boots stay (painted in the set's colours). About 255 models.
2. **Hunyuan for every piece, rigid**: 425 models; chest and legs are shells fastened to the spine / thighs; some clipping while running.
3. **Hunyuan makes a whole armored character per set** and the armory shows that picture-model: not usable in a match (all 85 would replace the class model).

My recommendation: option 1.

## Order I suggest (each batch: I show the reference pictures, you approve, I generate, download, and plug them in)

1. **Batch 1 (1 day):** the 12 perches, the chest (closed), the necromancer. Hooks are easy: a model in `models/perches/<map>.glb` replaces the procedural look and keeps the collision.
2. **Batch 2 (about 4 days):** the 85 weapons, in groups of 20 (swords, axes, bows, staffs...). Hook already in: drop `models/weapons/hy/<weapon id>.glb`.
3. **Batch 3 (about 6 days):** armor helmets + shields + pauldrons (option 1).
4. **Batch 4:** decor and animals, a few per map at a time, starting with the maps you play most.

What I need from you per batch: say "go" for the batch and answer on the pictures; sign in on the Hunyuan site when it asks (I never type your password).
