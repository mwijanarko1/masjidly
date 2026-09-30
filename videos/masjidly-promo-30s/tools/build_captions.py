#!/usr/bin/env python3
"""Single source for the typed caption rail.

Writes the BEATS table into compositions/v2/caption.html (between the BEATS markers)
and renders assets/audio/typing.wav with one keystroke per typed character, so the
sound always matches what the caption types. Run from the project root.
"""
import json
import random
import re
import struct
import subprocess
import wave

DURATION = 55.0
RATE = 44100
TYPE_CPS = 36
ERASE_CPS = 70

# v6: captions overlay the app (no cards), centered in its empty space; "inks" follow the sky.
W, K = "#FFFFFF", "#111111"
GOLD, NAVY = "#FFD27A", "#1E3F8F"
GAP = 1093  # top of a two-line block centered in the gap between the iqamah line and the prayer name
BEATS = [
    {"l1": [["calculated times drift."]], "t1": 2.9, "l2": [["yours come from "], ["your masjid.", 1]], "t2": 4.6, "erase": 7.4, "cut": 1, "top": GAP, "inks": [[0, W, GOLD]]},
    {"l1": [["prayer times, "], ["redesigned.", 1]], "t1": 7.8, "l2": [["adhan and iqamah at a glance."]], "t2": 8.6, "erase": 13.4, "cut": 1, "top": GAP, "inks": [[0, W, GOLD], [9.35, K, NAVY], [12.55, W, GOLD]]},
    {"l1": [["in "], ["your", 1], [" language."]], "t1": 14.4, "l2": [["right to left, too."]], "t2": 15.5, "erase": 19.6, "cut": 1, "top": GAP, "inks": [[0, K, NAVY]]},
    {"l1": [["add all your "], ["masjids.", 1]], "t1": 20.5, "l2": [["switch in "], ["one tap.", 1]], "t2": 21.4, "erase": 26.2, "cut": 1, "top": 1680, "inks": [[0, K, NAVY]]},
    {"l1": [["make it "], ["yours.", 1]], "t1": 26.6, "l2": [["your theme, or your own colours."]], "t2": 27.4, "erase": 31.3, "cut": 1, "top": 150, "inks": [[0, K, NAVY]]},
    {"l1": [["never miss "], ["iqamah.", 1]], "t1": 32.9, "l2": [["the "], ["adhan", 1], [", right on time."]], "t2": 34.5, "erase": 36.3, "cut": 1, "top": 1440, "inks": [[0, K, NAVY]]},
    {"l1": [["on your "], ["home screen", 1], ["."]], "t1": 36.9, "l2": [["and your "], ["lock screen.", 1]], "t2": 40.3, "erase": 42.6, "cut": 1, "top": 110, "inks": [[0, W, GOLD]]},
    {"l1": [["the "], ["night", 1], [", worked out."]], "t1": 43.6, "l2": [["midnight and the "], ["last third.", 1]], "t2": 44.4, "erase": 47.3, "cut": 1, "top": 110, "inks": [[0, W, GOLD]]},
    {"l1": [["masjids in 10 countries."]], "t1": 48.4, "l2": [["and "], ["more every week.", 1]], "t2": 49.4, "erase": 51.4, "cut": 1, "top": 1540, "inks": [[0, W, GOLD]]},
    {"l1": [["your masjid. "], ["your times.", 1]], "t1": 52.3, "l2": None, "t2": 0, "erase": 99, "cut": 1, "top": 985, "size": 60, "inks": [[0, W, GOLD]]},
]


def text_of(segs):
    return "".join(s[0] for s in segs) if segs else ""


def key_events():
    """(time, gain) for every keystroke the caption renders."""
    events = []
    for b in BEATS:
        for line, start in ((b["l1"], b["t1"]), (b["l2"], b["t2"])):
            txt = text_of(line)
            for i, ch in enumerate(txt):
                t = start + (i + 1) / TYPE_CPS
                if t < b["erase"]:
                    events.append((t, 0.55 if ch == " " else 1.0))
        if b["erase"] < DURATION and not b.get("cut"):
            typed = sum(min(len(text_of(l)), int(max(0.0, b["erase"] - s) * TYPE_CPS)) for l, s in ((b["l1"], b["t1"]), (b["l2"], b["t2"])) if l)
            for k in range(0, typed, 2):
                events.append((b["erase"] + (k + 1) / ERASE_CPS, 0.45))
    return sorted(events)


def load_key(path):
    raw = subprocess.check_output(["ffmpeg", "-v", "error", "-i", path, "-f", "s16le", "-ac", "1", "-ar", str(RATE), "-"])
    return list(struct.unpack("<%dh" % (len(raw) // 2), raw))


def render_typing(out_path):
    keys = [load_key("assets/sfx/keys/key-%d.wav" % i) for i in range(1, 11)]
    rng = random.Random(1447)
    mix = [0.0] * int(DURATION * RATE)
    for t, gain in key_events():
        k = rng.choice(keys)
        g = gain * rng.uniform(0.75, 1.0)
        start = int(t * RATE)
        for j, v in enumerate(k):
            if start + j < len(mix):
                mix[start + j] += v * g
    peak = max(1.0, max(abs(v) for v in mix))
    scale = min(1.0, 29000 / peak)
    with wave.open(out_path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(max(-32767, min(32767, v * scale)))) for v in mix))


def write_beats(html_path):
    src = open(html_path, encoding="utf-8").read()
    js = "const beats = " + json.dumps(BEATS, ensure_ascii=False) + ";"
    new, n = re.subn(r"/\*BEATS\*/.*?/\*END BEATS\*/", "/*BEATS*/ " + js + " /*END BEATS*/", src, flags=re.S)
    assert n == 1, "BEATS markers not found in " + html_path
    open(html_path, "w", encoding="utf-8").write(new)


if __name__ == "__main__":
    write_beats("compositions/v2/caption.html")
    render_typing("assets/audio/typing.wav")
    print("beats:", len(BEATS), "keystrokes:", len(key_events()))
