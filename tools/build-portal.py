#!/usr/bin/env python3
"""Builds mod portal packages.

  python3 tools/build-portal.py            -> dist/FreightForwarding-continued_<version>.zip
                                              dist/IntermodalContainers-continued_<version>.zip
  python3 tools/build-portal.py --original -> dist/FreightForwarding_<version>.zip (internal name unchanged)

The repository keeps the mod as "FreightForwarding" (so diffs against the original stay readable). The portal build
renames it to "FreightForwarding-continued": the name "FreightForwarding" on the mod portal belongs to its author.
Prototype names (ff-*) don't change, so blueprints keep working; a save made with the original mod loses the mod's
script data when switched to the continued one (the map and buildings are kept).
"""
import json, os, re, shutil, sys, zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DIST = ROOT / "dist"
CONTINUED = "FreightForwarding-continued"
SKIP = {".github", ".gitignore", ".git"}
TEXT = {".lua", ".json", ".cfg", ".txt", ".md"}


def build(src: Path, name: str, transform=None):
    info = json.loads((src / "info.json").read_text(encoding="utf-8"))
    version = info["version"]
    folder = f"{name}_{version}"
    target = DIST / f"{folder}.zip"
    DIST.mkdir(exist_ok=True)
    with zipfile.ZipFile(target, "w", zipfile.ZIP_DEFLATED) as z:
        for path in sorted(src.rglob("*")):
            rel = path.relative_to(src)
            if any(part in SKIP for part in rel.parts) or path.is_dir():
                continue
            data = path.read_bytes()
            if transform and rel.as_posix() == "thumbnail.png" and (ROOT / "tools" / "thumbnail-continued.png").exists():
                data = (ROOT / "tools" / "thumbnail-continued.png").read_bytes()
            if transform and path.suffix in TEXT:
                data = transform(rel, data.decode("utf-8")).encode("utf-8")
            z.writestr(f"{folder}/{rel.as_posix()}", data)
    print(target.relative_to(ROOT))


def continued(rel, text):
    text = text.replace("__FreightForwarding__", f"__{CONTINUED}__")
    if rel.as_posix() == "info.json":
        info = json.loads(text)
        info["name"] = CONTINUED
        info["title"] = "Freight Forwarding (continued)"
        info["author"] = "Xorimuth; continued by GemMaxweLlX"
        info["homepage"] = "https://github.com/GemMaxweLlX/Svasf"
        info["source"] = "https://github.com/GemMaxweLlX/Svasf/tree/main/FreightForwarding"
        info["description"] = ("Freight Forwarding for Factorio 2.1 and Space Age, continued. " + info["description"]
                               + "\nWith Space Age: rocket tiers, planet supply chains, container tiers, ships and trains "
                               "per planet, and interstellar freight contracts as the goal. A classic mode keeps the "
                               "original 1.x game.")
        deps = [d for d in info["dependencies"] if d not in ("? IntermodalContainers",)]
        deps.append("! FreightForwarding")
        info["dependencies"] = deps
        text = json.dumps(info, indent=2, ensure_ascii=False)
    if rel.as_posix() == "compatibility/milestones/presets.lua":
        text = text.replace('"FreightForwarding"', f'"{CONTINUED}"')
    return text


if __name__ == "__main__":
    if "--original" in sys.argv:
        build(ROOT / "FreightForwarding", "FreightForwarding")
    else:
        build(ROOT / "FreightForwarding", CONTINUED, continued)
    build(ROOT / "IntermodalContainers-continued", "IntermodalContainers-continued")
