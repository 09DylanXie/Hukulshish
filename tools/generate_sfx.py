#!/usr/bin/env python3
"""Synthesizes every Hukulshish sound effect into assets/audio/sfx/.

Standard library only. Output is deterministic: each file's random seed comes
from its name, so changing one recipe leaves every other file byte-identical.

    python tools/generate_sfx.py            # regenerate everything
    python tools/generate_sfx.py boss_hit   # regenerate one sound
    python tools/generate_sfx.py --report   # also print level statistics

After regenerating, open the project in Godot (or run it with --import) so the
.wav files are re-imported. Sound names and variant counts must match the
SOUNDS table in scripts/autoload/audio_manager.gd.
"""

import argparse
import math
import random
import struct
import sys
import zlib
from pathlib import Path

SAMPLE_RATE = 44100
OUTPUT_DIR = Path(__file__).resolve().parent.parent / "assets" / "audio" / "sfx"

RECIPES = {}


def sfx(name, variants=1, loop=False):
	"""Registers a recipe. Recipes receive (rng, variant) and return samples."""
	def register(fn):
		RECIPES[name] = (fn, variants, loop)
		return fn
	return register


# --- Oscillators and noise ---

def frames(duration):
	return max(1, int(duration * SAMPLE_RATE))


def sweep(start, end, x):
	"""Exponential interpolation, which sounds linear in pitch and brightness."""
	return start * (end / start) ** x


def osc(duration, f0, f1=None, wave="sine", vibrato_hz=0.0, vibrato_depth=0.0):
	f1 = f0 if f1 is None else f1
	n = frames(duration)
	out = [0.0] * n
	phase = 0.0
	for i in range(n):
		x = i / n
		freq = sweep(f0, f1, x)
		if vibrato_depth > 0.0:
			freq *= 1.0 + vibrato_depth * math.sin(math.tau * vibrato_hz * i / SAMPLE_RATE)
		phase = (phase + freq / SAMPLE_RATE) % 1.0
		if wave == "sine":
			out[i] = math.sin(math.tau * phase)
		elif wave == "tri":
			out[i] = 4.0 * abs(phase - 0.5) - 1.0
		elif wave == "saw":
			out[i] = 2.0 * phase - 1.0
		else:  # A rounded square wave aliases less than a hard one.
			out[i] = math.tanh(5.0 * math.sin(math.tau * phase))
	return out


def noise(duration, rng, cutoff0=8000.0, cutoff1=None):
	"""White noise through a low-pass filter whose cutoff sweeps over time."""
	cutoff1 = cutoff0 if cutoff1 is None else cutoff1
	n = frames(duration)
	out = [0.0] * n
	state = 0.0
	for i in range(n):
		cutoff = sweep(cutoff0, cutoff1, i / n)
		alpha = 1.0 - math.exp(-math.tau * cutoff / SAMPLE_RATE)
		state += alpha * (rng.uniform(-1.0, 1.0) - state)
		out[i] = state
	return normalized(out)


# --- Shaping ---

def env(samples, attack=0.002, power=2.0):
	"""Fast linear attack, then a (1 - x) ^ power decay across the whole sound."""
	n = len(samples)
	attack_frames = max(1, frames(attack))
	out = [0.0] * n
	for i, s in enumerate(samples):
		rise = min(1.0, i / attack_frames)
		out[i] = s * rise * (1.0 - i / n) ** power
	return out


def swell(samples, peak_at=0.5, power=2.0):
	"""Rises to full level at `peak_at`, then decays. For roars and horns."""
	n = len(samples)
	out = [0.0] * n
	for i, s in enumerate(samples):
		x = i / n
		level = (x / peak_at) if x < peak_at else (1.0 - (x - peak_at) / (1.0 - peak_at)) ** power
		out[i] = s * level
	return out


def lowpass(samples, cutoff):
	alpha = 1.0 - math.exp(-math.tau * cutoff / SAMPLE_RATE)
	out = [0.0] * len(samples)
	state = 0.0
	for i, s in enumerate(samples):
		state += alpha * (s - state)
		out[i] = state
	return out


def highpass(samples, cutoff):
	low = lowpass(samples, cutoff)
	return [s - l for s, l in zip(samples, low)]


def drive(samples, amount):
	"""Soft saturation: adds grit and weight without hard clipping."""
	return [math.tanh(s * amount) for s in samples]


def tremolo(samples, rate, depth):
	return [s * (1.0 - depth + depth * math.sin(math.tau * rate * i / SAMPLE_RATE))
		for i, s in enumerate(samples)]


def echo(samples, delay, feedback=0.3, repeats=3):
	step = frames(delay)
	out = list(samples) + [0.0] * (step * repeats)
	level = 1.0
	for r in range(1, repeats + 1):
		level *= feedback
		offset = step * r
		for i, s in enumerate(samples):
			out[i + offset] += s * level
	return out


def mix(*layers):
	"""Each layer is (samples, gain) or (samples, gain, start_seconds)."""
	length = 0
	for layer in layers:
		start = frames(layer[2]) if len(layer) > 2 else 0
		length = max(length, start + len(layer[0]))
	out = [0.0] * length
	for layer in layers:
		start = frames(layer[2]) if len(layer) > 2 else 0
		gain = layer[1]
		for i, s in enumerate(layer[0]):
			out[start + i] += s * gain
	return out


def normalized(samples, peak=1.0):
	top = max(abs(s) for s in samples)
	if top <= 0.0:
		return samples
	return [s * peak / top for s in samples]


def finish(samples, peak):
	"""Removes DC, cuts leading silence, fades the tail, and sets the level."""
	average = sum(samples) / len(samples)
	out = [s - average for s in samples]
	threshold = max(abs(s) for s in out) * 0.01
	start = next(i for i, s in enumerate(out) if abs(s) >= threshold)
	out = out[start:]
	fade = min(frames(0.008), len(out))
	for i in range(fade):
		out[-1 - i] *= i / fade
	return normalized(out, peak)


def make_seamless(samples, overlap):
	"""Crossfades the tail into the head so the sound can loop without a click."""
	count = frames(overlap)
	body = list(samples[:-count])
	for i in range(count):
		x = i / count
		# Equal-power curves keep noise at a steady level through the crossfade.
		body[i] = samples[i] * math.sin(x * math.pi / 2.0) \
			+ samples[len(samples) - count + i] * math.cos(x * math.pi / 2.0)
	return body


# --- Reusable instruments ---

def bell(duration, freq, brightness=0.5):
	"""A struck tone: slightly inharmonic overtones that die away quickly."""
	return mix(
		(env(osc(duration, freq), 0.002, 3.0), 1.0),
		(env(osc(duration, freq * 2.01), 0.001, 5.0), brightness),
		(env(osc(duration, freq * 3.03), 0.001, 8.0), brightness * 0.5),
	)


def growl(duration, f0, f1, rng, rough=0.5, flutter=38.0):
	"""A creature voice: a saw vocal fold, a throat filter, and throat flutter."""
	voice = osc(duration, f0, f1, "saw", 7.0, 0.025)
	voice = lowpass(voice, max(f0, f1) * 5.0)
	breath = noise(duration, rng, max(f0, f1) * 8.0, min(f0, f1) * 4.0)
	return tremolo(mix((voice, 1.0), (breath, rough)), flutter, 0.35)


def thud(duration, f0=150.0, f1=45.0):
	return env(osc(duration, f0, f1), 0.001, 3.0)


def boom(duration, rng, bright=3200.0):
	"""An explosion body: filtered noise that darkens, on top of a sub drop."""
	body = env(noise(duration, rng, bright, 160.0), 0.002, 2.4)
	return drive(mix((body, 1.0), (env(osc(duration, 110.0, 34.0), 0.002, 1.8), 0.9)), 1.8)


def melody(notes, voice):
	"""Each note is (start_seconds, frequency, duration, gain)."""
	return mix(*[(voice(duration, freq), gain, start) for start, freq, duration, gain in notes])


# Pitches, so jingles read as notes rather than bare frequencies.
A2, C3, D3, E3, F3, G3, A3, B3 = 110.0, 130.81, 146.83, 164.81, 174.61, 196.0, 220.0, 246.94
C4, D4, E4, F4, G4, A4, B4 = 261.63, 293.66, 329.63, 349.23, 392.0, 440.0, 493.88
C5, D5, E5, G5, A5 = 523.25, 587.33, 659.25, 783.99, 880.0
C6, E6, G6 = 1046.5, 1318.51, 1567.98


# --- Player and spells ---

@sfx("cast_base", variants=3)
def cast_base(rng, v):
	pitch = (1.0, 1.07, 0.93)[v]
	return finish(echo(mix(
		(env(osc(0.17, 1500 * pitch, 420 * pitch, "tri"), 0.002, 2.5), 1.0),
		(env(osc(0.13, 2300 * pitch, 650 * pitch), 0.001, 3.0), 0.45),
		(env(noise(0.1, rng, 7000, 1800), 0.001, 3.0), 0.2),
	), 0.055, 0.22, 2), 0.7)


@sfx("cast_boss_spell")
def cast_boss_spell(rng, v):
	return finish(echo(mix(
		(env(osc(0.3, 620, 150, "square"), 0.003, 2.2), 0.6),
		(env(osc(0.3, 220, 62), 0.002, 1.6), 1.0),
		(env(osc(0.22, 1250, 300, "tri"), 0.002, 2.5), 0.4),
		(env(noise(0.2, rng, 4000, 700), 0.002, 2.5), 0.25),
	), 0.08, 0.28, 2), 0.8)


@sfx("spell_hit", variants=3)
def spell_hit(rng, v):
	pitch = (1.0, 1.15, 0.86)[v]
	return finish(mix(
		(env(noise(0.09, rng, 6500 * pitch, 1400), 0.001, 3.0), 0.8),
		(env(osc(0.12, 340 * pitch, 110 * pitch), 0.001, 2.5), 1.0),
	), 0.7)


@sfx("split_spell")
def split_spell(rng, v):
	return finish(mix(
		(env(osc(0.2, 950, 1900, "tri"), 0.002, 2.0), 0.8),
		(env(osc(0.2, 950, 480, "tri"), 0.002, 2.0), 0.8),
		(env(noise(0.05, rng, 7000), 0.001, 2.0), 0.3),
	), 0.65)


@sfx("chain_lightning")
def chain_lightning(rng, v):
	# Arcs are bursts of noise switched on and off at random, not a steady hiss.
	crackle = highpass(noise(0.32, rng, 11000), 1500)
	gate_length = frames(0.0035)
	for start in range(0, len(crackle), gate_length):
		level = rng.choice((0.0, 0.25, 1.0, 1.0))
		for i in range(start, min(start + gate_length, len(crackle))):
			crackle[i] *= level
	return finish(mix(
		(env(crackle, 0.001, 1.4), 1.0),
		(env(osc(0.32, 120, 90, "saw"), 0.002, 1.5), 0.25),
	), 0.7)


@sfx("bomb_explosion")
def bomb_explosion(rng, v):
	return finish(boom(0.75, rng), 0.85)


@sfx("fire_loop", loop=True)
def fire_loop(rng, v):
	duration = 2.8
	rumble = noise(duration, rng, 420)
	roar = tremolo(highpass(noise(duration, rng, 2600), 500), 3.1, 0.3)
	layers = [(rumble, 0.5), (roar, 0.3)]
	for _ in range(46):
		size = rng.uniform(0.004, 0.022)
		pop = env(highpass(noise(size, rng, rng.uniform(3000, 9000)), 800), 0.0005, 2.5)
		layers.append((pop, rng.uniform(0.15, 0.6), rng.uniform(0.0, duration - 0.03)))
	return normalized(make_seamless(mix(*layers), 0.35), 0.6)


@sfx("sniper_shot")
def sniper_shot(rng, v):
	return finish(echo(mix(
		(env(osc(0.24, 3200, 760), 0.001, 2.4), 0.7),
		(env(highpass(noise(0.04, rng, 12000), 2000), 0.0005, 2.0), 0.9),
		(env(osc(0.16, 420, 120, "tri"), 0.001, 2.0), 0.5),
	), 0.09, 0.25, 2), 0.75)


@sfx("player_hurt")
def player_hurt(rng, v):
	return finish(drive(mix(
		(env(osc(0.24, 340, 130, "square"), 0.002, 1.8), 0.7),
		(env(noise(0.1, rng, 3500, 900), 0.001, 2.0), 0.6),
		(thud(0.16, 170, 70), 0.8),
	), 1.5), 0.85)


@sfx("shield_hit")
def shield_hit(rng, v):
	return finish(mix(
		(env(osc(0.22, 1180), 0.001, 3.0), 0.8),
		(env(osc(0.18, 1873), 0.001, 4.0), 0.5),
		(env(osc(0.14, 2641), 0.001, 5.0), 0.35),
		(env(noise(0.03, rng, 8000), 0.001, 2.0), 0.3),
	), 0.7)


@sfx("player_death")
def player_death(rng, v):
	return finish(echo(tremolo(mix(
		(env(osc(0.95, 440, 62, "saw"), 0.005, 1.3), 0.6),
		(env(osc(0.95, 220, 40), 0.005, 1.1), 1.0),
		(env(noise(0.5, rng, 1800, 200), 0.005, 2.0), 0.25),
	), 9.0, 0.3), 0.13, 0.3, 3), 0.85)


@sfx("revive")
def revive(rng, v):
	notes = [(0.0, C5, 0.5, 0.7), (0.11, E5, 0.5, 0.7), (0.22, G5, 0.55, 0.75), (0.33, C6, 0.75, 0.9)]
	shimmer = env(highpass(noise(0.9, rng, 9000), 3500), 0.2, 2.0)
	return finish(mix((melody(notes, bell), 1.0), (shimmer, 0.1)), 0.75)


# --- Monsters ---

@sfx("goblin_death")
def goblin_death(rng, v):
	return finish(mix(
		(env(growl(0.32, 720, 280, rng, 0.2, 52), 0.004, 1.4), 1.0),
		(env(noise(0.06, rng, 4500, 1500), 0.001, 2.0), 0.3),
	), 0.7)


@sfx("undead_death")
def undead_death(rng, v):
	# A hollow exhale with loose bones clattering down over it.
	breath = env(lowpass(highpass(noise(0.5, rng, 2400, 800), 350), 2200), 0.03, 1.5)
	layers = [(breath, 0.75), (env(osc(0.42, 240, 120, "tri"), 0.02, 1.6), 0.3)]
	start = 0.02
	for gain in (0.8, 0.65, 0.5, 0.4, 0.3):
		click = env(highpass(noise(0.018, rng, 7000), 1200), 0.0005, 2.5)
		layers.append((click, gain, start))
		start += rng.uniform(0.05, 0.09)
	return finish(mix(*layers), 0.7)


@sfx("demon_death")
def demon_death(rng, v):
	return finish(drive(mix(
		(env(growl(0.55, 210, 68, rng, 0.45, 30), 0.006, 1.5), 1.0),
		(env(highpass(noise(0.4, rng, 6000, 1500), 900), 0.02, 2.2), 0.3),
	), 2.0), 0.8)


@sfx("ogre_death")
def ogre_death(rng, v):
	return finish(drive(mix(
		(env(growl(0.58, 125, 48, rng, 0.3, 24), 0.008, 1.3), 1.0),
		(thud(0.32, 130, 38), 1.0, 0.24),
	), 1.8), 0.85)


@sfx("demon_shield_break")
def demon_shield_break(rng, v):
	shards = [(env(highpass(noise(0.12, rng, 11000, 4000), 1800), 0.001, 2.2), 0.55)]
	for freq, gain, start in ((2350, 0.5, 0.0), (3170, 0.42, 0.015), (4230, 0.34, 0.03), (2810, 0.3, 0.06)):
		shards.append((env(osc(0.2, freq), 0.001, 4.0), gain, start))
	return finish(mix(*shards), 0.7)


@sfx("undead_slow_cast")
def undead_slow_cast(rng, v):
	return finish(echo(mix(
		(env(osc(0.28, 940, 460, "sine", 13.0, 0.04), 0.012, 1.8), 1.0),
		(env(osc(0.28, 1420, 700, "tri"), 0.012, 2.2), 0.25),
		(env(lowpass(noise(0.26, rng, 3000), 2400), 0.02, 2.0), 0.2),
	), 0.07, 0.25, 2), 0.6)


# --- Nests and bosses ---

@sfx("nest_hit")
def nest_hit(rng, v):
	return finish(mix(
		(thud(0.16, 210, 85), 1.0),
		(env(noise(0.08, rng, 2200, 500), 0.001, 2.0), 0.55),
	), 0.65)


@sfx("nest_destroyed")
def nest_destroyed(rng, v):
	layers = [(boom(1.3, rng, 2400), 1.0)]
	start = 0.12
	while start < 0.95:
		size = rng.uniform(0.04, 0.14)
		debris = env(noise(size, rng, rng.uniform(900, 3200), 300), 0.001, 2.2)
		layers.append((debris, rng.uniform(0.15, 0.4), start))
		start += rng.uniform(0.04, 0.13)
	return finish(mix(*layers), 0.9)


@sfx("boss_spawn")
def boss_spawn(rng, v):
	rise = growl(0.5, 70, 190, rng, 0.35, 26)
	fall = growl(0.8, 190, 62, rng, 0.45, 26)
	roar = mix((swell(rise, 0.95, 1.0), 0.8), (env(fall, 0.01, 1.3), 1.0, 0.46))
	return finish(drive(roar, 2.2), 0.9)


@sfx("boss_hit")
def boss_hit(rng, v):
	return finish(mix(
		(thud(0.15, 170, 58), 1.0),
		(env(noise(0.07, rng, 2800, 700), 0.001, 2.5), 0.45),
	), 0.6)


@sfx("boss_death")
def boss_death(rng, v):
	return finish(drive(mix(
		(env(growl(1.3, 240, 42, rng, 0.45, 22), 0.01, 1.2), 1.0),
		(boom(1.2, rng, 2000), 0.75, 0.18),
	), 1.5), 0.9)


@sfx("boss_shot")
def boss_shot(rng, v):
	return finish(mix(
		(env(osc(0.26, 460, 170, "square"), 0.003, 2.0), 0.7),
		(env(noise(0.14, rng, 2600, 500), 0.002, 2.2), 0.4),
		(thud(0.14, 150, 60), 0.5),
	), 0.65)


@sfx("mega_boss_spawn")
def mega_boss_spawn(rng, v):
	drone = swell(mix(
		(osc(2.6, 42, 92, "saw"), 0.7),
		(osc(2.6, 63, 138, "saw"), 0.45),
		(noise(2.6, rng, 220, 1400), 0.5),
	), 0.5, 1.4)
	roar = env(growl(1.5, 165, 50, rng, 0.5, 21), 0.02, 1.2)
	return finish(drive(mix(
		(lowpass(drone, 2400), 0.8),
		(roar, 1.0, 1.05),
		(boom(1.5, rng, 1600), 0.7, 1.05),
	), 1.6), 0.95)


@sfx("mega_boss_shield_regen")
def mega_boss_shield_regen(rng, v):
	layers = [(swell(osc(1.0, 170, 680, "tri", 11.0, 0.025), 0.75, 1.5), 0.6)]
	layers.append((swell(highpass(noise(1.0, rng, 3000, 11000), 1500), 0.8, 1.5), 0.28))
	for start, freq in ((0.35, C5), (0.5, G5), (0.65, C6)):
		layers.append((bell(0.35, freq, 0.4), 0.3, start))
	return finish(mix(*layers), 0.75)


@sfx("mega_boss_death")
def mega_boss_death(rng, v):
	layers = [
		(env(growl(2.5, 280, 30, rng, 0.5, 18), 0.02, 1.0), 0.9),
		(boom(1.0, rng, 2600), 0.8),
		(boom(1.2, rng, 2000), 0.75, 0.48),
		(boom(1.5, rng, 1500), 0.95, 1.05),
	]
	return finish(drive(mix(*layers), 1.5), 0.95)


# --- Pickups and economy ---

def coin(duration, freq):
	return mix(
		(env(osc(duration, freq), 0.001, 3.5), 1.0),
		(env(osc(duration, freq * 1.5), 0.001, 5.0), 0.5),
		(env(osc(duration, freq * 2.74), 0.001, 7.0), 0.28),
	)


@sfx("gold_pickup", variants=2)
def gold_pickup(rng, v):
	first, second = ((2093, 2794), (2349, 3136))[v]
	return finish(mix((coin(0.07, first), 0.7), (coin(0.12, second), 1.0, 0.045)), 0.55)


@sfx("gold_mine_collect")
def gold_mine_collect(rng, v):
	layers = []
	start = 0.0
	for _ in range(9):
		layers.append((coin(0.16, rng.uniform(1900, 3400)), rng.uniform(0.5, 1.0), start))
		start += rng.uniform(0.025, 0.055)
	return finish(mix(*layers), 0.7)


@sfx("scroll_pickup")
def scroll_pickup(rng, v):
	rustle = env(highpass(noise(0.07, rng, 7000), 1800), 0.004, 1.5)
	return finish(mix(
		(rustle, 0.16),
		(bell(0.24, G5, 0.45), 0.8, 0.02),
		(bell(0.28, C6, 0.45), 1.0, 0.09),
	), 0.65)


@sfx("boss_spell_pickup")
def boss_spell_pickup(rng, v):
	notes = [(0.0, C5, 0.45, 0.8), (0.07, G5, 0.45, 0.8), (0.14, C6, 0.45, 0.8),
		(0.21, E6, 0.55, 0.85), (0.3, G6, 0.5, 0.75)]
	return finish(mix(
		(melody(notes, bell), 1.0),
		(env(osc(0.7, 130, 260, "tri"), 0.01, 1.6), 0.3),
	), 0.8)


@sfx("potion_use")
def potion_use(rng, v):
	layers = []
	start = 0.0
	for freq in (360, 430, 520, 610, 760):
		layers.append((env(osc(0.075, freq, freq * 1.5), 0.004, 1.3), 0.8, start))
		start += rng.uniform(0.05, 0.07)
	return finish(mix(*layers), 0.6)


@sfx("heal")
def heal(rng, v):
	notes = [(0.0, E5, 0.26, 0.7), (0.09, A5, 0.3, 0.8), (0.17, C6, 0.3, 0.6)]
	return finish(melody(notes, lambda d, f: bell(d, f, 0.2)), 0.5)


# --- Castle and menus ---

@sfx("castle_enter")
def castle_enter(rng, v):
	return finish(mix(
		(bell(0.65, C4, 0.5), 1.0),
		(bell(0.55, G4, 0.35), 0.5, 0.06),
		(env(noise(0.3, rng, 900, 300), 0.03, 1.6), 0.15),
	), 0.65)


@sfx("shop_buy")
def shop_buy(rng, v):
	return finish(mix((coin(0.1, 1760), 0.7), (coin(0.22, 2637), 1.0, 0.075)), 0.6)


@sfx("shop_deny")
def shop_deny(rng, v):
	return finish(mix(
		(env(osc(0.09, 190, None, "square"), 0.002, 0.7), 1.0),
		(env(osc(0.11, 148, None, "square"), 0.002, 0.9), 1.0, 0.1),
	), 0.45)


@sfx("ui_click")
def ui_click(rng, v):
	return finish(mix(
		(env(osc(0.045, 1250, 650, "tri"), 0.0005, 3.0), 1.0),
		(env(noise(0.012, rng, 7000), 0.0005, 2.0), 0.2),
	), 0.45)


# --- Run events ---

def brass(duration, freq):
	"""A horn: a saw with vibrato, filtered so it sits low and round."""
	voice = lowpass(osc(duration, freq, None, "saw", 5.2, 0.006), freq * 4.5)
	n = len(voice)
	attack = frames(0.04)
	release = frames(0.12)
	return [s * min(1.0, i / attack) * min(1.0, (n - i) / release) for i, s in enumerate(voice)]


@sfx("victory")
def victory(rng, v):
	# A minor pickup that resolves to C major, with a held chord at the end.
	lead = [(0.0, G3, 0.2, 0.7), (0.21, C4, 0.2, 0.7), (0.42, E4, 0.2, 0.75), (0.63, G4, 0.42, 0.85),
		(1.06, E4, 0.2, 0.7), (1.27, G4, 0.2, 0.75), (1.48, C5, 1.9, 0.9)]
	harmony = [(1.48, C4, 1.9, 0.5), (1.48, E4, 1.9, 0.5), (1.48, G4, 1.9, 0.5), (1.48, C3, 1.9, 0.6)]
	sparkle = [(1.48, C6, 0.8, 0.3), (1.62, E6, 0.8, 0.3), (1.76, G6, 0.8, 0.25)]
	return finish(mix(
		(melody(lead + harmony, brass), 1.0),
		(melody(sparkle, bell), 1.0),
	), 0.85)


@sfx("defeat")
def defeat(rng, v):
	lead = [(0.0, A3, 0.55, 0.85), (0.58, F3, 0.55, 0.8), (1.16, E3, 0.55, 0.8), (1.74, D3, 0.6, 0.8),
		(2.36, A2, 1.1, 0.95)]
	body = lowpass(melody(lead, brass), 1200)
	toll = (bell(1.3, A2, 0.3), 0.6, 2.36)
	return finish(echo(mix((body, 1.0), toll), 0.2, 0.2, 2), 0.8)


@sfx("endless_wave")
def endless_wave(rng, v):
	horn = mix(
		(brass(0.28, D3), 0.8),
		(brass(0.3, A3), 0.5),
		(brass(1.05, D3), 1.0, 0.33),
		(brass(1.05, A3), 0.6, 0.33),
		(brass(1.05, D4), 0.35, 0.33),
	)
	return finish(mix((horn, 1.0), (thud(0.45, 95, 42), 0.9, 0.33)), 0.8)


# --- Output ---

def file_stem(name, variant, variants):
	return f"{name}_{variant + 1}" if variants > 1 else name


def write_wav(path, samples, loop):
	"""Writes 16-bit mono PCM. Loops get a `smpl` chunk, which Godot's importer reads."""
	pcm = struct.pack(f"<{len(samples)}h", *(
		max(-32767, min(32767, int(round(s * 32767.0)))) for s in samples
	))
	fmt = struct.pack("<HHIIHH", 1, 1, SAMPLE_RATE, SAMPLE_RATE * 2, 2, 16)
	chunks = [b"fmt " + struct.pack("<I", len(fmt)) + fmt]
	chunks.append(b"data" + struct.pack("<I", len(pcm)) + pcm + (b"\0" if len(pcm) % 2 else b""))
	if loop:
		sample_period = 1000000000 // SAMPLE_RATE
		header = struct.pack("<9I", 0, 0, sample_period, 60, 0, 0, 0, 1, 0)
		loop_points = struct.pack("<6I", 0, 0, 0, len(samples) - 1, 0, 0)
		smpl = header + loop_points
		chunks.append(b"smpl" + struct.pack("<I", len(smpl)) + smpl)
	body = b"WAVE" + b"".join(chunks)
	path.write_bytes(b"RIFF" + struct.pack("<I", len(body)) + body)


def describe(stem, samples):
	"""Measures what can be checked without ears: length, level, and brightness."""
	peak = max(abs(s) for s in samples)
	rms = math.sqrt(sum(s * s for s in samples) / len(samples))
	crossings = sum(1 for a, b in zip(samples, samples[1:]) if (a < 0.0) != (b < 0.0))
	brightness = crossings / 2.0 / (len(samples) / SAMPLE_RATE)
	lead = next(i for i, s in enumerate(samples) if abs(s) >= peak * 0.01) / SAMPLE_RATE * 1000.0
	seam = abs(samples[-1] - samples[0])
	return (f"{stem:28s}{len(samples) / SAMPLE_RATE:6.2f}s  peak {peak:4.2f}  "
		f"rms {rms:5.3f}  ~{brightness:6.0f} Hz  lead {lead:4.1f} ms  seam {seam:5.3f}")


def main():
	parser = argparse.ArgumentParser(description="Synthesize the game's sound effects.")
	parser.add_argument("names", nargs="*", help="sounds to generate (default: all)")
	parser.add_argument("--report", action="store_true", help="print level statistics")
	args = parser.parse_args()

	unknown = [name for name in args.names if name not in RECIPES]
	if unknown:
		sys.exit(f"Unknown sounds: {', '.join(unknown)}")

	OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
	for name in args.names or RECIPES:
		recipe, variants, loop = RECIPES[name]
		for variant in range(variants):
			stem = file_stem(name, variant, variants)
			samples = recipe(random.Random(zlib.crc32(stem.encode())), variant)
			write_wav(OUTPUT_DIR / f"{stem}.wav", samples, loop)
			if args.report:
				print(describe(stem, samples))


if __name__ == "__main__":
	main()
