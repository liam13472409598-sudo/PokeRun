#!/usr/bin/env python3
"""Download official pixel & animated Pokémon sprites across 7 series (3,215 runners total!):
1. Black & White (Gen 5, #1–649)               -> Resources/sprites/{id}.gif
2. FireRed (Gen 3, #1–386)                     -> Resources/sprites_firered/{id}.png
3. Sun & Moon · Alola (Gen 7 #722–809 + Alola) -> Resources/sprites_alola/{id}.gif
4. Alola & Gen 6–9 Pixel (#650–1025 + Alola)   -> Resources/sprites_modern/{id}.png
5. Overworld Walking (#1–1025 + Alola)         -> Resources/sprites_hgss/{id}.png
6. Emerald (Gen 3, #1–386)                     -> Resources/sprites_emerald/{id}.png
7. Crystal (Gen 2, #1–251)                     -> Resources/sprites_crystal/{id}.gif
8. Species names (#1–1025 + 18 Alolan forms)   -> Resources/names.json

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
SPRITES_ALOLA = os.path.join(RES, "sprites_alola")
SPRITES_MODERN = os.path.join(RES, "sprites_modern")
SPRITES_HGSS = os.path.join(RES, "sprites_hgss")
SPRITES_EM = os.path.join(RES, "sprites_emerald")
SPRITES_CRY = os.path.join(RES, "sprites_crystal")

MAX_NATIONAL_ID = 1025
MAX_BW_ID = 649
MAX_FR_ID = 386
MAX_EM_ID = 386
MAX_CRY_ID = 251

# 18 Official Alolan Regional Forms mapped to IDs 1026..1043
# (runner_id, base_dex_id, display_name, pe_exp_subpath, pokeapi_pokemon_id)
ALOLA_FORMS = [
    (1026, 19,  "Alolan Rattata",   "rattata/alola",   10091),
    (1027, 20,  "Alolan Raticate",  "raticate/alola",  10092),
    (1028, 26,  "Alolan Raichu",    "raichu/alola",    10100),
    (1029, 27,  "Alolan Sandshrew", "sandshrew/alola", 10101),
    (1030, 28,  "Alolan Sandslash", "sandslash/alola", 10102),
    (1031, 37,  "Alolan Vulpix",    "vulpix/alola",    10103),
    (1032, 38,  "Alolan Ninetales", "ninetales/alola", 10104),
    (1033, 50,  "Alolan Diglett",   "diglett/alola",   10105),
    (1034, 51,  "Alolan Dugtrio",   "dugtrio/alola",   10106),
    (1035, 52,  "Alolan Meowth",    "meowth/alola",    10107),
    (1036, 53,  "Alolan Persian",   "persian/alola",   10108),
    (1037, 74,  "Alolan Geodude",   "geodude/alola",   10109),
    (1038, 75,  "Alolan Graveler",  "graveler/alola",  10110),
    (1039, 76,  "Alolan Golem",     "golem/alola",     10111),
    (1040, 88,  "Alolan Grimer",    "grimer/alola",    10112),
    (1041, 89,  "Alolan Muk",       "muk/alola",       10113),
    (1042, 103, "Alolan Exeggutor", "exeggutor/alola", 10114),
    (1043, 105, "Alolan Marowak",   "marowak/alola",   10115),
]

BW_URL = ("https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/"
          "versions/generation-v/black-white/animated/{id}.gif")
FR_URL = "https://raw.githubusercontent.com/pret/pokefirered/master/graphics/pokemon/{slug}/icon.png"
PE_EXP_BASE = "https://raw.githubusercontent.com/rh-hideout/pokeemerald-expansion/master/graphics/pokemon"
EM_URL = "https://raw.githubusercontent.com/pret/pokeemerald/master/graphics/pokemon/{slug}/anim_front.png"
CRY_URL = ("https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/"
           "versions/generation-ii/crystal/animated/{id}.gif")
SHOWDOWN_URL = "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/showdown/{id}.gif"
PNG_FALLBACK_URL = "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/{id}.png"
NAMES_URL = f"https://pokeapi.co/api/v2/pokemon-species?limit={MAX_NATIONAL_ID}"

SPECIAL_NAMES = {
    "nidoran-f": "Nidoran♀",
    "nidoran-m": "Nidoran♂",
    "mr-mime": "Mr. Mime",
    "mr-rime": "Mr. Rime",
    "farfetchd": "Farfetch’d",
    "sirfetchd": "Sirfetch’d",
    "ho-oh": "Ho-Oh",
    "mime-jr": "Mime Jr.",
    "porygon-z": "Porygon-Z",
    "porygon2": "Porygon2",
    "flabebe": "Flabébé",
    "type-null": "Type: Null",
    "jangmo-o": "Jangmo-o",
    "hakamo-o": "Hakamo-o",
    "kommo-o": "Kommo-o",
    "tapu-koko": "Tapu Koko",
    "tapu-lele": "Tapu Lele",
    "tapu-bulu": "Tapu Bulu",
    "tapu-fini": "Tapu Fini",
    "great-tusk": "Great Tusk",
    "scream-tail": "Scream Tail",
    "brute-bonnet": "Brute Bonnet",
    "flutter-mane": "Flutter Mane",
    "slither-wing": "Slither Wing",
    "sandy-shocks": "Sandy Shocks",
    "iron-treads": "Iron Treads",
    "iron-bundle": "Iron Bundle",
    "iron-hands": "Iron Hands",
    "iron-jugulis": "Iron Jugulis",
    "iron-moth": "Iron Moth",
    "iron-thorns": "Iron Thorns",
    "wo-chien": "Wo-Chien",
    "chien-pao": "Chien-Pao",
    "ting-lu": "Ting-Lu",
    "chi-yu": "Chi-Yu",
    "roaring-moon": "Roaring Moon",
    "iron-valiant": "Iron Valiant",
    "walking-wake": "Walking Wake",
    "iron-leaves": "Iron Leaves",
    "gouging-fire": "Gouging Fire",
    "raging-bolt": "Raging Bolt",
    "iron-boulder": "Iron Boulder",
    "iron-crown": "Iron Crown",
}

# Candidate subdirectories in pokeemerald-expansion for species with form folders
PE_EXP_FORM_SUBDIRS = {
    "basculin": ["basculin", "basculin/red_striped"],
    "darmanitan": ["darmanitan", "darmanitan/standard"],
    "tornadus": ["tornadus", "tornadus/incarnate"],
    "thundurus": ["thundurus", "thundurus/incarnate"],
    "landorus": ["landorus", "landorus/incarnate"],
    "keldeo": ["keldeo", "keldeo/ordinary"],
    "meloetta": ["meloetta", "meloetta/aria"],
    "flabebe": ["flabebe", "flabebe/red_flower", "flabebe/red"],
    "floette": ["floette", "floette/red_flower", "floette/red"],
    "florges": ["florges", "florges/red_flower", "florges/red"],
    "meowstic": ["meowstic", "meowstic/male", "meowstic/m"],
    "aegislash": ["aegislash", "aegislash/shield"],
    "pumpkaboo": ["pumpkaboo", "pumpkaboo/average"],
    "gourgeist": ["gourgeist", "gourgeist/average"],
    "zygarde": ["zygarde", "zygarde/50"],
    "hoopa": ["hoopa", "hoopa/confined"],
    "oricorio": ["oricorio", "oricorio/baile"],
    "lycanroc": ["lycanroc", "lycanroc/midday"],
    "wishiwashi": ["wishiwashi", "wishiwashi/solo"],
    "minior": ["minior", "minior/meteor", "minior/core_red", "minior/core"],
    "mimikyu": ["mimikyu", "mimikyu/disguised"],
    "toxtricity": ["toxtricity", "toxtricity/amped"],
    "sinistea": ["sinistea", "sinistea/phony"],
    "polteageist": ["polteageist", "polteageist/phony"],
    "alcremie": ["alcremie", "alcremie/strawberry"],
    "eiscue": ["eiscue", "eiscue/ice", "eiscue/ice_face"],
    "indeedee": ["indeedee", "indeedee/male", "indeedee/m"],
    "morpeko": ["morpeko", "morpeko/full_belly"],
    "urshifu": ["urshifu", "urshifu/single_strike"],
    "basculegion": ["basculegion", "basculegion/male", "basculegion/m"],
    "enamorus": ["enamorus", "enamorus/incarnate"],
    "oinkologne": ["oinkologne", "oinkologne/male", "oinkologne/m"],
    "maushold": ["maushold", "maushold/family_of_four", "maushold/four"],
    "squawkabilly": ["squawkabilly", "squawkabilly/green_plumage", "squawkabilly/green"],
    "palafin": ["palafin", "palafin/zero"],
    "tatsugiri": ["tatsugiri", "tatsugiri/curly"],
    "dudunsparce": ["dudunsparce", "dudunsparce/two_segment"],
    "gimmighoul": ["gimmighoul", "gimmighoul/chest"],
    "poltchageist": ["poltchageist", "poltchageist/counterfeit"],
    "sinistcha": ["sinistcha", "sinistcha/unremarkable"],
    "ogerpon": ["ogerpon", "ogerpon/teal_mask", "ogerpon/teal"],
    "terapagos": ["terapagos", "terapagos/normal"],
}


def pretty(name: str) -> str:
    if name in SPECIAL_NAMES:
        return SPECIAL_NAMES[name]
    return "-".join(p.capitalize() for p in name.split("-"))


def fetch(url: str) -> bytes:
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "PokeRun-personal-build"})
        with urllib.request.urlopen(req, timeout=30) as r:
            return r.read()
    except Exception:
        return subprocess.check_output(["curl", "-sSfL", "--max-time", "30", url], stderr=subprocess.DEVNULL)


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


def download_candidates(args):
    key, urls, path, index0_trns = args
    if os.path.exists(path) and os.path.getsize(path) > 0:
        return key, True
    for _ in range(2):
        for url in urls:
            try:
                data = fetch(url)
                if len(data) < 64:
                    continue
                if index0_trns:
                    data = ensure_index0_transparent(data)
                with open(path, "wb") as f:
                    f.write(data)
                return key, True
            except Exception:
                continue
    return key, False


def pe_exp_candidates(raw_slug: str, filenames):
    base = raw_slug.replace("-", "_")
    subdirs = PE_EXP_FORM_SUBDIRS.get(base, [base])
    urls = []
    for sub in subdirs:
        for fn in filenames:
            urls.append(f"{PE_EXP_BASE}/{sub}/{fn}")
    return urls


def main():
    for d in [SPRITES_BW, SPRITES_FR, SPRITES_ALOLA, SPRITES_MODERN, SPRITES_HGSS, SPRITES_EM, SPRITES_CRY]:
        os.makedirs(d, exist_ok=True)

    slugs_path = os.path.join(RES, "slugs.json")
    names_path = os.path.join(RES, "names.json")

    need_refresh = True
    if os.path.exists(names_path) and os.path.exists(slugs_path):
        with open(names_path, "r", encoding="utf-8") as f:
            existing_names = json.load(f)
        if len(existing_names) >= MAX_NATIONAL_ID + len(ALOLA_FORMS):
            need_refresh = False
            with open(slugs_path, "r", encoding="utf-8") as sf:
                raw_slugs = json.load(sf)

    if need_refresh:
        data = json.loads(fetch(NAMES_URL))
        species = sorted(data["results"], key=lambda r: int(r["url"].rstrip("/").split("/")[-1]))[:MAX_NATIONAL_ID]
        raw_slugs = [r["name"] for r in species]
        names = [pretty(s) for s in raw_slugs] + [entry[2] for entry in ALOLA_FORMS]
        with open(names_path, "w", encoding="utf-8") as f:
            json.dump(names, f, ensure_ascii=False, indent=0)
        with open(slugs_path, "w", encoding="utf-8") as f:
            json.dump(raw_slugs, f, ensure_ascii=False, indent=0)
        print(f"names.json updated: {len(names)} entries (#001–#1025 + 18 Alolan forms)")

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

    # 1. B/W (1..649)
    bw_tasks = [(f"bw:{i}", [BW_URL.format(id=i)], os.path.join(SPRITES_BW, f"{i}.gif"), False)
                for i in range(1, MAX_BW_ID + 1)]

    # 2. FireRed (1..386)
    fr_tasks = [(f"fr:{i}", [FR_URL.format(slug=fr_slug(raw_slugs[i - 1]))],
                 os.path.join(SPRITES_FR, f"{i}.png"), False)
                for i in range(1, MAX_FR_ID + 1)]

    # 3. Sun & Moon · Alola Animated (722..809 + 1026..1043 = 106 Gen 7 Alola runners)
    alola_tasks = [
        (f"alola:{i}", [SHOWDOWN_URL.format(id=i)], os.path.join(SPRITES_ALOLA, f"{i}.gif"), False)
        for i in range(722, 810)
    ] + [
        (f"alola:{rid}", [SHOWDOWN_URL.format(id=paid)], os.path.join(SPRITES_ALOLA, f"{rid}.gif"), False)
        for (rid, _, _, _, paid) in ALOLA_FORMS
    ]

    # 4. Alola & Gen 6–9 Pixel Battle (650..1025 + 1026..1043 = 394 runners)
    modern_tasks = [
        (
            f"modern:{i}",
            pe_exp_candidates(raw_slugs[i - 1], ["anim_front.png", "front.png"]) + [PNG_FALLBACK_URL.format(id=i)],
            os.path.join(SPRITES_MODERN, f"{i}.png"),
            True,
        )
        for i in range(650, MAX_NATIONAL_ID + 1)
    ] + [
        (
            f"modern:{rid}",
            [f"{PE_EXP_BASE}/{sub}/anim_front.png", f"{PE_EXP_BASE}/{sub}/front.png"],
            os.path.join(SPRITES_MODERN, f"{rid}.png"),
            True,
        )
        for (rid, _, _, sub, _) in ALOLA_FORMS
    ]

    # 5. Overworld Walking Followers (1..1025 + 1026..1043 = 1,043 runners!)
    hgss_tasks = [
        (
            f"hgss:{i}",
            pe_exp_candidates(raw_slugs[i - 1], ["overworld.png"]),
            os.path.join(SPRITES_HGSS, f"{i}.png"),
            True,
        )
        for i in range(1, MAX_NATIONAL_ID + 1)
    ] + [
        (
            f"hgss:{rid}",
            [f"{PE_EXP_BASE}/{sub}/overworld.png"],
            os.path.join(SPRITES_HGSS, f"{rid}.png"),
            True,
        )
        for (rid, _, _, sub, _) in ALOLA_FORMS
    ]

    # 6. Emerald (1..386)
    em_tasks = [(f"em:{i}", [EM_URL.format(slug=em_slug(raw_slugs[i - 1]))],
                 os.path.join(SPRITES_EM, f"{i}.png"), False)
                for i in range(1, MAX_EM_ID + 1)]

    # 7. Crystal (1..251)
    cry_tasks = [(f"cry:{i}", [CRY_URL.format(id=i)], os.path.join(SPRITES_CRY, f"{i}.gif"), False)
                 for i in range(1, MAX_CRY_ID + 1)]

    sets = [
        ("B/W", bw_tasks),
        ("FireRed", fr_tasks),
        ("Alola SM", alola_tasks),
        ("Gen6-9Px", modern_tasks),
        ("Walking", hgss_tasks),
        ("Emerald", em_tasks),
        ("Crystal", cry_tasks),
    ]

    all_failed = []
    with ThreadPoolExecutor(max_workers=16) as ex:
        for label, tasks in sets:
            results = list(ex.map(download_candidates, tasks))
            failed = [k for k, ok in results if not ok]
            print(f"{label:8s} sprites: {len(tasks) - len(failed)}/{len(tasks)} ready")
            all_failed.extend(failed)

    if all_failed:
        print("failed:", all_failed)
        sys.exit(1)


if __name__ == "__main__":
    main()
