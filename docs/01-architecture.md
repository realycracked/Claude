# 01 – Architecture du projet

## Principe

- **Le serveur décide de tout** (argent, dégâts, achats, équipement). Le client affiche et
  envoie des intentions : « je frappe ce slime », « j'achète cette épée ».
- **Les configurations sont centralisées** dans `ReplicatedStorage.Config`. Changer un prix,
  une probabilité ou des points de vie ne demande jamais de toucher aux services.
- **Tout est généré par script** : map, œufs, slimes, épées, interface. Aucun asset externe.

## Vue d'ensemble

```
            ┌──────────────────── CLIENT (LocalScript) ────────────────────┐
            │ UIController   CombatController   CombatVFX                   │
            │ ConveyorController   CompanionController   ClientState        │
            └───────────────┬───────────────────────────▲──────────────────┘
      RemoteFunction Request│ (actions)      RemoteEvents│ ProfileUpdated, AttackVFX,
      RemoteEvent Attack    │                            │ CompanionAttack, Notify
            ┌───────────────▼───────────────────────────┴──────────────────┐
            │ RequestRouter → InventoryService / ShopService / PlayerService│
            │ CombatService → SlimeService → PlayerService.AddCash          │
            │ ConveyorService → InventoryService.AddEgg                     │
            │ CompanionService (modèles)      DataService (DataStore)       │
            │ Builders : MapBuilder, SlimeBuilder, SwordBuilder, EggBuilder │
            └───────────────────────────────────────────────────────────────┘
```

## Modules de configuration (`ReplicatedStorage.Config`)

| Module | Contenu |
| --- | --- |
| `GameConfig` | argent de départ, spawn, tapis (longueur, vitesse, intervalle, distance d'achat), combat (portée des œufs, tolérances), vente (50 %), compagnons (positions, flottement), sauvegarde. |
| `EggConfig` | 6 raretés (prix, poids d'apparition, DPS, intervalle d'attaque, couleurs, matériau, taches, lumière, particules, aura) + 3 variantes (Normal, Argent ×2 / ×1.5, Or ×4 / ×2.5). Fonctions `GetPrice`, `GetDPS`, `GetDisplayName`, `RollRarity`, `RollVariant`. |
| `SlimeConfig` | 6 catégories : PV, récompense, taille, couleur, nombre, réapparition, zone (position, rayon). |
| `SwordConfig` | 6 épées : prix, DPS, portée, style (couleurs, matériau, longueur, lueur). |
| `EffectConfig` | 6 effets cosmétiques : prix, couleurs de traînée, couleur d'impact, lumière, particules. |
| `RankConfig` | 6 rangs selon l'argent total gagné en combat ; chaque rang fixe le nombre d'œufs équipables. |

## Code partagé (`ReplicatedStorage.Shared`)

- **`Remotes`** : crée et retrouve les RemoteEvents / RemoteFunction (dossier `ReplicatedStorage.Remotes`).
- **`CombatMath`** : le cœur de l'équilibrage.
  - `GetTotalDPS(profile)` = DPS de l'épée + DPS des œufs équipés.
  - `GetTier(totalDPS)` → palier 1 à 6 ; chaque palier a un **intervalle d'attaque** (0.60 s → 0.22 s).
  - `GetSwordAttack(profile)` → `dégâts par coup = DPS épée × intervalle du palier`. Le DPS de
    l'épée est donc constant ; seule la vitesse (et le spectacle) change.
  - `GetEggAttack(item)` → `dégâts = DPS œuf × intervalle de la rareté`.
- **`EggBuilder`** : œuf 3D en couches de blocs (forme géométrique), détails selon la rareté,
  étiquette (nom, rareté, prix vert) pour le tapis.
- **`Util`** : formatage des nombres, copies, réconciliation de sauvegarde.

## Serveur (`ServerScriptService`)

`Main` (Script) : crée les remotes et les dossiers `Workspace.ConveyorEggs / Slimes / Companions`,
génère la map, puis appelle `Init()` de chaque service dans l'ordre des dépendances.

| Service | Rôle | Vérifications serveur |
| --- | --- | --- |
| `DataService` | profils DataStore, autosave, sauvegarde à la déconnexion et à la fermeture. | si le chargement échoue → profil vide **sans** sauvegarde (jamais d'écrasement). |
| `RequestRouter` | une seule RemoteFunction `Request(action, payload)` → handlers enregistrés par les services. | anti-spam 50 ms, erreurs capturées (`pcall`). |
| `PlayerService` | arrivée/départ, leaderstats, `Push` (envoi du profil), `AddCash`, `SpendCash`, rangs, actions `GetProfile`, `GoHome`. | |
| `ConveyorService` | apparition / disparition des œufs, attributs `SpawnTime` + `StartPosition`, ProximityPrompt. | œuf non déjà vendu (réservation immédiate), distance recalculée, argent suffisant. |
| `InventoryService` | `AddEgg`, `EquipEgg`, `UnequipEgg`, `EquipBest`, `SellEgg`, `SellUnequipped`. | possession, limite d'équipement selon le rang. |
| `ShopService` | `BuySword`, `EquipSword`, `BuyEffect`, `EquipEffect`. | possession, argent. |
| `CompanionService` | crée les modèles 3D des œufs équipés dans `Workspace.Companions.<Joueur>`. | |
| `SlimeService` | apparition, sauts, PV, flash de dégâts, mort, **répartition des récompenses au prorata des dégâts**, réapparition. | drapeau `Alive` → une mort = une seule distribution. |
| `CombatService` | reçoit `Attack`, applique les dégâts, fait attaquer les œufs équipés pendant 8 s après le dernier coup. | cadence (tolérance 25 %), portée épée + tolérance, cible vivante, dégâts calculés serveur. |

Builders : `MapBuilder` (sol, chemins, zones, arbres, rochers, tapis, spawn, lumière),
`SlimeBuilder` (corps ellipsoïde, yeux, barre de vie, animations), `SwordBuilder` (épée soudée
à la main droite, traînée).

## Client (`StarterPlayer.StarterPlayerScripts`)

| Contrôleur | Rôle |
| --- | --- |
| `ClientState` | copie locale du profil, `Request(action, payload)`, notifications de changement. |
| `UIController` | toute l'interface : HUD (Home, Sell, Bag, Shop, Index, Ranks, argent, DPS), panneaux, confirmations, toasts, bouton ATTAQUE mobile, mise à l'échelle. |
| `CombatController` | clic / bouton tactile → cible la plus proche à portée → animation locale → `Attack:FireServer(slime)`. Anime aussi les coups des autres joueurs. |
| `CombatVFX` | animation du bras (Motor6D), traînée, impact (particules + lumière), nombres de dégâts, aperçu d'effet. Intensité selon le palier. |
| `ConveyorController` | position des œufs = `StartPosition + direction × vitesse × (heure serveur − SpawnTime)` ; lamelles du tapis. |
| `CompanionController` | suivi fluide (lerp) + flottement des œufs de tous les joueurs ; charge visuelle lors d'une attaque. |

## Données sauvegardées (profil)

```lua
{
  Cash = 0, TotalEarned = 0, Kills = 0,
  Eggs = { { Id = "e1", Rarity = "Common", Variant = "Normal" }, ... }, NextEggId = 2,
  Equipped = { "e1" },
  Swords = { "Wood" }, EquippedSword = "Wood",
  Effects = { "Fire" }, EquippedEffect = "Fire",   -- "" = aucun
  Discovered = { Common_Normal = true },           -- pour l'Index
}
```

## Flux principaux

**Achat d'un œuf** : prompt déclenché → `ConveyorService.tryBuy` → `Sold = true` immédiatement
→ vérifs → `SpendCash` → `InventoryService.AddEgg` (équipe automatiquement s'il reste une place)
→ `CompanionService.Refresh` → `PlayerService.Push` → le client met l'interface à jour.

**Coup d'épée** : clic → `CombatController` choisit le slime le plus proche à portée → animation
locale → `Attack:FireServer` → `CombatService.onAttack` vérifie cadence / portée / cible →
`SlimeService.ApplyDamage` → `AttackVFX:FireAllClients` (impact + animation chez les autres)
→ si PV ≤ 0 : récompenses, `PlayDeath`, réapparition après `RespawnTime`.

**Œufs compagnons** : tant que le joueur a frappé il y a moins de 8 s, chaque œuf équipé attaque
toutes les `AttackInterval` secondes le dernier slime frappé (ou le plus proche dans 28 studs)
→ `CompanionAttack:FireAllClients` → charge visuelle + nombre de dégâts.
