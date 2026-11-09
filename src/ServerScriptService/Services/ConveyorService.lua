--[[
	ConveyorService (ModuleScript)
	Emplacement : ServerScriptService > Services > ConveyorService

	Fait apparaître les œufs à une extrémité du tapis et les détruit à l'autre.
	Le déplacement visuel est calculé par chaque client d'après l'heure d'apparition
	(attribut SpawnTime) : c'est fluide et le serveur retrouve la position exacte
	au moment de l'achat pour vérifier la distance.

	Achat : ProximityPrompt (touche E sur PC, bouton tactile sur mobile).
	Un œuf ne peut être acheté qu'une seule fois, même si deux joueurs appuient en même temps.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local EggConfig = require(ReplicatedStorage.Config.EggConfig)
local EggBuilder = require(ReplicatedStorage.Shared.EggBuilder)
local Util = require(ReplicatedStorage.Shared.Util)

local DataService = require(ServerScriptService.Services.DataService)
local PlayerService = require(ServerScriptService.Services.PlayerService)
local InventoryService = require(ServerScriptService.Services.InventoryService)

local ConveyorService = {}

local conf = GameConfig.Conveyor
local eggsFolder = workspace:WaitForChild("ConveyorEggs")
local random = Random.new()

local direction = conf.Direction.Unit
local travelLength = conf.Length - 4
local travelTime = travelLength / conf.Speed

local function startPosition()
	local eggHeight = EggBuilder.GetHeight(conf.EggScale)
	return conf.Center - direction * (travelLength / 2) + Vector3.new(0, conf.BeltHeight + eggHeight / 2, 0)
end

-- Position actuelle d'un œuf (même formule que le client)
function ConveyorService.GetEggPosition(model)
	local spawnTime = model:GetAttribute("SpawnTime") or 0
	local start = model:GetAttribute("StartPosition") or startPosition()
	local elapsed = workspace:GetServerTimeNow() - spawnTime
	return start + direction * conf.Speed * elapsed
end

local function tryBuy(player, model)
	if not model.Parent then
		return
	end
	-- Réservation immédiate : le premier arrivé gagne
	if model:GetAttribute("Sold") then
		PlayerService.Notify(player, "Trop tard, cet œuf vient d'être acheté !", Color3.fromRGB(255, 120, 120))
		return
	end
	model:SetAttribute("Sold", true)

	local function refuse(message)
		model:SetAttribute("Sold", false)
		PlayerService.Notify(player, message, Color3.fromRGB(255, 120, 120))
	end

	local profile = DataService.Get(player)
	if not profile then
		return refuse("Profil non chargé")
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return refuse("Personnage introuvable")
	end
	local distance = (root.Position - ConveyorService.GetEggPosition(model)).Magnitude
	if distance > conf.BuyDistance + GameConfig.Combat.DistanceTolerance then
		return refuse("Trop loin de l'œuf")
	end
	local price = model:GetAttribute("Price") or 0
	if not PlayerService.SpendCash(player, price) then
		return refuse("Pas assez d'argent (" .. Util.FormatNumber(price) .. " $)")
	end

	local rarityId = model:GetAttribute("Rarity")
	local variantId = model:GetAttribute("Variant")
	model:Destroy()
	InventoryService.AddEgg(player, rarityId, variantId)
	PlayerService.Notify(player, "🥚 " .. EggConfig.GetDisplayName(rarityId, variantId) .. " acheté !", Color3.fromRGB(120, 255, 120))
end

local function spawnEgg()
	local rarity = EggConfig.RollRarity(random)
	local variant = EggConfig.RollVariant(random)
	local price = EggConfig.GetPrice(rarity.Id, variant.Id)

	local model = EggBuilder.Build(rarity.Id, variant.Id, conf.EggScale)
	model.Name = "ConveyorEgg"
	local start = startPosition()
	model:SetAttribute("Price", price)
	model:SetAttribute("SpawnTime", workspace:GetServerTimeNow())
	model:SetAttribute("StartPosition", start)
	model:SetAttribute("Sold", false)
	model:PivotTo(CFrame.new(start))

	EggBuilder.AddLabel(model, rarity.Id, variant.Id, price)

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Acheter"
	prompt.ObjectText = EggConfig.GetDisplayName(rarity.Id, variant.Id) .. "  •  " .. Util.FormatNumber(price) .. " $"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = conf.BuyDistance
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.UIOffset = Vector2.new(0, 40)
	prompt.Parent = model.PrimaryPart
	prompt.Triggered:Connect(function(player)
		tryBuy(player, model)
	end)

	model.Parent = eggsFolder

	-- Disparition au bout du tapis
	task.delay(travelTime, function()
		if model.Parent then
			model:Destroy()
		end
	end)
end

function ConveyorService.Init()
	task.spawn(function()
		task.wait(2)
		while true do
			if #eggsFolder:GetChildren() < conf.MaxEggs then
				spawnEgg()
			end
			task.wait(conf.SpawnInterval)
		end
	end)
end

return ConveyorService
