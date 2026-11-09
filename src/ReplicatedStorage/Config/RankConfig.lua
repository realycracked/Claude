--[[
	RankConfig (ModuleScript)
	Emplacement : ReplicatedStorage > Config > RankConfig

	Paliers de progression. Le rang dépend de l'argent TOTAL gagné en combat
	(les ventes d'œufs ne comptent pas). Chaque rang fixe le nombre
	maximum d'œufs équipés.
]]

local RankConfig = {}

RankConfig.List = {
	{ Id = 1, Name = "Débutant", Required = 0, MaxEquipped = 3, Color = Color3.fromRGB(200, 200, 200) },
	{ Id = 2, Name = "Chasseur", Required = 500, MaxEquipped = 3, Color = Color3.fromRGB(120, 220, 120) },
	{ Id = 3, Name = "Guerrier", Required = 5000, MaxEquipped = 4, Color = Color3.fromRGB(90, 160, 255) },
	{ Id = 4, Name = "Champion", Required = 50000, MaxEquipped = 4, Color = Color3.fromRGB(190, 90, 255) },
	{ Id = 5, Name = "Légende", Required = 500000, MaxEquipped = 5, Color = Color3.fromRGB(255, 180, 40) },
	{ Id = 6, Name = "Mythe", Required = 5000000, MaxEquipped = 6, Color = Color3.fromRGB(255, 70, 160) },
}

-- Retourne l'index du rang et sa définition
function RankConfig.GetRank(totalEarned)
	local current = RankConfig.List[1]
	for _, rank in ipairs(RankConfig.List) do
		if (totalEarned or 0) >= rank.Required then
			current = rank
		end
	end
	return current.Id, current
end

function RankConfig.GetMaxEquipped(totalEarned)
	local _, rank = RankConfig.GetRank(totalEarned)
	return rank.MaxEquipped
end

-- Prochain rang (nil si déjà au maximum)
function RankConfig.GetNextRank(totalEarned)
	local id = RankConfig.GetRank(totalEarned)
	return RankConfig.List[id + 1]
end

return RankConfig
