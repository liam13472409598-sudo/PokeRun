# PokéRun

A personal macOS menu bar app inspired by **RunCat**, starring **3,215 Pokémon runners** spanning **every generation (`#001`–`#1025`, Gen 1 through Gen 9)** plus **all 18 Alolan Regional Forms**!

Your Pokémon lives in the macOS menu bar and animates faster as CPU usage climbs — strolling calmly when idle and sprinting under heavy workloads.

## Included Series (3,215 Runners · Gen 1–9 + Alola)

1. **Pokémon Black & White (`#001`–`#649` · 649 sprites)** — Gen 5 Nintendo DS multi-frame animated battle sprites.
2. **Pokémon FireRed (`#001`–`#386` · 386 sprites)** — Classic Gen 3 GBA `32×32` 2-frame bouncing party/PC pixel icons.
3. **Pokémon Sun & Moon · Gen 7 Alola (`#722`–`#809` + 18 Alolan Forms · 106 sprites)** — Full multi-frame Sun & Moon / Ultra Sun & Ultra Moon animations for every Alola Pokémon (*Rowlet, Decidueye, Litten, Incineroar, Popplio, Primarina, Rockruff, Lycanroc, Mimikyu, Cosmog, Solgaleo, Lunala, Necrozma, Zeraora, Marshadow, Melmetal*, plus *Alolan Vulpix, Ninetales, Raichu, Marowak, Exeggutor*, and more).
4. **Alola & Gen 6–9 Pixel Battle (`#650`–`#1025` + 18 Alolan Forms · 394 sprites)** — Retro GBA-style pixel battle animations covering Kalos, Alola, Galar, Hisui, and Paldea.
5. **Walking Followers (`#001`–`#1025` + 18 Alolan Forms · 1,043 sprites)** — Side-view overworld walking follower pixel sprites across every single Pokémon generation that walk & run in place like RunCat.
6. **Pokémon Emerald (`#001`–`#386` · 386 sprites)** — Gen 3 GBA `64×64` 2-frame animated Hoenn battle sprites.
7. **Pokémon Crystal (`#001`–`#251` · 251 sprites)** — Nostalgic Gen 2 Game Boy Color 8-bit animated battle sprites.

## Features

- **Dynamic CPU-driven animation** in the macOS menu bar (`0.5×` at idle up to `5×` at 100% CPU), with nearest-neighbour Retina pixel rendering.
- **Full RunCat system dashboard** on click (CPU, Memory + Activity-Monitor pressure bar, Storage, Battery health & cycles, and live Wi-Fi/VPN network speed).
- **Per-series menu & Pokédex browser**:
  - Quick-switch runners via ordered per-series submenus or **Random Runner** (`⌘R`).
  - Filter by series (`All`, `B/W`, `FireRed`, `Gen 7`, `6–9 Px`, `Walk`, `Emerald`, `Crystal`) and search by name or `#number` in **Settings → Runners**.
- **RunCat controls & preferences**:
  - **Pause Runner** (`⌘P`), **Invert horizontally**, **Invert speed**, **Speed limit** (`None` / `3×` / `2×` / `1×`), **FPS limit** (`60`–`10 fps`), **Launch at login**, and quick **Activity Monitor** shortcut.

## Build & Install

```bash
./scripts/build_app.sh
```

Compiles a release build, bundles all 3,215 sprites + custom app icon into `~/Applications/PokeRun.app`, ad-hoc signs it, and launches it in your menu bar.

---

*Personal build only. Pokémon names and sprites © Nintendo / Creatures Inc. / GAME FREAK inc. / The Pokémon Company.*
