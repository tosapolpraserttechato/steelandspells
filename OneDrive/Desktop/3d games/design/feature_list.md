# Your feature list, with where each one stands

Everything you have asked for, in one place (updated 2026-10-21). Details for each line are in `game_design.md`. **Status words:** *built* = exists as files you can look at; *designed* = written down only, no game code (code is paused until you say); *to do* = not started.

## The game

| Feature | Status |
|---|---|
| Multiplayer fantasy team shooter in Godot (started as an MMORPG) | built as a game against bots on one computer, plus LAN multiplayer (host or join over the local network, see the LAN section at the end); internet play is not built |
| Maps first, then game code when you say | following this |
| No guns: fantasy weapons only (CC0 packs, never hand-made models) | built |
| UI easy to understand, rarity always clear (colour + shape + icon + written name) | built |

## Art

| Feature | Status |
|---|---|
| Objects made on Hunyuan from pictures you approve (never text-to-3D, never local) | following this; 4 map-wall models and 19 props made this way today |
| "Try to not use Hunyuan": CC0 first for props, Hunyuan only if no good CC0 model | following this (Chess Arena and Pirate Cove are CC0) |
| Same art style everywhere, maps and characters | built: painted style pass (`maps/stylize_lib.py`), matte materials, per-map cliff colours |
| Map walls from Hunyuan, matching each map's style | built for Desert Tomb, Pirate Cove, Shadow Crypt, Toxic Swamp; pictures still needed for the rest |
| Cloth simulation on capes, skirts, wings, hair | built (baked into the 13 characters' animation clips) |
| Animations (idle, run, jump, attack, cast, ultimate, hit, death) plus hair animation | built (30 CC0 clips per class) |
| Lantern lights are real light sources | built in Shadow Crypt; crystals in Crystal Caves too |

## Maps (13)

| Feature | Status |
|---|---|
| 13 maps, each with a home class buff and a rival debuff | **all 13 built** (Clockwork Mines and Moon Sanctuary finished 2026-10-21) |
| 1 unique mechanic + 1 hazard per map | marked in all 11 built maps (the game code that runs them is built: HazardNode.gd) |
| Natural theme boundary, never a bare wall | built (cliffs and props round every edge, coloured per map) |
| Two teams on mirror-image halves | built (every map is symmetric by 180-degree rotation) |
| Flora Forest has dense and lighter areas | built |
| More rooftops and jump pads to the high ground | built (every map has jump or bounce pads except Sky Islands, which uses updrafts; the giant mushrooms in Flora Forest and Toxic Swamp now bounce too) |
| Loot crates found on the maps (6 rarities, plus gold crates) | built (12-24 crate spots in every map, plus air drops) |
| NPCs on the maps give missions (XP + full heal; 2-3 per half) | built (6-8 NPCs in every map, Crystal Caves only 2) |
| Map pickups (health, ammo, armor, power weapon) | built (4 per half on every new map) |

## Classes

| Feature | Status |
|---|---|
| 13 classes (Druid, Sea King, Flame Lord, Frost Mage, Thunder God, Desert Assassin, Necromancer, Arcanist, Poison Brewer, Pirate Captain, Time Mage, Celestial Mage, GM Ravn) | 13 character models built and rigged |
| GM Ravn: Chess Arena, no debuffs, huge sacrificed queen ultimate, checkmate finisher on ultimate kills | built |
| 3 chosen skills from any class + a fixed 4th area-attack signature skill + ultimate + 1 passive + class meter | built |
| Own-class skills massively buffed | built |
| 10 skills per class, a unique one every 10 levels, level cap 100 | built |
| Class stats: speed, acceleration, size, sight distance, crit chance | built |

## Progression, cards and items

| Feature | Status |
|---|---|
| XP from kills, crates and missions; at each level pick 1 of 3 cards | built |
| Tab hides and shows the cards; rerolls from crates give 3 new cards | built |
| 125 cards, 6 rarities, stacking up to 6 times (each copy one rarity higher) | built |
| 50 armor sets x 5 pieces (helmet, chestplate, shield, leggings, boots), each piece its own passive, full set much stronger | built |
| 55 weapons with **no skins of their own** (the only skin comes from a brand-new loot crate roll); magic and non-magic versions of weapons and armor | built |
| Runes (new item type from crates, socketed into gear) | built |
| Loot crates: roll weapon / armor / shield / rune / card reroll, then old (tiny debuff) or brand new (skin + modifier) | built |
| Legendary modified gear = gold aura; mythic modified gear = unique aura; armor gets modifiers too | built |
| Status effects (burn, freeze, poison, shock, stun, slow, root, ...) used by hazards, skills, gear | built |
| Quest skills: 50 skills, common to mythic, good for every class, earned from a rare quest NPC with a demo and a % reward chance (example: Thirst for Blood) | built (50 quest skills with quests and demos; list in `quest_skills.md`) |
| Potions and usable items | built |
| Kill streaks: +10% damage per kill, expires 25 s after the last kill | built |
| Hidden recovery: heal while unseen and moving | built |

## Added 2026-10-27

| Feature | Status |
|---|---|
| Sprinting (Shift, stamina) replaces dashing; the dash skills became sprint skills | built |
| Lobby: vote the map from 4 random maps | built |
| Settings: volume (master, music, effects), brightness, contrast, colour, fullscreen, vsync, fps, mouse, field of view, shake, rebindable keys | built |
| Map borders that fit each map's theme | in progress (pictures taken for all 13 maps; fixes per map still to do) |
| Smaller weapons that never clip into the body | built (hold offsets and tilts searched against every class's body; check by eye in the game) |
| Clothes never stretch | mostly built (a few classes still stretch a little in extreme poses) |
| Every map's decor has more variety: each tree, rock, fern, crystal, kelp, cloud gets its own size, lean, turn and colour | built |
| Capture the flag (third mode, pick it on the title screen): each team has a flag at its base, take the enemy flag to your own base while yours is home, first to 3 captures; a carrier is a little slower and drops the flag when killed; touch your own dropped flag to send it home (or it goes home after 20 s); bots attack, defend and chase carriers; flags show on the minimap | built (first test) |
| Leaderboard that tracks kills AND deaths as a K/D ratio: the in-match scoreboard (B) now has K, D, K/D, streak, flags, best ratio first; the title screen has a LEADERBOARD with your career K/D (by class too), the best fighters over all matches (bots have names now), and your recent matches; the result screen shows the match and career K/D | built |
| Air drops: every 70-100 s a crate on a parachute falls on a spot of the map with a golden light column, minimap marker and a toast; it lands as a gold loot crate anyone can open; bots head for it too | built |
| Loot crates | already in every map (12-24 per map) |
| Each class holds its OWN weapon (the weapon you equip is remembered per class, so the title and armory show the class's own weapon, not one shared wand) | built |
| Title screen: the real maps as a slowly turning panorama (with flowers, rim trees and animals), hero only plays idle | built |
| Map rim dressing: a belt of the map's own trees, rocks, ferns, crystals, kelp planted bigger beyond the play area, plus big decor shapes | built (first version, look at it) |
| New scattered decor in every map (flowers in many shapes and colours, grass, mushrooms, bushes, ferns, rocks, boulders, stumps, logs, bones, mounds, graves, glowing pods, giant blooms, corals, cacti, gears), a different mix per map, kept off the paths | built |
| Better rocks: chunky faceted stone, with moss on top (forest, swamp, crypt) or snow (frozen peaks), small stones around | built |
| Small animals in every map (not chess): bunnies, frogs, mice, lizards, beetles, crabs, penguins hop and scurry; butterflies, dragonflies, birds, bats fly; fish and jellyfish swim; they run away from fighters | built |
| More fantasy look: sky, particles, UI, title screen; weapons, cards and skill buttons in one style | built |
| A distinct animation for every skill and weapon family | built |

## What I still owe you

1. Crate spots, mission NPC spots and quest NPC spots in the 11 older maps (the two newest maps have them), and jump pads / rooftops in the 9 maps that lack them.
2. NPC and crate models for the 11 older maps (pictures first).
3. Wall pictures for the marble, crystal, steampunk and moon themes.
4. Game code, when you lift the pause.

## Also added 2026-10-27 (later)

| Feature | Status |
|---|---|
| Giant mushrooms are bouncy: a ring around the foot throws you up onto the cap and the cap bounces you again (HazardNode bounce_pad with `inward`) | built |
| Legs / cloth stretching while walking and running: the body fixer now probes the run, sprint, slide and jump-loop clips too (and really plays the animation: the old probe only saw the rest pose), keeps robe hems off the feet, and joins the hems between the two feet to the hips | improved, check by eye |
| Optimising: sky reflection map no longer redrawn every frame, shadows 80 m / 2048 map, mesh level-of-detail starts earlier, decor and animals drawn only nearby, rim props only to 260 m | built, measured on the laptop: Pirate Cove about 13-20 fps -> 25-29 fps |

## Added 2026-10-27 (night)

| Feature | Status |
|---|---|
| Double jump for everyone (one extra jump in the air, with a ring of dust); cards that give extra jumps add to it | built |
| Fall damage: a drop of more than 6 m hurts 4.5% of max health per extra metre (a very long fall kills); jump pads, ladders and teleports do not count | built |
| Ladders (walk into them to climb, away to go down, Space kicks off, at the top you hop onto the ledge): one at the front of every sniper perch and one up every real cliff of the rim | built, tested on Clockwork Mines |
| Wall parkour: stepped slabs 2 m apart up the rim beside each perch (a double jump from slab to slab) wherever the rim is steep, a second jump pad to the third slab, and a ladder + jump pad up every cliff face near the arena | built (flat-sloped rims such as the forest have none: you just walk up) |
| Sniper perches dressed in each map's own theme (treehouse, stilt hut, reef lookout, ice shelf, forge gallery, sun terrace, bone balcony, crystal shelf, gear walk, moon terrace, crow's nest, rook tower) | built (procedural; to be replaced by Hunyuan models once the pictures are approved) |
| 85 weapons: the 55 old ones + 30 new ones, each new one with a different mechanic (lifesteal, execute, lunge, double strike, pull, knockback, chain lightning, ramping fire rate, burst, pierce, homing, mana on hit, full-circle spin) | built, mechanics in WeaponRunner; models are placeholders from the packs until Hunyuan models exist (drop `models/weapons/hy/<id>.glb`) |
| 85 armor sets: the 50 old ones + 35 new ones, every set with its own look (16 styles), colours, passives on every piece, a set bonus and a SIGNATURE WEAPON; a complete set looks better (glow, taller crest, spikes, mantle, sparks) and gives the set bonus, and with its own weapon an extra +12% damage and +8% health | built |
| Armor on the body: every piece is built to fit the real chest, limbs and head of that class model, is fastened to the skeleton and moves with the animation; the original clothes under it are cut out of the body mesh; bots wear armor too | built, first version: blocky, look at it |
| Armor keeps the class's feel: each class leans the colours to its own and adds its own motif (leaf crown, fins, flames, ice points, wings, veil, bone crown, rune ring, goggles, tricorn, gear halo, moon) | built |
| 10 weapon skins and 10 armor skins (Ivory, Obsidian, Crimson, Azure, Verdant, Gilded, Frostwork, Emberglass, Moonlit, Voidtouched), some much rarer than others; only a brand-new item rolls one (a better crate leans to the rarer skins); the skin is painted over the weapon or the armor | built |
| Old, worn weapons and armor look rusty (rust patches, dull metal, no glow) | built |
| Necromancer remade on a body with real arms and legs (the old model could not be fixed); dark hooded outfit with a bone crown and skull shoulders, shown whatever armor is worn | built (placeholder body; a Hunyuan model would be better) |
| Crate screen fixed: the buttons could be pushed off the bottom of a small window (softlock); they now sit in a bar at the bottom, Enter or Esc closes; the chest lid had see-through faces | fixed |

## Changed 2026-10-28

| Feature | Status |
|---|---|
| Armor is no longer drawn on the characters (you asked to drop it: only weapons are shown). Armor items still give their passives, set bonuses, skins and the old/new look in the armory and crates. The code to draw it (and a first Hunyuan plate set) stays and can be switched on with `CharacterModel.ARMOR_VISIBLE` | done |
| Weapons from Hunyuan: pictures in one realistic style (Perchance "Concept Art") -> Hunyuan image-to-3D -> `models/weapons/hy/<weapon id>.glb` (the game picks them up by itself) | not started (0 of 85) |
| Necromancer remade from scratch: new picture (hooded dark mage, A-pose) -> Hunyuan -> rigged with the 30 CC0 clips -> in the game with arms and legs | done; idle arms stay out (A-pose), cloak is rigid, check by eye |

## Running stretch fix (Arcanist, Frost Mage, Time Mage, Sea King)
- `run_calm` in `data/classes.json` (cloth/hair bones held at rest, shorter leg/arm/spine swing in Run and Sprint), applied by `ClothDamp.apply`; stretched spike triangles removed from the four fixed bodies (`tools/cull_stretch.gd`, originals kept as `.pre_cull`).
- Bad edges while running (Run): Arcanist 1081 -> 54, Frost Mage 404 -> 37, Time Mage 392 -> 6, Sea King 196 -> 4. Trade-off: the stride of these four is shorter (robed glide-run).
- Other classes were not touched (Celestial Mage skirt, Thunder God feet, Druid shin are the next worst).
- Same `run_calm` now also on Druid, Thunder God and Celestial Mage (Run bad edges 106 -> 14, 257 -> 26, 170 -> 30). Not yet calmed: Necromancer, Poison Brewer, Pirate Captain, Desert Assassin, Flame Lord.
- Also calmed: Necromancer, Poison Brewer, Desert Assassin (strong) and Pirate Captain, Flame Lord (mild), so every live class has `run_calm`. Necromancer now has a fixed body with rigid boots (`fixed/necromancer_body.res`), which stopped its boots shredding while running.

## LAN multiplayer (host or join)
- Title screen: LAN GAME. HOST starts a server (port 24565) and shows the address friends type; START opens the map vote and begins the match for everyone. JOIN takes the host's address.
- The host runs the real match (bots, points, pickups, damage, deaths); joined players move their own character and the host does the fighting for them with their own gear and skills. Everyone sees the same fighters, attacks, damage numbers, kill feed, score and clock.
- Not shared yet: capture the flag (host falls back to domination), loot crates, NPC missions, air drops (these stay local to each machine). Internet play (outside the local network) is not built.

## Human-like running (not floating)
- The running clips are played at a speed that matches how fast the fighter really moves (no foot skating), and the model is lowered while running so the lowest foot rests on the ground instead of hovering. Robed classes keep a slightly shorter stride (legs 80%) so capes and skirts do not tear; the other classes use the natural stride.
- Known limit: there is no walk clip, so very slow movement (1-3 m/s) plays the run clip slowly.

## Crosshair and animation transitions
- Crosshair in the middle of the screen (the old one was drawn off-screen, so it never showed): four ticks and a dot with a dark outline, the gap opens when you move, sprint, jump or fire and closes when you aim, it turns red on an enemy, a ring fills while a ranged weapon charges a sniper shot, a cross flashes on every hit (red on a kill). Hidden while dead or in a menu. Works in LAN games too.
- Every pair of the 30 animation clips has its own fade time (attacks and hits 0.04-0.06 s, idle/run/sprint 0.16-0.22 s, landing, slides, death, revive, emotes in between), so nothing pops between animations.

## Session of 2026-10-28 (evening): fixes and polish
- Name: the game is now **Steel and Spells** (title screen, project name).
- Walking and jumping: a Walk clip (shorter stride, less bounce) for speeds under 3.3 m/s, a leaping air stride (Air clip) while moving fast through the air, a dedicated Climb clip for ladders (arms reach up and take turns, knees come up one after the other), the feet kept apart so the boots no longer pass through each other. The run clip already swings the arms (measured: hands move about 0.4 m front to back, opposite to the legs).
- Attacks: capes and skirts are held back in every clip, not only running (`run_calm.cloth_all`), so they no longer tear when arms and legs swing wide; the Celestial Mage's wings are calmed in all clips; Arcanist and Celestial Mage weights re-smoothed (`tools/fix_body.gd`). Worst stretch while attacking dropped from x11-x23 to x2.6-x6.6.
- Death is a ragdoll (`scripts/core/Ragdoll.gd`): every main bone becomes a rigid body with joint limits, the killing hit pushes the body away from the attacker; undone on respawn. Setting `ragdoll` (default true) turns it off.
- Lighting: the point lights in the map files had energies of 100 000 and burned the Crystal Caves, Shadow Crypt and Moon Sanctuary to white; they now get a soft strength and fade out with distance. Glowing materials are tinted and capped, dark maps get an ambient floor.
- Maps: pedestals, altars, fountains, statues and chests now collide (they had no hitbox); floating water (the oasis of the Desert Tomb) is lowered onto the ground; loot crates and air drops are moved out of walls and rocks.
- Crates: legendary crates are four times rarer and mythic ten times rarer (and a gold crate is epic or better, no longer always legendary); end-of-match crate odds lowered at the top.
- Crosshair now visible (see above), hexagon ground rings no longer cut off at the corners.
- Performance: adaptive render scale (55-100%) when the frame rate is low, fighters far away stop casting shadows, map lights fade with distance, the minimap redraws at ~11 Hz. Honest limit: this PC was at 100% CPU with under 1 GB free memory while testing, so the real gain could not be measured.
