--[[
	MapConfig (ModuleScript)
	Emplacement : ReplicatedStorage > Config > MapConfig

	Réglages du décor : sol, barrières, nuages, arbres et quantités de décor.
]]

local MapConfig = {}

-- Sol (pas d'herbe : plastique lisse vert, style low poly)
MapConfig.Ground = {
	Center = Vector3.new(0, -1, -150),
	Size = Vector3.new(340, 2, 540),
	Color = Color3.fromRGB(96, 200, 90),
	Material = Enum.Material.SmoothPlastic,
}

MapConfig.PathColor = Color3.fromRGB(222, 200, 160)

-- Styles d'arbres utilisés sur la map (mélange possible) :
--  "A" boules étagées · "B" low poly facetté · "C" sapin à étages · "D" parasol/acacia · "E" palmier
MapConfig.TreeStyles = { "A", "B", "D" }

-- Quantités de décor
MapConfig.Decor = {
	Trees = 60,
	Rocks = 25,
	Bushes = 40,
	Flowers = 80,
}

-- Barrière low poly tout autour de la map (+ murs invisibles pour ne pas tomber)
MapConfig.Fence = {
	Enabled = true,
	Inset = 5, -- distance entre le bord du sol et la barrière
	PostSpacing = 6,
	PostSize = Vector3.new(1, 4.2, 1),
	PostColor = Color3.fromRGB(118, 78, 42),
	RailHeights = { 1.5, 3.1 },
	RailSize = Vector3.new(0.45, 0.55, 0), -- (épaisseur, hauteur, longueur calculée)
	RailColor = Color3.fromRGB(160, 112, 62),
	WallHeight = 40,
}

-- Nuages low poly (déplacés lentement par le client)
MapConfig.Clouds = {
	Count = 22,
	MinHeight = 75,
	MaxHeight = 115,
	Speed = 1.2, -- studs / seconde
	Color = Color3.fromRGB(255, 255, 255),
}

return MapConfig
