--!nonstrict

local host = require("../keybind-cheatsheet/tests/host_mock")
local parser = require("../keybind-cheatsheet/panel")

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

host.setFiles({
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
})

host.setFileExists("/fixtures/mango/main.conf", false)
local mango = parser.walkConfig("/fixtures/mango/main.conf", parser.parseMangoContent)
expectEqual(#mango.bindings, 3, "Mango follows globs and stops include cycles")
expectEqual(descriptions(mango.bindings)["Workspace 1"], true, "Mango keeps descriptions from included files")
expectEqual(mango.rootRead, true, "Mango reads explicit paths without a racy existence pre-check")
expectEqual(parser.configReadError(mango), nil, "A readable root config does not produce an error")
expectEqual(parser.configReadError({ rootRead = false }), "missing_config", "An unreadable root config produces an error")
expectEqual(parser.mangoCategoryFromComment("# Window Management"), "Window Management", "Mango recognizes title-style category comments")
expectEqual(parser.mangoCategoryFromComment("# SUPER + x (Cycle presets)"), nil, "Mango ignores explanatory shortcut comments")
expectEqual(parser.mangoCategoryFromComment("# ----------------"), nil, "Mango ignores separator comments")
expectEqual(parser.friendlyAction({ action = "view 4,0" }), "Workspace 4", "Mango workspace actions get readable labels")
expectEqual(parser.friendlyAction({ action = "exchange_client left" }), "Move Window Left", "Mango direction actions get readable labels")
expectEqual(parser.friendlyAction({ action = "spawn kitty" }), "Terminal", "Known applications get readable labels")
expectEqual(parser.categoryPriority("Applications") < parser.categoryPriority("Layouts"), true, "Common application categories sort before layouts")
expectEqual(parser.categoryPriority("Without Description") > parser.categoryPriority("Touchpad Gestures"), true, "Fallback categories sort after common controls")
expectEqual(parser.bindingAvailableInView(true, false, false, true), false, "Hidden bindings stay out of the main view")
expectEqual(parser.bindingAvailableInView(true, false, true, true), true, "Hidden bindings remain visible in edit mode")
expectEqual(parser.bindingAvailableInView(false, true, true, false), true, "Edit mode includes undescribed bindings")
expectEqual(parser.bindingContentOpacity(true), 0.45, "Hidden binding content is visibly muted")
expectEqual(parser.bindingContentOpacity(false), 1, "Visible binding content remains fully opaque")

local hypr = parser.walkConfig("/fixtures/hypr/main.conf", parser.parseHyprContent)
expectEqual(#hypr.bindings, 2, "Hyprland expands variables in recursive source paths")
expectEqual(table.concat(hypr.bindings[1].modifiers, "+"), "SUPER", "Hyprland resolves modifier variables")

local niri = parser.walkConfig("/fixtures/niri/config.kdl", parser.parseNiriContent)
expectEqual(#niri.bindings, 3, "Niri follows globbed includes")
expectEqual(niri.bindings[1].description, "Terminal app", "Niri reads quoted titles containing spaces")
expectEqual(niri.bindings[2].category, "Applications", "Niri preserves comment categories")

if failures > 0 then
  error(tostring(failures) .. " parser test(s) failed")
end

print("All parser tests passed")
