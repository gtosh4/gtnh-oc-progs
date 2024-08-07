local component = require("component")
local io = require("io")

for addr, t in pairs(component.list()) do
  local c = component.proxy(addr)
  local f = io.open(c.type .. ".txt", "w")
  for k, v in pairs(c) do
    if type(v) == "table" and v.address then
      local str = tostring(v)
      f:write(k..str:sub(9).."\n")
    end
  end
end
