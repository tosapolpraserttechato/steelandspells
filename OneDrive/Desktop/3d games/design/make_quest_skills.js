// Writes design/quest_skills.json and design/quest_skills.md from the table below.
// Run: node design/make_quest_skills.js
const fs = require('fs');
const path = require('path');

// Rarity rules (my proposal; Thirst for Blood is your example and sits at Epic: NPC 50 %, skill 20 %).
const RARITY = {
  common:    { npc: 90, reward: 70, count: 12 },
  uncommon:  { npc: 75, reward: 50, count: 11 },
  rare:      { npc: 60, reward: 35, count: 10 },
  epic:      { npc: 50, reward: 20, count: 8 },
  legendary: { npc: 35, reward: 12, count: 6 },
  mythic:    { npc: 20, reward: 6,  count: 3 },
};

// [name, rarity, quest, seconds (null = no limit), what the demo does, skill effect, cooldown seconds]
const S = [
  // ---- common (12)
  ['Quick Step', 'common', 'Sprint 300 m', 40, 'Dash 6 m forward, no cooldown during the quest', 'Dash 6 m forward', 8],
  ['Second Wind', 'common', 'Take 150 damage and stay alive', 30, 'Heal 20% health over 3 s, no cooldown', 'Heal 20% of max health over 3 s', 25],
  ['Sharp Eye', 'common', 'Land 8 hits in a row without a miss', 40, 'Enemies within 20 m glow for 4 s', 'Enemies within 20 m glow for 4 s', 20],
  ['Stone Skin', 'common', 'Survive 3 enemy hits with no healing', 20, 'Take 25% less damage for 4 s', 'Take 25% less damage for 4 s', 22],
  ['Light Feet', 'common', 'Jump 10 times while moving', 30, 'Double jump for 8 s', 'Double jump for 8 s', 30],
  ["Scavenger's Nose", 'common', 'Open 2 crates', 60, 'Crates and pickups within 40 m show through walls for 8 s', 'Crates and pickups within 40 m show through walls for 8 s', 30],
  ['Brave Heart', 'common', 'Stand on a capture point against 2 enemies', 15, 'Immune to slow and root for 5 s', 'Immune to slow and root for 5 s', 35],
  ['Quick Hands', 'common', 'Get 3 kills', 25, '+30% attack speed and reload speed for 5 s', '+30% attack speed and reload speed for 5 s', 30],
  ['Mana Spring', 'common', 'Use 5 different skills', 30, 'Restore 30% mana and take 2 s off your other cooldowns', 'Restore 30% mana and take 2 s off your other cooldowns', 40],
  ['Camp Fire', 'common', 'Stay unseen and moving', 20, 'A small fire: allies within 6 m regenerate 4 health per second for 8 s', 'A small fire: allies within 6 m regenerate 4 health per second for 8 s', 35],
  ['Trail Blazer', 'common', 'Use 3 jump pads', 60, 'Leave a glowing trail: allies on it get +15% speed for 6 s', 'Leave a glowing trail: allies on it get +15% speed for 6 s', 30],
  ['Bounty Hunter', 'common', 'Kill the enemy the NPC marks for you', 60, 'Mark an enemy: allies deal +15% damage to it for 8 s', 'Mark an enemy: allies deal +15% damage to it for 8 s', 25],
  // ---- uncommon (11)
  ['Shadow Step', 'uncommon', 'Kill 2 enemies from behind', 40, 'Blink 10 m forward', 'Blink 10 m forward', 18],
  ['Ricochet', 'uncommon', 'Get 5 kills with area or splash attacks', 60, 'Your next 3 attacks chain to a second target within 6 m', 'Your next 3 attacks chain to a second target within 6 m', 30],
  ['Iron Will', 'uncommon', 'Get 2 kills while under 50% health', 60, 'Below 30% health gain a 25% shield for 5 s (once per use)', 'Below 30% health gain a 25% shield for 5 s', 40],
  ['Battle Cry', 'uncommon', 'Capture a point with 3 allies near you', 45, 'Allies within 12 m get +10% speed and damage for 6 s', 'Allies within 12 m get +10% speed and damage for 6 s', 35],
  ['Smoke Bomb', 'uncommon', 'Break line of sight from 3 chasing enemies', 20, 'A 6 m smoke cloud for 6 s: enemies inside cannot see out, you move faster', 'A 6 m smoke cloud for 6 s: enemies inside cannot see out, you move faster', 30],
  ['Vampiric Touch', 'uncommon', 'Heal 100 health from kills', 45, 'For 6 s heal 25% of the damage you deal', 'For 6 s heal 25% of the damage you deal', 35],
  ['Grapple Line', 'uncommon', 'Get 2 kills from the high ground', 60, 'Grapple to a ledge or a player within 25 m', 'Grapple to a ledge or a player within 25 m', 20],
  ['Mirror Shield', 'uncommon', 'Take 5 projectile hits', 30, 'Reflect the next projectile within 3 s back at its shooter', 'Reflect the next projectile within 3 s back at its shooter', 25],
  ['Pathfinder', 'uncommon', 'Reach all 3 capture points', 90, 'See enemy footprints within 20 m for 10 s', 'See enemy footprints within 20 m for 10 s', 25],
  ['Overcharge', 'uncommon', 'Fill your class meter 2 times', 90, 'Your class meter fills 50% faster for 10 s', 'Your class meter fills 50% faster for 10 s', 45],
  ['Lucky Coin', 'uncommon', 'Open 3 crates', 90, 'The next crate you open rolls one rarity higher', 'The next crate you open rolls one rarity higher (once per life)', 0],
  // ---- rare (10)
  ['Rushing Gale', 'rare', 'Cover 500 m using jump pads', 45, '+40% speed for 5 s and slide through enemies without being blocked', '+40% speed for 5 s and slide through enemies', 30],
  ['Cleanse the Land', 'rare', 'Get rid of 5 status effects on yourself', 60, 'Remove all debuffs from you and allies within 8 m, then 2 s immunity', 'Remove all debuffs from you and allies within 8 m, then 2 s immunity', 35],
  ['Dead Reckoning', 'rare', 'Land 5 critical hits', 45, 'Your next attack is a guaranteed critical hit', 'Your next attack is a guaranteed critical hit', 25],
  ['Phase Cloak', 'rare', 'Stay unseen for 40 s in total and get 1 kill', 90, 'Invisible for 4 s; attacking breaks it', 'Invisible for 4 s; attacking breaks it', 40],
  ['Earth Tremor', 'rare', 'Stun or slow 6 enemies', 40, 'An 8 m tremor: slow 40% and knock enemies down for 1 s', 'An 8 m tremor: slow 40% and knock enemies down for 1 s', 35],
  ['Static Field', 'rare', 'Deal 600 damage with area attacks', 45, 'A 5 m field round you for 6 s that deals 15 damage per second', 'A 5 m field round you for 6 s that deals 15 damage per second', 35],
  ['Guardian Angel', 'rare', 'Heal or shield an ally 2 times', 60, 'Wrap the nearest ally in a 150 health barrier for 6 s', 'Wrap the nearest ally in a 150 health barrier for 6 s', 40],
  ['Gravity Well', 'rare', 'Pull or knock back 4 enemies', 60, 'Pull enemies within 8 m toward a point for 1.5 s', 'Pull enemies within 8 m toward a point for 1.5 s', 40],
  ['Eagle Vision', 'rare', 'Keep 10 different enemies in sight', 40, 'See every enemy within 40 m through walls for 5 s', 'See every enemy within 40 m through walls for 5 s', 45],
  ['Last Stand', 'rare', 'Survive at under 20% health', 20, 'For 6 s you cannot drop below 1 health and deal +30% damage', 'For 6 s you cannot drop below 1 health and deal +30% damage', 60],
  // ---- epic (8)
  ['Thirst for Blood', 'epic', 'ONESHOT 10 enemies (kill each with a single hit)', 45, 'You get the real skill to use during the quest', 'X-ray for 10 s: you see every enemy through walls; click an x-rayed enemy to teleport behind them', 45],
  ['Time Skip', 'epic', 'Get 5 kills', 30, 'Return to where you were, with the health you had, 4 s ago', 'Return to your position and health from 4 s ago', 50],
  ['Soul Siphon', 'epic', 'Get 3 kills with the same skill', 60, 'For 10 s each kill heals 15% health and takes 10% off your cooldowns', 'For 10 s each kill heals 15% health and takes 10% off your cooldowns', 45],
  ['Mirror Image', 'epic', 'Get 6 kills without dying', 60, 'Two illusions copy you for 8 s and deal 40% damage', 'Two illusions copy you for 8 s and deal 40% damage', 45],
  ['Storm Step', 'epic', 'Chain 3 kills, each within 8 s of the last', 40, 'Dash 12 m, stunning everyone along the path', 'Dash 12 m, stunning everyone along the path', 35],
  ['Fortress', 'epic', 'Hold a contested capture point', 45, 'A 6 m dome for 6 s that blocks projectiles for allies inside', 'A 6 m dome for 6 s that blocks projectiles for allies inside', 55],
  ["Hunter's Mark", 'epic', 'Kill the enemy with the most kills (the NPC names them)', 90, 'Mark an enemy: it is revealed and takes 25% more damage for 10 s', 'Mark an enemy: it is revealed and takes 25% more damage for 10 s; if it dies, your cooldown resets', 45],
  ['Warp Strike', 'epic', 'Get 3 kills right after dashing or teleporting', 45, 'Throw yourself at a target within 20 m for 150 area damage', 'Throw yourself at a target within 20 m for 150 area damage', 35],
  // ---- legendary (6)
  ['Phoenix Rebirth', 'legendary', 'Win 3 duels while under 30% health, in one life', null, 'Revive once with 50% health after 2 s', 'Once per life, revive with 50% health after 2 s', 120],
  ['Sky Hunter', 'legendary', 'Get 5 kills from the high ground', 60, 'Glide for 6 s; attacks from above deal +30%', 'Glide for 6 s; attacks from above deal +30%', 50],
  ['Dominion', 'legendary', 'Capture 2 points', 90, 'For 12 s you capture twice as fast and allies inside get +20% damage', 'For 12 s you capture twice as fast and allies on your point get +20% damage', 60],
  ['Blood Moon', 'legendary', 'Deal 2000 damage', 45, 'For 12 s: 30% lifesteal, +25% damage, low-health enemies glow', 'For 12 s: 30% lifesteal, +25% damage, low-health enemies glow', 70],
  ['Void Walker', 'legendary', 'Stay alive in the enemy half', 90, 'Walk through walls and obstacles for 3 s', 'Walk through walls and obstacles for 3 s', 60],
  ['Colossus', 'legendary', 'Absorb 1500 damage with shields or armor', 60, 'Grow 40% bigger with +50% max health; enemies you touch are knocked back, for 10 s', 'Grow 40% bigger with +50% max health; enemies you touch are knocked back, for 10 s', 75],
  // ---- mythic (3)
  ['Time Lord', 'mythic', 'Get 12 kills', 60, 'Slow every enemy within 25 m by 60% for 6 s while you move normally', 'Slow every enemy within 25 m by 60% for 6 s while you move normally', 90],
  ["Reaper's Contract", 'mythic', 'Kill 10 enemies without dying or taking damage', 90, 'For 10 s enemies below 20% health within 15 m die instantly (once every 6 s)', 'For 10 s enemies below 20% health within 15 m die instantly (once every 6 s)', 100],
  ['World Breaker', 'mythic', 'Destroy 3 crates, win 3 duels and capture 1 point', 120, 'A 10 m slam: 300 damage, launches enemies, cracks the ground for 5 s', 'A 10 m slam: 300 damage, launches enemies, cracks the ground for 5 s', 110],
];

const slug = (n) => n.toLowerCase().replace(/[^a-z0-9]+/g, '_').replace(/^_|_$/g, '');
const out = S.map(([name, rarity, quest, secs, demo, effect, cd], i) => ({
  id: slug(name), number: i + 1, name, rarity,
  npc_appear_chance_percent: RARITY[rarity].npc,
  reward_chance_percent: RARITY[rarity].reward,
  quest, quest_time_limit_seconds: secs, demo, effect, cooldown_seconds: cd,
}));

// checks
const counts = {};
out.forEach((s) => { counts[s.rarity] = (counts[s.rarity] || 0) + 1; });
for (const [r, v] of Object.entries(RARITY)) if (counts[r] !== v.count) throw new Error(`rarity ${r}: ${counts[r]} != ${v.count}`);
if (out.length !== 50) throw new Error('need 50 skills, have ' + out.length);
// Thirst for Blood must match the user's example exactly
const tfb = out.find((s) => s.id === 'thirst_for_blood');
if (tfb.npc_appear_chance_percent !== 50 || tfb.reward_chance_percent !== 20 || tfb.quest_time_limit_seconds !== 45) throw new Error('Thirst for Blood no longer matches the example');

fs.writeFileSync(path.join(__dirname, 'quest_skills.json'), JSON.stringify(out, null, 1));

const cap = (s) => s[0].toUpperCase() + s.slice(1);
let md = `# Quest skills (50)

*Added 2026-10-21 from your message. **Thirst for Blood is your example, written exactly as you gave it.** The other 49 are my proposals for you to confirm or swap, in the same way as the cards.*

## How a quest skill works

1. A **quest NPC** appears on the map (a chance per match; rarer skills have a lower chance). Talk to it to start the quest.
2. You get a **demo of the skill** to help you finish the quest.
3. Finish the quest (usually inside a **time limit**) and you get **a chance** to receive the skill (rarer skills have a lower chance). You can try again when the NPC appears again.
4. Quest skills are **good for every class**: they are not tied to a class and do not get the own-class buff.
5. **50 skills in the same 6 rarities** as cards and crates (common to mythic).

*To confirm:* how many quest skills you can equip *(proposal: 1 slot, chosen before a match)*, whether you keep them between matches *(proposal: yes)*, and what a duplicate does *(proposal: nothing, or it raises the rarity of your copy, like cards)*.

## Rarity rules (proposal)

| Rarity | Skills | NPC appears | Skill awarded after the quest |
|---|---|---|---|
`;
for (const [r, v] of Object.entries(RARITY)) md += `| ${cap(r)} | ${v.count} | ${v.npc}% | ${v.reward}% |\n`;
md += '\nThirst for Blood is **Epic**: the NPC appears 50% of the time and you get the skill 20% of the time, as in your example.\n\n';
let cur = '';
for (const s of out) {
  if (s.rarity !== cur) { cur = s.rarity; md += `## ${cap(cur)} (${RARITY[cur].count})\n\n| # | Skill | Quest | Time | Demo during the quest | The skill | Cooldown |\n|---|---|---|---|---|---|---|\n`; }
  md += `| ${s.number} | **${s.name}** | ${s.quest} | ${s.quest_time_limit_seconds ? s.quest_time_limit_seconds + ' s' : 'none'} | ${s.demo} | ${s.effect} | ${s.cooldown_seconds ? s.cooldown_seconds + ' s' : 'once per life'} |\n`;
  const next = out[s.number];
  if (!next || next.rarity !== cur) md += '\n';
}
fs.writeFileSync(path.join(__dirname, 'quest_skills.md'), md);
console.log('wrote', out.length, 'quest skills', JSON.stringify(counts));
