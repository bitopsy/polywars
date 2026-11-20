-- Shared brightness model for the pylon light and the power wires: when a team's energy
-- store runs low the lights dim and flicker, with random brief blackouts as it nears empty.
local M = {}

M.LOW = 0.25    -- below this fraction of full storage the lights start to flicker

function M.Ratio(teamID)
	local cur, sto = Spring.GetTeamResources(teamID, "energy")
	if not cur or not sto or sto <= 0 then return 1 end   -- unknown (e.g. hidden enemy): assume fine
	return math.max(0, math.min(1, cur / sto))
end

local function Noise(k, id)                              -- cheap deterministic pseudo-random in [0,1)
	local x = math.sin(k * 12.9898 + id * 78.233) * 43758.5453
	return x - math.floor(x)
end

-- returns a brightness multiplier in 0..1 for one light (id keeps lights out of sync)
function M.Brightness(teamID, id, t)
	local r = M.Ratio(teamID)
	if r >= M.LOW then return 1 end
	local sev = 1 - r / M.LOW                             -- 0 (just below threshold) .. 1 (empty)
	local bucket = math.floor(t * 13 + id * 3.7)          -- new random value ~13 times per second
	local n = Noise(bucket, id)
	if n < 0.55 * sev then return 0.05 end               -- blackout flash
	local dim = 1 - 0.55 * sev                            -- overall dimming
	return dim * (1 - 0.4 * sev * Noise(bucket + 101, id))
end

return M
