--!nonstrict
-- Minimal Noctalia host used by the standalone Luau parser tests.

local files = {}
local stateValues = {}
local fileExistsOverrides = {}

local function normalize(path)
  local absolute = path:sub(1, 1) == "/"
  local parts = {}
  for part in path:gmatch("[^/]+") do
    if part == ".." then
      if #parts > 0 then table.remove(parts) end
    elseif part ~= "." and part ~= "" then
      table.insert(parts, part)
    end
  end
  return (absolute and "/" or "") .. table.concat(parts, "/")
end

local function directory(path)
  local prefix = path:gsub("/+$", "") .. "/"
  local names = {}
  for file in pairs(files) do
    if file:sub(1, #prefix) == prefix then
      local rest = file:sub(#prefix + 1)
      local name = rest:match("^([^/]+)")
      if name ~= nil then names[name] = true end
    end
  end
  local result = {}
  for name in pairs(names) do table.insert(result, name) end
  table.sort(result)
  return result
end

local function translation(key, substitutions)
  local value = key
  for name, replacement in pairs(substitutions or {}) do
    value = value:gsub("{" .. name .. "}", tostring(replacement))
  end
  return value
end

local noctalia = {
  tr = translation,
  getenv = function(name) return name == "HOME" and "/home/test" or nil end,
  expandPath = function(path) return normalize(path:gsub("^~", "/home/test")) end,
  fileExists = function(path)
    path = normalize(path)
    if fileExistsOverrides[path] ~= nil then return fileExistsOverrides[path] end
    if files[path] ~= nil then return true end
    return #directory(path) > 0
  end,
  fileInfo = function(path)
    path = normalize(path)
    if files[path] ~= nil then return { size = #files[path], mtime = 0, isDir = false } end
    if #directory(path) > 0 then return { size = 0, mtime = 0, isDir = true } end
    return nil, "missing"
  end,
  listDir = function(path)
    local values = directory(normalize(path))
    if #values > 0 then return values, nil end
    return nil, "missing"
  end,
  readFile = function(path)
    local content = files[normalize(path)]
    if content ~= nil then return content, nil end
    return nil, "missing"
  end,
  writeFile = function(path, content) files[normalize(path)] = content return true end,
  pluginDir = function() return "/plugin" end,
  pluginDataDir = function() return "/data" end,
  commandExists = function() return false end,
  getConfig = function() return nil end,
  outputs = function() return {} end,
  focusedOutputName = function() return nil end,
  clipboardText = function() return nil end,
  openColorPicker = function() return false end,
  notify = function() end,
  notifyError = function() end,
  log = function() end,
  togglePanel = function() end,
  runAsync = function() return false end,
  string = { trim = function(value) return (value:gsub("^%s+", ""):gsub("%s+$", "")) end },
  json = { decode = function() return nil, "not implemented in host mock" end, encode = function() return "{}" end },
  state = {
    get = function(key) return stateValues[key] end,
    set = function(key, value) stateValues[key] = value end,
    watch = function() end,
  },
}

local function node(kind)
  return function(props, children) return { type = kind, props = props or {}, children = children or {} } end
end

local ui = {}
for _, kind in ipairs({ "column", "row", "box", "label", "glyph", "image", "separator", "spacer", "progress", "button", "graph", "input", "select", "slider", "toggle", "scroll" }) do
  ui[kind] = node(kind)
end

return {
  noctalia = noctalia,
  ui = ui,
  panel = { render = function() end, close = function() end, setWantsSecondTicks = function() end },
  setFiles = function(value)
    files = {}
    fileExistsOverrides = {}
    for path, content in pairs(value) do files[normalize(path)] = content end
  end,
  setFileExists = function(path, value)
    fileExistsOverrides[normalize(path)] = value
  end,
}
