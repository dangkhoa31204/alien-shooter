# CHIẾN DỊCH LỊCH SỬ (Historical Campaign)

A 2D Action Platformer game built with Godot Engine 4.6.

## 1. Project Overview
- **Game Engine:** Godot Engine v4.6 (Forward+ Renderer)
- **Language:** GDScript
- **Genre:** 2D Side-scrolling Action Platformer (Run & Gun)
- **Platform:** Windows PC

## 2. Complete Source Files
This repository contains the complete source code, including:
- `project.godot`: Main Godot configuration file containing game settings, window size, and autoloads.
- `scenes/`: Contains all visual node trees (the player, enemies, tanks, levels, UI).
- `scripts/`: Contains the GDScript logic driving all mechanics.
- `assets/`: Contains all graphics, sprites, and audio files used to render the game.

## 3. Setup and Rebuilding Instructions
To open and edit the source code:
1. Download and install **Godot Engine 4.6** (Standard version) from [godotengine.org](https://godotengine.org/).
2. Open Godot, click on **Import**, and select the `project.godot` file located in the root of this folder.
3. The editor will automatically re-import all assets the first time you open it (this may take a few seconds).
4. No external plugins or custom C++ modules are required. The game relies purely on standard GDScript.
5. Press `F5` (or the Play button in the top right corner) to run the game from the editor.

## 4. Ready-to-Run Build
Inside the `/Build/` directory (if provided in the submission zip), you will find the exported standalone `.exe` game files. 
- You do **not** need Godot installed to play the game.
- Simply extract the ZIP file, navigate to the `Build` folder, and run `ChienDichLichSu.exe` (or the similarly named executable).
- *Note: Leave the associated `.pck` file in the exact same directory as the `.exe` for the game to launch successfully, as it contains all packaged game data.*

## 5. Usage Notes & Controls
- **A / D or Left / Right Arrows:** Move left and right
- **W / Up Arrow:** Aim upwards (Wait, jump is usually Space?) -> **Spacebar:** Jump
- **Mouse / Click:** Aim and Shoot with main weapon
- **Right Click / Shift:** Use sub-weapon / Special
- **E / Q:** Switch weapons/skills
- **Esc:** Pause the game

## 6. Export Settings (For Future Deployment)
If you wish to create a new build of this game from the source code:
1. Open the project in Godot 4.6.
2. Go to **Project > Export...** in the top menu.
3. Click **Add...** and select **Windows Desktop**.
4. *(If you haven't downloaded export templates, click the "Manage Export Templates" link at the bottom and download them).*
5. Uncheck "Export With Debug" for the final release.
6. Click **Export Project**, choose a folder (e.g., `Build/`), and save as an `.exe` file.
