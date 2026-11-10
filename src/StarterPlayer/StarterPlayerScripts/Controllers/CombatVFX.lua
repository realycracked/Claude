--[[
	CombatVFX (ModuleScript)
	Emplacement : StarterPlayer > StarterPlayerScripts > Controllers > CombatVFX

	Effets visuels du combat, côté client uniquement :
	- animation du bras et de l'épée (plus rapide et plus stylée selon le palier de DPS)
	- traînée de l'épée (couleur de l'effet équipé)
	- impact sur le slime + nombre de dégâts
	Tout est léger pour rester fluide sur mobile et ne jamais cacher les barres de vie.
]]

local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EffectConfig = require(ReplicatedStorage.Config.EffectConfig)
local CombatMath = require(ReplicatedStorage.Shared.CombatMath)
local Util = require(ReplicatedStorage.Shared.Util)

local CombatVFX = {}

local originalC0 = {} -- [Motor6D] = CFrame d'origine
local swingCount = {} -- [character] = nombre de coups (pour alterner les enchaînements)

local function getShoulder(character)
	local upperArm = character:FindFirstChild("RightUpperArm")
	if upperArm then
		return upperArm:FindFirstChild("RightShoulder"), "R15"
	end
	local torso = character:FindFirstChild("Torso")
	if torso then
		return torso:FindFirstChild("Right Shoulder"), "R6"
	end
	return nil
end

local function armRotation(rigType, angle, twist)
	-- R15 : l'épaule tourne autour de X ; R6 : autour de Z (axe du Motor6D)
	if rigType == "R15" then
		return CFrame.Angles(math.rad(angle), 0, math.rad(twist))
	end
	return CFrame.Angles(0, math.rad(-twist), math.rad(angle))
end

local function getTrail(character)
	local sword = character:FindFirstChild("Sword")
	local blade = sword and sword:FindFirstChild("Blade")
	return blade and blade:FindFirstChild("Trail")
end

-- Couleur arc-en-ciel qui tourne avec le temps
local function rainbowSequence()
	local keypoints = {}
	for i = 0, 5 do
		local hue = (os.clock() * 0.6 + i / 6) % 1
		table.insert(keypoints, ColorSequenceKeypoint.new(i / 5, Color3.fromHSV(hue, 1, 1)))
	end
	return ColorSequence.new(keypoints)
end

-- Animation d'un coup d'épée sur un personnage (le sien ou celui d'un autre joueur)
function CombatVFX.PlaySwing(character, interval, tierIndex, effectId)
	if not character then
		return
	end
	local motor, rigType = getShoulder(character)
	if not motor then
		return
	end
	if not originalC0[motor] then
		originalC0[motor] = motor.C0
	end
	local base = originalC0[motor]
	local count = (swingCount[character] or 0) + 1
	swingCount[character] = count

	-- Enchaînement : coup vertical / coup diagonal en alternance (dès le palier 2)
	local twist = 0
	if tierIndex >= 2 and count % 2 == 0 then
		twist = 55
	end
	if tierIndex >= 4 and count % 3 == 0 then
		twist = -45
	end

	local raiseTime = interval * 0.3
	local strikeTime = interval * 0.22
	local returnTime = interval * 0.3

	local raised = base * armRotation(rigType, 150 + tierIndex * 5, twist)
	local struck = base * armRotation(rigType, 25, twist)

	local trail = getTrail(character)
	local effect = EffectConfig.Get(effectId)

	task.spawn(function()
		local raise = TweenService:Create(motor, TweenInfo.new(raiseTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { C0 = raised })
		raise:Play()
		raise.Completed:Wait()

		if trail then
			trail.Lifetime = 0.1 + tierIndex * 0.05
			trail.WidthScale = NumberSequence.new(0.8 + tierIndex * 0.35)
			if effect and effect.Rainbow then
				trail.Color = rainbowSequence()
			end
			trail.Enabled = true
		end

		local strike = TweenService:Create(motor, TweenInfo.new(strikeTime, Enum.EasingStyle.Back, Enum.EasingDirection.In), { C0 = struck })
		strike:Play()
		strike.Completed:Wait()

		task.delay(0.08, function()
			if trail then
				trail.Enabled = false
			end
		end)

		local back = TweenService:Create(motor, TweenInfo.new(returnTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { C0 = base })
		back:Play()
	end)
end

-- Nombre de dégâts qui monte et disparaît
local function damageNumber(position, damage, color, tierIndex)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.Transparency = 1
	part.Size = Vector3.new(0.2, 0.2, 0.2)
	part.CFrame = CFrame.new(position + Vector3.new(math.random(-15, 15) / 10, 1.5, math.random(-15, 15) / 10))
	part.Parent = workspace

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(120, 50)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Parent = part

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.Text = Util.FormatShort(damage)
	label.TextColor3 = color
	label.TextSize = 24 + tierIndex * 3
	label.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = Color3.new(0, 0, 0)
	stroke.Parent = label

	TweenService:Create(part, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = part.CFrame + Vector3.new(0, 3, 0) }):Play()
	TweenService:Create(label, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { TextTransparency = 1 }):Play()
	TweenService:Create(stroke, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Transparency = 1 }):Play()
	Debris:AddItem(part, 0.8)
end

-- Impact sur un slime : particules + lumière selon l'effet, + nombre de dégâts
function CombatVFX.PlayImpact(position, damage, effectId, tierIndex, isCompanion)
	tierIndex = tierIndex or 1
	local effect = EffectConfig.Get(effectId)
	local color = effect and effect.ImpactColor or Color3.fromRGB(255, 255, 255)
	if effect and effect.Rainbow then
		color = Color3.fromHSV(os.clock() % 1, 1, 1)
	end

	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.Transparency = 1
	part.Size = Vector3.new(0.5, 0.5, 0.5)
	part.CFrame = CFrame.new(position)
	part.Parent = workspace

	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(color)
	emitter.LightEmission = 1
	local size = (effect and effect.ParticleSize or 0.6) * (isCompanion and 0.6 or 1) * (0.8 + tierIndex * 0.12)
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size), NumberSequenceKeypoint.new(1, 0) })
	emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	emitter.Lifetime = NumberRange.new((effect and effect.ParticleLifetime or 0.4) * 0.7, effect and effect.ParticleLifetime or 0.4)
	emitter.Speed = NumberRange.new((effect and effect.ParticleSpeed or 8) * 0.6, effect and effect.ParticleSpeed or 8)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Rate = 0
	emitter.Enabled = false
	emitter.Parent = part
	emitter:Emit(math.min(30, (isCompanion and 5 or 8) + tierIndex * 3))

	if effect and effect.LightBrightness > 0 then
		local light = Instance.new("PointLight")
		light.Color = effect.LightColor
		light.Brightness = effect.LightBrightness
		light.Range = 8 + tierIndex
		light.Parent = part
		TweenService:Create(light, TweenInfo.new(0.25), { Brightness = 0 }):Play()
	end
	Debris:AddItem(part, 1.5)

	damageNumber(position, damage, isCompanion and Color3.fromRGB(255, 220, 120) or color, tierIndex)
end

-- Aperçu d'un effet (boutique) : applique la couleur 3 s, joue un coup et un impact devant soi
function CombatVFX.Preview(character, effectId)
	local trail = getTrail(character)
	local effect = EffectConfig.Get(effectId)
	if not trail or not effect then
		return
	end
	local previousColor = trail.Color
	trail.Color = effect.TrailColor
	local root = character:FindFirstChild("HumanoidRootPart")
	task.spawn(function()
		for i = 1, 3 do
			CombatVFX.PlaySwing(character, 0.45, 3, effectId)
			task.wait(0.25)
			if root then
				CombatVFX.PlayImpact(root.Position + root.CFrame.LookVector * 4, 0, effectId, 3, false)
			end
			task.wait(0.4)
		end
		task.wait(0.5)
		if trail.Parent then
			trail.Color = previousColor
		end
	end)
end

-- Intervalle d'attaque d'un palier (pour animer les autres joueurs)
function CombatVFX.GetTierInterval(tierIndex)
	local tier = CombatMath.Tiers[tierIndex] or CombatMath.Tiers[1]
	return tier.Interval
end

return CombatVFX
