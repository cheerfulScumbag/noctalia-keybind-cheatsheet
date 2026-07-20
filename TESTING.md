# Compositor Testing

Mango is tested on a live desktop. The automated fixture suite covers Mango,
Hyprland classic configuration, Hyprland Lua metadata, `hyprctl binds -j`, and
Niri configuration parsing. Real Hyprland and Niri sessions are still needed
before the first community-store submission.

## Install the test source

```sh
noctalia msg plugins source add keybind-cheatsheet git https://github.com/cheerfulScumbag/noctalia-keybind-cheatsheet
noctalia msg plugins enable kenn/keybind-cheatsheet
```

Open or close the panel with:

```sh
noctalia msg panel-toggle kenn/keybind-cheatsheet:cheatsheet
```

The `keybinds` bar widget should also appear in Noctalia's widget picker.

## Test matrix

Testing is needed for:

- Hyprland classic `.conf` configuration
- Hyprland 0.55 or newer with Lua configuration
- Niri with a single configuration file
- Niri with recursive or globbed `include` files
- Non-default configuration paths for every compositor
- Automatic compositor detection and explicitly selected parser modes

For Hyprland Lua mode, install `hyprctl` and confirm that `hyprctl binds -j`
works before opening the panel.

## Checks

1. Confirm the panel opens, closes, and reopens from both IPC and the bar widget.
2. Confirm every expected binding appears with readable modifiers and keys.
3. Compare bindings from recursively included and globbed files.
4. Search by key, description, action, and category.
5. Hide a binding, close the panel, reopen it, and confirm the choice persists.
6. Restore hidden bindings and confirm bindings hidden for another compositor are unchanged.
7. Add a custom description and color, then confirm both persist after reopening.
8. Refresh repeatedly and confirm only the final keymap is shown without errors.
9. Run the parser self-test:

   ```sh
   noctalia msg plugin kenn/keybind-cheatsheet:cheatsheet all self-test
   ```

## Reporting results

Open a
[compositor test report](https://github.com/cheerfulScumbag/noctalia-keybind-cheatsheet/issues/new?template=compositor-test.yml).
Include:

- Noctalia version
- Compositor and version
- Parser mode
- Whether automatic detection worked
- Whether includes, search, editing, persistence, refresh, IPC, and the bar widget worked
- The exact visible error and relevant Noctalia log lines when something failed

Do not attach a complete private compositor configuration. Reduce failures to a
small sanitized example that still reproduces the problem.
