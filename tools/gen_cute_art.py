#!/usr/bin/env python3
"""Cute placeholder sprites (playtest 2: "design all items, power-ups, enemies, bosses to be cute").

Chibi style: round bodies, big shiny eyes, blush, pastel colours, clockwork wind-up keys
(they're still robot mice), and a dark outline around every silhouette for readability.
Painted procedurally with simple shapes so it's easy to tweak; run after tools/gen_art.py
(it overwrites the same file names):   python3 tools/gen_cute_art.py
Enemies face LEFT (they fly in from the right). Replace any PNG with real art any time.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from gen_art import write_png_rgba, OUT  # noqa: E402

INK = (52, 34, 72, 255)          # outline
EYE = (40, 26, 58, 255)
WHITE = (255, 255, 255, 255)
PINK = (255, 150, 185, 255)
PINK_D = (230, 100, 150, 255)
BLUSH = (255, 170, 195, 255)
LILAC = (214, 206, 240, 255)
LILAC_L = (238, 234, 252, 255)
PEACH = (255, 214, 178, 255)
PEACH_L = (255, 236, 214, 255)
MINT = (176, 236, 214, 255)
MINT_L = (218, 250, 236, 255)
SKY = (170, 205, 255, 255)
SKY_L = (214, 232, 255, 255)
STEEL = (150, 160, 190, 255)
GOLD = (255, 214, 90, 255)
GOLD_D = (226, 170, 50, 255)
ORANGE = (255, 160, 80, 255)
RED = (255, 90, 110, 255)
GREEN = (120, 220, 130, 255)
GREEN_D = (70, 170, 95, 255)
CREAM = (255, 244, 200, 255)
MAGENTA = (220, 110, 200, 255)
MAGENTA_D = (170, 70, 160, 255)
GREY = (196, 184, 204, 255)
GREY_L = (226, 218, 232, 255)
CYAN = (140, 235, 255, 255)
GLASS = (190, 240, 255, 255)


class Canvas:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.px = [[None] * w for _ in range(h)]

    def set(self, x, y, c):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.px[y][x] = c

    def ellipse(self, cx, cy, rx, ry, c):
        for y in range(self.h):
            for x in range(self.w):
                dx, dy = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
                if dx * dx + dy * dy <= 1.0:
                    self.px[y][x] = c

    def rect(self, x0, y0, x1, y1, c):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.set(x, y, c)

    def poly(self, pts, c):
        for y in range(self.h):
            for x in range(self.w):
                px, py = x + 0.5, y + 0.5
                inside = False
                j = len(pts) - 1
                for i in range(len(pts)):
                    xi, yi = pts[i]
                    xj, yj = pts[j]
                    if (yi > py) != (yj > py) and px < (xj - xi) * (py - yi) / (yj - yi) + xi:
                        inside = not inside
                    j = i
                if inside:
                    self.px[y][x] = c

    def line(self, x0, y0, x1, y1, c):
        n = max(abs(x1 - x0), abs(y1 - y0), 1)
        for i in range(n + 1):
            self.set(round(x0 + (x1 - x0) * i / n), round(y0 + (y1 - y0) * i / n), c)

    def outline(self, c=INK):
        add = []
        for y in range(self.h):
            for x in range(self.w):
                if self.px[y][x] is None:
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        nx, ny = x + dx, y + dy
                        if 0 <= nx < self.w and 0 <= ny < self.h and self.px[ny][nx] not in (None, c):
                            add.append((x, y))
                            break
        for x, y in add:
            self.px[y][x] = c

    def eye(self, x, y, tall=2):
        """Big shiny eye: dark oval with a white highlight (x, y = top-left)."""
        self.rect(x, y, x + 1, y + tall, EYE)
        self.set(x, y, WHITE)

    def save(self, name):
        rows = [[c if c else (0, 0, 0, 0) for c in row] for row in self.px]
        write_png_rgba(os.path.join(OUT, name), rows)


def wind_key(c, x, y):
    """Clockwork wind-up key (they're robot mice)."""
    c.rect(x, y, x, y + 2, GOLD_D)
    c.rect(x + 1, y - 1, x + 2, y, GOLD)
    c.rect(x + 1, y + 2, x + 2, y + 3, GOLD)


def mouse(name, body, belly, w=24, h=19, accessory=None, stretch=1.0):
    c = Canvas(w, h)
    # tail (behind)
    c.line(w - 4, 13, w - 2, 11, PINK_D)
    c.line(w - 2, 11, w - 2, 9, PINK_D)
    c.ellipse(13, 11.5, 7.5 * stretch, 5.5, body)          # body
    c.ellipse(12, 13.5, 4.5 * stretch, 2.6, belly)         # belly
    c.ellipse(10, 3.6, 3.0, 3.0, body)                     # back ear
    c.ellipse(10, 3.6, 1.7, 1.7, PINK)
    c.ellipse(7.5, 8.5, 5.6, 5.0, body)                    # head
    c.ellipse(4.5, 3.4, 2.8, 2.8, body)                    # front ear
    c.ellipse(4.5, 3.4, 1.5, 1.5, PINK)
    c.set(1, 9, PINK_D)                                    # nose
    c.set(2, 9, PINK)
    c.eye(5, 6, 2)
    c.set(7, 10, BLUSH)
    c.set(8, 10, BLUSH)
    c.rect(8, 16, 9, 16, PINK_D)                           # feet
    c.rect(15, 16, 16, 16, PINK_D)
    if accessory:
        accessory(c)
    c.outline()
    c.save(name)


def gunner_bits(c):
    # orange cork popgun held in front + a tiny party hat
    c.rect(0, 12, 4, 13, ORANGE)
    c.set(0, 12, CREAM)
    c.set(0, 13, CREAM)
    c.poly([(6, 2), (9, 2), (7.5, -1)], RED)
    c.set(7, 0, GOLD)
    wind_key(c, 20, 6)


def grunt_bits(c):
    wind_key(c, 20, 6)


def dasher_bits(c):
    # racing goggles and a fluttering scarf
    c.rect(3, 6, 8, 6, GOLD_D)
    c.rect(4, 5, 6, 8, (255, 240, 140, 255))
    c.set(5, 6, EYE)
    c.set(5, 7, EYE)
    c.set(4, 5, WHITE)
    c.rect(10, 12, 14, 13, RED)
    c.line(14, 12, 18, 10, RED)
    c.line(14, 13, 19, 12, RED)


def shield_bits(c):
    # little knight helmet
    c.ellipse(8, 5.5, 5.2, 3.4, STEEL)
    c.rect(4, 5, 12, 5, (190, 200, 225, 255))
    c.set(9, 2, RED)
    c.set(10, 1, RED)
    c.eye(5, 7, 1)
    wind_key(c, 20, 6)


def plate():
    # a round pot-lid shield with a heart
    c = Canvas(7, 11)
    c.ellipse(3.5, 5.5, 3.0, 5.0, SKY)
    c.ellipse(3.5, 5.5, 2.0, 4.0, SKY_L)
    for x, y in ((2, 4), (4, 4), (2, 5), (3, 5), (4, 5), (3, 6)):
        c.set(x, y, PINK_D)
    c.outline()
    c.save("shield_plate.png")


def tank():
    c = Canvas(32, 20)
    c.rect(0, 10, 7, 12, STEEL)                            # cannon
    c.ellipse(1.0, 11.0, 1.6, 2.2, PINK)                   # cannon ring
    c.ellipse(17, 16.5, 13, 3.2, (120, 110, 150, 255))     # treads
    for x in (8, 13, 18, 23, 27):
        c.ellipse(x, 16.5, 1.8, 1.8, GREY_L)
    c.ellipse(17, 12, 11, 4.2, MINT)                       # hull
    c.ellipse(17, 11, 8, 2.2, MINT_L)
    c.ellipse(23, 3.2, 2.8, 2.8, GREY)                     # back ear
    c.ellipse(23, 3.2, 1.5, 1.5, PINK)
    c.ellipse(18, 6.5, 6.0, 4.8, GREY)                     # mouse head peeking out
    c.ellipse(14, 2.6, 2.6, 2.6, GREY)                     # front ear
    c.ellipse(14, 2.6, 1.4, 1.4, PINK)
    c.set(12, 7, PINK_D)
    c.eye(15, 4, 2)
    c.set(17, 8, BLUSH)
    c.set(18, 8, BLUSH)
    c.rect(20, 9, 29, 9, GOLD)                             # hatch rim
    for x in (11, 17, 23):
        c.set(x, 13, (255, 255, 255, 255))                 # rivets
    c.outline()
    c.save("boss_tank.png")


def mothership():
    c = Canvas(36, 18)
    c.ellipse(18, 6.5, 8, 6, GLASS)                        # glass dome
    c.ellipse(14.5, 4, 2.2, 2.2, GREY)                     # pilot mouse ears
    c.ellipse(14.5, 4, 1.2, 1.2, PINK)
    c.ellipse(20, 4, 2.2, 2.2, GREY)
    c.ellipse(20, 4, 1.2, 1.2, PINK)
    c.ellipse(17, 8, 4.2, 3.5, GREY)                       # pilot head
    c.eye(15, 6, 2)
    c.set(13, 9, PINK_D)
    c.set(17, 9, BLUSH)
    c.set(21, 3, WHITE)                                    # dome shine
    c.set(22, 4, WHITE)
    c.ellipse(18, 12, 17, 4.5, GOLD)                       # cheese saucer
    c.ellipse(18, 11, 14, 2.0, CREAM)
    for x, y in ((6, 12), (12, 14), (24, 14), (29, 12), (18, 13)):
        c.ellipse(x, y, 1.4, 1.0, GOLD_D)                  # cheese holes
    for x in (8, 14, 22, 28):
        c.set(x, 16, PINK)                                 # lights
    c.outline()
    c.save("boss_mothership.png")


def rat_king():
    c = Canvas(28, 24)
    c.line(23, 19, 26, 16, PINK_D)                         # tail
    c.line(26, 16, 26, 13, PINK_D)
    c.ellipse(16, 16, 10, 7, MAGENTA)                      # cape
    c.ellipse(16, 15, 7, 2.5, MAGENTA_D)
    c.ellipse(14, 16, 8, 6.5, GREY)                        # chubby body
    c.ellipse(13, 18, 5, 3.5, GREY_L)                      # belly
    c.ellipse(14, 7.5, 3.2, 3.2, GREY)                     # back ear
    c.ellipse(14, 7.5, 1.8, 1.8, PINK)
    c.ellipse(9, 11, 6.5, 5.5, GREY)                       # head
    c.ellipse(5.5, 6.5, 3.0, 3.0, GREY)                    # front ear
    c.ellipse(5.5, 6.5, 1.6, 1.6, PINK)
    # crown with jewels
    c.rect(6, 3, 12, 5, GOLD)
    for x in (6, 9, 12):
        c.set(x, 1, GOLD)
        c.set(x, 2, GOLD)
    c.set(7, 4, RED)
    c.set(9, 4, CYAN)
    c.set(11, 4, RED)
    c.set(2, 12, PINK_D)                                   # nose
    c.set(3, 12, PINK)
    c.eye(6, 9, 2)
    c.line(3, 14, 6, 13, EYE)                              # royal moustache
    c.set(9, 13, BLUSH)
    c.set(10, 13, BLUSH)
    c.rect(10, 22, 11, 22, PINK_D)                         # feet
    c.rect(17, 22, 18, 22, PINK_D)
    c.outline()
    c.save("boss_rat_king.png")


def cheese():
    # a chunky smiling cheese wedge
    c = Canvas(13, 11)
    c.poly([(0, 10.5), (12.5, 10.5), (12.5, 1.5), (0, 5.5)], GOLD)
    c.poly([(0, 5.5), (12.5, 1.5), (12.5, 3.2), (0, 6.6)], CREAM)   # top face
    c.ellipse(10.5, 8.5, 1.1, 1.1, GOLD_D)
    c.ellipse(2.5, 9.0, 0.9, 0.9, GOLD_D)
    c.set(5, 7, EYE)                                       # happy face
    c.set(8, 7, EYE)
    c.set(6, 9, PINK_D)
    c.set(7, 9, PINK_D)
    c.set(4, 8, BLUSH)
    c.set(9, 8, BLUSH)
    c.outline()
    c.save("cheese.png")


def battery():
    c = Canvas(9, 13)
    c.rect(3, 0, 5, 1, GREY_L)
    c.rect(1, 2, 7, 11, GREEN)
    c.rect(1, 2, 7, 3, GREEN_D)
    c.set(3, 6, EYE)                                       # face
    c.set(5, 6, EYE)
    c.set(4, 8, PINK_D)
    c.set(2, 7, BLUSH)
    c.set(6, 7, BLUSH)
    c.outline()
    c.save("battery.png")


def yarn():
    c = Canvas(12, 12)
    c.ellipse(5.5, 5.5, 5.0, 5.0, PINK)
    c.line(2, 3, 8, 9, PINK_D)
    c.line(3, 2, 9, 8, PINK_D)
    c.line(2, 7, 6, 3, (255, 200, 220, 255))
    c.line(9, 9, 11, 11, PINK_D)                           # loose strand
    c.set(4, 4, WHITE)
    c.outline()
    c.save("yarn.png")


def enemy_shot():
    # a hot-pink candy bubble with a white core: cute but very visible
    c = Canvas(8, 8)
    c.ellipse(4, 4, 3.5, 3.5, (255, 80, 160, 255))
    c.ellipse(4, 4, 2.0, 2.0, (255, 200, 230, 255))
    c.set(3, 3, WHITE)
    c.outline((120, 20, 80, 255))
    c.save("enemy_shot.png")


def player_shot():
    # a little star of yarn-light
    c = Canvas(10, 6)
    c.ellipse(5, 3, 4.5, 2.2, CYAN)
    c.ellipse(5.5, 3, 2.5, 1.2, WHITE)
    c.save("player_shot.png")


def laser_shot():
    c = Canvas(16, 4)
    c.rect(0, 1, 15, 2, RED)
    c.rect(2, 1, 15, 1, (255, 200, 210, 255))
    c.ellipse(14, 2, 2, 2, (255, 60, 90, 255))             # the laser-pointer dot
    c.set(14, 1, WHITE)
    c.save("shot_laser.png")


def fish_shot():
    # swims to the right (the shot rotates to its velocity): tail left, head right
    c = Canvas(11, 7)
    c.poly([(3.2, 3.5), (0.2, 0.5), (0.2, 6.5)], ORANGE)   # tail
    c.ellipse(6.5, 3.5, 4.2, 2.6, ORANGE)
    c.set(8, 2, EYE)
    c.set(5, 4, (255, 210, 150, 255))
    c.outline()
    c.save("shot_fish.png")


def main():
    mouse("grunt.png", LILAC, LILAC_L, accessory=grunt_bits)
    mouse("gunner.png", PEACH, PEACH_L, accessory=gunner_bits)
    mouse("dasher.png", MINT, MINT_L, w=26, h=19, accessory=dasher_bits, stretch=1.2)
    mouse("shield_mouse.png", SKY, SKY_L, accessory=shield_bits)
    plate()
    tank()
    mothership()
    rat_king()
    cheese()
    battery()
    yarn()
    enemy_shot()
    player_shot()
    laser_shot()
    fish_shot()
    print("wrote cute sprites to", os.path.normpath(OUT))


if __name__ == "__main__":
    main()
