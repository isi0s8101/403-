# Sillons d'Empire 0.20.0 — zonage dynamique, LOT B (candidate)

Base : 0.19.0, qui contenait le LOT A. Ouvrir `sillons/project.godot` avec **Godot 4.7.2**.
Pour essayer : **Nouvelle campagne · deux systèmes**, puis **Bâtir → Zones**.

Le LOT A (0.19.0) reste en place : zonage dès l'âge I, routes, ville qui se construit seule, niveaux, criminalité, incendies, conversion des parties 0.18.

Le LOT B (0.20.0) ajoute :
- **Filtres sur la carte**, un toucher par filtre : zonage, population, densité, criminalité, prospérité, production, pollution, état, incidents, infrastructures.
- **Événements** : séisme, inondation, tempête, crise économique, vague de migration, exode. Ils sont rares, jamais pendant les 15 premières minutes, et frappent l'IA comme le joueur.
- **Villes lointaines** : les villes des autres mondes continuent de vivre avec un calcul allégé (40 % du coût). Le panneau Ville montre toutes vos villes.
- **L'IA construit un petit quartier dès l'âge I**, avec les mêmes commandes que vous.
- **10 âges reconnaissables** : couleurs et toitures propres à chaque âge.
- **Calcul de la ville plus rapide** : 9 à 11 ms au lieu de 15 à 16 pour 136 bâtiments, sur ordinateur. Les camps et les mondes sont calculés à des moments décalés.

Guides : [README-ZONAGE-0.20.0.md](README-ZONAGE-0.20.0.md) (nouveautés) et [README-ZONAGE-0.19.0.md](README-ZONAGE-0.19.0.md) (bases). Rapport de tests : `sillons/game-studio/VALIDATION-ZONAGE-0.20.0.md`. Aperçu : [APERCU-VISUEL.html](APERCU-VISUEL.html).

Sur ordinateur, les **64 scénarios** Godot passent en un seul passage : les 61 anciens et les 3 du zonage.

**Aucun APK n'est fourni. Android et Galaxy S25 Ultra : NOT_RUN.**

Aucun contenu d'un jeu existant n'a été repris.
