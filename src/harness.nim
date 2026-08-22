## hackmud-nim solver harness.
##
## Given a Node and a player-written solution file (which defines a `solve`
## proc matching the node's `decl` signature), this module codegens a runner,
## compiles it with the system Nim compiler, runs it, and reports per-case
## PASS/FAIL verdicts.
##
## Isolation model: the player's Nim runs in a throwaway scratch dir via the
## same compiler. It is NOT a real sandbox — a player-supplied proc could touch
## the filesystem. This is acceptable for a local single-player game (documented
## in README). What the harness DOES enforce: a hard wall-clock timeout on the
## runner so an infinite loop / busy-wait costs the player's bandwidth, not the
## host, and the game only reads stdout verdicts — never trusting game logic in.

import std/[os, osproc, strutils]
import challenges

const RunTimeoutMs = 8000   # hard cap on the compiled runner

proc esc(s: string): string =
  ## Escape a string for use as a Nim string-literal fragment.
  s.replace("\\", "\\\\").replace("\"", "\\\"")

proc silentCompile(src: string, binPath: string, workDir: string): string =
  ## Compile src with the system nim; return "" on success or the compiler text.
  let cmd = "nim c --hints:off --warnings:off --verbosity:0 " &
            "--skipParentCfg --skipUserCfg --colors:off " &
            "--out:" & binPath & " " & src
  let (cout, code) = execCmdEx(cmd, workingDir = workDir)
  if code != 0: cout.strip() else: ""

proc runnerSource*(n: Node, solutionSrc: string): string =
  ## The player's solution is pasted verbatim (imports stay in scope).
  ## Each hidden test declares a proc calling `solve` directly with the arg
  ## literals — arg types are inferred from solve's parameter types, which
  ## makes `@seq` literals and `@[]` work. Results are stringified and compared
  ## against the canonical stringified expectation.
  var parts: seq[string]

  parts.add "# hackmud-nim generated runner: " & n.id
  parts.add ""
  parts.add solutionSrc.strip()
  parts.add ""

  for i, tc in n.tests:
    parts.add "proc hack_run" & $i & "(): string ="
    parts.add "  $solve(" & tc.args.join(", ") & ")"
    parts.add ""

  parts.add "proc hack_passes(i: int; got, want: string) ="
  parts.add "  if got == want:"
  parts.add "    echo \"PASS #\", i, \"|\", got"
  parts.add "  else:"
  parts.add "    echo \"FAIL #\", i, \"|\", got, \"|\", want"
  parts.add ""

  parts.add "when isMainModule:"
  for i, tc in n.tests:
    parts.add "  hack_passes(" & $i & ", hack_run" & $i & "(), \"" & esc(tc.want) & "\")"
  parts.add ""

  result = parts.join("\n")

proc runHarness*(n: Node, solutionSrc: string, workRoot: string): tuple[
    verdicts: seq[string], passed: int, total: int, err: string] =
  ## Compile + run player's solution for node `n`, return per-case verdicts.
  createDir(workRoot)
  let safe = n.id.replace('-', '_')
  let srcPath = workRoot / (safe & "_runner.nim")
  let binPath = workRoot / (safe & "_runner")

  writeFile(srcPath, runnerSource(n, solutionSrc))

  # compile
  let cerr = silentCompile(srcPath, binPath, workRoot)
  if cerr.len > 0 or not fileExists(binPath):
    return (@["COMPILE_ERROR"], 0, n.tests.len, cerr)

  # run under `timeout` so a pathological solution can't hang the terminal.
  let secs = (RunTimeoutMs div 1000).max(1)
  let (outp, runExit) = execCmdEx("timeout " & $secs & "s " & binPath,
                                  workingDir = workRoot)
  if runExit == 124:
    return (@["TIMEOUT"], 0, n.tests.len, "runner exceeded " & $RunTimeoutMs & "ms")

  # parse verdicts
  var verdicts: seq[string]
  var passed = 0
  for line in outp.splitLines:
    let l = line.strip()
    if l.startsWith("PASS #"):
      verdicts.add l
      passed.inc
    elif l.startsWith("FAIL #"):
      verdicts.add l

  if verdicts.len == 0:
    return (@["NO_VERDICT"], 0, n.tests.len, outp.strip())

  (verdicts, passed, n.tests.len, "")