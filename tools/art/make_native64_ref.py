#!/usr/bin/env python3
"""舊產線的 64px layout diagnostic；v3.0 正式流程已停用。

此工具會縮放高解析圖，因此輸出不是 v3 D2 Pixel Art Reference、D3 Native Seed 或 strip source。
只允許為既有 2026-08-14 素材重現歷史 layout diagnostic；新素材不得使用。

同一組角色必須共用一個 global scale，才留得住彼此的身高差；scale 由 --group-height（對應到滿格
cell 高度的原圖內容 px）決定，省略時取本次輸入裡最高的那張。單獨重出某角色時務必補上同組的
--group-height，否則會被單獨拉滿 64 高而與同伴不同比例。

用法：
    python3 tools/art/make_native64_ref.py --legacy <src...> [--cell 64] [--sharpen 40] [--group-height 824]
"""

import argparse
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

ALPHA_FLOOR = 24  # 低於此值視為邊緣殘影，不列入 bbox


def content_crop(src: Path) -> Image.Image:
    im = Image.open(src).convert("RGBA")
    ys, xs = np.where(np.array(im)[:, :, 3] > ALPHA_FLOOR)
    if len(xs) == 0:
        raise ValueError(f"{src}: 全透明，找不到角色像素")
    return im.crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))


def build_ref(src: Path, cell: int, sharpen: int, group_height: int) -> tuple[Path, Path]:
    crop = content_crop(src)

    scale = cell / group_height
    target_w, target_h = max(1, round(crop.width * scale)), max(1, round(crop.height * scale))
    if target_w > cell:
        raise ValueError(f"{src}: 縮放後寬 {target_w}px 超出 {cell}px cell，需改用更寬的 cell")

    # premultiply alpha 再縮，避免透明邊被平均進來產生黑／白 halo
    arr = np.array(crop).astype(np.float64)
    arr[:, :, :3] *= arr[:, :, 3:4] / 255.0
    small = Image.fromarray(arr.round().clip(0, 255).astype(np.uint8), "RGBA").resize(
        (target_w, target_h), Image.LANCZOS
    )
    s = np.array(small).astype(np.float64)
    sa = s[:, :, 3:4] / 255.0
    s[:, :, :3] = np.where(sa > 0, s[:, :, :3] / np.maximum(sa, 1e-6), 0)
    small = Image.fromarray(s.round().clip(0, 255).astype(np.uint8), "RGBA")

    if sharpen > 0:
        rgb = small.convert("RGB").filter(
            ImageFilter.UnsharpMask(radius=1.0, percent=sharpen, threshold=2)
        )
        small = Image.merge("RGBA", (*rgb.split(), small.split()[3]))

    canvas = Image.new("RGBA", (cell, cell), (0, 0, 0, 0))  # bottom-center anchor，腳底貼齊 cell 底
    canvas.paste(small, ((cell - target_w) // 2, cell - target_h))
    out = src.with_name(src.stem.replace("_alpha", "") + f"_native{cell}_ref.png")
    canvas.save(out)

    # 驗收圖：原圖等比參考 | 原生 1x | 8x nearest
    zoom = canvas.resize((cell * 8, cell * 8), Image.NEAREST)
    ref = crop.copy()
    ref.thumbnail((cell * 8, cell * 8), Image.LANCZOS)
    prev = Image.new(
        "RGBA", (ref.width + 16 + cell + 16 + zoom.width, zoom.height), (30, 30, 34, 255)
    )
    prev.alpha_composite(ref, (0, zoom.height - ref.height))
    prev.alpha_composite(canvas, (ref.width + 16, zoom.height - cell))
    prev.alpha_composite(zoom, (ref.width + 16 + cell + 16, 0))
    prev_path = out.with_name(out.stem + "_preview.png")
    prev.save(prev_path)
    return out, prev_path


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument(
        "--legacy",
        action="store_true",
        help="確認只重現舊 layout diagnostic；v3 正式素材不可使用",
    )
    ap.add_argument("sources", nargs="+", type=Path, help="高解析 seed（透明去背版）")
    ap.add_argument("--cell", type=int, default=64, help="目標 cell 邊長，預設 64")
    ap.add_argument("--sharpen", type=int, default=40, help="UnsharpMask percent，0 為不銳化，預設 40")
    ap.add_argument(
        "--group-height",
        type=int,
        default=0,
        help="對應滿格 cell 高度的原圖內容 px（同組共用的 global scale）；省略時取本次輸入的最大值",
    )
    args = ap.parse_args()
    if not args.legacy:
        print(
            "[STOP] v3 世界立繪流程禁止由高解析圖自動縮成 D2／D3；"
            "只有重現歷史 diagnostic 時可加 --legacy。",
            file=sys.stderr,
        )
        return 2

    group_height = args.group_height
    if group_height <= 0:
        heights = []
        for src in args.sources:
            try:
                heights.append(content_crop(src).height)
            except (OSError, ValueError) as exc:
                print(f"[FAIL] {src}: {exc}", file=sys.stderr)
                return 1
        group_height = max(heights)
    print(f"global scale 基準：group-height={group_height}px → {args.cell}px")

    failed = False
    for src in args.sources:
        try:
            out, prev = build_ref(src, args.cell, args.sharpen, group_height)
        except (OSError, ValueError) as exc:
            print(f"[FAIL] {src}: {exc}", file=sys.stderr)
            failed = True
            continue
        print(f"[OK] {out}\n     {prev}")
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
