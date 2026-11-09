--[[
	UIController (ModuleScript)
	Emplacement : StarterPlayer > StarterPlayerScripts > Controllers > UIController

	Construit TOUTE l'interface par script (rien à dessiner à la main) :
	- en haut : boutons Home (orange) et Sell (turquoise)
	- à gauche : Bag, Shop, Index, Ranks
	- en bas à gauche : argent (billet vert + grand nombre vert) et DPS
	- panneaux : inventaire, boutique (épées + effets), vente, index, rangs
	- confirmation, notifications, bouton ATTAQUE tactile
	L'interface est dessinée pour un écran 1280x720 puis mise à l'échelle (UIScale)
	pour s'adapter au PC et au mobile.
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local EggConfig = require(ReplicatedStorage.Config.EggConfig)
local SwordConfig = require(ReplicatedStorage.Config.SwordConfig)
local EffectConfig = require(ReplicatedStorage.Config.EffectConfig)
local RankConfig = require(ReplicatedStorage.Config.RankConfig)
local CombatMath = require(ReplicatedStorage.Shared.CombatMath)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Util = require(ReplicatedStorage.Shared.Util)

local ClientState = require(script.Parent.ClientState)
local CombatVFX = require(script.Parent.CombatVFX)
local CombatController = require(script.Parent.CombatController)

local UIController = {}

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

---------------------------------------------------------------------------
-- Palette et petites fonctions de construction
---------------------------------------------------------------------------
local C = {
	White = Color3.new(1, 1, 1),
	Black = Color3.new(0, 0, 0),
	Orange = Color3.fromRGB(245, 150, 40),
	OrangeDark = Color3.fromRGB(170, 90, 10),
	Teal = Color3.fromRGB(60, 200, 210),
	TealDark = Color3.fromRGB(20, 120, 130),
	Green = Color3.fromRGB(80, 200, 90),
	GreenDark = Color3.fromRGB(30, 110, 40),
	Red = Color3.fromRGB(230, 70, 70),
	RedDark = Color3.fromRGB(130, 30, 30),
	Blue = Color3.fromRGB(70, 140, 255),
	BlueDark = Color3.fromRGB(30, 70, 150),
	Purple = Color3.fromRGB(170, 90, 255),
	PurpleDark = Color3.fromRGB(90, 40, 150),
	Grey = Color3.fromRGB(120, 120, 130),
	GreyDark = Color3.fromRGB(70, 70, 80),
	Panel = Color3.fromRGB(40, 42, 56),
	Card = Color3.fromRGB(58, 61, 80),
	CardDark = Color3.fromRGB(30, 32, 42),
	Cash = Color3.fromRGB(90, 230, 90),
	Gold = Color3.fromRGB(255, 215, 0),
	Yellow = Color3.fromRGB(255, 230, 120),
}

local FONT = Enum.Font.FredokaOne

local function create(className, props, parent)
	local inst = Instance.new(className)
	for key, value in pairs(props) do
		inst[key] = value
	end
	inst.Parent = parent
	return inst
end

local function corner(parent, radius)
	return create("UICorner", { CornerRadius = UDim.new(0, radius) }, parent)
end

local function stroke(parent, thickness, color, transparency)
	return create("UIStroke", {
		Thickness = thickness,
		Color = color or C.Black,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
	}, parent)
end

local function padding(parent, all)
	return create("UIPadding", {
		PaddingTop = UDim.new(0, all),
		PaddingBottom = UDim.new(0, all),
		PaddingLeft = UDim.new(0, all),
		PaddingRight = UDim.new(0, all),
	}, parent)
end

-- Texte blanc avec contour noir
local function label(parent, props, strokeThickness)
	local defaults = {
		BackgroundTransparency = 1,
		Font = FONT,
		TextColor3 = C.White,
		TextScaled = true,
		Text = "",
		Size = UDim2.fromScale(1, 1),
	}
	for key, value in pairs(props) do
		defaults[key] = value
	end
	local inst = create("TextLabel", defaults, parent)
	stroke(inst, strokeThickness or 2, C.Black)
	return inst
end

-- Bouton coloré arrondi
local function button(parent, props, onClick)
	local color = props.Color or C.Green
	local dark = props.DarkColor or C.Black
	local inst = create("TextButton", {
		Size = props.Size or UDim2.fromOffset(150, 50),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.new(0, 0),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Font = FONT,
		Text = props.Text or "",
		TextColor3 = C.White,
		TextScaled = true,
		AutoButtonColor = onClick ~= nil,
		LayoutOrder = props.LayoutOrder or 0,
	}, parent)
	corner(inst, props.Radius or 12)
	create("UIStroke", { Thickness = 3, Color = dark, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, inst)
	stroke(inst, 2, C.Black) -- contour du texte
	padding(inst, 6)
	if onClick then
		inst.MouseButton1Click:Connect(function()
			onClick(inst)
		end)
	end
	return inst
end

---------------------------------------------------------------------------
-- Racine + mise à l'échelle
---------------------------------------------------------------------------
local screenGui = create("ScreenGui", {
	Name = "MainGui",
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	IgnoreGuiInset = false,
}, playerGui)

local scale = create("UIScale", { Scale = 1 }, screenGui)

local function updateScale()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local viewport = camera.ViewportSize
	local factor = math.min(viewport.X / 1280, viewport.Y / 720)
	-- Sur mobile l'écran est petit : on garde les boutons assez grands
	if UserInputService.TouchEnabled then
		factor = math.max(factor, viewport.Y / 560)
	end
	scale.Scale = math.clamp(factor, 0.55, 1.5)
end

---------------------------------------------------------------------------
-- HUD : Home / Sell, Bag / Shop / Index / Ranks, argent, DPS, bouton ATTAQUE
---------------------------------------------------------------------------
local cashLabel, dpsLabel
local openPanel -- défini plus bas

local function buildHUD()
	-- Haut : Home + Sell
	local top = create("Frame", {
		Name = "TopBar",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 10),
		Size = UDim2.fromOffset(360, 60),
	}, screenGui)
	button(top, { Text = "Home", Color = C.Orange, DarkColor = C.OrangeDark, Size = UDim2.fromOffset(165, 58), Position = UDim2.fromOffset(0, 0), Radius = 14 }, function()
		local result = ClientState.Request("GoHome")
		UIController.Toast(result.message, result.ok and C.White or C.Red)
	end)
	button(top, { Text = "Sell", Color = C.Teal, DarkColor = C.TealDark, Size = UDim2.fromOffset(165, 58), Position = UDim2.fromOffset(195, 0), Radius = 14 }, function()
		openPanel("Sell")
	end)

	-- Gauche : 4 boutons carrés
	local left = create("Frame", {
		Name = "LeftMenu",
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 18, 0.5, -110),
		Size = UDim2.fromOffset(200, 200),
	}, screenGui)
	local entries = {
		{ Name = "Bag", Icon = "🎒", Panel = "Bag", X = 0, Y = 0 },
		{ Name = "Shop", Icon = "🛒", Panel = "Shop", X = 102, Y = 0 },
		{ Name = "Index", Icon = "📖", Panel = "Index", X = 0, Y = 102 },
		{ Name = "Ranks", Icon = "📈", Panel = "Ranks", X = 102, Y = 102 },
	}
	for _, entry in ipairs(entries) do
		local btn = create("TextButton", {
			Name = entry.Name,
			Size = UDim2.fromOffset(94, 94),
			Position = UDim2.fromOffset(entry.X, entry.Y),
			BackgroundColor3 = Color3.fromRGB(45, 45, 55),
			BackgroundTransparency = 0.3,
			BorderSizePixel = 0,
			Text = "",
			AutoButtonColor = true,
		}, left)
		corner(btn, 18)
		create("UIStroke", { Thickness = 2, Color = C.White, Transparency = 0.6, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, btn)
		label(btn, { Text = entry.Icon, Size = UDim2.new(1, 0, 0, 48), Position = UDim2.fromOffset(0, 6) }, 0)
		label(btn, { Text = entry.Name, Size = UDim2.new(1, -8, 0, 26), Position = UDim2.fromOffset(4, 60) }, 2)
		btn.MouseButton1Click:Connect(function()
			openPanel(entry.Panel)
		end)
	end

	-- Bas gauche : argent
	local cashRow = create("Frame", {
		Name = "CashRow",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 18, 1, -70),
		Size = UDim2.fromOffset(320, 56),
	}, screenGui)
	local bill = create("Frame", {
		Size = UDim2.fromOffset(52, 34),
		Position = UDim2.fromOffset(0, 11),
		BackgroundColor3 = Color3.fromRGB(70, 200, 70),
		BorderSizePixel = 0,
	}, cashRow)
	corner(bill, 7)
	create("UIStroke", { Thickness = 3, Color = Color3.fromRGB(20, 80, 20), ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, bill)
	label(bill, { Text = "$", TextColor3 = C.White }, 1.5)
	create("Frame", { Size = UDim2.fromOffset(6, 6), Position = UDim2.fromOffset(6, 6), BackgroundColor3 = Color3.fromRGB(30, 120, 30), BorderSizePixel = 0 }, bill)
	create("Frame", { Size = UDim2.fromOffset(6, 6), Position = UDim2.fromOffset(40, 22), BackgroundColor3 = Color3.fromRGB(30, 120, 30), BorderSizePixel = 0 }, bill)
	cashLabel = label(cashRow, {
		Text = "0",
		TextColor3 = C.Cash,
		Size = UDim2.fromOffset(260, 56),
		Position = UDim2.fromOffset(64, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
	}, 3)

	dpsLabel = label(screenGui, {
		Text = "⚔ DPS : 5  ·  Novice",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 20, 1, -40),
		Size = UDim2.fromOffset(360, 26),
		TextXAlignment = Enum.TextXAlignment.Left,
	}, 2)

	-- Mobile : bouton ATTAQUE
	if UserInputService.TouchEnabled then
		local attack = button(screenGui, {
			Text = "⚔️\nATTAQUE",
			Color = C.Red,
			DarkColor = C.RedDark,
			Size = UDim2.fromOffset(120, 120),
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -28, 1, -40),
			Radius = 60,
		}, nil)
		attack.AutoButtonColor = true
		attack.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
				CombatController.SetHolding(true)
			end
		end)
		attack.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
				CombatController.SetHolding(false)
			end
		end)
	end
end

---------------------------------------------------------------------------
-- Notifications (toasts) et "+X $"
---------------------------------------------------------------------------
local toastContainer

function UIController.Toast(message, color)
	if not message or message == "" then
		return
	end
	local toast = create("Frame", {
		BackgroundColor3 = Color3.fromRGB(25, 25, 35),
		BackgroundTransparency = 0.25,
		Size = UDim2.new(1, 0, 0, 44),
		BorderSizePixel = 0,
	}, toastContainer)
	corner(toast, 12)
	local text = label(toast, { Text = message, TextColor3 = color or C.White, Size = UDim2.new(1, -20, 1, -10), Position = UDim2.fromOffset(10, 5) }, 2)
	task.delay(3, function()
		TweenService:Create(toast, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
		TweenService:Create(text, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
		task.wait(0.45)
		toast:Destroy()
	end)
end

local function cashPop(amount)
	local pop = label(screenGui, {
		Text = (amount > 0 and "+" or "") .. Util.FormatNumber(amount) .. " $",
		TextColor3 = amount > 0 and C.Cash or C.Red,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 90, 1, -120),
		Size = UDim2.fromOffset(220, 34),
		TextXAlignment = Enum.TextXAlignment.Left,
	}, 2)
	TweenService:Create(pop, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.new(0, 90, 1, -175),
		TextTransparency = 1,
	}):Play()
	task.delay(0.9, function()
		pop:Destroy()
	end)
end

---------------------------------------------------------------------------
-- Confirmation Oui / Non
---------------------------------------------------------------------------
local function confirm(message, onYes)
	local overlay = create("Frame", {
		Name = "Confirm",
		BackgroundColor3 = C.Black,
		BackgroundTransparency = 0.5,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 50,
	}, screenGui)
	local box = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(480, 220),
		BackgroundColor3 = C.Panel,
		BorderSizePixel = 0,
		ZIndex = 51,
	}, overlay)
	corner(box, 18)
	create("UIStroke", { Thickness = 3, Color = C.White, Transparency = 0.6, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, box)
	local text = label(box, { Text = message, Size = UDim2.new(1, -40, 0, 100), Position = UDim2.fromOffset(20, 20), TextWrapped = true, ZIndex = 52 }, 2)
	text.TextScaled = false
	text.TextSize = 26
	button(box, { Text = "Oui", Color = C.Green, DarkColor = C.GreenDark, Size = UDim2.fromOffset(180, 56), Position = UDim2.fromOffset(40, 140) }, function()
		overlay:Destroy()
		onYes()
	end).ZIndex = 52
	button(box, { Text = "Non", Color = C.Red, DarkColor = C.RedDark, Size = UDim2.fromOffset(180, 56), Position = UDim2.fromOffset(260, 140) }, function()
		overlay:Destroy()
	end).ZIndex = 52
end

---------------------------------------------------------------------------
-- Panneau central (une seule fenêtre ouverte à la fois)
---------------------------------------------------------------------------
local panel, panelTitle, tabsFrame, content, footer
local currentPanel = nil
local currentTab = {} -- [panelName] = tabId
local renderers = {}

local function buildPanel()
	panel = create("Frame", {
		Name = "Panel",
		Visible = false,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(800, 510),
		BackgroundColor3 = C.Panel,
		BackgroundTransparency = 0.05,
		BorderSizePixel = 0,
		ZIndex = 10,
	}, screenGui)
	corner(panel, 22)
	create("UIStroke", { Thickness = 3, Color = C.White, Transparency = 0.65, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, panel)

	panelTitle = label(panel, { Text = "Titre", Size = UDim2.new(1, -140, 0, 46), Position = UDim2.fromOffset(70, 12), ZIndex = 11 }, 2.5)

	button(panel, { Text = "✕", Color = C.Red, DarkColor = C.RedDark, Size = UDim2.fromOffset(46, 46), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 12), Radius = 23 }, function()
		UIController.ClosePanel()
	end).ZIndex = 11

	tabsFrame = create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -40, 0, 42), Position = UDim2.fromOffset(20, 66), ZIndex = 11 }, panel)
	create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }, tabsFrame)

	content = create("ScrollingFrame", {
		Name = "Content",
		BackgroundColor3 = C.CardDark,
		BackgroundTransparency = 0.4,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(20, 116),
		Size = UDim2.new(1, -40, 1, -196),
		ScrollBarThickness = 8,
		ScrollBarImageColor3 = C.White,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ZIndex = 11,
	}, panel)
	corner(content, 14)

	footer = create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -40, 0, 56), AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 20, 1, -14), ZIndex = 11 }, panel)
end

local function clearChildren(parent)
	for _, child in ipairs(parent:GetChildren()) do
		child:Destroy()
	end
end

local function useList(paddingPx)
	create("UIListLayout", { Padding = UDim.new(0, paddingPx or 8), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center }, content)
	padding(content, 10)
end

local function useGrid(cellWidth, cellHeight)
	create("UIGridLayout", {
		CellSize = UDim2.fromOffset(cellWidth, cellHeight),
		CellPadding = UDim2.fromOffset(10, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
	}, content)
	padding(content, 10)
end

local function setTabs(tabs, selected, onSelect)
	clearChildren(tabsFrame)
	create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }, tabsFrame)
	for order, tab in ipairs(tabs) do
		local active = tab.Id == selected
		button(tabsFrame, {
			Text = tab.Name,
			Color = active and C.Blue or C.GreyDark,
			DarkColor = active and C.BlueDark or C.Black,
			Size = UDim2.fromOffset(170, 42),
			LayoutOrder = order,
			Radius = 10,
		}, function()
			onSelect(tab.Id)
		end).ZIndex = 12
	end
end

local function emptyMessage(text)
	local msg = label(content, { Text = text, Size = UDim2.new(1, -20, 0, 60), TextWrapped = true, ZIndex = 12 }, 2)
	msg.TextScaled = false
	msg.TextSize = 22
	return msg
end

-- Ligne standard (nom + infos + boutons à droite)
local function row(order, height)
	local frame = create("Frame", {
		BackgroundColor3 = C.Card,
		BorderSizePixel = 0,
		Size = UDim2.new(1, -8, 0, height or 96),
		LayoutOrder = order,
		ZIndex = 12,
	}, content)
	corner(frame, 14)
	return frame
end

local function rowButton(frame, text, color, dark, index, onClick)
	-- index 1 = le plus à droite
	local btn = button(frame, {
		Text = text,
		Color = color,
		DarkColor = dark,
		Size = UDim2.fromOffset(150, 48),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14 - (index - 1) * 162, 0.5, 0),
		Radius = 12,
	}, onClick)
	btn.ZIndex = 13
	return btn
end

local function render()
	if not currentPanel or not ClientState.Profile then
		return
	end
	local canvasPosition = content.CanvasPosition
	clearChildren(content)
	clearChildren(footer)
	clearChildren(tabsFrame)
	renderers[currentPanel](ClientState.Profile)
	-- Sans onglets, le contenu remonte pour occuper la place
	local hasTabs = tabsFrame:FindFirstChildWhichIsA("TextButton") ~= nil
	content.Position = UDim2.fromOffset(20, hasTabs and 116 or 66)
	content.Size = UDim2.new(1, -40, 1, hasTabs and -196 or -146)
	task.defer(function()
		content.CanvasPosition = canvasPosition
	end)
end

openPanel = function(name)
	currentPanel = name
	panel.Visible = true
	render()
end
UIController.OpenPanel = openPanel

function UIController.ClosePanel()
	currentPanel = nil
	panel.Visible = false
end

local function request(action, payload)
	local result = ClientState.Request(action, payload)
	UIController.Toast(result.message, result.ok and C.White or Color3.fromRGB(255, 140, 140))
	return result
end

---------------------------------------------------------------------------
-- Panneau BAG (inventaire) : œufs + effets
---------------------------------------------------------------------------
local function eggCard(order, item, equipped)
	local rarity = EggConfig.GetRarity(item.Rarity)
	local variant = EggConfig.GetVariant(item.Variant)
	local card = create("Frame", { BackgroundColor3 = C.Card, BorderSizePixel = 0, LayoutOrder = order, ZIndex = 12 }, content)
	corner(card, 16)
	if equipped then
		create("UIStroke", { Thickness = 3, Color = C.Gold, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, card)
	end

	-- Aperçu : forme d'œuf colorée
	local preview = create("Frame", {
		Size = UDim2.fromOffset(80, 96),
		Position = UDim2.new(0.5, -40, 0, 10),
		BackgroundColor3 = variant.Tint and rarity.Color:Lerp(variant.Tint, 0.6) or rarity.Color,
		BorderSizePixel = 0,
		ZIndex = 13,
	}, card)
	corner(preview, 40)
	create("UIStroke", { Thickness = 2, Color = rarity.SpotColor, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, preview)
	if variant.Name ~= "" then
		label(preview, { Text = variant.Name, Size = UDim2.new(1, 0, 0, 24), Position = UDim2.fromOffset(0, 36), TextColor3 = variant.LabelColor, ZIndex = 14 }, 2)
	end

	local nameLabel = label(card, { Text = EggConfig.GetDisplayName(item.Rarity, item.Variant), Size = UDim2.new(1, -10, 0, 40), Position = UDim2.fromOffset(5, 110), TextWrapped = true, ZIndex = 13 }, 2)
	nameLabel.TextScaled = false
	nameLabel.TextSize = 18

	local damage, interval = CombatMath.GetEggAttack(item)
	local stats = label(card, {
		Text = string.format("DPS %s  (%s / %.1fs)", Util.FormatShort(CombatMath.GetEggItemDPS(item)), Util.FormatShort(damage), interval),
		Size = UDim2.new(1, -10, 0, 22),
		Position = UDim2.fromOffset(5, 150),
		TextColor3 = C.Yellow,
		ZIndex = 13,
	}, 1.5)
	stats.TextScaled = false
	stats.TextSize = 15

	local btn = button(card, {
		Text = equipped and "Retirer" or "Équiper",
		Color = equipped and C.Orange or C.Green,
		DarkColor = equipped and C.OrangeDark or C.GreenDark,
		Size = UDim2.new(1, -20, 0, 40),
		Position = UDim2.fromOffset(10, 178),
		Radius = 10,
	}, function()
		request(equipped and "UnequipEgg" or "EquipEgg", { id = item.Id })
	end)
	btn.ZIndex = 13
	return card
end

local function renderBagEggs(profile)
	useGrid(176, 228)
	local maxEquipped = RankConfig.GetMaxEquipped(profile.TotalEarned)

	if #profile.Eggs == 0 then
		clearChildren(content)
		useList()
		emptyMessage("Aucun œuf pour l'instant.\nAchète-en sur le tapis roulant (approche-toi et appuie sur E / le bouton).")
	else
		-- Équipés d'abord, puis par puissance
		local sorted = table.clone(profile.Eggs)
		table.sort(sorted, function(a, b)
			local ea = table.find(profile.Equipped, a.Id) ~= nil
			local eb = table.find(profile.Equipped, b.Id) ~= nil
			if ea ~= eb then
				return ea
			end
			return CombatMath.GetEggItemDPS(a) > CombatMath.GetEggItemDPS(b)
		end)
		for order, item in ipairs(sorted) do
			eggCard(order, item, table.find(profile.Equipped, item.Id) ~= nil)
		end
	end

	local info = label(footer, {
		Text = string.format("Équipés : %d / %d   ·   DPS des œufs : %s   ·   Total : %d œufs", #profile.Equipped, maxEquipped, Util.FormatShort(CombatMath.GetEggsDPS(profile)), #profile.Eggs),
		Size = UDim2.new(1, -230, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 12,
	}, 2)
	info.TextScaled = false
	info.TextSize = 20
	button(footer, { Text = "⭐ Équiper les meilleurs", Color = C.Purple, DarkColor = C.PurpleDark, Size = UDim2.fromOffset(220, 50), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0) }, function()
		request("EquipBest")
	end).ZIndex = 12
end

local function effectSwatch(parent, effect)
	local swatch = create("Frame", { Size = UDim2.fromOffset(64, 64), Position = UDim2.fromOffset(14, 16), BackgroundColor3 = C.White, BorderSizePixel = 0, ZIndex = 13 }, parent)
	corner(swatch, 14)
	create("UIGradient", { Color = effect.TrailColor, Rotation = 45 }, swatch)
	label(swatch, { Text = effect.Icon, ZIndex = 14 }, 0)
	return swatch
end

local function effectRow(order, effect, profile, inShop)
	local frame = row(order, 96)
	effectSwatch(frame, effect)
	local owned = table.find(profile.Effects, effect.Id) ~= nil
	local equipped = profile.EquippedEffect == effect.Id

	local name = label(frame, { Text = effect.Name .. (equipped and "  ✓ équipé" or ""), Size = UDim2.fromOffset(330, 34), Position = UDim2.fromOffset(92, 10), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 13 }, 2)
	name.TextScaled = false
	name.TextSize = 24
	local desc = label(frame, {
		Text = EffectConfig.Description .. (inShop and not owned and ("  ·  " .. Util.FormatNumber(effect.Price) .. " $") or ""),
		Size = UDim2.fromOffset(320, 44),
		Position = UDim2.fromOffset(92, 46),
		TextColor3 = C.Yellow,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		ZIndex = 13,
	}, 1.5)
	desc.TextScaled = false
	desc.TextSize = 15

	if owned then
		if equipped then
			rowButton(frame, "Retirer", C.Orange, C.OrangeDark, 1, function()
				request("EquipEffect", { id = "" })
			end)
		else
			rowButton(frame, "Équiper", C.Green, C.GreenDark, 1, function()
				request("EquipEffect", { id = effect.Id })
			end)
		end
	else
		local affordable = profile.Cash >= effect.Price
		rowButton(frame, "Acheter " .. Util.FormatShort(effect.Price) .. " $", affordable and C.Green or C.Grey, affordable and C.GreenDark or C.GreyDark, 1, function()
			request("BuyEffect", { id = effect.Id })
		end)
	end
	rowButton(frame, "👁 Aperçu", C.Purple, C.PurpleDark, 2, function()
		CombatVFX.Preview(player.Character, effect.Id)
		UIController.Toast("Aperçu de l'effet " .. effect.Name, C.White)
	end)
	return frame
end

local function renderBagEffects(profile)
	useList()
	if #profile.Effects == 0 then
		emptyMessage("Aucun effet possédé.\nAchète-en dans la boutique (onglet Effets). Les effets sont uniquement cosmétiques.")
	else
		local order = 0
		for _, effect in ipairs(EffectConfig.List) do
			if table.find(profile.Effects, effect.Id) then
				order = order + 1
				effectRow(order, effect, profile, false)
			end
		end
	end
	local equippedEffect = EffectConfig.Get(profile.EquippedEffect)
	local info = label(footer, {
		Text = equippedEffect and ("Effet équipé : " .. equippedEffect.Name) or "Aucun effet équipé",
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 12,
	}, 2)
	info.TextScaled = false
	info.TextSize = 20
end

renderers.Bag = function(profile)
	panelTitle.Text = "🎒 Sac"
	local tab = currentTab.Bag or "Eggs"
	setTabs({ { Id = "Eggs", Name = "Œufs" }, { Id = "Effects", Name = "Effets" } }, tab, function(id)
		currentTab.Bag = id
		render()
	end)
	if tab == "Eggs" then
		renderBagEggs(profile)
	else
		renderBagEffects(profile)
	end
end

---------------------------------------------------------------------------
-- Panneau SHOP : épées + effets
---------------------------------------------------------------------------
local function renderShopSwords(profile)
	useList()
	local _, interval = CombatMath.GetSwordAttack(profile)
	for order, sword in ipairs(SwordConfig.List) do
		local frame = row(order, 96)
		local swatch = create("Frame", { Size = UDim2.fromOffset(20, 68), Position = UDim2.fromOffset(36, 14), BackgroundColor3 = sword.Style.BladeColor, BorderSizePixel = 0, ZIndex = 13 }, frame)
		corner(swatch, 6)
		create("Frame", { Size = UDim2.fromOffset(44, 10), Position = UDim2.fromOffset(24, 58), BackgroundColor3 = sword.Style.GuardColor, BorderSizePixel = 0, ZIndex = 14 }, frame)
		create("Frame", { Size = UDim2.fromOffset(12, 18), Position = UDim2.fromOffset(40, 68), BackgroundColor3 = sword.Style.GripColor, BorderSizePixel = 0, ZIndex = 14 }, frame)

		local owned = table.find(profile.Swords, sword.Id) ~= nil
		local equipped = profile.EquippedSword == sword.Id
		local name = label(frame, { Text = sword.Name .. (equipped and "  ✓ équipée" or ""), Size = UDim2.fromOffset(360, 34), Position = UDim2.fromOffset(92, 10), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 13 }, 2)
		name.TextScaled = false
		name.TextSize = 24
		local stats = label(frame, {
			Text = string.format("DPS %s  ·  %s dégâts / coup toutes les %.2f s  ·  portée %d", Util.FormatShort(sword.DPS), Util.FormatShort(sword.DPS * interval), interval, sword.Range),
			Size = UDim2.fromOffset(400, 40),
			Position = UDim2.fromOffset(92, 46),
			TextColor3 = C.Yellow,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextWrapped = true,
			ZIndex = 13,
		}, 1.5)
		stats.TextScaled = false
		stats.TextSize = 15

		if equipped then
			rowButton(frame, "Équipée ✓", C.Grey, C.GreyDark, 1, nil)
		elseif owned then
			rowButton(frame, "Équiper", C.Blue, C.BlueDark, 1, function()
				request("EquipSword", { id = sword.Id })
			end)
		else
			local affordable = profile.Cash >= sword.Price
			rowButton(frame, "Acheter " .. Util.FormatShort(sword.Price) .. " $", affordable and C.Green or C.Grey, affordable and C.GreenDark or C.GreyDark, 1, function()
				request("BuySword", { id = sword.Id })
			end)
		end
	end
	local info = label(footer, { Text = "La cadence d'attaque augmente avec ton DPS total (épée + œufs).", TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 12 }, 2)
	info.TextScaled = false
	info.TextSize = 18
end

local function renderShopEffects(profile)
	useList()
	for order, effect in ipairs(EffectConfig.List) do
		effectRow(order, effect, profile, true)
	end
	local info = label(footer, { Text = "Les effets changent la traînée de l'épée et l'impact. Ils ne modifient PAS les dégâts.", TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true, ZIndex = 12 }, 2)
	info.TextScaled = false
	info.TextSize = 18
end

renderers.Shop = function(profile)
	panelTitle.Text = "🛒 Boutique"
	local tab = currentTab.Shop or "Swords"
	setTabs({ { Id = "Swords", Name = "Épées" }, { Id = "Effects", Name = "Effets" } }, tab, function(id)
		currentTab.Shop = id
		render()
	end)
	if tab == "Swords" then
		renderShopSwords(profile)
	else
		renderShopEffects(profile)
	end
end

---------------------------------------------------------------------------
-- Panneau SELL : revente des œufs avec confirmation
---------------------------------------------------------------------------
local function sellPrice(item)
	return math.max(1, math.floor(EggConfig.GetPrice(item.Rarity, item.Variant) * GameConfig.Sell.RefundRatio))
end

renderers.Sell = function(profile)
	panelTitle.Text = "💰 Vendre des œufs"
	useList()
	if #profile.Eggs == 0 then
		emptyMessage("Tu n'as aucun œuf à vendre.")
		return
	end
	local sorted = table.clone(profile.Eggs)
	table.sort(sorted, function(a, b)
		return CombatMath.GetEggItemDPS(a) < CombatMath.GetEggItemDPS(b)
	end)
	local unequippedTotal, unequippedCount = 0, 0
	for order, item in ipairs(sorted) do
		local equipped = table.find(profile.Equipped, item.Id) ~= nil
		local price = sellPrice(item)
		if not equipped then
			unequippedTotal = unequippedTotal + price
			unequippedCount = unequippedCount + 1
		end
		local frame = row(order, 70)
		local rarity = EggConfig.GetRarity(item.Rarity)
		local dot = create("Frame", { Size = UDim2.fromOffset(40, 48), Position = UDim2.fromOffset(16, 11), BackgroundColor3 = rarity.Color, BorderSizePixel = 0, ZIndex = 13 }, frame)
		corner(dot, 20)
		local name = label(frame, {
			Text = EggConfig.GetDisplayName(item.Rarity, item.Variant) .. (equipped and "  (équipé)" or "") .. "  ·  DPS " .. Util.FormatShort(CombatMath.GetEggItemDPS(item)),
			Size = UDim2.fromOffset(420, 50),
			Position = UDim2.fromOffset(70, 10),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = equipped and C.Yellow or C.White,
			ZIndex = 13,
		}, 2)
		name.TextScaled = false
		name.TextSize = 20
		rowButton(frame, "Vendre " .. Util.FormatShort(price) .. " $", C.Teal, C.TealDark, 1, function()
			confirm(string.format("Vendre %s pour %s $ ?%s", EggConfig.GetDisplayName(item.Rarity, item.Variant), Util.FormatNumber(price), equipped and "\n(il sera retiré de ton équipe)" or ""), function()
				request("SellEgg", { id = item.Id })
			end)
		end)
	end
	if unequippedCount > 0 then
		button(footer, {
			Text = string.format("Vendre les %d non équipés (+%s $)", unequippedCount, Util.FormatShort(unequippedTotal)),
			Color = C.Teal,
			DarkColor = C.TealDark,
			Size = UDim2.fromOffset(380, 50),
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, 0, 0.5, 0),
		}, function()
			confirm(string.format("Vendre %d œuf(s) non équipé(s) pour %s $ ?", unequippedCount, Util.FormatNumber(unequippedTotal)), function()
				request("SellUnequipped")
			end)
		end).ZIndex = 12
	end
	local info = label(footer, { Text = "Prix de revente : " .. math.floor(GameConfig.Sell.RefundRatio * 100) .. " % du prix d'achat", Size = UDim2.new(1, -400, 1, 0), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 12 }, 2)
	info.TextScaled = false
	info.TextSize = 18
end

---------------------------------------------------------------------------
-- Panneau INDEX : collection d'œufs (rareté x variante)
---------------------------------------------------------------------------
renderers.Index = function(profile)
	panelTitle.Text = "📖 Index des œufs"
	useGrid(240, 100)
	local discovered, total = 0, 0
	local order = 0
	for _, rarity in ipairs(EggConfig.Rarities) do
		for _, variant in ipairs(EggConfig.Variants) do
			order = order + 1
			total = total + 1
			local known = profile.Discovered[EggConfig.GetIndexKey(rarity.Id, variant.Id)] == true
			if known then
				discovered = discovered + 1
			end
			local color = variant.Tint and rarity.Color:Lerp(variant.Tint, 0.6) or rarity.Color
			local card = create("Frame", { BackgroundColor3 = known and color or C.CardDark, BorderSizePixel = 0, LayoutOrder = order, ZIndex = 12 }, content)
			corner(card, 14)
			create("UIStroke", { Thickness = 2, Color = known and rarity.SpotColor or C.GreyDark, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, card)
			local name = label(card, {
				Text = known and EggConfig.GetDisplayName(rarity.Id, variant.Id) or "???",
				Size = UDim2.new(1, -16, 0, 40),
				Position = UDim2.fromOffset(8, 8),
				TextWrapped = true,
				ZIndex = 13,
			}, 2)
			name.TextScaled = false
			name.TextSize = 20
			local info = label(card, {
				Text = known and string.format("DPS %s  ·  %s $", Util.FormatShort(EggConfig.GetDPS(rarity.Id, variant.Id)), Util.FormatShort(EggConfig.GetPrice(rarity.Id, variant.Id))) or (rarity.Name .. (variant.Name ~= "" and (" " .. variant.Name) or "") .. "  ·  non découvert"),
				Size = UDim2.new(1, -16, 0, 30),
				Position = UDim2.fromOffset(8, 56),
				TextColor3 = known and C.White or C.Grey,
				ZIndex = 13,
			}, 1.5)
			info.TextScaled = false
			info.TextSize = 15
		end
	end
	local summary = label(footer, { Text = string.format("Découverts : %d / %d", discovered, total), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 12 }, 2)
	summary.TextScaled = false
	summary.TextSize = 20
end

---------------------------------------------------------------------------
-- Panneau RANKS : paliers de progression
---------------------------------------------------------------------------
renderers.Ranks = function(profile)
	panelTitle.Text = "📈 Rangs"
	useList()
	local currentId = RankConfig.GetRank(profile.TotalEarned)
	for order, rank in ipairs(RankConfig.List) do
		local reached = profile.TotalEarned >= rank.Required
		local frame = row(order, 70)
		if rank.Id == currentId then
			create("UIStroke", { Thickness = 3, Color = C.Gold, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, frame)
		end
		local badge = create("Frame", { Size = UDim2.fromOffset(48, 48), Position = UDim2.fromOffset(14, 11), BackgroundColor3 = rank.Color, BorderSizePixel = 0, ZIndex = 13 }, frame)
		corner(badge, 24)
		label(badge, { Text = tostring(rank.Id), ZIndex = 14 }, 2)
		local name = label(frame, {
			Text = rank.Name .. (rank.Id == currentId and "  ← ton rang" or (reached and "  ✓" or "")),
			Size = UDim2.fromOffset(360, 30),
			Position = UDim2.fromOffset(76, 8),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = reached and C.White or C.Grey,
			ZIndex = 13,
		}, 2)
		name.TextScaled = false
		name.TextSize = 24
		local info = label(frame, {
			Text = string.format("Dès %s $ gagnés en combat  ·  %d œufs équipables", Util.FormatNumber(rank.Required), rank.MaxEquipped),
			Size = UDim2.fromOffset(520, 26),
			Position = UDim2.fromOffset(76, 40),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = C.Yellow,
			ZIndex = 13,
		}, 1.5)
		info.TextScaled = false
		info.TextSize = 15
	end
	local nextRank = RankConfig.GetNextRank(profile.TotalEarned)
	local text
	if nextRank then
		text = string.format("Total gagné : %s $   ·   prochain rang (%s) à %s $", Util.FormatNumber(profile.TotalEarned), nextRank.Name, Util.FormatNumber(nextRank.Required))
	else
		text = "Total gagné : " .. Util.FormatNumber(profile.TotalEarned) .. " $   ·   rang maximum atteint !"
	end
	local summary = label(footer, { Text = text, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 12 }, 2)
	summary.TextScaled = false
	summary.TextSize = 18
end

---------------------------------------------------------------------------
-- Mise à jour depuis le profil
---------------------------------------------------------------------------
local lastCash = nil

local function refresh(profile)
	if lastCash ~= nil and profile.Cash ~= lastCash then
		cashPop(profile.Cash - lastCash)
	end
	lastCash = profile.Cash
	cashLabel.Text = Util.FormatNumber(profile.Cash)

	local total = CombatMath.GetTotalDPS(profile)
	local _, tier = CombatMath.GetTier(total)
	local _, rank = RankConfig.GetRank(profile.TotalEarned)
	dpsLabel.Text = string.format("⚔ DPS : %s  ·  %s  ·  Rang %s", Util.FormatShort(total), tier.Name, rank.Name)

	if currentPanel then
		render()
	end
end

function UIController.Init()
	updateScale()
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)

	buildHUD()
	buildPanel()

	toastContainer = create("Frame", {
		Name = "Toasts",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 80),
		Size = UDim2.fromOffset(560, 200),
		ZIndex = 60,
	}, screenGui)
	create("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center }, toastContainer)

	Remotes.Get("Notify").OnClientEvent:Connect(function(message, color)
		UIController.Toast(message, color)
	end)

	ClientState.OnChanged(refresh)

	-- Échap ferme le panneau
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if not gameProcessed and input.KeyCode == Enum.KeyCode.Escape and currentPanel then
			UIController.ClosePanel()
		end
	end)
end

return UIController
