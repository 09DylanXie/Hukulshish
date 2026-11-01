#!/usr/bin/env python3
"""Draws the game's generated terrain art into assets/.

Standard library only, and deterministic like generate_sfx.py.

    python tools/generate_art.py         # regenerate everything
    python tools/generate_art.py tree_1  # regenerate one image

After regenerating, open the project in Godot (or run it with --import).
"""

import argparse
import math
import random
import struct
import sys
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TILESETS = ROOT / "assets" / "tilesets"
WORLD = ROOT / "assets" / "sprites" / "world"
BOSSES = ROOT / "assets" / "sprites" / "bosses"
SPELLS = ROOT / "assets" / "sprites" / "spells"
UI = ROOT / "assets" / "sprites" / "ui"
OUTLINE = (14, 16, 18, 255)

ART = {}


def art(name, folder):
	"""Registers a recipe. Recipes receive a seeded rng and return an Image."""
	def register(fn):
		ART[name] = (fn, folder)
		return fn
	return register


class Image:
	def __init__(self, width, height):
		self.width = width
		self.height = height
		self.pixels = [(0, 0, 0, 0)] * (width * height)

	def get(self, x, y):
		return self.pixels[y * self.width + x]

	def set(self, x, y, color):
		if 0 <= x < self.width and 0 <= y < self.height:
			self.pixels[y * self.width + x] = color

	def wrapped(self, x, y, color):
		"""Draws across the edges, so tiles repeat without seams."""
		self.pixels[(y % self.height) * self.width + (x % self.width)] = color

	def fill(self, color):
		self.pixels = [color] * (self.width * self.height)

	def outline(self):
		"""Adds the black pixel outline every sprite in the game has."""
		edges = []
		for y in range(self.height):
			for x in range(self.width):
				if self.get(x, y)[3] != 0:
					continue
				for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
					nx, ny = x + dx, y + dy
					if 0 <= nx < self.width and 0 <= ny < self.height and self.get(nx, ny)[3] != 0:
						edges.append((x, y))
						break
		for x, y in edges:
			self.set(x, y, OUTLINE)

	def save(self, path):
		rows = bytearray()
		for y in range(self.height):
			rows.append(0)
			for pixel in self.pixels[y * self.width:(y + 1) * self.width]:
				rows.extend(pixel)
		def chunk(tag, data):
			body = tag + data
			return struct.pack(">I", len(data)) + body + struct.pack(">I", zlib.crc32(body))
		header = struct.pack(">IIBBBBB", self.width, self.height, 8, 6, 0, 0, 0)
		path.write_bytes(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", header)
			+ chunk(b"IDAT", zlib.compress(bytes(rows), 9)) + chunk(b"IEND", b""))


def shade(ramp, value):
	"""Picks a color from a dark-to-light ramp, with value in 0..1."""
	return ramp[max(0, min(len(ramp) - 1, int(value * len(ramp))))]


def blob(image, cx, cy, rx, ry, ramp, rng, grain=0.1):
	"""A lumpy ball lit from the top left, which is how the castle and mine are lit."""
	for y in range(int(cy - ry), int(cy + ry) + 1):
		for x in range(int(cx - rx), int(cx + rx) + 1):
			dx = (x - cx) / rx
			dy = (y - cy) / ry
			if dx * dx + dy * dy > 1.0:
				continue
			light = 0.56 - 0.42 * dx * 0.6 - 0.42 * dy + rng.uniform(-grain, grain)
			image.set(x, y, shade(ramp, light))


def wave_noise(x, y, size, waves):
	"""Sum of sine waves that repeat every `size` pixels, for seamless tiles."""
	total = 0.0
	for fx, fy, phase, weight in waves:
		total += weight * math.sin(math.tau * (fx * x + fy * y) / size + phase)
	return total


def random_waves(rng, count):
	waves = []
	for i in range(count):
		weight = 1.0 / (1.0 + i * 0.5)
		waves.append((rng.randint(-4, 4), rng.randint(1, 5), rng.uniform(0.0, math.tau), weight))
	return waves


# --- Palettes ---

LEAVES = [(18, 66, 30, 255), (28, 96, 36, 255), (44, 130, 44, 255), (72, 166, 52, 255), (120, 198, 70, 255)]
PINE = [(12, 54, 42, 255), (18, 76, 54, 255), (28, 102, 66, 255), (48, 130, 76, 255)]
BARK = [(52, 34, 24, 255), (78, 52, 32, 255), (104, 72, 44, 255)]
STONE = [(62, 66, 74, 255), (88, 94, 102, 255), (118, 124, 130, 255), (156, 162, 164, 255)]
MOSS = [(58, 110, 46, 255), (86, 142, 54, 255)]
BUSH = [(24, 92, 44, 255), (40, 124, 52, 255), (66, 156, 62, 255), (104, 186, 76, 255)]
GRASS = [(62, 158, 58, 255), (72, 172, 62, 255), (84, 186, 66, 255), (98, 198, 72, 255)]
WATER = [(34, 110, 170, 255), (42, 128, 188, 255), (54, 148, 204, 255), (90, 178, 222, 255)]


# --- Sprites ---

def trunk(image, cx, top, bottom, half_width, rng):
	for y in range(top, bottom):
		flare = 2 if y >= bottom - 3 else 0
		for x in range(cx - half_width - flare, cx + half_width + flare + 1):
			side = (x - cx + half_width) / (2.0 * half_width + 1.0)
			image.set(x, y, shade(BARK, 0.9 - side * 0.8 + rng.uniform(-0.12, 0.12)))


@art("tree_1", WORLD)
def tree_round(rng):
	image = Image(64, 80)
	trunk(image, 32, 44, 77, 5, rng)
	blobs = [(32, 46, 22, 15), (17, 38, 13, 12), (47, 38, 13, 12), (32, 26, 21, 18), (20, 21, 11, 10), (43, 20, 12, 11)]
	for cx, cy, rx, ry in blobs:
		blob(image, cx, cy, rx, ry, LEAVES, rng, 0.12)
	image.outline()
	return image


@art("tree_2", WORLD)
def tree_pine(rng):
	image = Image(56, 80)
	trunk(image, 28, 62, 77, 4, rng)
	for top, bottom, half_width in ((44, 68, 25), (26, 52, 20), (10, 36, 15), (3, 20, 9)):
		for y in range(top, bottom):
			reach = half_width * (y - top + 2) / (bottom - top)
			for x in range(int(28 - reach), int(28 + reach) + 1):
				side = (x - 28) / max(1.0, reach)
				light = 0.62 - 0.45 * side - 0.3 * (y - top) / (bottom - top)
				image.set(x, y, shade(PINE, light + rng.uniform(-0.1, 0.1)))
	image.outline()
	return image


def rock(rng, width, height, lumps):
	image = Image(width, height)
	for cx, cy, rx, ry in lumps:
		blob(image, cx, cy, rx, ry, STONE, rng, 0.07)
	for _ in range(width):
		x = rng.randint(0, width - 1)
		y = rng.randint(0, height // 2)
		if image.get(x, y)[3] != 0:
			image.set(x, y, rng.choice(MOSS))
	image.outline()
	return image


@art("rock_1", WORLD)
def rock_large(rng):
	return rock(rng, 42, 34, [(21, 20, 18, 12), (14, 15, 10, 9), (28, 13, 11, 10)])


@art("rock_2", WORLD)
def rock_small(rng):
	return rock(rng, 36, 28, [(15, 17, 13, 9), (25, 19, 9, 7)])


@art("bush_1", WORLD)
def bush(rng):
	image = Image(30, 24)
	for cx, cy, rx, ry in ((15, 14, 12, 8), (9, 12, 7, 7), (21, 12, 7, 7)):
		blob(image, cx, cy, rx, ry, BUSH, rng, 0.12)
	for _ in range(5):
		image.set(rng.randint(7, 23), rng.randint(6, 16), (232, 92, 110, 255))
	image.outline()
	return image


STALL_ICONS = {
	"stall_spell": ((86, 170, 255, 255), "star"),
	"stall_mods": ((236, 222, 176, 255), "scroll"),
	"stall_augmentations": ((240, 70, 96, 255), "gem"),
	"stall_personal": ((88, 226, 120, 255), "gem"),
	"stall_gold": ((250, 206, 66, 255), "coin"),
}
AWNINGS = {
	"stall_spell": ((44, 92, 176, 255), (214, 226, 240, 255)),
	"stall_mods": ((60, 136, 150, 255), (226, 232, 214, 255)),
	"stall_augmentations": ((162, 44, 66, 255), (240, 214, 214, 255)),
	"stall_personal": ((46, 130, 74, 255), (222, 238, 214, 255)),
	"stall_gold": ((176, 124, 28, 255), (246, 232, 192, 255)),
}
WOOD = [(70, 44, 26, 255), (102, 68, 38, 255), (134, 92, 52, 255)]


def stall(name, rng):
	"""A market stall: posts, a counter, a striped awning, and an icon of what it sells."""
	image = Image(60, 58)
	for x in (9, 48):
		for y in range(20, 54):
			for i in range(3):
				image.set(x + i, y, shade(WOOD, 0.8 - i * 0.3))
	for y in range(36, 54):
		for x in range(7, 53):
			board = 1.0 if (y - 36) % 6 == 0 else 0.0
			image.set(x, y, shade(WOOD, 0.62 - board * 0.4 - (y - 36) * 0.012 + rng.uniform(-0.05, 0.05)))
	for x in range(5, 55):
		image.set(x, 36, WOOD[2])
		image.set(x, 37, WOOD[2])
	first, second = AWNINGS[name]
	for y in range(8, 24):
		lean = (24 - y) // 3
		for x in range(3 + lean, 57 - lean):
			image.set(x, y, first if (x - 3) // 6 % 2 == 0 else second)
	for x in range(3, 57):
		if (x - 3) % 6 < 4:
			image.set(x, 24, first if (x - 3) // 6 % 2 == 0 else second)
	color, icon = STALL_ICONS[name]
	cx, cy = 30, 30
	if icon == "coin":
		blob(image, cx, cy, 5, 5, [(176, 124, 28, 255), color, (255, 240, 150, 255)], rng, 0.0)
	elif icon == "scroll":
		for y in range(cy - 5, cy + 5):
			for x in range(cx - 6, cx + 7):
				image.set(x, y, color)
		for y in range(cy - 6, cy + 6):
			image.set(cx - 7, y, (150, 120, 80, 255))
			image.set(cx + 7, y, (150, 120, 80, 255))
		for y in (cy - 2, cy + 1):
			for x in range(cx - 4, cx + 5):
				image.set(x, y, (120, 96, 70, 255))
	elif icon == "star":
		for i in range(-6, 7):
			reach = (6 - abs(i)) // 2
			for j in range(-reach, reach + 1):
				image.set(cx + i, cy + j, color)
				image.set(cx + j, cy + i, color)
	else:
		for y in range(-6, 7):
			for x in range(-(6 - abs(y)), 7 - abs(y)):
				image.set(cx + x, cy + y, color if x + y < 2 else tuple(c // 2 + 40 for c in color[:3]) + (255,))
	image.outline()
	return image


def register_stalls():
	for name in STALL_ICONS:
		ART[name] = ((lambda stall_name: lambda rng: stall(stall_name, rng))(name), WORLD)


register_stalls()


# --- Layer floors and walls ---

def ground_tile(rng, ramp, specks):
	"""A seamless floor: soft blotches plus scattered specks of the given colors."""
	size = 256
	image = Image(size, size)
	waves = random_waves(rng, 6)
	for y in range(size):
		for x in range(size):
			value = 0.5 + 0.1 * wave_noise(x, y, size, waves) + rng.uniform(-0.09, 0.09)
			image.set(x, y, shade(ramp, value))
	for _ in range(520):
		color = rng.choice(specks)
		x, y = rng.randrange(size), rng.randrange(size)
		image.wrapped(x, y, color)
		if rng.random() < 0.4:
			image.wrapped(x + 1, y, color)
	return image


@art("dirt_tile", TILESETS)
def dirt_tile(rng):
	ramp = [(170, 138, 92, 255), (184, 152, 104, 255), (198, 166, 116, 255), (210, 178, 128, 255)]
	return ground_tile(rng, ramp, [(146, 116, 76, 255), (222, 196, 148, 255), (128, 100, 66, 255)])


@art("crypt_tile", TILESETS)
def crypt_tile(rng):
	ramp = [(44, 44, 46, 255), (52, 52, 54, 255), (60, 60, 62, 255), (70, 70, 72, 255)]
	return ground_tile(rng, ramp, [(30, 30, 32, 255), (118, 118, 120, 255), (168, 168, 170, 255)])


@art("hell_tile", TILESETS)
def hell_tile(rng):
	ramp = [(86, 38, 28, 255), (100, 46, 32, 255), (114, 54, 36, 255), (128, 62, 40, 255)]
	return ground_tile(rng, ramp, [(62, 26, 20, 255), (150, 78, 46, 255), (46, 20, 18, 255)])


@art("abyss_tile", TILESETS)
def abyss_tile(rng):
	ramp = [(32, 32, 38, 255), (40, 40, 46, 255), (48, 48, 54, 255), (58, 58, 64, 255)]
	return ground_tile(rng, ramp, [(22, 22, 28, 255), (84, 82, 96, 255), (70, 56, 96, 255)])


@art("lava_tile", TILESETS)
def lava_tile(rng):
	size = 64
	image = Image(size, size)
	waves = random_waves(rng, 4)
	ramp = [(176, 44, 12, 255), (226, 88, 18, 255), (250, 150, 34, 255), (255, 216, 92, 255)]
	for y in range(size):
		for x in range(size):
			value = 0.42 + 0.2 * wave_noise(x, y, size, waves) + rng.uniform(-0.05, 0.05)
			image.set(x, y, shade(ramp, value))
	return image


@art("wall_brick", TILESETS)
def wall_brick(rng):
	size = 32
	image = Image(size, size)
	ramp = [(112, 86, 58, 255), (132, 104, 72, 255), (150, 120, 84, 255)]
	for y in range(size):
		row = y // 8
		for x in range(size):
			shifted = x + (8 if row % 2 else 0)
			if y % 8 == 0 or shifted % 16 == 0:
				image.set(x, y, (66, 50, 36, 255))
			else:
				image.set(x, y, shade(ramp, 0.5 + rng.uniform(-0.3, 0.3)))
	return image


def bar_tile(rng, background, bar_ramp, band):
	size = 32
	image = Image(size, size)
	image.fill(background)
	for x in range(2, size, 8):
		for width in range(4):
			for y in range(size):
				image.set(x + width, y, shade(bar_ramp, 0.85 - width * 0.26 + rng.uniform(-0.05, 0.05)))
	for y in (5, 6, 25, 26):
		for x in range(size):
			image.set(x, y, band)
	return image


@art("wall_bars", TILESETS)
def wall_bars(rng):
	return bar_tile(rng, (14, 14, 16, 255), [(70, 72, 78, 255), (112, 114, 120, 255), (160, 162, 168, 255)], (92, 94, 100, 255))


@art("wall_hell_bars", TILESETS)
def wall_hell_bars(rng):
	return bar_tile(rng, (92, 26, 12, 255), [(10, 10, 12, 255), (26, 26, 30, 255), (48, 46, 50, 255)], (20, 20, 24, 255))


@art("wall_bone", TILESETS)
def wall_bone(rng):
	size = 32
	image = Image(size, size)
	image.fill((26, 25, 24, 255))
	ramp = [(166, 160, 144, 255), (202, 196, 178, 255), (232, 228, 212, 255)]
	for row, offset in ((0, 0), (1, 11), (2, 5)):
		y = 5 + row * 11
		for x in range(size):
			image.wrapped(x + offset, y, shade(ramp, 0.72 + rng.uniform(-0.1, 0.1)))
			image.wrapped(x + offset, y + 1, shade(ramp, 0.4 + rng.uniform(-0.1, 0.1)))
		for dx, dy in ((0, -1), (0, 2), (1, -2), (1, 3), (2, -1), (2, 2)):
			image.wrapped(offset + dx, y + dy, ramp[2])
			image.wrapped(offset + size // 2 + dx, y + dy, ramp[1])
	return image


GRAVE_STONE = [(128, 128, 132, 255), (170, 170, 174, 255), (214, 214, 216, 255)]


@art("grave_1", WORLD)
def grave_slab(rng):
	image = Image(22, 28)
	for y in range(3, 26):
		for x in range(3, 19):
			corner = abs(x - 10.5) > 5.5 and y < 7
			if not corner:
				image.set(x, y, shade(GRAVE_STONE, 0.75 - (x - 3) * 0.03 + rng.uniform(-0.1, 0.1)))
	for x in range(7, 15):
		image.set(x, 11, GRAVE_STONE[0])
		image.set(x, 15, GRAVE_STONE[0])
	image.outline()
	return image


@art("grave_2", WORLD)
def grave_cross(rng):
	image = Image(22, 30)
	for y in range(3, 28):
		for x in range(9, 13):
			image.set(x, y, shade(GRAVE_STONE, 0.72 + rng.uniform(-0.1, 0.1)))
	for y in range(9, 13):
		for x in range(4, 18):
			image.set(x, y, shade(GRAVE_STONE, 0.72 + rng.uniform(-0.1, 0.1)))
	image.outline()
	return image


@art("crown", BOSSES)
def crown(rng):
	image = Image(22, 14)
	ramp = [(176, 116, 18, 255), (240, 186, 44, 255), (255, 230, 120, 255)]
	for x in range(2, 20):
		spike = 7 - min(abs((x - 2) % 8 - 4) * 2, 7)
		for y in range(2 + spike, 12):
			image.set(x, y, shade(ramp, 0.75 - (y - 2) * 0.05))
	for x in (6, 11, 15):
		image.set(x, 9, (214, 50, 66, 255))
	image.outline()
	return image


def polygon(image, points, color):
	"""Fills a polygon by testing every pixel in its bounding box."""
	xs = [p[0] for p in points]
	ys = [p[1] for p in points]
	for y in range(int(min(ys)), int(max(ys)) + 1):
		for x in range(int(min(xs)), int(max(xs)) + 1):
			inside = False
			j = len(points) - 1
			for i in range(len(points)):
				xi, yi = points[i]
				xj, yj = points[j]
				if (yi > y) != (yj > y) and x < (xj - xi) * (y - yi) / (yj - yi) + xi:
					inside = not inside
				j = i
			if inside:
				image.set(x, y, color)


@art("wall_rock", TILESETS)
def wall_rock(rng):
	size = 32
	image = Image(size, size)
	waves = random_waves(rng, 4)
	ramp = [(12, 11, 16, 255), (18, 16, 24, 255), (26, 23, 34, 255), (36, 32, 46, 255)]
	for y in range(size):
		for x in range(size):
			image.set(x, y, shade(ramp, 0.42 + 0.14 * wave_noise(x, y, size, waves) + rng.uniform(-0.1, 0.1)))
	return image


@art("crystal", WORLD)
def crystal(rng):
	image = Image(92, 124)
	dark, mid, light, glint = (74, 28, 138, 255), (118, 54, 200, 255), (168, 104, 240, 255), (232, 204, 255, 255)
	shards = [
		([(46, 4), (66, 40), (60, 112), (32, 112), (26, 40)], mid),
		([(46, 4), (26, 40), (32, 112), (46, 112)], light),
		([(20, 44), (32, 66), (32, 112), (12, 112), (8, 66)], dark),
		([(70, 50), (84, 74), (80, 112), (60, 112), (60, 72)], dark),
		([(70, 50), (60, 72), (60, 112), (70, 112)], mid),
		([(20, 44), (8, 66), (12, 112), (20, 112)], mid),
	]
	for points, color in shards:
		polygon(image, points, color)
	polygon(image, [(40, 18), (46, 10), (44, 52), (38, 52)], glint)
	for x in range(6, 86):
		for y in range(112, 118):
			if rng.random() < 0.8:
				image.set(x, y, (38, 30, 58, 255))
	image.outline()
	return image


DRAGON_SCALES = [(44, 10, 20, 255), (78, 16, 26, 255), (118, 26, 30, 255), (160, 40, 32, 255), (198, 74, 40, 255)]
DRAGON_BELLY = [(150, 96, 52, 255), (196, 142, 74, 255), (226, 184, 104, 255)]
DRAGON_BONE = (232, 214, 170, 255)
DRAGON_WING_NEAR = (86, 20, 40, 255)
DRAGON_WING_FAR = (46, 12, 28, 255)


def curve(points, steps):
	"""A smooth path through (x, y, radius) points, as evenly spaced samples."""
	padded = [points[0]] + list(points) + [points[-1]]
	samples = []
	for i in range(1, len(padded) - 2):
		p0, p1, p2, p3 = padded[i - 1], padded[i], padded[i + 1], padded[i + 2]
		for step in range(steps):
			t = step / steps
			samples.append(tuple(
				0.5 * (2 * b + (c - a) * t + (2 * a - 5 * b + 4 * c - d) * t * t + (3 * b - a - 3 * c + d) * t * t * t)
				for a, b, c, d in zip(p0, p1, p2, p3)))
	samples.append(points[-1])
	return samples


def scaled_limb(image, points, rng, belly_side=0.0):
	"""A scaly tube along a curve. belly_side is -1 or 1 to band one edge like a snake's belly."""
	samples = curve(points, 14)
	for i, (cx, cy, radius) in enumerate(samples):
		ax, ay, _ = samples[max(0, i - 1)]
		bx, by, _ = samples[min(len(samples) - 1, i + 1)]
		length = math.hypot(bx - ax, by - ay) or 1.0
		nx, ny = (by - ay) / length, (ax - bx) / length
		reach = int(radius + 1)
		for y in range(int(cy) - reach, int(cy) + reach + 1):
			for x in range(int(cx) - reach, int(cx) + reach + 1):
				if math.hypot(x - cx, y - cy) > radius:
					continue
				across = ((x - cx) * nx + (y - cy) * ny) / max(radius, 1.0)
				if belly_side != 0.0 and across * belly_side > 0.42:
					image.set(x, y, DRAGON_BELLY[0 if i % 5 == 0 else 1 + (i // 5) % 2])
					continue
				scale_mark = 0.13 if (x + y // 3 * 3) % 6 < 2 and (y // 3) % 2 == 0 else 0.0
				light = 0.5 + 0.2 * across * (-belly_side or 1.0) - 0.22 * (y - cy) / max(radius, 1.0)
				image.set(x, y, shade(DRAGON_SCALES, light + scale_mark + rng.uniform(-0.05, 0.05)))
	return samples


def dorsal_spines(image, samples, side, start, end, every, height):
	"""Bone-tipped spines along one edge of a limb, shrinking toward the end."""
	last = len(samples) - 1
	for i in range(int(last * start), int(last * end), every):
		cx, cy, radius = samples[i]
		ax, ay, _ = samples[max(0, i - 2)]
		bx, by, _ = samples[min(last, i + 2)]
		length = math.hypot(bx - ax, by - ay) or 1.0
		dx, dy = (bx - ax) / length, (by - ay) / length
		nx, ny = -dy * side, dx * side
		size = max(2.0, height * (radius / 8.0))
		base_a = (cx + nx * (radius - 1) - dx * size * 0.5, cy + ny * (radius - 1) - dy * size * 0.5)
		base_b = (cx + nx * (radius - 1) + dx * size * 0.5, cy + ny * (radius - 1) + dy * size * 0.5)
		tip = (cx + nx * (radius + size) - dx * size * 0.7, cy + ny * (radius + size) - dy * size * 0.7)
		polygon(image, [base_a, tip, base_b], DRAGON_BONE if size > 3.0 else DRAGON_SCALES[4])


def bat_wing(image, shoulder, elbow, wrist, fingertips, color, bone):
	"""A leathery wing: bony arm, long fingers, and membrane scooped between the tips."""
	polygon(image, [shoulder, elbow, wrist] + fingertips[:1], color)
	anchors = fingertips + [shoulder]
	for i in range(len(anchors) - 1):
		a, b = anchors[i], anchors[i + 1]
		mid = ((a[0] + b[0]) * 0.5, (a[1] + b[1]) * 0.5)
		sag = (mid[0] + (wrist[0] - mid[0]) * 0.32, mid[1] + (wrist[1] - mid[1]) * 0.32)
		polygon(image, [wrist, a, sag, b], color)
	for start, end in [(shoulder, elbow), (elbow, wrist)] + [(wrist, tip) for tip in fingertips]:
		steps = int(max(abs(end[0] - start[0]), abs(end[1] - start[1]))) + 1
		for i in range(steps + 1):
			x = int(start[0] + (end[0] - start[0]) * i / steps)
			y = int(start[1] + (end[1] - start[1]) * i / steps)
			image.set(x, y, bone)
			image.set(x, y + 1, bone)
	polygon(image, [(wrist[0] - 3, wrist[1] + 1), (wrist[0] + 2, wrist[1] - 7), (wrist[0] + 3, wrist[1] + 1)], DRAGON_BONE)


def clawed_leg(image, points, rng):
	samples = scaled_limb(image, points, rng)
	foot_x, foot_y, _ = samples[-1]
	for offset in (-5, -1, 3):
		polygon(image, [(foot_x + offset - 1, foot_y), (foot_x + offset + 3, foot_y), (foot_x + offset + 5, foot_y + 5)], DRAGON_BONE)


def shadow_scales(image):
	"""Darkens what's drawn so far, so far-side limbs sit behind the body."""
	for y in range(image.height):
		for x in range(image.width):
			pixel = image.get(x, y)
			if pixel in DRAGON_SCALES:
				image.set(x, y, DRAGON_SCALES[max(0, DRAGON_SCALES.index(pixel) - 1)])


@art("dragon", BOSSES)
def dragon(rng):
	image = Image(164, 128)
	bat_wing(image, (84, 50), (66, 24), (46, 5), [(4, 12), (10, 36), (26, 54), (46, 62)], DRAGON_WING_FAR, DRAGON_SCALES[1])
	clawed_leg(image, [(92, 78, 6), (102, 90, 5), (100, 104, 4), (106, 114, 3)], rng)
	clawed_leg(image, [(58, 80, 7), (52, 94, 5), (58, 106, 4), (54, 115, 3)], rng)
	shadow_scales(image)

	tail = scaled_limb(image, [(56, 72, 13), (36, 80, 10), (18, 94, 7), (14, 110, 5), (26, 118, 3), (38, 114, 2)], rng, 1.0)
	body = scaled_limb(image, [(52, 68, 15), (76, 66, 17), (100, 64, 15)], rng, -1.0)
	neck = scaled_limb(image, [(100, 64, 13), (117, 58, 9), (120, 42, 7), (112, 30, 6), (118, 18, 6), (130, 14, 6)], rng, -1.0)
	polygon(image, [(36, 116), (46, 101), (53, 110), (47, 123)], DRAGON_SCALES[2])
	polygon(image, [(41, 113), (46, 105), (49, 115)], DRAGON_SCALES[4])

	# Head: a long wedge of a skull, with an open jaw.
	polygon(image, [(124, 8), (140, 7), (160, 15), (158, 21), (142, 22), (124, 24)], DRAGON_SCALES[3])
	polygon(image, [(124, 8), (140, 7), (160, 15), (142, 14), (126, 15)], DRAGON_SCALES[4])
	polygon(image, [(126, 22), (142, 27), (155, 32), (153, 35), (138, 33), (124, 28)], DRAGON_SCALES[2])
	polygon(image, [(136, 22), (160, 21), (154, 31), (142, 26)], (54, 8, 14, 255))
	for x in range(142, 158, 4):
		polygon(image, [(x, 21), (x + 3, 21), (x + 1, 26)], DRAGON_BONE)
	for x in range(141, 152, 4):
		polygon(image, [(x, 29), (x + 3, 30), (x, 25)], DRAGON_BONE)
	polygon(image, [(126, 11), (114, 1), (108, 2), (120, 15)], DRAGON_BONE)
	polygon(image, [(134, 8), (126, 0), (120, 1), (130, 10)], DRAGON_BONE)
	polygon(image, [(124, 20), (112, 25), (124, 26)], DRAGON_SCALES[1])
	polygon(image, [(134, 12), (142, 11), (142, 14), (135, 15)], DRAGON_SCALES[0])
	for x, y, color in ((138, 12, (255, 226, 80, 255)), (139, 12, (255, 226, 80, 255)), (140, 12, (20, 8, 8, 255)), (156, 15, (30, 8, 10, 255))):
		image.set(x, y, color)

	dorsal_spines(image, tail, 1, 0.0, 0.8, 7, 5)
	dorsal_spines(image, body, -1, 0.0, 0.95, 6, 5)
	dorsal_spines(image, neck, -1, 0.0, 0.9, 7, 6)

	bat_wing(image, (92, 56), (70, 34), (52, 14), [(12, 30), (20, 54), (38, 70), (62, 74)], DRAGON_WING_NEAR, DRAGON_SCALES[4])
	clawed_leg(image, [(104, 74, 8), (118, 84, 6), (114, 98, 4), (120, 108, 3)], rng)
	clawed_leg(image, [(72, 76, 10), (66, 94, 7), (74, 106, 5), (70, 116, 3)], rng)
	image.outline()
	return image


@art("dragon_hatchling", BOSSES)
def dragon_hatchling(rng):
	"""A runt of the big dragon: big head, stubby body, small wings."""
	image = Image(56, 48)
	bat_wing(image, (24, 22), (17, 13), (11, 4), [(1, 8), (3, 18), (11, 24)], DRAGON_WING_NEAR, DRAGON_SCALES[4])
	scaled_limb(image, [(18, 30, 5), (10, 34, 3), (5, 41, 2), (10, 45, 1)], rng, 1.0)
	scaled_limb(image, [(18, 29, 7), (28, 28, 8)], rng, -1.0)
	clawed_leg(image, [(20, 33, 3), (19, 41, 2)], rng)
	clawed_leg(image, [(30, 33, 3), (31, 41, 2)], rng)
	scaled_limb(image, [(30, 26, 5), (35, 19, 4), (38, 13, 4)], rng, -1.0)
	polygon(image, [(35, 7), (46, 6), (55, 12), (53, 15), (45, 17), (35, 18)], DRAGON_SCALES[3])
	polygon(image, [(35, 7), (46, 6), (55, 12), (45, 11), (37, 12)], DRAGON_SCALES[4])
	polygon(image, [(38, 17), (46, 19), (51, 22), (49, 24), (38, 22)], DRAGON_SCALES[2])
	polygon(image, [(37, 8), (31, 1), (28, 2), (34, 10)], DRAGON_BONE)
	polygon(image, [(43, 8), (40, 13), (46, 12)], (255, 226, 80, 255))
	image.set(44, 10, (20, 8, 8, 255))
	image.outline()
	return image


@art("hidden_boss", BOSSES)
def hidden_boss(rng):
	"""What's left inside the dragon: a shrouded thing with a shard crown and too many eyes."""
	image = Image(96, 96)
	shroud = [(14, 8, 24, 255), (26, 14, 42, 255), (44, 22, 68, 255), (70, 34, 104, 255)]
	polygon(image, [(48, 14), (72, 34), (88, 92), (70, 82), (58, 94), (48, 84), (38, 94), (26, 82), (8, 92), (24, 34)], shroud[1])
	polygon(image, [(48, 14), (34, 32), (22, 84), (38, 76), (48, 84)], shroud[2])
	polygon(image, [(48, 14), (40, 32), (36, 62), (48, 70)], shroud[3])
	blob(image, 48, 32, 17, 18, shroud, rng, 0.08)
	blob(image, 48, 36, 11, 12, [(4, 2, 8, 255), (8, 4, 14, 255)], rng, 0.02)
	for x, tall in ((28, 12), (38, 18), (48, 24), (58, 18), (68, 12)):
		polygon(image, [(x - 4, 18), (x, 18 - tall + 6), (x + 4, 18)], (168, 104, 240, 255))
	glow, core = (236, 70, 130, 255), (255, 214, 226, 255)
	for x, y, size in ((43, 34, 2), (53, 34, 2), (48, 41, 3), (40, 44, 1), (56, 44, 1), (48, 29, 1)):
		for dy in range(-size, size + 1):
			for dx in range(-size, size + 1):
				if dx * dx + dy * dy <= size * size:
					image.set(x + dx, y + dy, glow)
		image.set(x, y, core)
	for i in range(4):
		left, right = 18 - i * 3, 78 + i * 3
		polygon(image, [(left + 8, 46 + i * 9), (left - 8, 58 + i * 9), (left + 10, 52 + i * 9)], shroud[3])
		polygon(image, [(right - 8, 46 + i * 9), (right + 8, 58 + i * 9), (right - 10, 52 + i * 9)], shroud[2])
	image.outline()
	return image


@art("icon_doppelganger", UI)
def icon_doppelganger(rng):
	image = Image(36, 36)
	robe = [(54, 26, 96, 255), (84, 44, 146, 255), (122, 72, 200, 255), (176, 124, 244, 255)]
	polygon(image, [(18, 13), (27, 33), (9, 33)], robe[1])
	polygon(image, [(18, 13), (18, 33), (9, 33)], robe[2])
	blob(image, 18, 12, 5, 5, robe, rng, 0.04)
	polygon(image, [(8, 9), (28, 9), (19, 0)], robe[0])
	image.set(16, 12, (255, 255, 255, 255))
	image.set(20, 12, (255, 255, 255, 255))
	image.outline()
	return image


# --- Unique spell pickups ---

UNIQUE_ORBS = {
	"unique_water": [(16, 58, 128, 255), (30, 104, 188, 255), (70, 164, 230, 255), (176, 226, 250, 255)],
	"unique_earth": [(62, 44, 22, 255), (106, 78, 38, 255), (150, 118, 60, 255), (206, 176, 112, 255)],
	"unique_death": [(30, 12, 54, 255), (72, 28, 116, 255), (130, 62, 184, 255), (204, 150, 240, 255)],
	"unique_abyssal": [(20, 10, 30, 255), (46, 20, 62, 255), (84, 34, 104, 255), (190, 70, 130, 255)],
	"unique_fireball": [(120, 28, 8, 255), (206, 70, 12, 255), (248, 142, 32, 255), (255, 226, 120, 255)],
}


def orb(name, rng):
	image = Image(26, 26)
	blob(image, 13, 13, 10, 10, UNIQUE_ORBS[name], rng, 0.08)
	for x, y in ((9, 8), (10, 8), (9, 9)):
		image.set(x, y, (255, 255, 255, 255))
	image.outline()
	return image


def register_orbs():
	for name in UNIQUE_ORBS:
		ART[name] = ((lambda orb_name: lambda rng: orb(orb_name, rng))(name), SPELLS)


register_orbs()


# --- Tiles ---

@art("grass_tile", TILESETS)
def grass_tile(rng):
	size = 256
	image = Image(size, size)
	waves = random_waves(rng, 6)
	for y in range(size):
		for x in range(size):
			value = 0.5 + 0.11 * wave_noise(x, y, size, waves) + rng.uniform(-0.08, 0.08)
			image.set(x, y, shade(GRASS, value))
	for _ in range(420):
		x = rng.randrange(size)
		y = rng.randrange(size)
		color = rng.choice(((54, 142, 54, 255), (122, 212, 84, 255), (146, 224, 96, 255)))
		image.wrapped(x, y, color)
		image.wrapped(x, y - 1, color)
		if rng.random() < 0.5:
			image.wrapped(x + rng.choice((-1, 1)), y - 2, color)
	return image


@art("water_tile", TILESETS)
def water_tile(rng):
	size = 64
	image = Image(size, size)
	waves = random_waves(rng, 4)
	for y in range(size):
		for x in range(size):
			value = 0.42 + 0.06 * wave_noise(x, y, size, waves) + rng.uniform(-0.06, 0.06)
			image.set(x, y, shade(WATER[:3], value))
	for _ in range(22):
		x = rng.randrange(size)
		y = rng.randrange(size)
		for i in range(rng.randint(3, 8)):
			image.wrapped(x + i, y, WATER[3])
	return image


def main():
	parser = argparse.ArgumentParser(description="Draw the game's generated terrain art.")
	parser.add_argument("names", nargs="*", help="images to generate (default: all)")
	args = parser.parse_args()
	unknown = [name for name in args.names if name not in ART]
	if unknown:
		sys.exit(f"Unknown art: {', '.join(unknown)}")
	for name in args.names or ART:
		recipe, folder = ART[name]
		folder.mkdir(parents=True, exist_ok=True)
		recipe(random.Random(zlib.crc32(name.encode()))).save(folder / f"{name}.png")


if __name__ == "__main__":
	main()
