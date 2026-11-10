# Modèles d'œufs externes (poly.pizza)

| Dossier | Fichiers | Auteur (source poly.pizza) | Licence à vérifier sur la page du modèle |
| --- | --- | --- | --- |
| `Egg_PolyByGoogle/` | `CHAHIN_UNCRACKED_EGG.obj` + `.mtl` + `CHAHIN_UNCRACKED_EGG_TEXTURE.jpg` | Poly by Google (modèle « Egg ») | CC-BY : citer « Poly by Google » dans la description du jeu |

## Importer dans Studio et l'utiliser pour les œufs du jeu

1. Onglet **Home** → **Import 3D** → `CHAHIN_UNCRACKED_EGG.obj` (garde le `.mtl` et le `.jpg`
   dans le même dossier : Studio importe la texture avec, elle passe par la modération).
2. Studio crée un **MeshPart**. Dans l'Explorateur : `ReplicatedStorage` → dossier `Assets`
   → dossier `EggMeshes` → glisse le MeshPart dedans et **renomme-le avec la rareté** qu'il doit
   représenter : `Common`, `Uncommon`, `Rare`, `Epic`, `Legendary` ou `Mythic`.
   Pour l'utiliser pour toutes les raretés, duplique-le (Ctrl+D) et renomme chaque copie.
3. `EggBuilder` le met automatiquement à l'échelle de l'œuf et le **recolore** avec la couleur
   de la rareté. Pour garder la texture d'origine, ajoute l'attribut booléen `KeepColor = true`
   sur le MeshPart (*Properties* → *Attributes* → `+`).
4. Les taches, ornements (éclats, anneaux, orbites), lumière, particules et aura de la rareté
   restent ajoutés par le code autour du mesh.
