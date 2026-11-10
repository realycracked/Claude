--[[
	SlimeConfig (ModuleScript)
	Emplacement : ReplicatedStorage > Config > SlimeConfig

	Les 6 catégories de slimes. Chaque catégorie possède sa propre zone sur la map.
	- Health : points de vie
	- Reward : argent donné à la mort (réparti selon les dégâts de chacun)
	- Size : diamètre du slime (studs)
	- Count : nombre de slimes dans la zone
	- RespawnTime : secondes avant réapparition
	- ZonePosition / ZoneRadius : emplacement de la zone sur la map
]]

local SlimeConfig = {}

SlimeConfig.List = {
	{
		Id = "Weak",
		Name = "Slime faible",
		Health = 20,
		Reward = 3,
		Size = 3,
		Color = Color3.fromRGB(170, 240, 120),
		EyeColor = Color3.fromRGB(20, 20, 20),
		Count = 5,
		RespawnTime = 4,
		HopInterval = 2.5,
		WanderRadius = 12,
		ZonePosition = Vector3.new(0, 0, -30),
		ZoneRadius = 22,
	},
	{
		Id = "Basic",
		Name = "Slime basique",
		Health = 100,
		Reward = 12,
		Size = 4,
		Color = Color3.fromRGB(80, 200, 80),
		EyeColor = Color3.fromRGB(20, 20, 20),
		Count = 5,
		RespawnTime = 5,
		HopInterval = 2.5,
		WanderRadius = 13,
		ZonePosition = Vector3.new(0, 0, -95),
		ZoneRadius = 24,
	},
	{
		Id = "Hard",
		Name = "Slime difficile",
		Health = 600,
		Reward = 60,
		Size = 5,
		Color = Color3.fromRGB(70, 140, 255),
		EyeColor = Color3.fromRGB(20, 20, 20),
		Count = 4,
		RespawnTime = 7,
		HopInterval = 2.2,
		WanderRadius = 14,
		ZonePosition = Vector3.new(0, 0, -160),
		ZoneRadius = 26,
	},
	{
		Id = "VeryHard",
		Name = "Slime très difficile",
		Health = 4000,
		Reward = 350,
		Size = 6.5,
		Color = Color3.fromRGB(160, 70, 230),
		EyeColor = Color3.fromRGB(255, 255, 255),
		Count = 4,
		RespawnTime = 10,
		HopInterval = 2.2,
		WanderRadius = 15,
		ZonePosition = Vector3.new(0, 0, -230),
		ZoneRadius = 28,
	},
	{
		Id = "Mega",
		Name = "Slime méga difficile",
		Health = 30000,
		Reward = 2200,
		Size = 8,
		Color = Color3.fromRGB(255, 90, 60),
		EyeColor = Color3.fromRGB(255, 230, 80),
		Count = 3,
		RespawnTime = 15,
		HopInterval = 2,
		WanderRadius = 16,
		ZonePosition = Vector3.new(0, 0, -305),
		ZoneRadius = 30,
	},
	{
		Id = "Boss",
		Name = "Boss Slime",
		Health = 250000,
		Reward = 15000,
		Size = 13,
		Color = Color3.fromRGB(45, 45, 60),
		EyeColor = Color3.fromRGB(255, 200, 0),
		Count = 1,
		RespawnTime = 60,
		HopInterval = 3,
		WanderRadius = 12,
		ZonePosition = Vector3.new(0, 0, -385),
		ZoneRadius = 32,
	},
}

-- Apparence propre à chaque catégorie : bien plus que la taille et la couleur.
--  Eyes : nombre d'yeux · Brows : sourcils en colère · Blush : joues roses · Leaf : pousse sur la tête
--  Spots : taches · Crystals : cristaux de glace · Horns : cornes · Spikes : pointes · Cracks : fissures lumineuses
--  Armor : plaques dorées · Crown : couronne · Particles : "Frost" / "Shadow" / "Fire" / "Embers"
--  Light : couleur de la lumière émise · Aura : couleur de l'aura · EyeGlow : pupilles lumineuses
SlimeConfig.Looks = {
	Weak = { Eyes = 2, Blush = true },
	Basic = { Eyes = 2, Leaf = true, Spots = 4 },
	Hard = { Eyes = 2, Brows = true, Crystals = 6, CrystalColor = Color3.fromRGB(185, 235, 255), Particles = "Frost", Light = Color3.fromRGB(150, 220, 255) },
	VeryHard = { Eyes = 3, Brows = true, Horns = true, Particles = "Shadow", Aura = Color3.fromRGB(190, 90, 255) },
	Mega = { Eyes = 2, Brows = true, Spikes = 8, Cracks = 7, CrackColor = Color3.fromRGB(255, 130, 20), Particles = "Fire", Light = Color3.fromRGB(255, 120, 40), EyeGlow = true },
	Boss = { Eyes = 4, Brows = true, Crown = true, Armor = true, Spikes = 10, Cracks = 9, CrackColor = Color3.fromRGB(255, 50, 50), Particles = "Embers", Light = Color3.fromRGB(255, 60, 60), EyeGlow = true, Aura = Color3.fromRGB(255, 70, 70) },
}

function SlimeConfig.GetLook(id)
	return SlimeConfig.Looks[id] or {}
end

local byId = {}
for index, def in ipairs(SlimeConfig.List) do
	def.Index = index
	byId[def.Id] = def
end

function SlimeConfig.Get(id)
	return byId[id]
end

return SlimeConfig
