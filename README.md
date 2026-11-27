# PokéRun

A personal macOS menu bar app inspired by **RunCat**, starring **2,165 official pixel Pokémon runners** across **5 classic Pokémon series**.

Your Pokémon lives in the macOS menu bar and animates faster as CPU usage climbs — strolling calmly when idle and sprinting under heavy workloads.

## Included Series (2,165 Pixel Runners)

1. **Pokémon Black & White (`#001`–`#649` · 649 sprites)** — Full multi-frame Gen 5 Nintendo DS animated battle sprites.
2. **Pokémon FireRed (`#001`–`#386` · 386 sprites)** — Classic Gen 3 GBA `32×32` 2-frame bouncing party/PC pixel icons.
3. **Pokémon HeartGold & SoulSilver (`#001`–`#493` · 493 sprites)** — Gen 4 Nintendo DS side-view overworld walking follower sprites (walks & runs in place like RunCat!).
4. **Pokémon Emerald (`#001`–`#386` · 386 sprites)** — Gen 3 GBA `64×64` 2-frame animated Hoenn battle sprites.
5. **Pokémon Crystal (`#001`–`#251` · 251 sprites)** — Nostalgic Gen 2 Game Boy Color 8-bit animated battle sprites (the very first animated sprites in Pokémon history).

## Features

- **Dynamic CPU-driven pixel animation** in the macOS menu bar (`0.5×` at idle up to `5×` at 100% CPU), with nearest-neighbour Retina pixel rendering.
- **Full RunCat system dashboard** on click:
  - **CPU**: total %, system / user / idle breakdown
  - **Memory**: used / total, Activity-Monitor-style memory pressure bar, app / wired / compressed / cached files
  - **Storage**: used / total and available disk space
  - **Battery**: charge %, power source, charging/discharging state, time remaining / to full, max capacity %, cycle count, Low Power Mode
  - **Network**: active physical interface (`Wi-Fi` / Ethernet + VPN indicator), live upload/download speed, local IP
- **Per-series menu & Pokédex browser**:
  - Quick-switch runners via ordered per-series submenus (`Black & White`, `FireRed Pixel`, `HeartGold & SoulSilver`, `Emerald`, `Crystal`) or **Random Runner** (`⌘R`).
  - Filter by series (`All`, `B/W`, `FireRed`, `HGSS`, `Emerald`, `Crystal`) and search by name or `#number` in **Settings → Runners**.
- **RunCat controls & preferences**:
  - **Pause Runner** (`⌘P`), **Invert horizontally**, **Invert speed**, **Speed limit** (`None` / `3×` / `2×` / `1×`), **FPS limit** (`60`–`10 fps`), **Launch at login**, and quick **Activity Monitor** shortcut.

## Build & Install

```bash
./scripts/build_app.sh
```

Compiles a release build, bundles all 2,165 pixel sprites + custom app icon into `~/Applications/PokeRun.app`, ad-hoc signs it, and launches it in your menu bar.

---

*Personal build only. Pokémon names and sprites © Nintendo / Creatures Inc. / GAME FREAK inc. / The Pokémon Company.*
