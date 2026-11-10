--[[
	SlimeAnimator (ModuleScript)
	Emplacement : StarterPlayer > StarterPlayerScripts > Controllers > SlimeAnimator

	Anime tous les slimes côté client (zéro trafic réseau) :
	- respiration (le corps gonfle et s'aplatit doucement)
	- clignement des yeux
	- coup reçu : flash blanc + compression (détecté par la baisse de l'attribut Health)
	- mort : le slime rétrécit et disparaît (attribut Alive = false)
	Les pièces attachées (yeux, cornes, cristaux...) suivent la déformation du corps.
]]

local RunService = game:GetService("RunService")

local SlimeAnimator = {}

local states = {} -- [model] = état d'animation
local random = Random.new()
local ANIMATE_DISTANCE = 170 -- au-delà, pas d'animation (économie sur mobile)
local DEATH_TIME = 0.45
local WHITE = Color3.new(1, 1, 1)

local function initState(model)
	local body = model.PrimaryPart
	if not body then
		return nil
	end
	local state = {
		Body = body,
		BaseSize = body:GetAttribute("BaseSize") or body.Size,
		BaseColor = body.Color,
		BaseTransparency = body.Transparency,
		Phase = random:NextNumber(0, math.pi * 2),
		Flash = 0,
		Squash = 0,
		LastHealth = model:GetAttribute("Health"),
		NextBlink = os.clock() + random:NextNumber(2, 5),
		BlinkUntil = 0,
		DeathStart = nil,
		Parts = {},
	}
	for _, part in ipairs(model:GetChildren()) do
		if part:IsA("BasePart") and part ~= body then
			state.Parts[part] = {
				Rel = body.CFrame:ToObjectSpace(part.CFrame),
				Size = part.Size,
				Color = part.Color,
				Transparency = part.Transparency,
			}
		end
	end
	return state
end

local function update(model, state, now, dt, cameraPosition)
	local body = state.Body
	if not body.Parent then
		return
	end

	-- Détection des coups et de la mort via les attributs
	local health = model:GetAttribute("Health")
	if health ~= nil and state.LastHealth ~= nil and health < state.LastHealth then
		state.Flash = 1
		state.Squash = 1
	end
	state.LastHealth = health
	if model:GetAttribute("Alive") == false and not state.DeathStart then
		state.DeathStart = now
	end

	-- Trop loin : on n'anime pas (sauf la mort)
	if not state.DeathStart and (body.Position - cameraPosition).Magnitude > ANIMATE_DISTANCE then
		return
	end

	state.Flash = math.max(0, state.Flash - dt * 6)
	state.Squash = math.max(0, state.Squash - dt * 5)

	if now >= state.NextBlink then
		state.BlinkUntil = now + 0.12
		state.NextBlink = now + random:NextNumber(2, 5)
	end
	local blinking = now < state.BlinkUntil

	local breathe = math.sin((now + state.Phase) * 3)
	local sx = 1 + 0.035 * breathe + 0.22 * state.Squash
	local sy = 1 - 0.05 * breathe - 0.38 * state.Squash

	local deathProgress = 0
	if state.DeathStart then
		deathProgress = math.clamp((now - state.DeathStart) / DEATH_TIME, 0, 1)
		local shrink = 1 - deathProgress
		sx = sx * shrink
		sy = sy * shrink
	end
	sx = math.max(sx, 0.02)
	sy = math.max(sy, 0.02)

	body.Size = Vector3.new(state.BaseSize.X * sx, state.BaseSize.Y * sy, state.BaseSize.Z * sx)
	body.Color = state.BaseColor:Lerp(WHITE, state.Flash)
	if state.DeathStart then
		body.Transparency = state.BaseTransparency + (1 - state.BaseTransparency) * deathProgress
	end

	local scaleVector = Vector3.new(sx, sy, sx)
	for part, info in pairs(state.Parts) do
		if part.Parent then
			local rel = info.Rel
			part.CFrame = body.CFrame * CFrame.new(rel.Position * scaleVector) * rel.Rotation
			local blinkScale = 1
			if blinking and (part.Name == "Eye" or part.Name == "Pupil" or part.Name == "Shine") then
				blinkScale = 0.12
			end
			local newSize = Vector3.new(info.Size.X * sx, info.Size.Y * sy * blinkScale, info.Size.Z * sx)
			part.Size = Vector3.new(math.max(newSize.X, 0.02), math.max(newSize.Y, 0.02), math.max(newSize.Z, 0.02))
			if part.Name == "Core" or part.Name == "Drop" then
				part.Color = info.Color:Lerp(WHITE, state.Flash)
			end
			if state.DeathStart then
				part.Transparency = info.Transparency + (1 - info.Transparency) * deathProgress
			end
		end
	end
end

function SlimeAnimator.Init()
	local slimes = workspace:WaitForChild("Slimes")
	slimes.ChildRemoved:Connect(function(model)
		states[model] = nil
	end)

	RunService.RenderStepped:Connect(function(dt)
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local now = os.clock()
		local cameraPosition = camera.CFrame.Position
		for _, model in ipairs(slimes:GetChildren()) do
			local state = states[model]
			if not state then
				state = initState(model)
				states[model] = state
			end
			if state then
				update(model, state, now, dt, cameraPosition)
			end
		end
	end)
end

return SlimeAnimator
