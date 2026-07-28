"""已核可 WorldProps 的素材源掃描（地圖工具與 Hub 共用）。"""

import json
from pathlib import Path


def prop_catalog(assets_root: Path):
    root = assets_root / "props" / "world"
    items = []
    if not root.is_dir():
        return items
    for meta_file in sorted(root.glob("*/*/*/meta.json")):
        try:
            meta = json.loads(meta_file.read_text("utf-8"))
            item_id = meta["id"]
            item_type = meta["type"]
            footprint = meta["footprint"]
            canvas_px = meta["canvas_px"]
            if (not isinstance(footprint, list) or len(footprint) != 2 or
                    not all(isinstance(v, int) and v > 0 for v in footprint) or
                    not isinstance(canvas_px, list) or len(canvas_px) != 2):
                continue
            preview = meta_file.parent / "design_anchor_alpha.png"
            if not preview.is_file():
                preview = meta_file.parent / "final.png"
            if not preview.is_file():
                continue
            items.append({
                "id": item_id,
                "type": item_type,
                "footprint": footprint,
                "canvas_px": canvas_px,
                "anchor": meta.get("anchor", "bottom_center"),
                "preview": str(preview.relative_to(assets_root)).replace("\\", "/"),
            })
        except (OSError, ValueError, KeyError, TypeError):
            continue
    return items
