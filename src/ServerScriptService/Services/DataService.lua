--[[
	DataService (ModuleScript)
	Emplacement : ServerScriptService > Services > DataService

	Chargement / sauvegarde des profils avec DataStoreService.
	- Si le chargement échoue, le joueur joue avec un profil vide MAIS la sauvegarde
	  est désactivée pour la session (pour ne jamais écraser une vraie sauvegarde).
	- Sauvegarde automatique, à la déconnexion et à la fermeture du serveur.

	Dans Studio : Game Settings > Security > "Enable Studio Access to API Services"
	doit être coché pour que les DataStores fonctionnent en test.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local SwordConfig = require(ReplicatedStorage.Config.SwordConfig)
local Util = require(ReplicatedStorage.Shared.Util)

local DataService = {}

local store = nil
local sessions = {} -- [player] = { Data = table, Loaded = boolean }

-- Profil d'un nouveau joueur
local function defaultProfile()
	return {
		Cash = GameConfig.StartCash,
		TotalEarned = 0, -- argent total gagné en combat (sert pour les rangs)
		Kills = 0,
		Eggs = {}, -- { {Id = "e1", Rarity = "Common", Variant = "Normal"}, ... }
		NextEggId = 1,
		Equipped = {}, -- identifiants des œufs équipés
		Swords = { SwordConfig.DefaultSword },
		EquippedSword = SwordConfig.DefaultSword,
		Effects = {},
		EquippedEffect = "",
		Discovered = {}, -- ["Common_Normal"] = true
	}
end

local function keyFor(player)
	return "player_" .. player.UserId
end

function DataService.Init()
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(GameConfig.Data.StoreName)
	end)
	if ok then
		store = result
	else
		warn("[DataService] DataStore indisponible : " .. tostring(result))
	end

	Players.PlayerRemoving:Connect(function(player)
		DataService.Save(player)
		sessions[player] = nil
	end)

	game:BindToClose(function()
		local remaining = 0
		for player in pairs(sessions) do
			remaining = remaining + 1
			task.spawn(function()
				DataService.Save(player)
				remaining = remaining - 1
			end)
		end
		local start = os.clock()
		while remaining > 0 and os.clock() - start < 25 do
			task.wait(0.1)
		end
	end)

	-- Sauvegarde automatique
	task.spawn(function()
		while true do
			task.wait(GameConfig.Data.AutosaveInterval)
			for player in pairs(sessions) do
				DataService.Save(player)
				task.wait(0.5)
			end
		end
	end)
end

-- Charge le profil (bloquant). Retourne la session { Data, Loaded }.
function DataService.Load(player)
	local session = { Data = defaultProfile(), Loaded = false }
	sessions[player] = session

	if not store then
		warn("[DataService] Pas de DataStore : " .. player.Name .. " joue sans sauvegarde.")
		return session
	end

	local success, data = false, nil
	for attempt = 1, GameConfig.Data.LoadRetries do
		success, data = pcall(store.GetAsync, store, keyFor(player))
		if success then
			break
		end
		warn(string.format("[DataService] Échec chargement %s (essai %d) : %s", player.Name, attempt, tostring(data)))
		task.wait(attempt)
	end

	-- Le joueur est parti pendant le chargement
	if sessions[player] ~= session then
		return session
	end

	if success then
		if type(data) == "table" then
			session.Data = Util.Reconcile(data, defaultProfile())
		end
		session.Loaded = true
	else
		warn("[DataService] Sauvegarde DÉSACTIVÉE pour " .. player.Name .. " (chargement impossible).")
	end
	return session
end

function DataService.Get(player)
	local session = sessions[player]
	return session and session.Data or nil
end

function DataService.IsLoaded(player)
	local session = sessions[player]
	return session ~= nil and session.Loaded
end

function DataService.Save(player)
	local session = sessions[player]
	if not session or not session.Loaded or not store then
		return false
	end
	local data = session.Data
	local ok, err = pcall(store.UpdateAsync, store, keyFor(player), function()
		return data
	end)
	if not ok then
		warn("[DataService] Échec sauvegarde " .. player.Name .. " : " .. tostring(err))
	end
	return ok
end

return DataService
