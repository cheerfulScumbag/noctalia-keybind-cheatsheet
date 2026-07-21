# Keybind Cheatsheet Project Scope

## Purpose

Keybind Cheatsheet uses one event-driven Noctalia data service to read and cache
compositor keybindings for a searchable panel and bar widget. The service stays
resident while the plugin is enabled but performs no recurring work.

Supported sources:

- Mango configuration files
- Hyprland `.conf` files
- Hyprland Lua configuration with live `hyprctl binds -j` data
- Niri KDL configuration files
- Recursive includes and glob patterns supported by each parser

The existing parser capabilities, user interface, saved descriptions, hidden
bindings, colors, search, and column layout remain in scope.

## Architecture Decision

Keep the plugin in Luau and retain the existing compositor parsers. Move parser,
cache, and refresh ownership into one data service. The service publishes an
atomic shared snapshot; the panel only reads that snapshot and renders it.

Do not add:

- More than one data service for parsing and cache ownership
- A filesystem watcher or polling timer
- An external parser process
- A panel-tick or per-binding parsing scheduler
- Undocumented Luau module loading or a generated build bundle

The single service is allowed to load the durable cache and parse the selected
configuration once during Noctalia's script-load budget. After that it remains
idle until settings change or the user explicitly requests a refresh.

## Data Lifecycle

### Service startup without a cache

1. Publish a lightweight loading snapshot.
2. Parse the configured sources during the initial script-load budget.
3. Persist and publish the complete last-known-good snapshot.
4. Remain idle with no update interval, watcher, or subprocess.

### Service startup with a cache

1. Load and publish matching disk-cached bindings immediately.
2. Parse the selected configuration once.
3. Replace the snapshot and cache only after a complete successful parse.
4. Preserve the cached snapshot with a warning when parsing fails.

### Panel opening

1. Read the current shared snapshot.
2. Reset search and editing view state.
3. Render without reading configuration files or decoding the disk cache.

### Manual refresh

The refresh button and refresh IPC command send a shared request to the data
service and perform a complete rescan. Repeated requests while one is active
are coalesced. Successful results replace the display and cache atomically.
Failed results leave the previous bindings visible and report the error.

### While the panel is closed

The service retains its in-memory snapshot but performs no parsing, polling,
watching, or scheduled work. The disk cache survives Noctalia restarts, system
reboots, and plugin updates.

## Cache Contract

Store the cache under `noctalia.pluginDataDir()` with a schema version. Cache
data contains normalized bindings and source metadata for diagnostics and
future schema migrations.

The recorded cache metadata includes:

- Cache schema
- Selected compositor
- Parser mode and configured root paths
- Parsed source paths with file size and modification time
- Glob patterns with enough directory metadata to detect added or removed files

Missing, malformed, or incompatible cache data is treated as a cache miss. It
must never prevent a fresh parse. The service performs one fresh parse at every
startup regardless of cache availability. Description, visibility, and color
preferences remain separate from the parsed-binding cache.

Hyprland Lua is a special case: cached bindings are published first, followed
by an asynchronous startup `hyprctl binds -j` refresh because live runtime
bindings cannot be validated solely through file timestamps.

## Performance And Failure Rules

- Cached openings must display useful bindings without an empty loading panel.
- Parsing, grouping, and UI construction must be timed separately in Noctalia.
- Optimize repeated string work, translations, derived display values, and UI
  construction before adding scheduling complexity.
- A refresh must never change the visible count to zero while valid cached data
  exists.
- Commit a new cache only after a complete successful parse.
- A parse error, panel close, or stale async callback must not overwrite the
  last successful model.
- No timer or subprocess may remain active after startup or refresh work
  completes.

## Current Remediation Scope

1. Remove the experimental panel scheduler.
2. Move existing parsers and durable cache ownership into one data service.
3. Publish cache-first, last-known-good shared snapshots.
4. Make panel opening and refresh follow the lifecycle defined above.
5. Measure startup parsing, explicit refresh, and declarative UI construction
   independently inside the real Noctalia host.
6. Add regression tests, validate Mango locally, and request Hyprland and Niri
   community testing.

If parsing alone still exceeds the host callback budget after targeted
optimization, stop and document the measurements and supported alternatives
before implementing another scheduling strategy.

## Acceptance Criteria

- First-ever opening completes without callback timeout on the maintained Mango
  fixture and a representative real configuration.
- Reopening the panel in the same session is immediate.
- Opening after a reboot uses the durable cache immediately.
- Startup and forced refresh discover changes to root files, recursively
  included files, and glob membership.
- Forced refresh always performs a complete rescan.
- Refresh failure and corrupt cache recovery never discard a valid prior view.
- The service has no update interval, watcher, polling loop, or persistent
  subprocess after startup work completes.
- Parser fixture tests continue to pass for every supported compositor mode.
