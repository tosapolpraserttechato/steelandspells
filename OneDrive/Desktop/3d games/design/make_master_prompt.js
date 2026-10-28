// Builds design/ALL_FEATURES_PROMPT.md: the one big prompt with every feature.
//   node design/make_master_prompt.js
// Sources: design/master_prompt_main.md (hand-written), design/cards.md, design/quest_skills.md,
//          game/tools/data_classes.py and data_basic.py (classes, skills, status effects; read with Blender's Python).
const fs = require("fs");
const path = require("path");
const { execFileSync } = require("child_process");

const root = path.resolve(__dirname, "..");
const py = "C:/Program Files/Blender Foundation/Blender 5.2/5.2/python/bin/python.exe";
const dump = `
import sys, json
sys.path.insert(0, ${JSON.stringify(path.join(root, "game", "tools"))})
import data_classes as d, data_basic as b
sk = {s["id"]: s for s in d.SKILLS}
out = {"classes": [], "statuses": b.STATUSES}
for c in d.CLASSES:
    out["classes"].append({"name": c["name"], "home": c["home_map"], "magic": c["magic"], "health": c["health"], "mana": c["mana"],
        "passive": c["passive"]["name"] + ": " + c["passive"]["desc"], "meter": c["meter"]["name"] + ": " + c["meter"]["desc"],
        "skills": [[sk[s]["name"], sk[s]["desc"], sk[s]["cooldown"]] for s in c["skills"]],
        "signature": [sk[c["signature"]]["name"], sk[c["signature"]]["desc"], sk[c["signature"]]["cooldown"]],
        "ultimate": [sk[c["ultimate"]]["name"], sk[c["ultimate"]]["desc"]], "blurb": c["blurb"]})
print(json.dumps(out))
`;
const data = JSON.parse(execFileSync(py, ["-I", "-c", dump], { encoding: "utf8", maxBuffer: 1 << 26 }));

const rename = { Pharaoh: "Pharaoh (becomes Desert Assassin; redo)", "GM Levy": "GM Levy (becomes GM Ravn; ultimate becomes the Queen Sacrifice)" };
let classes = "";
for (const c of data.classes) {
  classes += `**${rename[c.name] || c.name}** (${c.magic ? "magic" : "non-magic"}, home map ${c.home.replace(/_/g, " ")}, health ${c.health}, mana ${c.mana}): ${c.blurb}\n`;
  classes += `- Passive: ${c.passive}\n- Class meter: ${c.meter}\n`;
  classes += `- Skills: ${c.skills.map((s) => `**${s[0]}** (${s[2]} s: ${s[1]})`).join("; ")}\n`;
  classes += `- Signature (area attack): **${c.signature[0]}** (${c.signature[2]} s: ${c.signature[1]})\n- Ultimate: **${c.ultimate[0]}** (${c.ultimate[1]})\n\n`;
}

let statuses = "| Effect | Kind | Duration | Stacks | What it does | Typical source |\n|---|---|---|---|---|---|\n";
for (const s of data.statuses) {
  statuses += `| **${s.name}** | ${s.harmful ? "harmful" : "helpful"} | ${s.duration} s | ${s.max_stacks} | ${s.desc} | ${s.symbol} icon |\n`;
}

const cardsMd = fs.readFileSync(path.join(__dirname, "cards.md"), "utf8");
const cards = cardsMd.slice(cardsMd.indexOf("## Common"));
const questMd = fs.readFileSync(path.join(__dirname, "quest_skills.md"), "utf8");
const quest = questMd.slice(questMd.indexOf("## Rarity rules"));

let main = fs.readFileSync(path.join(__dirname, "master_prompt_main.md"), "utf8");
main = main.replace("<<CLASSES>>", () => classes.trim()).replace("<<STATUSES>>", () => statuses.trim())
  .replace("<<CARDS>>", () => cards.trim()).replace("<<QUEST>>", () => quest.trim());
const out = path.join(__dirname, "ALL_FEATURES_PROMPT.md");
fs.writeFileSync(out, main, "utf8");
console.log("wrote", out, main.length, "characters,", main.split("\n").length, "lines");
