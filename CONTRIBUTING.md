# Contributing

First off, thanks for taking the time to contribute! The intention behind this repository is a genre-agnostic template for making multiplayer games in Godot.

To keep things running smoothly, please follow these guidelines when submitting issues or pull requests (PRs).

## Ground Rules

* **Keep it clean:** Write clear, concise commit messages. 
* **One feature per PR:** Keep your pull requests focused on a single issue or feature. It makes reviewing much easier.

## Development Workflow

1. **Fork & Branch:** Fork the repository and create a new branch for your feature or bugfix.
  - Make sure that your branch name is descriptive (e.g., `rg/add-contributions-md` or `fix/lobby-bug`)
2. **Make Changes:** Implement your changes in your new branch.
  - The code is tested via [GUT](https://gut.readthedocs.io/en/v9.5.0/). Make sure you haven't broken any existing tests.
  - If you add a new feature, add a new test for it.
  - If you have modified behavior covered by a `README.md` file, then be sure to update it as well.
3. **Pull Request:** Submit a pull request to the `main` branch
  - This should run the Github Actions for the unit tests as well.

## Pull Requests

When submitting a pull request, please make sure that you:

1. Describe your changes thoroughly and if possible, include images or screenshots.
2. Link to any relevant issues that your pull request addresses (e.g. `closes #123` or `fixes #123`)
3. Try to keep up to date with the `main` branch. This is not a requirement, but it makes the review process much easier.

## Code Style / Architecture

* **Extensibility:** Try to make your code extensible and easy to modify. If a script does more than one thing, it's probably doing too much.
* **GDScript conventions:** Try to adhere to standard GDScript styling guidelines so the codebase stays consistent.