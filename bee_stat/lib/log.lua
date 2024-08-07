local io = require("io")
local gpu = require("component").gpu

local Log = {
  level = 0,
  file = nil,
  levels = {
    DEBUG = 0,
    INFO = 1,
    WARN = 2,
    ERROR = 3,
  }
}

local function coloredPrint(color, prefix, msg, ...)
  local old_color = gpu.setForeground(color)
  io.write(prefix)
  gpu.setForeground(old_color)

  local full = string.format(msg, ...) .. "\n"

  io.write(full)

  if Log.file then
    Log.file:write(prefix .. full)
  end
end

function Log:debug(msg, ...)
  if self.level > Log.levels.DEBUG then
    return
  end

  -- blue
  coloredPrint(3300000, "[DEBUG] ", msg, ...)
end

function Log:info(msg, ...)
  if self.level > Log.levels.INFO then
    return
  end

  -- green
  coloredPrint(39219, "[INFO] ", msg, ...)
end

function Log:warn(msg, ...)
  if self.level > Log.levels.WARN then
    return
  end

  -- yellow
  coloredPrint(15258675, "[WARN] ", msg, ...)
end

function Log:error(msg, ...)
  -- red
  coloredPrint(12058624, "[ERROR] ", msg, ...)
end

return Log
