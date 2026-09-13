# ZSA Voyager Oryx Layout

This layout is tuned for a QWERTY Voyager used with Vim, tmux, Kitty, and
AeroSpace. The goal is low finger travel, no same-hand modifier chords for
`h/j/k/l`, and a small number of layers that are easy to remember.

## Principles

- Keep the base letter layout boring. Do not change QWERTY while changing
  modifiers and layers.
- Put `Ctrl` on a thumb hold and `Option` on mirrored home-row index holds so
  common chords do not load the pinkies.
- Keep `Cmd` available on the right side for macOS shortcuts that mostly pair
  with left-hand letters.
- Use layers for missing laptop keys: arrows, symbols, numbers, window actions.
- Keep home-row mods narrow at first. `F` and `J` are enough for Option; do not
  add a full home-row-mod suite until the base layout feels stable.

## Base Layer

Keep letters, numbers, punctuation, and shifted punctuation standard.

Current thumb keys:

| Position    | Tap         | Hold   | Why                             |
| ----------- | ----------- | ------ | ------------------------------- |
| Left thumb  | `Enter`     | `Sym`  | Enter plus symbols              |
| Left thumb  | `Tab`       | `Ctrl` | tmux/Vim panes                  |
| Right thumb | `Backspace` | `Cmd`  | Delete plus macOS shortcuts     |
| Right thumb | `Space`     | `Nav`  | Space plus universal navigation |

Current home-row Option holds:

| Position | Tap | Hold           | Why                                     |
| -------- | --- | -------------- | --------------------------------------- |
| `F`      | `F` | `Left Option`  | AeroSpace `Alt-h/j/k/l` from home row   |
| `J`      | `J` | `Right Option` | Option available from the opposite hand |

The old Caps Word position is plain `Tab`.

This makes the core app chords ergonomic:

- tmux prefix: hold left thumb `Ctrl`, tap right thumb `Space`.
- Vim/tmux panes: hold left thumb `Ctrl`, press `h/j/k/l`.
- AeroSpace windows: hold `F` for `Option`, press `h/j/k/l`.
- AeroSpace move windows: hold `F` for `Option` plus either `Shift`, press
  `h/j/k/l`.
- AeroSpace workspaces: hold `F` for `Option`, press `p`/`n` (or `[`/`]`) for
  previous/next workspace without stretching to the number row.
- AeroSpace move window to workspace: hold `F` for `Option` plus `Shift`, press
  `p`/`n` (or `[`/`]`).
- AeroSpace monitors: hold `F` for `Option`, press `m` to focus the next
  monitor, or `Shift-m` to move the window to the next monitor.

## Nav Layer

Hold right thumb `Space`.

Right-hand navigation cluster:

| Base key | Nav output  |
| -------- | ----------- |
| `h`      | `Left`      |
| `j`      | `Down`      |
| `k`      | `Up`        |
| `l`      | `Right`     |
| `u`      | `Page Down` |
| `i`      | `Page Up`   |
| `y`      | `Home`      |
| `o`      | `End`       |
| `n`      | `Cmd-Left`  |
| `m`      | `Cmd-Right` |
| `,`      | `Alt-Left`  |
| `.`      | `Alt-Right` |

Left-hand utility keys:

| Base key | Nav output |
| -------- | ---------- |
| `q`      | `Esc`      |
| `w`      | `Cmd-w`    |
| `r`      | `Cmd-r`    |
| `t`      | `Cmd-t`    |
| `s`      | `Cmd-s`    |
| `z`      | `Cmd-z`    |
| `x`      | `Cmd-x`    |
| `c`      | `Cmd-c`    |
| `v`      | `Cmd-v`    |

## Sym Layer

Hold left thumb `Enter`.

Keep symbols on the right side and numbers/operators on the left side:

| Base key | Sym output |
| -------- | ---------- |
| `q`      | `1`        |
| `w`      | `2`        |
| `e`      | `3`        |
| `r`      | `4`        |
| `t`      | `5`        |
| `a`      | `6`        |
| `s`      | `7`        |
| `d`      | `8`        |
| `f`      | `9`        |
| `g`      | `0`        |
| `y`      | `[`        |
| `u`      | `]`        |
| `i`      | `{`        |
| `o`      | `}`        |
| `h`      | `-`        |
| `j`      | `=`        |
| `k`      | `_`        |
| `l`      | `+`        |
| `n`      | `/`        |
| `m`      | Backslash  |
| `,`      | Pipe       |
| `.`      | `~`        |

## Optional WM Layer

If Oryx feels better with a dedicated window-manager layer than holding `Alt`,
add a `WM` layer on a left-side hold key or a two-key combo.

| Base key  | WM output       |
| --------- | --------------- |
| `h`       | `Alt-h`         |
| `j`       | `Alt-j`         |
| `k`       | `Alt-k`         |
| `l`       | `Alt-l`         |
| `y`       | `Alt-Shift-h`   |
| `u`       | `Alt-Shift-j`   |
| `i`       | `Alt-Shift-k`   |
| `o`       | `Alt-Shift-l`   |
| `1`       | `Alt-1`         |
| `2`       | `Alt-2`         |
| `3`       | `Alt-3`         |
| `4`       | `Alt-4`         |
| `5`       | `Alt-5`         |
| `6`       | `Alt-6`         |
| `7`       | `Alt-7`         |
| `8`       | `Alt-8`         |
| `9`       | `Alt-9`         |
| `0`       | `Alt-0`         |
| `b`       | `Alt-b`         |
| `f`       | `Alt-f`         |
| `r`       | `Alt-r`         |
| `v`       | `Alt-v`         |
| Backslash | `Alt-Backslash` |

Start without this layer. Add it only if holding `Alt` for AeroSpace still feels
awkward after a day or two.

## Oryx Settings

Use conservative hold/tap behavior:

- Prefer "hold on other key press" for thumb dual-function keys.
- Start with a tapping term around 180-220 ms.
- Increase the tapping term only for keys you accidentally hold.
- Avoid global auto-shift until the base layout is stable.

## Keymapp Checklist

1. Create a new layout revision in Oryx.
2. Apply the Base, Nav, and Sym layers above.
3. Flash with Keymapp.
4. Test these chords:
   - `Ctrl-h/j/k/l` moves through Neovim splits and tmux panes.
   - `Alt-h/j/k/l` moves through AeroSpace windows.
   - `Alt-Shift-h/j/k/l` moves AeroSpace windows.
   - `C-Space` opens tmux prefix mode.
5. If any dual-function key misfires, tune that key before adding the optional
   `WM` layer.
