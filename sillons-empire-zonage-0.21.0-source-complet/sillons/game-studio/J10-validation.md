# J10 — Critères de validation

- **Génération** : même graine = mêmes systèmes, orbites, noms, IDs ; graine distincte = autre catalogue ; lune rattachée à un parent valide.
- **Rétrocompatibilité** : 3 secteurs historiques et ses sauvegardes 0.9.1 lisibles ; aucun changement de catalogue des âges I–X ni de scripts `sim/rules.gd`.
- **Transition UI** : terrain → globe → orbite → système, puis sens inverse ; aucune sélection tactique / ordre altéré par le changement de caméra.
- **Conquête** : nouvelle planète inhabité, expédition validée depuis port allié avec navire + ouvrier, ressources payées, ETA > 0, arrivée, fondation, unité présente.
- **Simulation** : ticks poursuivis indépendamment de la vue, y compris planète d'arrivée, jeu ×0,5 à ×8 ; corps inhabité sans coût de pathfinding.
- **Sauvegarde** : hash avant/après reprise identique, vol en transit conservé, corruption ou seed d'extra-map refusées, sauvegarde historique acceptée.
- **Android** : interface et gestes sur S25 Ultra, durée au moins 20 min, FPS, mémoire, thermique, stabilité après mise en arrière-plan et restauration.

Règle de recette : tout test runtime absent reste `NOT_RUN`, aucun PASS statique ne permet d'affirmer que l'APK compile ou fonctionne.
