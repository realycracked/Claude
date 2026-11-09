# 04 – Dépannage

Ouvre toujours la fenêtre **Output** (View → Output) : les erreurs y sont écrites en rouge
avec le nom du script et le numéro de ligne.

| Symptôme | Cause probable | Solution |
| --- | --- | --- |
| `Dossier Remotes introuvable` | `Main` n'a pas démarré (mauvais type : ce doit être un **Script**, pas un ModuleScript ni un LocalScript) | Vérifie `ServerScriptService.Main` et son contenu. |
| `attempt to index nil with 'Config'` ou `Shared` | Dossier mal nommé / mal placé dans ReplicatedStorage | Les noms doivent être exactement `Config` et `Shared`. |
| `X is not a valid member of Folder "Services"` | Un ModuleScript manque ou porte un autre nom | Compare avec l'arborescence de `00-installation.md`. |
| Rien ne s'affiche à l'écran | `ClientMain` n'est pas un **LocalScript**, ou `Controllers` est mal placé | `StarterPlayer > StarterPlayerScripts > ClientMain` (LocalScript) + dossier `Controllers`. |
| Message rouge « Données non chargées » | API Services désactivés, ou DataStore injoignable | Game Settings → Security → Enable Studio Access to API Services. |
| L'épée n'apparaît pas dans la main | Personnage R6 sans `Right Arm`, ou chargement trop rapide | Le script gère R15 et R6 ; relance le jeu. En dernier recours, Game Settings → Avatar → R15. |
| Le bras tourne dans le mauvais sens | Rig personnalisé | Dans `CombatVFX.armRotation`, inverse le signe de `angle`. |
| Les œufs du tapis sont immobiles | `ConveyorController` ne tourne pas, ou `Map.Conveyor.Slats` absent | Vérifie l'Output côté client ; la map doit être générée par `MapBuilder`. |
| Un emoji s'affiche en carré | Police sans l'emoji | Remplace l'emoji par du texte dans `UIController` (ex. `Icon = "BAG"`). |
| Les œufs achetés ne suivent pas | `Workspace.Companions` manquant | Créé par `Main` ; vérifie que `Main` a bien tourné. |
| Rien ne se passe en cliquant un slime | Tu es trop loin (portée 10–12 studs + taille du slime) | Approche-toi ; le serveur rejette les coups hors portée. |
| « Trop rapide ! » en boucle | Clics très rapides sur l'interface | Normal : anti-spam de 50 ms, sans effet sur le jeu. |

## Réinitialiser la map

La map est générée seulement si `Workspace.Map` n'existe pas. Si tu l'as « figée » pour la
modifier (en la générant depuis la barre de commande), supprime `Workspace.Map` pour la
régénérer à partir des configurations.

## Remettre une sauvegarde à zéro

Change `GameConfig.Data.StoreName` (par exemple `SlimeEggs_v2`). Tous les joueurs repartent
de zéro. Pour un seul joueur, utilise le plugin DataStore Editor de ton choix ou appelle
`DataStoreService:GetDataStore("SlimeEggs_v1"):RemoveAsync("player_<UserId>")` dans la barre
de commande de Studio (API Services activés).
