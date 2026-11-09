# 03 – Équilibrage et personnalisation

Tous les nombres du jeu sont dans `ReplicatedStorage.Config`. Aucun autre fichier n'a besoin
d'être modifié pour changer l'équilibrage.

## Progression prévue au départ

| Étape du joueur | Ce qu'il frappe | Ce qu'il vise |
| --- | --- | --- |
| 0 $ – épée en bois (5 DPS) | Slime faible (20 PV, 3 $) : 4 s par kill | Œuf Commun 10 $, épée en fer 75 $ |
| Épée en fer (15 DPS) + œufs communs | Slime basique (100 PV, 12 $) | Épée en acier 600 $, œufs Peu communs 50 $ |
| Acier (45 DPS) | Slime difficile (600 PV, 60 $) | Œufs Rares 250 $, cristal 4 500 $ |
| Cristal (150 DPS) + Rares | Slime très difficile (4 000 PV, 350 $) | Œufs Épiques 1 500 $, dragon 35 000 $ |
| Dragon (500 DPS) + Épiques | Slime méga difficile (30 000 PV, 2 200 $) | Œufs Légendaires 10 000 $ |
| Mythique (1 800 DPS) + Légendaires | Boss (250 000 PV, 15 000 $) | Œufs Mythiques 75 000 $ |

## Œufs (`EggConfig`)

| Rareté | Prix | Poids | DPS | Intervalle | Dégâts / attaque |
| --- | --- | --- | --- | --- | --- |
| Commun | 10 | 50 % | 1 | 1.2 s | 1.2 |
| Peu commun | 50 | 28 % | 3 | 1.1 s | 3.3 |
| Rare | 250 | 13 % | 10 | 1.0 s | 10 |
| Épique | 1 500 | 6 % | 35 | 0.9 s | 31.5 |
| Légendaire | 10 000 | 2.5 % | 120 | 0.8 s | 96 |
| Mythique | 75 000 | 0.5 % | 450 | 0.7 s | 315 |

Variantes : Argent (12 %, prix ×2, DPS ×1.5), Or (3 %, prix ×4, DPS ×2.5).
Les poids sont relatifs : ils n'ont pas besoin de faire 100.

- Rendre les œufs rares plus fréquents : augmente leur `Weight`.
- Changer l'apparence : `Color`, `SpotColor`, `Material`, `Spots`, `Glow`, `Sparkles`, `Aura`.

## Paliers de cadence (`CombatMath.Tiers`)

| Palier | DPS total requis | Intervalle épée |
| --- | --- | --- |
| Novice | 0 | 0.60 s |
| Combattant | 25 | 0.50 s |
| Vétéran | 120 | 0.42 s |
| Maître | 600 | 0.34 s |
| Légende | 2 500 | 0.27 s |
| Mythique | 10 000 | 0.22 s (maximum) |

Dégâts par coup = DPS de l'épée × intervalle. Monter de palier ne change donc pas le DPS,
seulement la vitesse et le spectacle (traînée plus large, enchaînements).

## Slimes (`SlimeConfig`)

Pour chaque catégorie : `Health`, `Reward`, `Size`, `Count`, `RespawnTime`, `ZonePosition`,
`ZoneRadius`. Si tu déplaces une zone, les chemins et les arbres s'adaptent automatiquement
au prochain lancement (la map est régénérée si `Workspace.Map` n'existe pas).

## Épées (`SwordConfig`) et effets (`EffectConfig`)

Ajouter une épée ou un effet = ajouter une entrée dans la liste. L'interface, la boutique et
la sauvegarde les prennent en compte sans autre modification.

## Rangs (`RankConfig`)

`Required` = argent total gagné en combat (les ventes ne comptent pas). `MaxEquipped` = nombre
d'œufs équipables à ce rang.

## Réglages généraux (`GameConfig`)

- `Conveyor.Speed`, `SpawnInterval`, `MaxEggs`, `BuyDistance`.
- `Combat.CompanionRange`, `CombatTimeout`, tolérances réseau.
- `Sell.RefundRatio` (0.5 = 50 %).
- `Companion.Offsets` : positions des œufs autour du joueur.
- `Data.StoreName` : changer ce nom remet toutes les sauvegardes à zéro.
