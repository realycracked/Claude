--[[
	EggConfig (ModuleScript)
	Emplacement : ReplicatedStorage > Config > EggConfig

	Les 6 raretés d'œufs et leurs variantes (Normal, Argent, Or).
	- Price : prix sur le tapis
	- Weight : probabilité relative d'apparition (la somme fait 100 ici)
	- DPS : dégâts par seconde ajoutés quand l'œuf est équipé
	- AttackInterval : secondes entre deux attaques de l'œuf
	  (dégâts par attaque = DPS x AttackInterval, calculé dans CombatMath)
]]

local EggConfig = {}

-- Apparence 3D des œufs : "Smooth" (œuf lisse et arrondi) ou "Blocks" (couches de blocs, comme la photo)
EggConfig.Style = "Smooth"

EggConfig.Rarities = {
	{
		Id = "Common",
		Name = "Commun",
		Price = 10,
		Weight = 50,
		DPS = 1,
		AttackInterval = 1.2,
		Color = Color3.fromRGB(236, 224, 196),
		SpotColor = Color3.fromRGB(200, 185, 150),
		Material = Enum.Material.SmoothPlastic,
		Spots = 0,
		Glow = false,
		Sparkles = false,
		Aura = false,
	},
	{
		Id = "Uncommon",
		Name = "Peu commun",
		Price = 50,
		Weight = 28,
		DPS = 3,
		AttackInterval = 1.1,
		Color = Color3.fromRGB(120, 210, 110),
		SpotColor = Color3.fromRGB(50, 140, 60),
		Material = Enum.Material.SmoothPlastic,
		Spots = 4,
		Glow = false,
		Sparkles = false,
		Aura = false,
	},
	{
		Id = "Rare",
		Name = "Rare",
		Price = 250,
		Weight = 13,
		DPS = 10,
		AttackInterval = 1.0,
		Color = Color3.fromRGB(70, 140, 255),
		SpotColor = Color3.fromRGB(190, 235, 255),
		Material = Enum.Material.SmoothPlastic,
		Spots = 6,
		Glow = true,
		Sparkles = false,
		Aura = false,
	},
	{
		Id = "Epic",
		Name = "Épique",
		Price = 1500,
		Weight = 6,
		DPS = 35,
		AttackInterval = 0.9,
		Color = Color3.fromRGB(160, 70, 230),
		SpotColor = Color3.fromRGB(255, 120, 255),
		Material = Enum.Material.Glass,
		Spots = 7,
		Glow = true,
		Sparkles = false,
		Aura = false,
	},
	{
		Id = "Legendary",
		Name = "Légendaire",
		Price = 10000,
		Weight = 2.5,
		DPS = 120,
		AttackInterval = 0.8,
		Color = Color3.fromRGB(255, 170, 30),
		SpotColor = Color3.fromRGB(255, 245, 140),
		Material = Enum.Material.Metal,
		Spots = 8,
		Glow = true,
		Sparkles = true,
		Aura = false,
	},
	{
		Id = "Mythic",
		Name = "Mythique",
		Price = 75000,
		Weight = 0.5,
		DPS = 450,
		AttackInterval = 0.7,
		Color = Color3.fromRGB(45, 10, 65),
		SpotColor = Color3.fromRGB(255, 40, 130),
		Material = Enum.Material.SmoothPlastic,
		Spots = 10,
		Glow = true,
		Sparkles = true,
		Aura = true,
	},
}

-- Variantes : Normal (sans nom), Argent, Or
EggConfig.Variants = {
	{ Id = "Normal", Name = "", Weight = 85, PriceMult = 1, PowerMult = 1, Tint = nil, Material = nil, Sparkles = false, LabelColor = Color3.fromRGB(255, 255, 255) },
	{ Id = "Silver", Name = "Argent", Weight = 12, PriceMult = 2, PowerMult = 1.5, Tint = Color3.fromRGB(215, 215, 225), Material = Enum.Material.Metal, Sparkles = false, LabelColor = Color3.fromRGB(220, 220, 235) },
	{ Id = "Gold", Name = "Or", Weight = 3, PriceMult = 4, PowerMult = 2.5, Tint = Color3.fromRGB(255, 215, 0), Material = Enum.Material.Metal, Sparkles = true, LabelColor = Color3.fromRGB(255, 220, 60) },
}

local rarityById = {}
for index, rarity in ipairs(EggConfig.Rarities) do
	rarity.Index = index
	rarityById[rarity.Id] = rarity
end

local variantById = {}
for index, variant in ipairs(EggConfig.Variants) do
	variant.Index = index
	variantById[variant.Id] = variant
end

function EggConfig.GetRarity(rarityId)
	return rarityById[rarityId]
end

function EggConfig.GetVariant(variantId)
	return variantById[variantId or "Normal"] or variantById.Normal
end

-- Prix d'achat d'un œuf (rareté + variante)
function EggConfig.GetPrice(rarityId, variantId)
	local rarity = EggConfig.GetRarity(rarityId)
	local variant = EggConfig.GetVariant(variantId)
	if not rarity then
		return 0
	end
	return math.floor(rarity.Price * variant.PriceMult)
end

-- DPS apporté par un œuf équipé
function EggConfig.GetDPS(rarityId, variantId)
	local rarity = EggConfig.GetRarity(rarityId)
	local variant = EggConfig.GetVariant(variantId)
	if not rarity then
		return 0
	end
	return rarity.DPS * variant.PowerMult
end

-- Nom affiché : "Œuf Rare Argent"
function EggConfig.GetDisplayName(rarityId, variantId)
	local rarity = EggConfig.GetRarity(rarityId)
	local variant = EggConfig.GetVariant(variantId)
	if not rarity then
		return "Œuf inconnu"
	end
	local name = "Œuf " .. rarity.Name
	if variant.Name ~= "" then
		name = name .. " " .. variant.Name
	end
	return name
end

-- Clé utilisée par l'Index (collection) : "Rare_Silver"
function EggConfig.GetIndexKey(rarityId, variantId)
	return rarityId .. "_" .. (variantId or "Normal")
end

local function weightedRoll(list, random)
	local total = 0
	for _, entry in ipairs(list) do
		total = total + entry.Weight
	end
	local roll = random:NextNumber() * total
	for _, entry in ipairs(list) do
		roll = roll - entry.Weight
		if roll <= 0 then
			return entry
		end
	end
	return list[#list]
end

function EggConfig.RollRarity(random)
	return weightedRoll(EggConfig.Rarities, random)
end

function EggConfig.RollVariant(random)
	return weightedRoll(EggConfig.Variants, random)
end

return EggConfig
