# 05 – Ressources externes (meshs, modèles, images)

Le jeu fonctionne entièrement sans ressource externe : tout est généré par script. Mais si tu
veux des œufs, des arbres ou des décors encore plus travaillés, voici où chercher et comment
les brancher sans toucher au code.

## Où chercher

| Source | Quoi | Licence | Comment récupérer |
| --- | --- | --- | --- |
| **Creator Store** (dans Studio : onglet *View* → *Toolbox*, filtre *Models* ou *Meshes*) | modèles Roblox prêts à l'emploi | gratuits, vérifie l'auteur et les avis | glisser dans le Workspace, puis déplacer dans `ReplicatedStorage > Assets > …` |
| **poly.pizza** | milliers de modèles low poly (.glb / .fbx) | CC0 ou CC-BY (nom de l'auteur à citer) | télécharger en `.fbx`, importer dans Studio |
| **kenney.nl** (packs *Nature Kit*, *Platformer Kit*, *Castle Kit*) | arbres, barrières, rochers, nuages low poly | CC0 (libre) | télécharger le pack, importer les `.fbx` ou `.obj` |
| **quaternius.com** | packs low poly animés et statiques (nature, créatures) | CC0 | idem |
| **sketchfab.com** (filtres *Downloadable* + licence CC0 / CC-BY) | modèles plus détaillés | selon le modèle | télécharger en `.glb` / `.fbx` |
| **itch.io** (recherche « low poly pack ») | packs d'assets | selon le pack | idem |

Termes de recherche utiles (en anglais, c'est là qu'il y a le plus de résultats) :
`low poly egg`, `cartoon egg`, `pet simulator egg`, `low poly tree`, `stylized tree`,
`low poly fence`, `wooden fence`, `low poly cloud`, `cartoon slime`, `low poly rock`,
`low poly bush`, `low poly flower`.

Pour les icônes 2D : le pack fourni dans `assets/icons/` suffit. Si tu veux d'autres icônes :
**flaticon.com** (attribution requise en gratuit), **game-icons.net** (CC-BY), **icons8.com**.

## Importer un mesh dans Studio

1. Onglet **Home** → **Import 3D** (ou *View* → *Asset Manager* → *Bulk Import*).
2. Choisis le fichier `.fbx`, `.obj` ou `.glb`. Studio crée un **MeshPart** (ou un **Model**
   s'il y a plusieurs pièces). Les textures sont uploadées avec et passent par la modération.
3. Dans l'Explorateur, crée un dossier `Assets` dans `ReplicatedStorage`, puis les sous-dossiers
   ci-dessous selon ce que tu veux remplacer.

## Brancher les meshs dans le jeu

### Œufs : `ReplicatedStorage > Assets > EggMeshes`

Place un **MeshPart** (ou un Model) **nommé comme la rareté** : `Common`, `Uncommon`, `Rare`,
`Epic`, `Legendary`, `Mythic`. `EggBuilder` l'utilise à la place de la coquille générée, le met à
l'échelle sur la hauteur de l'œuf et le recolore avec la couleur de la rareté.
Pour garder la texture d'origine, ajoute l'attribut booléen `KeepColor = true` sur le mesh
(onglet *Properties* → *Attributes* → `+`). Les taches, ornements, lumière, particules et aura
restent ajoutés par le code.

### Arbres déjà fournis dans le dépôt : `assets/models/trees/`

Trois arbres low poly (Quaternius, Marc Solà, Poly by Google, trouvés sur poly.pizza) sont
inclus avec leurs fichiers `.fbx` / `.obj`. Le `README.md` du dossier explique l'import et
les licences (attribution à citer pour les modèles CC-BY).

### Arbres : `ReplicatedStorage > Assets > TreeModels`

Dépose un ou plusieurs **Models** d'arbres (n'importe quel nom). `MapBuilder` en choisit un au
hasard pour chaque emplacement d'arbre à la place des 5 styles générés. Vérifie que le pivot
du modèle est au pied du tronc (clic droit → *Pivot* → *Reset*) et que les parts sont **Anchored**.

### Slimes

Les slimes gardent leur construction par script (yeux, cornes, cristaux, fissures, animations) :
c'est elle qui différencie les six catégories. Pour changer leur allure, modifie
`SlimeConfig.Looks` (nombre d'yeux, cornes, pointes, particules, aura…) ou leurs couleurs.

## Licences : à retenir

- **CC0** : libre, sans condition.
- **CC-BY** : libre, mais il faut citer l'auteur (par exemple dans la description du jeu).
- Les ressources du Creator Store sont utilisables dans Roblox ; évite les modèles contenant des
  scripts que tu ne comprends pas (supprime tout `Script` à l'intérieur avant de les utiliser).
