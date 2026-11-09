--[[
	ClientState (ModuleScript)
	Emplacement : StarterPlayer > StarterPlayerScripts > Controllers > ClientState

	Garde la copie locale du profil du joueur et envoie les requêtes au serveur.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local ClientState = {}
ClientState.Profile = nil

local listeners = {}
local request = nil

-- Appelle fn(profile) à chaque mise à jour (et tout de suite si le profil est déjà connu)
function ClientState.OnChanged(fn)
	table.insert(listeners, fn)
	if ClientState.Profile then
		task.spawn(fn, ClientState.Profile)
	end
end

local function setProfile(profile)
	ClientState.Profile = profile
	for _, fn in ipairs(listeners) do
		task.spawn(fn, profile)
	end
end

-- Envoie une action au serveur. Retourne { ok, message, data }.
function ClientState.Request(action, payload)
	local success, result = pcall(request.InvokeServer, request, action, payload or {})
	if not success then
		return { ok = false, message = "Erreur de connexion" }
	end
	if type(result) ~= "table" then
		return { ok = false, message = "Réponse invalide" }
	end
	return result
end

function ClientState.Init()
	request = Remotes.Get("Request")
	Remotes.Get("ProfileUpdated").OnClientEvent:Connect(setProfile)

	-- Demande le profil jusqu'à l'obtenir (le serveur peut encore être en train de charger)
	task.spawn(function()
		while ClientState.Profile == nil do
			local result = ClientState.Request("GetProfile")
			if result.ok and result.data then
				setProfile(result.data)
				break
			end
			task.wait(1)
		end
	end)
end

return ClientState
