--[[
	CompanionController (ModuleScript)
	Emplacement : StarterPlayer > StarterPlayerScripts > Controllers > CompanionController

	Fait suivre les œufs compagnons (de TOUS les joueurs) avec un mouvement fluide
	et un flottement. Joue aussi la petite "charge" quand un œuf attaque un slime.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local CombatVFX = require(script.Parent.CombatVFX)
local EggAnimator = require(script.Parent.EggAnimator)

local CompanionController = {}

local lunges = {} -- [model] = { Target = Vector3, Start = os.clock() }
local LUNGE_TIME = 0.35
local companions = nil

local function findCompanion(ownerUserId, slot)
	local player = Players:GetPlayerByUserId(ownerUserId)
	local folder = player and companions:FindFirstChild(player.Name)
	if not folder then
		return nil
	end
	for _, model in ipairs(folder:GetChildren()) do
		if model:GetAttribute("Slot") == slot then
			return model
		end
	end
	return nil
end

function CompanionController.Init()
	companions = workspace:WaitForChild("Companions")
	local conf = GameConfig.Companion

	Remotes.Get("CompanionAttack").OnClientEvent:Connect(function(ownerUserId, slot, slimeModel, position, damage)
		local model = findCompanion(ownerUserId, slot)
		if model then
			lunges[model] = { Target = position, Start = os.clock() }
		end
		CombatVFX.PlayImpact(position, damage, "", 1, true)
	end)

	RunService.RenderStepped:Connect(function(dt)
		local now = os.clock()
		local alpha = math.min(1, dt * conf.FollowSpeed)
		for _, folder in ipairs(companions:GetChildren()) do
			local player = Players:FindFirstChild(folder.Name)
			local character = player and player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root then
				for _, model in ipairs(folder:GetChildren()) do
					local slot = model:GetAttribute("Slot") or 1
					local offset = conf.Offsets[slot] or conf.Offsets[#conf.Offsets]
					local bob = math.sin(now * conf.BobSpeed + slot * 1.3) * conf.BobHeight
					local target = root.CFrame * CFrame.new(offset + Vector3.new(0, bob, 0))

					local lunge = lunges[model]
					if lunge then
						local progress = (now - lunge.Start) / LUNGE_TIME
						if progress >= 1 then
							lunges[model] = nil
						else
							local toTarget = lunge.Target - target.Position
							if toTarget.Magnitude > 0.1 then
								local push = toTarget.Unit * math.min(toTarget.Magnitude * 0.6, 6) * math.sin(progress * math.pi)
								target = CFrame.lookAt(target.Position + push, lunge.Target)
							end
						end
					end

					local current = model:GetPivot()
					model:PivotTo(current:Lerp(target, alpha))
					EggAnimator.Animate(model, now)
				end
			end
		end
	end)
end

return CompanionController
