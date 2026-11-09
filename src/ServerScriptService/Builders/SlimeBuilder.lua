--[[
	SlimeBuilder (ModuleScript)
	Emplacement : ServerScriptService > Builders > SlimeBuilder

	Construit le modèle 3D d'un slime d'après sa catégorie (SlimeConfig) et son apparence
	(SlimeConfig.Looks) : corps gélatineux, yeux, sourcils, cristaux, cornes, pointes,
	fissures lumineuses, armure, couronne, particules, lumière, aura, barre de vie.

	Les animations (respiration, clignement, coup reçu, mort) sont jouées par chaque
	client dans SlimeAnimator : le serveur ne touche qu'aux attributs et à la position.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SlimeConfig = require(ReplicatedStorage.Config.SlimeConfig)
local Util = require(ReplicatedStorage.Shared.Util)

local SlimeBuilder = {}

local function newPart(name, size, color, parent)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

function SlimeBuilder.GetBodySize(def)
	return Vector3.new(def.Size, def.Size * 0.75, def.Size)
end

-- Particules par type
local PARTICLE_PRESETS = {
	Frost = { Colors = { Color3.fromRGB(190, 235, 255), Color3.fromRGB(255, 255, 255) }, Size = 0.12, Speed = NumberRange.new(0.5, 1.5), Lifetime = NumberRange.new(1, 2), Rate = 2, Transparency = 0.2, LightEmission = 0.8, Spread = 180, Acceleration = Vector3.new(0, 0.5, 0) },
	Shadow = { Colors = { Color3.fromRGB(90, 0, 130), Color3.fromRGB(20, 0, 30) }, Size = 0.3, Speed = NumberRange.new(0.5, 1.2), Lifetime = NumberRange.new(1, 1.8), Rate = 2.5, Transparency = 0.4, LightEmission = 0, Spread = 180, Acceleration = Vector3.new(0, 0.8, 0) },
	Fire = { Colors = { Color3.fromRGB(255, 210, 70), Color3.fromRGB(255, 60, 0) }, Size = 0.22, Speed = NumberRange.new(2, 4), Lifetime = NumberRange.new(0.5, 0.9), Rate = 4, Transparency = 0.1, LightEmission = 1, Spread = 35, Acceleration = Vector3.new(0, 3, 0) },
	Embers = { Colors = { Color3.fromRGB(255, 130, 60), Color3.fromRGB(255, 40, 40) }, Size = 0.08, Speed = NumberRange.new(3, 6), Lifetime = NumberRange.new(0.8, 1.4), Rate = 5, Transparency = 0, LightEmission = 1, Spread = 60, Acceleration = Vector3.new(0, 2, 0) },
}

function SlimeBuilder.Build(def)
	local size = def.Size
	local look = SlimeConfig.GetLook(def.Id)
	local model = Instance.new("Model")
	model.Name = def.Name

	-- Corps gélatineux : enveloppe translucide + cœur plus foncé
	local body = newPart("Body", SlimeBuilder.GetBodySize(def), def.Color, model)
	body.CanQuery = true
	body.Transparency = 0.22
	body.Reflectance = 0.04
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = body
	body:SetAttribute("BaseSize", body.Size)
	model.PrimaryPart = body

	local radiusX, radiusY = size / 2, size * 0.375

	-- Point sur la surface du corps (angle autour, élévation en radians)
	local function surface(angle, elevation, factor)
		factor = factor or 1
		return Vector3.new(math.cos(elevation) * math.cos(angle) * radiusX, math.sin(elevation) * radiusY, math.cos(elevation) * math.sin(angle) * radiusX) * factor
	end

	local function ellipsoid(name, partSize, color, offset)
		local part = newPart(name, partSize, color, model)
		part.CFrame = body.CFrame * CFrame.new(offset)
		local partMesh = Instance.new("SpecialMesh")
		partMesh.MeshType = Enum.MeshType.Sphere
		partMesh.Parent = part
		return part
	end

	-- Bloc allongé planté sur le corps, pointant dans une direction (cristaux, cornes, pointes)
	local function shard(name, base, direction, length, width, color, material)
		local dir = direction.Unit
		local part = newPart(name, Vector3.new(width, length, width), color, model)
		part.Material = material or Enum.Material.SmoothPlastic
		part.CFrame = body.CFrame * (CFrame.lookAt(base + dir * length / 2, base + dir * length) * CFrame.Angles(-math.pi / 2, 0, 0))
		return part
	end

	-- Plaque posée à plat sur la surface (fissures, armure)
	local function plate(name, point, partSize, color, material, spin)
		local part = newPart(name, partSize, color, model)
		part.Material = material or Enum.Material.SmoothPlastic
		part.CFrame = body.CFrame * (CFrame.lookAt(point, point * 2) * CFrame.Angles(0, 0, spin or 0))
		return part
	end

	local rng = Random.new(def.Index * 31)

	-- Cœur et reflet
	local core = ellipsoid("Core", SlimeBuilder.GetBodySize(def) * 0.6, def.Color:Lerp(Color3.new(0, 0, 0), 0.35), Vector3.new(0, -size * 0.04, 0))
	core.Transparency = 0.05
	local highlight = ellipsoid("Highlight", Vector3.new(size * 0.2, size * 0.08, size * 0.14), Color3.new(1, 1, 1), Vector3.new(-size * 0.2, size * 0.24, -size * 0.3))
	highlight.Transparency = 0.3
	highlight.CFrame = highlight.CFrame * CFrame.Angles(math.rad(-30), math.rad(20), math.rad(-25))

	-- Yeux
	local function eye(x, y, z, scale)
		local sclera = ellipsoid("Eye", Vector3.new(size * 0.2, size * 0.24, size * 0.2) * scale, Color3.new(1, 1, 1), Vector3.new(x, y, z))
		local pupil = newPart("Pupil", Vector3.new(size * 0.11, size * 0.11, size * 0.11) * scale, def.EyeColor, model)
		pupil.Shape = Enum.PartType.Ball
		if look.EyeGlow then
			pupil.Material = Enum.Material.Neon
		end
		pupil.CFrame = sclera.CFrame * CFrame.new(0, -size * 0.01 * scale, -size * 0.07 * scale)
		local shine = newPart("Shine", Vector3.new(size * 0.045, size * 0.045, size * 0.045) * scale, Color3.new(1, 1, 1), model)
		shine.Shape = Enum.PartType.Ball
		shine.CFrame = pupil.CFrame * CFrame.new(size * 0.03 * scale, size * 0.035 * scale, -size * 0.04 * scale)
	end
	local eyeCount = look.Eyes or 2
	for _, side in ipairs({ -1, 1 }) do
		eye(side * size * 0.18, size * 0.14, -size * 0.4, 1)
	end
	if eyeCount >= 3 then
		eye(0, size * 0.3, -size * 0.33, 0.7)
	end
	if eyeCount >= 4 then
		for _, side in ipairs({ -1, 1 }) do
			eye(side * size * 0.33, size * 0.27, -size * 0.3, 0.65)
		end
	end

	-- Sourcils en colère
	if look.Brows then
		for _, side in ipairs({ -1, 1 }) do
			local brow = newPart("Brow", Vector3.new(size * 0.2, size * 0.045, size * 0.04), Color3.fromRGB(30, 15, 25), model)
			brow.CFrame = body.CFrame * CFrame.new(side * size * 0.18, size * 0.3, -size * 0.41) * CFrame.Angles(0, 0, side * math.rad(25))
		end
	end

	-- Bouche
	local mouth = newPart("Mouth", Vector3.new(size * 0.2, size * 0.04, size * 0.05), Color3.fromRGB(60, 20, 35), model)
	mouth.CFrame = body.CFrame * CFrame.new(0, -size * 0.03, -size * 0.49)
	if look.Brows then
		-- Bouche en colère : deux crocs
		for _, side in ipairs({ -1, 1 }) do
			local fang = newPart("Fang", Vector3.new(size * 0.035, size * 0.06, size * 0.03), Color3.new(1, 1, 1), model)
			fang.CFrame = body.CFrame * CFrame.new(side * size * 0.06, -size * 0.07, -size * 0.49)
		end
	end

	-- Joues roses
	if look.Blush then
		for _, side in ipairs({ -1, 1 }) do
			local blush = ellipsoid("Blush", Vector3.new(size * 0.14, size * 0.07, size * 0.06), Color3.fromRGB(255, 150, 170), Vector3.new(side * size * 0.32, 0, -size * 0.36))
			blush.Transparency = 0.3
		end
	end

	-- Pousse sur la tête
	if look.Leaf then
		local stem = newPart("Stem", Vector3.new(size * 0.05, size * 0.2, size * 0.05), Color3.fromRGB(60, 150, 60), model)
		stem.CFrame = body.CFrame * CFrame.new(0, size * 0.44, 0)
		for _, side in ipairs({ -1, 1 }) do
			local leaf = ellipsoid("Leaf", Vector3.new(size * 0.3, size * 0.06, size * 0.14), Color3.fromRGB(90, 200, 90), Vector3.new(side * size * 0.14, size * 0.53, 0))
			leaf.CFrame = leaf.CFrame * CFrame.Angles(0, 0, side * math.rad(20))
		end
	end

	-- Taches
	for _ = 1, look.Spots or 0 do
		local point = surface(rng:NextNumber(0, math.pi * 2), rng:NextNumber(-0.2, 0.7), 0.97)
		local spot = newPart("Spot", Vector3.new(size * 0.14, size * 0.14, size * 0.14), def.Color:Lerp(Color3.new(0, 0, 0), 0.25), model)
		spot.Shape = Enum.PartType.Ball
		spot.CFrame = body.CFrame * CFrame.new(point)
	end

	-- Cristaux de glace
	for i = 1, look.Crystals or 0 do
		local angle = i * (math.pi * 2 / (look.Crystals or 1)) + 0.3
		local base = surface(angle, rng:NextNumber(0.35, 0.75), 0.9)
		shard("Crystal", base, base + Vector3.new(0, size * 0.2, 0), rng:NextNumber(0.3, 0.5) * size, size * 0.1, look.CrystalColor or Color3.fromRGB(185, 235, 255), Enum.Material.Neon)
	end
	if (look.Crystals or 0) > 0 then
		shard("Crystal", Vector3.new(0, radiusY * 0.9, 0), Vector3.new(0.1, 1, 0), size * 0.55, size * 0.14, look.CrystalColor or Color3.fromRGB(185, 235, 255), Enum.Material.Neon)
	end

	-- Cornes
	if look.Horns then
		for _, side in ipairs({ -1, 1 }) do
			local base = Vector3.new(side * size * 0.2, size * 0.32, -size * 0.05)
			local dir = Vector3.new(side * 0.45, 1, -0.15)
			shard("Horn", base, dir, size * 0.38, size * 0.13, Color3.fromRGB(35, 15, 45))
			shard("Horn", base + dir.Unit * size * 0.34, dir + Vector3.new(side * 0.3, 0, 0), size * 0.2, size * 0.07, Color3.fromRGB(35, 15, 45))
		end
	end

	-- Pointes
	for i = 1, look.Spikes or 0 do
		local angle = i * (math.pi * 2 / (look.Spikes or 1))
		if math.abs(math.sin(angle)) > 0.35 or math.cos(angle) < 0 then -- pas devant les yeux
			local base = surface(angle, rng:NextNumber(0.05, 0.4), 0.92)
			shard("Spike", base, base + Vector3.new(0, size * 0.15, 0), size * 0.3, size * 0.1, Color3.fromRGB(45, 20, 25))
		end
	end

	-- Fissures lumineuses
	for _ = 1, look.Cracks or 0 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local point = surface(angle, rng:NextNumber(-0.3, 0.6), 0.995)
		if math.abs(math.sin(angle)) > 0.3 or math.cos(angle) < 0 then
			plate("Crack", point, Vector3.new(size * 0.05, size * 0.28, size * 0.02), look.CrackColor or Color3.fromRGB(255, 120, 20), Enum.Material.Neon, rng:NextNumber(0, math.pi))
		end
	end

	-- Armure dorée
	if look.Armor then
		for i = 1, 4 do
			local angle = math.rad(45 + (i - 1) * 90)
			local point = surface(angle, 0.15, 1.0)
			plate("Armor", point, Vector3.new(size * 0.34, size * 0.26, size * 0.06), Color3.fromRGB(230, 180, 50), Enum.Material.Metal, 0)
			local rivet = newPart("Rivet", Vector3.new(size * 0.05, size * 0.05, size * 0.05), Color3.fromRGB(120, 80, 20), model)
			rivet.Shape = Enum.PartType.Ball
			rivet.CFrame = body.CFrame * CFrame.new(surface(angle, 0.15, 1.03))
		end
	end

	-- Gouttes
	for i = 1, 3 do
		local angle = i * (math.pi * 2 / 3) + 0.4
		local drop = ellipsoid("Drop", Vector3.new(size * 0.16, size * 0.12, size * 0.16), def.Color, Vector3.new(math.cos(angle) * size * 0.42, -size * 0.3, math.sin(angle) * size * 0.42))
		drop.Transparency = 0.2
	end

	-- Couronne
	if look.Crown then
		local crownY = radiusY + size * 0.02
		local base = newPart("Crown", Vector3.new(size * 0.06, size * 0.42, size * 0.42), Color3.fromRGB(255, 200, 40), model)
		base.Shape = Enum.PartType.Cylinder
		base.Material = Enum.Material.Metal
		base.CFrame = body.CFrame * CFrame.new(0, crownY, 0) * CFrame.Angles(0, 0, math.rad(90))
		for i = 1, 5 do
			local angle = i * (math.pi * 2 / 5)
			local spike = newPart("CrownSpike", Vector3.new(size * 0.09, size * 0.16, size * 0.09), Color3.fromRGB(255, 220, 60), model)
			spike.Material = Enum.Material.Neon
			spike.CFrame = body.CFrame * CFrame.new(math.cos(angle) * size * 0.17, crownY + size * 0.1, math.sin(angle) * size * 0.17)
		end
		local gem = newPart("Gem", Vector3.new(size * 0.1, size * 0.1, size * 0.1), Color3.fromRGB(255, 60, 90), model)
		gem.Shape = Enum.PartType.Ball
		gem.Material = Enum.Material.Neon
		gem.CFrame = body.CFrame * CFrame.new(0, crownY + size * 0.05, -size * 0.2)
	end

	-- Particules
	local preset = look.Particles and PARTICLE_PRESETS[look.Particles]
	if preset then
		local emitter = Instance.new("ParticleEmitter")
		emitter.Name = "Particles"
		emitter.Color = ColorSequence.new(preset.Colors[1], preset.Colors[2])
		emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, preset.Size * size), NumberSequenceKeypoint.new(1, 0) })
		emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, preset.Transparency), NumberSequenceKeypoint.new(1, 1) })
		emitter.Speed = preset.Speed
		emitter.Lifetime = preset.Lifetime
		emitter.Rate = preset.Rate * size
		emitter.LightEmission = preset.LightEmission
		emitter.SpreadAngle = Vector2.new(preset.Spread, preset.Spread)
		emitter.Acceleration = preset.Acceleration
		emitter.Parent = body
	end

	-- Lumière
	if look.Light then
		local light = Instance.new("PointLight")
		light.Color = look.Light
		light.Range = size * 1.8
		light.Brightness = 1.2
		light.Parent = body
	end

	-- Aura
	if look.Aura then
		local aura = ellipsoid("Aura", SlimeBuilder.GetBodySize(def) * 1.18, look.Aura, Vector3.new(0, 0, 0))
		aura.Material = Enum.Material.Neon
		aura.Transparency = 0.86
	end

	-- Nom + barre de vie
	local gui = Instance.new("BillboardGui")
	gui.Name = "Info"
	gui.Adornee = body
	gui.Size = UDim2.fromOffset(190, 60)
	gui.StudsOffsetWorldSpace = Vector3.new(0, radiusY + (look.Crown and size * 0.3 or 0) + (look.Crystals and size * 0.5 or 0) + 2.5, 0)
	gui.MaxDistance = 150
	gui.LightInfluence = 0
	gui.Parent = body

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.BackgroundTransparency = 1
	nameLabel.Size = UDim2.new(1, 0, 0, 30)
	nameLabel.Font = Enum.Font.FredokaOne
	nameLabel.Text = def.Name
	nameLabel.TextColor3 = def.Index >= 5 and Color3.fromRGB(255, 120, 90) or Color3.new(1, 1, 1)
	nameLabel.TextSize = 24
	nameLabel.Parent = gui
	local nameStroke = Instance.new("UIStroke")
	nameStroke.Thickness = 2.5
	nameStroke.Color = Color3.new(0, 0, 0)
	nameStroke.Parent = nameLabel

	local barBackground = Instance.new("Frame")
	barBackground.Name = "Bar"
	barBackground.Size = UDim2.new(1, -20, 0, 20)
	barBackground.Position = UDim2.fromOffset(10, 34)
	barBackground.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
	barBackground.BorderSizePixel = 0
	barBackground.Parent = gui
	local barCorner = Instance.new("UICorner")
	barCorner.CornerRadius = UDim.new(0, 8)
	barCorner.Parent = barBackground
	local barStroke = Instance.new("UIStroke")
	barStroke.Thickness = 2
	barStroke.Color = Color3.new(0, 0, 0)
	barStroke.Parent = barBackground

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(90, 230, 90)
	fill.BorderSizePixel = 0
	fill.Parent = barBackground
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 8)
	fillCorner.Parent = fill

	local hpLabel = Instance.new("TextLabel")
	hpLabel.Name = "HpLabel"
	hpLabel.BackgroundTransparency = 1
	hpLabel.Size = UDim2.fromScale(1, 1)
	hpLabel.Font = Enum.Font.FredokaOne
	hpLabel.Text = Util.FormatNumber(def.Health) .. " / " .. Util.FormatNumber(def.Health)
	hpLabel.TextColor3 = Color3.new(1, 1, 1)
	hpLabel.TextSize = 15
	hpLabel.Parent = barBackground
	local hpStroke = Instance.new("UIStroke")
	hpStroke.Thickness = 1.5
	hpStroke.Color = Color3.new(0, 0, 0)
	hpStroke.Parent = hpLabel

	model:SetAttribute("SlimeId", def.Id)
	model:SetAttribute("MaxHealth", def.Health)
	model:SetAttribute("Health", def.Health)
	model:SetAttribute("Alive", true)
	return model
end

function SlimeBuilder.UpdateHealth(model, health, maxHealth)
	local body = model.PrimaryPart
	local gui = body and body:FindFirstChild("Info")
	if not gui then
		return
	end
	local ratio = math.clamp(health / maxHealth, 0, 1)
	local bar = gui.Bar
	bar.Fill.Size = UDim2.fromScale(ratio, 1)
	bar.Fill.BackgroundColor3 = Color3.fromRGB(230, 60, 60):Lerp(Color3.fromRGB(90, 230, 90), ratio)
	bar.HpLabel.Text = Util.FormatNumber(math.max(0, health)) .. " / " .. Util.FormatNumber(maxHealth)
end

-- Mort : cache la barre de vie puis attend la fin de l'animation jouée par les clients
function SlimeBuilder.PlayDeath(model)
	local info = model:FindFirstChild("Info", true)
	if info then
		info.Enabled = false
	end
	local emitter = model:FindFirstChild("Particles", true)
	if emitter then
		emitter.Enabled = false
	end
	task.wait(0.5)
end

return SlimeBuilder
