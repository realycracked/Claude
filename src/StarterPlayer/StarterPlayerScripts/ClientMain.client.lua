--[[
	ClientMain (LocalScript)
	Emplacement : StarterPlayer > StarterPlayerScripts > ClientMain

	Point d'entrée du client : démarre tous les contrôleurs.
]]

local Controllers = script.Parent:WaitForChild("Controllers")

local ClientState = require(Controllers.ClientState)
local UIController = require(Controllers.UIController)
local ConveyorController = require(Controllers.ConveyorController)
local CompanionController = require(Controllers.CompanionController)
local CombatController = require(Controllers.CombatController)
local SlimeAnimator = require(Controllers.SlimeAnimator)
local DecorController = require(Controllers.DecorController)

ClientState.Init()
UIController.Init()
ConveyorController.Init()
CompanionController.Init()
CombatController.Init()
SlimeAnimator.Init()
DecorController.Init()

print("[SlimeEggs] Client prêt ✔")
