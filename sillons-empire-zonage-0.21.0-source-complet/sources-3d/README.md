# Sillons d'Empire — bibliothèque d'assets 3D 1.0.0

800 modèles originaux, chacun en 3 niveaux de détail (2 400 fichiers GLB autonomes), générés par la chaîne
`assets_pipeline/` du dépôt. Rapport complet : `report.html`. Catalogue : `catalog.csv`, `manifest.json`.

## Ce qu'il faut savoir avant de s'en servir

- **Style** : volumes géométriques « low-poly » lisibles en vue de stratégie, matériaux PBR. Ce ne sont **pas** des modèles
  photoréalistes sculptés à la main ; aucun outil de sculpture ni Blender n'était disponible.
- **Vérifié réellement** : structure de chaque fichier relu, import et instanciation des 2 400 fichiers dans Godot 4.7.1
  (sans affichage), squelettes, animations, collisions.
- **Non vérifié** : rendu dans Godot avec carte graphique, Android, Galaxy S25 Ultra, images par seconde. Les budgets de
  triangles sont des cibles à mesurer.
- **Revue visuelle** : faite sur des planches d'aperçus (rendu logiciel), pour une partie des catégories seulement.
  `report.json` dit, asset par asset, ce qui a été regardé (`reviewed_ok`), ce qui est à reprendre (`needs_work`)
  et ce qui n'a pas été regardé (`not_reviewed`).

## Conventions

Mètres, Y vers le haut, avant du modèle vers +Z, pivot au sol au centre de l'emprise (vaisseaux et structures orbitales :
pivot au centre). Parcelle = 8 m. Routes et rails : dalles de 8 × 8 m, raccord au milieu des bords, épaisseur 0,12 m,
ponts et rampes à +2,4 m. Les pièces de courbe relient le bord −Z au bord +X.

| Dossier | Contenu |
|---|---|
| `buildings/residential`, `commercial`, `industrial` | 30 bâtiments urbains : **géométrie des 30 GLB fournis** (`sources/`, conservés intacts), convertie en Y-haut, normales et UV recalculés, couleurs par sommet remplacées par des matériaux PBR |
| `buildings/special` | 120 bâtiments : commandement, casernes, murs, tours, portes, hôpitaux, police, pompiers, énergie, eau, entrepôts, dépôts, laboratoires, universités, recherche, usines, radars, aéroports, ports, spatioports, chantiers navals, défenses, temples, marchés |
| `units/civilian` | 110 personnages (17 rôles) |
| `units/military` | 180 : infanterie, cavalerie, engins de siège, artillerie, tourelles, drones terrestres, robots, exosquelettes |
| `vehicles/ground`, `air`, `naval` | 90 + 41 + 29 |
| `space/ships`, `space/orbital_structures` | 80 + 30 |
| `roads` | 90 pièces de routes, voies industrielles et rails |
| `materials/materials.json`, `textures/` | 58 matériaux PBR, 174 textures carrelables 128 px (base, normale, occlusion-rugosité-métal) |
| `previews/` | 800 vignettes, 18 planches par catégorie, 10 planches par âge |

## Matériaux

Chaque GLB contient ses matériaux PBR en **facteurs** (couleur, métal, rugosité, émission) et ses UV : il s'affiche seul.
Les textures ne sont pas recopiées dans les 2 400 fichiers : elles sont partagées et appliquées par nom de matériau
(projection triplanaire) par `AssetLibrary`. Le matériau `team` est la couleur de camp.

## Personnages

Squelette commun de 11 os (`hips, spine, head, arm_upper/lower_l/r, leg_upper/lower_l/r`), skinning rigide,
animations `idle`, `walk`, `attack`, `work` dans chaque fichier. Les cavaliers utilisent le même squelette, relevé à la selle ;
la monture est statique.

## Éléments mobiles

Nœuds nommés, pivot à l'axe : `wheel_*`, `track_l/r`, `turret`, `gun`, `barrel`, `rotor`, `propeller*`, `ramp`, `door`,
`crane`, `ladder`, `blade`, `antenna`, `radar`, `sail_*`, `engine_*`, `turret_*`, `hangar_*`, `solar_*`, `dock_arm_*`, `ring`…
La liste par asset est dans `manifest.json` (`nodes`).

## Dans Godot

```gdscript
var id: String = AssetLibrary.find("building_special", "hospital", 7)   # famille + âge -> identifiant
var node: Node3D = AssetLibrary.instantiate(id, 0)                       # 0 proche, 1 intermédiaire, 2 lointain
AssetLibrary.set_team_color(node, Color.RED)
node.scale = Vector3.ONE * AssetLibrary.scale_for_cells(id, 4.0)        # tenir dans 4 cases de la carte tactique
```

Le nœud `collision-colonly` de chaque LOD0 devient une forme de collision à l'import. Test : `lab/assets_3d_test.gd`.
`technology_id` relie un asset à l'identifiant du jeu (`centre`, `caserne`, `char`, `fregate`…) quand il existe ; il est vide
pour les familles que le jeu ne simule pas encore.

## Limites connues

- Les modèles ne sont **pas encore affichés par le jeu** : la bibliothèque et son chargeur sont livrés et testés, le
  remplacement des visuels actuels (`unit_visual.gd`, `building_visual.gd`, globe) reste à faire.
- Frégate, destroyer, croiseur, cuirassé : silhouettes trop proches ; drones constructeurs Mk1–3 peu différenciés ;
  carrefours industriels à reprendre (marqués `needs_work`).
- Emprises : un modèle par bâtiment, pas encore de modules d'extension 2×1 / 4×2 séparés.
- Skinning rigide (pas de déformation douce aux articulations) ; montures, véhicules et tourelles sans animation enregistrée
  (les pivots sont prêts).
- Niveaux de détail des personnages peu réduits (formes déjà simples).
- Textures procédurales simples en 128 px.
