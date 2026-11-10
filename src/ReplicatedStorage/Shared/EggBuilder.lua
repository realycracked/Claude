--[[
	EggBuilder (ModuleScript)
	Emplacement : ReplicatedStorage > Shared > EggBuilder

	Construit un œuf en 3D. Deux styles (EggConfig.Style) :
	- "Smooth" : œuf lisse et arrondi avec reflet (par défaut)
	- "Blocks" : couches de blocs empilés (style de la photo de référence)
	Détails selon la rareté : taches, lumière, particules, aura, et ornements
	(pousse, éclats de cristal, anneaux, fissures lumineuses, éclats en orbite).

	Mesh externe (facultatif) : si ReplicatedStorage > Assets > EggMeshes contient un
	MeshPart ou un Model nommé comme la rareté ("Common", "Rare", ...), il est utilisé
	à la place de la coquille générée (voir docs/05-assets-externes.md).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EggConfig = require(ReplicatedStorage.Config.EggConfig)
local IconConfig = require(ReplicatedStorage.Config.IconConfig)
local Util = require(ReplicatedStorage.Shared.Util)

local EggBuilder = {}

-- Style "Blocks" : largeur de chaque couche, du bas vers le haut
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

local function sphereMesh(part)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = part
	return mesh
end

-- Mesh fourni par l'utilisateur (ReplicatedStorage.Assets.EggMeshes.<Rarity>)
local function externalMesh(rarityId)
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local meshes = assets and assets:FindFirstChild("EggMeshes")
	return meshes and meshes:FindFirstChild(rarityId) or nil
end

function EggBuilder.Build(rarityId, variantId, scale)
	scale = scale or 1
	local rarity = EggConfig.GetRarity(rarityId) or EggConfig.Rarities[1]
	local variant = EggConfig.GetVariant(variantId)
	local ornaments = EggConfig.GetOrnaments(rarity.Id)

	local bodyColor = rarity.Color
	if variant.Tint then
		bodyColor = bodyColor:Lerp(variant.Tint, 0.6)
	end
	local material = variant.Material or rarity.Material
	local spotMaterial = rarity.Glow and Enum.Material.Neon or material

	local model = Instance.new("Model")
	model.Name = "Egg"

	local height = EggBuilder.GetHeight(scale)
	local hitbox = newPart("Hitbox", Vector3.new(2.3 * scale, height, 2.3 * scale), bodyColor, Enum.Material.SmoothPlastic, model)
	hitbox.Transparency = 1
	hitbox.CanQuery = true
	hitbox.CFrame = CFrame.new()
	model.PrimaryPart = hitbox

	-- Géométrie de référence de la coquille (sphère basse + ellipsoïde haut)
	local lowerRadius = 1.15 * scale
	local lowerCenter = -height / 2 + lowerRadius
	local upperCenter = -height / 2 + 1.65 * scale

	-- Point sur la coquille basse (angle autour, élévation en radians)
	local function lowerSurface(angle, elevation, factor)
		local r = lowerRadius * (factor or 1)
		return Vector3.new(math.cos(elevation) * math.cos(angle) * r, lowerCenter + math.sin(elevation) * r, math.cos(elevation) * math.sin(angle) * r)
	end

	local seed = rarity.Index * 100 + variant.Index
	local rng = Random.new(seed)

	local external = externalMesh(rarity.Id)
	if external then
		-- Coquille fournie par l'utilisateur, mise à l'échelle sur la hauteur de l'œuf
		local shell = external:Clone()
		shell.Name = "Shell"
		if shell:IsA("BasePart") then
			local factor = height / math.max(shell.Size.Y, 0.01)
			shell.Size = shell.Size * factor
			shell.Anchored = true
			shell.CanCollide = false
			shell.CanQuery = false
			if not shell:GetAttribute("KeepColor") then
				shell.Color = bodyColor
			end
			shell.CFrame = CFrame.new()
		elseif shell:IsA("Model") then
			local _, modelSize = shell:GetBoundingBox()
			local factor = height / math.max(modelSize.Y, 0.01)
			shell:ScaleTo(factor)
			for _, part in ipairs(shell:GetDescendants()) do
				if part:IsA("BasePart") then
					part.Anchored = true
					part.CanCollide = false
					if not shell:GetAttribute("KeepColor") then
						part.Color = bodyColor
					end
				end
			end
			shell:PivotTo(CFrame.new())
		end
		shell.Parent = model
	elseif EggConfig.Style == "Blocks" then
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
	elseif EggConfig.Style == "Faceted" then
		-- Style facetté : couches de blocs tournées alternativement de 45° (silhouette octogonale, effet gemme)
		local y = -height / 2
		for index, width in ipairs(PROFILE) do
			local w = width * 0.95 * scale
			local layerColor = index % 2 == 0 and bodyColor:Lerp(Color3.new(1, 1, 1), 0.08) or bodyColor
			local layer = newPart("Layer" .. index, Vector3.new(w, LAYER_HEIGHT * scale * 1.15, w), layerColor, material, model)
			layer.CFrame = CFrame.new(0, y + LAYER_HEIGHT * scale / 2, 0) * CFrame.Angles(0, (index % 2) * math.rad(45), 0)
			y = y + LAYER_HEIGHT * scale
		end
		for _ = 1, rarity.Spots do
			local spotSize = rng:NextNumber(0.22, 0.32) * scale
			local spot = newPart("Spot", Vector3.new(spotSize, spotSize, spotSize), rarity.SpotColor, spotMaterial, model)
			spot.CFrame = CFrame.new(lowerSurface(rng:NextNumber(0, math.pi * 2), rng:NextNumber(-0.4, 0.8), 0.92)) * CFrame.Angles(rng:NextNumber(0, 1), rng:NextNumber(0, 1), 0)
		end
	else
		-- Style lisse ("Smooth") ou deux tons ("TwoTone")
		local topColor = bodyColor
		if EggConfig.Style == "TwoTone" then
			topColor = bodyColor:Lerp(rarity.SpotColor, 0.55)
		end
		local lower = newPart("Shell", Vector3.new(2.3 * scale, 2.3 * scale, 2.3 * scale), bodyColor, material, model)
		sphereMesh(lower)
		lower.CFrame = CFrame.new(0, lowerCenter, 0)
		local upper = newPart("ShellTop", Vector3.new(1.9 * scale, 2.4 * scale, 1.9 * scale), topColor, material, model)
		sphereMesh(upper)
		upper.CFrame = CFrame.new(0, upperCenter, 0)
		if EggConfig.Style == "TwoTone" then
			-- Jonction : anneau métallique sombre entre les deux tons
			local seamY = upperCenter - 0.2 * scale
			local seam = newPart("Seam", Vector3.new(0.12 * scale, 2.1 * scale, 2.1 * scale), Color3.fromRGB(60, 60, 70), Enum.Material.Metal, model)
			seam.Shape = Enum.PartType.Cylinder
			seam.CFrame = CFrame.new(0, seamY, 0) * CFrame.Angles(0, 0, math.rad(90))
		end

		local gloss = newPart("Gloss", Vector3.new(0.5 * scale, 0.8 * scale, 0.3 * scale), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, model)
		sphereMesh(gloss)
		gloss.Transparency = 0.45
		gloss.CFrame = CFrame.new(-0.55 * scale, upperCenter + 0.55 * scale, -0.7 * scale) * CFrame.Angles(0, math.rad(40), math.rad(20))

		for _ = 1, rarity.Spots do
			local angle = rng:NextNumber(0, math.pi * 2)
			local spotSize = rng:NextNumber(0.28, 0.42) * scale
			local spot = newPart("Spot", Vector3.new(spotSize, spotSize, spotSize), rarity.SpotColor, spotMaterial, model)
			spot.Shape = Enum.PartType.Ball
			if rng:NextNumber() < 0.6 then
				spot.CFrame = CFrame.new(lowerSurface(angle, rng:NextNumber(-0.5, 0.6), 0.97))
			else
				local elevation = rng:NextNumber(0.1, 1.0)
				spot.CFrame = CFrame.new(math.cos(elevation) * math.cos(angle) * 0.92 * scale, upperCenter + math.sin(elevation) * 1.17 * scale, math.cos(elevation) * math.sin(angle) * 0.92 * scale)
			end
		end
	end

	---------------------------------------------------------------------
	-- Ornements
	---------------------------------------------------------------------
	-- Pousse sur le dessus
	if ornaments.Leaf then
		local stem = newPart("Stem", Vector3.new(0.08 * scale, 0.35 * scale, 0.08 * scale), Color3.fromRGB(60, 150, 60), Enum.Material.SmoothPlastic, model)
		stem.CFrame = CFrame.new(0, height / 2 + 0.12 * scale, 0)
		for _, side in ipairs({ -1, 1 }) do
			local leaf = newPart("Leaf", Vector3.new(0.5 * scale, 0.1 * scale, 0.24 * scale), Color3.fromRGB(90, 200, 90), Enum.Material.SmoothPlastic, model)
			sphereMesh(leaf)
			leaf.CFrame = CFrame.new(side * 0.24 * scale, height / 2 + 0.3 * scale, 0) * CFrame.Angles(0, 0, side * math.rad(25))
		end
	end

	-- Éclats de cristal plantés dans la coquille basse
	for i = 1, ornaments.Shards or 0 do
		local angle = i * (math.pi * 2 / (ornaments.Shards or 1)) + 0.5
		local base = lowerSurface(angle, rng:NextNumber(-0.2, 0.5), 0.9)
		local direction = (base - Vector3.new(0, lowerCenter, 0)).Unit
		local length = rng:NextNumber(0.5, 0.8) * scale
		local shard = newPart("Shard", Vector3.new(0.16 * scale, length, 0.16 * scale), ornaments.ShardColor or rarity.SpotColor, Enum.Material.Neon, model)
		shard.CFrame = CFrame.lookAt(base + direction * length / 2, base + direction * length) * CFrame.Angles(-math.pi / 2, 0, 0) * CFrame.Angles(0, math.rad(45), 0)
	end

	-- Anneaux métalliques (disques fins qui dépassent de la coquille)
	for i = 1, ornaments.Bands or 0 do
		local bandY = (i == 1) and (lowerCenter - 0.15 * scale) or (upperCenter + 0.25 * scale)
		local dy = bandY - lowerCenter
		local shellRadius = (i == 1) and math.sqrt(math.max(lowerRadius ^ 2 - dy ^ 2, 0.1)) or (0.85 * scale)
		local diameter = shellRadius * 2 + 0.16 * scale
		local band = newPart("Band", Vector3.new(0.1 * scale, diameter, diameter), ornaments.BandColor or Color3.fromRGB(255, 215, 60), Enum.Material.Metal, model)
		band.Shape = Enum.PartType.Cylinder
		band.CFrame = CFrame.new(0, bandY, 0) * CFrame.Angles(0, 0, math.rad(90))
	end

	-- Fissures lumineuses sur la coquille
	for _ = 1, ornaments.Cracks or 0 do
		local point = lowerSurface(rng:NextNumber(0, math.pi * 2), rng:NextNumber(-0.4, 0.7), 1.0)
		local normal = (point - Vector3.new(0, lowerCenter, 0)).Unit
		local crack = newPart("Crack", Vector3.new(0.06 * scale, 0.4 * scale, 0.03 * scale), ornaments.CrackColor or rarity.SpotColor, Enum.Material.Neon, model)
		crack.CFrame = CFrame.lookAt(point, point + normal) * CFrame.Angles(0, 0, rng:NextNumber(0, math.pi))
	end

	-- Éclats en orbite (position mise à jour par EggAnimator côté client)
	for i = 1, ornaments.Orbit or 0 do
		local phase = i * (math.pi * 2 / (ornaments.Orbit or 1))
		local orbit = newPart("Orbit", Vector3.new(0.28 * scale, 0.28 * scale, 0.28 * scale), ornaments.OrbitColor or rarity.SpotColor, Enum.Material.Neon, model)
		orbit:SetAttribute("Radius", 1.75 * scale)
		orbit:SetAttribute("Height", rng:NextNumber(-0.4, 0.5) * scale)
		orbit:SetAttribute("Phase", phase)
		orbit:SetAttribute("Speed", 1.6)
		orbit.CFrame = CFrame.Angles(0, phase, 0) * CFrame.new(1.75 * scale, 0, 0) * CFrame.Angles(math.rad(45), math.rad(45), 0)
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

	-- Aura
	if rarity.Aura then
		local aura = newPart("Aura", Vector3.new(3.2 * scale, 3.6 * scale, 3.2 * scale), rarity.SpotColor, Enum.Material.Neon, model)
		sphereMesh(aura)
		aura.Transparency = 0.82
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
