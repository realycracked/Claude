--[[
	EggAnimator (ModuleScript)
	Emplacement : StarterPlayer > StarterPlayerScripts > Controllers > EggAnimator

	Anime les ornements des œufs côté client : les éclats "Orbit" tournent autour de l'œuf.
	Appelé par ConveyorController (œufs du tapis) et CompanionController (compagnons)
	juste après avoir déplacé le modèle.
]]

local EggAnimator = {}

function EggAnimator.Animate(model, now)
	local pivot = model:GetPivot()
	for _, part in ipairs(model:GetChildren()) do
		if part.Name == "Orbit" then
			local radius = part:GetAttribute("Radius") or 1.5
			local height = part:GetAttribute("Height") or 0
			local phase = part:GetAttribute("Phase") or 0
			local speed = part:GetAttribute("Speed") or 1.5
			local angle = phase + now * speed
			local bob = math.sin(now * 2 + phase) * 0.15
			part.CFrame = pivot * CFrame.Angles(0, angle, 0) * CFrame.new(radius, height + bob, 0) * CFrame.Angles(now * 2, now * 1.3, 0)
		end
	end
end

return EggAnimator
