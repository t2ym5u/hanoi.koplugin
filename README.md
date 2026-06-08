# Towers of Hanoi

> **Status: stub — not yet implemented**

## Description

Classic Tower of Hanoi: move a stack of disks from peg A to peg C, never placing a larger disk on a smaller one.

## Files to create

- `board.lua` — game logic, puzzle generator, serialize/load
- `board_widget.lua` — grid rendering and tap gestures
- `screen.lua` — full-screen layout (buttons + board)
- `main.lua` — PluginBase entry point

## Notes

Placement/deduction game — adapt InputContainer pattern from game-common.
