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
| `F`      | `F` | `Left Option`  | Cross-hand Alt chords and WM prefix     |
| `J`      | `J` | `Right Option` | Option available from the opposite hand |

The old Caps Word position is plain `Tab`.

This makes the core app chords ergonomic:

- tmux prefix: hold left thumb `Ctrl`, tap right thumb `Space`.
- Vim/tmux panes: hold left thumb `Ctrl`, press `h/j/k/l`.
- Neovim Alt actions: hold the opposite-hand `Option` key, then press the action
  key.
- AeroSpace: hold `F` for `Option`, tap `;`, release both, then press one action
  key from the prefix table below.

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

## AeroSpace Prefix Mode

The same sequence works on both keyboards:

- US Mac keyboard: hold `Option`, tap `;`, release both, then press an action
  key.
- Voyager: hold `F`, tap `;`, release both, then press an action key.

Each action automatically returns AeroSpace to its main mode.

| Key                 | Action                                 |
| ------------------- | -------------------------------------- |
| `h/j/k/l`           | Focus left/down/up/right               |
| `y/u/i/o`           | Move window left/down/up/right         |
| `e` or `/`          | Tile or rotate the tiled orientation   |
| `s/w`               | Vertical/horizontal accordion          |
| `b`                 | Balance tiled window sizes             |
| `Space`             | Toggle the focused window floating     |
| `1`-`0`             | Switch to workspace 1-10               |
| `Shift-1`-`Shift-0` | Move window to workspace 1-10          |
| `p/n`               | Switch to previous/next workspace      |
| `m`                 | Focus the next monitor                 |
| `Shift-m`           | Move the window to the next monitor    |
| `f`                 | Toggle fullscreen                      |
| `r`                 | Enter resize mode                      |
| `g`                 | Open the searchable system key guide   |
| `Enter`             | Open a new Kitty instance              |
| `;`                 | Enter the less-common service commands |
| `Esc`               | Cancel the prefix                      |

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
   - `Ctrl + h/j/k/l` moves through Neovim splits and tmux panes.
   - Bare `Alt` bindings reach Neovim and Snacks.
   - Hold `Option`, tap `;`, release, then tap `h/j/k/l` to move through
     AeroSpace windows.
   - Hold `Option`, tap `;`, release, then tap `y/u/i/o` to move AeroSpace
     windows.
   - Hold `Option`, tap `;`, release, then tap `g` to open the key guide.
   - Hold `Control`, tap `Space`, release, then tap `g` to open the tmux guide.
5. If any dual-function key misfires, tune that key before adding more layers.
