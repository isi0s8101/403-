# Sillons d’Empire — 0.15.1 R2 candidate

Réédition reconstruite depuis le ZIP 0.15.0 fourni. Les 32 fichiers `sillons/sim/` restent identiques à la base. Godot 4.7.2.

## Installer l’APK

1. Télécharger `sillons-empire-test-0.15.1-r2-arm64.apk` sur le Galaxy S25 Ultra.
2. Ouvrir le fichier, autoriser cette installation si Android le demande, puis installer.
3. Lancer **Sillons d’Empire Test R2**.

Paquet : `fr.sillons.empire.recette.r2`, versionCode 151. La R2 utilise une nouvelle signature de debug et un identifiant distinct. Elle s’installe à côté du jeu historique `fr.sillons.empire.j1` et de la première recette `fr.sillons.empire.recette`. Les sauvegardes sont privées à chaque application ; elles ne sont pas copiées automatiquement.

Le ZIP source est livré séparément de l’APK. Après extraction complète, ouvrir `sillons/project.godot` dans Godot 4.7.2.

## Vérifier démarrage et commandes sur le téléphone

| Contrôle | Résultat attendu |
|---|---|
| Trois démarrages | Menu affiché sans fermeture de l’application |
| Nouvelle campagne | Carte, simulation et menus utilisables |
| Toucher un bâtiment | Fiche avec onglets, noms, vignettes et production |
| Produire et définir le ralliement | Unité créée puis envoyée au point choisi |
| Glisser, pincer, sélectionner | Caméra réactive, aucun ordre parasite |
| Replier puis utiliser Retour Android | Panneau prioritaire fermé, navigation conservée |
| Trois passages en arrière-plan | Retour utilisable et aucun geste bloqué |
| Sauvegarder puis reprendre | État restauré sans perte ni duplication visible |
| Atelier empire et orbite | Sélection, production, déplacements et combat orbitaux |
| Système et galaxie | Suivi du trafic et navigation |

Ces contrôles Android restent à effectuer sur l’appareil réel. Les scénarios automatisés fournis ont été exécutés sous Linux.

## Mesurer dans l’application

Ouvrir **Laboratoire et scénarios → Performances Android · grande carte / fronts / orbite**.

| Recette | Charge initiale |
|---|---|
| Grande carte | Trois mondes 256 × 256, développement de l’IA distante |
| Trois fronts | 360 soldats ajoutés aux 12 unités initiales, sur trois mondes |
| Batailles orbitales | 120 vaisseaux au total, 40 sur chacune des trois orbites |

Graine fixe : 15101. Les combats sont simulés : les unités détruites disparaissent ; le rapport conserve les effectifs initiaux, ceux de chaque seconde et les effectifs finaux. Ce n’est pas une charge à effectif constant. Les mondes hors écran continuent de progresser. La caméra change de monde toutes les 20 secondes.

1. Choisir d’abord le profil **Équilibrés** dans les paramètres du menu.
2. Faire une première série de **60 secondes** sur chaque recette.
3. Toucher le bouton de durée pour passer à **600 secondes**, puis refaire les trois recettes séparément.
4. À la fin, utiliser **Copier le rapport JSON**. Il reste également visible et s’enregistre dans `user://mesures/`.

Le rapport indique intervalles d’images p50/p95/p99, temps bruts des ticks, FPS moyens, effectifs, RSS si lisible, appels de dessin et qualité adaptative. Les cinq premières secondes préparent le rendu et sont exclues des statistiques d’images. Le temps CPU de construction initial est séparé. Les interruptions en arrière-plan sont comptées et suspendent la recette ; les préférences de vitesse sont rétablies au retour au menu.

Les panneaux de gameplay sont masqués pendant la recette, au profit du diagnostic. Le build est signé en debug. Ces mesures ne remplacent pas les essais de l’interface complète ni ceux d’un futur build de production.

La température n’est pas supposée : elle reste indisponible dans le rapport interne. Le relevé ADB ci-dessous ajoute les métriques réellement exposées par Android.

## Mémoire Android et chauffe avec ADB

Contexte : utilisateur standard sur PC Linux/macOS/Windows, Python 3.10+, Android Platform-Tools dans le PATH. Téléphone connecté par USB, débogage USB autorisé. Aucun root nécessaire.

```bash
adb devices -l
```

Lancer une recette de 600 secondes, puis aussitôt, depuis le dossier `sillons/` :

```bash
python3 tools/collect-android-performance.py --seconds 660 --interval 10 --output mesures-s25
```

Sous Windows, `python` peut remplacer `python3`. S’il y a plusieurs appareils, ajouter `--serial IDENTIFIANT_EXACT` issu d’ADB.

Le script ne modifie aucune application. Il crée un nouveau dossier horodaté contenant `samples.csv`, `samples.json`, les relevés mémoire/batterie/thermique bruts, un journal ciblé de l’application et `summary.json`. Il récupère aussi `godot-last-report.json` via `run-as` si le rapport privé est disponible. Vérifier la date et le scénario : le dernier rapport peut précéder la mesure courante. Les données absentes restent `null`.

La température batterie n’est pas la température CPU, GPU ou de surface. Les capteurs non exposés ne sont pas devinés. Les FPS viennent de Godot ; le script ne transforme pas `gfxinfo` en FPS du rendu 3D.

Pour comparer les séries, garder luminosité, résolution, profil graphique et alimentation identiques ; noter le branchement du chargeur et laisser refroidir entre deux séries. Mesurer sans capture vidéo, puis enregistrer une vidéo distincte pour les problèmes visuels.

## Reproduire l’export et les tests

Contexte testé : utilisateur standard, Linux x86_64, Godot 4.7.2 et templates officiels, OpenJDK 21, Build-Tools 36.0.0. Aucun téléchargement automatique par le script.

```bash
python3 tools/export-android-0151.py \
  --godot /chemin/vers/Godot_v4.7.2-stable_linux.x86_64 \
  --sdk /chemin/vers/android-sdk \
  --java /chemin/vers/java \
  --output /chemin/vers/sillons-empire-test-0.15.1-r2-arm64.apk
```

Le script refuse d’écraser un APK existant. Sa clé de debug et les intermédiaires restent dans `build/android-private/`, exclu de l’archive. Une autre clé ne permet pas de mettre à jour directement une application signée avec la clé livrée ; récupérer les données de recette avant d’envisager une réinstallation.

Le conditionnement corrige les booléens/entiers des déclarations Vulkan et l’autorité distincte d’AndroidX Startup du manifeste exporté par Godot 4.7.2. La correction est idempotente, puis le paquet est aligné, signé à nouveau et vérifié par `apksigner`, `zipalign` et `aapt`. Les bibliothèques et ressources du jeu restent identiques avant/après cette correction. Le lanceur utilise un `activity-alias` Android.

```bash
GODOT_BIN=/chemin/vers/Godot_v4.7.2-stable_linux.x86_64 bash tools/verify-refonte.sh
```

Mesure CPU complémentaire sans rendu :

```bash
/chemin/vers/Godot_v4.7.2-stable_linux.x86_64 --headless --path . --script res://tools/benchmark-performance-0151.gd
```

## Statut et retour à la base

La candidate passe 50 scénarios Godot sous Linux. APK ARM64, signature, manifeste et alignement 16 Ko sont vérifiés. Les ressources compilées extraites de l’APK passent aussi trois parcours sous Linux, sans source : cela n’exécute pas le code natif Android. Aucun téléphone n’est connecté ici ; installation, FPS, mémoire et chauffe du S25 Ultra restent à mesurer.

Les résultats et preuves sont dans `sillons/game-studio/resultats-android.md` et `sillons/game-studio/preuves/android-performances-0.15.1-r2/`. Les pointes de calcul sur trois fronts restent à surveiller ; aucune fluidité Android n’est certifiée.

Pour revenir au jeu précédent, fermer Test R2 et relancer l’application historique. Le ZIP original 0.15.0 est préservé comme référence.

Documentation : [export Android Godot 4.7](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_android.html), [dumpsys Android](https://developer.android.com/tools/dumpsys), [activity-alias](https://developer.android.com/guide/topics/manifest/activity-alias-element), [exporteur Godot 4.7.2](https://github.com/godotengine/godot/blob/4.7.2-stable/platform/android/export/export_plugin.cpp).
