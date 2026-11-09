--[[
	EffectConfig (ModuleScript)
	Emplacement : ReplicatedStorage > Config > EffectConfig

	Effets d'attaque (traînée de l'épée + impact sur le slime).
	100 % COSMÉTIQUES : aucun bonus de dégâts.
]]

local EffectConfig = {}

local function sequence(colors)
	local keypoints = {}
	for index, color in ipairs(colors) do
		local time = (index - 1) / math.max(1, #colors - 1)
		table.insert(keypoints, ColorSequenceKeypoint.new(time, color))
	end
	return ColorSequence.new(keypoints)
end

EffectConfig.Description = "Effet purement cosmétique : ne change pas les dégâts."

EffectConfig.List = {
	{
		Id = "Fire",
		Name = "Feu",
		Icon = "🔥",
		Price = 500,
		TrailColor = sequence({ Color3.fromRGB(255, 200, 60), Color3.fromRGB(255, 110, 0), Color3.fromRGB(200, 30, 0) }),
		ImpactColor = Color3.fromRGB(255, 120, 20),
		LightColor = Color3.fromRGB(255, 120, 20),
		LightBrightness = 2,
		ParticleSize = 0.9,
		ParticleSpeed = 8,
		ParticleLifetime = 0.5,
		Rainbow = false,
	},
	{
		Id = "Ice",
		Name = "Glace",
		Icon = "❄️",
		Price = 1500,
		TrailColor = sequence({ Color3.fromRGB(255, 255, 255), Color3.fromRGB(150, 230, 255), Color3.fromRGB(60, 160, 255) }),
		ImpactColor = Color3.fromRGB(170, 235, 255),
		LightColor = Color3.fromRGB(150, 220, 255),
		LightBrightness = 1.5,
		ParticleSize = 0.7,
		ParticleSpeed = 4,
		ParticleLifetime = 0.9,
		Rainbow = false,
	},
	{
		Id = "Lightning",
		Name = "Éclairs",
		Icon = "⚡",
		Price = 5000,
		TrailColor = sequence({ Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 255, 120), Color3.fromRGB(255, 220, 0) }),
		ImpactColor = Color3.fromRGB(255, 255, 140),
		LightColor = Color3.fromRGB(255, 255, 160),
		LightBrightness = 4,
		ParticleSize = 0.5,
		ParticleSpeed = 18,
		ParticleLifetime = 0.3,
		Rainbow = false,
	},
	{
		Id = "Shadow",
		Name = "Ombres",
		Icon = "🌑",
		Price = 15000,
		TrailColor = sequence({ Color3.fromRGB(120, 0, 180), Color3.fromRGB(50, 0, 80), Color3.fromRGB(10, 0, 15) }),
		ImpactColor = Color3.fromRGB(90, 0, 140),
		LightColor = Color3.fromRGB(120, 0, 180),
		LightBrightness = 1,
		ParticleSize = 1.3,
		ParticleSpeed = 3,
		ParticleLifetime = 1.1,
		Rainbow = false,
	},
	{
		Id = "Light",
		Name = "Lumière",
		Icon = "✨",
		Price = 50000,
		TrailColor = sequence({ Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 250, 200), Color3.fromRGB(255, 220, 100) }),
		ImpactColor = Color3.fromRGB(255, 245, 190),
		LightColor = Color3.fromRGB(255, 240, 180),
		LightBrightness = 6,
		ParticleSize = 1.0,
		ParticleSpeed = 10,
		ParticleLifetime = 0.7,
		Rainbow = false,
	},
	{
		Id = "Rainbow",
		Name = "Arc-en-ciel",
		Icon = "🌈",
		Price = 150000,
		TrailColor = sequence({
			Color3.fromRGB(255, 0, 0),
			Color3.fromRGB(255, 170, 0),
			Color3.fromRGB(255, 255, 0),
			Color3.fromRGB(0, 255, 80),
			Color3.fromRGB(0, 150, 255),
			Color3.fromRGB(170, 0, 255),
		}),
		ImpactColor = Color3.fromRGB(255, 255, 255),
		LightColor = Color3.fromRGB(255, 255, 255),
		LightBrightness = 3,
		ParticleSize = 1.0,
		ParticleSpeed = 12,
		ParticleLifetime = 0.8,
		Rainbow = true, -- la couleur tourne avec le temps
	},
}

local byId = {}
for index, def in ipairs(EffectConfig.List) do
	def.Index = index
	byId[def.Id] = def
end

function EffectConfig.Get(id)
	if id == nil or id == "" then
		return nil
	end
	return byId[id]
end

return EffectConfig
