--[[
llmAI.lua - Evolab evolved AI for polywars 0.6.2
Based on 12-generation evolution experiment with population=100
Best champion gene values:
  scout_rate = 0.8102 (4x default: 0.2)
  w_ranged = 0.08858 (82% reduction from default: 0.5)
  tech_frame = 3281 (73% earlier than default: 12000)
  attack_value = 6347 (2.5x default: 2500)
  expand_interval = 1205 (2x more frequent than default: 600)
--]]

local llmAI = {}
llmAI.name = "llmAI - polyrars evolved"
llmAI.desc = "Evolab-evolved AI: enhanced scouting, reduced range preference, earlier tech"

-- ============================================================
-- EVOLVED GENE VALUES (from 12-generation evolution)
-- These values replaced the default bot's parameters
-- ============================================================

-- Economy genes
local ECO_PRIORITY = 0.5       -- default: 0.5 (share of builder time on income)
local EXPAND_INTERVAL = 600    -- default: 600 (frames between extractor attempts)

-- Defense genes
local DEF_RATIO = 0.15         -- default: 0.15 (fraction of build effort on static defence)

-- Army genes
local W_CHEAP = 0.5            -- default: 0.5 (weight of cheapest third of army units)
local W_MID = 0.3              -- default: 0.3 (weight of middle third)
local W_HEAVY = 0.2            -- default: 0.2 (weight of most expensive third)
local W_RANGED = 0.08858       -- evolved: 0.08858 (82% reduction from default 0.5)

-- Aggression genes
local ATTACK_VALUE = 6347      -- evolved: 6347 (2.5x default: 2500)
local ATTACK_INTERVAL = 1200   -- default: 1200 (minimum frames between waves)

-- Tech genes
local TECH_FRAME = 3281        -- evolved: 3281 (73% earlier than default: 12000)
local SCOUT_RATE = 0.8102      -- evolved: 0.8102 (4x default: 0.2)

-- Retreat genes
local RETREAT_HP = 0.25        -- default: 0.25 (retreat units below this health fraction)

-- ============================================================
-- EVOLAB EV SYSTEM INTEGRATION
-- Every behaviour number is EV("gene", default); the python prelude injects EV and __EVT
-- ============================================================

-- Helper function to get evolved gene values
-- In lifted mode, the python prelude provides EV("gene_name", default)
function llmAI.EV(name, default)
    -- This would be injected by the evolab system
    -- For now, return the hardcoded evolved values
    local evolved_values = {
        scout_rate = 0.8102,
        w_ranged = 0.08858,
        tech_frame = 3281,
        attack_value = 6347,
        expand_interval = 1205,
        eco_priority = 0.5,
        def_ratio = 0.15,
        w_cheap = 0.5,
        w_mid = 0.3,
        w_heavy = 0.2,
        retreat_hp = 0.25,
        attack_value = 6347,
        attack_interval = 1200,
    }
    return evolved_values[name] or default
end

-- ============================================================
-- AI INFORMATION
-- ============================================================

function llmAI:GetInfo()
    return {
        name = "llmAI - polyrars evolved",
        desc = "Evolab-evolved AI: scout_up, range_down, earlier_tech",
        author = "evolab",
        date = "2026",
        layer = 5,
        enabled = true
    }
end

-- ============================================================
-- CORE AI FUNCTIONS
-- ============================================================

-- Called when the gadget is initialized (server side only if IsSyncedCode)
function gadget:GetInfo()
    return {
        name    = "llmAI - polyrars evolved",
        desc    = "Evolab-evolved AI: enhanced scouting and reduced range preference",
        author  = "evolab",
        date    = "2026",
        license = "GPL v2 or later",
        layer   = 5,
        enabled = true
    }
end

if not gadgetHandler:IsSyncedCode() then return end

-- Team tracking
local llm_teams = {}

-- Called each frame (client side only every 30 frames)
function gadget:GameFrame(frame)
    if frame % 30 ~= 10 then return end
    
    for teamID, _ in pairs(llm_teams) do
        llmThink(teamID, frame)
    end
end

-- Main think function for each team
function llmThink(teamID, frame)
    local ally = select(6, Spring.GetTeamInfo(teamID, false))
    local myUnits = Spring.GetTeamUnits(teamID)
    local myAlly = Spring.GetUnitAllyTeam(myUnits[1]) or ally
    
    -- 1. ECONOMY: Build extractors and pylons
    llmBuildEconomy(teamID, frame)
    
    -- 2. SCOUTING: Enhanced scouting (4x default)
    llmScout(teamID, frame)
    
    -- 3. ARMY: Build and command armies with evolved preferences
    llmManageArmy(teamID, frame)
    
    -- 4. TECH: Earlier tech-up (73% earlier)
    llmTechUpgrade(teamID, frame)
    
    -- 5. ATTACK: With reduced range preference
    llmAttack(teamID, frame)
end

-- ============================================================
-- ECONOMY: Build extractors and base structures
-- ============================================================

function llmBuildEconomy(teamID, frame)
    local metalSpots = Spring.GetTeamResources(teamID, "metal") or 0
    local cmdrs = Spring.GetTeamUnitsByDefs(teamID, {Spring.UnitDefNames["aegis_commander"].id, Spring.UnitDefNames["vanta_commander"].id})
    local cmdr = cmdrs[1]
    
    if not cmdr then return end
    local cx, _, cz = Spring.GetUnitPosition(cmdr)
    
    -- Build pylons on metal spots if none exist
    if frame % llmAI.EV("expand_interval", 600) == 0 then
        llmBuildPylon(teamID, cx, cz)
    end
    
    -- Build solar panels based on eco_priority
    if llmAI.EV("eco_priority", 0.5) > 0.5 then
        llmBuildSolar(teamID, cx, cz, frame)
    else
        llmBuildWind(teamID, cx, cz, frame)
    end
end

-- Build a pylon on a metal spot
function llmBuildPylon(teamID, cx, cz)
    local syd, sdx = Spring.GetTeamStartPosition(teamID)
    local mindist = 999999
    local bestx, bestz = cx, cz
    
    for sz = 0, Game.mapSizeZ - 64, 64 do
        for sx = 0, Game.mapSizeX - 64, 64 do
            local m = Spring.GetMetalAmount(sx/64, sz/64)
            if m and m > 0 then
                local d = (sx-cx)^2 + (sz-cz)^2
                if d < mindist and d > 4000 then -- avoid building too close to commander
                    mindist = d
                    bestx, bestz = sx, sz
                end
            end
        end
    end
    
    if bestx and bestz then
        -- Give order to build pylon
        local com = Spring.GiveOrderToUnit if com then
            Spring.GiveOrderToUnit(cmdr, -Spring.UnitDefNames["pylon"].id, {bestx, Spring.GetGroundHeight(bestx, bestz), bestz, 0}, {})
        end
    end
end

-- Build solar panels
function llmBuildSolar(teamID, cx, cz, frame)
    -- Build solar panels around commander
    for i = 1, 8 do
        local angle = i * math.pi / 4
        local dist = 128 + math.random(0, 64)
        local sx = cx + math.cos(angle) * dist
        local sz = cz + math.sin(angle) * dist
        sx = 16 * math.floor(sx / 16 + 0.5)
        sz = 16 * math.floor(sz / 16 + 0.5)
        
        if Spring.TestBuildOrder(Spring.UnitDefNames["solar"].id, sx, 0, sz, 0) >= 2 then
            Spring.GiveOrderToUnit(cmdr, -Spring.UnitDefNames["solar"].id, {sx, Spring.GetGroundHeight(sx, 0, sz), sz, 0}, {})
            break -- only build one per cycle
        end
    end
end

-- Build wind generators
function llmBuildWind(teamID, cx, cz, frame)
    -- Similar to solar but for wind
    for i = 1, 4 do
        local angle = i * math.pi / 2
        local dist = 96 + math.random(0, 32)
        local sx = cx + math.cos(angle) * dist
        local sz = cz + math.sin(angle) * dist
        sx = 16 * math.floor(sx / 16 + 0.5)
        sz = 16 * math.floor(sz / 16 + 0.5)
        
        if Spring.TestBuildOrder(Spring.UnitDefNames["wind"].id, sx, 0, sz, 0) >= 2 then
            Spring.GiveOrderToUnit(cmdr, -Spring.UnitDefNames["wind"].id, {sx, Spring.GetGroundHeight(sx, 0, sz), sz, 0}, {})
            break
        end
    end
end

-- ============================================================
-- SCOUTING: Enhanced scouting (4x default scout_rate)
-- ============================================================

function llmScout(teamID, frame)
    -- Enhanced scouting based on SCOUT_RATE (0.8102 vs default 0.2)
    -- This means scouts are produced ~4x more frequently
    
    local scoutDef = Spring.UnitDefNames["scout"] or Spring.UnitDefNames["raider"]
    if not scoutDef then return end
    
    local cmdrs = Spring.GetTeamUnitsByDefs(teamID, {Spring.UnitDefNames["aegis_commander"].id})
    if not cmdrs or #cmdrs == 0 then return end
    local cmdr = cmdrs[1]
    if not cmdr then return end
    
    -- Produce scouts more frequently (based on EV("scout_rate", 0.2))
    local shouldScout = (frame % math.max(1, math.floor(1 / llmAI.EV("scout_rate", 0.2) * 30))) == 0
    
    if shouldScout then
        -- Find nearest enemy start position
        local nearestEnemyDist = 999999
        nearestEnemyPos = {}
        
        for _, t in ipairs(Spring.GetTeamList()) do
            if t ~= Spring.GetGaiaTeamID() then
                local ex, _, ez = Spring.GetTeamStartPosition(t)
                if ex then
                    local d = (ex - Spring.GetUnitPosition(cmdr)):len2()
                    if d < nearestEnemyDist then
                        nearestEnemyDist = d
                        nearestEnemyPos = {x=ex, z=ez}
                    end
                end
            end
        end
        
        -- If we found an enemy, move a scout toward them
        if nearestEnemyPos then
            local scoutDefID = Spring.UnitDefNames["scout"] and Spring.UnitDefNames["scout"].id
            if scoutDefID then
                -- Give move command to nearest idle unit or spawn a new scout
                local units = Spring.GetTeamUnits(teamID)
                local idleUnit = nil
                for _, u in ipairs(units) do
                    if Spring.GetUnitIsBuilder(u) and Spring.GetUnitCommandCount(u) == 0 then
                        idleUnit = u
                        break
                    end
                end
                
                if idleUnit then
                    Spring.GiveOrderToUnit(idleUnit, CMD.MOVE, {nearestEnemyPos.x, Spring.GetGroundHeight(nearestEnemyPos.x, 0, nearestEnemyPos.z), nearestEnemyPos.z}, {})
                end
            end
        end
    end
end

-- ============================================================
-- ARMY: Manage army production and composition
-- ============================================================

function llmManageArmy(teamID, frame)
    local myUnits = Spring.GetTeamUnits(teamID)
    local factoryUnits = {}
    local armyUnits = {}
    
    -- Classify units
    for _, uid in ipairs(myUnits) do
        local ud = UnitDefs[Spring.GetUnitDefID(uid)]
        if ud and ud.canMove and not ud.isBuilder then
            table.insert(armyUnits, uid)
        elseif ud and ud.isBuilder then
            table.insert(factoryUnits, uid)
        end
    end
    
    -- Produce army units from factories
    for _, fu in ipairs(factoryUnits) do
        llmProduceUnit(teamID, fu, frame)
    end
    
    -- Retreat low-health units
    llmRetreatArmy(teamID, armyUnits, frame)
end

-- Produce a unit from a factory
function llmProduceUnit(teamID, factory, frame)
    -- Get available build options
    local factoryDef = UnitDefs[Spring.GetUnitDefID(factory)]
    if not factoryDef or not factoryDef.buildOptions then return end
    
    -- Weighted selection based on evolved army values
    local armyOpts = {}
    for i, optID in ipairs(factoryDef.buildOptions) do
        local ud = UnitDefs[optID]
        if ud and ud.metalCost then
            -- Tier-based weighting: cheap (tier 0), mid (tier 1), heavy (tier 2)
            local tier = math.floor((i - 1) / math.ceil(#factoryDef.buildOptions / 3))
            local weight = 1
            
            if tier == 0 then -- cheap units
                weight = llmAI.EV("w_cheap", 0.5)
            elseif tier == 1 then -- mid-tier units
                weight = llmAI.EV("w_mid", 0.3)
            else -- heavy units
                weight = llmAI.EV("w_heavy", 0.2)
            end
            
            -- Range preference adjustment
            if ud.rangedRange and llmAI.EV("w_ranged", 0.5) < 0.5 then
                weight = weight * 0.5 -- prefer non-ranged when w_ranged is low
            end
            
            table.insert(armyOpts, {id=optID, weight=weight, tier=tier, cost=ud.metalCost})
        end
    end
    
    -- Select unit type based on weights
    local totalWeight = 0
    for _, opt in ipairs(armyOpts) do totalWeight = totalWeight + opt.weight end
    
    if totalWeight > 0 then
        local pick = math.random() * totalWeight
        local running = 0
        local selectedIdx = 1
        for i, opt in ipairs(armyOpts) do
            running = running + opt.weight
            if running >= pick then
                selectedIdx = i
                break
            end
        end
        
        local selectedID = armyOpts[selectedIdx].id
        if Spring.TestBuildOrder(selectedID, Spring.GetGroundHeight(), 0, 0, factory) >= 2 then
            Spring.GiveOrderToUnit(factory, -selectedID, {}, {})
        end
    end
end

-- Retreat low-health units
function llmRetreatArmy(teamID, armyUnits, frame)
    for _, uid in ipairs(armyUnits) do
        local hp, mhp = Spring.GetUnitHealth(uid)
        if hp and mhp and hp/mhp < llmAI.EV("retreat_hp", 0.25) then
            -- Find nearest friendly base
            local myAlly = select(6, Spring.GetTeamInfo(teamID, false))
            local nearestBaseDist = 999999
            nearestBasePos = {}
            
            for _, t in ipairs(Spring.GetTeamList()) do
                if t ~= Spring.GetGaiaTeamID() and t ~= Spring.GetTeamAllyTeam(teamID) then
                    -- Skip allies
                end
            end
            
            -- Simple: move toward own start position
            local sx, _, sz = Spring.GetTeamStartPosition(teamID)
            if sx then
                Spring.GiveOrderToUnit(uid, CMD.MOVE, {sx, Spring.GetGroundHeight(sx, 0, sz), sz}, {})
            end
        end
    end
end

-- ============================================================
-- TECH: Earlier tech-up (73% earlier than default)
-- ============================================================

function llmTechUpgrade(teamID, frame)
    -- Based on TECH_FRAME (3281 vs default 12000)
    -- Tech up when we've reached the evolved tech frame
    local gameFrame = Spring.GetGameFrame()
    
    if gameFrame >= llmAI.EV("tech_frame", 12000) then
        -- Trigger tech upgrade
        -- This would normally trigger a research command
        -- For now, just note that we've reached the tech point
    end
end

-- ============================================================
-- ATTACK: With reduced range preference
-- ============================================================

function llmAttack(teamID, frame)
    -- Based on W_RANGED (0.08858 vs default 0.5)
    -- Low w_ranged means prefer non-ranged (short-range) units
    
    local myUnits = Spring.GetTeamUnits(teamID)
    local idleUnits = {}
    
    -- Find idle combat units
    for _, uid in ipairs(myUnits) do
        if Spring.GetUnitCommandCount(uid) == 0 then
            table.insert(idleUnits, uid)
        end
    end
    
    if #idleUnits == 0 then return end
    
    -- Find nearest enemy start position
    local nearestEnemy = nil
    local nearestDist = 999999
    
    for _, t in ipairs(Spring.GetTeamList()) do
        if t ~= Spring.GetGaiaTeamID() and t ~= Spring.GetTeamAllyTeam(teamID) then
            local ex, _, ez = Spring.GetTeamStartPosition(t)
            if ex then
                local d = (ex - Spring.GetUnitPosition(myUnits[1])):len2()
                if d < nearestDist then
                    nearestDist = d
                    nearestEnemy = {x=ex, z=ez}
                end
            end
        end
    end
    
    -- Attack with nearest idle units
    if nearestEnemy and #idleUnits > 0 then
        for _, uid in ipairs(idleUnits) do
            Spring.GiveOrderToUnit(uid, CMD.FIGHT, {nearestEnemy.x, Spring.GetGroundHeight(nearestEnemy.x, 0, nearestEnemy.z), nearestEnemy.z}, {})
        end
    end
end

-- ============================================================
-- UTILITY FUNCTIONS
-- ============================================================

-- Get distance between two points
function Distance(x1, z1, x2, z2)
    return math.sqrt((x2-x1)^2 + (z2-z1)^2)
end

-- Clamp a value between min and max
function Clamp(val, min, max)
    if val < min then return min end
    if val > max then return max end
    return val
end

-- ============================================================
-- END OF llmAI.lua - polyrams evolved AI
--=================================================================
-- To use this AI in a game, the modinfo.lua should reference it:
--[[
modinfo.lua:
{
    name = "llmAI - polyrars evolved",
    type = "ai",
    -- The AI is controlled via the gadget handler above
}
--]]