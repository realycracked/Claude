# 00 – Installation dans Roblox Studio

Deux méthodes. La méthode A (import de 3 fichiers) est la plus rapide et évite les fautes
de frappe. La méthode B explique où va chaque script si tu préfères tout créer à la main.

## Méthode A – importer les fichiers `.rbxmx` (recommandée)

1. Studio → **New** → modèle **Baseplate**.
2. Récupère les trois fichiers du dossier `build/` du dépôt (bouton *Download* sur GitHub,
   ou clone le dépôt).
3. Dans la fenêtre **Explorer** de Studio (View → Explorer si elle est cachée) :

   | Clic droit sur… | Insert from File… | Résultat |
   | --- | --- | --- |
   | `ReplicatedStorage` | `ReplicatedStorage.rbxmx` | dossiers `Config` et `Shared` |
   | `ServerScriptService` | `ServerScriptService.rbxmx` | `Main` + dossiers `Services`, `Builders` |
   | `StarterPlayer` → `StarterPlayerScripts` | `StarterPlayerScripts.rbxmx` | `ClientMain` + dossier `Controllers` |

   Si Studio insère les objets dans `Workspace` au lieu du service sélectionné, fais-les
   glisser au bon endroit dans l'Explorateur.
4. **Home → Game Settings → Security → Enable Studio Access to API Services** → coché →
   Save. Sans cela la sauvegarde ne fonctionne pas en test (le jeu tourne quand même, un
   avertissement s'affiche).
5. **Play** (F5). Dans la fenêtre *Output* tu dois lire `[SlimeEggs] Serveur prêt ✔` puis
   `[SlimeEggs] Client prêt ✔`.

Le modèle Baseplate de Studio contient une `Baseplate` et un `SpawnLocation` : le script
`MapBuilder` les supprime automatiquement au démarrage et génère la map du jeu.

## Méthode B – créer les scripts à la main

Arborescence à reproduire exactement (les noms comptent : ils sont utilisés par `require`).

```
ReplicatedStorage
├─ Config (Folder)
│  ├─ GameConfig        (ModuleScript)
│  ├─ EggConfig         (ModuleScript)
│  ├─ SlimeConfig       (ModuleScript)
│  ├─ SwordConfig       (ModuleScript)
│  ├─ EffectConfig      (ModuleScript)
│  └─ RankConfig        (ModuleScript)
└─ Shared (Folder)
   ├─ Remotes           (ModuleScript)
   ├─ Util              (ModuleScript)
   ├─ CombatMath        (ModuleScript)
   └─ EggBuilder        (ModuleScript)

ServerScriptService
├─ Main                 (Script)          ← le seul Script serveur
├─ Services (Folder)
│  ├─ DataService       (ModuleScript)
│  ├─ RequestRouter     (ModuleScript)
│  ├─ PlayerService     (ModuleScript)
│  ├─ CompanionService  (ModuleScript)
│  ├─ InventoryService  (ModuleScript)
│  ├─ ShopService       (ModuleScript)
│  ├─ SlimeService      (ModuleScript)
│  ├─ CombatService     (ModuleScript)
│  └─ ConveyorService   (ModuleScript)
└─ Builders (Folder)
   ├─ MapBuilder        (ModuleScript)
   ├─ SlimeBuilder      (ModuleScript)
   └─ SwordBuilder      (ModuleScript)

StarterPlayer
└─ StarterPlayerScripts
   ├─ ClientMain        (LocalScript)     ← le seul LocalScript
   └─ Controllers (Folder)
      ├─ ClientState         (ModuleScript)
      ├─ UIController        (ModuleScript)
      ├─ CombatVFX           (ModuleScript)
      ├─ CombatController    (ModuleScript)
      ├─ CompanionController (ModuleScript)
      └─ ConveyorController  (ModuleScript)
```

Pour chaque entrée : clic droit sur le parent → *Insert Object* → choisir **Folder**,
**Script**, **LocalScript** ou **ModuleScript** → renommer (F2) → double-cliquer → effacer
le contenu → coller le fichier correspondant de `src/`. Correspondance des noms de fichiers :

| Fichier dans `src/` | Objet Studio |
| --- | --- |
| `Nom.server.lua` | **Script** nommé `Nom` |
| `Nom.client.lua` | **LocalScript** nommé `Nom` |
| `Nom.lua` | **ModuleScript** nommé `Nom` |

Rien d'autre n'est à créer : les dossiers `Workspace.Map`, `ConveyorEggs`, `Slimes`,
`Companions`, le dossier `ReplicatedStorage.Remotes` et l'interface `MainGui` sont
fabriqués par les scripts au lancement.

## Activer les icônes (images du dossier `assets/icons/`)

Le projet fournit 18 icônes PNG (256×256, fond transparent) : sac, caddie, livre, graphique,
maison, pièces, billet, épée, œuf, épées croisées, feu, glace, éclair, ombre, lumière,
arc-en-ciel, étoile, fermer. Tant qu'elles ne sont pas uploadées, l'interface affiche des
emoji à la place : le jeu fonctionne dans les deux cas.

1. Studio → onglet **View** → **Asset Manager** → bouton **Bulk Import** → sélectionne tous les
   PNG de `assets/icons/` (sauf `_planche.png`). Chaque image passe par la modération Roblox
   (quelques minutes en général).
2. Dans l'Asset Manager, dossier **Images** : clic droit sur une image → **Copy ID to clipboard**.
3. Ouvre `ReplicatedStorage > Config > IconConfig` et colle chaque identifiant sous la forme
   `rbxassetid://123456789` dans la table `Images` (une ligne par icône, le nom du fichier est
   indiqué en commentaire).
4. Relance le jeu : les boutons Home / Sell / Bag / Shop / Index / Ranks, le billet d'argent,
   le bouton ATTAQUE, les cartes d'œufs (image teintée selon la rareté) et les effets utilisent
   les images.

## Méthode C – Rojo (développeurs)

`default.project.json` est fourni. Avec [Rojo](https://rojo.space) installé :
`rojo serve` puis connecter le plugin Rojo dans Studio. `rojo build -o SlimeEggs.rbxlx`
construit un lieu complet.

## Tester sur mobile

Studio → onglet **Test** → **Device** → choisir un téléphone. Le bouton rouge **ATTAQUE**
apparaît en bas à droite, et les ProximityPrompts du tapis affichent un bouton tactile.
L'interface se met à l'échelle automatiquement (`UIScale` dans `UIController`).

## Tester à plusieurs

Studio → onglet **Test** → **Clients and Servers** → 2 joueurs → **Start**. Utile pour vérifier
qu'un même œuf ne peut être acheté qu'une fois et que les récompenses des slimes sont
réparties selon les dégâts.
