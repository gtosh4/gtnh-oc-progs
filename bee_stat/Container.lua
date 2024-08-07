---@class Container
---@field transposer table
---@field side number
local Container = {}


---@param sink number|table either a side (number) or an inventory object
---@param count? number
---@param sourceSlot? number
---@param sinkSlot? number
---@return number number of items actually transferred
function Container:transferItem(sink, ...)
  if sink and type(sink) == "table" then sink = sink.side end
  return self.transposer.transferItem(self.side, sink, ...)
end

function Container:name()
  return self.transposer.getInventoryName(self.side)
end

function Container:size()
  return self.transposer.getInventorySize(self.side)
end

---@param slot number
function Container:getStackInSlot(slot)
  return self.transposer.getStackInSlot(self.side, slot)
end

function Container:getAllStacks()
  local stacks = self.transposer.getAllStacks(self.side)
  local slot = 0
  return function()
    slot = slot + 1
    local stack = stacks()
    if stack then
      return slot, stack
    end
  end
end

---@param start_slot number
---@param stop_slot number
function Container:allStacksBetween(start_slot, stop_slot)
  local stacks = self:getAllStacks()
  return function()
    local slot, stack = stacks()

    while slot and slot < start_slot do
      slot, stack = stacks()
    end
    if slot and slot < stop_slot then
      return slot, stack
    end
  end
end

return Container
