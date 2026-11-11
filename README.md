# Column Control

A Quickshell plugin for Omarchy that combines a bar widget for selecting the focused window's width in Hyprland's scrolling layout with configurable screen hot corners.

The compact card offers narrow, normal, wide, full-width, and fullscreen actions. Expand it to customize the three preset percentages. Values are stored in `~/.config/omarchy/column-width.json`.

Hot corners work on every monitor. By default, the top-left corner opens the Column Control popup. In the expanded card, adjust trigger size and delay, then click a corner's action to cycle between disabled, opening Column Control, and showing the desktop. These settings are saved to `~/.config/omarchy/hot-corners.json`. You can still configure argument-list commands there:

```json
{
  "size": 6,
  "delayMs": 120,
  "corners": {
    "top-left": { "action": "open-column-control" },
    "top-right": { "action": "command", "command": ["omarchy", "capture", "screenshot"] }
  }
}
```

Corner names are `top-left`, `top-right`, `bottom-left`, and `bottom-right`. Preset actions are `open-column-control`, `show-desktop`, `focus-left`, `focus-right`, and `center-focused`; `command` with a non-empty argument array is also supported. Unlisted corners are disabled. The default corner configuration opens Column Control from the top-left, centers the focused column from the top-right, and focuses left or right from the lower corners.

## Install

Copy this directory to `~/.config/omarchy/plugins/zm.column-control`, add `zm.column-control` to `plugins` and its bar widget to the bar layout in `~/.config/omarchy/shell.json`. Bind a key with `{ panel = "zm.column-control" }` if desired.
