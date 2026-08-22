import std/[os, strutils, tables, math]
import challenges
import harness

proc main =
  # Prove multi-param + typed comparison + return-value correctness on real nodes.
  let nodes = @["add-03", "fib-01", "crypt-01", "max-03", "prime-01", "lock-01"]
  var anyFail = false

  let solutions = {
    "add-03": """
proc solve(a: int, b: int): int =
  a + b
""",
    "fib-01": """
proc solve(n: int): int =
  if n <= 1: n
  else: solve(n-1) + solve(n-2)
""",
    "crypt-01": """
proc solve(plain: string, shift: int): string =
  var res: string
  for c in plain:
    if c in 'a'..'z':
      res.add chr(((ord(c) - ord('a') + shift) mod 26 + 26) mod 26 + ord('a'))
    else:
      res.add c
  res
""",
    "max-03": """
proc solve(xs: seq[int]): int =
  xs.max
""",
    "prime-01": """
import std/math
proc solve(n: int): bool =
  if n < 2: return false
  for i in 2 .. int(sqrt(n.toFloat)):
    if n mod i == 0: return false
  true
""",
    "lock-01": """
import std/[sequtils, sets]
proc solve(src: seq[int]): seq[int] =
  var seen = initHashSet[int]()
  var res: seq[int]
  for x in src:
    if x notin seen:
      seen.incl x
      res.add x
  res
""",
  }.toTable

  for id in nodes:
    let n = node(id)
    if not solutions.hasKey(id):
      echo "SKIP ", id, ": no solution provided"
      continue
    let (v, passed, tot, err) = runHarness(n, solutions[id], getTempDir() / ("hm-" & id))
    let ok = passed == tot
    if not ok: anyFail = true
    echo if ok: "[OK ] " else: "[FAIL] ", id, ": passed=", passed, "/", tot, " err='" & err & "'"
    for line in v: echo "      ", line

  echo if anyFail: "OVERALL: SOME FAILED" else: "OVERALL: ALL PASS"

if isMainModule:
  main()