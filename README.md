# Friendslop Template 🎮

This is a Godot 4.4 starter kit designed to get your multiplayer game running quickly. It comes with scene synchronization, lobby, and player spawning systems. 

[![Watch the video](https://img.youtube.com/vi/T7xIrRo7aLg/0.jpg)](https://www.youtube.com/watch?v=T7xIrRo7aLg)

## 🚀 Key Features

*   **Multiplayer Ready**: Supports ENet out of the box and can be easily extended.
*   **Safe Scene Management**: A robust system to handle level transitions for all connected players simultaneously.
*   **Input Routing**: A clean pattern to handle local co-op input.
*   **Handshake Replication**: A custom spawning system that ensures clients are _actually ready_ to receive spawn/sync packets
*   **Testing**: Pre-configured with [GUT](https://gut.readthedocs.io/en/v9.5.0/) for unit testing.

## 📂 Project Structure

*   `addons/`: Third-party tools ([GUT](https://gut.readthedocs.io/en/v9.5.0/)).
*   `scenes/`: All your .tscn files (Menus, Levels, UI).
*   `scripts/`: The brains
    *   [`core/`](scripts/core/README.md): The Scene Manager nodes.
    *   [`input/`](scripts/input/README.md): Device input handling logic.
    *   [`multiplayer/`](scripts/multiplayer/README.md): Networking, Lobby, and Replication logic.
*   `test/`: Unit tests to keep your code sane.

## 🛠️ Getting Started

1.  Clone the repo.
2.  Open in Godot 4.
3.  Run the project. You'll land on a Main Menu where you can host or join.

## Philosophy

I prefer **Simple over Complex**. This template avoids massive, monolithic managers in favor of smaller, focused components. If a script does more than one thing, it's probably doing too much.

Enjoy!
