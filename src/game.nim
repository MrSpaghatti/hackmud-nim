## hackmud-nim — the game shell.
##
## A terminal hacking simulator. Connect to nodes on a net; each node is a
## Nim coding challenge. Author a `solve` proc, run it against hidden tests,
## clear nodes, climb the credit ladder. Terse, dry, hacker-green-on-black.

import std/[os, strutils, sequtils, tables, json, parsecfg]
import challenges
import harness

# ---------------------------------------------------------------- ANSI ----
const
  BOLD   = "\e[1m"
  GREEN  = "\e[32m"
  DIM    = "\e[2m"
  CYAN   = "\e[36m"
  RED    = "\e[31m"
  YELLOW = "\e[33m"
  RST    = "\e[0m"

proc pnl(s: string) = echo s
proc green(s: string) = echo GREEN & s & RST
proc dim(s: string)  = echo DIM & s & RST
proc cyan(s: string) = echo CYAN & s & RST

# ------------------------------------------------------------- game state --
type
  GameState = object
    credits: int
    cleared: Table[string, bool]   # node id -> cleared
    current: string                # connected node id ("" = hub)
    walletInit: int

proc statePath: string =
  getHomeDir() / ".config" / "hackmud" / "state.json"

proc save(g: GameState) =
  createDir(parentDir(statePath()))
  var c: seq[string]
  for id, done in g.cleared:
    if done: c.add "\"" & id & "\":true"
  let body = "{\"credits\":" & $g.credits & ",\"cleared\":{" & c.join(",") & "},\"walletInit\":" & $g.walletInit & "}"
  writeFile(statePath(), body)

proc loadState: GameState =
  var g = GameState(credits: 0, walletInit: 100, cleared: initTable[string, bool](), current: "")
  if fileExists(statePath()):
    try:
      let j = parseFile(statePath())
      g.credits = if j.hasKey("credits"): j["credits"].getInt else: g.walletInit
      g.walletInit = if j.hasKey("walletInit"): j["walletInit"].getInt else: 100
      if j.hasKey("cleared"):
        for k, v in j["cleared"]:
          g.cleared[k] = v.getBool
    except CatchableError:
      discard   # corrupt state → start clean
  g

proc solPath(n: Node): string =
  getHomeDir() / ".config" / "hackmud" / "hacks" / (n.id & ".nim")

# helper: regenerate the stub into the player's solution file
proc writeStub(n: Node) =
  createDir(parentDir(solPath(n)))
  if not fileExists(solPath(n)):
    writeFile(solPath(n), n.stub)

# ------------------------------------------------------------------ banner --
proc banner() =
  cyan "████████╗  ██████╗  ██████╗  "
  cyan "╚══██╔══╝ ██╔═══██╗ ██╔══██╗ "
  cyan "   ██║    ██║   ██║ ██████╔╝ "
  cyan "   ██║    ██║   ██║ ██╔══██╗ "
  cyan "   ██║    ╚██████╔╝ ██████╔╝ "
  cyan "   ╚═╝     ╚═════╝  ╚═════╝  "
  cyan ""
  dim  " hackmud-nim · a Nim hacking sim"
  dim  " type 'help'"
  cyan ""

proc cmdHelp() =
  echo ""
  dim "  help               this list"
  dim "  status             wallet, cleared nodes"
  dim "  map                the net"
  dim "  connect <id>       enter a node, see its challenge"
  dim "  write              (re)write the solution stub to disk"
  dim "  run                compile + test your solve against hidden cases"
  dim "  leave              exit the current node"
  dim "  credits            show wallet"
  dim "  q | quit           leave the network"
  echo ""

proc cmdStatus(g: GameState) =
  echo GREEN & "wallet: " & RST & $g.credits & " CR"
  var clearedItems: seq[string]
  for id, done in g.cleared:
    if done: clearedItems.add id
  if clearedItems.len == 0:
    echo GREEN & "cleared: " & RST & DIM & "none yet" & RST
  else:
    echo GREEN & "cleared: " & RST & clearedItems.join(", ") & " (" & $clearedItems.len & "/" & $allIds().len & ")"

proc cmdMap(g: GameState) =
  echo ""
  cyan "  net  | diff |  reward"
  for id in allIds():
    let n = node(id)
    let mark = (if g.cleared.hasKey(id) and g.cleared[id]: GREEN&"✓"&RST else: DIM&"·"&RST)
    echo  "   " & mark & "  " & n.id.align(9) &
          "  diff " & $n.diff & "  " & YELLOW & "+" & $n.reward & "CR" & RST &
          "  " & DIM & n.region & RST
  echo ""

proc cmdConnect(g: var GameState, id: string) =
  if not has(id):
    echo RED & "no such node: " & id & RST
    return
  g.current = id
  let n = node(id)
  cyan "→ entering " & n.name & RST
  green "  " & n.help & RST
  dim  "  signature: " & n.decl
  dim  "  difficulty " & $n.diff & " · +" & $n.reward & "CR"
  writeStub(n)
  echo DIM & "  stub written to " & solPath(n).quoteShell & RST

# REPL
when isMainModule:
  var g = loadState()
  banner()
  while true:
    stdout.write GREEN & ("you(" & g.current & ")> ") & RST & RST
    stdout.flushFile
    let line = readLine(stdin)
    let parts = line.strip().splitWhitespace()
    if parts.len == 0: continue
    case parts[0]
    of "help", "?":
      cmdHelp()
    of "status", "s":
      cmdStatus(g)
    of "map", "m":
      cmdMap(g)
    of "credits", "c":
      echo GREEN & $g.credits & "CR" & RST
    of "connect":
      if parts.len < 2: echo RED & "usage: connect <id>" & RST
      else: cmdConnect(g, parts[1])
    of "write":
      if g.current.len == 0: echo RED & "connect to a node first" & RST
      else:
        writeStub(node(g.current))
        echo "wrote " & solPath(node(g.current))
    of "leave", "back":
      g.current = ""
      dim "left the node — back at hub"
    of "run":
      if g.current.len == 0:
        echo RED & "connect to a node first" & RST; continue
      let n = node(g.current)
      let p = solPath(n)
      if not fileExists(p):
        echo "no solution yet — 'write' first"; continue
      let src = readFile(p)
      let (v, passed, total, err) = runHarness(n, src, getTempDir() / ("hackmud-" & n.id))
      for line in v: echo line
      echo "  → " & GREEN & $passed & "/" & $total & RST & " passed"
      if passed == total:
        if not (g.cleared.getOrDefault(n.id, false)):
          g.cleared[n.id] = true
          g.credits += n.reward
          echo GREEN & "  node cleared! +" & $n.reward & "CR → wallet " & $g.credits & RST
        else:
          echo DIM & "  already cleared (no extra credit)" & RST
      else:
        echo RED & "  some hidden cases failed — try again" & RST
      save(g)
    of "quit":
      break
    of "name", "prog":
      echo "no."
    else:
      echo "unknown: " & parts[0] & " (try 'help')"