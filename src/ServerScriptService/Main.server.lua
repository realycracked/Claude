--[[
	Main (Script)
	Emplacement : ServerScriptService > Main

	Point d'entrée du serveur : crée les dossiers, génère la map,
	puis démarre tous les services dans le bon ordre.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
Remotes.Init()

-- Dossiers du Workspace utilisés par le jeu
local function ensureFolder(name)
	local folder = workspace:FindFirstChild(name)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = name
		folder.Parent = workspace
	end
	return folder
end
ensureFolder("ConveyorEggs")
ensureFolder("Slimes")
ensureFolder("Companions")

-- Décor
require(ServerScriptService.Builders.MapBuilder).Build()

-- Services (l'ordre compte : les dépendances d'abord)
local Services = ServerScriptService.Services
require(Services.DataService).Init()
require(Services.RequestRouter).Init()
require(Services.PlayerService).Init()
require(Services.InventoryService).Init()
require(Services.ShopService).Init()
require(Services.SlimeService).Init()
require(Services.CombatService).Init()
require(Services.ConveyorService).Init()

print("[SlimeEggs] Serveur prêt ✔")
