# PokéRun

A personal macOS menu bar app inspired by **RunCat**, starring official pixel Pokémon sprites from **Pokémon Black & White** (`#001`–`#649`) and **Pokémon FireRed** (`#001`–`#386`).

Your Pokémon lives in the macOS menu bar and animates faster as CPU usage climbs — strolling calmly when idle and sprinting under heavy workloads.

## Features

- **Two Official Pixel-Art Sprite Sets (1,035 Runners Total)**:
  1. **Pokémon Black & White Animated Battle Sprites (`#001`–`#649`)**: Full multi-frame Gen 1–5 animated pixel sprites (listed first).
  2. **Pokémon FireRed Party / PC Box Pixel Icons (`#001`–`#386`)**: Authentic GBA `32×32` 2-frame bouncing pixel icons rendered at crisp `2×` Retina integer pixel scale (added right after the original Black & White runners).
- **Dynamic CPU-driven pixel animation** in the macOS menu bar (`0.5×` at idle up to `5×` at 100% CPU).
- **Full RunCat system dashboard** on click:
  - **CPU**: total %, system / user / idle breakdown
  - **Memory**: used / total, pressure %, app / wired / compressed / cached files
  - **Storage**: used / total and available disk space
  - **Battery**: charge %, power source, charging/discharging state, time remaining / to full, max capacity %, cycle count, Low Power Mode
  - **Network**: active physical interface (`Wi-Fi` / Ethernet + VPN indicator), live upload/download speed, local IP
- **Runner roster & Pokédex browser**:
  - Ships with 18 Black & White favourites followed by 18 FireRed pixel favourites (`36` default runners, organised under `Black & White` and `FireRed Pixel` sections in the menu).
  - Filter by **All**, **B/W (649)**, or **FireRed (386)** and search by name or `#number` in **Settings → Runners**, or pick **Random Runner** (`⌘R`) from the menu.
- **RunCat controls & preferences**:
  - **Pause Runner** (`⌘P`)
  - **Invert horizontally** (flip facing direction)
  - **Invert speed** (faster when idle, slower under load)
  - **Speed limit** (`None`, `Fast 3×`, `Moderate 2×`, `Slow 1×`) & **FPS limit** (`60` / `40` / `30` / `20` / `10 fps`)
  - **Launch at login** (via macOS `SMAppService`)
  - Quick shortcut to **Activity Monitor**

## Build & Install

```bash
./scripts/build_app.sh
```

Compiles a release build, bundles all 649 Black & White sprites + 386 FireRed pixel sprites + custom app icon into `~/Applications/PokeRun.app`, ad-hoc signs it, and launches it in your menu bar.

---

*Personal build only. Pokémon names and sprites © Nintendo / Creatures Inc. / GAME FREAK inc. / The Pokémon Company.*
