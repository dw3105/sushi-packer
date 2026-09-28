#!/usr/bin/env python3
"""Mod logo: thumbnail.png (144x144, portal thumbnail, shipped) + portal/logo-512.png (README, GitHub).

Pure Python (no PIL on build VM). SUPERSEDED 2026-09-28 by tools/thumb_from_shot.py (in-game shot); do not run main(). Only mod's own box sprite; belts and items are drawn shapes, never base-game art.
Scene: mixed single items ride in on both lanes -> yellow sushi packer -> one-kind 4-stacks ride out, lanes kept.
Drawn at 1024 px, area-averaged down (anti-aliasing). Layout below in 144-px units.
"""
import struct
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BIG = 1024
K = BIG / 144  # 144-unit -> big px

BG = (36, 34, 32, 255)
BG_ALT = (44, 42, 39, 255)  # floor checker, Factoriopedia look
TILE = 24
BELT, BELT_EDGE, LANE_LINE, CHEVRON = (58, 56, 52, 255), (28, 27, 25, 255), (46, 44, 41, 255), (214, 164, 22, 150)
OUTLINE = (20, 18, 16, 255)
ITEMS = {  # (fill, highlight, shape)
    "iron": ((150, 160, 172, 255), (205, 212, 220, 255), "plate"),
    "copper": ((200, 104, 52, 255), (240, 160, 110, 255), "plate"),
    "coal": ((40, 40, 42, 255), (96, 96, 100, 255), "lump"),
    "circuit": ((52, 150, 60, 255), (150, 220, 120, 255), "chip"),
}
BELT_Y, BELT_H = 72, 52  # belt centre y, belt height (two lanes)
LANES = (BELT_Y - BELT_H / 4, BELT_Y + BELT_H / 4)
BOX = 100  # box sprite size, centred at (72, BELT_Y)


def decode(path):
    data = path.read_bytes()
    assert data[:8] == b"\x89PNG\r\n\x1a\n"
    pos, compressed = 8, bytearray()
    while pos < len(data):
        size = struct.unpack(">I", data[pos:pos + 4])[0]
        kind, payload = data[pos + 4:pos + 8], data[pos + 8:pos + 8 + size]
        pos += size + 12
        if kind == b"IHDR": width, height, depth, color, comp, filt, inter = struct.unpack(">IIBBBBB", payload)
        elif kind == b"IDAT": compressed.extend(payload)
        elif kind == b"IEND": break
    if (depth, color, comp, filt, inter) != (8, 6, 0, 0, 0): raise ValueError("expected 8-bit RGBA PNG")
    raw, stride, bpp = zlib.decompress(compressed), width * 4, 4
    rows, offset, previous = [], 0, bytearray(stride)
    for _ in range(height):
        ft = raw[offset]; offset += 1
        scan = bytearray(raw[offset:offset + stride]); offset += stride
        for i in range(stride):
            a = scan[i - bpp] if i >= bpp else 0
            b = previous[i]
            c = previous[i - bpp] if i >= bpp else 0
            if ft == 1: scan[i] = (scan[i] + a) & 255
            elif ft == 2: scan[i] = (scan[i] + b) & 255
            elif ft == 3: scan[i] = (scan[i] + ((a + b) // 2)) & 255
            elif ft == 4:
                p = a + b - c; pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                scan[i] = (scan[i] + (a if pa <= pb and pa <= pc else b if pb <= pc else c)) & 255
            elif ft != 0: raise ValueError("unsupported PNG filter")
        rows.append(scan); previous = scan
    return width, height, rows


def write_png(path, rows):
    def chunk(tag, payload):
        body = tag + payload
        return struct.pack(">I", len(payload)) + body + struct.pack(">I", zlib.crc32(body) & 0xffffffff)
    size = len(rows)
    raw = b"".join(b"\0" + bytes(row) for row in rows)
    data = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", size, size, 8, 6, 0, 0, 0))
    data += chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data)


def resize(rows, src_w, out):
    """Area-average square RGBA image src_w -> out (premultiplied, so transparent edges stay clean)."""
    result, scale = [], src_w / out
    for oy in range(out):
        y0, y1 = oy * scale, (oy + 1) * scale
        row = bytearray(out * 4)
        for ox in range(out):
            x0, x1 = ox * scale, (ox + 1) * scale
            r = g = b = a = area = 0.0
            for sy in range(int(y0), min(int(y1 + 0.999999), src_w)):
                wy = min(y1, sy + 1) - max(y0, sy)
                src = rows[sy]
                for sx in range(int(x0), min(int(x1 + 0.999999), src_w)):
                    w = wy * (min(x1, sx + 1) - max(x0, sx)); i = sx * 4
                    al = src[i + 3] * w
                    r += src[i] * al; g += src[i + 1] * al; b += src[i + 2] * al; a += al; area += w
            if a > 0: row[ox * 4:ox * 4 + 4] = bytes((round(r / a), round(g / a), round(b / a), round(a / area)))
        result.append(row)
    return result


class Canvas:
    def __init__(self, size, color):
        self.size = size
        self.rows = [bytearray(bytes(color) * size) for _ in range(size)]

    def blend(self, x, y, color):
        if 0 <= x < self.size and 0 <= y < self.size:
            row, i, al = self.rows[y], x * 4, color[3] / 255
            for c in range(3): row[i + c] = round(color[c] * al + row[i + c] * (1 - al))
            row[i + 3] = max(row[i + 3], color[3])

    def fill(self, inside, bbox, color):
        """Fill every big pixel whose centre (in 144 units) satisfies inside(x, y); bbox in 144 units."""
        x0, y0, x1, y1 = (max(0, int(v * K)) for v in bbox)
        for py in range(y0, min(self.size, int(y1 + 1))):
            for px in range(x0, min(self.size, int(x1 + 1))):
                if inside((px + 0.5) / K, (py + 0.5) / K): self.blend(px, py, color)

    def rect(self, x0, y0, x1, y1, color, radius=0.0):
        def inside(x, y):
            dx = max(x0 + radius - x, 0, x - (x1 - radius)); dy = max(y0 + radius - y, 0, y - (y1 - radius))
            return x0 <= x <= x1 and y0 <= y <= y1 and dx * dx + dy * dy <= radius * radius
        self.fill(inside, (x0, y0, x1, y1), color)

    def circle(self, cx, cy, r, color):
        self.fill(lambda x, y: (x - cx) ** 2 + (y - cy) ** 2 <= r * r, (cx - r, cy - r, cx + r, cy + r), color)

    def chevron(self, cx, cy, w, h, color):
        t = w * 0.45  # stroke thickness along x
        def inside(x, y):
            u = cx + w / 2 - x; v = abs(y - cy)  # tip on right: flow left -> right
            edge = v * (w / 2) / (h / 2)
            return v <= h / 2 and edge <= u <= edge + t
        self.fill(inside, (cx - w / 2, cy - h / 2, cx + w, cy + h / 2), color)

    def sprite(self, rows, src_w, cx, cy, size, alpha=1.0):
        out = round(size * K)
        small = resize(rows, src_w, out)
        ox, oy = round((cx - size / 2) * K), round((cy - size / 2) * K)
        for y in range(out):
            for x in range(out):
                i = x * 4; px = small[y][i:i + 4]
                if px[3]: self.blend(ox + x, oy + y, (px[0], px[1], px[2], round(px[3] * alpha)))


def item(canvas, kind, cx, cy, r=6.0):
    fill, light, shape = ITEMS[kind]
    if shape == "lump":
        canvas.circle(cx, cy, r + 0.9, OUTLINE); canvas.circle(cx, cy, r, fill)
        canvas.circle(cx - r * 0.35, cy - r * 0.35, r * 0.35, light)
    elif shape == "chip":
        canvas.rect(cx - r - 0.9, cy - r - 0.9, cx + r + 0.9, cy + r + 0.9, OUTLINE, 1.6)
        canvas.rect(cx - r, cy - r, cx + r, cy + r, fill, 1.2)
        for dy in (-0.45, 0.0, 0.45): canvas.rect(cx - r * 0.7, cy + dy * r - 0.45, cx + r * 0.7, cy + dy * r + 0.45, light)
    else:
        canvas.rect(cx - r - 0.9, cy - r * 0.8 - 0.9, cx + r + 0.9, cy + r * 0.8 + 0.9, OUTLINE, 2.0)
        canvas.rect(cx - r, cy - r * 0.8, cx + r, cy + r * 0.8, fill, 1.6)
        canvas.rect(cx - r * 0.75, cy - r * 0.6, cx + r * 0.2, cy - r * 0.25, light, 0.6)


def stack(canvas, kind, cx, cy):
    for n in range(4):  # back to front: 4 items = one belt stack
        item(canvas, kind, cx - 3.0 + n * 1.5, cy + 3.6 - n * 2.4, 5.8)


def draw():
    c = Canvas(BIG, BG)
    for ty in range(6):
        for tx in range(6):
            if (tx + ty) % 2: c.rect(tx * TILE, ty * TILE, (tx + 1) * TILE, (ty + 1) * TILE, BG_ALT)
    # belt: full width, two lanes, chevrons show flow left -> right
    c.rect(-1, BELT_Y - BELT_H / 2 - 1.5, 145, BELT_Y + BELT_H / 2 + 1.5, BELT_EDGE)
    c.rect(-1, BELT_Y - BELT_H / 2, 145, BELT_Y + BELT_H / 2, BELT)
    c.rect(-1, BELT_Y - 0.6, 145, BELT_Y + 0.6, LANE_LINE)
    for x in range(6, 144, 13):
        for y in LANES: c.chevron(x, y, 5.5, 11.0, CHEVRON)
    # in: mixed single items, each lane its own two kinds
    for i, x in enumerate((6, 19, 32)):
        item(c, ("iron", "copper")[i % 2], x, LANES[0])
        item(c, ("coal", "circuit")[(i + 1) % 2], x - 2, LANES[1])
    # out: one-kind 4-stacks, lanes kept
    for i, x in enumerate((114, 133)):
        stack(c, ("copper", "iron")[i], x, LANES[0])
        stack(c, ("circuit", "coal")[i], x - 2, LANES[1])
    # box: mod's own yellow sprite facing east, shadow first
    base = ROOT / "graphics/entity/sushi-packer/yellow"
    for name in ("sushi-packer-yellow-east-shadow.png", "sushi-packer-yellow-east.png"):
        w, h, rows = decode(base / name)
        if (w, h) != (128, 128): raise ValueError(f"unexpected sprite size {name} {w}x{h}")
        shadow = "shadow" in name
        c.sprite(rows, w, 72 + (2 if shadow else 0), BELT_Y, BOX, 0.45 if shadow else 1.0)
    return c.rows


def main():
    big = draw()
    write_png(ROOT / "portal/logo-512.png", resize(big, BIG, 512))
    write_png(ROOT / "thumbnail.png", resize(big, BIG, 144))


if __name__ == "__main__":
    main()
