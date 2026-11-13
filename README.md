# Violet Files — الملفات البنفسجية

First-person detective game for mobile (landscape), built with Godot 4.

## Current build
- **Main menu**: live 3D night office (rain, flickering violet neon, steam, gyro parallax) with Continue / Solo Play / Local Play (LAN) / Settings.
- **Case 1 "Under Rent" (تحت الإيجار)** — insurance fraud, from the design document:
  - Walk around the office (touch: left side = move, right side = look; PC: WASD + right-mouse drag).
  - Negotiate with the client Abu Firas (hidden patience/greed: 600 → 750 → 900, or he walks out).
  - Assistant **Haitham** works in the office: invoices and camera-footage searches (1 slot + 30 each).
  - Phone: camera (photo quality depends on distance and rain), gallery, notes, call Haitham.
  - Roof of the burned building in the rain: real evidence vs misleading evidence.
  - Question Salma with the hidden-tension system (watch the face, sweat, hands and her pen), pressure/calm tools, bribe choices (legal / grey / illegal).
  - Hand the file in from the violet folder on the desk; scored out of 100 as in chapter 21 of the document.

## Files
- `scripts/game.gd` — autoload: case state, evidence, scoring, save/load
- `scripts/world.gd` — world manager (locations, photo capture, camera focus)
- `scripts/case1.gd` — all of case 1's logic (dialogue, negotiation, interrogation, hand-in)
- `scripts/office_scene.gd`, `roof_scene.gd` — the 3D locations
- `scripts/blocky_person.gd` — characters with the tension "tells"
- `scripts/player.gd`, `game_ui.gd`, `ui_kit.gd` — controls and UI
- `scripts/main_menu.gd`, `settings.gd`, `rain_audio.gd` — menu, settings, procedural audio
- `fonts/` — drop `Cairo.ttf` here for the Arabic font; it is picked up automatically
