# hackmud-nim — design spec

A hackmud-style terminal hacking game where **the in-game scripting language is Nim**.
You connect to nodes across a "net"; each node is a coding challenge. To take a
node you write a `solve` proc in Nim, compile it, and run it against hidden test
cases. You earn credits and progress up the difficulty ladder.

Terminal-native, ANSI, zero external deps beyond the system `nim` compiler.
Built with Nim 2.x.

## Core loop

1. Type commands at a prompt (`you>`-style, like hackmud's cursor).
2. `connect <node>` moves you to a node and shows its challenge.
3. `write` / `edit` opens your solution file (the player authors a `solve` proc).
4. `run` compiles your solution and tests it against the node's **hidden cases**,
   reporting per-case PASS/FAIL.
5. All-pass earns the node's payoff and marks it cleared; credits let you unlock
   higher-tier nodes.

## Layout

```
src/challenges.nim   # node registry (DONE — clean, compile against this)
src/harness.nim      # THE core: codegen runner + nim c + execute + verdicts
src/game.nim         # REPL, ANSI shell, credits, net map, state persistence
```

## Challenges (src/challenges.nim)

Already implemented and correct. Each `Node` has:

- `id`, `region`, `name`, `diff` (1..5), `reward` (credits), `flavor`, `help`
- `decl`: the `solve` signature as Nim code, e.g. `proc solve(s: string): string`
- `stub`: full text written to the player's solution file (proc header + a hint)
- `tests`: hidden test cases. Each `Test` has `args` (Nim literal code, one per
  parameter) and `want` (expected-result literal code).

There is a `Test` constructor `t(args: seq[string], want: string)` and a
`t`-builder. The registry exposes `byId`, `order`, `initRegistry`, `node(id)`,
`has(id)`, `allIds`, `nodeToJson(n)`.

## Harness (src/harness.nim) — the correctness-critical piece

Design contract (do NOT change the input/output semantics):

1. `runnerSource(n: Node, solutionSrc: string): string` — assemble runnable Nim:
   - Player's solution file pasted verbatim at the top (its `import`s stay in scope)
   - a `__check(caseNum, got, want)` helper that echoes
     `PASS #N|got|want` or `FAIL #N|got|want`
   - an `isMainModule` driver looping `0 ..< n.tests.len`, binding each test's
     args via `let a0 = <lit>; let a1 = <lit>; ...`, calling
     `let g = $solve(a0, a1, ...)`, then `__check`.
2. `compileAndRun(src, workDir)` writes the runner to a temp file, invokes the
   system `nim c -r --hints:off --warnings:off --verbosity:0` with a **hard
   timeout** (so an infinite-looping solution costs the player bandwidth, not
   the host — this is a security/sandbox boundary), captures combined output.
3. Return per-case verdicts + overall pass count.

Compile flags: `c -r --hints:off --warnings:off --verbosity:0 --skipParentCfg
--skipUserCfg --colors:off`. Sandbox in a scratch dir under
`workspace/hacks/<node-id>/`. Use a `timeout` on the spawned proc.

Because the player supplies arbitrary Nim, treat the solution as untrusted: run
it in a throwaway dir, no write-through of game state. (A malicious Nim proc
could still touch the filesystem — that's fine for a fun local game; we are not
claiming real isolation. Document it.)

## Game (src/game.nim) — the shell

REPL with these commands:

- `help` — command list (table)
- `status` / `credits` — wallet, cleared nodes, region
- `map` — node list with diff + reward, cleared markers
- `connect <id>` — enter a node, show its prompt/stub
- `write` — regenerate the solution stub into your editor ($EDITOR / fallback helix)
- `run` — invoke harness on the current solution file; print verdicts + credit delta
- `leave` / `back` — exit a node
- `q` / `quit` — exit

Flavor: keep it dry and terse, hacker-green-on-black ANSI. Persist progress
(credits, cleared nodes) in a JSON state file under `workspace/state.json`.

## Build

- nimble file `hackmud.nimble` with `bin` = `hackmud-nim`, source = `src/game.nim`.
- `nimble build` or `nim c -r src/game.nim`.

## Non-goals / notes

- No real sandbox; cosmetic-risk only. Document in README.
- No networking/multiplayer. Single-player local.
- Keep it tight: a handful of nodes is a fine v1.

## Milestones

1. harness compiles a trivial correctly-solved node (seed-01 echo) → green
2. harness FAILs a wrong solution → red, with the got/want in output
3. game shell: connect → write → run → credits increment on clear
4. 8 registered nodes playable end-to-end end
5. state persists across restarts