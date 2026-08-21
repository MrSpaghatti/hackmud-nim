# Package

version       = "0.1.0"
author        = "spag"
description   = "hackmud-style terminal hacking game with Nim as the in-game scripting language"
license       = "MIT"
srcDir        = "src"
bin           = @["hackmud-nim"]

# Dependencies
requires "nim >= 2.0.0"

task build, "compile the game":
  exec "nim c --hints:off -o:bin/hackmud-nim src/game.nim"

task run, "build and run":
  exec "nim c -r --hints:off src/game.nim"