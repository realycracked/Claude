--[[
	EggBuilder (ModuleScript)
	Emplacement : ReplicatedStorage > Shared > EggBuilder

	Construit un œuf en 3D à partir de blocs empilés (style géométrique de la photo).
	Les détails (taches, lumière, particules, aura) dépendent de la rareté.
	Utilisé pour les œufs du tapis ET pour les compagnons.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EggConfig = require(ReplicatedStorage.Config.EggConfig)
local IconConfig = require(ReplicatedStorage.Config.IconConfig)
local Util = require(ReplicatedStorage.Shared.Util)

local EggBuilder = {}

-- Largeur de chaque couche, du bas vers le haut (forme d'œuf)
local PROFILE = { 0.9, 1.5, 1.9, 2.15, 2.25, 2.2, 2.0, 1.6, 1.1 }
local LAYER_HEIGHT = 0.32

function EggBuilder.GetHeight(scale)
	return #PROFILE * LAYER_HEIGHT * (scale or 1)
end

local function newPart(name, size, color, material, parent)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = material
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

-- Construit le modèle. Le pivot (PrimaryPart "Hitbox") est au centre de l'œuf.
function EggBuilder.Build(rarityId, variantId, scale)
	scale = scale or 1
	local rarity = EggConfig.GetRarity(rarityId) or EggConfig.Rarities[1]
	local variant = EggConfig.GetVariant(variantId)

	local bodyColor = rarity.Color
	if variant.Tint then
		bodyColor = bodyColor:Lerp(variant.Tint, 0.6)
	end
	local material = variant.Material or rarity.Material

	local model = Instance.new("Model")
	model.Name = "Egg"

	local height = EggBuilder.GetHeight(scale)
	local hitbox = newPart("Hitbox", Vector3.new(2.3 * scale, height, 2.3 * scale), bodyColor, Enum.Material.SmoothPlastic, model)
	hitbox.Transparency = 1
	hitbox.CanQuery = true
	hitbox.CFrame = CFrame.new()
	model.PrimaryPart = hitbox

	-- Taches (motifs) : positions identiques pour une même rareté/variante
	local seed = rarity.Index * 100 + variant.Index
	local rng = Random.new(seed)
	local spotMaterial = rarity.Glow and Enum.Material.Neon or material

	if EggConfig.Style == "Blocks" then
		-- Style géométrique (comme la photo de référence) : couches de blocs empilés
		local layerCenters = {}
		local y = -height / 2
		for index, width in ipairs(PROFILE) do
			local layerColor = bodyColor
			if index % 2 == 0 then
				layerColor = bodyColor:Lerp(Color3.new(0, 0, 0), 0.07)
			end
			local layer = newPart("Layer" .. index, Vector3.new(width * scale, LAYER_HEIGHT * scale, width * scale), layerColor, material, model)
			local centerY = y + LAYER_HEIGHT * scale / 2
			layer.CFrame = CFrame.new(0, centerY, 0)
			layerCenters[index] = centerY
			y = y + LAYER_HEIGHT * scale
		end
		for _ = 1, rarity.Spots do
			local layerIndex = rng:NextInteger(2, #PROFILE - 1)
			local angle = rng:NextNumber(0, math.pi * 2)
			local radius = PROFILE[layerIndex] * scale / 2
			local spotSize = rng:NextNumber(0.25, 0.4) * scale
			local spot = newPart("Spot", Vector3.new(spotSize, spotSize, spotSize), rarity.SpotColor, spotMaterial, model)
			spot.CFrame = CFrame.new(math.cos(angle) * radius, layerCenters[layerIndex], math.sin(angle) * radius) * CFrame.Angles(0, -angle, 0)
		end
	else
		-- Style lisse : vrai œuf = sphère large en bas + ellipsoïde plus fin en haut
		local function shell(name, size, offsetY)
			local part = newPart(name, size, bodyColor, material, model)
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = Enum.MeshType.Sphere
			mesh.Parent = part
			part.CFrame = CFrame.new(0, offsetY, 0)
			return part
		end
		local lowerRadius = 1.15 * scale
		local lowerCenter = -height / 2 + lowerRadius
		local upperCenter = -height / 2 + 1.65 * scale
		shell("Shell", Vector3.new(2.3 * scale, 2.3 * scale, 2.3 * scale), lowerCenter)
		shell("ShellTop", Vector3.new(1.9 * scale, 2.4 * scale, 1.9 * scale), upperCenter)

		-- Reflet brillant
		local gloss = newPart("Gloss", Vector3.new(0.5 * scale, 0.8 * scale, 0.3 * scale), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, model)
		local glossMesh = Instance.new("SpecialMesh")
		glossMesh.MeshType = Enum.MeshType.Sphere
		glossMesh.Parent = gloss
		gloss.Transparency = 0.45
		gloss.CFrame = CFrame.new(-0.55 * scale, upperCenter + 0.55 * scale, -0.7 * scale) * CFrame.Angles(0, math.rad(40), math.rad(20))

		-- Taches posées sur la coquille (petites boules)
		for _ = 1, rarity.Spots do
			local angle = rng:NextNumber(0, math.pi * 2)
			local spotSize = rng:NextNumber(0.28, 0.42) * scale
			local spot = newPart("Spot", Vector3.new(spotSize, spotSize, spotSize), rarity.SpotColor, spotMaterial, model)
			spot.Shape = Enum.PartType.Ball
			if rng:NextNumber() < 0.6 then
				local elevation = rng:NextNumber(-0.5, 0.6)
				local r = lowerRadius * 0.97
				spot.CFrame = CFrame.new(math.cos(elevation) * math.cos(angle) * r, lowerCenter + math.sin(elevation) * r, math.cos(elevation) * math.sin(angle) * r)
			else
				local elevation = rng:NextNumber(0.1, 1.0)
				spot.CFrame = CFrame.new(math.cos(elevation) * math.cos(angle) * 0.92 * scale, upperCenter + math.sin(elevation) * 1.17 * scale, math.cos(elevation) * math.sin(angle) * 0.92 * scale)
			end
		end
	end

	-- Lumière
	if rarity.Glow then
		local light = Instance.new("PointLight")
		light.Color = rarity.SpotColor
		light.Range = 8 * scale
		light.Brightness = 1.5
		light.Parent = hitbox
	end

	-- Particules scintillantes
	if rarity.Sparkles or variant.Sparkles then
		local emitter = Instance.new("ParticleEmitter")
		emitter.Name = "Sparkles"
		emitter.Color = ColorSequence.new(variant.Tint or rarity.SpotColor)
		emitter.LightEmission = 1
		emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25 * scale), NumberSequenceKeypoint.new(1, 0) })
		emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
		emitter.Lifetime = NumberRange.new(0.8, 1.4)
		emitter.Rate = 8
		emitter.Speed = NumberRange.new(1, 2)
		emitter.SpreadAngle = Vector2.new(180, 180)
		emitter.Parent = hitbox
	end

	-- Aura (sphère lumineuse translucide)
	if rarity.Aura then
		local aura = newPart("Aura", Vector3.new(3.2 * scale, 3.2 * scale, 3.2 * scale), rarity.SpotColor, Enum.Material.Neon, model)
		aura.Shape = Enum.PartType.Ball
		aura.Transparency = 0.8
		aura.CFrame = CFrame.new()
	end

	model:SetAttribute("Rarity", rarity.Id)
	model:SetAttribute("Variant", variant.Id)
	return model
end

-- Étiquette au-dessus d'un œuf du tapis : nom, rareté, prix
function EggBuilder.AddLabel(model, rarityId, variantId, price)
	local rarity = EggConfig.GetRarity(rarityId)
	local variant = EggConfig.GetVariant(variantId)
	local hitbox = model.PrimaryPart
	if not rarity or not hitbox then
		return
	end

	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Adornee = hitbox
	gui.Size = UDim2.fromOffset(220, 100)
	gui.StudsOffsetWorldSpace = Vector3.new(0, hitbox.Size.Y / 2 + 2.2, 0)
	gui.MaxDistance = 90
	gui.LightInfluence = 0
	gui.AlwaysOnTop = false

	local function makeText(text, color, size, position)
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.new(1, 0, 0, size)
		label.Position = position
		label.Font = Enum.Font.FredokaOne
		label.Text = text
		label.TextColor3 = color
		label.TextSize = size
		label.TextScaled = false
		label.Parent = gui
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 2
		stroke.Color = Color3.new(0, 0, 0)
		stroke.Parent = label
		return label
	end

	makeText(EggConfig.GetDisplayName(rarityId, variantId), variant.LabelColor, 26, UDim2.fromOffset(0, 0))
	makeText(rarity.Name, rarity.Id == "Mythic" and rarity.SpotColor or rarity.Color, 20, UDim2.fromOffset(0, 28))

	-- Prix : icône billet + nombre vert
	local priceRow = Instance.new("Frame")
	priceRow.BackgroundTransparency = 1
	priceRow.Size = UDim2.new(1, 0, 0, 34)
	priceRow.Position = UDim2.fromOffset(0, 54)
	priceRow.Parent = gui

	local priceText = Util.FormatNumber(price)
	local textWidth = #priceText * 16 + 10
	local totalWidth = 34 + 6 + textWidth

	if IconConfig.HasImage("Cash") then
		local image = Instance.new("ImageLabel")
		image.BackgroundTransparency = 1
		image.Image = IconConfig.GetImage("Cash")
		image.ScaleType = Enum.ScaleType.Fit
		image.Size = UDim2.fromOffset(34, 34)
		image.Position = UDim2.new(0.5, -totalWidth / 2, 0.5, -17)
		image.Parent = priceRow
	else
		local icon = Instance.new("Frame")
		icon.Size = UDim2.fromOffset(34, 22)
		icon.Position = UDim2.new(0.5, -totalWidth / 2, 0.5, -11)
		icon.BackgroundColor3 = Color3.fromRGB(70, 200, 70)
		icon.BorderSizePixel = 0
		icon.Parent = priceRow
		local iconCorner = Instance.new("UICorner")
		iconCorner.CornerRadius = UDim.new(0, 5)
		iconCorner.Parent = icon
		local iconStroke = Instance.new("UIStroke")
		iconStroke.Thickness = 2
		iconStroke.Color = Color3.fromRGB(20, 80, 20)
		iconStroke.Parent = icon
		local dollar = Instance.new("TextLabel")
		dollar.BackgroundTransparency = 1
		dollar.Size = UDim2.fromScale(1, 1)
		dollar.Font = Enum.Font.FredokaOne
		dollar.Text = "$"
		dollar.TextColor3 = Color3.new(1, 1, 1)
		dollar.TextSize = 18
		dollar.Parent = icon
	end

	local priceLabel = Instance.new("TextLabel")
	priceLabel.BackgroundTransparency = 1
	priceLabel.Size = UDim2.fromOffset(textWidth, 34)
	priceLabel.Position = UDim2.new(0.5, -totalWidth / 2 + 40, 0, 0)
	priceLabel.Font = Enum.Font.FredokaOne
	priceLabel.Text = priceText
	priceLabel.TextColor3 = Color3.fromRGB(90, 230, 90)
	priceLabel.TextSize = 30
	priceLabel.TextXAlignment = Enum.TextXAlignment.Left
	priceLabel.Parent = priceRow
	local priceStroke = Instance.new("UIStroke")
	priceStroke.Thickness = 2.5
	priceStroke.Color = Color3.new(0, 0, 0)
	priceStroke.Parent = priceLabel

	gui.Parent = hitbox
	return gui
end

return EggBuilder
