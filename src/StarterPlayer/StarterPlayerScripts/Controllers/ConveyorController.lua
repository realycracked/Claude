--[[
	ConveyorController (ModuleScript)
	Emplacement : StarterPlayer > StarterPlayerScripts > Controllers > ConveyorController

	Déplace visuellement les œufs du tapis et les lamelles du tapis.
	La position dépend uniquement de l'heure serveur : tous les joueurs voient la même chose.
]]

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Config.GameConfig)

local ConveyorController = {}

function ConveyorController.Init()
	local conf = GameConfig.Conveyor
	local direction = conf.Direction.Unit
	local eggsFolder = workspace:WaitForChild("ConveyorEggs")
	local map = workspace:WaitForChild("Map", 30)
	local slats = map and map:WaitForChild("Conveyor", 30) and map.Conveyor:WaitForChild("Slats", 30)
	local slatStart = conf.Center - direction * (conf.Length / 2) + Vector3.new(0, conf.BeltHeight + 0.04, 0)
	local slatRotation = CFrame.lookAt(Vector3.zero, direction).Rotation

	RunService.RenderStepped:Connect(function()
		local now = workspace:GetServerTimeNow()

		for _, model in ipairs(eggsFolder:GetChildren()) do
			local spawnTime = model:GetAttribute("SpawnTime")
			local start = model:GetAttribute("StartPosition")
			if spawnTime and start and model.PrimaryPart then
				local elapsed = now - spawnTime
				local position = start + direction * conf.Speed * elapsed
				-- Petite rotation pour rendre l'œuf vivant
				model:PivotTo(CFrame.new(position) * CFrame.Angles(0, elapsed * 0.6, 0))
			end
		end

		if slats then
			for _, slat in ipairs(slats:GetChildren()) do
				local offset = slat:GetAttribute("Offset") or 0
				local distance = (offset + now * conf.Speed) % conf.Length
				slat.CFrame = CFrame.new(slatStart + direction * distance) * slatRotation
			end
		end
	end)
end

return ConveyorController
