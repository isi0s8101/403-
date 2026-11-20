# Sillons d'Empire 0.17.0 — Interface et commandes « grand RTS », thème qui suit l'âge (candidate)

Base : 0.16.0 (auditée : voir [AUDIT-UI-0.16.0.md](AUDIT-UI-0.16.0.md)). Le projet s'ouvre avec `sillons/project.godot` dans **Godot 4.7.2**.
Lancer **Nouvelle campagne · deux systèmes**.

- **Sélection rapide** : double appui (tous les mêmes à l'écran), glisser depuis une unité (rectangle), bouton ＋ (ajouter / retirer), boutons Inactifs, Armée, Héros, 6 groupes de contrôle (appui long pour enregistrer, toucher pour rappeler, double toucher pour centrer).
- **Carte de commandes** en bas à droite, toujours au même endroit : Marcher, Assaut, Arrêt, Tenir, Patrouille, Repli, Garnison, postures, formations, cible prioritaire, suivre, explorer ; pour les ouvriers : récolter, réparer, rapporter, Auto.
- **Ordres enchaînés** : bouton **Enchaîner**, puis un toucher par étape (A → B → C) ; numéros au sol, déplacer / supprimer / insérer une étape, boucle, annuler, vider ; **pause active** pour donner des ordres jeu arrêté.
- **Production** : ×1 / ×5, appui maintenu, production répétée, annuler un élément de la file, drapeau de ralliement sur une ressource, bouton **Former** utilisable de partout.
- **Construction** : pose en ligne (murs, palissades) d'un seul glissé, pose multiple, raison du refus affichée sur le fantôme, ouvriers qui enchaînent plusieurs chantiers.
- **Héros, pouvoirs, alertes** : barre des héros et des pouvoirs (visée en 2 touchers, cercle au sol), alertes regroupées avec « Voir », points sur la mini-carte.
- **Thème qui suit l'âge** : 10 habillages (de l'antique à « l'appli de nouvelle génération » à l'âge X) qui changent la matière, les polices, les couleurs, les sons et les petites animations — **jamais la place des boutons ni les gestes**. Contraste texte ≥ 4,5:1 mesuré dans les 10 âges. Courte cérémonie au passage d'âge (toucher pour passer).
- **Réglages** : thème fixe ou suivant l'âge, sons, vibrations, **main gauche** (miroir), échelle 85 à 130 %, réduire les animations, afficher les portées.

Les règles du jeu ne changent pas : les nouvelles commandes passent par la simulation, au même titre que les anciennes, et l'IA a droit aux mêmes, aux mêmes conditions.

Guide : [README-INTERFACE-0.17.0.md](README-INTERFACE-0.17.0.md). Validation : `sillons/game-studio/VALIDATION-INTERFACE-0.17.0.md`. Aperçu : [APERCU-VISUEL.html](APERCU-VISUEL.html).
Les **58 scénarios** Godot passent sous Linux (52 anciens + 6 nouveaux). **Aucun APK n'est fourni avec cette version ; Android et Galaxy S25 Ultra : NOT_RUN.**
Les sauvegardes 0.16 se relisent ; les escarmouches historiques et les scénarios de laboratoire conservent leurs règles.
