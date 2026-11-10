--[[
	SwordConfig (ModuleScript)
	Emplacement : ReplicatedStorage > Config > SwordConfig

	Les 6 épées. Le joueur commence avec "Wood" (gratuite).
	- DPS : dégâts par seconde de l'épée
	  (la cadence dépend du palier de DPS total, voir CombatMath ;
	   dégâts par coup = DPS x intervalle, donc le DPS est toujours respecté)
	- Range : portée d'attaque (studs)
]]

local SwordConfig = {}

SwordConfig.DefaultSword = "Wood"

SwordConfig.List = {
	{
		Id = "Wood",
		Name = "Épée en bois",
		Price = 0,
		DPS = 5,
		Range = 10,
		Style = {
			BladeColor = Color3.fromRGB(165, 115, 60),
			GuardColor = Color3.fromRGB(110, 70, 35),
			GripColor = Color3.fromRGB(70, 45, 25),
			Material = Enum.Material.Wood,
			Length = 2.4,
			Glow = nil,
		},
	},
	{
		Id = "Iron",
		Name = "Épée en fer",
		Price = 75,
		DPS = 15,
		Range = 10,
		Style = {
			BladeColor = Color3.fromRGB(190, 190, 200),
			GuardColor = Color3.fromRGB(90, 90, 100),
			GripColor = Color3.fromRGB(60, 40, 30),
			Material = Enum.Material.Metal,
			Length = 2.6,
			Glow = nil,
		},
	},
	{
		Id = "Steel",
		Name = "Épée en acier",
		Price = 600,
		DPS = 45,
		Range = 11,
		Style = {
			BladeColor = Color3.fromRGB(225, 230, 240),
			GuardColor = Color3.fromRGB(40, 60, 130),
			GripColor = Color3.fromRGB(30, 30, 40),
			Material = Enum.Material.Metal,
			Length = 2.8,
			Glow = nil,
		},
	},
	{
		Id = "Crystal",
		Name = "Épée de cristal",
		Price = 4500,
		DPS = 150,
		Range = 11,
		Style = {
			BladeColor = Color3.fromRGB(120, 220, 255),
			GuardColor = Color3.fromRGB(60, 120, 200),
			GripColor = Color3.fromRGB(30, 50, 90),
			Material = Enum.Material.Glass,
			Length = 3.0,
			Glow = Color3.fromRGB(120, 220, 255),
		},
	},
	{
		Id = "Dragon",
		Name = "Épée du dragon",
		Price = 35000,
		DPS = 500,
		Range = 12,
		Style = {
			BladeColor = Color3.fromRGB(255, 90, 40),
			GuardColor = Color3.fromRGB(120, 20, 20),
			GripColor = Color3.fromRGB(40, 10, 10),
			Material = Enum.Material.Metal,
			Length = 3.3,
			Glow = Color3.fromRGB(255, 120, 40),
		},
	},
	{
		Id = "Mythic",
		Name = "Épée mythique",
		Price = 280000,
		DPS = 1800,
		Range = 12,
		Style = {
			BladeColor = Color3.fromRGB(255, 60, 200),
			GuardColor = Color3.fromRGB(40, 0, 60),
			GripColor = Color3.fromRGB(20, 0, 30),
			Material = Enum.Material.Neon,
			Length = 3.6,
			Glow = Color3.fromRGB(255, 80, 220),
		},
	},
}

local byId = {}
for index, def in ipairs(SwordConfig.List) do
	def.Index = index
	byId[def.Id] = def
end

function SwordConfig.Get(id)
	return byId[id]
end

return SwordConfig
