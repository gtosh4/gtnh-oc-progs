local component = require("component")
local sides = require("sides")
local io = require("io")
local os = require("os")

local json = require("json")
local log = require("log")

local Container = require("Container")
local Bee = require("Bee")

local pairs = pairs

---@param start string
function string:starts_with(start)
  return self:sub(1, #start) == start
end

-- print_table(component.list(), "components")

local i = component.transposer



local apiary = setmetatable({
  transposer = i,
  side = sides.unknown,
  queen_slot = 1,
  drone_slot = 2,
  output_slots = { start = 3, stop = 10 },
  frame_slots = { start = 10, stop = 13 },
}, { __index = Container })

local chest = setmetatable({
  transposer = i,
  side = sides.unknown,
}, { __index = Container })

local trash = setmetatable({
  transposer = i,
  side = sides.unknown,
}, { __index = Container })

local function find_containers()
  for side = 0, 5 do
    local name = i.getInventoryName(side)
    local size = i.getInventorySize(side)
    if name == "tile.for.apiculture" then
      apiary.side = side
    elseif name == "tile.extrautils:trashcan" then
      trash.side = side
    elseif size and name:sub(1, -2) ~= "tile.oc.case" then
      chest.side = side
    end
  end

  log:info("apiary=%s, chest=%s, trash=%s", sides[apiary.side], sides[chest.side], sides[trash.side])

  if apiary.side == sides.unknown then
    error("No apiary found")
  end
  if chest.side == sides.unknown then
    error("No chest found")
  end
  if trash.side == sides.unknown then
    error("No trash can found")
  end
end


function apiary:frame_stacks()
  return self:allStacksBetween(self.frame_slots.start, self.frame_slots.stop)
end

function apiary:output_stacks()
  return self:allStacksBetween(self.output_slots.start, self.output_slots.stop)
end

function apiary:check_frames()
  for slot, frame in self:frame_stacks() do
    if frame and frame.name and frame.damage >= frame.maxDamage - 1 then
      log:info("frame[%d] almost broken", slot)
      return false
    end
  end
  return true
end

function apiary:trash_drones()
  for slot, stack in self:output_stacks() do
    if stack and stack.name == "Forestry:beeDroneGE" then
      self:transferItem(trash, stack.size, slot)
    end
  end
end

local stat_weights = {
  species = 100,  -- makes sure we don't accidentally breed out of the target species
  fertility = 10, -- higher fertility makes it easier to breed the other stats
}
setmetatable(stat_weights, { __index = function() return 1 end })

---@class DesiredStats
---@field species string
---@field speed string
---@field lifespan string
---@field fertility string
---@field temperature string
---@field humidity string
---@field tolerantFlyer string
---@field flowers string
---@field pollination string
---@field territory string
---@field effect string
local DesiredStats = {}

function DesiredStats:score(stats)
  local score, max = 0, 0
  for k, v in pairs(stats) do
    local desired = self[k]
    max = max + 2 * stat_weights[k]

    if desired == v.active then
      score = score + stat_weights[k]
    end
    if desired == v.inactive then
      score = score + stat_weights[k]
    end
  end
  return score, max
end

function DesiredStats:best_drone(drone_stacks_iter)
  local best
  for slot, stack in drone_stacks_iter do
    if stack and stack.name == "Forestry:beeDroneGE" then
      local bee = Bee.new(stack)
      local score, _ = self:score(bee.stats)
      log:debug("candidate[slot=%d]=%d %s", slot, score, json.encode(bee.stats))
      if not best or score > best.score then
        best = bee
        best.slot = slot
        best.score = score
      end
    end
  end
  return best
end

function DesiredStats.new(stack_iter)
  local desired_stats = {}

  local drone_species
  local princess_species
  local princess
  for s, stack in stack_iter do
    if stack.name == "Forestry:beeDroneGE" and not desired_stats.fertility then
      local bee = Bee.new(stack)
      drone_species = bee.stats.species.active
      for k, v in pairs(bee.stats) do
        if k ~= "species" then
          desired_stats[k] = v.active
        end
      end
      local apiary_drones = apiary:getStackInSlot(apiary.drone_slot)
      if apiary_drones then
        apiary:transferItem(chest, apiary_drones.size, apiary.drone_slot)
      end
    elseif stack.name == "Forestry:beePrincessGE" and not desired_stats.species then
      local bee = Bee.new(stack)
      princess_species = bee.stats.species
      desired_stats.species = bee.stats.species.active
      local apiary_queen = apiary:getStackInSlot(apiary.queen_slot)
      if apiary_queen then
        apiary:transferItem(chest, apiary_queen.size, apiary.queen_slot)
      end
      princess = bee
      princess.slot = s
    end

    if desired_stats.fertility and desired_stats.species then
      log:debug("checking species desired=%s: {drone=%s, princess=%s/%s}", desired_stats.species, drone_species,
        princess_species.active, princess_species.inactive)
      if desired_stats.species == drone_species then
        desired_stats.species = princess_species.inactive
      end

      break
    end
  end

  return setmetatable(desired_stats, { __index = DesiredStats }), princess
end

---@param desired_stats DesiredStats
function chest:add_stat_drone(desired_stats)
  local best = desired_stats:best_drone(chest:getAllStacks())
  if not best then
    error("No drones found")
  end
  self:transferItem(apiary, 1, best.slot, apiary.drone_slot)
end

---@param desired_stats DesiredStats
function apiary:get_output(desired_stats)
  local princess
  local stacks = self:output_stacks()
  local iter = function()
    local slot, stack = stacks()
    if stack then
      if stack.name and stack.name == "Forestry:beePrincessGE" then
        princess = Bee.new(stack)
        princess.slot = slot
      end
      return slot, stack
    end
  end

  local best = desired_stats:best_drone(iter)
  return princess, best
end

local generation = 0

---@param desired_stats DesiredStats
---@return boolean true if the breeding is complete
function apiary:handle_output(desired_stats)
  local princess, best = self:get_output(desired_stats)

  if not princess then
    local queen = self:getStackInSlot(self.queen_slot)
    if queen then
      if queen.name == "Forestry:beeQueenGE" then
        -- Still waiting for output
        return false
      end
      -- queen slot has a princess, check if there's a drone
      if self:getStackInSlot(self.drone_slot) then
        -- Drone present, waiting to combine to queen
        return false
      end
    else
      log:warn("No princess found")
      return true
    end
  end

  if best then
    log:debug("best=%s (%d)", json.encode(best.stats), best.score)
  else
    log:debug("No best drone in output")
  end

  local princess_score, max_score = desired_stats:score(princess.stats)
  log:debug("princess=%s (%d)", json.encode(princess.stats), princess_score)

  if princess_score == max_score and best and best.score == max_score then
    self:transferItem(chest, princess.stack.size, princess.slot)
    self:transferItem(chest, best.stack.size, best.slot)
    self:trash_drones()
    return true
  else
    local princess_species_not_ok = (
      princess.stats.species.active ~= desired_stats.species and
      princess.stats.species.inactive ~= desired_stats.species
    )
    local best_species_not_ok = (not best or (
      best.stats.species.active ~= desired_stats.species and
      best.stats.species.inactive ~= desired_stats.species
    ))

    if princess_species_not_ok and best_species_not_ok then
      log:warn("Princess and best drone is not the target species")
      return true
    end

    if best then
      -- Only swap in a stat drone if the princess is fully the target species or the best drone has none of the species.
      -- This is to avoid a situation where swapping in the stat drone would result in only 1/4 of the target species.
      local species_satisfied = (princess.stats.species.active == desired_stats.species and princess.stats.species.inactive == desired_stats.species) or
          (best.stats.species.active ~= desired_stats.species and best.stats.species.inactive ~= desired_stats.species)
      if species_satisfied and best.score <= princess_score then
        -- If the best done is worse than the princess, then might as well continue with the stat drones
        log:info("Swapping in stat drone {best=%d, princess=%d, max=%d}", best.score, princess_score, max_score)
        chest:add_stat_drone(desired_stats)
      else
        log:info("Continuing with best drone {best=%d, princess=%d, max=%d}", best.score, princess_score, max_score)
        self:transferItem(self, 1, best.slot, self.drone_slot)
      end
    else
      chest:add_stat_drone(desired_stats)
    end
    apiary:trash_drones()

    if not self:check_frames() then
      -- If the frame is almost broken, return the princess to the chest (for resuming)
      self:transferItem(chest, princess.stack.size, princess.slot)
      return true
    end

    self:transferItem(self, princess.stack.size, princess.slot, self.queen_slot)
    generation = generation + 1

    return false
  end
end

local function run()
  log.level = log.levels.INFO
  log.file = io.open("/home/logs/breed_stats.log", "w")

  find_containers()

  local desired_stats, princess = DesiredStats.new(chest:getAllStacks())

  local princess_score, max_score = desired_stats:score(princess.stats)
  if princess_score == max_score then
    log:info("Princess already has all desired stats")
    return
  else
    chest:transferItem(apiary, 1, princess.slot, apiary.queen_slot)
  end

  local r = component.isAvailable("redstone") and component.redstone

  local redstone_state = setmetatable({
    on = false,
  }, {
    __index = function(self, k)
      if sides[k] then
        return self.on and 15 or 0
      end
    end,
  })

  local function toggle_redstone(on)
    if r then
      redstone_state.on = on
      r.setOutput(redstone_state)
    end
  end

  if not apiary:check_frames() then return end

  chest:add_stat_drone(desired_stats)
  toggle_redstone(true)
  log:info("desired_stats=%s", json.encode(desired_stats))

  while true do
    local complete = apiary:handle_output(desired_stats)
    if complete then
      log:info("Breeding complete after %d generations", generation)
      break
    end
    os.sleep(1)
  end

  toggle_redstone(false)

  if log.file then io.close(log.file) end
end

xpcall(run, function(err)
  log:error(debug.traceback(err))
end)
