--[[
	InventoryService (ModuleScript)
	Emplacement : ServerScriptService > Services > InventoryService

	Œufs possédés : ajout (achat), équiper / retirer, "Équiper les meilleurs", vente.
	Toutes les vérifications sont faites ici, côté serveur.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local EggConfig = require(ReplicatedStorage.Config.EggConfig)
local RankConfig = require(ReplicatedStorage.Config.RankConfig)
local CombatMath = require(ReplicatedStorage.Shared.CombatMath)
local Util = require(ReplicatedStorage.Shared.Util)

local DataService = require(ServerScriptService.Services.DataService)
local PlayerService = require(ServerScriptService.Services.PlayerService)
local CompanionService = require(ServerScriptService.Services.CompanionService)
local RequestRouter = require(ServerScriptService.Services.RequestRouter)

local InventoryService = {}

local function isEquipped(profile, eggId)
	return table.find(profile.Equipped, eggId) ~= nil
end

local function unequip(profile, eggId)
	local index = table.find(profile.Equipped, eggId)
	if index then
		table.remove(profile.Equipped, index)
		return true
	end
	return false
end

function InventoryService.GetMaxEquipped(profile)
	return RankConfig.GetMaxEquipped(profile.TotalEarned)
end

-- Prix de revente d'un œuf
function InventoryService.GetSellPrice(item)
	return math.max(1, math.floor(EggConfig.GetPrice(item.Rarity, item.Variant) * GameConfig.Sell.RefundRatio))
end

-- Ajoute un œuf au profil (après un achat validé). Équipe automatiquement s'il reste une place.
function InventoryService.AddEgg(player, rarityId, variantId)
	local profile = DataService.Get(player)
	if not profile then
		return nil
	end
	local item = { Id = "e" .. profile.NextEggId, Rarity = rarityId, Variant = variantId }
	profile.NextEggId = profile.NextEggId + 1
	table.insert(profile.Eggs, item)
	profile.Discovered[EggConfig.GetIndexKey(rarityId, variantId)] = true

	if #profile.Equipped < InventoryService.GetMaxEquipped(profile) then
		table.insert(profile.Equipped, item.Id)
	end
	CompanionService.Refresh(player)
	PlayerService.Push(player)
	return item
end

local function finish(player)
	CompanionService.Refresh(player)
	PlayerService.Push(player)
end

function InventoryService.Init()
	RequestRouter.Register("EquipEgg", function(player, payload)
		local profile = DataService.Get(player)
		if not profile then
			return false, "Profil non chargé"
		end
		local item = type(payload.id) == "string" and CombatMath.FindEgg(profile, payload.id)
		if not item then
			return false, "Œuf introuvable"
		end
		if isEquipped(profile, item.Id) then
			return false, "Déjà équipé"
		end
		local max = InventoryService.GetMaxEquipped(profile)
		if #profile.Equipped >= max then
			return false, "Limite atteinte : " .. max .. " œufs équipés (monte en rang pour en équiper plus)"
		end
		table.insert(profile.Equipped, item.Id)
		finish(player)
		return true, EggConfig.GetDisplayName(item.Rarity, item.Variant) .. " équipé"
	end)

	RequestRouter.Register("UnequipEgg", function(player, payload)
		local profile = DataService.Get(player)
		if not profile then
			return false, "Profil non chargé"
		end
		if type(payload.id) ~= "string" or not unequip(profile, payload.id) then
			return false, "Cet œuf n'est pas équipé"
		end
		finish(player)
		return true, "Œuf retiré"
	end)

	RequestRouter.Register("EquipBest", function(player)
		local profile = DataService.Get(player)
		if not profile then
			return false, "Profil non chargé"
		end
		local sorted = table.clone(profile.Eggs)
		table.sort(sorted, function(a, b)
			return CombatMath.GetEggItemDPS(a) > CombatMath.GetEggItemDPS(b)
		end)
		local max = InventoryService.GetMaxEquipped(profile)
		profile.Equipped = {}
		for i = 1, math.min(max, #sorted) do
			table.insert(profile.Equipped, sorted[i].Id)
		end
		finish(player)
		return true, "Meilleurs œufs équipés (" .. #profile.Equipped .. "/" .. max .. ")"
	end)

	RequestRouter.Register("SellEgg", function(player, payload)
		local profile = DataService.Get(player)
		if not profile then
			return false, "Profil non chargé"
		end
		local item = type(payload.id) == "string" and CombatMath.FindEgg(profile, payload.id)
		if not item then
			return false, "Œuf introuvable"
		end
		local price = InventoryService.GetSellPrice(item)
		unequip(profile, item.Id)
		table.remove(profile.Eggs, table.find(profile.Eggs, item))
		PlayerService.AddCash(player, price, false)
		finish(player)
		return true, EggConfig.GetDisplayName(item.Rarity, item.Variant) .. " vendu pour " .. Util.FormatNumber(price) .. " $"
	end)

	RequestRouter.Register("SellUnequipped", function(player)
		local profile = DataService.Get(player)
		if not profile then
			return false, "Profil non chargé"
		end
		local total, count = 0, 0
		local kept = {}
		for _, item in ipairs(profile.Eggs) do
			if isEquipped(profile, item.Id) then
				table.insert(kept, item)
			else
				total = total + InventoryService.GetSellPrice(item)
				count = count + 1
			end
		end
		if count == 0 then
			return false, "Aucun œuf non équipé à vendre"
		end
		profile.Eggs = kept
		PlayerService.AddCash(player, total, false)
		finish(player)
		return true, count .. " œuf(s) vendu(s) pour " .. Util.FormatNumber(total) .. " $"
	end)
end

return InventoryService
