--[[
	SlimeService (ModuleScript)
	Emplacement : ServerScriptService > Services > SlimeService

	Fait apparaître les slimes dans leurs zones, les fait sautiller, gère leurs
	points de vie, leur mort, la répartition des récompenses et la réapparition.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local SlimeConfig = require(ReplicatedStorage.Config.SlimeConfig)
local DataService = require(ServerScriptService.Services.DataService)
local PlayerService = require(ServerScriptService.Services.PlayerService)
local SlimeBuilder = require(ServerScriptService.Builders.SlimeBuilder)

local SlimeService = {}

local slimesFolder = workspace:WaitForChild("Slimes")
local states = {} -- [model] = state
local random = Random.new()

local function groundHeight(def)
	return SlimeBuilder.GetBodySize(def).Y / 2 + 0.05
end

local spawnSlime -- défini plus bas

-- Un saut vers un point aléatoire de la zone
local function hop(state)
	state.Hopping = true
	local def = state.Def
	local model = state.Model
	local startPosition = model:GetPivot().Position

	local angle = random:NextNumber(0, math.pi * 2)
	local distance = random:NextNumber(def.Size * 0.6, def.Size * 1.6)
	local target = startPosition + Vector3.new(math.cos(angle), 0, math.sin(angle)) * distance
	-- Reste dans la zone
	local fromHome = Vector3.new(target.X - state.Home.X, 0, target.Z - state.Home.Z)
	if fromHome.Magnitude > def.WanderRadius then
		target = state.Home + fromHome.Unit * def.WanderRadius * 0.9
	end
	target = Vector3.new(target.X, groundHeight(def), target.Z)

	local flat = Vector3.new(target.X - startPosition.X, 0, target.Z - startPosition.Z)
	local rotation = model:GetPivot().Rotation
	if flat.Magnitude > 0.05 then
		rotation = CFrame.lookAt(Vector3.zero, flat).Rotation
	end

	local duration = 0.5
	local startTime = os.clock()
	while state.Alive and model.Parent do
		local progress = math.min((os.clock() - startTime) / duration, 1)
		local position = startPosition:Lerp(target, progress) + Vector3.new(0, math.sin(progress * math.pi) * def.Size * 0.45, 0)
		model:PivotTo(CFrame.new(position) * rotation)
		if progress >= 1 then
			break
		end
		RunService.Heartbeat:Wait()
	end
	state.NextHop = os.clock() + def.HopInterval * random:NextNumber(0.7, 1.4)
	state.Hopping = false
end

-- Mort : récompenses réparties selon les dégâts de chacun, puis réapparition
local function kill(state)
	if not state.Alive then
		return
	end
	state.Alive = false -- empêche toute double récompense
	local model = state.Model
	local def = state.Def
	model:SetAttribute("Alive", false)
	states[model] = nil

	local totalDamage = 0
	for _, damage in pairs(state.Damage) do
		totalDamage = totalDamage + damage
	end
	if totalDamage > 0 then
		for userId, damage in pairs(state.Damage) do
			local player = Players:GetPlayerByUserId(userId)
			if player then
				local share = math.max(1, math.floor(def.Reward * damage / totalDamage + 0.5))
				local profile = DataService.Get(player)
				if profile then
					profile.Kills = profile.Kills + 1
				end
				PlayerService.AddCash(player, share, true)
			end
		end
	end

	task.spawn(function()
		SlimeBuilder.PlayDeath(model)
		model:Destroy()
		task.delay(def.RespawnTime, function()
			spawnSlime(def, state.Home)
		end)
	end)
end

-- Applique des dégâts. Retourne true si le coup a compté.
function SlimeService.ApplyDamage(state, player, amount)
	if not state or not state.Alive or amount <= 0 then
		return false
	end
	local dealt = math.min(amount, state.Health)
	state.Health = state.Health - dealt
	state.Damage[player.UserId] = (state.Damage[player.UserId] or 0) + dealt

	local model = state.Model
	model:SetAttribute("Health", math.max(0, state.Health))
	SlimeBuilder.UpdateHealth(model, state.Health, state.Def.Health)
	if state.Health <= 0 then
		kill(state)
	else
		SlimeBuilder.PlayHit(model, state.Def)
	end
	return true
end

spawnSlime = function(def, home)
	local model = SlimeBuilder.Build(def)
	local state = {
		Model = model,
		Def = def,
		Home = home,
		Health = def.Health,
		Damage = {}, -- [userId] = dégâts infligés
		Alive = true,
		Hopping = false,
		NextHop = os.clock() + random:NextNumber(0.5, def.HopInterval),
	}
	model:PivotTo(CFrame.new(home.X, groundHeight(def), home.Z) * CFrame.Angles(0, random:NextNumber(0, math.pi * 2), 0))
	model.Parent = slimesFolder
	states[model] = state
	return state
end

function SlimeService.GetState(model)
	return states[model]
end

-- Slime vivant le plus proche d'une position, dans une portée donnée
function SlimeService.GetNearest(position, range)
	local best, bestDistance = nil, range
	for _, state in pairs(states) do
		if state.Alive and state.Model.Parent then
			local distance = (state.Model:GetPivot().Position - position).Magnitude - state.Def.Size / 2
			if distance <= bestDistance then
				best = state
				bestDistance = distance
			end
		end
	end
	return best
end

function SlimeService.Init()
	for _, def in ipairs(SlimeConfig.List) do
		for i = 1, def.Count do
			local angle = (i / def.Count) * math.pi * 2
			local radius = def.Count == 1 and 0 or def.ZoneRadius * 0.5
			local home = def.ZonePosition + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
			spawnSlime(def, home)
		end
	end

	-- Déclenche les sauts
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		for _, state in pairs(states) do
			if state.Alive and not state.Hopping and now >= state.NextHop then
				task.spawn(hop, state)
			end
		end
	end)
end

return SlimeService
