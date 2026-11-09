# Slime Eggs – jeu Roblox complet (Luau)

Un jeu Roblox jouable, dans le style cartoon low poly de la capture de référence :
le joueur frappe des **slimes** avec une **épée** pour gagner de l'argent, achète des
**œufs** sur un **tapis roulant**, les équipe comme **compagnons** (ils ajoutent du DPS),
achète des **épées** plus fortes et des **effets d'attaque** cosmétiques, et progresse
à travers six zones de difficulté jusqu'au **Boss Slime**.

Tout le décor, les modèles 3D et l'interface sont **générés par script** : aucun asset
externe, aucun identifiant inventé, rien à dessiner à la main.

![Référence](docs/reference.jpg)

## Démarrage rapide (3 fichiers à importer)

1. Ouvre Roblox Studio, crée un nouveau lieu **Baseplate**.
2. Télécharge les trois fichiers du dossier [`build/`](build/) :
   `ReplicatedStorage.rbxmx`, `ServerScriptService.rbxmx`, `StarterPlayerScripts.rbxmx`.
3. Dans l'Explorateur de Studio :
   - clic droit sur **ReplicatedStorage** → *Insert from File…* → `ReplicatedStorage.rbxmx`
   - clic droit sur **ServerScriptService** → *Insert from File…* → `ServerScriptService.rbxmx`
   - déplie **StarterPlayer**, clic droit sur **StarterPlayerScripts** → *Insert from File…* → `StarterPlayerScripts.rbxmx`
4. *Game Settings → Security → Enable Studio Access to API Services* : coché (sauvegarde).
5. Appuie sur **Play**. La map, le tapis, les slimes et l'interface apparaissent.

Le guide détaillé (avec la méthode « copier-coller chaque script ») est dans
[`docs/00-installation.md`](docs/00-installation.md).

## Contenu du dépôt

| Dossier / fichier | Rôle |
| --- | --- |
| `src/ReplicatedStorage/Config/` | **6 modules de configuration** : œufs, slimes, épées, effets, rangs, réglages généraux. C'est ici qu'on équilibre le jeu. |
| `src/ReplicatedStorage/Shared/` | Code partagé client/serveur : remotes, maths de combat (DPS → dégâts par coup + cadence), constructeur d'œufs, utilitaires. |
| `src/ServerScriptService/` | `Main` (démarrage), `Services/` (données, joueurs, tapis, inventaire, boutique, slimes, combat, compagnons), `Builders/` (map, slimes, épées). |
| `src/StarterPlayer/StarterPlayerScripts/` | `ClientMain` + `Controllers/` (interface, combat, effets visuels, tapis, compagnons). |
| `build/*.rbxmx` | Fichiers prêts à importer dans Studio (générés depuis `src/`). |
| `assets/icons/` | Pack de 18 icônes PNG dessinées pour l'interface (à uploader dans Studio, identifiants à coller dans `IconConfig` ; emoji de secours sinon). |
| `tools/build_rbxmx.py` | Regénère `build/` après une modification de `src/` : `python3 tools/build_rbxmx.py`. |
| `default.project.json` | Projet [Rojo](https://rojo.space) pour ceux qui préfèrent synchroniser depuis VS Code. |
| `docs/` | Installation, architecture, étapes de test, équilibrage, dépannage. |

## Fonctionnalités

- **Tapis roulant** partagé : œufs qui apparaissent, avancent et disparaissent ; achat par
  ProximityPrompt (touche **E** sur PC, bouton tactile sur mobile) ; un œuf ne peut être
  acheté qu'une seule fois même si deux joueurs appuient en même temps.
- **6 raretés d'œufs** (Commun → Mythique) × 3 variantes (Normal, Argent, Or), apparence
  différente selon la rareté (couleurs, matériaux, taches, lumière, particules, aura).
- **Compagnons** : jusqu'à 3 œufs équipés au départ (jusqu'à 6 avec les rangs), suivi fluide
  avec flottement, attaques automatiques sur un slime proche pendant le combat.
- **6 catégories de slimes** dans 6 zones, nom + barre de vie, sauts, flash de dégâts,
  animation de mort, réapparition, récompenses réparties selon les dégâts de chacun.
- **6 épées**, boutique, dégâts et cadence calculés à partir du DPS (jamais multiplié deux fois).
- **Paliers de DPS** : plus le DPS total monte, plus l'épée frappe vite (jusqu'à une vitesse
  maximale lisible) avec traînée plus large et enchaînements alternés.
- **6 effets d'attaque** cosmétiques (feu, glace, éclairs, ombres, lumière, arc-en-ciel) :
  aperçu, achat, équipement, un seul à la fois, sauvegardés.
- **Interface** : Home / Sell en haut, Bag / Shop / Index / Ranks à gauche, argent en bas à
  gauche, adaptée PC et mobile, confirmation avant chaque vente, icônes dessinées (pack PNG).
- **Décor** : arbres cartoon à feuillage en boules (dont des cerisiers), rochers moussus,
  buissons, fleurs ; slimes gélatineux translucides avec cœur, yeux, bouche et gouttes,
  couronne pour le Boss.
- **Sauvegarde** DataStore avec gestion des erreurs (sauvegarde désactivée si le chargement échoue).
- **Sécurité** : le serveur vérifie argent, distance, cadence, portée, possession ; le client ne
  choisit jamais les dégâts ni l'argent.
