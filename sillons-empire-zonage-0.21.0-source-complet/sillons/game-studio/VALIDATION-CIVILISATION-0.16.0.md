# Validation — 0.16.0 candidate (évolution de la civilisation)

Environnement : Linux x86_64, **Godot 4.7.2.stable.official.ed1daf0bf**, sans rendu (`--headless`), 18 novembre 2026.
Journaux : `game-studio/preuves/civilisation-0.16.0/`.

## Exécuté réellement

| Contrôle | Résultat |
|---|---|
| 15 contrôles statiques + manifeste du projet | PASS |
| Import Godot (`--editor --quit`), aucune erreur de script | PASS |
| `tools/verify-refonte.sh` : 50 scénarios hérités + `civ_evolution` + `civ_ui` | **PASS 52/52** (`verify-refonte.log`) |
| `lab/civ_evolution_test.gd` : parties historiques inchangées, voies, monuments (âge, objectif, choix unique, construction réelle, passage d'âge, bonus perdu à la destruction), forge et améliorations (durée, effet +10 %), héros (unicité, aura, rappel), points et six pouvoirs (refus sans effet, recharges, effets), sauvegarde et reprise déterministe, campagne (état partagé par l'empire, sauvegarde V2, relecture 0.15, refus d'une sauvegarde falsifiée), duel IA contre IA sur 256 cases | PASS 62/62 |
| `lab/civ_ui_test.gd` dans la vraie scène : bouton, panneau, choix de voie, monument proposé, déblocage et ciblage d'un pouvoir par toucher, fiche du centre (héros, améliorations, unités d'autres voies masquées) | PASS 14/14 |
| Capture réelle du panneau (OpenGL logiciel sous xvfb, pas le moteur Mobile) | `panneau-civilisation.png` |

Recettes historiques adaptées (comportement voulu, pas un contournement) : `modern_catalog_test` ignore les 12 unités réservées à l'évolution de la civilisation (couvertes par `civ_evolution_test`) ; `interface_interaction_test` compte les bâtiments réellement proposés (seuls les deux monuments de l'âge suivant apparaissent) ; `verify-refonte-static.py` déclare les trois fichiers de simulation modifiés en plus.

## NON exécuté

- Export APK, Android, Galaxy S25 Ultra (tactile réel, images par seconde, mémoire, chauffe) : **NOT_RUN**.
- Rendu avec le moteur Mobile et une carte graphique : NOT_RUN (une seule capture en rendu logiciel).
- Parties humaines, équilibrage des voies, monuments, coûts et pouvoirs : NOT_RUN.
- Usage des pouvoirs par l'IA en vraie bataille : vérifié en laboratoire seulement (dans le duel, les camps ne se rencontrent pas).
