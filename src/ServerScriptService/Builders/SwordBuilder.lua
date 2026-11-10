--[[
	SwordBuilder (ModuleScript)
	Emplacement : ServerScriptService > Builders > SwordBuilder

	Construit l'épée (modèle "Sword" dans le personnage) et la soude à la main droite.
	L'épée est toujours tenue : pas de Tool ni de barre d'outils à gérer.
	La traînée (Trail) est créée ici ; sa couleur dépend de l'effet équipé.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SwordConfig = require(ReplicatedStorage.Config.SwordConfig)
local EffectConfig = require(ReplicatedStorage.Config.EffectConfig)

local SwordBuilder = {}

local function newPart(name, size, color, material, parent)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = material
	part.Anchored = false
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function getHand(character)
	return character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
end

function SwordBuilder.Attach(character, swordId, effectId)
	local def = SwordConfig.Get(swordId) or SwordConfig.Get(SwordConfig.DefaultSword)
	local hand = getHand(character)
	if not hand then
		return nil
	end

	local old = character:FindFirstChild("Sword")
	if old then
		old:Destroy()
	end

	local style = def.Style
	local model = Instance.new("Model")
	model.Name = "Sword"

	-- Point de prise : la lame pointe vers l'avant de la main
	local gripOffset
	if hand.Name == "RightHand" then
		gripOffset = CFrame.new(0, -0.15, 0)
	else
		gripOffset = CFrame.new(0, -1, 0) -- R6
	end
	gripOffset = gripOffset * CFrame.Angles(-math.pi / 2, 0, 0)
	local handleCFrame = hand.CFrame * gripOffset

	local handle = newPart("Handle", Vector3.new(0.3, 1.1, 0.3), style.GripColor, Enum.Material.SmoothPlastic, model)
	handle.CFrame = handleCFrame

	local pommel = newPart("Pommel", Vector3.new(0.45, 0.3, 0.45), style.GuardColor, Enum.Material.Metal, model)
	pommel.CFrame = handleCFrame * CFrame.new(0, -0.7, 0)

	local guard = newPart("Guard", Vector3.new(1.3, 0.22, 0.42), style.GuardColor, Enum.Material.Metal, model)
	guard.CFrame = handleCFrame * CFrame.new(0, 0.65, 0)

	local blade = newPart("Blade", Vector3.new(0.18, style.Length, 0.6), style.BladeColor, style.Material, model)
	blade.CFrame = handleCFrame * CFrame.new(0, 0.76 + style.Length / 2, 0)

	local tip = Instance.new("WedgePart")
	tip.Name = "Tip"
	tip.Size = Vector3.new(0.18, 0.6, 0.6)
	tip.Color = style.BladeColor
	tip.Material = style.Material
	tip.Anchored = false
	tip.CanCollide = false
	tip.CanQuery = false
	tip.CanTouch = false
	tip.Massless = true
	tip.CastShadow = false
	-- Pointe biseautée posée sur le haut de la lame
	tip.CFrame = handleCFrame * CFrame.new(0, 0.76 + style.Length + 0.3, 0)
	tip.Parent = model

	-- Traînée lumineuse (activée pendant les coups par le client)
	local top = Instance.new("Attachment")
	top.Name = "TrailTop"
	top.Position = Vector3.new(0, style.Length / 2 + 0.5, 0)
	top.Parent = blade
	local bottom = Instance.new("Attachment")
	bottom.Name = "TrailBottom"
	bottom.Position = Vector3.new(0, -style.Length / 2 + 0.2, 0)
	bottom.Parent = blade

	local trail = Instance.new("Trail")
	trail.Name = "Trail"
	trail.Attachment0 = top
	trail.Attachment1 = bottom
	trail.Enabled = false
	trail.Lifetime = 0.2
	trail.MinLength = 0
	trail.FaceCamera = true
	trail.LightEmission = 0.8
	trail.LightInfluence = 0
	trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	trail.WidthScale = NumberSequence.new(1)
	trail.Parent = blade

	if style.Glow then
		local light = Instance.new("PointLight")
		light.Color = style.Glow
		light.Range = 7
		light.Brightness = 1.2
		light.Parent = blade
	end

	-- Soudures : tout est attaché au manche, le manche est attaché à la main
	for _, part in ipairs(model:GetChildren()) do
		if part ~= handle and part:IsA("BasePart") then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = handle
			weld.Part1 = part
			weld.Parent = part
		end
	end
	local grip = Instance.new("Weld")
	grip.Name = "Grip"
	grip.Part0 = hand
	grip.Part1 = handle
	grip.C0 = gripOffset
	grip.Parent = handle

	model.PrimaryPart = handle
	model:SetAttribute("SwordId", def.Id)
	model.Parent = character

	SwordBuilder.ApplyEffect(character, effectId)
	return model
end

-- Applique la couleur de traînée de l'effet équipé (ou blanc par défaut)
function SwordBuilder.ApplyEffect(character, effectId)
	local sword = character:FindFirstChild("Sword")
	local blade = sword and sword:FindFirstChild("Blade")
	local trail = blade and blade:FindFirstChild("Trail")
	if not trail then
		return
	end
	local effect = EffectConfig.Get(effectId)
	if effect then
		trail.Color = effect.TrailColor
		trail.LightEmission = 1
	else
		trail.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255))
		trail.LightEmission = 0.6
	end
	sword:SetAttribute("Effect", effect and effect.Id or "")
end

return SwordBuilder
