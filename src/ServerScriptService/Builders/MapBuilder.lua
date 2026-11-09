--[[
	MapBuilder (ModuleScript)
	Emplacement : ServerScriptService > Builders > MapBuilder

	Génère tout le décor dans Workspace > Map :
	pelouse, chemins beiges, zones de slimes, arbres, rochers, tapis roulant, spawn.
	Appelé automatiquement par Main au démarrage (sauf si Workspace.Map existe déjà).

	Astuce : pour "figer" la map et la modifier à la main dans Studio, tape dans la
	barre de commande :  require(game.ServerScriptService.Builders.MapBuilder).Build()
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local SlimeConfig = require(ReplicatedStorage.Config.SlimeConfig)
local Util = require(ReplicatedStorage.Shared.Util)

local MapBuilder = {}

local GRASS_COLOR = Color3.fromRGB(96, 200, 90)
local PATH_COLOR = Color3.fromRGB(222, 200, 160)

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

local function folder(name, parent)
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

-- Sol
local function buildGround(map)
	-- La map s'étend de z = +120 (spawn) à z = -420 (boss)
	local ground = newPart("Ground", Vector3.new(340, 2, 540), CFrame.new(0, -1, -150), GRASS_COLOR, Enum.Material.Grass, map)
	ground.Name = "Ground"
	return ground
end

-- Chemins
local function buildPaths(map)
	local paths = folder("Paths", map)
	-- Grand chemin central du spawn jusqu'au boss
	newPart("MainPath", Vector3.new(12, 0.2, 480), CFrame.new(0, 0.1, -160), PATH_COLOR, Enum.Material.SmoothPlastic, paths)
	-- Chemin autour du tapis
	local conveyor = GameConfig.Conveyor
	newPart("ConveyorPath", Vector3.new(conveyor.Length + 16, 0.2, conveyor.Width + 16), CFrame.new(conveyor.Center + Vector3.new(0, 0.1, 0)), PATH_COLOR, Enum.Material.SmoothPlastic, paths)
	-- Place du spawn
	newPart("SpawnPlaza", Vector3.new(40, 0.2, 30), CFrame.new(GameConfig.SpawnPosition.X, 0.1, GameConfig.SpawnPosition.Z), PATH_COLOR, Enum.Material.SmoothPlastic, paths)
end

-- Zones de slimes (cercle coloré + panneau)
local function buildZones(map)
	local zones = folder("Zones", map)
	for _, def in ipairs(SlimeConfig.List) do
		local center = def.ZonePosition
		local diameter = def.ZoneRadius * 2
		local color = def.Color:Lerp(GRASS_COLOR, 0.55)
		local disc = newPart("Zone_" .. def.Id, Vector3.new(0.3, diameter, diameter), CFrame.new(center.X, 0.15, center.Z) * CFrame.Angles(0, 0, math.rad(90)), color, Enum.Material.SmoothPlastic, zones)
		disc.Shape = Enum.PartType.Cylinder

		-- Panneau à l'entrée de la zone (côté spawn)
		local post = newPart("Sign_" .. def.Id, Vector3.new(0.6, 5, 0.6), CFrame.new(center.X + 9, 2.5, center.Z + def.ZoneRadius), Color3.fromRGB(110, 70, 35), Enum.Material.Wood, zones)
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

-- Palettes de feuillage (vert classique, vert clair, et quelques arbres colorés)
local LEAF_PALETTES = {
	{ Color3.fromRGB(52, 150, 68), Color3.fromRGB(70, 180, 82), Color3.fromRGB(96, 208, 104) },
	{ Color3.fromRGB(62, 170, 92), Color3.fromRGB(88, 200, 110), Color3.fromRGB(120, 225, 130) },
	{ Color3.fromRGB(46, 140, 80), Color3.fromRGB(60, 165, 90), Color3.fromRGB(80, 190, 100) },
	{ Color3.fromRGB(230, 120, 150), Color3.fromRGB(245, 150, 180), Color3.fromRGB(255, 185, 205) }, -- cerisier
}

-- Un arbre cartoon : tronc effilé en deux segments, racines, feuillage en boules étagées
local function buildTree(parent, position, rng)
	local scale = rng:NextNumber(0.8, 1.5)
	local yaw = rng:NextNumber(0, math.pi * 2)
	local rotation = CFrame.Angles(0, yaw, 0)
	local model = Instance.new("Model")
	model.Name = "Tree"
	model.Parent = parent

	local barkColor = Color3.fromRGB(110 + rng:NextInteger(-15, 15), 72 + rng:NextInteger(-10, 10), 40)

	-- Tronc : cylindres verticaux (l'axe d'un Cylinder est X, on le redresse avec une rotation de 90° sur Z)
	local upright = CFrame.Angles(0, 0, math.rad(90))
	local lowerHeight, upperHeight = 4.2 * scale, 3.4 * scale
	local trunk = newPart("Trunk", Vector3.new(lowerHeight, 2.0 * scale, 2.0 * scale), CFrame.new(position + Vector3.new(0, lowerHeight / 2, 0)) * rotation * upright, barkColor, Enum.Material.Wood, model)
	trunk.Shape = Enum.PartType.Cylinder
	local upper = newPart("TrunkTop", Vector3.new(upperHeight, 1.4 * scale, 1.4 * scale), CFrame.new(position + Vector3.new(0, lowerHeight + upperHeight / 2 - 0.2, 0)) * rotation * upright, barkColor, Enum.Material.Wood, model)
	upper.Shape = Enum.PartType.Cylinder

	-- Racines
	for i = 1, 3 do
		local angle = yaw + i * (math.pi * 2 / 3)
		local root = newPart("Root", Vector3.new(0.9, 0.7, 2.2) * scale, CFrame.new(position + Vector3.new(math.cos(angle) * 1.3 * scale, 0.3 * scale, math.sin(angle) * 1.3 * scale)) * CFrame.Angles(0, -angle + math.rad(90), 0) * CFrame.Angles(math.rad(-15), 0, 0), barkColor, Enum.Material.Wood, model)
		root.CanCollide = false
	end

	-- Branches courtes
	for i = 1, 2 do
		local angle = yaw + i * math.pi + rng:NextNumber(-0.5, 0.5)
		local branch = newPart("Branch", Vector3.new(2.6 * scale, 0.5 * scale, 0.5 * scale), CFrame.new(position + Vector3.new(math.cos(angle) * 1.2 * scale, lowerHeight + 0.8 * scale, math.sin(angle) * 1.2 * scale)) * CFrame.Angles(0, -angle, 0) * CFrame.Angles(0, 0, math.rad(35)), barkColor, Enum.Material.Wood, model)
		branch.Shape = Enum.PartType.Cylinder
		branch.CanCollide = false
	end

	-- Feuillage : grosse boule centrale, couronne de boules autour, petite boule au sommet
	local palette = LEAF_PALETTES[rng:NextNumber() < 0.12 and 4 or rng:NextInteger(1, 3)]
	local crownY = lowerHeight + upperHeight + 1.2 * scale
	local function leaf(offset, diameter, color)
		local ball = newPart("Leaves", Vector3.new(diameter, diameter, diameter), CFrame.new(position + offset), color, Enum.Material.SmoothPlastic, model)
		ball.Shape = Enum.PartType.Ball
		ball.CanCollide = false
		return ball
	end
	leaf(Vector3.new(0, crownY, 0), 7.5 * scale, palette[1])
	local ringCount = rng:NextInteger(4, 5)
	for i = 1, ringCount do
		local angle = yaw + i * (math.pi * 2 / ringCount)
		local radius = 2.6 * scale
		leaf(Vector3.new(math.cos(angle) * radius, crownY - 0.9 * scale + rng:NextNumber(-0.4, 0.6) * scale, math.sin(angle) * radius), rng:NextNumber(4.2, 5.4) * scale, palette[(i % 2) + 1])
	end
	leaf(Vector3.new(0.4 * scale, crownY + 2.8 * scale, -0.3 * scale), 4.4 * scale, palette[3])

	model.PrimaryPart = trunk
	return model
end

-- Rocher : un gros bloc incliné + deux petits blocs + une touche de mousse
local function buildRock(parent, position, rng)
	local model = Instance.new("Model")
	model.Name = "Rock"
	model.Parent = parent
	local grey = 110 + rng:NextInteger(-15, 20)
	local color = Color3.fromRGB(grey, grey, grey + 8)
	local size = Vector3.new(rng:NextNumber(3, 6), rng:NextNumber(2.2, 4.2), rng:NextNumber(3, 6))
	local rotation = CFrame.Angles(math.rad(rng:NextNumber(-14, 14)), rng:NextNumber(0, math.pi * 2), math.rad(rng:NextNumber(-14, 14)))
	local main = newPart("Rock", size, CFrame.new(position + Vector3.new(0, size.Y * 0.35, 0)) * rotation, color, Enum.Material.Slate, model)
	for i = 1, 2 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local small = Vector3.new(rng:NextNumber(1.2, 2.4), rng:NextNumber(1, 1.8), rng:NextNumber(1.2, 2.4))
		newPart("Pebble", small, CFrame.new(position + Vector3.new(math.cos(angle) * size.X * 0.6, small.Y * 0.3, math.sin(angle) * size.Z * 0.6)) * CFrame.Angles(0, angle, math.rad(rng:NextNumber(-20, 20))), color:Lerp(Color3.new(0, 0, 0), 0.08), Enum.Material.Slate, model)
	end
	local moss = newPart("Moss", Vector3.new(size.X * 0.55, 0.5, size.Z * 0.55), CFrame.new(position + Vector3.new(0, size.Y * 0.75, 0)) * rotation, Color3.fromRGB(90, 170, 80), Enum.Material.Grass, model)
	moss.Shape = Enum.PartType.Ball
	moss.CanCollide = false
	model.PrimaryPart = main
	return model
end

-- Buisson : 3 boules vertes serrées
local function buildBush(parent, position, rng)
	local scale = rng:NextNumber(0.7, 1.2)
	for i = 1, 3 do
		local angle = i * (math.pi * 2 / 3) + rng:NextNumber(0, 1)
		local diameter = rng:NextNumber(2, 2.8) * scale
		local ball = newPart("Bush", Vector3.new(diameter, diameter, diameter), CFrame.new(position + Vector3.new(math.cos(angle) * 0.8 * scale, diameter * 0.35, math.sin(angle) * 0.8 * scale)), Color3.fromRGB(60 + rng:NextInteger(0, 30), 165 + rng:NextInteger(0, 30), 80), Enum.Material.SmoothPlastic, parent)
		ball.Shape = Enum.PartType.Ball
		ball.CanCollide = false
	end
end

-- Fleur : tige + corolle colorée
local FLOWER_COLORS = { Color3.fromRGB(255, 90, 120), Color3.fromRGB(255, 210, 60), Color3.fromRGB(120, 150, 255), Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 150, 50) }
local function buildFlower(parent, position, rng)
	local stem = newPart("Stem", Vector3.new(0.2, 1.2, 0.2), CFrame.new(position + Vector3.new(0, 0.6, 0)), Color3.fromRGB(70, 160, 70), Enum.Material.SmoothPlastic, parent)
	stem.CanCollide = false
	local head = newPart("Flower", Vector3.new(0.9, 0.5, 0.9), CFrame.new(position + Vector3.new(0, 1.3, 0)), FLOWER_COLORS[rng:NextInteger(1, #FLOWER_COLORS)], Enum.Material.SmoothPlastic, parent)
	head.Shape = Enum.PartType.Ball
	head.CanCollide = false
	local center = newPart("Center", Vector3.new(0.35, 0.35, 0.35), CFrame.new(position + Vector3.new(0, 1.5, 0)), Color3.fromRGB(255, 230, 90), Enum.Material.SmoothPlastic, parent)
	center.Shape = Enum.PartType.Ball
	center.CanCollide = false
end

-- Vérifie qu'une position ne gêne pas le jeu (chemins, zones, tapis, spawn)
local function isFree(position)
	if math.abs(position.X) < 11 then
		return false -- chemin central
	end
	local conveyor = GameConfig.Conveyor
	local toConveyor = position - conveyor.Center
	if math.abs(toConveyor.X) < conveyor.Length / 2 + 14 and math.abs(toConveyor.Z) < conveyor.Width / 2 + 14 then
		return false
	end
	if (Vector3.new(position.X, 0, position.Z) - Vector3.new(GameConfig.SpawnPosition.X, 0, GameConfig.SpawnPosition.Z)).Magnitude < 28 then
		return false
	end
	for _, def in ipairs(SlimeConfig.List) do
		if (Vector3.new(position.X, 0, position.Z) - Vector3.new(def.ZonePosition.X, 0, def.ZonePosition.Z)).Magnitude < def.ZoneRadius + 8 then
			return false
		end
	end
	return true
end

local function buildNature(map)
	local nature = folder("Nature", map)
	local rng = Random.new(42) -- décor identique à chaque démarrage
	local trees, rocks, bushes, flowers = 0, 0, 0, 0
	local attempts = 0
	while (trees < 60 or rocks < 25 or bushes < 40 or flowers < 90) and attempts < 4000 do
		attempts = attempts + 1
		local position = Vector3.new(rng:NextNumber(-160, 160), 0, rng:NextNumber(-410, 110))
		if isFree(position) then
			local roll = rng:NextNumber()
			if trees < 60 and roll < 0.3 then
				buildTree(nature, position, rng)
				trees = trees + 1
			elseif rocks < 25 and roll < 0.42 then
				buildRock(nature, position, rng)
				rocks = rocks + 1
			elseif bushes < 40 and roll < 0.6 then
				buildBush(nature, position, rng)
				bushes = bushes + 1
			elseif flowers < 90 then
				buildFlower(nature, position, rng)
				flowers = flowers + 1
			end
		end
	end
end

-- Tapis roulant : bande noire, bordures grises, lamelles qui défilent (animées côté client)
local function buildConveyor(map)
	local conf = GameConfig.Conveyor
	local model = Instance.new("Model")
	model.Name = "Conveyor"
	model.Parent = map

	local direction = conf.Direction.Unit
	local look = CFrame.lookAt(conf.Center, conf.Center + direction) -- axe Z local = direction
	local beltCenter = look * CFrame.new(0, conf.BeltHeight / 2, 0)

	-- La bande : longue selon la direction
	local belt = newPart("Belt", Vector3.new(conf.Width, conf.BeltHeight, conf.Length), beltCenter, Color3.fromRGB(25, 25, 28), Enum.Material.SmoothPlastic, model)
	belt.Name = "Belt"

	-- Bordures
	local borderHeight = conf.BeltHeight + 0.7
	for _, side in ipairs({ -1, 1 }) do
		local border = newPart("Border", Vector3.new(1.4, borderHeight, conf.Length + 2.8), look * CFrame.new(side * (conf.Width / 2 + 0.7), borderHeight / 2, 0), Color3.fromRGB(125, 125, 130), Enum.Material.SmoothPlastic, model)
		border.Name = "Border"
	end
	-- Extrémités
	for _, endSide in ipairs({ -1, 1 }) do
		newPart("End", Vector3.new(conf.Width + 2.8, borderHeight, 1.4), look * CFrame.new(0, borderHeight / 2, endSide * (conf.Length / 2 + 0.7)), Color3.fromRGB(125, 125, 130), Enum.Material.SmoothPlastic, model)
	end

	-- Lamelles décoratives (déplacées par ConveyorController côté client)
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

	-- Retire la baseplate et le spawn du modèle de départ de Studio
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
	buildConveyor(map)
	buildSpawn(map)
	setupLighting()
	return map
end

return MapBuilder
