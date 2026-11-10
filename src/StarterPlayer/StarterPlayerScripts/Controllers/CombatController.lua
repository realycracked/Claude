--[[
	CombatController (ModuleScript)
	Emplacement : StarterPlayer > StarterPlayerScripts > Controllers > CombatController

	Entrées du joueur : clic gauche (PC) ou bouton tactile ATTAQUE (mobile).
	Choisit le slime le plus proche à portée, joue l'animation et prévient le serveur.
	Reçoit aussi les coups des autres joueurs pour les animer.
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SwordConfig = require(ReplicatedStorage.Config.SwordConfig)
local CombatMath = require(ReplicatedStorage.Shared.CombatMath)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local ClientState = require(script.Parent.ClientState)
local CombatVFX = require(script.Parent.CombatVFX)

local CombatController = {}

local player = Players.LocalPlayer
local holding = false
local nextAllowed = 0
local slimesFolder = nil
local attackRemote = nil

local function getRoot()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart")
end

-- Slime vivant le plus proche dans la portée de l'épée
local function findTarget(root, range)
	local best, bestDistance = nil, range
	for _, model in ipairs(slimesFolder:GetChildren()) do
		if model:GetAttribute("Alive") and model.PrimaryPart then
			local size = model.PrimaryPart.Size.X
			local distance = (model.PrimaryPart.Position - root.Position).Magnitude - size / 2
			if distance <= bestDistance then
				best = model
				bestDistance = distance
			end
		end
	end
	return best
end

local function tryAttack()
	local profile = ClientState.Profile
	local root = getRoot()
	if not profile or not root then
		return
	end
	local now = os.clock()
	if now < nextAllowed then
		return
	end
	local _, interval, tierIndex = CombatMath.GetSwordAttack(profile)
	nextAllowed = now + interval

	local sword = SwordConfig.Get(profile.EquippedSword) or SwordConfig.Get(SwordConfig.DefaultSword)
	local target = findTarget(root, sword.Range)

	CombatVFX.PlaySwing(player.Character, interval, tierIndex, profile.EquippedEffect)
	if target then
		attackRemote:FireServer(target)
	end
end

-- À brancher sur le bouton tactile (UIController)
function CombatController.SetHolding(value)
	holding = value
	if value then
		tryAttack()
	end
end

function CombatController.Init()
	slimesFolder = workspace:WaitForChild("Slimes")
	attackRemote = Remotes.Get("Attack")

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.KeyCode == Enum.KeyCode.ButtonR2 then
			holding = true
			tryAttack()
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.KeyCode == Enum.KeyCode.ButtonR2 then
			holding = false
		end
	end)

	-- Attaque continue tant que le bouton reste enfoncé
	RunService.Heartbeat:Connect(function()
		if holding then
			tryAttack()
		end
	end)

	-- Coups validés par le serveur (les miens et ceux des autres)
	Remotes.Get("AttackVFX").OnClientEvent:Connect(function(attacker, slimeModel, position, damage, tierIndex, effectId)
		if attacker ~= player and attacker.Character then
			CombatVFX.PlaySwing(attacker.Character, CombatVFX.GetTierInterval(tierIndex), tierIndex, effectId)
		end
		CombatVFX.PlayImpact(position, damage, effectId, tierIndex, false)
	end)
end

return CombatController
