# Sillons d'Empire 0.20.0 — zonage dynamique, LOT B

Suite de la 0.19.0 (LOT A, guide : [README-ZONAGE-0.19.0.md](README-ZONAGE-0.19.0.md), toujours valable).
Rapport de tests : `sillons/game-studio/VALIDATION-ZONAGE-0.20.0.md`.

## Ce que la 0.20.0 ajoute

### Filtres sur la carte

Dans le mode **Zones**, le bouton **Filtre** passe au filtre suivant à chaque toucher :

> aucun → zonage → population → densité → criminalité → prospérité → production → pollution → état → incidents → infrastructures → aucun

- Les quartiers sont teintés par-dessus les bâtiments. Une ligne explique les couleurs.
- Les mêmes filtres sont dans le panneau **Ville**, avec les vues de 0.18 : électricité, eau, pompiers, santé, bien-être.
- Le filtre **Zonage** garde le calque coloré du terrain même hors du mode Zones.

### Événements

Les événements arrivent seuls, rarement, et jamais pendant les 15 premières minutes de la partie. Le joueur et l'IA y sont soumis de la même façon.

| Événement | Effet |
|---|---|
| **Séisme** | Abîme les bâtiments autour d'un point ; peut allumer des incendies. |
| **Inondation** | Seulement au bord de l'eau : production arrêtée 40 s, petits dégâts. |
| **Tempête** | Abîme surtout les maisons de bois ; éteint les incendies. |
| **Crise économique** | Commerce et industrie ralentissent pendant 2 minutes. |
| **Vague de migration** | Des habitants arrivent ; la demande d'habitat monte. |
| **Exode** | Quand la criminalité est forte, des habitants partent. |

Ce qui se passe s'affiche à trois endroits : les alertes, la barre du mode Zones (« En cours : … ») et le panneau Ville.

Pour les développeurs : chaque événement est une ligne de données dans `sim/urban_events.gd` (zone touchée, dégâts, feu, inondation, production, demande, densité, durée). Ajouter un événement ne demande pas de nouveau code.

### Villes à plusieurs échelles

- La ville du monde affiché est calculée en détail, toutes les 2 secondes.
- Les villes des autres mondes (autres régions, planètes, systèmes) continuent de vivre avec les mêmes règles. Elles sont calculées 3 fois moins souvent, avec les durées et les chances ajustées.
- Mesure : cela coûte 40 % du calcul détaillé, pour la même production et la même croissance.
- Passer d'une vue à l'autre ne fait rien perdre.
- Le panneau Ville montre **toutes vos villes**, monde par monde, avec les totaux.

### L'IA construit sa ville dès l'âge I

Avant l'électricité, l'IA trace des routes et peint un petit quartier. Elle utilise pour cela les mêmes commandes que vous, et seulement si elle a des ressources en trop : l'armée et le passage des âges restent prioritaires. Elle ajoute un puits quand le quartier grandit.

### Architecture des 10 âges

Chaque âge a ses propres couleurs et sa propre toiture :

| Âge | Matériaux et toiture |
|---|---|
| I | chaume |
| II | bois |
| III | pierre et tuiles |
| IV | colombages et cheminées |
| V | brique et réservoir d'eau |
| VI | brique industrielle et hautes cheminées |
| VII | béton et antennes |
| VIII | béton blanc et panneaux solaires |
| IX | verre, acier et toits jardins |
| X | blanc futuriste et anneau lumineux |

Image : `sillons/game-studio/preuves/zonage-0.20.0/ages-1600.png`.

### Fluidité

- **Accès à la route** : un bâtiment qui vérifiait son accès relisait tous les bâtiments de la carte. Ce coût, qui grandissait au carré, est supprimé. Une ville de 136 bâtiments se calcule maintenant en 9 à 11 ms au lieu de 15 à 16 (ordinateur Linux).
- **Calculs décalés** : les camps et les mondes ne sont plus calculés au même moment, ce qui évite d'additionner les saccades.
- **Seuils mesurés** sous Linux :
  - calcul complet d'une ville de 136 bâtiments : moins de 20 ms ;
  - accès à la route de tous les bâtiments en un tick : moins de 6 ms ;
  - ville lointaine : moins de la moitié du calcul détaillé.

  Sur téléphone, ces mesures n'ont pas été faites (NOT_RUN).
- Outil de mesure, partie par partie : `godot --headless --path sillons --script res://tools/profile-urban.gd`.

## Limites connues

- **Android** : rien n'a été lancé sur téléphone, et il n'y a pas d'APK. Ni les seuils ni la fluidité n'y ont été vérifiés.
- **Bois de l'IA** : après l'électricité, l'IA dépense beaucoup de bois pour son armée. Sans bois, elle ne peut plus réparer, et un incendie peut laisser des ruines dans sa ville. Ce comportement existait déjà avant ; il est maintenant plus visible.
- **Valeurs provisoires** : les fréquences et la force des événements, et le rythme des villes lointaines, restent à équilibrer en partie réelle.
- **Niveaux I à III** : l'habitat de ces niveaux utilise les modèles de la bibliothèque, qui changent tous les deux âges. La couleur de l'âge et la toiture d'époque n'apparaissent qu'à partir du niveau IV.
