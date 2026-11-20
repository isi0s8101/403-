# Sillons d'Empire 0.19.0 — la ville se construit seule sur les zones peintes (candidate, LOT A)

Base : 0.18.1, auditée avant modification : [AUDIT-ZONAGE-0.18.1.md](AUDIT-ZONAGE-0.18.1.md). Le projet s'ouvre avec `sillons/project.godot` dans **Godot 4.7.2**.
Lancer **Nouvelle campagne · deux systèmes**, puis **Bâtir → Zones**.

- **Zonage dès l'âge I** : habitat (bas, moyen, dense), commerce, industrie, agricole, routes, gomme. Outils : pinceau au doigt (1 à 3 cases), rectangle, parcelle, inspecter, annuler. Le calque coloré ne s'affiche que dans ce mode.
- **La ville bâtit seule**, seulement près d'une route reliée au centre, s'il y a de la demande, des ressources et pas de danger. Certaines parcelles restent vides.
- **Demande** par catégorie, tirée de la vraie économie ; les habitants mangent.
- **Niveaux et densité** qui montent seuls, avec un plafond selon l'âge ; **architecture de l'âge** de construction, qui change peu à peu ; quartiers historiques.
- **Criminalité** (vols, pillages, émeutes) et **incendies** (matériaux, saison sèche, propagation, ruines, reconstruction), avec des remèdes à chaque âge.
- **L'IA** trace ses routes et peint ses zones avec les mêmes règles.
- Les parties 0.18 sont converties (les zones posées deviennent des parcelles zonées).

Guide : [README-ZONAGE-0.19.0.md](README-ZONAGE-0.19.0.md). Rapport de tests : `sillons/game-studio/VALIDATION-ZONAGE-0.19.0.md`. Aperçu : [APERCU-VISUEL.html](APERCU-VISUEL.html).
Les **63 scénarios** Godot passent sous Linux (61 anciens + 2 nouveaux). **Aucun APK n'est fourni ; Android et Galaxy S25 Ultra : NOT_RUN.**
Le LOT B (0.20.0) reste à faire :
- villes lointaines et changement d'échelle ;
- filtres visuels ;
- événements ;
- seuils de performance Android.

Aucun contenu d'un jeu existant n'a été repris.
