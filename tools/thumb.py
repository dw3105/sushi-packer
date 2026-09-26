#!/usr/bin/env python3
"""Build the 144x144 portal thumbnail from the mod's four existing tier sprites."""
import struct
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TIERS = ("yellow", "red", "blue", "turbo")


def decode(path):
    data = path.read_bytes()
    assert data[:8] == b"\x89PNG\r\n\x1a\n"
    pos, compressed = 8, bytearray()
    width = height = depth = color = None
    while pos < len(data):
        size = struct.unpack(">I", data[pos:pos+4])[0]
        kind, payload = data[pos+4:pos+8], data[pos+8:pos+8+size]
        pos += size + 12
        if kind == b"IHDR": width, height, depth, color, comp, filt, inter = struct.unpack(">IIBBBBB", payload)
        elif kind == b"IDAT": compressed.extend(payload)
        elif kind == b"IEND": break
    if (depth, color, comp, filt, inter) != (8, 6, 0, 0, 0):
        raise ValueError("expected non-interlaced 8-bit RGBA PNG")
    raw = zlib.decompress(compressed)
    stride, bpp = width * 4, 4
    rows, offset, previous = [], 0, bytearray(width * 4)
    for _ in range(height):
        ft = raw[offset]; offset += 1
        scan = bytearray(raw[offset:offset+stride]); offset += stride
        for i in range(stride):
            a = scan[i-bpp] if i >= bpp else 0
            b = previous[i]
            c = previous[i-bpp] if i >= bpp else 0
            if ft == 1: scan[i] = (scan[i] + a) & 255
            elif ft == 2: scan[i] = (scan[i] + b) & 255
            elif ft == 3: scan[i] = (scan[i] + ((a+b)//2)) & 255
            elif ft == 4:
                p = a+b-c; pa, pb, pc = abs(p-a), abs(p-b), abs(p-c)
                scan[i] = (scan[i] + (a if pa <= pb and pa <= pc else b if pb <= pc else c)) & 255
            elif ft != 0: raise ValueError("unsupported PNG filter")
        rows.append(scan); previous = scan
    return width, height, rows


def resize_area(rows, out=72):
    src = len(rows)
    result = []
    for oy in range(out):
        y0, y1 = oy * src / out, (oy + 1) * src / out
        row = bytearray(out * 4)
        for ox in range(out):
            x0, x1 = ox * src / out, (ox + 1) * src / out
            sums = [0.0] * 4; area = 0.0
            for sy in range(int(y0), min(int(y1 + 0.999999), src)):
                wy = max(0.0, min(y1, sy+1) - max(y0, sy))
                for sx in range(int(x0), min(int(x1 + 0.999999), src)):
                    wx = max(0.0, min(x1, sx+1) - max(x0, sx)); w = wx * wy
                    area += w
                    for c in range(4): sums[c] += rows[sy][sx*4+c] * w
            for c in range(4): row[ox*4+c] = round(sums[c] / area)
        result.append(row)
    return result


def png(path, rows):
    def chunk(tag, payload):
        body = tag + payload
        return struct.pack(">I", len(payload)) + body + struct.pack(">I", zlib.crc32(body) & 0xffffffff)
    raw = b"".join(b"\0" + bytes(row) for row in rows)
    data = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", 144, 144, 8, 6, 0, 0, 0))
    data += chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")
    path.write_bytes(data)


canvas = [bytearray(144 * 4) for _ in range(144)]
for i, tier in enumerate(TIERS):
    w, h, source = decode(ROOT / "graphics/entity/sushi-packer" / tier / f"sushi-packer-{tier}-north.png")
    if (w, h) != (128, 128): raise ValueError(f"unexpected sprite size: {tier} {w}x{h}")
    small = resize_area(source)
    ox, oy = (i % 2) * 72, (i // 2) * 72
    for y in range(72): canvas[oy+y][ox*4:(ox+72)*4] = small[y]
png(ROOT / "thumbnail.png", canvas)
