# Modèles d'arbres externes (poly.pizza)

Trois arbres low poly fournis par le joueur, à importer dans Roblox Studio pour remplacer
les arbres générés par script (voir `docs/05-assets-externes.md`).

| Dossier | Fichiers | Auteur (source poly.pizza) | Licence à vérifier sur la page du modèle |
| --- | --- | --- | --- |
| `Tree_Quaternius/` | `Tree2.fbx` | Quaternius | CC0 (les packs Quaternius sont en domaine public) |
| `Tree2_MarcSola/` | `model.obj` + `materials.mtl` (couleurs violet / bleu) | Marc Solà | généralement CC-BY : citer l'auteur dans la description du jeu |
| `Tree_PolyByGoogle/` | `tree01.obj` + `tree01.mtl` + `tree_texture.png` | Poly by Google | CC-BY : citer « Poly by Google » |

## Importer dans Studio

1. Onglet **Home** → **Import 3D** → choisir `Tree2.fbx`, `model.obj` ou `tree01.obj`
   (pour l'OBJ, garder le `.mtl` et la texture dans le même dossier : Studio les lit avec).
2. Studio crée un **MeshPart** ou un **Model**. Vérifie que toutes ses parts sont **Anchored**
   et que le pivot est au pied du tronc (clic droit → *Pivot* → *Reset*), sinon l'arbre flotte.
3. Dans l'Explorateur : `ReplicatedStorage` → dossier `Assets` → dossier `TreeModels` →
   glisse le modèle dedans. Au prochain lancement, `MapBuilder` choisit au hasard un de ces
   modèles pour chaque emplacement d'arbre à la place des styles A/B générés.
4. Taille : les arbres générés font 10 à 14 studs de haut. Si un modèle importé est trop
   petit ou trop grand, sélectionne-le et utilise l'outil *Scale* de Studio avant de le placer
   dans `TreeModels`.

Pour mélanger arbres importés et arbres générés, vide `TreeModels` de temps en temps ou
duplique les modèles importés avec des échelles différentes : `MapBuilder` n'utilise les
modèles importés que si le dossier n'est pas vide.
