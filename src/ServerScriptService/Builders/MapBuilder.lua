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

-- Un arbre low poly : tronc + 3 blocs de feuillage
local function buildTree(parent, position, rng)
	local scale = rng:NextNumber(0.8, 1.4)
	local rotation = CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	local trunk = newPart("Trunk", Vector3.new(1.4, 6, 1.4) * scale, CFrame.new(position + Vector3.new(0, 3 * scale, 0)) * rotation, Color3.fromRGB(120, 80, 45), Enum.Material.Wood, parent)
	local greens = {
		Color3.fromRGB(60, 160, 70),
		Color3.fromRGB(75, 185, 80),
		Color3.fromRGB(95, 205, 95),
	}
	local sizes = { 7, 5.2, 3.4 }
	local heights = { 1.6, 2.2, 2.2 }
	local y = 6 * scale
	for i = 1, 3 do
		local size = Vector3.new(sizes[i], heights[i], sizes[i]) * scale
		local twist = CFrame.Angles(0, math.rad(i * 25), 0)
		newPart("Leaves", size, CFrame.new(position + Vector3.new(0, y + size.Y / 2, 0)) * rotation * twist, greens[i], Enum.Material.SmoothPlastic, parent)
		y = y + size.Y
	end
	return trunk
end

local function buildRock(parent, position, rng)
	local size = Vector3.new(rng:NextNumber(2.5, 6), rng:NextNumber(1.8, 4), rng:NextNumber(2.5, 6))
	local rotation = CFrame.Angles(math.rad(rng:NextNumber(-12, 12)), rng:NextNumber(0, math.pi * 2), math.rad(rng:NextNumber(-12, 12)))
	local grey = 110 + rng:NextInteger(-15, 20)
	newPart("Rock", size, CFrame.new(position + Vector3.new(0, size.Y * 0.35, 0)) * rotation, Color3.fromRGB(grey, grey, grey + 8), Enum.Material.Slate, parent)
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
	local trees, rocks = 0, 0
	local attempts = 0
	while (trees < 70 or rocks < 30) and attempts < 2000 do
		attempts = attempts + 1
		local position = Vector3.new(rng:NextNumber(-160, 160), 0, rng:NextNumber(-410, 110))
		if isFree(position) then
			if trees < 70 and rng:NextNumber() < 0.7 then
				buildTree(nature, position, rng)
				trees = trees + 1
			elseif rocks < 30 then
				buildRock(nature, position, rng)
				rocks = rocks + 1
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
