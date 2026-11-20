# Rapport de reprise — Sillons d'Empire 0.20.0 (zonage dynamique, LOTS A et B)

Pour reprendre le travail dans une nouvelle session. Versions précédentes : `RAPPORT-REPRISE-0.19.0-HISTORIQUE.md` (LOT A), `RAPPORT-REPRISE-0.18.1-HISTORIQUE.md`.

## Où en est le projet

- Version **0.20.0-zonage-candidate** (code Android 200). Projet : `sillons/project.godot`, **Godot 4.7.2**.
- La demande de zonage dynamique est livrée en entier : **LOT A** en 0.19.0, **LOT B** en 0.20.0.
- Reste à faire hors de cet environnement :
  - recette sur téléphone et APK (NOT_RUN) ;
  - équilibrage en partie réelle.

## Ce que la 0.20.0 ajoute (détail technique)

**Événements** — `sim/urban_events.gd` (UrbanEvents)
- `EVENTS` décrit chaque événement par des données : `area`, `damage`, `fire`, `extinguish`, `flood`, `output`, `demand`, `density`, `duration`, `condition`.
- `step` est appelé par `UrbanCity.step` après chaque calcul de camp. Tirage tous les 15 calculs, déterministe, jamais avant `GRACE_TICKS` (9000).
- `start` déclenche un événement (aussi par la commande de recette `lab_urban_event`).
- `output_mult` et `demand_bias` sont lus par la production (`UrbanCity`) et la demande (`UrbanGrowth.demand`).
- Données sauvegardées : `t.city["events"]` et `b.city["flooded"]`.

**Villes à plusieurs échelles**
- `SimWorld.urban_far` et `urban_phase` sont fixés à chaque tick par `StarCampaign.step` et `EvolutionCampaign.step`.
- `UrbanCity.step` :
  - calcule les camps pairs à `7 + phase` et les camps impairs 10 ticks plus tard ;
  - pour un monde lointain, ne calcule qu'une période sur `FAR_EVERY` (3), avec `time_scale` = 3 ;
  - `period_s()`, `prob_scaled()` et `ease_scaled()` ajustent durées, chances et lissages.
- `sim/urban_abstract.gd` (UrbanAbstract) fournit `summary`, `empire`, `empire_line` (lecture seule).

**Performance**
- `UrbanZoning.linked` garde son résultat pour le tick en cours (`linked_tick`, `linked_rev`).
- Outil : `tools/profile-urban.gd`.

**IA**
- `UrbanAI.think_early` (avant l'électricité) est appelé depuis `AiController._economy` ; il zone seulement sur les surplus (`EARLY_RESERVE`), selon les plafonds `EARLY_ZONES`.
- `zone_for` ne garde en réserve que les ressources que la route coûte à l'âge en cours.

**Interface**
- `CityOverlay` : 8 vues en plus, `FILTERS`, `NEUTRAL`, teintes dessinées sans test de profondeur.
- `ZoningPanel` : `filter_btn`, `cycle_filter`, `set_filter`.
- `CityPanel` : sections « ÉVÉNEMENTS » et « TOUTES VOS VILLES ».

**Visuel**
- `UrbanVisual.ERA` : 10 palettes, une par âge.
- `UrbanVisual._crown` : toiture propre à chaque âge, à partir du niveau IV.
- Captures : `tools/capture-ui-017.gd`, modes `ages` et `filtre` (en plus de `quartier` et `zonage`).

## Vérifier

```
cd sillons
GODOT_BIN=godot bash tools/verify-refonte.sh      # statique (17 suites), import, compilation, glyphes, 64 scénarios
python3 -I tools/verify-urbain-static.py          # ville, zonage, LOT B
godot --headless --path . --script res://tools/profile-urban.gd   # coût du calcul, partie par partie
```

Après toute modification :
1. `git add` ;
2. `python3 -I tools/update-manifest-j13.py`.

Une nouvelle classe exige `godot --headless --path . --import` avant la compilation.

## Pistes pour la suite

1. Mesurer sur téléphone les seuils P01, P02 et M05 et la fluidité avec deux grandes villes. Si le calcul d'une très grande ville saccade, le répartir sur plusieurs ticks à l'intérieur d'un même camp.
2. IA après l'électricité : garder une réserve de bois pour les réparations de sa ville.
3. Équilibrer les événements et le rythme des villes lointaines en partie réelle.
4. Habitat de niveau I à III : des modèles propres à chaque âge (la bibliothèque n'en a qu'un tous les deux âges).

## NOT_RUN

- Android, Galaxy S25 Ultra et APK : pas de SDK Android ni de modèles d'export ici, réseau coupé.
