#!/usr/bin/env python3
"""Generate iOS assets + localization + Swift sound catalog from the Android AnimalSpin source.

Faithful port: parses models/Animals.kt for the *active* animal set (commented-out
"on ice"/"ponytail" entries are naturally skipped) and its clip mapping, so nothing is
transcribed by hand.
"""
import json
import os
import re
import shutil
import subprocess
import sys
import xml.etree.ElementTree as ET

SRC = "/Users/kylefalconer/Code/AnimalSpin"
DST = "/Volumes/Sandisk1TB/Code/AnimalSpin-iOS"
RES = os.path.join(SRC, "app/src/main/res")
ANIMALS_KT = os.path.join(SRC, "app/src/main/java/com/circuitstitch/toys/models/Animals.kt")

# --- Android drawable -> source jpg filename (from res/drawable) -----------------
DRAWABLE_FILE = {
    "bear": "bear.jpg", "cat_1": "cat_1.jpg", "hen_chicken": "hen_chicken.jpg",
    "cicada": "cicada.jpg", "cow_female_black_white": "cow_female_black_white.jpg",
    "cricket": "cricket.jpg", "crow": "crow.jpg", "dog_1": "dog_1.jpg",
    "donkey_in_clovelly_north_devon_england": "donkey_in_clovelly_north_devon_england.jpg",
    "mallard_duck": "mallard_duck.jpg", "frog": "frog.jpg", "goat_white": "goat_white.jpg",
    "goose": "goose.jpg", "domestic_horse_essenpas_bemmel": "domestic_horse_essenpas_bemmel.jpg",
    "hyena": "hyena.jpg", "young_african_lion_33560925282": "young_african_lion_33560925282.jpg",
    "monkey_portrait_animal": "monkey_portrait_animal.jpg", "tawny_owl": "tawny_owl.jpg",
    "parrot": "parrot.jpg", "peacock": "peacock.jpg", "pig": "pig.jpg",
    "pexels_ellie_burgin_10895600": "pexels_ellie_burgin_10895600.jpg",
    "squirrel": "squirrel.jpg", "tiger": "tiger.jpg",
}


def parse_animals_kt():
    """Return (animals, sounds).
    animals: list of dicts {enum, key(lowercase rawValue), drawable, tts_key} in declaration order.
    sounds:  dict enum -> [clip_stem, ...] in declaration order.
    """
    text = open(ANIMALS_KT).read()
    animals = []
    # enum entries look like:  BEAR(R.drawable.bear, R.string.tts_bear_says),
    # Commented lines start with // so they never match this anchored pattern.
    enum_re = re.compile(r'^\s*([A-Z][A-Z_]*)\(R\.drawable\.(\w+),\s*R\.string\.(\w+)\)', re.M)
    for m in enum_re.finditer(text):
        enum, drawable, tts = m.group(1), m.group(2), m.group(3)
        animals.append({
            "enum": enum,
            "key": enum.lower(),
            "drawable": drawable,
            "tts_key": tts,
        })
    sound_re = re.compile(r'AnimalNoise\(Animal\.([A-Z_]+),\s*R\.raw\.(\w+)\)')
    sounds = {}
    for m in sound_re.finditer(text):
        sounds.setdefault(m.group(1), []).append(m.group(2))
    return animals, sounds


def android_unescape(s):
    return s.replace("\\'", "'").replace('\\"', '"').replace("\\@", "@").replace("\\n", "\n").strip()


def load_strings(path):
    """Return dict name->value for an Android strings.xml (skips non-<string>)."""
    out = {}
    if not os.path.exists(path):
        return out
    tree = ET.parse(path)
    for el in tree.getroot():
        if el.tag != "string":
            continue
        name = el.get("name")
        # ElementTree already resolved XML entities; join text (no nested markup here)
        val = el.text or ""
        v = android_unescape(val)
        # strip a fully-wrapping pair of double quotes (Android literal quoting)
        if len(v) >= 2 and v[0] == '"' and v[-1] == '"':
            v = v[1:-1]
        out[name] = v
    return out


def build_xcstrings(dst_path):
    base = load_strings(os.path.join(RES, "values/strings.xml"))
    locales = ["ar", "de", "es", "fr", "hi", "id", "it", "ja", "ko",
               "nl", "pl", "pt", "ru", "th", "tr", "vi"]
    per_locale = {loc: load_strings(os.path.join(RES, f"values-{loc}/strings.xml")) for loc in locales}

    # union of all keys, base order first
    keys = list(base.keys())
    for loc in locales:
        for k in per_locale[loc]:
            if k not in keys:
                keys.append(k)

    strings = {}
    for k in keys:
        locs = {}
        if k in base:
            locs["en"] = {"stringUnit": {"state": "translated", "value": base[k]}}
        for loc in locales:
            if k in per_locale[loc]:
                locs[loc] = {"stringUnit": {"state": "translated", "value": per_locale[loc][k]}}
        strings[k] = {"localizations": locs}

    catalog = {"sourceLanguage": "en", "strings": strings, "version": "1.0"}
    with open(dst_path, "w") as f:
        json.dump(catalog, f, ensure_ascii=False, indent=2)
    return len(keys), locales


def write_json(path, obj):
    with open(path, "w") as f:
        json.dump(obj, f, indent=2)
        f.write("\n")


def main():
    animals, sounds = parse_animals_kt()
    print(f"active animals: {len(animals)}")
    total_clips = sum(len(sounds[a['enum']]) for a in animals)
    print(f"active clips:   {total_clips}")

    res_dir = os.path.join(DST, "Sources/Resources")
    assets = os.path.join(res_dir, "Assets.xcassets")
    sounds_dir = os.path.join(res_dir, "Sounds")

    # clean+recreate generated resource trees
    for p in (assets, sounds_dir):
        if os.path.exists(p):
            shutil.rmtree(p)
    os.makedirs(assets)
    os.makedirs(sounds_dir)

    write_json(os.path.join(assets, "Contents.json"), {"info": {"author": "xcode", "version": 1}})

    # --- image sets (named by enum rawValue, e.g. "bear") --------------------
    for a in animals:
        fn = DRAWABLE_FILE[a["drawable"]]
        srcimg = os.path.join(RES, "drawable", fn)
        setdir = os.path.join(assets, f"{a['key']}.imageset")
        os.makedirs(setdir)
        shutil.copy2(srcimg, os.path.join(setdir, fn))
        write_json(os.path.join(setdir, "Contents.json"), {
            "images": [{"filename": fn, "idiom": "universal"}],
            "info": {"author": "xcode", "version": 1},
        })
    print(f"imagesets written: {len(animals)}")

    # --- AppIcon (upscale 512 playstore png -> 1024) -------------------------
    iconset = os.path.join(assets, "AppIcon.appiconset")
    os.makedirs(iconset)
    src_icon = os.path.join(SRC, "app/src/debug/ic_launcher-playstore.png")
    out_icon = os.path.join(iconset, "AppIcon.png")
    subprocess.run(["sips", "-z", "1024", "1024", src_icon, "--out", out_icon],
                   check=True, capture_output=True)
    write_json(os.path.join(iconset, "Contents.json"), {
        "images": [{"filename": "AppIcon.png", "idiom": "universal",
                    "platform": "ios", "size": "1024x1024"}],
        "info": {"author": "xcode", "version": 1},
    })

    # --- AccentColor ---------------------------------------------------------
    accent = os.path.join(assets, "AccentColor.colorset")
    os.makedirs(accent)
    write_json(os.path.join(accent, "Contents.json"), {
        "colors": [{"idiom": "universal", "color": {"color-space": "srgb",
                    "components": {"red": "0.384", "green": "0.0", "blue": "0.933", "alpha": "1.000"}}}],
        "info": {"author": "xcode", "version": 1},
    })

    # --- audio clips ---------------------------------------------------------
    copied = 0
    missing = []
    for a in animals:
        for clip in sounds[a["enum"]]:
            src = os.path.join(RES, "raw", clip + ".mp3")
            if not os.path.exists(src):
                missing.append(clip)
                continue
            shutil.copy2(src, os.path.join(sounds_dir, clip + ".mp3"))
            copied += 1
    print(f"audio copied:   {copied}")
    if missing:
        print("MISSING CLIPS:", missing); sys.exit(1)

    # --- String Catalog ------------------------------------------------------
    nkeys, locales = build_xcstrings(os.path.join(res_dir, "Localizable.xcstrings"))
    print(f"xcstrings keys: {nkeys}  locales: en+{len(locales)}")

    # --- generated Swift sound catalog --------------------------------------
    gen = os.path.join(DST, "Sources/Models/AnimalSounds.generated.swift")
    os.makedirs(os.path.dirname(gen), exist_ok=True)
    lines = [
        "// Generated by tools/gen_assets.py from the Android AnimalSpin source. Do not edit by hand.",
        "// Maps each Animal to its recorded clip resource names (mp3 in the app bundle).",
        "",
        "enum AnimalSounds {",
        "    /// Clip resource names (without extension) for each animal, in source order.",
        "    static let clips: [Animal: [String]] = [",
    ]
    for a in animals:
        clips = sounds[a["enum"]]
        clip_lits = ", ".join(f'"{c}"' for c in clips)
        lines.append(f"        .{a['key']}: [{clip_lits}],")
    lines.append("    ]")
    lines.append("}")
    lines.append("")
    with open(gen, "w") as f:
        f.write("\n".join(lines))
    print(f"wrote {gen}")

    # emit the ordered enum-case list so the hand-written enum can be verified
    print("ENUM_ORDER:", ",".join(a["key"] for a in animals))


if __name__ == "__main__":
    main()
