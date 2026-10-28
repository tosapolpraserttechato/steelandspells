# Game design notes

A multiplayer fantasy shooter. These notes record the rules as you described them. Items marked *(to confirm)* are my reading or my proposal and still need your yes. Last updated 2026-10-20 (levels, missions, potions, kill streaks, class stats, hidden recovery, gold crates, rooftops and jump pads added).

## Everything you asked for (checklist)

Kept here so nothing gets lost. Each line says where the detail is.

- **Game:** a multiplayer fantasy team shooter in Godot (it started as an MMORPG). **Maps first, no game code until you say so.**
- **Art:** every 3D object is made on the Hunyuan3D website from a **picture** (image-to-3D, never text-to-3D, never run locally); pictures come from Google Images and are credited in `CREDITS.md`. Same art style across all maps.
- **Maps:** 13 maps, each with a home class buff and a rival debuff (*Maps: buffs and debuffs*), **1 unique mechanic and 1 hazard each** (*Map mechanics and hazards*), a theme-matching **natural boundary** (never a bare wall), and two teams on **mirror-image halves**. Flora Forest has **dense and lighter areas**.
- **Classes:** 13, with the new names (Thunder God, Poison Brewer, Time Mage, Celestial Mage) and **GM Ravn** with no debuffs, a huge sacrificed **queen** as his ultimate, and a **checkmate finisher** on ultimate kills (*Classes*).
- **Every player:** 3 chosen skills from any class, a fixed **4th signature skill that is an area attack**, an **ultimate**, 1 passive and a **class meter** with its own mechanic; **class skills are massively buffed for their own class** (*What every player has*).
- **Progress:** XP from kills and crates, then **1 of 3 cards** at each level; **Tab hides and shows the cards**; **rerolls** (from crates) get 3 new cards; **125 cards** in 6 rarities that stack up to 6 times, each copy one rarity higher (*Cards*).
- **No guns:** weapons are fantasy only (swords, bows, staffs and so on), from CC0 model packs, never hand-made 3D models.
- **Gear:** **50 armor sets of 5 pieces** (helmet, chestplate, shield, leggings, boots), **each piece has its own passive**, completing a set is much stronger; **55 weapons with no skins of their own** (the only skin an item ever gets is the one rolled by a brand-new loot crate); both **magic and non-magic** versions (*Armor*, *Weapons*).
- **Runes:** a new item type that drops from crates (*Runes*).
- **Status effects:** burn, freeze, poison, shock, stun, slow, root and more, plus buffs; map hazards, skills, gear and modifiers all use them (*Status effects*).
- **Auras:** legendary modified gear = **gold aura**; mythic modified gear = a **unique aura**; **armor gets modifiers too** (*Loot crates*).
- **Crates:** common to mythic; open one and it picks weapon, armor, shield, rune or a card reroll, then **old (tiny debuff) or brand new (skin plus a modifier that grows with rarity)** (*Loot crates*).
- **Levels:** level cap **100**; every **10 levels** you unlock a **unique skill of your class**; each class has **10 distinct skills** you can mix and match (*Levels and skills*).
- **NPC missions:** NPCs give missions; finishing one gives **XP and a full heal** (*Missions*).
- **Potions and items:** potions plus other usable items (*Potions and items*).
- **Kill streaks:** every kill adds **+10% damage**, and the streak **expires after 25 seconds** without a kill (*Kill streaks*).
- **Class stats:** every class has its own **acceleration, size, sight distance, speed and crit chance** (*Class stats*).
- **Hidden recovery:** you **heal when no enemy sees you and you are moving** (*Hidden recovery*).
- **Gold crates:** a new gold crate type (*Loot crates*).
- **Maps:** **more rooftops** and **jump pads** to reach the high ground (*Map rules: rooftops and jump pads*).
- **Characters:** the 13 class characters are made on **Hunyuan** from pictures in the **Time Mage's art style**; the Pharaoh is now the **Desert Assassin** (*Classes*).
- **UI:** easy to understand, **rarity always clear** by colour, shape, icon and written name (*UI rules*).
- **Cloth sim (2026-10-21):** capes, coats, robes, scarves and hair of the class characters move with a **cloth simulation** (*Cloth simulation*).
- **Animations (2026-10-21):** every class gets idle, run, jump, attack, cast, ultimate, hit and death clips, plus **hair animations** (*Animations*); needs rigging first.
- **Quest skills (2026-10-21):** **50 quest skills**, common to mythic, **good for every class**, earned from **quests given by an NPC that appears only some of the time**; you get a **demo** of the skill to do the quest, and the **reward comes only a % of the time**. Example (yours): *Thirst for Blood* = NPC 50% of the time, ONESHOT 10 enemies in 45 s, 20% to get it; x-ray for 10 s, click an x-rayed enemy to teleport behind them (*Quest skills*, full list in `quest_skills.md`).
- **Less Hunyuan (2026-10-21):** "try to not use hunyuan": the 13 class characters stay on Hunyuan, but map props should come from **CC0 models** (Poly Haven and similar) where a good one exists, to save the daily free generations (*Art sources*).

## Core loop

1. Pick a **class**, 3 skills, a weapon and armor, then fight on a map.
2. **Get XP** by killing enemies, opening **crates** and finishing **NPC missions** (a mission also heals you fully).
3. **Level up** (cap **100**), then pick **1 of 3 cards**; every **10th level** also unlocks a unique class skill.
4. Cards, armor and your class all make your character stronger for the rest of the match.

## Classes

13 classes, one home map each. Final names (changed 2026-10-20):

| # | Class | Home map | Class meter |
|---|---|---|---|
| 1 | Druid | Flora Forest | *(coming from you)* |
| 2 | Sea King | Underwater Ocean | *(coming from you)* |
| 3 | Flame Lord | Volcano Forge | *(coming from you)* |
| 4 | Frost Mage | Frozen Peaks | *(coming from you)* |
| 5 | **Thunder God** (was Storm Caller) | Sky Islands | *(coming from you)* |
| 6 | Desert Assassin | Desert Tomb | *(coming from you)* |
| 7 | Necromancer | Shadow Crypt | *(coming from you)* |
| 8 | Arcanist | Crystal Caves | *(coming from you)* |
| 9 | **Poison Brewer** (was Witch) | Toxic Swamp | *(coming from you)* |
| 10 | Pirate Captain | Pirate Cove | *(coming from you)* |
| 11 | **Time Mage** (was Engineer) | Clockwork Mines | *(coming from you)* |
| 12 | **Celestial Mage** (was Moon Priest) | Moon Sanctuary | *(coming from you)* |
| 13 | **GM Ravn** | Chess Arena | *(coming from you)* |

### Class characters

The 13 characters are made on **Hunyuan** (image to 3D) from reference pictures, all in the **art style of the Time Mage picture** (clean anime-style game art, full body, plain background). They are static models for now; rigging and animation come later.

### Desert Assassin (replaces the Pharaoh, 2026-10-20)

- Home map: **Desert Tomb**. A fast, sneaky blade fighter of the dunes: daggers and curved blades, sand, vanishing and poison. The old Pharaoh skills (curses, locusts, eclipse) need to be redone for this class *(skills, meter and ultimate coming from you or my proposal)*.

### GM Ravn (13th class, replaces GM Levy)

- **Made-up name and look (2026-10-20):** a young, invented Norwegian-style chess champion in a smart suit with a king piece. "Ravn" is Norwegian for raven. He is **not** based on any real player's face or name.

- Home map: **Chess Arena**.
- **No debuffs:** there is no map where Ravn is weakened.
- **Ultimate: Queen Sacrifice.** He **spawns a huge queen and sacrifices it** (changed from a rook on 2026-10-20) *(effect to describe: area blast? wall? damage? My proposal: the queen sweeps across the board like a queen move in one line then shatters in a huge blast; same kit as before: big damage, knockback and stun)*.
- **Finisher:** when a kill is made **with an ultimate**, a finisher plays: **Ravn checkmates the victim on the spot** *(to confirm: only when Ravn gets the ultimate kill, or for every class's ultimate kills, with Ravn appearing?)*.
- Meter and skills: *(coming from you)*.

### What every player has

| Slot | Count | Rules |
|---|---|---|
| **Chosen skills** | 3 | Pick any 3 from the skills of **all** classes you have unlocked (each class has **10 distinct skills**, unlocked one per 10 levels: see *Levels and skills*). |
| **Signature skill (4th skill)** | 1 | Fixed by your class. You can't choose or swap it. **Every class's signature skill is an area attack (AOE).** |
| **Ultimate** | 1 | A very strong skill you can use only when you've **fully charged your bar** *(to confirm: is that the class meter, or a separate ultimate bar?)*. Every class has its own. |
| **Passive** | 1 | A permanent effect from your class. |
| **Class meter** | 1 | A bar with its own mechanic, different for every class. **You'll tell me the mechanics later.** |

**Class mastery:** a skill that belongs to your own class is **massively buffed** when you use it. Taking another class's skill works, but at normal strength. So a Frost Mage who picks a Flame Lord skill gets a normal fireball, and a Flame Lord gets a boosted one.

Each class owns **10 distinct skills** in the shared pool, so **130 skills** in total, plus the signature skill and ultimate of each class.

## Maps: buffs and debuffs

Each map **buffs** its home class and **debuffs** one rival class. Every class is buffed on exactly 1 map and debuffed on exactly 1 map, except **GM Ravn**, who is buffed on Chess Arena and debuffed nowhere. The debuff targets below are my proposal *(to confirm)*; the map says on the loading screen who is buffed and who is weakened.

| # | Map | Theme | Buffed class | Debuffed class |
|---|---|---|---|---|
| 1 | Flora Forest | Giant mushrooms and flowers, leafy trees, hollow logs, vine-covered ruins | Druid | Desert Assassin (no sand or sun) |
| 2 | Underwater Ocean | Coral reefs, kelp forest, a shipwreck, giant clams, sunken ruins | **Sea King** | Flame Lord (fire is put out) |
| 3 | Volcano Forge | Lava rivers, obsidian rocks, a dwarven forge | Flame Lord | Frost Mage (ice melts) |
| 4 | Frozen Peaks | Ice cliffs, a frozen lake, snowy pines, an ice fortress | Frost Mage | Sea King (the water is frozen) |
| 5 | Sky Islands | Floating islands, rope bridges, wind shrines | Thunder God | Pirate Captain (no sea) |
| 6 | Desert Tomb | Dunes, a pyramid tomb, broken statues, an oasis | Desert Assassin | Druid (no plants) |
| 7 | Shadow Crypt | Graveyard, crypts, a haunted cathedral, fog | Necromancer | Celestial Mage (no moonlight) |
| 8 | Crystal Caves | Glowing crystal caverns, an underground river | Arcanist | Thunder God (no sky) |
| 9 | Toxic Swamp | Mangroves, glowing poison pools, witch huts | Poison Brewer | Arcanist (magic fizzles in the fumes) |
| 10 | Pirate Cove | Beach, docks, a beached pirate ship, sea caves | Pirate Captain | Time Mage (no machines) |
| 11 | Clockwork Mines | Mine tunnels, rails, giant gears, steam pipes | Time Mage | Poison Brewer (steam clears the fumes) |
| 12 | Moon Sanctuary | White marble night temple, moon pools, floating stones | Celestial Mage | Necromancer (holy light) |
| 13 | **Chess Arena** | A giant chessboard: black and white tiles, towering chess pieces as cover, a marble hall | **GM Ravn** | *nobody*: Ravn has no debuffs, so this map weakens no one |

How strong the buff and debuff are is *(to decide)*.

### Map mechanics and hazards

Every map has **1 unique mechanic** (something players can use) and **1 hazard** (something that hurts). These are my proposals *(to confirm or swap)*; the first two are being built into the maps now.

| # | Map | Unique mechanic | Hazard |
|---|---|---|---|
| 1 | Flora Forest | **Spore Bounce**: giant mushroom caps are jump pads that fling you onto roofs and over bushes | **Thorn Vines**: patches of vines slow you down and hurt you over time |
| 2 | Underwater Ocean | **Tidal Currents**: lanes of current carry you quickly across the map (and push enemies) | **Jellyfish Swarms**: drifting swarms shock and stun anyone who touches them |
| 3 | Volcano Forge | **Cooling Bridges**: lava bridges harden into walkable stone when hit with ice or water, then melt again | **Lava**: deep lava river, heavy damage |
| 4 | Frozen Peaks | **Ice Slides**: smooth ramps launch you down the slope at speed | **Avalanche**: warning rumble, then snow sweeps one slope |
| 5 | Sky Islands | **Updrafts**: wind columns lift you between islands so you can glide | **Lightning Strikes**: marked spots get hit, big damage |
| 6 | Desert Tomb | **Pressure Plates**: stepping on plates opens or closes tomb doors | **Quicksand**: sinks and slows you; stay too long and you take damage |
| 7 | Shadow Crypt | **Lantern Light**: fog hides players; lanterns reveal everyone nearby | **Cursed Graves**: graves spawn ghosts that chase the nearest player |
| 8 | Crystal Caves | **Resonance**: shooting a crystal shatters it into shards, or turns it into cover | **Falling Stalactites**: shaking, then rocks drop on marked circles |
| 9 | Toxic Swamp | **Spore Pods**: popping a pod gives a burst of speed and charge to your meter | **Poison Water**: standing in the pools drains health |
| 10 | Pirate Cove | **Cannons**: mounted cannons you can fire at distant targets | **Rising Tide**: waves flood low ground, pushing and slowing you |
| 11 | Clockwork Mines | **Mine Carts**: ride rails across the map; you can shoot from the cart | **Steam Vents**: bursts of steam burn on a timer |
| 12 | Moon Sanctuary | **Moon Phases**: the moon changes every minute and each phase gives a different team buff | **Eclipse Dark Zones**: the dark patches drain your shield |
| 13 | Chess Arena | **Living Board**: giant chess pieces slide across the board on a timer and become moving cover | **Falling Pieces**: a knight's jump lands on a marked square, crushing anyone there |

### Map rules: rooftops and jump pads

*Added from your message ("make rooftops more common", "jump pads for using the high ground").*

- **Every map gets more rooftops** that players can stand on: buildings, ruins, platforms and ledges with a flat, reachable top, spread across both halves.
- **Jump pads** launch you up to the high ground (rooftops, ledges). Each team half gets several, placed next to the high spots, with a `jump_pad` marker (launch direction and height) in the map data.
- The six built maps (Flora Forest, Underwater Ocean, Volcano Forge, Frozen Peaks, Sky Islands, Desert Tomb) need a pass for this *(to confirm which maps first)*; the next maps are built with it from the start.

Chess Arena (2026-10-21): built from the CC0 Poly Haven Chess Set scaled x95 (giant pieces 5-9 m, board 52 m), 0 problems; hall, galleries and jump pads made in Blender. No marble column model yet (rook towers and giant pieces form the walls).

Map status (2026-10-21, evening): **all 13 maps are built and pass the map check**: Flora Forest, Underwater Ocean, Volcano Forge, Frozen Peaks, Sky Islands, Desert Tomb, Chess Arena, Pirate Cove, Shadow Crypt, Crystal Caves, Toxic Swamp, Clockwork Mines, Moon Sanctuary. Props come from CC0 libraries (Chess Arena, Pirate Cove) or Hunyuan from approved pictures (the rest). Still to do: crate and NPC spots plus jump pads in the older maps, and one more look at each map's art style once the game engine lighting exists.

## Levels and skills

*Added from your message. My reading is marked "to confirm".*

- **Level cap: 100.**
- **Each class has 10 distinct skills** that you can **mix and match** (any 3 can be equipped, from any class).
- **Every 10 levels you get a unique skill of your character** (levels 10, 20, 30 ... 100 = the class's 10 skills, one per milestone) *(to confirm: are the 10 skills exactly these 10 unlocks, or do you start with some and these are extra?)*.
- A skill of your **own class** is massively buffed (*Class mastery*).
- Level-ups still give **1 of 3 cards** at every level.
- *(To decide)* XP needed per level (proposal: fast early levels, slower later) and whether levels reset each match or are kept between matches.

## Missions

- **NPCs on the map give missions.** Finishing a mission gives **XP and a full heal**.
- *Proposal for mission types:* kill 3 enemies, capture a point, bring a pickup to the NPC, hold a point for 20 seconds, destroy a crate, get a kill from the high ground.
- *Proposal:* 2 to 3 NPCs per team half; one mission at a time; NPCs are neutral and cannot be hurt; a mission can be repeated after a cooldown.
- NPC characters will also be made on Hunyuan from pictures *(to confirm)*.

## Potions and items

- **Potions** *(proposal)*: Health (heal 60), Mana (restore 60), Speed (haste 6 s), Shield (barrier 6 s), Cleanse (remove debuffs and a short immunity), Rage (+25% damage 8 s). You carry up to 3 and use them with a key.
- **Items** *(proposal)*: usable pickups you carry: throwing bombs, traps, scrolls (one-use skill), a smoke bottle, a revive token.
- Potions and items drop from crates, NPC missions and map pickups, and use the same 6 rarities *(to confirm the item list)*.

## Kill streaks

- **Each kill adds +10% damage** (a streak counter shown on the HUD).
- The streak **expires 25 seconds after your last kill**; each new kill resets the 25 second timer.
- *(To confirm)* it resets when you die; bonuses add up (10 kills = +100%); a cap (proposal: +100%).

## Class stats

Every class has its own movement and sight numbers. *Proposal values; change any of them.*

| Class | Speed (m/s) | Acceleration | Size (scale) | Sight distance (m) | Crit chance |
|---|---|---|---|---|---|
| Druid | 5.8 | 9 | 1.00 | 70 | 6% |
| Sea King | 5.6 | 8 | 1.10 | 65 | 5% |
| Flame Lord | 5.8 | 9 | 1.00 | 70 | 8% |
| Frost Mage | 5.6 | 8 | 0.95 | 75 | 7% |
| Thunder God | 6.4 | 12 | 1.00 | 70 | 8% |
| Desert Assassin | 6.8 | 15 | 0.90 | 80 | 14% |
| Necromancer | 5.4 | 8 | 1.00 | 70 | 6% |
| Arcanist | 5.6 | 9 | 0.95 | 75 | 7% |
| Poison Brewer | 5.6 | 9 | 0.95 | 65 | 6% |
| Pirate Captain | 5.8 | 10 | 1.10 | 70 | 9% |
| Time Mage | 6.0 | 11 | 0.95 | 75 | 7% |
| Celestial Mage | 5.8 | 9 | 0.95 | 85 | 6% |
| GM Ravn | 6.0 | 10 | 1.00 | 80 | 8% |

- **Speed** is top running speed, **acceleration** is how fast you reach it (higher = snappier turns and stops), **size** is the character's scale (a bigger body is an easier target), **sight distance** is how far you can see enemy players and outlines, **crit chance** is the base chance for a critical hit.
- Cards, armor and runes add to these numbers.

## Hidden recovery

- **You heal while you are not seen and moving.** "Not seen" = no enemy has line of sight to you.
- *Proposal:* after 3 seconds unseen, regenerate **3 health per second** (and a little mana) while moving; standing still does not count; it stops the moment an enemy sees you or you are hit. Cards and armor can raise it.

## Cloth simulation (2026-10-21)

You said: **"add cloth sim"**. Recorded here as a feature; **no game code is written** (code is paused).

- **What moves:** cape, coat, robe, scarf, sash and long hair. Per class: Druid (cloak and leaf skirt), Sea King (ice-blue cloth), Flame Lord (cape and sash), Frost Mage (cape and long hair), Thunder God (long coat), Desert Assassin (scarf and sash), Necromancer (long red coat and hair), Arcanist (cape), Poison Brewer (skirt and sleeve), Pirate Captain (coat tails), Time Mage (long coat), Celestial Mage (cloak and wings), GM Ravn (suit jacket tails).
- **Cloth done in Blender (2026-10-21):** skirts, coats, capes and wings of all 13 classes now swing as separate parts, baked into the clips (`anim/README.md`, `anim/cloth.py`). In the game the same bones can keep swinging with Godot spring bones if live cloth is wanted; the baked version already works without code.
- **The catch (why it is not instant):** the Hunyuan characters are **one fused static mesh**: the cape, body, hair and weapon are a single piece and there is **no skeleton**. Cloth needs the moving parts **separated** and a skeleton to hang them from. That is the same job as rigging and animation (idle, run, jump, shoot, cast, hit, death), so cloth is part of the **animation phase**.
- **Proposal (to confirm):**
  1. **In the game:** **spring-bone chains** on cape, coat, scarf and hair (Godot's built-in `SpringBoneSimulator3D`): cheap, steady, works for 13+ players and online. Real per-vertex cloth is too heavy for a team shooter (Godot also has no built-in cloth; `SoftBody3D` is too slow for this).
  2. **Cutscenes and finishers** (GM Ravn's checkmate, ultimates, victory poses): a **Blender cloth simulation baked into the animation clip**, so it can look richer.
  3. Order: rig and separate cloth on one class first (the Druid), check how it looks, then do the other 12.
- *Open:* do you want the cape separate from the body in the model (needs me to cut the mesh by painting a vertex group), or is wobbling the whole lower half of the coat enough?

## Animations (2026-10-21)

You said: **"add animations too"** (also "make animations too" on 2026-10-20). **No game code is written.**

- **Clips every class needs:** idle, walk/run (8 directions), jump (start, air, land), shoot/attack, cast (skills 1-4), ultimate, hit reaction, death; plus a victory pose and, for GM Ravn, the checkmate finisher.
- **The catch:** the Hunyuan characters are static meshes with no skeleton. Each one has to be **rigged** before any clip can play. Several have wings, long capes, big hair or dynamic poses, which also breaks free auto-riggers (Adobe's Mixamo says wings, tails and large hair or clothing can make auto-rigging fail, and pre-posed characters may fail).
- **Proposal (to confirm):** rig in Blender (humanoid skeleton fitted to each model, automatic weights, hand-fixed where needed), then play **CC0 humanoid clips** on it: the Quaternius **Universal Animation Library** (CC0, 120+ clips, one humanoid rig, free "Standard" part), retargeted to each character's skeleton. Spell casts and a few specials that the library lacks are added later from a second CC0 pack or posed by me in Blender. **Cloth and hair** (see above) hang from extra spring bones. Start with the Druid as a test, show you the result, then do the other 12.
- **Hair animations (2026-10-21, "and some hair animations too"):** hair moves too, in two layers. (1) **Hair physics**: spring-bone chains on the long hair so it sways, trails behind when running and swings when turning. (2) **Hair-specific clips** that play on top of the body clips: idle sway, run flow, jump lift and fall, hit flinch, death fall, plus a wind-blown pose for victory and finishers. Classes with long or loose hair: Druid, Frost Mage, Necromancer, Poison Brewer, Flame Lord, Thunder God, Desert Assassin (headscarf ends), Celestial Mage, Arcanist. Short or covered hair (little or no hair motion): Time Mage, Pirate Captain (hat), Sea King, GM Ravn. Like cloth, the hair is part of the fused Hunyuan mesh, so it has to be **separated** (painted as its own vertex group) before it can move on its own; until then only the whole head would move.
- **Druid test done (2026-10-21):** `anim/rig_character.py` rigs a character and retargets the clips; result `anim/out/class_druid_rigged.glb` (2.9 MB) with 14 clips (Idle, Run, Sprint, JumpStart/Loop/Land, CastEnter/Idle/Shoot/Exit, Attack, HitChest, HitHead, Death) and 10 hair bones (back strand + both sides) with simulated hair motion baked in. Pictures: `previews/druid_animation_test_sheet.png`, `previews/druid_hair_test_sheet.png`. Known flaws: the long skirt and the bow follow the legs and hand (they are part of the fused mesh, so the skirt stretches when she runs), the hair used to open small gaps (not a see-through material, the texture is fully opaque): fixed on 2026-10-21 by weighting the hair only by height along one strand, so the hair bends as one mass, no finger bones, fitted by eye from side pictures. The Druid model itself stands with her left knee bent (taken from the reference picture), so the rig is bound to that bend and the animations are built from a straight leg.
- **CC0 clips only (2026-10-21, "use cc0 animations from the internet"):** all body clips come from the two Quaternius libraries (Universal Animation Library and Universal Animation Library 2, both CC0, downloaded from OpenGameArt). The Druid now has **30 clips**: the first 14 plus Knockback, Throw, Hook, Block, MeleeA/B/C/Combo, SlideStart/Loop/Exit, Consume (drink a potion), ChestOpen (crates), Revive, EmoteYes/No. Gaps in the free sets: only one simple spell cast (Enter/Idle/Shoot/Exit), no bow or staff attacks, no directional running (strafe/back). Melee combo clips drift forward (not in place yet). Hair motion is not a clip, it is a small spring simulation baked in by `anim/rig_character.py`.
- **Mixamo is the alternative** (free Adobe account, you sign in yourself; I upload and download), but it likely fails on the winged and caped models, so it is only for the plain humanoids (Desert Assassin, Pirate Captain, GM Ravn, Arcanist, Time Mage).

## Art sources (2026-10-21)

- **Characters:** Hunyuan from the approved pictures (your rule).
- **Map props:** you said **"try to not use hunyuan"**, so props now come from **CC0 libraries first** (Poly Haven, Quaternius, Kenney); Hunyuan only when no CC0 model fits. Chess Arena uses the **Poly Haven "Chess Set"** (CC0, by Riley Queen) for the pieces, so the CC-BY-NC-SA Sketchfab set is not needed there. Credits go in `CREDITS.md`.
- Hunyuan use so far today (2026-10-21): **14 of 60** (12 class models, GM Ravn, one chess king that was already running when you said stop), plus **19 map props** (Shadow Crypt 5, Crystal Caves 6, Toxic Swamp 5, Desert Tomb 3) and 1 spare queued at the time of writing.

## One art style (2026-10-21, "make sure the art style is consistent between the maps and characters")

The target is the **painted, saturated, matte look of the class models**: clean shapes, soft colour ramps, no photo grit, no mirror shine. Rules:

- **Characters and Hunyuan props** already have it. Hunyuan props only get a light touch (matte materials, strength 0.35).
- **Photo-scanned CC0 props** (Poly Haven ships, rocks, barrels, chess pieces) go through `maps/stylize_lib.py` when a map is built: fine texture detail is smoothed (strong edges stay), colours get richer, lightness is banded into a few paint tones, normal maps are weakened, metallic/roughness maps become flat matte values. Models on disk are not changed; the map script calls `kit.stylize(model, strength)`.
- **Ground, stone and walls** are procedural, painted textures with normal maps (`maps/surfaces.py ground_textures`): patchy colour, fine grain, pebbles, real brick or block courses. No more blocky pixel patterns.
- **Water, ice, quicksand and waterfalls** are hand-tuned materials in `maps/surfaces.py` (rippled see-through water with soft caustics, cracked glossy ice, a whirlpool of quicksand, streaked falls with foam). The same module will make the Toxic Swamp's green poison water.
- **Shine:** stone and sand props are matte (`kit.matte`), e.g. the Desert Tomb sphinx. Only water, ice, gold and real metal stay glossy.
- **Lights are real:** Shadow Crypt lamp posts carry real point lights (warm orange, 16 m range, no shadows to keep it cheap) with a glowing flame, exported in the map file, plus marker data for the flicker. Other lit props will use the same `kit.point_light`.
- **Walls come from Hunyuan** (your request, 2026-10-21): modular wall sections per theme, replacing procedural boxes. Reference pictures need approval first (`previews/style/wall_candidates_meshy.jpg` has the stone, palisade and ruin candidates).
- **Still to do in the game engine (code is paused):** one shared Godot Environment (tonemap, colour grade, sun colour) and an optional soft outline shader for characters and props, so lighting matches everywhere.


## Quest skills (2026-10-21)

You said: **"add quest skills that you get from quests that range from common to mythic that are good for every class, and there are 50 quest skills"**, with *Thirst for Blood* as the example. Full list, written like the cards: `quest_skills.md` (readable) and `quest_skills.json` (data), made by `make_quest_skills.js`.

- **How it works:** a quest NPC appears on the map only some of the time (more often for common, less for mythic). You talk to it, get a **demo of the skill** to help with the quest, and finish the quest (usually inside a time limit). Then you get the skill only a **percentage of the time**; try again when the NPC returns.
- **Your example, exactly:** **Thirst for Blood** (*Epic*): the NPC appears **50%** of the time; **ONESHOT 10 enemies in 45 s**; you get the skill **20%** of the time; the skill gives **x-ray for 10 s**, and **clicking an x-rayed enemy teleports you behind them**.
- **50 skills, 6 rarities:** 12 common, 11 uncommon, 10 rare, 8 epic, 6 legendary, 3 mythic. Rarer = harder quest, rarer NPC, lower reward chance *(my proposal; only Thirst for Blood is yours)*.
- **Good for every class:** these skills are not class skills, so they do not get the own-class buff.
- *To confirm:* how many you can equip (proposal: 1 slot, picked before a match), whether you keep them between matches (proposal: yes), duplicates (proposal: raise the rarity of your copy, like cards), cooldowns and numbers, and the other 49 skills themselves.
- **Maps:** each map needs a **quest NPC spot** as well as the normal mission NPCs (see *Missions*): a separate rare NPC that gives quests.

## Cards

- **125 different cards**, written and ready: see [cards.md](cards.md) (to read) and `cards.json` (for the game).
- Picked **1 of 3** on every level-up.
- **Tab hides the cards:** while the 3 cards are on screen, press **Tab** to hide them and look at the battlefield; press **Tab** again to bring them back. The match keeps running *(to confirm: does the fight pause while the cards are showing, or only while they are hidden?)*.
- **Rerolls:** you can spend a **reroll** to get 3 new cards. Rerolls come **from crates** *(to decide: how many per crate, whether they carry over between matches, whether the reroll keeps one card you like)*.
- **6 rarity tiers.** Split of the 125: **40 common, 30 uncommon, 22 rare, 16 epic, 10 legendary, 7 mythic.**

  | Tier | Rarity | Frame | Extra | Offered |
  |---|---|---|---|---|
  | 1 | Common | Grey, plain | none | 45% |
  | 2 | Uncommon | Green | small leaf mark | 25% |
  | 3 | Rare | Blue | gem mark | 15% |
  | 4 | Epic | Purple | light shimmer | 9% |
  | 5 | Legendary | Gold | glow | 5% |
  | 6 | Mythic | Red and black, animated | particles, sound | 1% |

- **Stacking:** a card can be taken up to **6 times**. Each copy is stronger, and each copy shows **one rarity higher** than the last (common reaches mythic on the 6th copy).
- Card types: offense, defense, mobility, skill, meter, economy, class, utility.
- Easy to change: edit `make_cards.py` and run it again to rebuild both files.

## Armor

- **50 armor sets**, each with **5 pieces**: helmet, chestplate, shield, leggings and boots. That's **250 pieces**.
- Every set is either **magic** or **non-magic** *(to decide how many of each; proposal: 25 and 25)*.
  - **Magic armor** (robes, enchanted plate): passives help spells, skills and the class meter.
  - **Non-magic armor** (mail, plate, leather): passives help health, defence, speed and weapon handling.
- **Every piece has its own passive.**
- **Completing a set** (all 5 pieces) makes the passives **massively stronger**. The UI shows set progress, like "3/5".
- Each set has a rarity from common to mythic *(to confirm)*.

## Weapons

- **55 weapons.** Weapons have **no skins of their own**. The only skin an item can have is the one rolled by a **brand-new loot crate** item (*Loot crates*). *(Corrected 2026-10-21: earlier notes said 2 skins per weapon, 110 skins.)*
- **No guns: fantasy weapons only.** Every weapon is either **magic** (staffs, wands, orbs, spellbooks, enchanted blades, gauntlets, spirit bows) or **non-magic** (bows, crossbows, thrown weapons, swords, axes, hammers, maces, spears, halberds, scythes, daggers) *(to decide the split; proposal: 28 magic and 27 non-magic)*.
- **Models:** weapons use free CC0 model packs, re-textured to the same painted dark-fantasy look as the maps. Claude does not build 3D models by hand.
  - **Magic weapons** use mana or the class meter, and add spell effects.
  - **Non-magic weapons** use ammo and reward aim; they ignore magic-only debuffs.
- The UI marks magic gear with a small spark icon so it's clear at a glance.
- Weapon types, damage and stats *(coming from you)*.
- A crate-rolled skin takes the rarity of the crate *(to confirm)*.

## Runes

*Added from your message "add runes too". I read it as a new kind of item that drops from crates; correct me if you meant something else.*

- A **rune** is a small magic item with **one effect**. It has the same **6 rarities** and the same look rules as everything else.
- *Proposal:* runes are **socketed into weapons and armor pieces** (1 slot on common gear, up to 3 on mythic gear), so the same bow or helmet can play differently with different runes.
- *Proposal for effects:* one stat or one small trigger each, for example "+4% reload speed", "your skill 2 leaves a frost patch", "heal a little on kill". Rarer runes give stronger or stranger effects.
- Runes can also appear in the **modifier roll** of a brand-new crate item (an item can come pre-socketed).
- *To decide:* how many rune slots per piece, whether runes can be moved between items, whether runes stack, and the full rune list (a first set of about 30 could be written like the cards).

## Status effects

*Added from your message "make it so there are status effects too". The list, numbers and rules below are my proposal; tell me what to change.*

Status effects are temporary conditions on a player. They come from **skills, weapons, runes, crate modifiers, cards, map hazards and map mechanics**.

**Harmful (debuffs)**

| Effect | What it does | Typical source |
|---|---|---|
| **Burn** | Fire damage every second for a few seconds; refreshing resets the timer | Flame Lord skills, fire modifier, lava |
| **Chill / Freeze** | Chill slows you; stacking chill freezes you in place for a moment | Frost Mage skills, avalanche, ice |
| **Poison** | Damage over time and healing is reduced | Poison Brewer, toxic water, spore pods |
| **Shock** | Small damage, then a short stun; can jump to a nearby player | Thunder God, jellyfish, lightning strikes |
| **Stun** | You can't move or use skills for a moment | Big skills, jellyfish, falling pieces |
| **Slow** | Move slower | Quicksand, thorn vines, cold water |
| **Root** | You can't move but can still shoot and use skills | Druid vines, mud |
| **Bleed** | Damage over time that is worse while you are moving | Blades, bone skills |
| **Weaken** | Your damage is reduced | Curses, Necromancer |
| **Vulnerable** | You take extra damage | Marks, Time Mage skills |
| **Silence** | You can't use skills (weapons still work); **magic only**, non-magic gear is immune | Arcanist, Celestial Mage |
| **Blind** | Your screen is partly covered or your aim is shaky | Sand, smoke, steam, flashes |

**Helpful (buffs)**: **Haste** (move faster), **Barrier** (absorbs damage), **Regen** (heal over time), **Empower** (more damage), **Cleanse shield** (immune to debuffs for a moment). The map buff and debuff for classes can also show as status icons.

**Rules (proposal)**
- Each effect has a **duration** and some can **stack** (chill, burn, poison, bleed); every stack shows a number on the icon.
- **Cleanse** skills, some cards and runes remove debuffs; **big skills and ultimates** get a short immunity afterwards so nobody is stun-locked.
- **Class links:** Flame Lord resists Burn, Frost Mage resists Chill, Thunder God resists Shock, Poison Brewer resists Poison, Sea King resists Slow in water (*to confirm*).
- **Magic vs non-magic:** non-magic weapons and armor ignore magic-only effects (Silence, and the magic part of Weaken); magic gear can add effects on hit (a fire modifier adds Burn).
- **Map hazards use these effects:** Quicksand = Slow, then damage; Thorn Vines = Slow + damage; Jellyfish = Shock + Stun; Lava = Burn; Avalanche = Chill + heavy damage; Steam Vents = Burn; Poison Water = Poison; Lightning Strikes = Shock.
- **UI:** a row of icons above the health bar, each with a **name tooltip, a ring that drains with the time left, and a stack number**; harmful ones have a red frame and helpful ones a green frame, always with a shape or symbol so colour is never the only clue.
- *To decide:* the final list, stack limits, how long each lasts, and who resists what.

## Loot crates

- Crates are found on the maps and come in the **same 6 rarities** (common, uncommon, rare, epic, legendary, mythic). Rarer crates look different and glow more, per the UI rules.
- Opening a crate rolls, in this order:
  1. **Item type:** a **weapon**, an **armor piece**, a **shield** (the 3rd piece of every armor set) or a **rune**. A crate can also give a **card reroll** *(proposal: a small share of crates; rarer crates give more)*. A crate can also give XP *(proposal: a small share of crates, to keep XP from crates)*.
  2. **Which item** of that type (which of the 55 weapons, or which piece of which of the 50 armor sets).
  3. **Old or brand new:**
     - **Old:** the item is worn. It gets a **tiny debuff** (a small stat penalty) and no skin or modifier.
     - **Brand new:** it rolls a **skin** (weapons have no skins of their own, so this is the only skin they ever get), and then a **modifier**.
  4. **Modifier** (new items only): a bonus whose strength follows the crate's rarity.
     - Common crate: a small stat, for example **+2% speed**.
     - Mythic crate: a special effect, for example **fire damage**.
     - *(These are examples from you; the real list is still to write.)*
- **Modifiers on armor too:** a brand-new **armor piece or shield** also rolls a modifier (not only weapons), strength by rarity, on top of the piece's own passive. *Proposal examples:* common +2% move speed; uncommon +3% max health; rare +4% armor; epic burn-resist or chill-resist; legendary a small thorns effect; mythic a special effect such as a fire nova when hit *(real list still to write)*.
- **Auras (visual rarity):** an item with a modifier shows an aura around the character and the item: a **legendary modified weapon or armor piece has a gold aura**; a **mythic one has its own unique aura** (each mythic modifier gets a distinct look, e.g. flames, lightning, stars) *(to decide: does an armor set's aura stack or show only the best piece; do other rarities get a small glow, per the UI rules)*.
- **Gold crates** *(new, to confirm what you mean)*: my reading is a special shiny **gold crate** that spawns rarely, often in risky spots (rooftops, the middle), and always rolls at least **epic**, with better odds of a new item with a modifier. Another reading is crates that give gold coins as a currency; tell me if that is it.
- In-match only for now; nothing is bought with real money.
- *To decide:* the odds of old vs new per crate rarity (proposal: common crates mostly old, mythic crates always new), how big the old-item debuff is (proposal: -3% to -5% on one stat), the modifier list per rarity, whether the item's own rarity follows the crate's rarity, crate respawn time, and whether magic and non-magic gear get different modifier pools.

## UI rules (easy to understand, rarity always clear)

1. **One rarity look everywhere:** cards, armor, weapons, skins, modifiers and crates use the same 6 tiers.
2. **Never colour alone:** every rarity also has its own frame shape, a small icon and its **name written out**, so it works for colour-blind players and in a fast fight.
3. **Higher rarity = more glow and motion**, so a mythic is obvious from across the screen. Common stays calm and plain.
4. **Level-up screen:** exactly 3 big cards, rarity name on top, one-line effect, and "Stack 2/6" if you already own it. A small "Tab: hide" hint sits under the cards (and "Tab: show" while hidden), and a button shows how many **rerolls** you have left.
5. **Armor:** a 5-slot silhouette showing which pieces you own; set progress "3/5" and the set bonus lit up only when complete.
6. **Skills and meter:** 4 skill icons with cooldown rings, the passive on the side, and the class meter bar under the health bar. The signature skill has its own frame.
7. **Map buffs:** a green up-arrow or red down-arrow banner at the start of every match says who is buffed or weakened, and a small icon stays on your HUD.
8. Plain words, big text, short tooltips.

## Added 2026-10-27 (all from the user)

- **Sprinting, not dashing.** Hold Shift to sprint (1.5x run speed, drains a stamina bar, rests when empty; no sprinting while aiming). The ten dash skills are now timed *sprint skills* (a few seconds of extra-fast, free sprinting that hurts and marks enemies you run into, some leave a trail); cards and gear that said dash now say sprint (Sprinter's Tonic, Long Stride, Blazing Trail, Phase Step, Thunderstep, Sprint Boots, Swift Soles); quest skills Quick Step and Storm Step are sprint boosts.
- **Lobby map vote.** Pressing Play opens a lobby with 4 randomly chosen maps; every player (you and the bots) votes, the map with the most votes is played, a tie is decided by chance.
- **Settings screen** with volume (master, music, effects), brightness and other options, and rebindable keybinds.
- **Maps** must have borders that look like they belong to the map's theme (not a bare wall or cliff).
- **Weapons** are smaller in the hand and must not clip into the character's body.
- **Clothes must not stretch** (skirts, capes, hair) in any animation.
- **Look and feel:** the whole game looks more fantasy (sky, particles, serif UI with gold trim, title screen); cards, skill buttons and weapons share one clean painted style; every skill and every weapon family has its own body animation; the armory shows the hero standing in the middle of a magic circle.

- **Decor variety in every map** (user: "make the flowers and stuff in every map have more variety ... all the maps decor"). Code: `Decor.gd` scatters flowers, grass, mushrooms, bushes, ferns, rocks, stumps, logs, bones, mounds, graves, pods, corals, cacti and gears on each map's ground (kinds and colour palettes per map in `Decor.SPECS` / `Decor.EXTRA`; shapes in `DecorMesh.gd`; shader `decor.gdshader` tints each instance); `MapLoader.VARIETY` gives every tree, rock, fern, crystal, kelp and cloud already in the map its own size, lean, turn and colour cast.
- **Better rocks** (user: "make rocks look better"): faceted stones with flat breaks, strata and dark feet, moss caps in green maps and snow caps in the frozen map, with small stones leaning on them.
- **Small animals** (user: "add some smol animals too"): `Critters.gd` and `CritterMesh.gd`; the list per map is in `Critters.SPECS`. Chess arena has none.

- **Capture the flag** (user: "add capture the flag"): third game mode next to Domination and Team Deathmatch. FlagNode.gd, Match.gd (`_make_flags`, `flag_captured`, `bot_goal`), Hud flag line and minimap flags; first team to 3 captures wins, the highest score wins at the end of the 10 minutes.
- **Leaderboard with kill/death ratio** (user: "a good leaderboard that tracks your kill death ratio instead of only deaths"): Game.record_match keeps the last 40 matches and your career; LeaderboardMenu.gd (title screen), K/D column in the scoreboard, K/D on the result screen.
- **Air drops** (user: "add the crates air drops"): AirDropNode.gd, one every 70-100 s.
- **Weapons per class** (user: "make the weapons from the character match the character not just a wand"): the equipped weapon is stored per class.
- **Title screen** (user): a panorama of the maps (MapPanorama.gd) and heroes that only idle.
- **Map borders** (user, asked several times): Border.gd plants the map's own props bigger beyond the play area; exposure is turned down on pale-ground maps.

## Open questions

0. How many armor sets and weapons are magic vs non-magic? Do magic classes and non-magic classes get different bonuses with each?
1. The skills each class owns, and what each class meter does.
2. Weapon types and stats for the 55 weapons; armor passive ideas.
3. The 6 rarity tiers, and whether a stacked card really climbs one rarity per copy.
4. XP from kills only, or also from assists and objectives?
5. Game modes (team deathmatch, capture the flag, domination, free-for-all, or something new)?
6. Underwater Ocean: do players walk on the sea floor or swim freely in 3D?
