--[[
	CombatMath (ModuleScript)
	Emplacement : ReplicatedStorage > Shared > CombatMath

	Calculs de combat partagés par le serveur ET le client.
	Règle d'or : on part toujours du DPS, puis dégâts par coup = DPS x intervalle.
	Le DPS n'est donc jamais multiplié deux fois.

	Paliers (Tiers) : plus le DPS total du joueur est élevé, plus l'épée frappe vite
	et plus les effets visuels sont impressionnants. L'intervalle minimum est 0.22 s
	pour que les animations restent lisibles.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EggConfig = require(ReplicatedStorage.Config.EggConfig)
local SwordConfig = require(ReplicatedStorage.Config.SwordConfig)

local CombatMath = {}

CombatMath.Tiers = {
	{ MinDPS = 0, Interval = 0.60, Name = "Novice" },
	{ MinDPS = 25, Interval = 0.50, Name = "Combattant" },
	{ MinDPS = 120, Interval = 0.42, Name = "Vétéran" },
	{ MinDPS = 600, Interval = 0.34, Name = "Maître" },
	{ MinDPS = 2500, Interval = 0.27, Name = "Légende" },
	{ MinDPS = 10000, Interval = 0.22, Name = "Mythique" }, -- vitesse maximale
}

-- Retrouve un œuf du profil par son identifiant
function CombatMath.FindEgg(profile, eggId)
	for _, item in ipairs(profile.Eggs) do
		if item.Id == eggId then
			return item
		end
	end
	return nil
end

function CombatMath.GetEggItemDPS(item)
	return EggConfig.GetDPS(item.Rarity, item.Variant)
end

-- Liste des œufs équipés (objets complets)
function CombatMath.GetEquippedEggs(profile)
	local list = {}
	for _, eggId in ipairs(profile.Equipped) do
		local item = CombatMath.FindEgg(profile, eggId)
		if item then
			table.insert(list, item)
		end
	end
	return list
end

function CombatMath.GetEggsDPS(profile)
	local total = 0
	for _, item in ipairs(CombatMath.GetEquippedEggs(profile)) do
		total = total + CombatMath.GetEggItemDPS(item)
	end
	return total
end

function CombatMath.GetSwordDPS(profile)
	local sword = SwordConfig.Get(profile.EquippedSword) or SwordConfig.Get(SwordConfig.DefaultSword)
	return sword.DPS
end

function CombatMath.GetTotalDPS(profile)
	return CombatMath.GetSwordDPS(profile) + CombatMath.GetEggsDPS(profile)
end

-- Palier d'après le DPS total -> index, définition
function CombatMath.GetTier(totalDPS)
	local index = 1
	for i, tier in ipairs(CombatMath.Tiers) do
		if totalDPS >= tier.MinDPS then
			index = i
		end
	end
	return index, CombatMath.Tiers[index]
end

-- Attaque à l'épée : dégâts par coup, intervalle entre deux coups, palier
function CombatMath.GetSwordAttack(profile)
	local swordDPS = CombatMath.GetSwordDPS(profile)
	local tierIndex, tier = CombatMath.GetTier(CombatMath.GetTotalDPS(profile))
	local interval = tier.Interval
	local damage = swordDPS * interval
	return damage, interval, tierIndex
end

-- Attaque d'un œuf : dégâts par attaque, intervalle entre deux attaques
function CombatMath.GetEggAttack(item)
	local rarity = EggConfig.GetRarity(item.Rarity)
	local interval = rarity and rarity.AttackInterval or 1
	local damage = CombatMath.GetEggItemDPS(item) * interval
	return damage, interval
end

return CombatMath
