# Sillons d’Empire 0.8.2 — correctifs issus de l’audit 0.8.1

Statut : **candidate**. Source 0.8.1 conservée. Aucun APK généré ni tests Godot exécutés dans l'environnement de création.

## Corrigé dans le code source

- P1-01 : validation stricte des vols/cargaisons (ratios finis, champ supply, types et identifiants), compatible avec les vols 0.8.1 dont `duration` était absent.
- P1-02 : identifiant de recette unique, réinitialisation des contrôles matériels sur chaque nouvelle exécution, association du rapport à un modèle de terminal et un horodatage UTC.
- P1-03 : repli vérifié vers `.bak` (SHA-256), sans réutiliser un backup corrompu ; indication de la provenance dans la partie.
- P1-04 : journal horodaté d'alertes critiques issues des secteurs non affichés ; accès au secteur via le panneau stratégique.
- P1-05 : expansion orbitale activée pour les DEUX camps réellement pilotés par IA.
- P1-06 : choix du vaisseau et de 1 à 6 unités par cases à cocher et confirmation explicite avant retrait/débit. Les appels de recette et IA sans sélection restent compatibles.
- P1-07 : interceptions uniquement lors du croisement géométrique des progressions sur un trajet opposé, non sur la seule proximité d'ETA.
- P2-08 : débarquements en attente quand la population dépasse la capacité ; ni disparition ni duplication des troupes.
- P2-09 : une seule fondation payée/en transit par camp et destination ; nouvelles expéditions refusées jusqu'à livraison.
- P2-10 : bouton COPIER LE RAPPORT (presse-papiers Android) en complément du JSON `user://`.
- P2-11 : mesures embarquées par vitesse après 15 s de simulation réelle (FPS moyen, p95/p99, ticks/s demandés/réels, mémoire statique Godot). Refaire chaque mesure sous charge constante ; surveiller température par outil externe / manuel.
- P2-12 : procédures d'exécution consolidées, mais **le critère n'est pas validé** tant que le moteur Godot 4.7.x et le Galaxy S25 Ultra n'ont pas été testés.

## Vérifier

Exécuter **depuis le dossier `sillons/`** :

```bash
python3 tools/verify-fix082-static.py
./tools/verify-fix082.sh
./tools/export-android-fix082.sh
```

`verify-fix082.sh` exécute d'abord les vérifications structurelles puis les tests Godot si Godot est installé ; absent : code retour **127**, donc aucun PASS artificiel. L'export exige Godot 4.7.x, ses modèles d'export Android, Java et un SDK Android configuré.

## Recette physique S25 Ultra

1. Installer et démarrer le nouvel APK (paysage).
2. Menu → Recette intégrale → **Démarrer** ; contrôler les PASS/FAIL et noter l'identifiant d'exécution.
3. Atelier spatial → sélectionner un port → SECTEURS → Envoyer → cocher uniquement les unités désirées. Vérifier coût/débit et arrivée.
4. Vérifier alertes des secteurs inactifs, déplacement à l'alerte, sauvegarde principale et restauration depuis `.bak` (avec données de test uniquement).
5. Régler la vitesse à 0,5×, 1×, 2×, 4× et 8×, jouer **15 s ou plus à chaque vitesse**, dans les mêmes conditions de charge. Observer la surcharge et revenir à 1× si nécessaire.
6. Revenir à la recette et contrôler les cinq vitesses mesurées. Saisir manuellement les résultats graphismes, tactile, FPS et stabilité. Copier le JSON pour audit externe.

**Critères de promotion** : Godot import PASS, tests de régression PASS, APK signé/debug généré et installé, recette manuelle S25 Ultra signée PASS et absence de crash.
