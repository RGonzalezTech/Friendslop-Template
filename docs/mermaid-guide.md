# Mermaid Diagram Guide

How to pick a diagram and keep it readable. Written down from the patterns already in this repo's READMEs.

## Pick the Tool

| You're showing... | Use | Example |
|-------------------|-----|---------|
| Who calls who, in what order (flows, signals, lifecycles, RPC protocols) | `sequenceDiagram` | [SceneManager flow](../scripts/core/README.md#scenemanager-scene_managergd) |
| What the parts are and what each one depends on | **Table**: Piece \| Job \| Knows about | below |
| A strict has-a tree (what's inside what) | `graph TD` | none yet |
| Named states where the transitions *are* the point | `stateDiagram-v2` | none yet |

**Default to `sequenceDiagram`.** Every diagram in this repo is one. If you're reaching for a graph, ask: "is this a flow pretending to be a structure?" If the arrows mean "calls" or "signals," it's a sequence.

**Pieces table** — the "Knows about" column carries the dependencies a graph would, without crossing arrows:

| Piece | Job | Knows about |
|-------|-----|-------------|
| `LocalCoopManager` | Device → seat mapping. No network effects | `InputProvider` |
| `LobbyManager` | Player lifecycle, broadcasts the active scene | `PeerManager`, `SceneManager` |

Follow it with one line on boundaries: *"The modal never touches the network. The coordinator never touches UI."*

**`graph TD` rules** (when you do use it):
- Every arrow means the same thing. Say what in the caption ("every arrow means has-a")
- Never mix *extends* and *has* in one graph
- No orphan nodes — if it has no edge, it doesn't belong
- Quote labels with parentheses: `HS["HandshakeSpawner (RPC)"]`

## Make It Readable

**Shape**
- 1–2 sentence intro above every diagram: what it shows and where to start reading
- **≤ 6 participants.** Need more? Split it, or move setup into its own diagram
- **≤ ~20 messages.** Same deal. The [lobby README](../scripts/multiplayer/lobby/README.md) uses 3 small diagrams, not 1 huge one
- One concern per diagram. Link to the neighbor diagram instead of repeating it

**Participants**
- Short aliases: `participant LM as LobbyManager`
- Declare every participant up top, ordered so the flow reads left → right
- `actor` for humans or hardware (players, gamepads)

**Arrows**
- `->>` = call or RPC. `-->>` = signal or return. Stick to it everywhere
- Labels use **real names from the code** (`start_transition_to(path)`, `signal player_joined(peer_id, local_id)`) so people can grep them
- Keep labels short (~40 chars). Detail goes in a `Note`

**Blocks**
- `alt` / `else` — branches that change behavior: server vs client, lobby full vs success ([lobby join protocol](../scripts/multiplayer/lobby/README.md#join-requestresponse-protocol))
- `opt` — "only sometimes"
- `loop` — retries, polling, "for each" ([handshake retries](../scripts/multiplayer/replication/README.md#-handshake-sequence))
- `par` — things that really happen at the same time (both sides loading the map)
- `rect rgb(...)` + `Note over: Phase N` — only for long, multi-phase flows ([spawning phases](../scripts/multiplayer/player_spawning/README.md#-spawning-flow))
- `activate` / `deactivate` — on the orchestrator in longer flows, so you can see who's "busy." Skip it in short diagrams

**Notes**
- Explain the *why* or the gotcha — never repeat the arrow
- Wrap with `<br/>` around ~35 chars
- If you simplified, say so: `Note over LM, PS: This is the simplified version`

## The 20/80 Cut

Show:
- The happy path
- The 1–2 branches that change what happens next (reject, cancel, disconnect, late join)
- Anything surprising ("`NetworkLevelRoot` only emits this on the server")

Skip:
- Asserts, logging, getters, private helpers
- Every edge case — that's what tests are for
- Anything another diagram already covers — link to it

## Keep It True

- Check every name against the code before committing. A wrong name is worse than no diagram
- READMEs describe what exists **on this branch**. Planned API goes in `docs/` design docs or an Open Questions checkbox
- Render before you commit — GitHub's mermaid parser is strict:

  ```bash
  npx -p @mermaid-js/mermaid-cli mmdc -i diagram.mmd -o out.svg
  ```

- Don't put `-->` inside an HTML comment (`<!-- -->`) — it closes the comment early

## Pair It With

A diagram is the middle of a section, not the whole thing:

1. Intro line → **diagram** → API / Pieces table
2. **Constraints & Invariants** — things that must always be true
3. **Integration** — numbered "how to hook this up" steps
4. **Design Decisions** — numbered, bold title + why
5. **Open Questions** — `- [ ]` checkboxes with a **Leaning**
