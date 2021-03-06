--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
function widget:GetInfo()
	return {
		name      = "Limit FPS",
		desc      = "Limits FPS to save idle CPU cycles",
		author    = "Licho",
		date      = "-306210.1318053026",
		license   = "GPL-v2",
		layer     = -3000,
		handler   = true,
		api       = true, -- Makes KeyPress occur before chili
		enabled   = true,
	}
end

local MAX_FPS = 15

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Callins

local lastTimer
local forceRedraw = false

function widget:Initialize() 
	lastTimer = Spring.GetTimer();
end

function widget:AllowDraw()
	if forceRedraw then
		forceRedraw = false
		return true
	end
	local timer = Spring.GetTimer();
	local diff = Spring.DiffTimers(timer, lastTimer)
	if (diff >= 1/MAX_FPS) then
		lastTimer = timer
		return true
	end 
	return false
end

function widget:MousePress()
	forceRedraw = true
	return false
end

function widget:KeyPress()
	forceRedraw = true
	return false
end
