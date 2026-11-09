--[[
	MapBuilder (ModuleScript)
	Emplacement : ServerScriptService > Builders > MapBuilder

	Génère tout le décor dans Workspace > Map :
	sol, chemins, zones de slimes, arbres (5 styles au choix dans MapConfig), rochers,
	buissons, fleurs, barrières low poly tout autour, nuages, tapis roulant, spawn.
	Appelé par Main au démarrage (sauf si Workspace.Map existe déjà).

	Astuce : pour "figer" la map et la modifier à la main dans Studio, tape dans la
	barre de commande :  require(game.ServerScriptService.Builders.MapBuilder).Build()

	Modèles externes (facultatif) : si ReplicatedStorage > Assets > TreeModels contient des
	modèles (importés depuis le Creator Store ou un fichier .fbx), ils remplacent les arbres générés.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local MapConfig = require(ReplicatedStorage.Config.MapConfig)
local SlimeConfig = require(ReplicatedStorage.Config.SlimeConfig)
local Util = require(ReplicatedStorage.Shared.Util)

local MapBuilder = {}

local GRASS_COLOR = MapConfig.Ground.Color
local PATH_COLOR = MapConfig.PathColor
local BARK = Color3.fromRGB(110, 72, 40)

---------------------------------------------------------------------------
-- Outils
---------------------------------------------------------------------------
local function newPart(name, size, cframe, color, material, parent)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function newBall(name, diameter, position, color, parent)
	local part = newPart(name, Vector3.new(diameter, diameter, diameter), CFrame.new(position), color, Enum.Material.SmoothPlastic, parent)
	part.Shape = Enum.PartType.Ball
	part.CanCollide = false
	return part
end

-- Ellipsoïde (sphère étirée) grâce à un SpecialMesh
local function newEllipsoid(name, size, cframe, color, parent)
	local part = newPart(name, size, cframe, color, Enum.Material.SmoothPlastic, parent)
	part.CanCollide = false
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = part
	return part
end

-- Cylindre vertical (l'axe d'un Cylinder Roblox est X : on le redresse)
local UPRIGHT = CFrame.Angles(0, 0, math.rad(90))
local function newColumn(name, height, diameter, position, color, parent, tilt)
	local cframe = CFrame.new(position) * (tilt or CFrame.new()) * UPRIGHT
	local part = newPart(name, Vector3.new(height, diameter, diameter), cframe, color, Enum.Material.SmoothPlastic, parent)
	part.Shape = Enum.PartType.Cylinder
	return part
end

-- Cylindre entre deux points (branches)
local function newBeam(name, from, to, diameter, color, parent)
	local length = (to - from).Magnitude
	local mid = (from + to) / 2
	local cframe = CFrame.lookAt(mid, to) * CFrame.Angles(0, math.rad(90), 0)
	local part = newPart(name, Vector3.new(length, diameter, diameter), cframe, color, Enum.Material.SmoothPlastic, parent)
	part.Shape = Enum.PartType.Cylinder
	part.CanCollide = false
	return part
end

local function folder(name, parent)
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

---------------------------------------------------------------------------
-- Sol, chemins, zones, spawn
---------------------------------------------------------------------------
local function buildGround(map)
	local g = MapConfig.Ground
	newPart("Ground", g.Size, CFrame.new(g.Center), g.Color, g.Material, map)
end

local function buildPaths(map)
	local paths = folder("Paths", map)
	newPart("MainPath", Vector3.new(12, 0.2, 480), CFrame.new(0, 0.1, -160), PATH_COLOR, Enum.Material.SmoothPlastic, paths)
	local conveyor = GameConfig.Conveyor
	newPart("ConveyorPath", Vector3.new(conveyor.Length + 16, 0.2, conveyor.Width + 16), CFrame.new(conveyor.Center + Vector3.new(0, 0.1, 0)), PATH_COLOR, Enum.Material.SmoothPlastic, paths)
	newPart("SpawnPlaza", Vector3.new(40, 0.2, 30), CFrame.new(GameConfig.SpawnPosition.X, 0.1, GameConfig.SpawnPosition.Z), PATH_COLOR, Enum.Material.SmoothPlastic, paths)
end

local function buildZones(map)
	local zones = folder("Zones", map)
	for _, def in ipairs(SlimeConfig.List) do
		local center = def.ZonePosition
		local diameter = def.ZoneRadius * 2
		local color = def.Color:Lerp(GRASS_COLOR, 0.55)
		local disc = newPart("Zone_" .. def.Id, Vector3.new(0.3, diameter, diameter), CFrame.new(center.X, 0.15, center.Z) * UPRIGHT, color, Enum.Material.SmoothPlastic, zones)
		disc.Shape = Enum.PartType.Cylinder
		-- Anneau de bordure (disque légèrement plus grand et plus foncé, dessous)
		local ring = newPart("ZoneRing_" .. def.Id, Vector3.new(0.2, diameter + 3, diameter + 3), CFrame.new(center.X, 0.1, center.Z) * UPRIGHT, color:Lerp(Color3.new(0, 0, 0), 0.25), Enum.Material.SmoothPlastic, zones)
		ring.Shape = Enum.PartType.Cylinder

		-- Panneau
		newPart("Sign_" .. def.Id, Vector3.new(0.6, 5, 0.6), CFrame.new(center.X + 9, 2.5, center.Z + def.ZoneRadius), Color3.fromRGB(110, 70, 35), Enum.Material.Wood, zones)
		local board = newPart("Board", Vector3.new(6, 3, 0.4), CFrame.new(center.X + 9, 5.5, center.Z + def.ZoneRadius), Color3.fromRGB(160, 110, 60), Enum.Material.Wood, zones)
		local gui = Instance.new("BillboardGui")
		gui.Size = UDim2.fromOffset(260, 110)
		gui.StudsOffsetWorldSpace = Vector3.new(0, 3.5, 0)
		gui.MaxDistance = 160
		gui.LightInfluence = 0
		gui.Adornee = board
		gui.Parent = board
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.TextColor3 = Color3.new(1, 1, 1)
		label.Text = string.format("Zone %d\n%s\n%s PV  ·  %s $", def.Index, def.Name, Util.FormatNumber(def.Health), Util.FormatNumber(def.Reward))
		label.Parent = gui
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 2.5
		stroke.Color = Color3.new(0, 0, 0)
		stroke.Parent = label
	end
end

local function buildSpawn(map)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Size = Vector3.new(10, 1, 10)
	spawn.CFrame = CFrame.new(GameConfig.SpawnPosition.X, 0.5, GameConfig.SpawnPosition.Z)
	spawn.Anchored = true
	spawn.Color = Color3.fromRGB(245, 150, 40)
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Duration = 0
	spawn.Parent = map
end

---------------------------------------------------------------------------
-- Arbres : 5 styles
---------------------------------------------------------------------------
local LEAF_PALETTES = {
	{ Color3.fromRGB(52, 150, 68), Color3.fromRGB(70, 180, 82), Color3.fromRGB(96, 208, 104) }, -- vert classique
	{ Color3.fromRGB(62, 170, 92), Color3.fromRGB(88, 200, 110), Color3.fromRGB(120, 225, 130) }, -- vert clair
	{ Color3.fromRGB(46, 140, 80), Color3.fromRGB(60, 165, 90), Color3.fromRGB(80, 190, 100) }, -- vert profond
	{ Color3.fromRGB(150, 200, 70), Color3.fromRGB(175, 220, 85), Color3.fromRGB(200, 235, 110) }, -- vert citron
	{ Color3.fromRGB(230, 140, 60), Color3.fromRGB(245, 170, 80), Color3.fromRGB(255, 200, 110) }, -- automne
	{ Color3.fromRGB(230, 120, 150), Color3.fromRGB(245, 150, 180), Color3.fromRGB(255, 185, 205) }, -- cerisier
}

-- Palettes vertes surtout, avec quelques arbres colorés (automne, cerisier)
local function pickPalette(rng)
	local roll = rng:NextNumber()
	if roll < 0.08 then
		return LEAF_PALETTES[6]
	elseif roll < 0.18 then
		return LEAF_PALETTES[5]
	end
	return LEAF_PALETTES[rng:NextInteger(1, 4)]
end

local BARK_DARK = Color3.fromRGB(82, 52, 28)

-- Tronc travaillé : effilé en 3 segments (droit ou tordu), écorce striée, nœud, racines effilées.
-- Retourne le sommet du tronc.
local function buildTrunk(model, position, rng, scale, yaw, height, style)
	style = style or MapConfig.TrunkStyle
	local bark = Color3.fromRGB(110 + rng:NextInteger(-12, 12), 72 + rng:NextInteger(-8, 8), 40)
	local segments = 3
	local segmentHeight = height / segments
	local point = position
	local tilt = 0
	local facing = CFrame.Angles(0, yaw, 0)

	for i = 1, segments do
		if style == "Twisted" then
			tilt = tilt + rng:NextNumber(-0.14, 0.14)
		end
		local diameter = (2.3 - (i - 0.5) * 0.45) * scale
		local step = facing * Vector3.new(math.sin(tilt) * segmentHeight, math.cos(tilt) * segmentHeight, 0)
		local mid = point + step / 2
		local segment = newPart("Trunk", Vector3.new(segmentHeight + 0.25 * scale, diameter, diameter), CFrame.lookAt(mid, point + step) * CFrame.Angles(0, math.rad(90), 0), bark, Enum.Material.SmoothPlastic, model)
		segment.Shape = Enum.PartType.Cylinder

		-- Stries d'écorce (fines lattes plus foncées collées au tronc)
		if style ~= "Smooth" then
			for s = 1, 3 do
				local angle = yaw + s * 2.1 + i * 0.7
				local radial = Vector3.new(math.cos(angle), 0, math.sin(angle))
				local ridge = newPart("Bark", Vector3.new(0.16 * scale, segmentHeight * 0.75, 0.42 * scale), CFrame.new(mid + radial * (diameter / 2 * 0.92)) * CFrame.Angles(0, -angle, 0), BARK_DARK, Enum.Material.SmoothPlastic, model)
				ridge.CanCollide = false
			end
		end
		point = point + step
	end

	-- Nœud dans le bois
	if style ~= "Smooth" then
		local angle = yaw + 1.2
		newEllipsoid("Knot", Vector3.new(0.3 * scale, 0.55 * scale, 0.55 * scale), CFrame.new(position + Vector3.new(math.cos(angle) * 0.95 * scale, height * 0.42, math.sin(angle) * 0.95 * scale)) * CFrame.Angles(0, -angle, 0), BARK_DARK, model)
	end

	-- Racines effilées (gros bloc incliné + petit bloc au bout)
	local rootCount = rng:NextInteger(3, 4)
	for r = 1, rootCount do
		local angle = yaw + r * (math.pi * 2 / rootCount) + rng:NextNumber(-0.3, 0.3)
		local radial = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local rotation = CFrame.Angles(0, -angle + math.rad(90), 0)
		local big = newPart("Root", Vector3.new(0.8, 0.8, 2.0) * scale, CFrame.new(position + radial * 1.5 * scale + Vector3.new(0, 0.35 * scale, 0)) * rotation * CFrame.Angles(math.rad(-18), 0, 0), bark, Enum.Material.SmoothPlastic, model)
		big.CanCollide = false
		local small = newPart("Root", Vector3.new(0.45, 0.4, 1.3) * scale, CFrame.new(position + radial * 2.9 * scale + Vector3.new(0, 0.15 * scale, 0)) * rotation * CFrame.Angles(math.rad(-8), 0, 0), bark, Enum.Material.SmoothPlastic, model)
		small.CanCollide = false
	end
	return point, bark
end

-- A : boules étagées (variantes : ronde, haute, large)
local function treeA(model, position, rng, scale, yaw)
	local variant = rng:NextInteger(1, 3) -- 1 ronde, 2 haute, 3 large
	local trunkHeight = (variant == 2 and 9 or 7.4) * scale
	local top, bark = buildTrunk(model, position, rng, scale, yaw, trunkHeight)
	local palette = pickPalette(rng)
	local crownY = top.Y + 1.0 * scale

	-- Une ou deux branches avec une petite touffe au bout
	for b = 1, rng:NextInteger(1, 2) do
		local angle = yaw + b * 2.4 + rng:NextNumber(0, 0.8)
		local endPoint = top + Vector3.new(math.cos(angle) * 3.2 * scale, -0.6 * scale, math.sin(angle) * 3.2 * scale)
		newBeam("Branch", top - Vector3.new(0, 0.8 * scale, 0), endPoint, 0.55 * scale, bark, model)
		newBall("Leaves", 2.4 * scale, endPoint + Vector3.new(0, 0.6 * scale, 0), palette[3], model)
	end

	if variant == 1 then
		newBall("Leaves", 7.5 * scale, Vector3.new(top.X, crownY, top.Z), palette[1], model)
		local ringCount = rng:NextInteger(4, 6)
		for i = 1, ringCount do
			local angle = yaw + i * (math.pi * 2 / ringCount)
			newBall("Leaves", rng:NextNumber(4.2, 5.4) * scale, Vector3.new(top.X + math.cos(angle) * 2.6 * scale, crownY - 0.9 * scale + rng:NextNumber(-0.4, 0.6) * scale, top.Z + math.sin(angle) * 2.6 * scale), palette[(i % 2) + 1], model)
		end
		newBall("Leaves", 4.4 * scale, Vector3.new(top.X + 0.4 * scale, crownY + 2.8 * scale, top.Z - 0.3 * scale), palette[3], model)
	elseif variant == 2 then
		-- Haute : boules empilées de plus en plus petites
		local sizes = { 6.4, 5.4, 4.4, 3.2 }
		local y = crownY - 0.5 * scale
		for i, d in ipairs(sizes) do
			local offset = Vector3.new(rng:NextNumber(-0.6, 0.6), 0, rng:NextNumber(-0.6, 0.6)) * scale
			newBall("Leaves", d * scale, Vector3.new(top.X, y, top.Z) + offset, palette[((i - 1) % 3) + 1], model)
			y = y + d * scale * 0.55
		end
	else
		-- Large : couronne aplatie de grosses boules
		local ringCount = rng:NextInteger(5, 7)
		for i = 1, ringCount do
			local angle = yaw + i * (math.pi * 2 / ringCount)
			newBall("Leaves", rng:NextNumber(4.8, 5.8) * scale, Vector3.new(top.X + math.cos(angle) * 3.6 * scale, crownY - 0.6 * scale + rng:NextNumber(-0.3, 0.3) * scale, top.Z + math.sin(angle) * 3.6 * scale), palette[(i % 2) + 1], model)
		end
		newBall("Leaves", 6.6 * scale, Vector3.new(top.X, crownY + 0.9 * scale, top.Z), palette[3], model)
	end
end

-- B : low poly facetté (cubes tournés en cristaux de feuillage, agencement aléatoire)
local function treeB(model, position, rng, scale, yaw)
	local top, _ = buildTrunk(model, position, rng, scale, yaw, 7.6 * scale)
	local palette = pickPalette(rng)
	local crownY = top.Y + 2.0 * scale
	local mainSize = rng:NextNumber(5.8, 7.2) * scale
	local main = newPart("Leaves", Vector3.new(mainSize, mainSize, mainSize), CFrame.new(top.X, crownY, top.Z) * CFrame.Angles(rng:NextNumber(0.3, 0.8), yaw, rng:NextNumber(0.3, 0.8)), palette[1], Enum.Material.SmoothPlastic, model)
	main.CanCollide = false
	local satellites = rng:NextInteger(3, 6)
	for i = 1, satellites do
		local angle = yaw + i * (math.pi * 2 / satellites) + rng:NextNumber(-0.4, 0.4)
		local elevation = rng:NextNumber(-0.5, 0.9)
		local distance = rng:NextNumber(2.4, 3.4) * scale
		local size = rng:NextNumber(3.0, 4.8) * scale
		local offset = Vector3.new(math.cos(elevation) * math.cos(angle) * distance, math.sin(elevation) * distance, math.cos(elevation) * math.sin(angle) * distance)
		local cube = newPart("Leaves", Vector3.new(size, size, size), CFrame.new(Vector3.new(top.X, crownY, top.Z) + offset) * CFrame.Angles(rng:NextNumber(0.2, 0.9), rng:NextNumber(0, 3), rng:NextNumber(0.3, 0.9)), palette[(i % 2) + 2], Enum.Material.SmoothPlastic, model)
		cube.CanCollide = false
	end
end

-- C : sapin à étages (blocs tournés à 45°, de plus en plus petits)
local function treeC(model, position, rng, scale, yaw)
	newColumn("Trunk", 4 * scale, 1.3 * scale, position + Vector3.new(0, 2 * scale, 0), BARK, model)
	local greens = { Color3.fromRGB(34, 110, 70), Color3.fromRGB(40, 130, 78), Color3.fromRGB(52, 150, 86), Color3.fromRGB(70, 175, 96) }
	local tiers = { { 7.5, 2.6 }, { 6.0, 2.4 }, { 4.6, 2.2 }, { 3.2, 2.0 }, { 1.9, 1.8 } }
	local y = 3.2 * scale
	for i, tier in ipairs(tiers) do
		local w, h = tier[1] * scale, tier[2] * scale
		local color = greens[math.min(i, 4)]
		local outer = newPart("Leaves", Vector3.new(w, h, w), CFrame.new(position + Vector3.new(0, y + h / 2, 0)) * CFrame.Angles(0, yaw + math.rad(45), 0), color, Enum.Material.SmoothPlastic, model)
		outer.CanCollide = false
		local inner = newPart("Leaves", Vector3.new(w * 0.8, h * 0.9, w * 0.8), CFrame.new(position + Vector3.new(0, y + h / 2 + 0.1, 0)) * CFrame.Angles(0, yaw, 0), color, Enum.Material.SmoothPlastic, model)
		inner.CanCollide = false
		y = y + h * 0.75
	end
	newBall("Star", 1.2 * scale, position + Vector3.new(0, y + 0.8 * scale, 0), Color3.fromRGB(255, 220, 80), model)
end

-- D : parasol / acacia (tronc incliné, branches, canopées plates)
local function treeD(model, position, rng, scale, yaw)
	local trunkH = 6 * scale
	local lean = CFrame.Angles(0, yaw, 0) * CFrame.Angles(0, 0, math.rad(10))
	newColumn("Trunk", trunkH, 1.4 * scale, position + Vector3.new(0, trunkH / 2, 0), BARK, model, lean)
	local top = position + (CFrame.Angles(0, yaw, 0) * Vector3.new(-1.0 * scale, trunkH, 0))
	local palette = pickPalette(rng)
	local canopies = { { -3.2, 1.6, -1.0, 7.5 }, { 2.6, 0.9, 1.4, 6.5 }, { 0.4, 2.8, -2.6, 5.5 }, { 0.6, 3.4, 2.2, 4.8 } }
	for i, c in ipairs(canopies) do
		local offset = CFrame.Angles(0, yaw, 0) * Vector3.new(c[1] * scale, c[2] * scale, c[3] * scale)
		local endPoint = top + offset
		newBeam("Branch", top, endPoint, 0.6 * scale, BARK, model)
		newEllipsoid("Leaves", Vector3.new(c[4] * scale, 1.6 * scale, c[4] * scale), CFrame.new(endPoint + Vector3.new(0, 0.5 * scale, 0)), palette[(i % 2) + 1], model)
	end
end

-- E : palmier (tronc courbé en segments, palmes, noix de coco)
local function treeE(model, position, rng, scale, yaw)
	local direction = CFrame.Angles(0, yaw, 0)
	local point = position
	local tilt = 0.05
	local trunkColor = Color3.fromRGB(150, 110, 70)
	for i = 0, 5 do
		local h = 1.9 * scale
		local step = direction * Vector3.new(math.sin(tilt) * h, math.cos(tilt) * h, 0)
		local mid = point + step / 2
		local segment = newPart("Trunk", Vector3.new(h, (1.4 - i * 0.1) * scale, (1.4 - i * 0.1) * scale), CFrame.lookAt(mid, point + step) * CFrame.Angles(0, math.rad(90), 0), trunkColor, Enum.Material.SmoothPlastic, model)
		segment.Shape = Enum.PartType.Cylinder
		point = point + step
		tilt = tilt + 0.07
	end
	local palette = pickPalette(rng)
	for i = 1, 7 do
		local angle = yaw + i * (math.pi * 2 / 7)
		local leaf = newPart("Leaf", Vector3.new(6.5 * scale, 0.25 * scale, 1.6 * scale), CFrame.new(point + Vector3.new(math.cos(angle) * 3 * scale, 0.6 * scale, math.sin(angle) * 3 * scale)) * CFrame.Angles(0, -angle, math.rad(-25)), palette[(i % 2) + 1], Enum.Material.SmoothPlastic, model)
		leaf.CanCollide = false
	end
	for i = 1, 3 do
		local angle = i * 2.1
		newBall("Coconut", 0.9 * scale, point + Vector3.new(math.cos(angle) * 0.8 * scale, -0.3 * scale, math.sin(angle) * 0.8 * scale), Color3.fromRGB(90, 60, 30), model)
	end
end

local TREE_BUILDERS = { A = treeA, B = treeB, C = treeC, D = treeD, E = treeE }

local function externalTreeModels()
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local treeFolder = assets and assets:FindFirstChild("TreeModels")
	if treeFolder and #treeFolder:GetChildren() > 0 then
		return treeFolder:GetChildren()
	end
	return nil
end

local function buildTree(parent, position, rng)
	local model = Instance.new("Model")
	model.Name = "Tree"
	model.Parent = parent
	local yaw = rng:NextNumber(0, math.pi * 2)

	local external = externalTreeModels()
	if external then
		local clone = external[rng:NextInteger(1, #external)]:Clone()
		clone:PivotTo(CFrame.new(position) * CFrame.Angles(0, yaw, 0))
		clone.Parent = model
		return model
	end

	local styles = MapConfig.TreeStyles
	local style = styles[rng:NextInteger(1, #styles)]
	local builder = TREE_BUILDERS[style] or treeA
	builder(model, position, rng, rng:NextNumber(0.8, 1.5), yaw)
	return model
end

---------------------------------------------------------------------------
-- Rochers, buissons, fleurs
---------------------------------------------------------------------------
local function buildRock(parent, position, rng)
	local model = Instance.new("Model")
	model.Name = "Rock"
	model.Parent = parent
	local grey = 110 + rng:NextInteger(-15, 20)
	local color = Color3.fromRGB(grey, grey, grey + 8)
	local size = Vector3.new(rng:NextNumber(3, 6), rng:NextNumber(2.2, 4.2), rng:NextNumber(3, 6))
	local rotation = CFrame.Angles(math.rad(rng:NextNumber(-14, 14)), rng:NextNumber(0, math.pi * 2), math.rad(rng:NextNumber(-14, 14)))
	newPart("Rock", size, CFrame.new(position + Vector3.new(0, size.Y * 0.35, 0)) * rotation, color, Enum.Material.Slate, model)
	for _ = 1, 2 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local small = Vector3.new(rng:NextNumber(1.2, 2.4), rng:NextNumber(1, 1.8), rng:NextNumber(1.2, 2.4))
		newPart("Pebble", small, CFrame.new(position + Vector3.new(math.cos(angle) * size.X * 0.6, small.Y * 0.3, math.sin(angle) * size.Z * 0.6)) * CFrame.Angles(0, angle, math.rad(rng:NextNumber(-20, 20))), color:Lerp(Color3.new(0, 0, 0), 0.08), Enum.Material.Slate, model)
	end
	return model
end

local function buildBush(parent, position, rng)
	local scale = rng:NextNumber(0.7, 1.2)
	for i = 1, 3 do
		local angle = i * (math.pi * 2 / 3) + rng:NextNumber(0, 1)
		local diameter = rng:NextNumber(2, 2.8) * scale
		newBall("Bush", diameter, position + Vector3.new(math.cos(angle) * 0.8 * scale, diameter * 0.35, math.sin(angle) * 0.8 * scale), Color3.fromRGB(60 + rng:NextInteger(0, 30), 165 + rng:NextInteger(0, 30), 80), parent)
	end
end

local FLOWER_COLORS = { Color3.fromRGB(255, 90, 120), Color3.fromRGB(255, 210, 60), Color3.fromRGB(120, 150, 255), Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 150, 50) }
local function buildFlower(parent, position, rng)
	local stem = newPart("Stem", Vector3.new(0.2, 1.2, 0.2), CFrame.new(position + Vector3.new(0, 0.6, 0)), Color3.fromRGB(70, 160, 70), Enum.Material.SmoothPlastic, parent)
	stem.CanCollide = false
	newEllipsoid("Flower", Vector3.new(0.9, 0.5, 0.9), CFrame.new(position + Vector3.new(0, 1.3, 0)), FLOWER_COLORS[rng:NextInteger(1, #FLOWER_COLORS)], parent)
	newBall("Center", 0.35, position + Vector3.new(0, 1.5, 0), Color3.fromRGB(255, 230, 90), parent)
end

-- Vérifie qu'une position ne gêne pas le jeu (chemins, zones, tapis, spawn, barrière)
local function isFree(position)
	if math.abs(position.X) < 11 then
		return false
	end
	local conveyor = GameConfig.Conveyor
	local toConveyor = position - conveyor.Center
	if math.abs(toConveyor.X) < conveyor.Length / 2 + 14 and math.abs(toConveyor.Z) < conveyor.Width / 2 + 14 then
		return false
	end
	local flat = Vector3.new(position.X, 0, position.Z)
	if (flat - Vector3.new(GameConfig.SpawnPosition.X, 0, GameConfig.SpawnPosition.Z)).Magnitude < 28 then
		return false
	end
	for _, def in ipairs(SlimeConfig.List) do
		if (flat - Vector3.new(def.ZonePosition.X, 0, def.ZonePosition.Z)).Magnitude < def.ZoneRadius + 8 then
			return false
		end
	end
	return true
end

local function buildNature(map)
	local nature = folder("Nature", map)
	local rng = Random.new(42)
	local want = MapConfig.Decor
	local counts = { Trees = 0, Rocks = 0, Bushes = 0, Flowers = 0 }
	local g = MapConfig.Ground
	local margin = MapConfig.Fence.Inset + 6
	local minX, maxX = g.Center.X - g.Size.X / 2 + margin, g.Center.X + g.Size.X / 2 - margin
	local minZ, maxZ = g.Center.Z - g.Size.Z / 2 + margin, g.Center.Z + g.Size.Z / 2 - margin
	local attempts = 0
	while (counts.Trees < want.Trees or counts.Rocks < want.Rocks or counts.Bushes < want.Bushes or counts.Flowers < want.Flowers) and attempts < 5000 do
		attempts = attempts + 1
		local position = Vector3.new(rng:NextNumber(minX, maxX), 0, rng:NextNumber(minZ, maxZ))
		if isFree(position) then
			local roll = rng:NextNumber()
			if counts.Trees < want.Trees and roll < 0.3 then
				buildTree(nature, position, rng)
				counts.Trees = counts.Trees + 1
			elseif counts.Rocks < want.Rocks and roll < 0.42 then
				buildRock(nature, position, rng)
				counts.Rocks = counts.Rocks + 1
			elseif counts.Bushes < want.Bushes and roll < 0.6 then
				buildBush(nature, position, rng)
				counts.Bushes = counts.Bushes + 1
			elseif counts.Flowers < want.Flowers then
				buildFlower(nature, position, rng)
				counts.Flowers = counts.Flowers + 1
			end
		end
	end
end

---------------------------------------------------------------------------
-- Barrière low poly + murs invisibles
---------------------------------------------------------------------------
local function buildFence(map)
	local conf = MapConfig.Fence
	if not conf.Enabled then
		return
	end
	local fence = folder("Fence", map)
	local g = MapConfig.Ground
	local halfX = g.Size.X / 2 - conf.Inset
	local halfZ = g.Size.Z / 2 - conf.Inset
	local cx, cz = g.Center.X, g.Center.Z

	-- Les 4 côtés : { départ, arrivée }
	local corners = {
		Vector3.new(cx - halfX, 0, cz - halfZ),
		Vector3.new(cx + halfX, 0, cz - halfZ),
		Vector3.new(cx + halfX, 0, cz + halfZ),
		Vector3.new(cx - halfX, 0, cz + halfZ),
	}
	for side = 1, 4 do
		local from = corners[side]
		local to = corners[side % 4 + 1]
		local length = (to - from).Magnitude
		local direction = (to - from).Unit
		local mid = (from + to) / 2
		local look = CFrame.lookAt(mid, to)

		-- Poteaux
		local count = math.floor(length / conf.PostSpacing)
		for i = 0, count do
			local position = from + direction * math.min(i * conf.PostSpacing, length)
			local post = newPart("Post", conf.PostSize, CFrame.new(position + Vector3.new(0, conf.PostSize.Y / 2, 0)) * look.Rotation, conf.PostColor, Enum.Material.SmoothPlastic, fence)
			-- Chapeau du poteau
			newPart("PostCap", Vector3.new(conf.PostSize.X + 0.3, 0.3, conf.PostSize.Z + 0.3), CFrame.new(position + Vector3.new(0, conf.PostSize.Y + 0.15, 0)) * look.Rotation, conf.PostColor:Lerp(Color3.new(0, 0, 0), 0.15), Enum.Material.SmoothPlastic, fence)
			post.CanCollide = true
		end
		-- Traverses
		for _, height in ipairs(conf.RailHeights) do
			newPart("Rail", Vector3.new(conf.RailSize.X, conf.RailSize.Y, length), look * CFrame.new(0, height, 0), conf.RailColor, Enum.Material.SmoothPlastic, fence)
		end
		-- Mur invisible (empêche de sortir de la map)
		local wall = newPart("Wall", Vector3.new(1, conf.WallHeight, length + 2), look * CFrame.new(0, conf.WallHeight / 2, 0), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, fence)
		wall.Transparency = 1
		wall.CanCollide = true
	end
end

---------------------------------------------------------------------------
-- Nuages low poly (déplacés par DecorController côté client)
---------------------------------------------------------------------------
local function buildClouds(map)
	local conf = MapConfig.Clouds
	local clouds = folder("Clouds", map)
	local rng = Random.new(7)
	local g = MapConfig.Ground
	local width = g.Size.X + 160
	for i = 1, conf.Count do
		local model = Instance.new("Model")
		model.Name = "Cloud"
		local scale = rng:NextNumber(0.8, 1.8)
		local puffs = rng:NextInteger(3, 5)
		local baseCFrame = CFrame.new()
		for p = 1, puffs do
			local offset = Vector3.new((p - (puffs + 1) / 2) * 5 * scale + rng:NextNumber(-1, 1), rng:NextNumber(-0.6, 0.8) * scale, rng:NextNumber(-1.5, 1.5) * scale)
			local size = Vector3.new(rng:NextNumber(6, 9) * scale, rng:NextNumber(3, 4.5) * scale, rng:NextNumber(5, 7) * scale)
			local puff = newEllipsoid("Puff", size, baseCFrame * CFrame.new(offset), conf.Color, model)
			puff.CastShadow = false
		end
		local primary = model:FindFirstChild("Puff")
		model.PrimaryPart = primary
		local y = rng:NextNumber(conf.MinHeight, conf.MaxHeight)
		local z = g.Center.Z + rng:NextNumber(-g.Size.Z / 2 - 60, g.Size.Z / 2 + 60)
		model:SetAttribute("Y", y)
		model:SetAttribute("Z", z)
		model:SetAttribute("Phase", rng:NextNumber(0, width))
		model:SetAttribute("Speed", conf.Speed * rng:NextNumber(0.6, 1.4))
		model:SetAttribute("StartX", g.Center.X - width / 2)
		model:SetAttribute("Width", width)
		model:PivotTo(CFrame.new(g.Center.X, y, z))
		model.Parent = clouds
	end
end

---------------------------------------------------------------------------
-- Tapis roulant
---------------------------------------------------------------------------
local function buildConveyor(map)
	local conf = GameConfig.Conveyor
	local model = Instance.new("Model")
	model.Name = "Conveyor"
	model.Parent = map

	local direction = conf.Direction.Unit
	local look = CFrame.lookAt(conf.Center, conf.Center + direction)
	local beltCenter = look * CFrame.new(0, conf.BeltHeight / 2, 0)

	newPart("Belt", Vector3.new(conf.Width, conf.BeltHeight, conf.Length), beltCenter, Color3.fromRGB(25, 25, 28), Enum.Material.SmoothPlastic, model)

	local borderHeight = conf.BeltHeight + 0.7
	for _, side in ipairs({ -1, 1 }) do
		newPart("Border", Vector3.new(1.4, borderHeight, conf.Length + 2.8), look * CFrame.new(side * (conf.Width / 2 + 0.7), borderHeight / 2, 0), Color3.fromRGB(125, 125, 130), Enum.Material.SmoothPlastic, model)
	end
	for _, endSide in ipairs({ -1, 1 }) do
		newPart("End", Vector3.new(conf.Width + 2.8, borderHeight, 1.4), look * CFrame.new(0, borderHeight / 2, endSide * (conf.Length / 2 + 0.7)), Color3.fromRGB(125, 125, 130), Enum.Material.SmoothPlastic, model)
		-- Rouleaux aux extrémités
		-- (l'axe du Cylinder est X = la largeur du tapis : aucune rotation nécessaire)
		local roller = newPart("Roller", Vector3.new(conf.Width + 1, 1.2, 1.2), look * CFrame.new(0, conf.BeltHeight / 2 + 0.3, endSide * (conf.Length / 2 + 1.6)), Color3.fromRGB(90, 90, 96), Enum.Material.Metal, model)
		roller.Shape = Enum.PartType.Cylinder
	end

	local slats = folder("Slats", model)
	local spacing = 3
	local count = math.floor(conf.Length / spacing)
	for i = 0, count - 1 do
		local slat = newPart("Slat", Vector3.new(conf.Width - 1.6, 0.08, 1.2), look * CFrame.new(0, conf.BeltHeight + 0.04, -conf.Length / 2 + i * spacing), Color3.fromRGB(75, 75, 80), Enum.Material.SmoothPlastic, slats)
		slat.CanCollide = false
		slat.CanQuery = false
		slat:SetAttribute("Offset", i * spacing)
	end
end

local function setupLighting()
	Lighting.ClockTime = 14
	Lighting.Brightness = 2.5
	Lighting.Ambient = Color3.fromRGB(120, 120, 120)
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 150, 150)
	Lighting.GlobalShadows = true
end

function MapBuilder.Build()
	if workspace:FindFirstChild("Map") then
		return workspace.Map
	end
	local oldBaseplate = workspace:FindFirstChild("Baseplate")
	if oldBaseplate then
		oldBaseplate:Destroy()
	end
	local oldSpawn = workspace:FindFirstChild("SpawnLocation")
	if oldSpawn then
		oldSpawn:Destroy()
	end

	local map = folder("Map", workspace)
	buildGround(map)
	buildPaths(map)
	buildZones(map)
	buildNature(map)
	buildFence(map)
	buildClouds(map)
	buildConveyor(map)
	buildSpawn(map)
	setupLighting()
	return map
end

return MapBuilder
