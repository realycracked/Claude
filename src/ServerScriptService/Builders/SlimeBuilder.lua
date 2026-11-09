--[[
	SlimeBuilder (ModuleScript)
	Emplacement : ServerScriptService > Builders > SlimeBuilder

	Construit le modèle 3D d'un slime (corps + yeux + barre de vie) et joue
	ses animations simples (dégâts, mort).
]]

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Util = require(ReplicatedStorage.Shared.Util)

local SlimeBuilder = {}

local function newPart(name, size, color, parent)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

function SlimeBuilder.GetBodySize(def)
	return Vector3.new(def.Size, def.Size * 0.75, def.Size)
end

function SlimeBuilder.Build(def)
	local size = def.Size
	local model = Instance.new("Model")
	model.Name = def.Name

	-- Corps (ellipsoïde)
	local body = newPart("Body", SlimeBuilder.GetBodySize(def), def.Color, model)
	body.CanQuery = true
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = body
	model.PrimaryPart = body

	-- Yeux
	for _, side in ipairs({ -1, 1 }) do
		local eye = newPart("Eye", Vector3.new(size * 0.18, size * 0.18, size * 0.18), def.EyeColor, model)
		eye.Shape = Enum.PartType.Ball
		eye.CanQuery = false
		eye.CFrame = body.CFrame * CFrame.new(side * size * 0.17, size * 0.12, -size * 0.4)
		local shine = newPart("Shine", Vector3.new(size * 0.06, size * 0.06, size * 0.06), Color3.new(1, 1, 1), model)
		shine.Shape = Enum.PartType.Ball
		shine.CanQuery = false
		shine.CFrame = eye.CFrame * CFrame.new(size * 0.03, size * 0.04, -size * 0.07)
	end

	-- Nom + barre de vie
	local gui = Instance.new("BillboardGui")
	gui.Name = "Info"
	gui.Adornee = body
	gui.Size = UDim2.fromOffset(190, 60)
	gui.StudsOffsetWorldSpace = Vector3.new(0, size * 0.75 / 2 + 2.5, 0)
	gui.MaxDistance = 150
	gui.LightInfluence = 0
	gui.Parent = body

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.BackgroundTransparency = 1
	nameLabel.Size = UDim2.new(1, 0, 0, 30)
	nameLabel.Font = Enum.Font.FredokaOne
	nameLabel.Text = def.Name
	nameLabel.TextColor3 = def.Index >= 5 and Color3.fromRGB(255, 120, 90) or Color3.new(1, 1, 1)
	nameLabel.TextSize = 24
	nameLabel.Parent = gui
	local nameStroke = Instance.new("UIStroke")
	nameStroke.Thickness = 2.5
	nameStroke.Color = Color3.new(0, 0, 0)
	nameStroke.Parent = nameLabel

	local barBackground = Instance.new("Frame")
	barBackground.Name = "Bar"
	barBackground.Size = UDim2.new(1, -20, 0, 20)
	barBackground.Position = UDim2.fromOffset(10, 34)
	barBackground.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
	barBackground.BorderSizePixel = 0
	barBackground.Parent = gui
	local barCorner = Instance.new("UICorner")
	barCorner.CornerRadius = UDim.new(0, 8)
	barCorner.Parent = barBackground
	local barStroke = Instance.new("UIStroke")
	barStroke.Thickness = 2
	barStroke.Color = Color3.new(0, 0, 0)
	barStroke.Parent = barBackground

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(90, 230, 90)
	fill.BorderSizePixel = 0
	fill.Parent = barBackground
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 8)
	fillCorner.Parent = fill

	local hpLabel = Instance.new("TextLabel")
	hpLabel.Name = "HpLabel"
	hpLabel.BackgroundTransparency = 1
	hpLabel.Size = UDim2.fromScale(1, 1)
	hpLabel.Font = Enum.Font.FredokaOne
	hpLabel.Text = Util.FormatNumber(def.Health) .. " / " .. Util.FormatNumber(def.Health)
	hpLabel.TextColor3 = Color3.new(1, 1, 1)
	hpLabel.TextSize = 15
	hpLabel.Parent = barBackground
	local hpStroke = Instance.new("UIStroke")
	hpStroke.Thickness = 1.5
	hpStroke.Color = Color3.new(0, 0, 0)
	hpStroke.Parent = hpLabel

	model:SetAttribute("SlimeId", def.Id)
	model:SetAttribute("MaxHealth", def.Health)
	model:SetAttribute("Health", def.Health)
	model:SetAttribute("Alive", true)
	return model
end

function SlimeBuilder.UpdateHealth(model, health, maxHealth)
	local body = model.PrimaryPart
	local gui = body and body:FindFirstChild("Info")
	if not gui then
		return
	end
	local ratio = math.clamp(health / maxHealth, 0, 1)
	local bar = gui.Bar
	bar.Fill.Size = UDim2.fromScale(ratio, 1)
	bar.Fill.BackgroundColor3 = Color3.fromRGB(230, 60, 60):Lerp(Color3.fromRGB(90, 230, 90), ratio)
	bar.HpLabel.Text = Util.FormatNumber(math.max(0, health)) .. " / " .. Util.FormatNumber(maxHealth)
end

-- Flash blanc + petite compression quand le slime est touché
function SlimeBuilder.PlayHit(model, def)
	local body = model.PrimaryPart
	if not body then
		return
	end
	local info = TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, true)
	local normal = SlimeBuilder.GetBodySize(def)
	local tween = TweenService:Create(body, info, {
		Color = Color3.new(1, 1, 1),
		Size = Vector3.new(normal.X * 1.08, normal.Y * 0.85, normal.Z * 1.08),
	})
	tween:Play()
	tween.Completed:Connect(function()
		if body.Parent then
			body.Color = def.Color
			body.Size = normal
		end
	end)
end

-- Animation de mort : le slime rétrécit et disparaît (fonction bloquante ~0.45 s)
function SlimeBuilder.PlayDeath(model)
	local body = model.PrimaryPart
	if not body then
		return
	end
	local info = model:FindFirstChild("Info", true)
	if info then
		info.Enabled = false
	end
	local tweenInfo = TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.In)
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			TweenService:Create(part, tweenInfo, { Size = Vector3.new(0.05, 0.05, 0.05), Transparency = 1 }):Play()
		end
	end
	task.wait(0.45)
end

return SlimeBuilder
