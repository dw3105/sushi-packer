#!/usr/bin/env python3
"""Mod thumbnail from real in-game screenshot (author 2026-09-28: "render in-game-realistic thumbnail").

Source: portal/thumb-shot.png, 1024x1024 RGBA, taken by author on laptop with game.take_screenshot (zoom 4) of
Factoriopedia scene (scripts/sim.lua) once stacks reached output belt. Crops square around box, area-averages to
thumbnail.png (144x144, portal thumbnail, shipped) and portal/logo-512.png (README, GitHub). Pure Python (no PIL).
Supersedes tools/logo.py main().
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from logo import ROOT, decode, resize, write_png  # noqa: E402

SHOT = ROOT / "portal/thumb-shot.png"
CX, CY, SIDE = 512, 495, 560  # box centre in shot (px), crop side: box + ~2 tiles belt each side


def main():
    width, height, rows = decode(SHOT)
    if (width, height) != (1024, 1024): raise ValueError(f"expected 1024x1024 shot, got {width}x{height}")
    x0, y0 = CX - SIDE // 2, CY - SIDE // 2
    crop = [row[x0 * 4:(x0 + SIDE) * 4] for row in rows[y0:y0 + SIDE]]
    write_png(ROOT / "portal/logo-512.png", resize(crop, SIDE, 512))
    write_png(ROOT / "thumbnail.png", resize(crop, SIDE, 144))


if __name__ == "__main__":
    main()
