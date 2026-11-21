#!/usr/bin/env python3
"""Generates the placeholder pixel art in Art/Generated/.

Each sprite is drawn as ASCII below (one character per pixel, see PALETTE), so it's easy to
tweak by hand. Run from the project root:  python3 tools/gen_art.py
Replace any output PNG with real art of similar size; the game scales sprites itself.
"""
import os
import struct
import zlib

OUT = os.path.join(os.path.dirname(__file__), "..", "Art", "Generated")

PALETTE = {
    ".": (0, 0, 0, 0),
    "K": (27, 24, 42, 255),     # outline
    "D": (88, 96, 112, 255),    # dark metal
    "G": (138, 148, 166, 255),  # metal
    "L": (197, 204, 216, 255),  # light metal
    "W": (255, 255, 255, 255),
    "P": (242, 155, 178, 255),  # pink
    "R": (255, 59, 59, 255),    # red
    "O": (255, 140, 40, 255),   # orange
    "Y": (255, 210, 63, 255),   # yellow
    "y": (214, 160, 30, 255),   # dark yellow
    "C": (110, 230, 255, 255),  # cyan
    "B": (60, 120, 255, 255),   # blue
    "N": (80, 220, 110, 255),   # green
    "n": (40, 150, 70, 255),    # dark green
    "M": (230, 90, 190, 255),   # magenta
    "m": (160, 50, 130, 255),   # dark magenta
}

SPRITES = {
    # robot mouse grunt, facing left (nose on the left)
    "grunt.png": """
        .......KKK..........
        ......KPPPK.........
        ......KPPPK..KKK....
        .......KKKKKKLLLK...
        ....KKKLLLLLLLLLGK..
        ..KKLLRLLLLLLLLLGGK.
        .KWLLLLLLLLLLLLLGGK.
        KKLLLLLLLLLLLLLGGGK.
        .KKDDLLLLLLLLGGGGK..
        ...KKDDDDDDDDDGGK.KK
        .....KKYKKKKYKKK.K.K
        ......KYK...KYK..KK.
        .......K.....K......
    """,
    # gunner: heavier dark-metal mouse with an orange cannon on its nose
    "gunner.png": """
        .......KKK...........
        ......KPPPK..........
        ......KPPPK...KKK....
        .......KKKKKKKDDDK...
        ..KKKKKDDDDDDDDDDGK..
        KKOOOKKDDRDDDDDDDGGK.
        KOOOOOKDDDDDDDDDDGGK.
        KKOOOKKDDDDDDDDDGGGK.
        ..KKKKKKDDDDDDDGGGK..
        .....KKDDDDDDDDGGK.KK
        ......KKYKKKKYKKK.K.K
        .......KYK...KYK..KK.
        ........K.....K......
    """,
    # dasher: sleek racing mouse with a red stripe and a jet flame at the back
    "dasher.png": """
        .........KKK...........
        ........KPPK...........
        .....KKKKKKKKKKKK......
        ...KKLLLLLLLLLLLLKKOO..
        .KKWRLLLLRRRRRRLLLKYOO.
        KKLLLLLLLLLLLLLLLLKOYO.
        .KKLLLLLLLLLLLLLLKKOO..
        ...KKKKKKKKKKKKKKK.....
    """,
    # the shield mouse carries this plate in front of it
    "shield_plate.png": """
        .KKK.
        KBBBK
        KBCBK
        KBCBK
        KBBBK
        KBCBK
        KBCBK
        KBBBK
        .KKK.
    """,
    "player_shot.png": """
        ..CCCCCC..
        .CWWWWWWC.
        .CWWWWWWC.
        ..CCCCCC..
    """,
    "enemy_shot.png": """
        .OOOO.
        ORRRRO
        ORYYRO
        ORYYRO
        ORRRRO
        .OOOO.
    """,
    "cheese.png": """
        ......KK.
        ....KKYYK
        ..KKYYyYK
        KKYYyYYYK
        KYYYYYyYK
        KYyYYYYYK
        KKKKKKKKK
    """,
    "battery.png": """
        ..KKK..
        .KLLLK.
        KKKKKKK
        KNNNNNK
        KNnNNNK
        KNNNNNK
        KNNnNNK
        KNNNNNK
        KnNNNNK
        KNNNNNK
        KKKKKKK
    """,
    "yarn.png": """
        ...KKK...
        .KKMMMKK.
        .KMmMMMK.
        KMMMmMMMK
        KMmMMmMMK
        KMMmMMmMK
        .KMMMmMK.
        .KKMMMKKK
        ...KKK..K
    """,
    "crosshair.png": """
        ......WWW......
        ......W.W......
        ......W.W......
        ...............
        ...............
        ...............
        WWW.........WWW
        W.W....W....W.W
        WWW.........WWW
        ...............
        ...............
        ...............
        ......W.W......
        ......W.W......
        ......WWW......
    """,
}


def write_png(path, rows):
    h, w = len(rows), len(rows[0])
    raw = b"".join(b"\x00" + bytes(c for ch in row for c in PALETTE[ch]) for row in rows)

    def chunk(tag, data):
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(raw)) + chunk(b"IEND", b"")
    with open(path, "wb") as f:
        f.write(png)


def main():
    os.makedirs(OUT, exist_ok=True)
    for name, art in SPRITES.items():
        rows = [line.strip() for line in art.strip().splitlines()]
        width = max(len(r) for r in rows)
        rows = [r.ljust(width, ".") for r in rows]
        write_png(os.path.join(OUT, name), rows)
    print("wrote %d sprites to %s" % (len(SPRITES), os.path.normpath(OUT)))


if __name__ == "__main__":
    main()
