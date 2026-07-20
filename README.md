# Noctalia Keybind Cheatsheet

A Noctalia v5 plugin source containing the `kenn/keybind-cheatsheet` plugin.
It reads Mango, Hyprland, or Niri keybindings only while its panel is open.

For installation, configuration, compositor keybinds, and IPC commands, see
[`keybind-cheatsheet/README.md`](keybind-cheatsheet/README.md).

Hyprland and Niri users can help validate real compositor behavior using the
[`TESTING.md`](TESTING.md) checklist before the community-store submission.

## Local development

Add this checkout as a path source, enable the plugin, then add its `keybinds`
widget to a bar:

```sh
noctalia msg plugins source add keybind-dev path "$PWD"
noctalia msg plugins enable kenn/keybind-cheatsheet
```

Luau files hot-reload. Reload Noctalia configuration after changing
`plugin.toml`.
