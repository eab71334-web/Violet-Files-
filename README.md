# Violet Files — الملفات البنفسجية

First-person detective game for mobile (landscape), built with Godot 4.

**Current build: main menu only.** A live 3D night-office scene (rain on the window,
flickering violet neon, coffee steam, gyro parallax) with Continue / Solo Play /
Local Play (LAN) / Settings. Cases come later.

- `project.godot` — landscape 1920x1080, Mobile renderer
- `scripts/settings.gd` — autoload: language (AR/EN), volume, quality, gyro, save check
- `scripts/office_scene.gd` — the 3D office, built entirely in code
- `scripts/rain_audio.gd` — procedural rain / synth pad / thunder (no audio files)
- `scripts/main_menu.gd` — menu UI, panels, LAN host/join (ENet, port 7777)
- `fonts/` — drop `Cairo.ttf` here for the Arabic font; it is picked up automatically
