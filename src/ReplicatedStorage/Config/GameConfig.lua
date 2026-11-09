--[[
	GameConfig (ModuleScript)
	Emplacement : ReplicatedStorage > Config > GameConfig

	Réglages généraux du jeu. Tout ce qui concerne le tapis roulant,
	le combat, la vente, les compagnons et la sauvegarde se règle ici.
]]

local GameConfig = {}

-- Argent de départ d'un nouveau joueur
GameConfig.StartCash = 0

-- Point d'apparition (le bouton Home ramène ici)
GameConfig.SpawnPosition = Vector3.new(0, 3, 55)

-- Tapis roulant
GameConfig.Conveyor = {
	Center = Vector3.new(0, 0, 25), -- centre du tapis (au niveau du sol)
	Direction = Vector3.new(1, 0, 0), -- sens de défilement des œufs
	Length = 70, -- longueur du tapis (studs)
	Width = 8, -- largeur du tapis
	BeltHeight = 1, -- épaisseur du tapis
	Speed = 5, -- vitesse des œufs (studs / seconde)
	SpawnInterval = 3, -- un nouvel œuf toutes les X secondes
	MaxEggs = 8, -- nombre maximum d'œufs sur le tapis
	BuyDistance = 12, -- distance maximale pour acheter (studs)
	EggScale = 1, -- taille des œufs sur le tapis
}

-- Combat
GameConfig.Combat = {
	CompanionRange = 28, -- portée des œufs équipés autour du joueur
	CombatTimeout = 8, -- les œufs attaquent pendant X s après le dernier coup du joueur
	CooldownTolerance = 0.75, -- tolérance réseau sur la cadence (0.75 = 25 % de marge)
	DistanceTolerance = 6, -- tolérance réseau sur la portée (studs)
}

-- Vente des œufs
GameConfig.Sell = {
	RefundRatio = 0.5, -- un œuf se revend 50 % de son prix
}

-- Compagnons (œufs équipés qui suivent le joueur)
GameConfig.Companion = {
	Scale = 0.55, -- taille des œufs compagnons
	BobHeight = 0.35, -- amplitude du flottement
	BobSpeed = 2.2, -- vitesse du flottement
	FollowSpeed = 7, -- réactivité du suivi (plus grand = plus rapide)
	-- Position de chaque emplacement par rapport au joueur (x = côté, y = hauteur, z = derrière)
	Offsets = {
		Vector3.new(-3, 1.5, 3),
		Vector3.new(3, 1.5, 3),
		Vector3.new(0, 2.2, 5.5),
		Vector3.new(-5, 1.5, 5.5),
		Vector3.new(5, 1.5, 5.5),
		Vector3.new(0, 3, 8),
	},
}

-- Sauvegarde
GameConfig.Data = {
	StoreName = "SlimeEggs_v1", -- changer ce nom remet toutes les sauvegardes à zéro
	AutosaveInterval = 120, -- sauvegarde automatique toutes les X secondes
	LoadRetries = 3,
}

return GameConfig
