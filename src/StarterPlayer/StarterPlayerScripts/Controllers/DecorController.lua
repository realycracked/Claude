--[[
	DecorController (ModuleScript)
	Emplacement : StarterPlayer > StarterPlayerScripts > Controllers > DecorController

	Décor animé côté client : les nuages dérivent lentement au-dessus de la map.
	La position dépend de l'heure serveur : tous les joueurs voient les mêmes nuages.
]]

local RunService = game:GetService("RunService")

local DecorController = {}

function DecorController.Init()
	local map = workspace:WaitForChild("Map", 30)
	local clouds = map and map:WaitForChild("Clouds", 30)
	if not clouds then
		return
	end

	RunService.RenderStepped:Connect(function()
		local now = workspace:GetServerTimeNow()
		for _, cloud in ipairs(clouds:GetChildren()) do
			local width = cloud:GetAttribute("Width")
			if width and cloud.PrimaryPart then
				local startX = cloud:GetAttribute("StartX") or 0
				local speed = cloud:GetAttribute("Speed") or 1
				local phase = cloud:GetAttribute("Phase") or 0
				local x = startX + (phase + now * speed) % width
				cloud:PivotTo(CFrame.new(x, cloud:GetAttribute("Y") or 80, cloud:GetAttribute("Z") or 0))
			end
		end
	end)
end

return DecorController
