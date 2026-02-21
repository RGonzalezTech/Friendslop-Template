# Friendslop Template 🎮

This is a Godot 4.4 starter kit designed to get your multiplayer game running quickly. It comes with scene synchronization, lobby, and player spawning systems. 

[![Tests](https://img.shields.io/github/actions/workflow/status/RGonzalezTech/Friendslop-Template/testing.yml?style=for-the-badge&logo=github&label=Tests)](https://github.com/RGonzalezTech/Friendslop-Template/actions/workflows/testing.yml)
[![Godot Version](https://img.shields.io/badge/Godot-4.4-%23478cbf?logo=godot-engine&logoColor=white&style=for-the-badge)](https://godotengine.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge)](https://opensource.org/licenses/MIT)
[![Stars](https://img.shields.io/github/stars/RGonzalezTech/Friendslop-Template?style=for-the-badge&logo=github)](https://github.com/RGonzalezTech/Friendslop-Template/stargazers)
[![Forks](https://img.shields.io/github/forks/RGonzalezTech/Friendslop-Template?style=for-the-badge&logo=github)](https://github.com/RGonzalezTech/Friendslop-Template/network/members)

> [!TIP]
> **This is intended as a GitHub Template.** Github does not support Git LFS in templates, so you will need to manually clone/fork this repo to use it.

### 📺 Video
<p align="center">
  <em>Check out the overview video below to see the template in editor.</em>
</p>

<p align="center">
  <a href="https://www.youtube.com/watch?v=T7xIrRo7aLg">
    <img src="https://img.youtube.com/vi/T7xIrRo7aLg/maxresdefault.jpg" alt="Friendslop Template Walkthrough" width="100%">
  </a>
</p>

## 🚀 Key Features

*   **Multiplayer Ready**: Supports ENet out of the box and can be easily extended.
*   **Safe Scene Management**: A robust system to handle level transitions for all connected players simultaneously.
*   **Input Routing**: A clean pattern to handle local co-op input.
*   **Handshake Replication**: A custom spawning system that ensures clients are _actually ready_ to receive spawn/sync packets
*   **Testing**: Pre-configured with [GUT](https://gut.readthedocs.io/en/v9.5.0/) for unit testing.

## 📂 Project Structure

*   `addons/`: Third-party tools (I always start with [GUT](https://gut.readthedocs.io/en/v9.5.0/) in my projects).
*   `scenes/`: All your .tscn files (Menus, Levels, UI).
    *   Gameplay scenes should contain and manage their own logic and state when possible.
*   `scripts/`: The brains
    *   [`core/`](scripts/core/README.md): The Scene Manager nodes.
    *   [`input/`](scripts/input/README.md): Device input handling logic.
    *   [`multiplayer/`](scripts/multiplayer/README.md): Networking, Lobby, and Replication logic.
*   `test/`: Unit tests to keep your code sane.

## 🛠️ Getting Started

1.  **Clone or Fork**: Manually clone or fork this repository to your account (GitHub Templates do not support Git LFS).
2.  **Open in Godot**: Open the project in **Godot 4.4** or later.
3.  **Run & Play**: Run the project to host or join a lobby right away.

## Philosophy

I prefer **Simple over Complex**. This template avoids massive, monolithic managers in favor of smaller, focused components. If a script does more than one thing, it's probably doing too much.

Enjoy!
