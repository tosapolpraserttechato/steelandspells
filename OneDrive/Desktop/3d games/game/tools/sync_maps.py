"""Copy the finished map files (glb + markers.json) from ../maps into game/maps so Godot can import them.

  python tools/sync_maps.py
"""
import shutil
from pathlib import Path

here = Path(__file__).resolve().parent.parent
src_root = here.parent / "maps"
for folder in sorted(src_root.iterdir()):
    glb = folder / f"{folder.name}.glb"
    markers = folder / "markers.json"
    if folder.is_dir() and glb.exists() and markers.exists() and not folder.name.startswith("_"):
        dst = here / "maps" / folder.name
        dst.mkdir(parents=True, exist_ok=True)
        shutil.copy2(glb, dst / glb.name)
        shutil.copy2(markers, dst / markers.name)
        print("synced", folder.name)
