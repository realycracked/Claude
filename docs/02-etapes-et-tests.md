# 02 – Construire et tester par étapes

Le projet complet est fourni, mais il a été pensé pour être **vérifié étape par étape**.
Chaque étape indique ce qui doit marcher et comment le tester. Si une étape échoue, la
suite ne fonctionnera pas : corrige-la avant de continuer (voir `04-depannage.md`).

## Étape 1 – Version jouable minimale

**Objectif** : map, tapis fonctionnel, achat d'un œuf, œuf équipé qui suit le joueur,
un slime, l'épée de départ et les récompenses.

Fichiers concernés : tous les `Config`, `Shared`, `Main`, `DataService`, `RequestRouter`,
`PlayerService`, `CompanionService`, `InventoryService`, `SlimeService`, `CombatService`,
`ConveyorService`, `MapBuilder`, `SlimeBuilder`, `SwordBuilder`, `EggBuilder`, et côté client
`ClientMain`, `ClientState`, `UIController`, `CombatController`, `CombatVFX`,
`ConveyorController`, `CompanionController`.

> Pour réduire volontairement l'étape 1 à « un seul slime » : dans `SlimeConfig`, mets
> `Count = 0` sur toutes les catégories sauf `Weak`, et `Count = 1` sur `Weak`.

**Tests :**

1. Play → Output : `[SlimeEggs] Serveur prêt ✔` et `[SlimeEggs] Client prêt ✔`, sans erreur rouge.
2. Tu apparais sur la place orange, le tapis noir aux bordures grises est devant toi, les
   œufs arrivent par la gauche toutes les 3 s et disparaissent à droite.
3. Ton personnage tient une épée en bois. Avance vers la **Zone 1**, clique sur un slime
   (ou maintiens le clic) : le bras se lève, la traînée apparaît, le slime flashe blanc, un
   nombre de dégâts monte, sa barre de vie descend, puis il rétrécit et disparaît.
4. L'argent passe de 0 à 3 avec un « +3 $ » vert. Le slime réapparaît après 4 s.
5. Avec 10 $, approche-toi d'un **Œuf Commun** sur le tapis : un ProximityPrompt « Acheter »
   apparaît. Appuie sur **E** : l'œuf disparaît, message « Œuf Commun acheté ! », et un petit
   œuf flotte derrière toi.
6. Retourne frapper un slime : l'œuf « charge » le slime et inflige ses propres dégâts
   (nombres jaunes).
7. **Bag** : la carte de l'œuf a un contour doré (équipé) ; « Retirer » le fait disparaître,
   « Équiper » le fait revenir.

## Étape 2 – Boutique d'épées et paliers de DPS

**Tests :**

1. **Shop → Épées** : l'épée en bois est « Équipée ✓ », l'épée en fer coûte 75 $. Le bouton
   est gris tant que tu n'as pas l'argent.
2. Achète l'épée en fer : le modèle dans ta main change de couleur, le texte DPS en bas à
   gauche passe de 5 à 15 + œufs, et le palier passe de « Novice » à « Combattant » dès 25 DPS.
3. Les coups sont plus rapides (0.50 s au lieu de 0.60 s) et un coup sur deux part en
   diagonale. La ligne de statistiques de la boutique montre « X dégâts / coup toutes les Y s ».
4. **Vérification serveur** : la cadence réelle est contrôlée côté serveur ; si tu modifies
   `CombatMath.Tiers` côté client seulement, les coups trop rapides sont ignorés.

## Étape 3 – Effets d'attaque (cosmétiques)

**Tests :**

1. **Shop → Effets** : 6 effets, chacun avec la mention « cosmétique » et son prix.
   « Aperçu » joue trois coups devant toi avec la traînée et les impacts de l'effet, sans rien acheter.
2. Achète **Feu** (500 $) : il est équipé automatiquement, la traînée devient orange / rouge,
   les impacts sont orange avec une lumière brève. Les dégâts ne changent pas.
3. **Bag → Effets** : « Retirer » remet la traînée blanche ; « Équiper » la remet.
4. Quitte et reviens : l'effet équipé est conservé (si la sauvegarde est active).

## Étape 4 – Inventaire, vente, index, rangs

**Tests :**

1. Achète plusieurs œufs (plus que la limite de 3) : le quatrième n'est pas équipé.
   « Équiper les meilleurs » choisit les 3 plus puissants.
2. **Sell** : chaque œuf a un bouton « Vendre X $ » (50 % du prix). Une confirmation Oui / Non
   apparaît. Le bouton du bas vend tous les œufs non équipés d'un coup.
3. **Index** : les œufs achetés sont colorés, les autres affichent « ??? ».
4. **Ranks** : ton rang est entouré d'or ; à 500 $ gagnés en combat le rang « Chasseur »
   s'affiche avec un message doré, et à 5 000 $ « Guerrier » autorise 4 œufs équipés.

## Étape 5 – Zones, boss et multijoueur

**Tests :**

1. Suis le chemin beige : zones 2 à 6 de plus en plus loin, panneaux avec PV et récompense.
   Le Boss (zone 6) est énorme, sombre, aux yeux dorés, et réapparaît au bout de 60 s.
2. **Home** te ramène instantanément au spawn.
3. **Test → Clients and Servers (2 joueurs)** : frappez le même slime à deux, la récompense est
   répartie au prorata des dégâts et aucun des deux ne reçoit la récompense complète.
4. Essayez d'acheter le même œuf en même temps : un seul l'obtient, l'autre lit
   « Trop tard, cet œuf vient d'être acheté ! ».

## Étape 6 – Sauvegarde

**Tests :**

1. API Services activés → joue, achète, quitte (Stop), relance : argent, œufs, équipement,
   épées, effets et rang sont conservés.
2. Désactive les API Services → au lancement, message rouge « Données non chargées : la
   sauvegarde est désactivée pour cette session » ; le jeu reste jouable.
3. Pour **remettre à zéro** toutes les sauvegardes : change `StoreName` dans `GameConfig.Data`.
