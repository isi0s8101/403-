# Validation J9 0.9.1 — candidats et critères

**Statut : candidat technique**. Baseline : 0.9.0. Le socle J1–J8 n'a pas été reconstruit. Les modules J9 interrégionaux ajoutent un état multi-région, une interface de franchissement et une sauvegarde compatible avec le schéma de campagne version 1 (extension optionnelle).

## Tests automatisables

- `tools/verify-j9-complete.sh` : structure + import Godot + laboratoire J9 + régressions J1–J8.
- `lab/j9_regions_test.gd` : continuité géométrique N/S/E/O et longitude, accès aux frontières, transit PV/ravitaillement/population, tick hors écran, reprise de transit, intégrité et migration schéma.
- `tools/export-android-j9-complete.sh` : export Android arm64 après succès du test suite.

**Sur le système de préparation : audits statiques réussis ; Godot absent ; recette Android non effectuée.** Un échec de compilation ou de script bloque toute promotion.

## Critères pour déclarer J9 validé

1. Toutes les commandes Godot terminent avec un code 0, sans erreur de parse/ressource.
2. Aucune perte/duplication d'unité ou de bâtiments au changement de région.
3. Reprise d'une sauvegarde et d'un voyage orbital vers une région mémorisée.
4. Combat et économie hors écran à ticks égaux pour 2, 4 et 8 régions habitées.
5. Niveau de fluidité et mémoire mesurés sur Galaxy S25 Ultra ; corrections effectuées selon les mesures et vidéos de recette.
