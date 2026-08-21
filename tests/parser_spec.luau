--!nonstrict

local host = require("../keybind-cheatsheet/tests/host_mock")

local failures = 0

local function expectEqual(actual, expected, message)
  if actual ~= expected then
    failures += 1
    print("FAIL: " .. message .. " (expected " .. tostring(expected) .. ", got " .. tostring(actual) .. ")")
  else
    print("PASS: " .. message)
  end
end

local function descriptions(bindings)
  local result = {}
  for _, binding in ipairs(bindings) do result[binding.description] = true end
  return result
end

local function treeContainsText(node, text)
  if type(node) ~= "table" then return false end
  if type(node.props) == "table" and node.props.text == text then return true end
  for _, child in ipairs(type(node.children) == "table" and node.children or {}) do
    if treeContainsText(child, text) then return true end
  end
  return false
end

local parserFixtures = {
  ["/fixtures/mango/main.conf"] = [[
# Applications
bind=SUPER,T,spawn,foot #"Terminal"
source=./nested.conf
source=./parts/*.conf
]],
  ["/fixtures/mango/nested.conf"] = [[
# Window Management
bind=SUPER,Q,killclient #"Close window"
source=./main.conf
]],
  ["/fixtures/mango/parts/workspaces.conf"] = [[
# Workspaces
bind=SUPER,1,view,1 #"Workspace 1"
]],
  ["/fixtures/hypr/main.conf"] = [[
$mainMod = SUPER
$bindDir = ./parts
source = $bindDir/*.conf
# 1. Applications
bind = $mainMod, T, exec, foot #"Terminal"
]],
  ["/fixtures/hypr/parts/window.conf"] = [[
# 2. Window Management
bind = SUPER SHIFT, Q, killactive, #"Close window"
]],
  ["/fixtures/niri/config.kdl"] = [[
include "./parts/*.kdl"
binds {
  // #"Applications"
  Mod+T hotkey-overlay-title="Terminal app" { spawn "foot"; }
  Mod+B { spawn "firefox"; }
}
]],
  ["/fixtures/niri/parts/window.kdl"] = [[
binds {
  // #"Window Management"
  Mod+Q hotkey-overlay-title="Close window" { close-window; }
}
]],
}

host.setFiles(parserFixtures)
host.setConfig({ compositor = "mango", mango_config = "/fixtures/mango/main.conf" })

local service = require("../keybind-cheatsheet/service")
local panel = require("../keybind-cheatsheet/panel")

local mango = service.walkConfig("/fixtures/mango/main.conf", service.parseMangoContent)
expectEqual(#mango.bindings, 3, "Mango follows globs and stops include cycles")
expectEqual(descriptions(mango.bindings)["Workspace 1"], true, "Mango keeps descriptions from included files")
expectEqual(mango.rootRead, true, "Mango reads the explicit root config")
expectEqual(service.configReadError(mango), nil, "A readable root config does not produce an error")
expectEqual(service.configReadError({ rootRead = false }), "missing_config", "An unreadable root config produces an error")
expectEqual(service.mangoCategoryFromComment("# Window Management"), "Window Management", "Mango recognizes title-style category comments")
expectEqual(service.mangoCategoryFromComment("# SUPER + x (Cycle presets)"), nil, "Mango ignores explanatory shortcut comments")
expectEqual(service.mangoCategoryFromComment("# ----------------"), nil, "Mango ignores separator comments")
expectEqual(panel.friendlyAction({ action = "view 4,0" }), "Workspace 4", "Mango workspace actions get readable labels")
expectEqual(panel.friendlyAction({ action = "exchange_client left" }), "Move Window Left", "Mango direction actions get readable labels")
expectEqual(panel.friendlyAction({ action = "spawn kitty" }), "Terminal", "Known applications get readable labels")
expectEqual(panel.categoryPriority("Applications") < panel.categoryPriority("Layouts"), true, "Common application categories sort before layouts")
expectEqual(panel.categoryPriority("Without Description") > panel.categoryPriority("Touchpad Gestures"), true, "Fallback categories sort after common controls")
expectEqual(panel.bindingAvailableInView(true, false, false, true), false, "Hidden bindings stay out of the main view")
expectEqual(panel.bindingAvailableInView(true, false, true, true), true, "Hidden bindings remain visible in edit mode")
expectEqual(panel.bindingContentOpacity(true), 0.45, "Hidden binding content is visibly muted")

local hiddenPreferences = {
  [mango.bindings[1].id] = true,
  ["niri|bind|SUPER|Q|close-window;|"] = true,
}
expectEqual(panel.hiddenBindingCount(mango.bindings, hiddenPreferences), 1, "Hidden count only includes the current keymap")
panel.restoreHiddenBindings(mango.bindings, hiddenPreferences)
expectEqual(hiddenPreferences[mango.bindings[1].id], nil, "Restore clears current-keymap hidden entries")
expectEqual(hiddenPreferences["niri|bind|SUPER|Q|close-window;|"], true, "Restore preserves other-keymap hidden entries")

local hypr = service.walkConfig("/fixtures/hypr/main.conf", service.parseHyprContent)
expectEqual(#hypr.bindings, 2, "Hyprland expands variables in recursive source paths")
expectEqual(table.concat(hypr.bindings[1].modifiers, "+"), "SUPER", "Hyprland resolves modifier variables")

local niri = service.walkConfig("/fixtures/niri/config.kdl", service.parseNiriContent)
expectEqual(#niri.bindings, 3, "Niri follows globbed includes")
expectEqual(niri.bindings[1].description, "Terminal app", "Niri reads quoted titles containing spaces")
expectEqual(niri.bindings[2].category, "Applications", "Niri preserves comment categories")

local snapshot = host.stateValue(service.snapshotKey)
expectEqual(snapshot.status, "ready", "Service startup publishes a ready snapshot")
expectEqual(#snapshot.bindings, 3, "Service startup parses the selected compositor")
expectEqual(host.fileContent("/data/bindings-cache.json") ~= nil, true, "Service startup writes the durable cache")
expectEqual(host.updateInterval(), nil, "Service startup does not install an update interval")

panel.onOpen()
expectEqual(panel.lifecycleState().bindingCount, 3, "Panel open renders the prepared service snapshot")
expectEqual(panel.lifecycleState().loading, false, "Prepared snapshots avoid the loading view")
local sourceReads = host.readCount("/fixtures/mango/main.conf")
panel.onClose()
panel.onOpen()
expectEqual(host.readCount("/fixtures/mango/main.conf"), sourceReads, "Panel reopen performs no configuration reads")
host.setConfig({ compositor = "mango", mango_config = "/fixtures/mango/main.conf", columns = 4 })
service.onConfigChanged()
expectEqual(host.readCount("/fixtures/mango/main.conf"), sourceReads, "UI-only setting changes do not reparse the configuration")

host.setFile("/fixtures/mango/main.conf", [[
# Applications
bind=SUPER,T,spawn,foot #"Terminal"
bind=SUPER,B,spawn,firefox #"Browser"
]])
panel.onIpc("refresh")
snapshot = host.stateValue(service.snapshotKey)
expectEqual(snapshot.status, "ready", "Manual refresh publishes a ready snapshot")
expectEqual(#snapshot.bindings, 2, "Manual refresh reparses the configuration")
expectEqual(panel.lifecycleState().bindingCount, 2, "An open panel receives the refreshed snapshot")

host.setFile("/fixtures/mango/main.conf", nil)
panel.onIpc("refresh")
snapshot = host.stateValue(service.snapshotKey)
expectEqual(snapshot.status, "ready", "Refresh failure keeps the last-known-good status")
expectEqual(#snapshot.bindings, 2, "Refresh failure preserves the last-known-good bindings")
expectEqual(snapshot.error, "missing_config", "Refresh failure is attached to the retained snapshot")

panel.onExit(0)
host.resetRuntime()
host.setConfig({ compositor = "mango", mango_config = "/fixtures/mango/main.conf" })
service.resetForTests()
snapshot = host.stateValue(service.snapshotKey)
expectEqual(#snapshot.bindings, 2, "A new service session restores the durable cache before a failed parse")
expectEqual(snapshot.error, "missing_config", "A failed startup parse leaves the restored cache available")
expectEqual(host.updateInterval(), nil, "A restored cache does not enable periodic work")

host.setFile("/fixtures/mango/main.conf", [[
# Applications
bind=SUPER,T,spawn,foot #"Terminal"
bind=SUPER,B,spawn,firefox #"Browser"
]])
host.setFile("/data/bindings-cache.json", "invalid cache")
host.resetRuntime()
host.setConfig({ compositor = "mango", mango_config = "/fixtures/mango/main.conf" })
service.resetForTests()
snapshot = host.stateValue(service.snapshotKey)
expectEqual(#snapshot.bindings, 2, "A fresh parse recovers from a corrupt cache")
expectEqual(host.fileContent("/data/bindings-cache.json") ~= "invalid cache", true, "Recovery replaces the corrupt cache")

host.setFiles({
  ["/fixtures/glob/main.conf"] = "# Applications\nsource=./parts/*.conf\n",
  ["/fixtures/glob/parts/one.conf"] = "bind=SUPER,1,spawn,one #\"One\"\n",
})
host.resetRuntime()
host.setConfig({ compositor = "mango", mango_config = "/fixtures/glob/main.conf" })
service.resetForTests()
expectEqual(service.lifecycleState().bindingCount, 1, "Glob fixture starts with one included binding")
host.setFile("/fixtures/glob/parts/two.conf", "bind=SUPER,2,spawn,two #\"Two\"\n")
service.refresh()
expectEqual(service.lifecycleState().bindingCount, 2, "Manual refresh discovers new glob matches")

local largeMango = { "# Applications" }
for index = 1, 96 do
  table.insert(largeMango, "bind=SUPER," .. tostring(index) .. ",spawn,app" .. tostring(index) .. " #\"App " .. tostring(index) .. "\"")
end
host.setFiles({ ["/fixtures/mango/large.conf"] = table.concat(largeMango, "\n") })
host.resetRuntime()
host.setConfig({ compositor = "mango", mango_config = "/fixtures/mango/large.conf" })
service.resetForTests()
expectEqual(service.lifecycleState().bindingCount, 96, "A 96-binding keymap parses without panel ticks")
expectEqual(host.wantsSecondTicks(), false, "The service architecture never enables panel ticks")
expectEqual(host.updateInterval(), nil, "The service remains event-driven after a large parse")

host.setFiles({ ["/fixtures/hypr/live.lua"] = "-- 1. Applications\n" })
host.resetRuntime()
host.setConfig({
  compositor = "hyprland",
  hyprland_parser = "lua",
  hyprland_lua_config = "/fixtures/hypr/live.lua",
})
host.setAvailableCommands({ hyprctl = true })
service.resetForTests()
expectEqual(host.asyncLaunchCount(), 1, "Hyprland Lua startup launches one live bind request")
service.refresh()
service.refresh()
expectEqual(host.asyncLaunchCount(), 1, "Repeated live refresh requests do not overlap")
host.completeAsync(1, { exitCode = 0, stdout = "[]", stderr = "", timedOut = false })
expectEqual(host.asyncLaunchCount(), 2, "Repeated live refresh requests coalesce into one follow-up")
host.completeAsync(2, { exitCode = 0, stdout = "[]", stderr = "", timedOut = false })
expectEqual(service.lifecycleState().refreshing, false, "Hyprland refresh returns the service to idle")

panel.onOpen()
expectEqual(panel.lifecycleState().bindingCount, 0, "The panel accepts an empty successful live snapshot")
panel.onClose()
local rendersAfterClose = host.renderCount()
service.refresh()
host.completeAsync(3, { exitCode = 0, stdout = "[]", stderr = "", timedOut = false })
expectEqual(host.renderCount(), rendersAfterClose, "Service updates cannot render a closed panel")
expectEqual(panel.lifecycleState().callbackCount, 0, "Panel close releases dynamic callbacks")

host.resetRuntime()
panel.onOpen()
expectEqual(panel.lifecycleState().loading, true, "A missing service snapshot renders a loading state")
expectEqual(treeContainsText(host.renderedTree(), "binding_count"), false, "A cold loading header does not display a zero count")
local niriSingleQuote = service.walkConfig("/fixtures/niri/single_quote.kdl", service.parseNiriContent)
host.setFiles({
  ["/fixtures/niri/single_quote.kdl"] = [[include './parts/window.kdl']],
  ["/fixtures/niri/parts/window.kdl"] = [[binds { Mod+Q { close-window; } }]],
})
niriSingleQuote = service.walkConfig("/fixtures/niri/single_quote.kdl", service.parseNiriContent)
expectEqual(#niriSingleQuote.bindings, 1, "Niri parses single-quoted include directives")

local luaScan = service.scanHyprLua("/fixtures/hypr/complex.lua")
host.setFiles({
  ["/fixtures/hypr/complex.lua"] = [[
-- 1. CustomCategory
hl.bind("SUPER + 1", "exec foo", { description = "" .. "Bar" })
hl.bind("SUPER + 2", "exec bar", {
  description = "Baz"
})
hl.bind("SUPER + 3", "exec workspace", { description = "Workspace " .. i })
]],
})
luaScan = service.scanHyprLua("/fixtures/hypr/complex.lua")
local hyprJsonTest = function() return {{ key = "1", dispatcher = "exec", arg = "foo", description = "Bar", modmask = 64 }, { key = "2", dispatcher = "exec", arg = "bar", description = "Baz", modmask = 64 }, { key = "3", dispatcher = "exec", arg = "workspace", description = "Workspace 1", modmask = 64 }} end
local parsedLuaJson = service.parseHyprJson(host.noctalia.json.encode(hyprJsonTest()), luaScan.rules) or {}
expectEqual(#parsedLuaJson, 3, "Hyprland Lua JSON parses 3 bindings with complex rules")
expectEqual(parsedLuaJson[1].category, "CustomCategory", "Hyprland Lua maps empty string prefix concatenation to category")
expectEqual(parsedLuaJson[2].category, "CustomCategory", "Hyprland Lua maps multiline description assignments to category")
expectEqual(parsedLuaJson[3].category, "CustomCategory", "Hyprland Lua maps concatenated descriptions to category")

local shortKeyPill = panel.keyPill("D", "default", "key")
expectEqual(shortKeyPill.props.minWidth, 20, "Short key pill specifies minWidth to prevent QML elision")
expectEqual(shortKeyPill.children[1].props.text, "D", "Short key pill contains exact key text D")
expectEqual(shortKeyPill.children[1].props.maxLines, nil, "Short key pill label omits maxLines to prevent elision")

expectEqual(panel.formatKey("up"), "↑", "formatKey maps lowercase 'up' to arrow symbol ↑")
expectEqual(panel.formatKey("Up"), "↑", "formatKey maps titlecase 'Up' to arrow symbol ↑")
expectEqual(panel.formatKey("UP"), "↑", "formatKey maps uppercase 'UP' to arrow symbol ↑")
expectEqual(panel.formatKey("down"), "↓", "formatKey maps lowercase 'down' to arrow symbol ↓")
expectEqual(panel.formatKey("Down"), "↓", "formatKey maps titlecase 'Down' to arrow symbol ↓")
expectEqual(panel.formatKey("left"), "←", "formatKey maps lowercase 'left' to arrow symbol ←")
expectEqual(panel.formatKey("Left"), "←", "formatKey maps titlecase 'Left' to arrow symbol ←")
expectEqual(panel.formatKey("right"), "→", "formatKey maps lowercase 'right' to arrow symbol →")
expectEqual(panel.formatKey("Right"), "→", "formatKey maps titlecase 'Right' to arrow symbol →")
expectEqual(panel.formatKey("RETURN"), "Enter", "formatKey maps uppercase 'RETURN' to Enter")
expectEqual(panel.formatKey("Return"), "Enter", "formatKey maps titlecase 'Return' to Enter")
expectEqual(panel.formatKey("escape"), "Esc", "formatKey maps lowercase 'escape' to Esc")
expectEqual(panel.formatKey("Page_Up"), "PgUp", "formatKey maps 'Page_Up' to PgUp")
expectEqual(panel.formatKey("Page_Down"), "PgDn", "formatKey maps 'Page_Down' to PgDn")
expectEqual(panel.formatKey("Prior"), "PgUp", "formatKey maps 'Prior' to PgUp")
expectEqual(panel.formatKey("Next"), "PgDn", "formatKey maps 'Next' to PgDn")
expectEqual(panel.formatKey("BackSpace"), "Backspace", "formatKey maps 'BackSpace' to Backspace")
expectEqual(panel.formatKey("Delete"), "Del", "formatKey maps 'Delete' to Del")
expectEqual(panel.formatKey("D"), "D", "formatKey preserves regular key characters")

local arrowKeyPill = panel.keyPill(panel.formatKey("up"), "default", "key")
expectEqual(arrowKeyPill.children[1].props.text, "↑", "Arrow key pill renders ↑ arrow glyph")

if failures > 0 then
  error(tostring(failures) .. " parser test(s) failed")
end
