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
- [ ] harness: compile + hidden tests (+timeout sandbox)
- [ ] game shell: connect/write/run/credits/net map
- [ ] state persistence

## Notes

The compiler sandbox is *cosmetic* isolation only — player-supplied Nim runs
on your machine like any local binary. It's a single-player game; that's the
point. Don't expose it as a multi-tenant service.