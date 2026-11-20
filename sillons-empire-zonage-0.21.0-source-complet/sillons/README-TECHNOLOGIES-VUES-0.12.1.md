# Sillons d’Empire — 0.12.1 candidate : progression technologique des vues

À partir de J12 0.12.0. Les sauvegardes de campagne restent dans le format J12 ; aucune progression existante n’est effacée. Un joueur dont l'âge est élevé mais qui n'a pas les nouvelles recherches doit les acheter pour consulter les vues correspondantes.

## Déblocage par joueur

| Échelle | Âge | Recherche | Bâtiment, à Val des Deux Gués | Coût de base | Durée |
|---|---|---|---|---|---|
| Terrain tactique | I | Aucune | — | — | — |
| Planétaire | II | Cartographie terrestre | Marché | 120 bois, 90 minerai | 30 s |
| Orbitale | IX | Observation orbitale (après cartographie) | Spatioport | 180 bois, 400 minerai | 45 s |
| Système stellaire | IX | Navigation interplanétaire (après observation) | Spatioport | 200 nourriture, 600 minerai | 60 s |
| Galaxie | X | Navigation stellaire puis cartographie galactique | Chantier orbital | 300 bois, 1000 minerai puis 200 bois, 900 minerai | 80 s puis 85 s |

Les coûts sont soumis au multiplicateur de règles du scénario ; durées de recherche à vitesse simulation ×1. Les prérequis sont vérifiés par le moteur, les boutons de recherche par l'UI, et l'accès par chaque chemin de navigation (dézoom, zoom, panneau stratégique, gestes souris et tactiles).

Pour ouvrir l'arbre : **Âge → Parcours technologique** ou **Pause → Progression : accès aux vues**. Chaque bouton indique le bâtiment manquant, les ressources, la recherche précédente ou l'état de progression.

Les ateliers de développement et les deux tests UI J10/J11 démarrent avec des recherches explicitement acquises ; les parties normales n'utilisent aucun déblocage forcé.

## Correctifs de chargement

Deux défauts d'indentation dans `lab/recette_suite.gd` ont été corrigés dans les gardes `_home_port` et `yard`. Les scripts `game/recette_screen.gd` et `lab/recette_integrale_test.gd` dépendent de `RecetteSuite` et ne devraient plus échouer à cause de ces deux blocs. Cette correction n'a pas encore été confirmée par le parseur réel de Godot dans cet environnement.

## Recette

- `./tools/verify-j12.sh` exécute les contrôles hérités et `lab/view_technology_test.gd` avec Godot.
- Sans le moteur, le script retourne 127 (non exécuté). L'intégrité du ZIP et les vérifications statiques ne garantissent pas que GDScript compile.
- `./tools/export-android-j12.sh` exporte `build/sillons-empire-j12-debug-0.12.1.apk` après la recette.
