import std/[os, strutils]
import challenges
import harness

proc main =
  # Exercise the harness directly against seed-01 (echo).
  let n = node("seed-01")

  # Correct solution
  let good = """
proc solve(s: string): string =
  s
"""
  let (vg, pg, tg, erg) = runHarness(n, good, getTempDir() / "hm-test-good")
  echo "GOOD: passed=", pg, "/", tg, " err='" & erg & "'"
  for v in vg: echo "  ", v

  # Wrong solution: compiles, but returns empty instead of echoing.
  let bad = """
proc solve(s: string): string =
  ""
"""
  let (vb, pb, tb, erb) = runHarness(n, bad, getTempDir() / "hm-test-bad")
  echo "BAD:  passed=", pb, "/", tb, " err='" & erb & "'"
  for v in vb: echo "  ", v

  # Confirm seed-01 demands exact echo (the reverse one must fail >= 1)
  echo "RESULT good_passed=", pg, " bad_passed=", pb

if isMainModule:
  main()