# Rapport de reprise — Sillons d'Empire 0.19.0 (zonage dynamique, LOT A)

Pour reprendre le travail dans une nouvelle session. Version précédente : `RAPPORT-REPRISE-0.18.1-HISTORIQUE.md`.

## Où en est le projet

- Version **0.19.0-zonage-candidate** (code Android 190). Projet : `sillons/project.godot`, **Godot 4.7.2**, rendu Mobile, orientation capteur.
- Demande de l'auteur : zonage dynamique façon city-builder, en deux lots. Le **LOT A est livré ici** ; le **LOT B (0.20.0) reste à faire**.
- Audit : `AUDIT-ZONAGE-0.18.1.md`. Décisions de l'auteur :
  - zonage dès l'âge I ;
  - pose manuelle remplacée, parties 0.18 converties ;
  - routes ajoutées.
- Le jeu fourni en référence (APK) n'a été ni décompilé ni réutilisé.

## Ce que la 0.19.0 ajoute

**Simulation (par composition, `sim/` non réécrit)**
- `sim/urban_zoning.gd` (UrbanZoning) :
  - calques `Team.zoning` : `zone`, `road`, compteurs `rev` / `road_rev`, `linked` (parcours depuis le centre), `parcels`, `last_roads`, `v` = 1 ;
  - commandes `zone_paint`, `zone_clear`, `road_paint`, `road_remove`, `zone_historic` (champ `cells`, ou `from` / `to`) ;
  - migration 0.18 (`_migrate`, `LEGACY_CODE`).
  `SimWorld.urban_roads` est un cache dérivé non sauvegardé, qui bloque `footprint_free`.
- `sim/urban_growth.gd` (UrbanGrowth) :
  - demande, chantiers (`_new_sites`), niveaux (`_level_ups`), états (`_update_states`) ;
  - ruines (`on_destroyed`), météo (`dryness`) ;
  - balayage limité : 96 candidats par catégorie et par calcul.
- `sim/urban_city.gd` : calcul toutes les 20 ticks (au tick 7 de chaque période) pour les camps qui ont une ville ou l'électricité. Ère pré-électrique (puits, garde), nourriture, émeutes, intensité du feu ; puis `UrbanGrowth.step`.
- `sim/urban_ai.gd` : `zone_for` (zones près d'une route reliée, sinon plan de routes `road_plan`), demande suivie.

**Interface et rendu**
- `interface/zoning_tool.gd` (ZoningTool) : gestes (`begin` / `drag` / `end`), annuler (30), inspecter. `interface/zoning_panel.gd` (ZoningPanel) : barre compacte.
- `game/hud.gd` : bouton Zones, `toggle_zoning`, place en portrait. `game/game.gd` : routage des touchers en mode `zone`.
- `game/world_view.gd` :
  - textures `road_tex`, `zone_tex`, `filter_tex` pour le shader du terrain (`game/realism/terrain.gdshader`) ;
  - `refresh_urban_layers`, appelé aussi en pause ;
  - `set_overlay` : 1 = zonage, 2 = filtre, prévu pour le LOT B ;
  - modèles `UrbanVisual` avec signature.
- `game/urban_visual.gd` (UrbanVisual) : modèles composés (catégorie, niveau, âge, état).

## Vérifier

```
cd sillons
GODOT_BIN=godot bash tools/verify-refonte.sh      # statique (17 suites), import, compilation, glyphes, 63 scénarios
python3 -I tools/verify-urbain-static.py          # contrôle statique ville + zonage
```
Recettes du zonage : `zoning` (79), `ui_zoning` (26). Après toute modification : `git add`, puis `python3 -I tools/update-manifest-j13.py`. Une nouvelle classe exige `godot --headless --path . --import` avant la compilation.
Captures : `tools/capture-ui-017.gd`, modes `quartier` et `zonage`. Pour le portrait : `--resolution 740x1600`.

## LOT B à faire (0.20.0)

1. Silhouettes plus distinctes pour chacun des 10 âges (`game/urban_visual.gd`), quartiers historiques visibles.
2. IA : zonage plus fin avant l'électricité, réaction aux crises.
3. Multi-échelle : ville abrégée pour les colonies et les vues orbite, système et galaxie (agrégats par camp, sans bâtiments).
4. Filtres visuels : `filter_tex` et `set_overlay(2)` sont prêts ; il manque le calcul des valeurs par case et les boutons.
5. Événements extensibles : séisme, inondation, tempête, crise économique, migration.
6. Performances :
   - répartir le calcul de la ville sur plusieurs ticks (pic actuel : 16 ms sous Linux pour 136 bâtiments) ;
   - fixer un seuil Android mesuré.

## Ce qui reste (honnêtement)

- **Android : NOT_RUN** (recette manuelle dans la validation). Aucun APK : pas de SDK Android ni de modèles d'export ici, réseau coupé.
- **Équilibrage** : toutes les valeurs sont provisoires.
- La capture du quartier est préparée : plusieurs âges sont réunis pour la montrer.
