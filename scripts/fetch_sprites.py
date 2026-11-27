#!/usr/bin/env python3
"""Download official pixel Pokémon sprites into Resources/:
1. Pokémon Black & White animated battle sprites (Gen 1–5, #1–649) -> Resources/sprites/{id}.gif
2. Pokémon FireRed 2-frame party/box pixel icons (Gen 1–3, #1–386) -> Resources/sprites_firered/{id}.png
3. English species names (#1–649) -> Resources/names.json

Personal use only.
"""
import json
import os
import sys
import urllib.request
from concurrent.futures import ThreadPoolExecutor

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RES = os.path.join(ROOT, "Resources")
SPRITES_BW = os.path.join(RES, "sprites")
SPRITES_FR = os.path.join(RES, "sprites_firered")

MAX_BW_ID = 649
MAX_FR_ID = 386

BW_URL = ("https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/"
          "versions/generation-v/black-white/animated/{id}.gif")
FR_URL = "https://raw.githubusercontent.com/pret/pokefirered/master/graphics/pokemon/{slug}/icon.png"
NAMES_URL = f"https://pokeapi.co/api/v2/pokemon-species?limit={MAX_BW_ID}"

SPECIAL_NAMES = {
    "nidoran-f": "Nidoran♀",
    "nidoran-m": "Nidoran♂",
    "mr-mime": "Mr. Mime",
    "farfetchd": "Farfetch’d",
    "ho-oh": "Ho-Oh",
    "mime-jr": "Mime Jr.",
    "porygon-z": "Porygon-Z",
    "porygon2": "Porygon2",
    "flabebe": "Flabébé",
}


def pretty(name: str) -> str:
    if name in SPECIAL_NAMES:
        return SPECIAL_NAMES[name]
    return "-".join(p.capitalize() for p in name.split("-"))


def fetch(url: str) -> bytes:
    req = urllib.request.Request(url, headers={"User-Agent": "PokeRun-personal-build"})
    with urllib.request.urlopen(req, timeout=60) as r:
        return r.read()


def download_file(args):
    key, url, path = args
    if os.path.exists(path) and os.path.getsize(path) > 0:
        return key, True
    for _ in range(3):
        try:
            data = fetch(url)
            with open(path, "wb") as f:
                f.write(data)
            return key, True
        except Exception:
            continue
    return key, False


def main():
    os.makedirs(SPRITES_BW, exist_ok=True)
    os.makedirs(SPRITES_FR, exist_ok=True)

    slugs_path = os.path.join(RES, "slugs.json")
    names_path = os.path.join(RES, "names.json")

    if not os.path.exists(names_path) or not os.path.exists(slugs_path):
        data = json.loads(fetch(NAMES_URL))
        species = sorted(data["results"], key=lambda r: int(r["url"].rstrip("/").split("/")[-1]))[:MAX_BW_ID]
        raw_slugs = [r["name"] for r in species]
        names = [pretty(s) for s in raw_slugs]
        with open(names_path, "w", encoding="utf-8") as f:
            json.dump(names, f, ensure_ascii=False, indent=0)
        with open(slugs_path, "w", encoding="utf-8") as f:
            json.dump(raw_slugs, f, ensure_ascii=False, indent=0)
        print(f"names.json: {len(names)} names")
    else:
        with open(slugs_path, "r", encoding="utf-8") as f:
            raw_slugs = json.load(f)

    bw_tasks = [
        (f"bw:{i}", BW_URL.format(id=i), os.path.join(SPRITES_BW, f"{i}.gif"))
        for i in range(1, MAX_BW_ID + 1)
    ]
    def fr_slug(s: str) -> str:
        s = s.replace("-", "_")
        return "unown/a" if s == "unown" else s

    fr_tasks = [
        (
            f"fr:{i}",
            FR_URL.format(slug=fr_slug(raw_slugs[i - 1])),
            os.path.join(SPRITES_FR, f"{i}.png"),
        )
        for i in range(1, MAX_FR_ID + 1)
    ]

    with ThreadPoolExecutor(max_workers=16) as ex:
        bw_results = list(ex.map(download_file, bw_tasks))
        fr_results = list(ex.map(download_file, fr_tasks))

    bw_failed = [k for k, ok in bw_results if not ok]
    fr_failed = [k for k, ok in fr_results if not ok]
    print(f"B/W sprites:     {MAX_BW_ID - len(bw_failed)}/{MAX_BW_ID} ready")
    print(f"FireRed sprites: {MAX_FR_ID - len(fr_failed)}/{MAX_FR_ID} ready")
    if bw_failed or fr_failed:
        print("failed:", bw_failed + fr_failed)
        sys.exit(1)


if __name__ == "__main__":
    main()
