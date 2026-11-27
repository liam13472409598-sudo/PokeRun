#!/usr/bin/env python3
"""Download official pixel Pokémon sprites across 5 iconic series into Resources/:
1. Black & White (Gen 5, #1–649)        -> Resources/sprites/{id}.gif
2. FireRed (Gen 3, #1–386)              -> Resources/sprites_firered/{id}.png
3. HeartGold & SoulSilver (Gen 4, #1–493)-> Resources/sprites_hgss/{id}.png
4. Emerald (Gen 3, #1–386)              -> Resources/sprites_emerald/{id}.png
5. Crystal (Gen 2, #1–251)              -> Resources/sprites_crystal/{id}.gif
6. English species names (#1–649)       -> Resources/names.json

Personal use only.
"""
import json
import os
import struct
import subprocess
import sys
import urllib.request
import zlib
from concurrent.futures import ThreadPoolExecutor

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RES = os.path.join(ROOT, "Resources")
SPRITES_BW = os.path.join(RES, "sprites")
SPRITES_FR = os.path.join(RES, "sprites_firered")
SPRITES_HGSS = os.path.join(RES, "sprites_hgss")
SPRITES_EM = os.path.join(RES, "sprites_emerald")
SPRITES_CRY = os.path.join(RES, "sprites_crystal")

MAX_BW_ID = 649
MAX_FR_ID = 386
MAX_HGSS_ID = 493
MAX_EM_ID = 386
MAX_CRY_ID = 251

BW_URL = ("https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/"
          "versions/generation-v/black-white/animated/{id}.gif")
FR_URL = "https://raw.githubusercontent.com/pret/pokefirered/master/graphics/pokemon/{slug}/icon.png"
HGSS_URL = ("https://raw.githubusercontent.com/rh-hideout/pokeemerald-expansion/master/"
            "graphics/pokemon/{slug}/overworld.png")
EM_URL = "https://raw.githubusercontent.com/pret/pokeemerald/master/graphics/pokemon/{slug}/anim_front.png"
CRY_URL = ("https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/"
           "versions/generation-ii/crystal/animated/{id}.gif")
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
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "PokeRun-personal-build"})
        with urllib.request.urlopen(req, timeout=45) as r:
            return r.read()
    except Exception:
        return subprocess.check_output(["curl", "-sSfL", "--max-time", "45", url])


def ensure_index0_transparent(png: bytes) -> bytes:
    """For indexed-palette PNGs without a tRNS chunk, mark palette index 0 as transparent."""
    if not png.startswith(b"\x89PNG\r\n\x1a\n"):
        return png
    pos = 8
    chunks = []
    color_type = None
    has_trns = False
    while pos + 8 <= len(png):
        length = struct.unpack(">I", png[pos:pos + 4])[0]
        ctype = png[pos + 4:pos + 8]
        cdata = png[pos + 8:pos + 8 + length]
        ccrc = png[pos + 8 + length:pos + 12 + length]
        chunks.append((ctype, cdata, ccrc))
        if ctype == b"IHDR" and len(cdata) >= 10:
            color_type = cdata[9]
        elif ctype == b"tRNS":
            has_trns = True
        pos += 12 + length
    if color_type != 3 or has_trns:
        return png
    out = bytearray(b"\x89PNG\r\n\x1a\n")
    trns_body = b"tRNS\x00"
    trns_chunk = struct.pack(">I", 1) + trns_body + struct.pack(">I", zlib.crc32(trns_body) & 0xFFFFFFFF)
    for ctype, cdata, ccrc in chunks:
        out += struct.pack(">I", len(cdata)) + ctype + cdata + ccrc
        if ctype == b"PLTE":
            out += trns_chunk
    return bytes(out)


def download_file(args):
    key, url, path, index0_trns = args
    if os.path.exists(path) and os.path.getsize(path) > 0:
        return key, True
    for _ in range(3):
        try:
            data = fetch(url)
            if index0_trns:
                data = ensure_index0_transparent(data)
            with open(path, "wb") as f:
                f.write(data)
            return key, True
        except Exception:
            continue
    return key, False


def main():
    for d in [SPRITES_BW, SPRITES_FR, SPRITES_HGSS, SPRITES_EM, SPRITES_CRY]:
        os.makedirs(d, exist_ok=True)

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
    else:
        with open(slugs_path, "r", encoding="utf-8") as f:
            raw_slugs = json.load(f)

    def fr_slug(s: str) -> str:
        s = s.replace("-", "_")
        return "unown/a" if s == "unown" else s

    def em_slug(s: str) -> str:
        s = s.replace("-", "_")
        if s == "unown":
            return "unown/a"
        if s == "castform":
            return "castform/normal"
        return s

    def hgss_slug(s: str) -> str:
        s = s.replace("-", "_")
        if s == "meloetta":
            return "meloetta/aria"
        return s

    sets = [
        ("B/W", [(f"bw:{i}", BW_URL.format(id=i), os.path.join(SPRITES_BW, f"{i}.gif"), False)
                 for i in range(1, MAX_BW_ID + 1)]),
        ("FireRed", [(f"fr:{i}", FR_URL.format(slug=fr_slug(raw_slugs[i - 1])),
                      os.path.join(SPRITES_FR, f"{i}.png"), False)
                     for i in range(1, MAX_FR_ID + 1)]),
        ("HGSS", [(f"hgss:{i}", HGSS_URL.format(slug=hgss_slug(raw_slugs[i - 1])),
                   os.path.join(SPRITES_HGSS, f"{i}.png"), True)
                  for i in range(1, MAX_HGSS_ID + 1)]),
        ("Emerald", [(f"em:{i}", EM_URL.format(slug=em_slug(raw_slugs[i - 1])),
                      os.path.join(SPRITES_EM, f"{i}.png"), False)
                     for i in range(1, MAX_EM_ID + 1)]),
        ("Crystal", [(f"cry:{i}", CRY_URL.format(id=i), os.path.join(SPRITES_CRY, f"{i}.gif"), False)
                     for i in range(1, MAX_CRY_ID + 1)]),
    ]

    all_failed = []
    with ThreadPoolExecutor(max_workers=16) as ex:
        for label, tasks in sets:
            results = list(ex.map(download_file, tasks))
            failed = [k for k, ok in results if not ok]
            print(f"{label:8s} sprites: {len(tasks) - len(failed)}/{len(tasks)} ready")
            all_failed.extend(failed)

    if all_failed:
        print("failed:", all_failed)
        sys.exit(1)


if __name__ == "__main__":
    main()
