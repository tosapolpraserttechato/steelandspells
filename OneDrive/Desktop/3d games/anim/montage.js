// Put several pictures side by side into one HTML sheet list for the helper page: node montage.js <dir> <out_dir_name> file1 file2 ...
const fs = require('fs');
const path = require('path');
const [dir, ...files] = process.argv.slice(2);
const items = files.map((f) => ({ file: f, title: f.replace('.png', ''), sub: '', source: '' }));
fs.writeFileSync(path.join(dir, 'items.json'), JSON.stringify(items, null, 1));
console.log(items.length, 'items in', dir);
