# Contributing

First off, thanks for taking the time to contribute! The intention behind this repository is a genre-agnostic template for making multiplayer games in Godot.

To keep things running smoothly, please follow these guidelines when submitting issues or pull requests (PRs).

## 🚩 Reporting Issues

If you've found a bug or have a feature suggestion, please check the [existing issues](https://github.com/RGonzalezTech/Friendslop-Template/issues) first to see if it's already being discussed.

When reporting a bug, please include:
- **Godot version** (e.g., 4.4 stable).
- **Steps to reproduce** the issue.
- **Expected vs. actual behavior**.
- If possible, a **minimal reproduction project** or scene.

## 💬 Getting Help

If you have questions about how to use the template or need clarification on the codebase before starting work, please reach out via an issue.

## ⚖️ Ground Rules

* **Keep it clean:** Write clear, concise commit messages.
* **One feature per PR:** Keep your pull requests focused on a single issue or feature. It makes reviewing much easier.

## 🛠️ Development Workflow

1. **Fork & Branch:** Fork the repository and create a new branch for your feature or bugfix.
  - Use a descriptive branch name (e.g., `username/feature-name` or `fix/issue-description`).
2. **Make Changes:** Implement your changes in your new branch.
  - The code is tested via [GUT](https://gut.readthedocs.io/en/v9.5.0/). Make sure you haven't broken any existing tests.
  - If you add a new feature, add a new test for it.
  - Update the relevant `README.md` if your changes modify existing behavior or project structure.
3. **Pull Request:** Submit a pull request to the `main` branch.
  - This will trigger GitHub Actions to run unit tests automatically.

## 📑 Pull Requests

When submitting a pull request, please make sure that you:

1. Describe your changes thoroughly and, if possible, include images or screenshots.
2. Link to relevant issues (e.g., `closes #123`).
3. Sync your branch with `main` before submitting to minimize merge conflicts.

## 🎨 Code Style / Architecture

* **Extensibility:** Write code that is genre-agnostic. Avoid hardcoding logic only meant for 2D or 3D; instead, write components that can be extended.
* **SOLID Principles:** If a script does more than one thing, it's probably doing too much. Use focused, modular components.
* **GDScript Style:** Adhere to the official [GDScript Style Guide](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html) to keep the codebase consistent.