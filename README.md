# hackmud-nim

A hackmud-style terminal hacking game where the in-game scripting language is **Nim**.

You connect to nodes across a net. Each node is a coding challenge: write a
`solve` proc, compile it against the node's hidden test cases, clear it, and
walk up the credit ladder. Terse hacker-green-on-black, keyboard-first, zero
deps beyond the system `nim` compiler.

See [DESIGN.md](DESIGN.md) for the full spec and architecture.

## Build & run

```bash
nimble build
./bin/hackmud-nim
```

## Roadmap

- [x] challenge registry (8 nodes)
- [x] harness: compile + hidden tests (+timeout sandbox)
- [x] game shell: connect/write/run/credits/net map
- [x] state persistence

## Verify

```bash
# harness RED-GREEN (seed-01 echo: correct vs wrong)
nim c -r --skipParentCfg --skipUserCfg src/demo_harness.nim
# all 7 non-trivial nodes via harness
nim c -r --skipParentCfg --skipUserCfg src/demo_nodes.nim
# timeout guard (infinite loop → TIME OUT, no hang)
nim c -r --skipParentCfg --skipUserCfg src/demo_timeout.nim
```

## Notes

The compiler sandbox is *cosmetic* isolation only — player-supplied Nim runs
on your machine like any local binary. It's a single-player game; that's the
point. Don't expose it as a multi-tenant service.