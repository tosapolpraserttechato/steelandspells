// Copies each class's animation preview frames into previews/class_sheets/<id>/ and writes the sheet list (items.json).
const fs = require('fs');
const path = require('path');
const root = path.resolve(__dirname, '..');
const nice = { Idle: 'Idle', Run: 'Run', Sprint: 'Sprint', CastShoot: 'Cast', Attack: 'Attack', JumpLoop: 'Jump', Death: 'Death' };
const order = ['Idle', 'Run', 'Sprint', 'CastShoot', 'Attack', 'JumpLoop', 'Death'];
const ids = process.argv.slice(2);
for (const id of ids) {
  const src = path.join(root, 'anim', 'previews', id);
  const dst = path.join(root, 'previews', 'class_sheets', id);
  fs.mkdirSync(dst, { recursive: true });
  const files = fs.readdirSync(src).filter((f) => f.endsWith('.png'));
  const items = [];
  for (const clip of order) {
    for (const f of files.filter((f) => f.startsWith(`${id}_${clip}_`)).sort()) {
      fs.copyFileSync(path.join(src, f), path.join(dst, f));
      items.push({ file: f, title: `${nice[clip]} f${Number(f.match(/_(\d+)\.png/)[1])}`, sub: `${id.replace('_', ' ')}: rigged, CC0 clip`, source: 'Quaternius Universal Animation Library' });
    }
  }
  fs.writeFileSync(path.join(dst, 'items.json'), JSON.stringify(items, null, 1));
  console.log(id, items.length);
}
