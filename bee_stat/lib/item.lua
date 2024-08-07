local nbt = require("nbt")
local deflate = require("deflate")

local string_char = string.char

local item = {}

function item.parseTag(raw_tag)
  local out = {}
  local append = function(s)
    out[#out + 1] = string_char(s)
  end
  deflate.gunzip {
    input = raw_tag,
    output = append,
    disable_crc = true,
  }
  return nbt.readFromNBT(out)
end

function item.parseStack(stack)
  if stack.hasTag then
    stack.tag = item.parseTag(stack.tag)
  end
  return stack
end

return item
