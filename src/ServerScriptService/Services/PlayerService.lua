--[[
	PlayerService (ModuleScript)
	Emplacement : ServerScriptService > Services > PlayerService

	Arrivée / départ des joueurs, leaderstats, envoi du profil au client,
	argent (AddCash / SpendCash) et rangs.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local RankConfig = require(ReplicatedStorage.Config.RankConfig)
local CombatMath = require(ReplicatedStorage.Shared.CombatMath)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Util = require(ReplicatedStorage.Shared.Util)

local DataService = require(ServerScriptService.Services.DataService)
local CompanionService = require(ServerScriptService.Services.CompanionService)
local RequestRouter = require(ServerScriptService.Services.RequestRouter)
local SwordBuilder = require(ServerScriptService.Builders.SwordBuilder)

local PlayerService = {}

local ProfileUpdated = Remotes.Get("ProfileUpdated")
local Notify = Remotes.Get("Notify")

-- Message affiché en haut de l'écran du joueur
function PlayerService.Notify(player, message, color)
	Notify:FireClient(player, message, color)
end

-- Envoie une copie du profil au client et met à jour les attributs publics
function PlayerService.Push(player)
	local profile = DataService.Get(player)
	if not profile then
		return
	end
	local tierIndex = CombatMath.GetTier(CombatMath.GetTotalDPS(profile))
	player:SetAttribute("Tier", tierIndex)
	player:SetAttribute("Effect", profile.EquippedEffect or "")
	local rankId, rank = RankConfig.GetRank(profile.TotalEarned)
	player:SetAttribute("Rank", rankId)

	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		leaderstats.Cash.Value = math.floor(profile.Cash)
		leaderstats.Rang.Value = rank.Name
	end
	ProfileUpdated:FireClient(player, profile)
end

-- Ajoute de l'argent. countsForRank = true pour l'argent gagné en combat.
function PlayerService.AddCash(player, amount, countsForRank)
	local profile = DataService.Get(player)
	if not profile or amount == 0 then
		return
	end
	profile.Cash = profile.Cash + amount
	if countsForRank and amount > 0 then
		local oldRank = RankConfig.GetRank(profile.TotalEarned)
		profile.TotalEarned = profile.TotalEarned + amount
		local newRank, def = RankConfig.GetRank(profile.TotalEarned)
		if newRank > oldRank then
			PlayerService.Notify(player, "🏆 Nouveau rang : " .. def.Name .. " ! (" .. def.MaxEquipped .. " œufs équipables)", Color3.fromRGB(255, 215, 0))
		end
	end
	PlayerService.Push(player)
end

-- Retire de l'argent si le joueur en a assez. Retourne true si réussi.
function PlayerService.SpendCash(player, amount)
	local profile = DataService.Get(player)
	if not profile or profile.Cash < amount then
		return false
	end
	profile.Cash = profile.Cash - amount
	return true
end

local function onCharacterAdded(player, character)
	local profile = DataService.Get(player)
	if not profile then
		return
	end
	character:WaitForChild("HumanoidRootPart", 10)
	task.wait(0.2) -- laisse le personnage finir de se charger
	if character.Parent then
		SwordBuilder.Attach(character, profile.EquippedSword, profile.EquippedEffect)
	end
end

local function onPlayerAdded(player)
	local session = DataService.Load(player)
	if player.Parent ~= Players then
		return
	end
	local profile = session.Data

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local cash = Instance.new("IntValue")
	cash.Name = "Cash"
	cash.Value = math.floor(profile.Cash)
	cash.Parent = leaderstats
	local rang = Instance.new("StringValue")
	rang.Name = "Rang"
	rang.Parent = leaderstats
	leaderstats.Parent = player

	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	if player.Character then
		task.spawn(onCharacterAdded, player, player.Character)
	end

	CompanionService.Refresh(player)
	PlayerService.Push(player)

	if not session.Loaded then
		task.delay(3, function()
			PlayerService.Notify(player, "⚠️ Données non chargées : la sauvegarde est désactivée pour cette session.", Color3.fromRGB(255, 120, 120))
		end)
	else
		task.delay(2, function()
			PlayerService.Notify(player, "Bienvenue " .. player.DisplayName .. " ! Frappe les slimes pour gagner de l'argent.", Color3.fromRGB(255, 255, 255))
		end)
	end
end

function PlayerService.Init()
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(onPlayerAdded, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		CompanionService.Remove(player)
	end)

	-- Le client demande son profil au démarrage (au cas où il aurait raté le premier envoi)
	RequestRouter.Register("GetProfile", function(player)
		local profile = DataService.Get(player)
		if not profile then
			return false, "Profil en cours de chargement"
		end
		return true, nil, profile
	end)

	-- Bouton Home : retour au point de départ
	RequestRouter.Register("GoHome", function(player)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not root then
			return false, "Personnage introuvable"
		end
		character:PivotTo(CFrame.new(GameConfig.SpawnPosition))
		return true, "Retour à la maison"
	end)
end

return PlayerService
