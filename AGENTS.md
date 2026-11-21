# AGENTS.md — AI Agent Instructions

How AI coding agents (Claude Code, Codex, Hermes, etc.) work in this repo. Humans: see [CONTRIBUTING.md](CONTRIBUTING.md) — same rules, less shouting.

## Before Any Code Change

1. **Design doc first.** Write `docs/<feature-name>.md` from the [template](docs/design-doc-template.md):
   - Pieces table: what exists today + what's new (`Piece | Job | Knows about`)
   - Mermaid sequence diagram of the proposed flow
   - Numbered architectural decisions — each with a recommendation, rationale, and open/settled
   - Open-questions checklist (`- [ ]`, each with a **Leaning**)
2. **Confirm the open questions** with the user before implementing.
3. **File-level plan.** List every file created vs modified, and for each whether it's a new `.gd`, a new `.tscn`, or an edit to an existing scene. Wait for approval before building.

## Documentation Conventions

- Every subsystem folder gets a `README.md` mirroring the code tree. Root README links to each one
- Diagrams follow [`docs/mermaid-guide.md`](docs/mermaid-guide.md). The short version:
  - Flows, signals, lifecycles, RPC protocols → `sequenceDiagram` (the default)
  - "What are the parts" → a `Piece | Job | Knows about` table, not a graph
  - `graph TD` only for strict has-a trees — one arrow meaning, no orphan nodes
  - ≤ 6 participants, ≤ ~20 messages, one concern per diagram — split rather than grow
  - `->>` calls/RPCs, `-->>` signals/returns. Labels use real method/signal names from the code
  - Show the happy path + the branches that change behavior (reject, disconnect, server vs client). Skip asserts, logging, helpers
- **Verify every name** in a diagram or doc against the code, and render it (`npx -p @mermaid-js/mermaid-cli mmdc -i x.mmd -o x.svg`) before committing
- **READMEs describe what exists on this branch.** Forward-looking API belongs in a `docs/` design doc or an Open Questions checkbox. If a README names a method that isn't in the code, ask whether the README or the code is wrong — don't implement it
- Cross-system doc comments can lie too ("X calls this"). Read both sides before wiring anything
- Backtick code fences (`ClassName`) — never Godot doc syntax (`[ClassName]`, `[method foo]`), which renders as literal brackets on GitHub
- Document API with purpose, not just signature. List invariants explicitly

## Architecture Rules

- **Simple over Complex.** No monolithic managers. If a script does more than one thing, split it
- **Genre-agnostic.** No hardcoded 2D-only or 3D-only logic in shared systems — write components that extend
- **Strategy pattern for pluggable behavior**: `BaseNetworkProvider` (ENet/Steam), `BasePlayerSpawnManager` (Simple/CollQueue). New behavior = new strategy, not a flag on the base
- **Server-authoritative.** Clients request via RPC, the server validates and acts (see the lobby join protocol)
- **Player identity is `(peer_id, local_player_id)`.** Primary = `0`, guests = `1+`. Never key players by `peer_id` alone
- **Local co-op has three layers** — device (gamepad), seat (`local_player_id`), network (`LobbyPlayer`). `LocalCoopManager` owns device → seat and has no network effects. Don't blur them
- **Scene changes** go through `SceneManager.start_transition_to()`, never `change_scene_to_*()` directly
- **Gameplay spawning** goes through `HandshakeSpawner`, not `MultiplayerSpawner`, so late joiners get the replay
- **Input** goes through `ActionRouter`, not `Input.is_action_pressed()` in player scripts
- Gameplay scenes own their own logic and state when possible

## Testing

- **TDD for all behavior changes**: write the failing test, run GUT and confirm RED, implement the minimum, confirm GREEN, refactor. Run the suite yourself — don't hand that to the user
- GUT headless (`-gconfig` and `-gdir` are required):
  ```bash
  godot --headless --rendering-driver opengl3 -s addons/gut/gut_cmdln.gd -gconfig=res://gutconfig.json -gdir=res://test
  ```
- After adding a script with `class_name`, run `godot --headless --import` first — otherwise GUT reports `Identifier "X" not declared`
- Don't verify autoload or `class_name` code with `godot -s script.gd` — that skips autoloads and the class registry. Use a throwaway GUT test
- Group related tests into inner classes (`class TestXxx: extends GutTest`), each with its own `before_each` that builds + autofrees the object under test. Network tests extend `BaseNetworkGutTest` (`test/__setup__/`)
- UI scenes get a load + instantiate smoke test under `test/ui/`, then the user does UX validation
- Doc-only edits skip the suite
- `test_scene_load_failed_returns_to_menu_with_reason` (`test/multiplayer/test_lobby_manager.gd`) is flaky — rerun once before treating it as real

## Git

- One feature per PR. Branch: `username/feature-name` or `fix/issue-description`
- Commits: `Component: what changed (#issue)`, imperative mood
- Multi-module branches split bottom-up in history: design doc → existing-code wrappers → pure logic → coordinators → leaf UI → top-level scene
- A `.gd.uid` sidecar goes in the same commit as its script — test scripts included
- Don't commit, push, or rewrite history unless asked

## GDScript

- Tab-indented. Official [GDScript Style Guide](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html)
- **Warnings are errors.** `clamp()` and `Dictionary.get()` return `Variant`, so `var x := clamp(...)` won't parse. Use `clampi()` / `clampf()` and explicit annotations (`var x: int = dict.get(...)`)
