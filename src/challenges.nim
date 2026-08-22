## hackmud-nim challenge registry.
##
## Each node is a coding challenge. The player writes a `solve` proc that
## satisfies a fixed per-node signature, then "runs" it: the game compiles it
## and tests it against hidden cases the player never sees.
##
## Test encoding: each test stores literal Nim *code* fragments.
##   - `args` is a seq, one element per parameter, each being a valid Nim
##     literal (or expression) for that parameter's type. e.g. for
##     `proc solve(a: int, b: int)` -> @["17", "-3"].
##   - `want` is the expected result as a literal of the return type.
## The harness generates `let a = <args[0]>; let b = <args[1]>; ...`,
## calls `solve(a, b, ...)`, and does a typed `got == want` comparison.

import std/[json, sequtils, tables]

type
  Test* = object
    args*: seq[string]   ## per-param literal code
    want*: string        ## expected-result literal code

  Node* = object
    id*: string          # e.g. "saw-01"
    region*: string
    name*: string
    diff*: int           # 1..5
    reward*: int         # credits on first clear
    flavor*: string      # lore line
    help*: string        # what to implement
    sig*: string         # printed declaration, e.g. "proc solve(s: string): string"
    decl*: string        # Nim code emitted as the function header (player fills body)
    stub*: string        # full text written to the player's solution file
    tests*: seq[Test]

proc t(args: seq[string], want: string): Test =
  Test(args: args, want: want)

## ------------------------------------------------------------------ nodes ---
## Deliberately small: 8 nodes spanning string ops, arithmetic, seq logic,
## and a cipher. Each has hidden tests the player must satisfy.
const NODE_DEFS* = @[
  Node(
    id: "seed-01", region: "START",
    diff: 1, reward: 25,
    name: "echo bay",
    help: "Return the input string unchanged.",
    decl: "proc solve(s: string): string",
    stub: """proc solve(s: string): string =
  ## Return s verbatim.
  s""",
    tests: @[
      t(@["\"ping\""], "ping"),
      t(@["\"\""], ""),
      t(@["\"hackmud\""], "hackmud"),
    ]),

  Node(
    id: "saw-01", region: "cortex",
    diff: 1, reward: 40,
    name: "reverse cut",
    flavor: "A reversed mirror in the cortex floods everything you give it.",
    decl: "proc solve(s: string): string",
    stub: """proc solve(s: string): string =
  ## Return rev(s). You may add any std import.
  s""",
    tests: @[
      t(@["\"abc\""], "cba"),
      t(@["\"hello world\""], "dlrow olleh"),
      t(@["\"racecar\""], "racecar"),
      t(@["\"A\""], "A"),
    ]),

  Node(
    id: "add-03", region: "cortex",
    diff: 1, reward: 50,
    name: "sum gate",
    decl: "proc solve(a: int, b: int): int",
    stub: """proc solve(a: int, b: int): int =
  ## Return a + b.
  a""",
    tests: @[
      t(@["1", "2"], "3"),
      t(@["0", "0"], "0"),
      t(@["-5", "12"], "7"),
      t(@["100", "250"], "350"),
    ]),

  Node(
    id: "max-03", region: "cortex",
    diff: 2, reward: 75,
    name: "peak seeker",
    help: "Return the maximum of a non-empty list of ints.",
    decl: "proc solve(xs: seq[int]): int",
    stub: """proc solve(xs: seq[int]): int =
  ## Return the maximum element. xs is never empty.
  0""",
    tests: @[
      t(@["@[3,7,2]"], "7"),
      t(@["@[-1,-5,-3]"], "-1"),
      t(@["@[42]"], "42"),
      t(@["@[9,9,9,1]"], "9"),
    ]),

  Node(
    id: "fib-01", region: "limbic",
    diff: 3, reward: 150,
    name: "fibonacci flame",
    help: "Return fib(n); fib(0)=0, fib(1)=1.",
    decl: "proc solve(n: int): int",
    stub: """proc solve(n: int): int =
  ## Return fib(n). fib(0)=0, fib(1)=1.
  0""",
    tests: @[
      t(@["0"], "0"),
      t(@["1"], "1"),
      t(@["6"], "8"),
      t(@["10"], "55"),
    ]),

  Node(
    id: "crypt-01", region: "lattice",
    diff: 3, reward: 150,
    name: "caesar relay",
    help: "Caesar cipher `plain` right by `shift` over a..z (wraps), pass others through.",
    decl: "proc solve(plain: string, shift: int): string",
    stub: """proc solve(plain: string, shift: int): string =
  ## Caesar cipher over lowercase a..z, shift right by `shift` (wraps).
  ## Only lowercase letters transform; everything else passes through.
  plain""",
    tests: @[
      t(@["\"abc\"", "1"], "bcd"),
      t(@["\"xyz\"", "1"], "yza"),
      t(@["\"hello world\"", "3"], "khoor zruog"),
      t(@["\"abc\"", "0"], "abc"),
      t(@["\"ABC\"", "1"], "ABC"),
    ]),

  Node(
    id: "prime-01", region: "lattice",
    diff: 3, reward: 200,
    name: "prime probe",
    help: "Return whether n is prime (n >= 1).",
    decl: "proc solve(n: int): bool",
    stub: """proc solve(n: int): bool =
  ## Return true if n is prime. n >= 1.
  false""",
    tests: @[
      t(@["1"], "false"),
      t(@["2"], "true"),
      t(@["17"], "true"),
      t(@["100"], "false"),
      t(@["7919"], "true"),
    ]),

  Node(
    id: "lock-01", region: "lattice",
    diff: 4, reward: 350,
    name: "dedup firewall",
    help: "Return src with duplicates removed, first-occurrence order preserved.",
    decl: "proc solve(src: seq[int]): seq[int]",
    stub: """proc solve(src: seq[int]): seq[int] =
  ## Return src with duplicates removed, order preserved
  ## (first occurrence position wins).
  src""",
    tests: @[
      t(@["@[1,2,2,3]"], "@[1, 2, 3]"),
      t(@["@[5,5,5]"], "@[5]"),
      t(@["@[3,1,2,1]"], "@[3, 1, 2]"),
      t(@["@[]"], "@[]"),
    ]),

  Node(
    id: "count-01", region: "cortex",
    diff: 2, reward: 80,
    name: "count chars",
    help: "count occurrences of char c in string s.",
    decl: "proc solve(s: string, c: char): int",
    stub: """proc solve(s: string, c: char): int =
  ## count occurrences of char c in string s.
  0""",
    tests: @[
      t(@["\"hello\"", "'l'"], "2"),
      t(@["\"abc\"", "'z'"], "0"),
      t(@["\"\"", "'a'"], "0"),
      t(@["\"aaa\"", "'a'"], "3"),
    ]),

  Node(
    id: "sumlist-01", region: "cortex",
    diff: 2, reward: 90,
    name: "sum list",
    help: "sum of the list (empty = 0).",
    decl: "proc solve(xs: seq[int]): int",
    stub: """proc solve(xs: seq[int]): int =
  ## sum of the list (empty = 0).
  0""",
    tests: @[
      t(@["@[1, 2, 3]"], "6"),
      t(@["@[]"], "0"),
      t(@["@[-1, 1]"], "0"),
      t(@["@[5, 5, 5]"], "15"),
    ]),

  Node(
    id: "anagram-01", region: "limbic",
    diff: 3, reward: 180,
    name: "anagram",
    help: "true if a and b are anagrams (case-sensitive, ignore nothing).",
    decl: "proc solve(a, b: string): bool",
    stub: """proc solve(a, b: string): bool =
  ## true if a and b are anagrams (case-sensitive, ignore nothing).
  false""",
    tests: @[
      t(@["\"listen\"", "\"silent\""], "true"),
      t(@["\"hello\"", "\"world\""], "false"),
      t(@["\"\"", "\"\""], "true"),
      t(@["\"a\"", "\"a\""], "true"),
      t(@["\"a\"", "\"b\""], "false"),
      t(@["\"Abc\"", "\"cba\""], "false"),
    ]),

  Node(
    id: "collatz-01", region: "limbic",
    diff: 3, reward: 220,
    name: "collatz",
    help: "number of steps to reach 1 (n >= 1; collatz(1)=0).",
    decl: "proc solve(n: int): int",
    stub: """proc solve(n: int): int =
  ## number of steps to reach 1 (n >= 1; collatz(1)=0).
  0""",
    tests: @[
      t(@["1"], "0"),
      t(@["2"], "1"),
      t(@["3"], "7"),
      t(@["12"], "9"),
    ]),
]

## ----------------------------------------------------------------- lookups --
var byId*: Table[string, Node]
var order*: seq[string]   # stable insertion order for the map

proc initRegistry* =
  ## Build lookup tables from the const. Call once at startup.
  ## (Const seqs can't be iterated at compile time for table building,
  ##  so we do it lazily and cache.)
  for n in NODE_DEFS:
    byId[n.id] = n
    order.add n.id

proc ensureInit =
  ## Idempotent lazy init; safe to call from any accessor.
  if order.len == 0 and NODE_DEFS.len > 0:
    initRegistry()

proc node*(id: string): Node =
  ensureInit()
  byId[id]

proc has*(id: string): bool =
  ensureInit()
  id in byId

proc allIds*: seq[string] =
  ensureInit()
  order

## ------------------------------------------------------------------ JSON ---
proc nodeToJson*(n: Node): JsonNode =
  ## Serialize the non-test fields (for the game's "map" / saved state).
  %*{
    "id": n.id,
    "region": n.region,
    "name": n.name,
    "diff": n.diff,
    "reward": n.reward,
    "flavor": n.flavor,
  }