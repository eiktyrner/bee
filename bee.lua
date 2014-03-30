-- BeeAnalyzer 4.4.1
-- Original code by Direwolf20
-- Hotfix 1 by Mandydax
-- Hotfix 2 by Mikeyhun/MaaadMike
-- 4.0 Major overhaul by MacLeopold
--     Breeds bees with best attributes in this order:
--     fertility, speed, nocturnal, flyer, cave, temperature tolerance, humidity tolerance
--     other attributes are ignored (lifespawn, flowers, effect and territory)
--     Can specify multiple target species to help with keeping to the correct line
-- 4.1 Minor fix for FTB Unleashed, no more inventory module or suckSneaky needed
-- 4.2 Major overhaul 2
--     Added magic bees, removed old bees
--     Added species graph
--     Changed targeting to target parent species
--     Changed breeding to keep stock of good bees to prevent losing attributes
--     Added logging
--     Changed scoring to look for best combination of princess and drone
-- 4.3 Updated targeting
-- 4.4 Switched to OpenPeripherals by Eiktyrner
-- 4.4.1  Modified to work with:
--			OpenPeripheral Core 0.3.0-s39
--			OpenPeripheral Addons 0.1.0-s41

-- attribute scoring for same species tie-breaking -----------------------------

scoresFertility = {
  [1] = 0.1,
  [2] = 0.2,
  [3] = 0.3,
  [4] = 0.4
}
scoresSpeed = {
  ["0.3"] = 0.01, -- Slowest
  ["0.6"] = 0.02, -- Slower
  ["0.8"] = 0.03, -- Slow
  ["1"]   = 0.04, -- Normal
  ["1.2"] = 0.05, -- Fast
  ["1.4"] = 0.06, -- Faster
  ["1.7"] = 0.07  -- Fastest
}
scoresAttrib = {
  diurnal       = 0.004,
  nocturnal     = 0.003,
  tolerantFlyer = 0.002,
  caveDwelling  = 0.0001
}
scoresTolerance = {
  ["NONE"]   = 0.00000,
  ["UP 1"]   = 0.00001,
  ["UP 2"]   = 0.00002,
  ["UP 3"]   = 0.00003,
  ["UP 4"]   = 0.00004,
  ["UP 5"]   = 0.00005,
  ["DOWN 1"] = 0.00001,
  ["DOWN 2"] = 0.00002,
  ["DOWN 3"] = 0.00003,
  ["DOWN 4"] = 0.00004,
  ["DOWN 5"] = 0.00005,
  ["BOTH 1"] = 0.00002,
  ["BOTH 2"] = 0.00004,
  ["BOTH 3"] = 0.00006,
  ["BOTH 4"] = 0.00008,
  ["BOTH 5"] = 0.00010
}

-- the bee graph ---------------------------------------------------------------

bees = {}

function addParent(parent, offspring)
  if bees[parent] then
    bees[parent].mutateTo[offspring] = true
  else
    bees[parent] = {
      --name = parent,
      score = nil,
      mutateTo = {[offspring]=true},
      mutateFrom = {}
    }
  end
end

function addOffspring(offspring, parentss)
  if bees[offspring] then
    for i, parents in ipairs(parentss) do
      table.insert(bees[offspring].mutateFrom, parents)
    end
  else
    bees[offspring] = {
      score = nil,
      mutateTo = {},
      mutateFrom = parentss
    }
  end
  for i, parents in ipairs(parentss) do
    for i, parent in ipairs(parents) do
      addParent(parent, offspring)
    end
  end
end

-- score bees that have no parent combinations as 1
-- iteratively find the next bee up the line and increase the score
function scoreBees()
  -- find all bees with no mutateFrom data
  local beeCount = 0
  local beeScore = 1
  for name, beeData in pairs(bees) do
    if #beeData.mutateFrom == 0 then
      beeData.score = beeScore
    else
      beeCount = beeCount + 1
    end
  end
  while beeCount > 0 do
    beeScore = beeScore * 2
    -- find all bees where all parent combos are scored
    for name, beeData in pairs(bees) do
      if not beeData.score then
        local scoreBee = true
        for i, beeParents in ipairs(beeData.mutateFrom) do
          local parent1 = bees[beeParents[1]]
          local parent2 = bees[beeParents[2]]

          if not parent1.score
              or parent1.score == beeScore
              or not parent2.score
              or parent2.score == beeScore then
            scoreBee = false
            break
          end
        end
        if scoreBee then
          beeData.score = beeScore
          beeCount = beeCount - 1
        end
      end
    end
  end
end

-- produce combinations from 1 or 2 lists
function choose(list, list2)
  local newList = {}
  if list2 then
    for i = 1, #list2 do
      for j = 1, #list do
        if list[j] ~= list[i] then
          table.insert(newList, {list[j], list2[i]})
        end
      end
    end
  else
    for i = 1, #list do
      for j = i, #list do
        if list[i] ~= list[j] then
          table.insert(newList, {list[i], list[j]})
        end
      end
    end
  end
  return newList
end

-- Experimental feature that works to build the table of bee parents/children instead of hard-coding

m = peripheral.wrap("front")
for key, value in pairs(m.getBeeBreedingData()) do
  addOffspring( fixName(value.result),  {{ fixName(value.allele1), fixName(value.allele2) }} )
end


scoreBees()

-- logging ---------------------------------------------------------------------

local logFile = fs.open("bee.log", "w")
function log(msg)
  msg = msg or ""
  logFile.write(tostring(msg))
  logFile.flush()
  io.write(msg)
end
function logLine(msg)
  msg = msg or ""
  logFile.write(msg.."\n")
  logFile.flush()
  io.write(msg.."\n")
end

function logTable(table)
  for key, value in pairs (table) do
    logLine(key .. " = " .. tostring(value))
  end
end

-- analyzing functions ---------------------------------------------------------

-- Fix for some versions returning bees.species.*
function fixName(name)
  return name:gsub("bees%.species%.",""):gsub("^.", string.upper)
end

-- Expects the turtle facing apiary
function clearSystem()
  -- clear out apiary
  while turtle.suck() do end

  -- clear out analyzer
  turtle.turnLeft()
  while turtle.suck() do end
  turtle.turnRight()
end
 
function getBees()
  -- get bees from apiary
  log("waiting for bees.")
  turtle.select(1)
  while not turtle.suck() do
    sleep(10)
    log(".")
  end
  log("*")
  while turtle.suck() do
    log("*")
  end
  logLine()
end

function countBees()
  -- spread dups and fill gaps
  local count = 0
  for i = 1, 16 do
    local slotCount = turtle.getItemCount(i)
    if slotCount == 1 then
      for j = 1, i-1 do
        if turtle.getItemCount(j) == 0 then
          turtle.select(i)
          turtle.transferTo(j)
          break
        end
      end
      count = count + 1
    elseif slotCount > 1 then
      for j = 2, slotCount do
        turtle.select(i)
        for k = 1, 16 do
          if turtle.getItemCount(k) == 0 then
            turtle.transferTo(k, 1)
          end
        end
      end
      if turtle.getItemCount(i) > 1 then
        turtle.dropDown(turtle.getItemCount(i)-1)
      end
    end
  end
  return count
end
 
function breedBees(princessSlot, droneSlot)
   turtle.select(princessSlot)
   turtle.drop()
   turtle.select(droneSlot)
   turtle.drop()
end
 
-- Turns to Analyzer and tries to drop item. 
-- If it's not accepted (not a bee)
-- drop to chest.
function ditchProduct()  
  logLine("ditching product...")
  turtle.turnLeft()
  m = peripheral.wrap("front")
  for i = 1, 16 do
    if turtle.getItemCount(i) > 0 then
      turtle.select(i)
      if not turtle.drop() then
        turtle.dropDown()
      else
        while not turtle.suck() do
          sleep(1)
        end
      end
    end
  end
  logLine()
  turtle.turnRight()
end

function swapBee(slot1, slot2, freeSlot)
  turtle.select(slot1)
  turtle.transferTo(freeSlot)
  turtle.select(slot2)
  turtle.transferTo(slot1)
  turtle.select(freeSlot)
  turtle.transferTo(slot2)
end  

-- Turn left to Analyzer
function analyzeBees()
  logLine("analyzing bees...")
  turtle.turnLeft()

  local freeSlot
  local princessSlot
  local highestScore
  local princessData
  local droneData = {}
  local beealyzer = peripheral.wrap("front")

  for i = 1, 16 do
    if turtle.getItemCount(i) > 0 then
      turtle.select(i)
      turtle.drop()

      sleep(1) -- To make sure the drone goes through the analyzer

      local tableData = beealyzer.getStackInSlot(9)
      local beeData = {}

      -- Get bees back into turtle after grabbing values
      while not turtle.suck() do
        sleep(1)
      end

      -- Check if it's a drone or princess
      for key, value in pairs (tableData) do
        if key == "rawName" then
          if string.find(value, "princess") then
            beeData["type"] = "princess"
          else
            beeData["type"] = "drone"
          end
        end
      end

      -- Active values
      for key, value in pairs (tableData.beeInfo.active) do
        if key == "species" then
          beeData["speciesPrimary"] = value
        else
          beeData[key] = value
        end
      end
      
      -- Inactive values
      for key, value in pairs (tableData.beeInfo.inactive) do
        if key == "species" then
          beeData["speciesSecondary"] = value
        end
      end

      if not beeData["speciesPrimary"] then
        logLine("Bee "..i.." not correctly analyzed")
      else
        beeData["speciesPrimary"] = fixName(beeData["speciesPrimary"])
        beeData["speciesSecondary"] = fixName(beeData["speciesSecondary"])
        if beeData["type"] == "princess" then
          princessData = beeData
          princessSlot = i
        else
          droneData[i] = beeData
        end
      end
    else
      freeSlot = i
    end
  end

  if princessData then
    if princessSlot ~= 1 then
      swapBee(1, princessSlot, freeSlot)
      droneData[princessSlot] = droneData[1]
      droneData[1] = nil
      princessSlot = 1
    end
    -- selection sort drones
    logLine("sorting drones...")
    for i = 2, 16 do
      highestScore = i
      if turtle.getItemCount(i) > 0 and droneData[i] then
        droneData[i].score = scoreBee(princessData, droneData[i])
        for j = i + 1, 16 do
          if turtle.getItemCount(j) > 0 and droneData[j] then
            if not droneData[j].score then
              droneData[j].score = scoreBee(princessData, droneData[j])
            end
            if droneData[j].score > droneData[highestScore].score then
              highestScore = j
            end
          end
        end
        -- swap bees
        if highestScore ~= i then
          swapBee(i, highestScore, freeSlot)
          droneData[i], droneData[highestScore] = droneData[highestScore], droneData[i]
        end
      end
    end
    printHeader()
    princessData.slot = 1
    printBee(princessData)
    for i = 2, 16 do
      if droneData[i] then
        droneData[i].slot = i
        printBee(droneData[i])
      end
    end
  end
  logLine()
  turtle.turnRight()
  return princessData, droneData
end

function scoreBee(princessData, droneData)
  local droneSpecies = {droneData["speciesPrimary"], droneData["speciesSecondary"]}
  -- check for untargeted species
  if not bees[droneSpecies[1]].targeted or not bees[droneSpecies[2]].targeted then
    return 0
  end
  local princessSpecies = {princessData["speciesPrimary"], princessData["speciesSecondary"]}
  local score
  local maxScore = 0
  for _, combo in ipairs({{princessSpecies[1], droneSpecies[1]}
                         ,{princessSpecies[1], droneSpecies[2]}
                         ,{princessSpecies[2], droneSpecies[1]}
                         ,{princessSpecies[2], droneSpecies[2]}}) do
    -- find maximum score for each combo
    score = (bees[combo[1]].score + bees[combo[2]].score) / 2
    for name, beeData in pairs(bees) do
      if beeData.targeted then
        for i, parents in ipairs(beeData.mutateFrom) do
          if combo[1] == parents[1] and combo[2] == parents[2]
              or combo[2] == parents[1] and combo[1] == parents[2] then
            score = (score + beeData.score) / 2
          end
        end
      end
    end
    maxScore = maxScore + score
  end
  -- add one for each combination that results in the maximum score
  score = maxScore
  -- score attributes
  score = score + math.max(scoresFertility[droneData["fertility"]], scoresFertility[princessData["fertility"]])
  score = score + math.min(scoresSpeed[tostring(droneData["speed"])], scoresSpeed[tostring(princessData["speed"])])
  if droneData["nocturnal"] or princessData["nocturnal"] then score = score + scoresAttrib["nocturnal"] end
  if droneData["tolerantFlyer"] or princessData["tolerantFlyer"] then score = score + scoresAttrib["tolerantFlyer"] end
  if droneData["caveDwelling"] or princessData["caveDwelling"] then score = score + scoresAttrib["caveDwelling"] end
  score = score + math.max(scoresTolerance[string.upper(droneData["temperatureTolerance"])], scoresTolerance[string.upper(princessData["temperatureTolerance"])])
  score = score + math.max(scoresTolerance[string.upper(droneData["humidityTolerance"])], scoresTolerance[string.upper(princessData["humidityTolerance"])])
  return score
end

function printHeader()
  logLine()
  logLine("sl t species f spd n f c tmp hmd score ")
  logLine("--|-|-------|-|---|-|-|-|---|---|------")
end

-- string constants for console output
toleranceString = {
  ["NONE"] = "  - ",
  ["UP 1"] = " +1 ",
  ["UP 2"] = " +2 ",
  ["UP 3"] = " +3 ",
  ["UP 4"] = " +4 ",
  ["UP 5"] = " +5 ",
  ["DOWN 1"] = " -1 ",
  ["DOWN 2"] = " -2 ",
  ["DOWN 3"] = " -3 ",
  ["DOWN 4"] = " -4 ",
  ["DOWN 5"] = " -5 ",
  ["BOTH 1"] = "+-1 ",
  ["BOTH 2"] = "+-2 ",
  ["BOTH 3"] = "+-3 ",
  ["BOTH 4"] = "+-4 ",
  ["BOTH 5"] = "+-5 "
}

speedString = {
  ["0.3"] = "0.3", -- Slowest
  ["0.6"] = "0.6", -- Slower
  ["0.8"] = "0.8", -- Slow
  ["1"]   = "1.0", -- Normal
  ["1.2"] = "1.2", -- Fast
  ["1.4"] = "1.4", -- Faster
  ["1.7"] = "1.7"  -- Fastest
}

function printBee(beeData)
  log(beeData["slot"] < 10 and " "..beeData["slot"].." " or beeData["slot"].." ")
  -- type
  log(beeData["type"] == "princess" and "P " or "D ")
  -- species
  log(beeData["speciesPrimary"]:gsub("bees%.species%.",""):sub(1,3)..":"..beeData["speciesSecondary"]:gsub("bees%.species%.",""):sub(1,3).." ")
  -- fertility
  log(tostring(beeData["fertility"]).." ")
  -- speed
  log(speedString[tostring(beeData["speed"])].." ")
  -- nocturnal
  log(beeData["nocturnal"] and "X " or "- ")
  -- flyer
  log(beeData["tolerantFlyer"] and "X " or "- ")
  -- cave dwelling
  log(beeData["caveDwelling"] and "X " or "- ")
  -- temperature tolerance
  log(toleranceString[string.upper(beeData["temperatureTolerance"])])
  -- humidity tolerance
  log(toleranceString[string.upper(beeData["humidityTolerance"])])
  -- score
  log(beeData.score and string.format("%5.1d", beeData.score).." " or "      ")
  logLine()
end

function dropExcess(droneData)
  logLine("dropping excess...")
  local count = 0
  for i = 1, 16 do
    if turtle.getItemCount(i) > 0 then
      -- check for untargeted species
      if droneData[i] and (not bees[droneData[i]["speciesPrimary"]].targeted
          or not bees[droneData[i]["speciesSecondary"]].targeted) then
        turtle.select(i)
        turtle.dropDown()
      else
        count = count + 1
      end
      -- drop drones over 9 to clear space for newly bred bees and product
      if count > 9 then
        turtle.select(i)
        turtle.dropDown()
        count = count - 1
      end
    end
  end  
end

function isPurebred(princessData, droneData)
  -- check if princess and drone are exactly the same and no chance for mutation
  if princessData["speciesPrimary"] ~= princessData["speciesSecondary"] then
    return false
  end
  for key, value in pairs(princessData) do
    if value ~= droneData[key] and key ~= "territory" and key ~= "type" and key ~= "slot" then
      return false
    end
  end
  return true
end

function getUnknown(princessData, droneData)
  -- lists species that are not in the bee graph
  local unknownSpecies = {}
  if not bees[princessData["speciesPrimary"]] then
    table.insert(unknownSpecies, princessData["speciesPrimary"])
  end
  if not bees[princessData["speciesSecondary"]] then
    table.insert(unknownSpecies, princessData["speciesSecondary"])
  end
  for _, beeData in pairs(droneData) do
    if not bees[beeData["speciesPrimary"]] then
      table.insert(unknownSpecies, beeData["speciesPrimary"])
    end
    if not bees[beeData["speciesSecondary"]] then
      table.insert(unknownSpecies, beeData["speciesSecondary"])
    end
  end
  return unknownSpecies
end

-- targeting -------------------------------------------------------------------

-- set species and all parents to targeted
function targetBee(name)
  local bee = bees[name]
  if bee and not bee.targeted then
    bee.targeted = true
    for i, parents in ipairs(bee.mutateFrom) do
      for j, parent in ipairs(parents) do
        targetBee(parent)
      end
    end
  end
end

-- set bee graph entry to targeted if species was specified on the command line
-- otherwise set all entries to targeted
tArgs = { ... }
if #tArgs > 0 then
  logLine("targeting bee species:")
  for i, target in ipairs(tArgs) do
    targetBee(target)
    for name, data in pairs(bees) do
      if data.targeted and data.score > 1 then
        logLine(name .. string.rep(" ", 20-#name), data.score)
      end
    end
  end
else
  for _, beeData in pairs(bees) do
    beeData.targeted = true
  end
end

-- breeding loop ---------------------------------------------------------------

logLine("Clearing system...")
clearSystem()
while true do
  ditchProduct()
  countBees()
  princessData, droneData = analyzeBees()
  if princessData then
    if isPurebred(princessData, droneData[2]) then
      logLine("Bees are purebred")
      turtle.turnRight()
      break
    end
    local unknownSpecies = getUnknown(princessData, droneData)
    if #unknownSpecies > 0 then
      logLine("Please add new species to bee graph:")
      for _, species in ipairs(unknownSpecies) do
        logLine("  "..species)
      end
      turtle.turnRight()
      break
    end
    breedBees(1, 2)
    dropExcess(droneData)
  end
  getBees()
end
logFile.close()
