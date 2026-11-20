# Sillons d’Empire 0.8.1 — Recette J1–J8 + accélération

Base : Sillons d’Empire `0.8.0-j678-candidate`. Tous les systèmes existants sont conservés.

## Depuis Android

1. Ouvrir le menu principal et choisir **RECETTE INTÉGRALE J1–J8**.
2. Appuyer sur **Démarrer**. Les scénarios de laboratoire hérités sont rejoués avec graine fixe, puis l’industrie, les armes, la guerre électronique, le transport orbital, l’expansion interstellaire, les interceptions et les sauvegardes sont contrôlés. Les travaux sont répartis par frame, sans modifier la sauvegarde normale.
3. Lire les résultats PASS/FAIL. Tant que le scénario n’est pas terminé, son statut est **NON EXÉCUTÉ / EN COURS** et non PASS.
4. Dans la colonne **RECETTE MATÉRIELLE ANDROID**, exécuter les huit vérifications sur le téléphone, éventuellement en passant par **Ouvrir l’atelier spatial** et **Partie normale**. Toucher chaque statut : **À contrôler → PASS → ÉCHEC → À contrôler**. Ces contrôles ne sont pas automatisables par une simple simulation sans matériel.
5. Utiliser **ENREGISTRER LE RAPPORT JSON**. Le rapport est enregistré dans `user://recette-j1-j8-<date>.json` (répertoire privé de l’application). Il conserve les résultats et les statuts manuels. Une recette globale n’est **PASS** que si l’automatique est PASS ET les huit contrôles manuels sont PASS. Sans cela, le résultat reste **INCOMPLETE** ou **FAIL**.

Dans l’écran de recette, ce réglage augmente également le nombre de ticks de test demandé par frame, sous une limite stricte de 8 ms de calcul pour préserver la réactivité tactile. L’accélération effectivement obtenue dépend du matériel.

La recette est **suspendue** lors du passage dans une partie ou un atelier. Les résultats et cases manuelles sont conservés en mémoire de session et retrouvés en revenant à la recette via le menu ; ils ne s’exécutent pas en arrière-plan. Enregistrer le JSON pour conserver une preuve entre deux redémarrages de l’application.

Les tests automatisés peuvent durer sur Android, particulièrement les 23 scénarios historiques dont certains dépassent 8 000 ticks. Le bouton **Arrêter** évite un gel de l’interface. Le rapport est un rapport de test, pas une attestation de certification matérielle.

## Accélérer la simulation

Dans le **menu principal** ou en **partie**, appuyer sur le bouton de vitesse. Les valeurs sont **×0,5 → ×1 → ×2 → ×4 → ×8 → ×0,5**. Le bouton de partie reflète la vitesse courante ; le réglage est conservé entre les scènes de la même session. La vitesse agit uniquement sur les ticks de simulation, pas sur les gestes tactiles, animations de caméra ou la vitesse d’affichage. Une limite de 12 ticks par frame évite les spirales de rattrapage si le CPU est saturé. **×8 est une vitesse demandée, pas une garantie sous charge**.

## Recette automatisée Godot et export Android (poste équipé)

```bash
cd sillons
./tools/verify-recette.sh
./tools/export-android-recette.sh
```

`verify-recette.sh` lance le banc de non-régression antérieur, la nouvelle suite complète et un test de l’interface des vitesses. La commande renvoie un statut d’échec sur erreur et `127` si Godot n’est pas installé. Le script d’export existant reste conservé et produit un APK uniquement si les prérequis Godot/Android sont présents. **La compilation et les tests Android réels sont encore à effectuer**.

## Limites et retour arrière

- Les tests historiques `strategic_test.gd`, `modern_test.gd`, `strategic_ui_test.gd`, les contrôles visuels sans GPU et les scénarios existants restent intacts.
- La recette en jeu ne peut pas mesurer elle-même la fidélité graphique, les appuis réels du téléphone ou la température ; ces contrôles sont explicitement manuels.
- Aucune migration forcée de sauvegarde, aucun accès réseau, aucun changement de vitesse du moteur de rendu.
- Pour revenir en arrière, repartir du ZIP source `sillons-empire-j678-0.8.0-source-complet.zip` original, conservé séparément.
