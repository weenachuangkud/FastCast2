--[[
	- Author : Mawin CK 
	- Date : 2025
	
]]
local Configs = {}

Configs.DebugLogging = {
	Casting = false,
	Segment = false,
	Hit = false,
	Pierced = false,
	Calculation = false,
}
Configs.VisualizeCasts = true

--[[
	How casts are stepped.

	"PerFrame" - One update per frame (PreSimulation on the client, Heartbeat
	             on the server). Cheapest, and the delta always matches the
	             real frame time. Recommended default.

	"Fixed"    - RunService:BindToSimulation at FixedSimulationFrequency. The
	             engine keeps the simulation at that fixed rate, so when the
	             frame rate drops below the frequency it runs MULTIPLE steps
	             per frame to catch up. Under heavy load this multiplies the
	             per-frame cast cost (a death spiral), which is why it is not
	             the default. Only use it if you need deterministic fixed-step
	             simulation.
]]
Configs.SimulationMode = "PerFrame"
Configs.FixedSimulationFrequency = Enum.StepFrequency.Hz60

--[[
	How often cosmetic bullet parts are moved, in simulation frames.

	1 = move every frame (smoothest). Higher values push cosmetic CFrames
	every Nth frame. Moving thousands of parts with BulkMoveTo (and
	replicating their CFrames to clients) is by far the most expensive part of
	an instanced cast, so 2 or 3 roughly halves/thirds that cost. Roblox
	replicates instance CFrames at roughly 20 Hz anyway, so 3 (~20 Hz at 60
	FPS) is the default; use 1 for very fast projectiles that need every-frame
	smoothness. Hit detection is unaffected: it still runs every frame.
]]
Configs.CosmeticUpdateInterval = 3

return Configs
