--[[
	ShopService (ModuleScript)
	Emplacement : ServerScriptService > Services > ShopService

	Boutique : achat / équipement des épées et des effets d'attaque (cosmétiques).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local SwordConfig = require(ReplicatedStorage.Config.SwordConfig)
local EffectConfig = require(ReplicatedStorage.Config.EffectConfig)
local Util = require(ReplicatedStorage.Shared.Util)

local DataService = require(ServerScriptService.Services.DataService)
local PlayerService = require(ServerScriptService.Services.PlayerService)
local RequestRouter = require(ServerScriptService.Services.RequestRouter)
local SwordBuilder = require(ServerScriptService.Builders.SwordBuilder)

local ShopService = {}

local function equipSword(player, profile, swordId)
	profile.EquippedSword = swordId
	if player.Character then
		SwordBuilder.Attach(player.Character, swordId, profile.EquippedEffect)
	end
	PlayerService.Push(player)
end

local function equipEffect(player, profile, effectId)
	profile.EquippedEffect = effectId or ""
	if player.Character then
		SwordBuilder.ApplyEffect(player.Character, profile.EquippedEffect)
	end
	PlayerService.Push(player)
end

function ShopService.Init()
	RequestRouter.Register("BuySword", function(player, payload)
		local profile = DataService.Get(player)
		if not profile then
			return false, "Profil non chargé"
		end
		local def = type(payload.id) == "string" and SwordConfig.Get(payload.id)
		if not def then
			return false, "Épée inconnue"
		end
		if table.find(profile.Swords, def.Id) then
			return false, "Tu possèdes déjà cette épée"
		end
		if not PlayerService.SpendCash(player, def.Price) then
			return false, "Pas assez d'argent (" .. Util.FormatNumber(def.Price) .. " $)"
		end
		table.insert(profile.Swords, def.Id)
		equipSword(player, profile, def.Id)
		return true, def.Name .. " achetée et équipée !"
	end)

	RequestRouter.Register("EquipSword", function(player, payload)
		local profile = DataService.Get(player)
		if not profile then
			return false, "Profil non chargé"
		end
		local def = type(payload.id) == "string" and SwordConfig.Get(payload.id)
		if not def or not table.find(profile.Swords, def.Id) then
			return false, "Tu ne possèdes pas cette épée"
		end
		equipSword(player, profile, def.Id)
		return true, def.Name .. " équipée"
	end)

	RequestRouter.Register("BuyEffect", function(player, payload)
		local profile = DataService.Get(player)
		if not profile then
			return false, "Profil non chargé"
		end
		local def = type(payload.id) == "string" and EffectConfig.Get(payload.id)
		if not def then
			return false, "Effet inconnu"
		end
		if table.find(profile.Effects, def.Id) then
			return false, "Tu possèdes déjà cet effet"
		end
		if not PlayerService.SpendCash(player, def.Price) then
			return false, "Pas assez d'argent (" .. Util.FormatNumber(def.Price) .. " $)"
		end
		table.insert(profile.Effects, def.Id)
		equipEffect(player, profile, def.Id)
		return true, "Effet " .. def.Name .. " acheté et équipé (cosmétique)"
	end)

	-- id = "" ou absent pour retirer l'effet
	RequestRouter.Register("EquipEffect", function(player, payload)
		local profile = DataService.Get(player)
		if not profile then
			return false, "Profil non chargé"
		end
		if payload.id == nil or payload.id == "" then
			equipEffect(player, profile, "")
			return true, "Effet retiré"
		end
		local def = type(payload.id) == "string" and EffectConfig.Get(payload.id)
		if not def or not table.find(profile.Effects, def.Id) then
			return false, "Tu ne possèdes pas cet effet"
		end
		equipEffect(player, profile, def.Id)
		return true, "Effet " .. def.Name .. " équipé"
	end)
end

return ShopService
