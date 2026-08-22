import std/[os]
import challenges
import harness

# Node requiring int. Give it a solver with an infinite loop -> must TIME OUT.
let n = node("fib-01")
let hang = """
proc solve(n: int): int =
  while true:
    discard
  return 0
"""
let (v, passed, total, err) = runHarness(n, hang, getTempDir() / "hm-timeout")
echo "verdicts: ", v
echo "passed: ", passed, " total: ", total
echo "is_timeout: ", (v.len == 1 and v[0] == "TIMEOUT")
echo "err: ", err