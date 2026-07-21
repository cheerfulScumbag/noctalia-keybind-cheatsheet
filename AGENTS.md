# Project Guidance

## Product Boundary

- This is a Noctalia data service, panel, and bar widget written in Luau.
- Support Mango, Hyprland configuration, Hyprland Lua through
  `hyprctl binds -j`, and Niri without compositor-specific background services.
- Preserve low idle resource use: one event-driven data service may load the
  durable cache and parse once at plugin startup, but it must not use a
  filesystem watcher, polling loop, recurring timer, or persistent process.
- Treat [PROJECT.md](PROJECT.md) as the source of truth for lifecycle, caching,
  refresh behavior, and current remediation scope.

## Implementation Decisions

- Prefer Noctalia's documented declarative UI and runtime APIs.
- Keep the existing parser behavior unless a measured defect requires a
  narrowly scoped change. Do not replace it as part of the cache work.
- Use a cache-first, last-known-good model. Never clear valid bindings while a
  refresh is in progress or because a refresh failed.
- Keep parser, cache, and refresh ownership in the data service. Panel
  `onOpen()` may only read the shared snapshot, reset view state, and render.
- The refresh button must bypass freshness checks and force a complete rescan.
- Do not use panel ticks as a parsing scheduler. The data service refreshes only
  at startup, after relevant plugin setting changes, or on an explicit request.
- Do not introduce `require()`-based runtime modules unless Noctalia documents
  plugin module loading. Organize the single entry file internally instead.
- Measure parsing and UI construction separately against the installed
  Noctalia callback budgets before choosing another scheduling mechanism.

## Change Control

- When the user requests investigation, review, or a plan, do not change
  implementation files until they explicitly approve implementation.
- If behavior is unsupported, uncertain, or requires a fragile workaround,
  stop before changing code. Explain the limitation and tradeoffs, present the
  practical alternatives, and ask which direction to take.
- Do not silently approximate a design with unusual encoding, undocumented
  properties, or fragile rendering behavior.
- Prefer supported visual alternatives such as muted colors or reduced opacity
  before proposing a text-encoding workaround.
- Keep an approved workaround narrowly scoped and document why it is necessary.

## Verification

- Cover cache miss, cache restore followed by refresh, corrupt cache, forced
  refresh, and refresh failure without losing the last successful bindings.
- Test changes to included files and glob directories, not only the root config.
- Keep parser fixture coverage for Mango, Hyprland conf, Hyprland Lua, and Niri.
- Verify real startup, refresh, and panel callback timing inside Noctalia;
  tight-loop host mocks are not a substitute for the host budgets.
