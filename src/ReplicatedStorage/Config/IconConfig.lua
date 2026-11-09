--[[
	IconConfig (ModuleScript)
	Emplacement : ReplicatedStorage > Config > IconConfig

	Icônes de l'interface. Les images PNG sont fournies dans le dossier assets/icons/ du projet.

	COMMENT LES ACTIVER (une seule fois) :
	1. Studio > onglet View > Asset Manager > Bulk Import > sélectionne tous les PNG de assets/icons/
	   (ou Home > Game Settings > ... ; chaque image passe par la modération Roblox, quelques minutes).
	2. Dans l'Asset Manager, clic droit sur une image > "Copy ID to clipboard".
	3. Colle l'identifiant ci-dessous, sous la forme "rbxassetid://123456789".

	Tant qu'une entrée est vide (""), l'interface affiche l'emoji de secours à la place :
	le jeu fonctionne donc même sans uploader les images.
]]

local IconConfig = {}

IconConfig.Images = {
	Bag = "", -- assets/icons/bag.png
	Shop = "", -- assets/icons/shop.png
	Index = "", -- assets/icons/index.png
	Ranks = "", -- assets/icons/ranks.png
	Home = "", -- assets/icons/home.png
	Sell = "", -- assets/icons/sell.png
	Cash = "", -- assets/icons/cash.png (billet vert du HUD et des étiquettes du tapis)
	Sword = "", -- assets/icons/sword.png
	Egg = "", -- assets/icons/egg.png (œuf blanc, teinté selon la rareté)
	Attack = "", -- assets/icons/attack.png (bouton tactile)
	Star = "", -- assets/icons/star.png (bouton "Équiper les meilleurs")
	Close = "", -- assets/icons/close.png
	-- Effets d'attaque
	Fire = "", -- assets/icons/fire.png
	Ice = "", -- assets/icons/ice.png
	Lightning = "", -- assets/icons/lightning.png
	Shadow = "", -- assets/icons/shadow.png
	Light = "", -- assets/icons/light.png
	Rainbow = "", -- assets/icons/rainbow.png
}

-- Emoji utilisés quand l'image n'est pas renseignée
IconConfig.Fallback = {
	Bag = "🎒",
	Shop = "🛒",
	Index = "📖",
	Ranks = "📈",
	Home = "🏠",
	Sell = "💰",
	Cash = "$",
	Sword = "🗡️",
	Egg = "🥚",
	Attack = "⚔️",
	Star = "⭐",
	Close = "✕",
	Fire = "🔥",
	Ice = "❄️",
	Lightning = "⚡",
	Shadow = "🌑",
	Light = "✨",
	Rainbow = "🌈",
}

-- Retourne l'identifiant d'image ("" si absent)
function IconConfig.GetImage(name)
	local id = IconConfig.Images[name]
	if type(id) == "string" and id ~= "" then
		return id
	end
	return ""
end

function IconConfig.GetFallback(name)
	return IconConfig.Fallback[name] or "?"
end

function IconConfig.HasImage(name)
	return IconConfig.GetImage(name) ~= ""
end

return IconConfig
