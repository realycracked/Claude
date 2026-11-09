--[[
	CombatService (ModuleScript)
	Emplacement : ServerScriptService > Services > CombatService

	Reçoit les attaques du joueur (RemoteEvent "Attack") et fait attaquer les œufs
	équipés automatiquement. Le SERVEUR calcule les dégâts, vérifie la cadence,
	la portée et la cible : le client n'envoie que "je frappe ce slime".
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local SwordConfig = require(ReplicatedStorage.Config.SwordConfig)
local CombatMath = require(ReplicatedStorage.Shared.CombatMath)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local DataService = require(ServerScriptService.Services.DataService)
local SlimeService = require(ServerScriptService.Services.SlimeService)

local CombatService = {}

local Attack = Remotes.Get("Attack")
local AttackVFX = Remotes.Get("AttackVFX")
local CompanionAttack = Remotes.Get("CompanionAttack")

local lastAttack = {} -- [player] = os.clock() du dernier coup accepté
local lastTarget = {} -- [player] = state du dernier slime frappé
local combatUntil = {} -- [player] = heure jusqu'à laquelle les œufs attaquent
local eggTimers = {} -- [player] = { [eggId] = prochaine attaque }

local function getRoot(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart")
end

local function onAttack(player, slimeModel)
	local profile = DataService.Get(player)
	if not profile then
		return
	end
	if typeof(slimeModel) ~= "Instance" then
		return
	end
	local state = SlimeService.GetState(slimeModel)
	if not state or not state.Alive then
		return
	end
	local root = getRoot(player)
	if not root then
		return
	end

	-- Cadence (avec une tolérance pour la latence)
	local damage, interval, tierIndex = CombatMath.GetSwordAttack(profile)
	local now = os.clock()
	if now - (lastAttack[player] or 0) < interval * GameConfig.Combat.CooldownTolerance then
		return
	end

	-- Portée
	local sword = SwordConfig.Get(profile.EquippedSword) or SwordConfig.Get(SwordConfig.DefaultSword)
	local slimePosition = slimeModel:GetPivot().Position
	local distance = (root.Position - slimePosition).Magnitude
	if distance > sword.Range + state.Def.Size / 2 + GameConfig.Combat.DistanceTolerance then
		return
	end

	lastAttack[player] = now
	combatUntil[player] = now + GameConfig.Combat.CombatTimeout
	lastTarget[player] = state

	SlimeService.ApplyDamage(state, player, damage)
	AttackVFX:FireAllClients(player, slimeModel, slimePosition, damage, tierIndex, profile.EquippedEffect or "")
end

-- Attaques automatiques des œufs équipés (pendant le combat seulement)
local function companionStep()
	local now = os.clock()
	for _, player in ipairs(Players:GetPlayers()) do
		if (combatUntil[player] or 0) > now then
			local profile = DataService.Get(player)
			local root = profile and getRoot(player)
			if root then
				local timers = eggTimers[player]
				if not timers then
					timers = {}
					eggTimers[player] = timers
				end
				local range = GameConfig.Combat.CompanionRange
				for slot, eggId in ipairs(profile.Equipped) do
					if (timers[eggId] or 0) <= now then
						local item = CombatMath.FindEgg(profile, eggId)
						if item then
							local damage, interval = CombatMath.GetEggAttack(item)
							local target = lastTarget[player]
							if not (target and target.Alive and target.Model.Parent and (target.Model:GetPivot().Position - root.Position).Magnitude <= range) then
								target = SlimeService.GetNearest(root.Position, range)
							end
							if target then
								timers[eggId] = now + interval
								local position = target.Model:GetPivot().Position
								local targetModel = target.Model
								SlimeService.ApplyDamage(target, player, damage)
								CompanionAttack:FireAllClients(player.UserId, slot, targetModel, position, damage)
							else
								timers[eggId] = now + 0.25 -- réessaie bientôt
							end
						end
					end
				end
			end
		end
	end
end

function CombatService.Init()
	Attack.OnServerEvent:Connect(onAttack)
	RunService.Heartbeat:Connect(companionStep)
	Players.PlayerRemoving:Connect(function(player)
		lastAttack[player] = nil
		lastTarget[player] = nil
		combatUntil[player] = nil
		eggTimers[player] = nil
	end)
end

return CombatService
