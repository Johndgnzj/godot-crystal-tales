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
            render = meta_file.parent / "final.png"   # 實尺寸疊圖用：final.png 像素尺寸＝canvas_px
            if not render.is_file():
                render = preview
            items.append({
                "id": item_id,
                "type": item_type,
                "footprint": footprint,
                "canvas_px": canvas_px,
                "anchor": meta.get("anchor", "bottom_center"),
                # 顯示用旗標（真相源＝素材庫 meta.json，GDScript 也直接讀那份，不寫進 map-def）
                "layer": str(meta.get("layer", "object")),        # "ground"＝平貼地面、build_scenes.gd 掛 GroundProps
                "walkable": meta.get("walkable", False) is True,  # True＝踩得過去、blueprint_to_paths.gd 不生碰撞
                "preview": str(preview.relative_to(assets_root)).replace("\\", "/"),
                "render": str(render.relative_to(assets_root)).replace("\\", "/"),
            })
        except (OSError, ValueError, KeyError, TypeError):
            continue
    return items
