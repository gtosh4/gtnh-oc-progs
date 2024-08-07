local itemlib = require("item")

---@class Bee
---@field stats table
---@field stack table
local Bee = {}

Bee.stat_slots = {
  species = 0,
  speed = 1,
  lifespan = 2,
  fertility = 3,
  temperature = 4,
  ["?1"] = 5, -- bool
  ["?2"] = 6, -- missing info
  humidity = 7,
  tolerantFlyer = 8,
  ["?4"] = 9, -- bool
  flowers = 10,
  pollination = 11,
  territory = 12,
  effect = 13,
}
Bee.slot_to_stat = {}
for k, v in pairs(Bee.stat_slots) do
  Bee.slot_to_stat[v] = k
end

function Bee.get_bee_stats(raw_tag)
  local tag = itemlib.parseTag(raw_tag)
  local chromos = tag["Genome"]["Chromosomes"]
  local stats = {}
  for _, chromo in ipairs(chromos) do
    stats[Bee.slot_to_stat[chromo["Slot"]]] = {
      active = chromo["UID0"],
      inactive = chromo["UID1"],
    }
  end
  return stats
end

function Bee.new(stack)
  local stats = Bee.get_bee_stats(stack.tag)
  return setmetatable({
    stats = stats,
    stack = stack,
  }, { __index = Bee })
end

return Bee
