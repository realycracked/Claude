--[[
	RequestRouter (ModuleScript)
	Emplacement : ServerScriptService > Services > RequestRouter

	Une seule RemoteFunction "Request" pour toutes les actions du client.
	Chaque service enregistre ses actions :  Router.Register("BuySword", function(player, payload) ... end)
	Le gestionnaire retourne : ok (bool), message (texte), data (facultatif).
	Le client reçoit toujours une table { ok = ..., message = ..., data = ... }.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local RequestRouter = {}

local handlers = {}
local lastRequest = {} -- anti-spam : [player] = os.clock()

function RequestRouter.Register(action, handler)
	handlers[action] = handler
end

function RequestRouter.Init()
	local request = Remotes.Get("Request")
	request.OnServerInvoke = function(player, action, payload)
		if type(action) ~= "string" then
			return { ok = false, message = "Requête invalide" }
		end
		local now = os.clock()
		if now - (lastRequest[player] or 0) < 0.05 then
			return { ok = false, message = "Trop rapide !" }
		end
		lastRequest[player] = now

		local handler = handlers[action]
		if not handler then
			return { ok = false, message = "Action inconnue : " .. action }
		end
		if type(payload) ~= "table" then
			payload = {}
		end

		local success, ok, message, data = pcall(handler, player, payload)
		if not success then
			warn("[RequestRouter] Erreur dans " .. action .. " : " .. tostring(ok))
			return { ok = false, message = "Erreur serveur" }
		end
		return { ok = ok and true or false, message = message, data = data }
	end

	game:GetService("Players").PlayerRemoving:Connect(function(player)
		lastRequest[player] = nil
	end)
end

return RequestRouter
