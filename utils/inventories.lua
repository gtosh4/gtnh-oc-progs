local component = require("component")
local json = require("json")
local item = require("item")

local i = component.transposer

for side = 0, 5 do
  local name = i.getInventoryName(side)
  if name then
    print(side, name)
    local slot = 0
    for stack in i.getAllStacks(side) do
      slot = slot + 1
      if stack.name then
        print(" ", slot, " ", json.encode(item.parseStack(stack)))
      end
    end
  end
end
