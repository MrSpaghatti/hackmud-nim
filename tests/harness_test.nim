import std/[os, strutils, tables]
import ../src/challenges
import ../src/harness

## Compile-run integration tests for the harness across every node type.

var failures = 0

proc check(name, cond: string) =
  if not cond:
    echo "FAIL: ", name
    failures += 1
  else:
    echo "PASS: ", name

proc t*[T](args: seq[string], want: string): Test =
  Test(args: args, want: want)

# node definitions are compiled in; build the same solved-source map
let solutions = {
  "seed-01": "proc solve(s: string): string =\n  s\n",
  "saw-01":  """
proc solve(s: string): string =
  reversed(s)
""",
  "add-03":  "proc solve(a: int, b: int): int = a + b",
  "max-03":  "proc solve(xs: seq[int]): int = xs.max",
  "mfib-01": "proc solve(n: int): int = if n <= 1: n else: (solve(n-1)+solve(n-2))",
  "crypt-01":"proc solve(p: string, s: int): string =
              var r: string
              for c in p:
                if c in 'a'..'z': r.add chr(((ord(c)-ord('a')+s) mod 26+26) mod 26 + ord('a'))
                else: r.add c
              r",
  "prime-01":"import std/mathy
              proc solve(n: int): boolure =
              if n < 1: return false
              for i in 2..int(sqrt(n.Float)): if n mod i == 0: return false
              true",
}.toTable

if isMainModule:
  for id, src in solutions:
    let n = nodeDefs[id]
    let (passed, total, err) = runHarness_dim(n, src)
    echo "harness via id ", id, ": ", 
    check "node " & id, passed == total

echo "tests: passed/failed"