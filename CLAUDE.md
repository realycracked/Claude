# Slime Eggs – notes pour Claude Code

Jeu Roblox complet en Luau (voir `README.md` et `docs/`). Tout le décor, les modèles 3D
et l'interface sont générés par script ; aucun identifiant d'asset inventé.

## Organisation

- `src/` suit l'Explorateur de Studio (convention Rojo : `.server.lua` = Script,
  `.client.lua` = LocalScript, `.lua` = ModuleScript). `default.project.json` est le projet Rojo.
- `build/*.rbxmx` sont générés depuis `src/` par `python3 tools/build_rbxmx.py` ;
  **les regénérer après toute modification de `src/`** et les committer.
- Tous les réglages de jeu vivent dans `src/ReplicatedStorage/Config/` ; ne pas dupliquer
  de nombres dans les services.
- Vérification de syntaxe sans Studio : `stylua --check` (parseur Luau) sur chaque fichier.
- Textes du jeu, commentaires et docs en français ; noms de boutons du HUD en anglais
  (Home, Sell, Bag, Shop, Index, Ranks) comme la capture de référence `docs/reference.jpg`.

## Règles de conception

- Le serveur décide de tout (argent, dégâts, achats, cadence, portée) ; le client n'envoie
  que des intentions via la RemoteFunction `Request(action, payload)` et l'event `Attack`.
- Dégâts par coup = DPS × intervalle (`CombatMath`) ; ne jamais multiplier le DPS deux fois.
- Animations de slimes, œufs et nuages côté client (`SlimeAnimator`, `EggAnimator`,
  `DecorController`) : zéro trafic réseau. Le serveur ne fait que `PivotTo` et attributs.
- Icônes : `IconConfig` (emoji de secours si l'identifiant est vide). Pack PNG dans `assets/icons/`.

## Choix visuels en attente (demander au joueur, lui montrer des rendus lettrés)

- Tronc d'arbre : `MapConfig.TrunkStyle` = `"Smooth"` (T1), `"Bark"` (T2, actuel), `"Twisted"` (T3).
- Style d'œuf : `EggConfig.Style` = `"Smooth"` (A, actuel), `"TwoTone"` (B), `"Faceted"` (C), `"Blocks"` (D).
- Arbres : `MapConfig.TreeStyles` = `{ "A", "B" }` (choisi par le joueur) ; C, D, E existent aussi.

## Tester dans Roblox Studio (session locale)

Si un serveur MCP Roblox Studio est configuré, l'utiliser pour : insérer les scripts
(ou `Insert from File…` des trois `.rbxmx`), lancer Play, lire l'Output, prendre des captures
et vérifier les étapes de `docs/02-etapes-et-tests.md`. Sinon, Rojo (`rojo serve`) synchronise
`src/` en direct dans Studio avec le plugin Rojo.
