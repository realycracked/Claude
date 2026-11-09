--[[
	Util (ModuleScript)
	Emplacement : ReplicatedStorage > Shared > Util

	Petites fonctions utilitaires partagées.
]]

local Util = {}

-- 1234567 -> "1 234 567"
function Util.FormatNumber(value)
	value = math.floor((tonumber(value) or 0) + 0.5)
	local text = tostring(value)
	local sign = ""
	if value < 0 then
		sign = "-"
		text = text:sub(2)
	end
	local result = ""
	while #text > 3 do
		result = " " .. text:sub(-3) .. result
		text = text:sub(1, -4)
	end
	return sign .. text .. result
end

-- 1234 -> "1.2k", 1500000 -> "1.5M" (pour les textes courts)
function Util.FormatShort(value)
	value = tonumber(value) or 0
	if value >= 1e9 then
		return string.format("%.1fB", value / 1e9)
	elseif value >= 1e6 then
		return string.format("%.1fM", value / 1e6)
	elseif value >= 1e4 then
		return string.format("%.1fk", value / 1e3)
	end
	return Util.FormatNumber(value)
end

-- Arrondi à N décimales (par défaut 1)
function Util.Round(value, decimals)
	local factor = 10 ^ (decimals or 1)
	return math.floor(value * factor + 0.5) / factor
end

-- Copie profonde d'une table
function Util.DeepCopy(source)
	if type(source) ~= "table" then
		return source
	end
	local copy = {}
	for key, value in pairs(source) do
		copy[key] = Util.DeepCopy(value)
	end
	return copy
end

-- Ajoute les clés manquantes d'après un modèle (utile pour les vieilles sauvegardes)
function Util.Reconcile(data, template)
	for key, value in pairs(template) do
		if data[key] == nil then
			data[key] = Util.DeepCopy(value)
		elseif type(value) == "table" and type(data[key]) == "table" and #value == 0 and next(value) ~= nil then
			Util.Reconcile(data[key], value)
		end
	end
	return data
end

return Util
