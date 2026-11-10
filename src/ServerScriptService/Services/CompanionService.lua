--[[
	CompanionService (ModuleScript)
	Emplacement : ServerScriptService > Services > CompanionService

	Crée les modèles 3D des œufs équipés dans Workspace > Companions > <NomDuJoueur>.
	Le mouvement (suivi fluide + flottement) est calculé par chaque client
	(CompanionController) : le serveur ne fait que créer / supprimer les modèles.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local EggBuilder = require(ReplicatedStorage.Shared.EggBuilder)
local CombatMath = require(ReplicatedStorage.Shared.CombatMath)
local DataService = require(ServerScriptService.Services.DataService)

local CompanionService = {}

local root = workspace:WaitForChild("Companions")

local function getFolder(player)
	local folder = root:FindFirstChild(player.Name)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = player.Name
		folder.Parent = root
	end
	return folder
end

-- Reconstruit les compagnons d'après la liste des œufs équipés
function CompanionService.Refresh(player)
	local profile = DataService.Get(player)
	if not profile then
		return
	end
	local folder = getFolder(player)
	folder:ClearAllChildren()

	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	local baseCFrame = hrp and hrp.CFrame or CFrame.new(GameConfig.SpawnPosition)

	for slot, eggId in ipairs(profile.Equipped) do
		local item = CombatMath.FindEgg(profile, eggId)
		if item then
			local model = EggBuilder.Build(item.Rarity, item.Variant, GameConfig.Companion.Scale)
			model.Name = "Companion_" .. eggId
			model:SetAttribute("Owner", player.UserId)
			model:SetAttribute("Slot", slot)
			model:SetAttribute("EggId", eggId)
			local offset = GameConfig.Companion.Offsets[slot] or GameConfig.Companion.Offsets[#GameConfig.Companion.Offsets]
			model:PivotTo(baseCFrame * CFrame.new(offset))
			model.Parent = folder
		end
	end
end

function CompanionService.Remove(player)
	local folder = root:FindFirstChild(player.Name)
	if folder then
		folder:Destroy()
	end
end

return CompanionService
