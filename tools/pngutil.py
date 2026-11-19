"""Tiny dependency-free PNG writer (streams rows, so 4096x4096 images are fine)."""
import struct
import zlib


def _chunk(f, tag, data):
    f.write(struct.pack(">I", len(data)) + tag + data)
    f.write(struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF))


def write_png(path, width, height, color_type, bit_depth, rows, level=6):
    """rows: iterable of `height` raw scanlines (bytes, no filter byte).
    color_type: 0 gray, 2 RGB, 6 RGBA."""
    comp = zlib.compressobj(level)
    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n")
        _chunk(f, b"IHDR", struct.pack(">IIBBBBB", width, height, bit_depth, color_type, 0, 0, 0))
        buf = bytearray()
        for row in rows:
            buf += b"\x00" + row
            if len(buf) > (1 << 20):
                data = comp.compress(bytes(buf))
                buf.clear()
                if data:
                    _chunk(f, b"IDAT", data)
        data = comp.compress(bytes(buf)) + comp.flush()
        if data:
            _chunk(f, b"IDAT", data)
        _chunk(f, b"IEND", b"")
