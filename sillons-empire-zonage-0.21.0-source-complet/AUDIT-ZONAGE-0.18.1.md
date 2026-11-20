# Audit avant le zonage urbain — Sillons d'Empire 0.18.1

Base auditée : 0.18.1 (61 scénarios sur 61). Fait avant toute modification, sur le code réellement présent.

## 1. Ce qui existe

| Domaine | Code | Constat |
|---|---|---|
| Simulation | `sim/sim_world.gd` (SimWorld) | Pas fixe 10 Hz, commandes `issue` → `_apply`, tout état dans des objets (Unit, Building, Node, Squad, Team) ; carte carrée (`map_size`), `terrain` (herbe / eau / gué), cases occupées `_occupied`, AStar. |
| Construction | `SimWorld._apply("build")`, `spawn_building`, `footprint_free` | Les ouvriers bâtissent (progress → `complete`). Emprises carrées, `Building.size`. Démolition (0.17) et destruction `_destroy_building`. |
| Ville 0.18 | `sim/urban_rules.gd`, `sim/urban_city.gd`, `sim/urban_ai.gd` | Après la recherche Électricité : zones habitation / commerce / industrie **posées comme des bâtiments** (2×2), 3 niveaux achetés, densité, réseaux électricité / eau, services à rayon et capacité, criminalité, incendies (propagation, destruction), épidémies, bien-être, production, IA. Calcul toutes les 20 ticks (2 s). État dans `Building.city` et `Team.city`. |
| Routes | — | **Aucune route** sur la carte de bataille (des routes n'existent que sur le globe, `PlanetCampaign`). |
| Économie | `Team.res` (food, wood, ore), `_pay`, `_can_pay`, `scaled_cost` | Trois ressources réelles ; la ville 0.18 produit dans ces mêmes ressources. |
| Population | `Team.pop`, `Team.pop_cap` | Maisons (+6), centre ; ville 0.18 : 4 habitants = 1 place. |
| Âges | `sim/age_progression.gd`, `sim/civ_evolution.gd` | Âges I à X par camp (`Team.age`) ; modèles 3D choisis par famille et âge. |
| Tactile | `game/game.gd` (`_unhandled_input`), `interface/placement_tool.gd` | Un doigt : déplacer / sélectionner / glissés spéciaux (ligne de murs, visée) ; deux doigts : zoom, rotation, déplacement. Retour Android géré par `_back_action`. |
| Sauvegarde | `sim/save_game.gd` | Version 1 stricte, SHA-256 ; **toutes les variables de script** des entités et des camps sont sauvegardées automatiquement (nouveaux champs inclus, absents = valeur par défaut). |
| Planète / colonies / espace | `sim/planet_campaign.gd`, `sim/star_campaign.gd`, `sim/j13_*` | Colonies par corps céleste, districts, installations, trésorerie ; économie du globe séparée de la carte de bataille. |
| Performances | `lab/j12_perf_test.gd`, `lab/android_performance*_test.gd`, `game/world_view.gd` | Régulateur visuel (détails rapprochés limités, LOD, lots lointains), terrain par tuiles avec un seul matériau (`game/realism/terrain.gdshader`). |
| Modèles 3D | `game/asset_library.gd` (800 modèles), `game/tactical_models.gd` | **Un seul modèle par âge** pour habitation, commerce et industrie (10 chacun) ; services : police (âges III+), pompiers (IV+), hôpital (I+), eau (I+), énergie (III+), entrepôt, marché, temple… |
| Urbanisme existant | ville 0.18 | Déjà : services, réseaux, criminalité, incendies, épidémies, bien-être, IA. **À ne pas recréer** : on l'étend. |

## 2. Décisions de l'auteur (19/11/2026)

1. Zonage **dès l'âge I**, à côté de la récolte des ouvriers ; la bascule Électricité de la 0.18 reste (fin de la récolte, maisons converties).
2. La pose manuelle des zones-bâtiments de la 0.18 est **remplacée** par le zonage peint ; dans les anciennes sauvegardes, chaque zone posée devient une parcelle zonée avec son bâtiment.
3. **Routes ajoutées** : un bâtiment ne pousse que près d'une route reliée au centre.
4. Aucun contenu du jeu cité en référence n'est repris : seules les règles habituelles du genre.

## 3. Architecture d'intégration (par composition, comme en 0.17 et 0.18)

- **`sim/urban_zoning.gd` (UrbanZoning)** — couches par camp dans `Team.zoning` (sauvegardées) : `zone` (code par case) et `road` (cases de route). Commandes `zone_paint`, `zone_clear`, `road_paint`, `road_remove` passées par `SimWorld.issue` (joueur et IA). Réseau routier relié au centre (parcours en largeur, recalculé seulement quand les routes changent). Migration paresseuse des sauvegardes 0.18.
- **`sim/urban_growth.gd` (UrbanGrowth)** — demande habitation / commerce / industrie / agriculture tirée de la vraie économie ; choix des parcelles 2×2 éligibles (zonées, libres, constructibles, près d'une route reliée, demande, ressources réelles payées, main-d'œuvre, sécurité, pas d'ennemi proche) ; construction progressive sans ouvrier ; niveaux par catégorie selon l'âge ; densification ; états des bâtiments ; ruines et reconstruction.
- **`sim/urban_city.gd`** (0.18) — étendu : fonctionne avant l'Électricité avec des besoins d'époque (pas de réseau électrique avant la recherche), criminalité et incendies enrichis (causes, conséquences, intensité, matériaux, temps qu'il fait), états.
- **Bâtiments** : les bâtiments qui poussent restent des `SimWorld.Building` (`zone_r`, `zone_c`, `zone_i`, nouveau `zone_a`) : électricité, eau, services, incendies, sauvegarde et IA de la 0.18 continuent de fonctionner sur eux. Nouveau bâtiment `ruine`.
- **Visuel** : `game/urban_visual.gd` compose chaque bâtiment selon catégorie, niveau, âge de construction, variante, orientation et état (échafaudage, fumée, flammes, brûlé, dégradé, abandonné, prospère) à partir des modèles existants et de volumes simples ; routes et calque des zones dessinés **par le shader du terrain** (une texture, aucune géométrie en plus) ; calque visible seulement en mode zonage ou filtre.
- **Interface** : mode **Zonage** (pinceau, rectangle, parcelle, gomme, routes, types, annuler), fiche de quartier.

Hooks d'une ligne dans `sim_world.gd` (case de route non constructible, pas de simulation), `world_view.gd` (modèle composé pour les zones), `game.gd` (gestes du mode zonage). Aucun fichier historique supprimé.

## 4. Limites connues dès l'audit

- Un seul modèle par âge et par catégorie : la diversité vient de la composition (volumes, annexes, étages, orientation, mélange avec l'âge précédent), pas de nouveaux modèles.
- Aucun SDK Android ni modèle d'export Android dans l'environnement, réseau fermé : **APK impossible ici (NOT_RUN)**.
- Le temps qu'il fait n'existe pas dans le jeu : un cycle sec / humide déterministe est ajouté pour les incendies.
