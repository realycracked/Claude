--[[
	Remotes (ModuleScript)
	Emplacement : ReplicatedStorage > Shared > Remotes

	Crée (côté serveur) et retrouve (des deux côtés) les RemoteEvents / RemoteFunctions.
	Rien à créer à la main : le serveur fabrique le dossier ReplicatedStorage.Remotes au démarrage.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = {}

local FOLDER_NAME = "Remotes"

-- Serveur -> client ou client -> serveur (sans réponse)
local EVENTS = {
	"ProfileUpdated", -- serveur -> client : nouvelle copie du profil (argent, œufs, ...)
	"Attack", -- client -> serveur : le joueur frappe un slime
	"AttackVFX", -- serveur -> tous : un joueur a touché un slime (animation + impact)
	"CompanionAttack", -- serveur -> tous : un œuf compagnon a attaqué
	"Notify", -- serveur -> client : message à afficher
}

-- Client -> serveur avec réponse
local FUNCTIONS = {
	"Request", -- toutes les actions (acheter, équiper, vendre, ...)
}

function Remotes.Init()
	local folder = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = FOLDER_NAME
		folder.Parent = ReplicatedStorage
	end
	for _, name in ipairs(EVENTS) do
		if not folder:FindFirstChild(name) then
			local event = Instance.new("RemoteEvent")
			event.Name = name
			event.Parent = folder
		end
	end
	for _, name in ipairs(FUNCTIONS) do
		if not folder:FindFirstChild(name) then
			local func = Instance.new("RemoteFunction")
			func.Name = name
			func.Parent = folder
		end
	end
end

function Remotes.Get(name)
	local folder = ReplicatedStorage:WaitForChild(FOLDER_NAME, 60)
	if not folder then
		error("Dossier Remotes introuvable : le script Main du serveur a-t-il démarré ?")
	end
	local remote = folder:WaitForChild(name, 60)
	if not remote then
		error("Remote introuvable : " .. tostring(name))
	end
	return remote
end

return Remotes
