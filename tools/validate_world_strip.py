#!/usr/bin/env python3
"""Validate a world Native Seed and, optionally, its Alpha strip."""

from __future__ import annotations

import argparse
from pathlib import Path
import sys

from PIL import Image


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--native-seed", type=Path, required=True)
    parser.add_argument("--strip", type=Path)
    parser.add_argument("--frames", type=int, default=9)
    parser.add_argument("--frame-size", type=int, default=64)
    parser.add_argument("--min-width", type=int, default=28)
    parser.add_argument("--max-width", type=int, default=40)
    parser.add_argument("--min-height", type=int, default=58)
    parser.add_argument("--max-height", type=int, default=64)
    parser.add_argument(
        "--key-color",
        default="FF00FF",
        help="forbidden visible chroma-key color as six-digit RGB hex (default: FF00FF)",
    )
    return parser.parse_args()


def fail(message: str) -> None:
    print(f"FAIL: {message}", file=sys.stderr)
    raise SystemExit(1)


def parse_key_color(value: str) -> tuple[int, int, int]:
    text = value.removeprefix("#")
    if len(text) != 6:
        fail("key-color must be a six-digit RGB hex value")
    try:
        return tuple(int(text[index : index + 2], 16) for index in (0, 2, 4))
    except ValueError:
        fail("key-color must be a six-digit RGB hex value")


def validate_frame(
    image: Image.Image,
    label: str,
    key_color: tuple[int, int, int],
    args: argparse.Namespace,
) -> tuple[int, int, int, int]:
    rgba = image.convert("RGBA")
    pixels = list(rgba.getdata())
    if any(alpha not in (0, 255) for _, _, _, alpha in pixels):
        fail(f"{label} contains semi-transparent pixels; production world art requires alpha 0/255")
    if any(alpha == 0 and (red, green, blue) != (0, 0, 0) for red, green, blue, alpha in pixels):
        fail(f"{label} contains RGB residue in fully transparent pixels")
    if any(alpha > 0 and (red, green, blue) == key_color for red, green, blue, alpha in pixels):
        fail(f"{label} contains visible key-color pixels")

    bbox = rgba.getchannel("A").getbbox()
    if bbox is None:
        fail(f"{label} is fully transparent")
    width = bbox[2] - bbox[0]
    height = bbox[3] - bbox[1]
    if not args.min_width <= width <= args.max_width:
        fail(f"{label} visible width is {width}px, expected {args.min_width}..{args.max_width}px")
    if not args.min_height <= height <= args.max_height:
        fail(f"{label} visible height is {height}px, expected {args.min_height}..{args.max_height}px")
    if bbox[3] != args.frame_size:
        fail(f"{label} lowest opaque pixel is y={bbox[3] - 1}, expected y={args.frame_size - 1}")
    return bbox


def main() -> None:
    args = parse_args()
    if args.frames < 1 or args.frame_size < 1:
        fail("frames and frame-size must be positive")
    if not 1 <= args.min_width <= args.max_width <= args.frame_size:
        fail("width bounds must be positive, ordered, and within frame-size")
    if not 1 <= args.min_height <= args.max_height <= args.frame_size:
        fail("height bounds must be positive, ordered, and within frame-size")

    try:
        seed = Image.open(args.native_seed).convert("RGBA")
        strip = Image.open(args.strip).convert("RGBA") if args.strip else None
    except (OSError, ValueError) as error:
        fail(str(error))

    expected_seed_size = (args.frame_size, args.frame_size)
    if seed.size != expected_seed_size:
        fail(
            f"native seed is {seed.size}, expected {expected_seed_size}; "
            "high-resolution references are not Native Seeds"
        )

    key_color = parse_key_color(args.key_color)
    seed_bbox = validate_frame(seed, "native seed", key_color, args)

    if strip is None:
        print(f"PASS: seed={seed.size}, bbox={seed_bbox}, alpha=binary, footline=locked")
        return

    expected_strip_size = (args.frame_size * args.frames, args.frame_size)
    if strip.size != expected_strip_size:
        fail(f"strip is {strip.size}, expected {expected_strip_size}")

    frames = []
    for index in range(args.frames):
        frame = strip.crop(
            (index * args.frame_size, 0, (index + 1) * args.frame_size, args.frame_size)
        )
        validate_frame(frame, f"strip frame {index}", key_color, args)
        frames.append(frame)
    if seed.tobytes() != frames[0].tobytes():
        fail("strip frame 0 is not pixel-identical to the approved Native Seed")

    print(
        f"PASS: seed={seed.size}, strip={strip.size}, frames={args.frames}, "
        "alpha=binary, residue=0, footline=locked, frame0=pixel-identical"
    )


if __name__ == "__main__":
    main()
