"""依 assets-source/map/map-def.xlsx 的 M2、M3 連通格合成地圖總覽。"""

from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]


def compose(folder: str, prefix: str, cell: int, columns: int, rows: int,
		placements: dict[str, tuple[int, int]]) -> None:
	directory = ROOT / "assets-source" / "map" / folder
	canvas = Image.new("RGB", (columns * cell, rows * cell), (45, 47, 46))
	for suffix, (x, y) in placements.items():
		source = Image.open(directory / f"{prefix}-{suffix}.png").convert("RGB")
		source = source.resize((cell, cell), Image.Resampling.LANCZOS)
		canvas.paste(source, (x * cell, y * cell))
	output = directory / f"{prefix}-map.png"
	canvas.save(output, optimize=True)
	print(f"{output.relative_to(ROOT)}: {canvas.size[0]}x{canvas.size[1]}")


compose(
	"M2-north-mine", "north-mine", 320, 4, 2,
	{"a": (0, 1), "b": (1, 1), "c": (2, 1), "d": (1, 0), "e": (2, 0), "f-boss-room": (3, 0)},
)
compose(
	"M3-east-forest", "east-forest", 251, 4, 5,
	{
		"a": (0, 2), "e": (1, 2), "b": (2, 2), "g": (3, 2),
		"h": (2, 1), "i": (2, 0), "f": (1, 3), "c": (2, 3),
		"d-boss-room": (2, 4),
	},
)
