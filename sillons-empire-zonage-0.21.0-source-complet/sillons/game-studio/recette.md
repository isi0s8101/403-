# Recette J1 (rejouée au J2) et recette J2

Statuts : **PASS**, **FAIL**, **NOT_RUN**. Les résultats du jour sont dans `resultats.md`.

## 1. Contrôles automatisés (laboratoire sans rendu)

Commande : `godot --headless --path . -s res://lab/lab_runner.gd -- all` (code de sortie 0 si tout passe).
Chaque scénario fixe une graine, des ressources/âges par camp, des placements d'unités et une suite d'ordres datés
en ticks (10 ticks = 1 s). Journal : `user://lab_logs/<scenario>.log`.

| Scénario | Couvre (recette minimale J1) |
|---|---|
| r01_priorites | 2 — changement de priorité et réaffectation |
| r02_epuisement | 2 — gisement épuisé, pénurie lisible, reprise après exploration |
| r02b_inaccessible | 2 — gisement visible mais inaccessible ignoré |
| r03_passage_age | 3 — ressources seules / objectif seul / les deux |
| r03b_ia_passage | 3 — l'IA passe indépendamment |
| r04_delegation | 4 — délégation, répartition, reprise d'une unité et d'une escouade, rendre la main |
| r05_conquete | 5 — dernier centre détruit avec constructeur capable, puis défaite |
| r05b, r05c, r05d | 5 — cas limites de reconstruction, variante de règle, reconstruction effective |
| r06_ia_reevaluation | IA : cible issue de sa mémoire, échec, cause exposée, réévaluation |
| r06b_ia_passage_bloque | IA : passage bloqué exposé, nouvelle cible |
| r07, r08 | Situations favorables à chaque ouverture |
| r09_determinisme | Même graine et mêmes ordres → même empreinte d'état |
| r10_partie_complete | Partie IA contre IA de l'âge I jusqu'à la conquête |

Recette tactile : `godot --headless --path . -s res://lab/touch_test.gd` (tap escouade, 2e tap unité seule, ordre au sol,
tremblement sous le seuil sans caméra, tap sur l'interface sans ordre, glisser = caméra sans ordre).

Mode visuel : menu > Laboratoire > choisir un scénario. Les assertions s'affichent en direct, l'état de l'IA aussi.

## 2. Export APK

`godot --headless --path . --export-debug "Android" build/sillons-j1-debug.apk`, puis
`apksigner verify --print-certs build/sillons-j1-debug.apk`.

## 3. Recette physique sur Galaxy S25 Ultra (obligatoire, à exécuter par le créateur)

Préparation : activer le débogage USB ou autoriser l'installation d'applications inconnues ; mode avion activé pour
prouver le hors ligne ; luminosité et mode d'économie d'énergie notés.

Installation : `adb install -r sillons-j1-debug-0.1.0.apk` (ou ouvrir l'APK depuis le téléphone).
Retour arrière : `adb uninstall fr.sillons.empire.j1` (aucune version antérieure à restaurer au J1).

| # | Contrôle | Attendu |
|---|---|---|
| A1 | Lancer en mode avion. | Le menu s'affiche en paysage, sans demande de réseau. |
| A2 | Escarmouche. Toucher un soldat d'une escouade (après en avoir produit 1 à la caserne). | L'escouade entière est entourée ; la caméra ne bouge pas. |
| A3 | Retoucher un soldat de cette escouade, puis toucher le sol. | Lui seul part (« contrôle direct ») ; l'escouade reste. « Rendre à l'escouade » le ramène. |
| A4 | Toucher puis glisser légèrement le doigt (< 3 mm) sur une unité. | Sélection sans déplacement de caméra. Noter tout déplacement involontaire. |
| A5 | Toucher les jauges Bois puis Nourriture du bandeau. | Les ouvriers changent de tâche en quelques secondes ; message de réaffectation. |
| A6 | Laisser épuiser les baies près du centre. | Message d'épuisement ; les ouvriers vont ailleurs ou la pénurie est expliquée. |
| A7 | Ouvrir le panneau d'âge sans comptoir, puis après l'avoir trouvé avec l'éclaireur. | Manques explicites ; passage possible quand coût et objectif sont réunis. |
| A8 | Avec 3 escouades : « Armée : défendre… » puis toucher un secteur. | Cercle bleu, rôles Réserve / Poste 1 / Poste 2 ; interception à l'arrivée d'ennemis. |
| A9 | Pendant la délégation, donner un ordre à une escouade, puis « Rendre à l'armée ». | Rôle « Ordre direct » puis retour à un poste. |
| A10 | Jouer une partie complète contre l'IA jusqu'à victoire ou défaite (viser 20-30 min). | Écran de fin avec la cause. Noter durée, chauffe ressentie, batterie début/fin. |
| A11 | Zone témoin : « Mesurer 10 s » au zoom par défaut, ombres oui puis non, échelle 3D 1,0 puis 0,75. | Résultats affichés et enregistrés (`temoin_*.json`). |
| A12 | En partie : menu II > Mesures, relever FPS et ms/tick en début, au milieu (≈ 10 min) et en fin. | Valeurs à reporter dans `resultats-android.md`. |
| A13 | Première partie guidée uniquement par le jeu : noter chaque hésitation de sélection, chaque ordre refusé dont la cause reste incomprise, chaque blocage de passage d'âge. | Liste de notes (avec captures). |

Récupérer les mesures : `adb pull /sdcard/Android/data/fr.sillons.empire.j1/files/mesures/` si l'accès existe, sinon
capture d'écran du résultat affiché (le chemin exact est affiché sous le résultat).


---

# Recette J2 — forteresses, siège, deux fronts

## 4. Contrôles automatisés J2 (laboratoire sans rendu)

| Scénario | Couvre (recette minimale J2) |
|---|---|
| r05e_minuteur | D-07 approuvé : délai annoncé, camp toujours en jeu avant le délai (moyens présents), éliminé après |
| r11_fort_passage | 1 — tenir un passage : deux gués fermés et couverts par des forts ; l'IA sans artillerie est repoussée et réévalue |
| r12_siege | 1 — ouvrir le passage par un siège ; navigation recalculée et franchissement après destruction |
| r13_route_alternative | 1 — l'IA choisit l'autre gué (détour chiffré), sans siège inutile, et détruit sa cible |
| r14_passage_age3 | Âge III : coût et objectif configurables, refus motivés, adversaire indépendant |
| r15_delegation_acces | Armée déléguée : postes atteints par un autre accès |
| r16_artillerie | Contraintes de l'artillerie : mise en batterie, dégâts de siège, portée minimale |
| r01 à r10 | 2 — contrôles J1 rejoués : passage I→II (r03, r03b), collecte (r01, r02, r02b), conquête (r05 à r05d, r10) ; R07/R08 bornés à l'âge II (`max_age: 2`) pour conserver la situation d'ouverture du J1 |

Commandes :

```bash
godot --headless --path . -s res://lab/lab_runner.gd -- all                # 23 scénarios, code 0 = PASS
godot --headless --path . -s res://lab/fronts_test.gd                       # invariance deux fronts (code 0 = PASS)
godot --headless --path . -s res://lab/fronts_test.gd -- 200 900            # variante : niveau 200, 900 ticks
godot --headless --path . -s res://lab/compare_settings.gd                  # comparaison du budget de chemins
godot --headless --path . -s res://lab/touch_test.gd                        # recette tactile J1
godot --headless --path . -- --fronts-auto --fronts-sec=40 --fronts-quit    # protocole deux fronts automatique
```

## 5. Invariance du test deux fronts (bloquant)

`lab/fronts_test.gd` exécute les deux fronts (`lab/fronts/front_a_gue.json` graine 3101, `front_b_plaine.json`
graine 3202) dans trois conditions : **A** sans vue ; **B** deux vues 3D créées, une seule attachée, bascule tous
les 100 ticks ; **C** bascule tous les 37 ticks et synchronisation des deux vues. Il compare à **chaque tick**
l'empreinte d'état de chaque front, puis les journaux d'événements, les **suites d'ordres** et l'état individuel
de chaque unité (position, PV, état, cible, escouade, recharge, mise en batterie). Plans : niveau 100 sur 1 500 ticks,
niveau 400 sur 300 ticks. Un **contrôle négatif** (décalage de 0,001 case d'une unité) doit être détecté.
Preuves : `preuves/deux_fronts/invariance.txt`, `invariance.json`, `ordres_front_*_niveau100_1500ticks.json`.

## 6. Recette physique J2 sur Galaxy S25 Ultra (obligatoire, à exécuter par le créateur)

Installation par-dessus J1 (même clé) : `adb install -r sillons-j2-debug-0.2.0.apk`.
**Restauration** de J1 : `adb install -r -d sillons-j1-debug-0.1.0.apk` (APK de debug, rétrogradation autorisée),
ou `adb uninstall fr.sillons.empire.j1` puis `adb install sillons-j1-debug-0.1.0.apk`.

Conditions à noter : mode avion, luminosité, mode économie d'énergie désactivé, température ambiante, batterie de
départ, téléphone posé sans coque si possible, 10 minutes de repos écran éteint avant la série de mesures.

| # | Contrôle | Attendu |
|---|---|---|
| B1 | Rejouer A1-A9 de la recette J1 (lancement hors ligne, escouades, unité seule, priorités, épuisement, passage I→II, délégation). | Comme au J1. |
| B2 | Laboratoire > « R14 — Passage II → III » : lire le panneau d'âge pendant le déroulé. | Refus avec cause, puis passage ; bouton « Âge II → III », puis « Âge III — Forteresses ». |
| B3 | Laboratoire > R11 : observer l'IA devant les palissades et le fort. | Message « passage bloqué par Palissade — siège », pertes sous le feu, puis repli et objectif « Préparer l'artillerie ». |
| B4 | Laboratoire > R12 : suivre le siège au gué sud-est. | Palissade détruite, « passage ouvert », les unités franchissent. |
| B5 | Laboratoire > R16 : regarder les canons. | Fût qui se relève (≈ 3 s) avant le premier tir, boulet en cloche, impact ; canon qui recule quand le lancier arrive. Noter si c'est lisible au zoom de jeu. |
| B6 | Escarmouche jusqu'à l'âge III : construire palissades et fort sur un gué, un atelier et 2 canons, assiéger un bâtiment ennemi. | Menu Construire : palissade, fort, atelier (verrous d'âge affichés) ; états du canon dans le panneau de sélection. |
| B7 | Menu > « Test technique : deux fronts » > « Protocole complet » (≈ 3 min, ne pas toucher l'écran). | Message « Mesures écrites : …/deux_fronts_<date>.json ». |
| B8 | Pendant B7, relever à la main toutes les 30 s : chaleur au toucher (1-5) en haut du dos, saccades visibles, et la température si l'écran l'affiche. Après B7, refaire B7 une seconde fois d'affilée (chauffe cumulée). | Notes reportées dans `resultats-android.md`. |
| B9 | Mode manuel : niveau 400, basculer 5 fois de front, et observer l'unité de référence (même escouade) avant et après la bascule. | La carte non affichée a progressé (positions, pertes), sans saut ni gel perceptible au retour. Noter toute saccade. |
| B10 | Récupérer les fichiers : `adb pull /sdcard/Android/data/fr.sillons.empire.j1/files/mesures/` (sinon capture d'écran du résumé). | JSON joints au retour. |

Critères bloquants : B7-B9 donnent les métriques par niveau (simulation par front, rendu CPU/GPU, images/s, mémoire,
chauffe observée), y compris les pics pendant le siège (`front0_sim_ms_pic_siege`) et lors des bascules
(`image_ms_pic_bascule`, `bascules[].cpu_ms`). Sans ces mesures physiques la recette J2 reste **NOT_RUN**.
