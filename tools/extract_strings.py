"""Collects the game's player-facing text into locale/messages.pot.

    python tools/extract_strings.py

A translator opens the template in Poedit (or any gettext editor), saves a
.po per language, and it goes in Project Settings > Localization. Godot
translates a Label's or Button's text by looking it up as a key, and the
formatted lines go through tr() first, so the template's msgids are the
English strings themselves. Picked up:
- tr("...") templates in scripts
- English-looking string literals in the UI and run scripts (two or more
  words, or a capitalized word), skipping paths, ids and debug text
- names and descriptions in the data .tres files
"""

import glob
import os
import re

ROOT = os.path.join(os.path.dirname(__file__), "..")
OUT = os.path.join(ROOT, "locale", "messages.pot")
SCRIPT_DIRS = ["scripts/ui", "scripts/run", "scripts/data", "scripts"]
SKIP_SCRIPTS = {"scripts/debug/benchmark.gd"}
STRING = re.compile(r'"((?:[^"\\]|\\.)*)"')
DATA_FIELDS = re.compile(
    r'^(display_name|description|evolved_name|level_descriptions|tier_names) = (.*)$', re.M)


def looks_like_text(s):
    if not s or s.startswith(("res://", "user://", "%", "#")) or "_" in s.split(" ")[0]:
        return False
    if re.fullmatch(r"[a-z0-9_./:{}\- ]*", s):  # ids, actions, paths, sfx names
        return False
    return bool(re.search(r"[A-Za-z]{2,}", s)) and (" " in s or s[:1].isupper())


def scripts():
    seen = set()
    for folder in SCRIPT_DIRS:
        for path in sorted(glob.glob(os.path.join(ROOT, folder, "*.gd"))):
            rel = os.path.relpath(path, ROOT).replace("\\", "/")
            if rel in SKIP_SCRIPTS or rel in seen:
                continue
            seen.add(rel)
            for number, line in enumerate(open(path, encoding="utf-8"), 1):
                code = line.split("#")[0] if '"' not in line.split("#")[0] else line
                if line.strip().startswith(("#", "##")) or "print(" in line or "push_" in line \
                        or "sfx(" in line or "preload(" in line or "load(" in line:
                    continue
                for match in STRING.finditer(code):
                    text = match.group(1)
                    if looks_like_text(text):
                        yield text, f"{rel}:{number}"


def data():
    for path in sorted(glob.glob(os.path.join(ROOT, "data", "**", "*.tres"), recursive=True)):
        rel = os.path.relpath(path, ROOT).replace("\\", "/")
        for match in DATA_FIELDS.finditer(open(path, encoding="utf-8").read()):
            for text in STRING.findall(match.group(2)):
                if text:
                    yield text, rel


def escape(text):
    return text.replace('"', '\\"') if '\\"' not in text else text


if __name__ == "__main__":
    entries = {}
    for text, where in list(scripts()) + list(data()):
        entries.setdefault(text, []).append(where)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8", newline="\n") as out:
        out.write('msgid ""\nmsgstr ""\n"Content-Type: text/plain; charset=UTF-8\\n"\n\n')
        for text, places in entries.items():
            out.write("#: " + " ".join(places[:4]) + "\n")
            out.write(f'msgid "{escape(text)}"\nmsgstr ""\n\n')
    print(f"{len(entries)} strings -> {os.path.relpath(OUT, ROOT)}")
