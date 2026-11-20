# Validation — Sillons d'Empire 0.17.0 (interface et commandes « grand RTS », thème qui suit l'âge)

Environnement : Godot **4.7.2.stable.official** (Linux x86_64), sans téléphone. Rendu des captures : xvfb + `--rendering-driver opengl3`.
Règle : ce qui n'a pas tourné est **NOT_RUN**.

## 1. Exécuté

| Contrôle | Résultat |
|---|---|
| Référence 0.16.0 intacte (`verify-refonte.sh`) | PASS — 52/52 |
| Contrôles statiques (`verify-refonte-static.py`, 16 suites dont `verify-interface-static.py`) | PASS |
| Compilation de chaque script (`tools/check-scripts.gd`, 94 scripts) | PASS |
| `verify-refonte.sh` 0.17.0 (import, compilation, **58 scénarios**) | PASS — **58/58**, en trois passages : contrôles statiques, import, compilation et 26 scénarios ; puis 5 ; puis les 27 derniers et le paquet natif (`NATIVE_PACKAGED_RUNTIME=PASS`). Entre deux passages, une seule correction : `modal_touch` échouait parce qu'un son d'interface lancé juste avant la fermeture retenait `tap.wav` ; sans sortie audio (pilote factice), le son n'est plus joué. |
| `unit_commands` (simulation : files, commandes § 5.12, sauvegarde, IA) | PASS — 96 vérifications |
| `ui_selection` (lot UI-1, vraie scène, vrais touchers) | PASS — 26 vérifications |
| `ui_orders` (lot UI-2 : carte de commandes, Enchaîner, édition au sol, pause active, ouvriers, pose en ligne) | PASS — 30 vérifications |
| `ui_production` (lot UI-3) | PASS — 16 vérifications |
| `ui_alerts` (lot UI-4 : alertes, mini-carte, héros, pouvoirs) | PASS — 17 vérifications |
| `ui_theme` (lot UI-6 : 10 thèmes, contrastes, couleurs codées en dur, cache, cérémonie, réglages, gaucher) | PASS — 45 vérifications |
| Captures réelles avant / après (1600×740 et 2400×1110) | 14 avant, 15 après — `preuves/interface-0.17.0/avant`, `apres` |
| Planche des 10 âges (`preuves/interface-0.17.0/planche-10-ages.png`) | contrastes mesurés pour les **10 âges** ; captures faites pour les âges I à V (scène) et I à IV (panneau Civilisation) ; captures des âges suivants **NOT_RUN** (arrêtées sur demande, l'outil `capture-ui-017.gd planche <âge>` permet de les faire) |

Recettes adaptées (comportement voulu changé, raison écrite dans le fichier) :
- `lab/touch_test.gd` : deux touchers à moins de 0,32 s forment désormais un **double appui** (« tous les mêmes à l'écran ») ; la recette attend donc 0,45 s avant le second toucher pour vérifier le sens « unité seule » du toucher lent.

## 2. Indicateurs du § 2 (mesurés par les recettes, compteur automatique de touchers)

| Action | 0.16.0 | 0.17.0 mesuré | Cible |
|---|---|---|---|
| Sélectionner tous les ouvriers inactifs | impossible | **1** | 1 |
| Toute l'armée | impossible | **1** | 1 à 2 |
| Toutes les unités d'un type à l'écran | impossible | **2** (double appui) | 1 à 2 |
| Rappeler un groupe de contrôle | impossible | **1** | 1 |
| Ordre « assaut » vers un point | 2 | **2** | 2 maximum |
| Trajet A → B → C | impossible | **1 bascule + 3** | 1 bascule + 1 par point |
| 3 bâtiments à la suite par les mêmes ouvriers | impossible | **1 bascule + 3 poses** | 1 bascule + 3 poses |
| Former 5 unités d'un coup | 5 | **1** (×5 activé) ; **1** appui maintenu | 1 |
| Ligne de murs | 12 | **1 glissé + 1 validation** | 1 glissé + 1 validation |
| Aller à la dernière alerte | impossible | **1** | 1 |
| Lancer un pouvoir de commandement | 3 et plus | **2** | 2 |
| Ordres involontaires (pincement, glissé, panneau ouvert) | 0 | **0** | 0 |
| Thèmes d'interface distincts | 1 | **10** | 10 |
| Contraste texte / fond dans chaque thème | — | **≥ 4,58:1** (minimum sur les 10 âges, fonds des jetons et centre réel des textures) | ≥ 4,5:1 |
| Contraste éléments graphiques (barres, bordures, icônes) | — | **≥ 3,46:1** | ≥ 3:1 |
| Changement de thème au passage d'âge | — | sans relance, sans fermer les panneaux, empreinte de simulation identique | idem |

Contrastes minimaux mesurés par âge (texte / éléments graphiques) : I 4,58 / 3,46 · II 5,34 / 5,19 · III 5,10 / 3,52 · IV 4,77 / 4,77 · V 6,20 / 5,86 · VI 4,60 / 5,18 · VII 6,58 / 5,19 · VIII 6,24 / 5,17 · IX 7,29 / 6,21 · X 7,70 / 5,52.

## 3. Performances (comparaison avec les mesures déjà disponibles)

| Contrôle | 0.16.0 | 0.17.0 |
|---|---|---|
| `j12_perf` (régulateur visuel : baisse du détail en surcharge, retour à la normale, sans effet sur la simulation) | PASS | PASS |
| `android_performance_ui` (recette de mesure tactile : vitesse ×1, mise en arrière-plan, rapport sans écraser la sauvegarde) | PASS | PASS |
| `evolution_performance`, `orbit_performance`, `android_performance` | PASS | PASS |
| Poids des ressources d'interface ajoutées (polices + habillages des 10 âges) | — | **2,64 Mio** (plafond fixé : 4 Mio) |
| Construction du thème au changement d'âge | — | une fois par âge puis mise en cache, thème unique partagé (recette `ui_theme`) |
| Dessin des repères au sol (étapes, cercles, portées) | — | 1 maillage pour les traits + 1 pour les barres de vie ; étiquettes réutilisées ; fantômes de pose en une seule instance multiple |

Ces recettes vérifient des comportements et des plafonds, pas un nombre d'images par seconde.
La mesure chiffrée avant/après (`tools/perf-ui-017.gd` : temps par image, appels de dessin) a été préparée mais **n'a pas été lancée : NOT_RUN**. Le nombre d'images par seconde sur téléphone n'est pas mesuré non plus (**NOT_RUN**, aucun appareil).

## 4. NOT_RUN

- **Android / Galaxy S25 Ultra** : aucun téléphone n'a servi. Aucun APK n'est fourni avec cette version.
- Vibrations (`Input.vibrate_handheld`) : code présent, jamais ressenti sur appareil.
- Lisibilité en plein soleil, confort du pouce, fluidité ressentie : à juger sur téléphone.

## 5. Recette manuelle Android (à faire, statut NOT_RUN)

Sur le Galaxy S25 Ultra, en paysage, partie « Nouvelle campagne · deux systèmes » de 30 minutes au pouce :
1. Toucher une escouade, double toucher rapide (tous les mêmes à l'écran), glisser depuis une unité (rectangle), appui long puis glisser.
2. Bouton ＋ : ajouter / retirer des unités ; portraits du bas : garder / retirer un type.
3. Inactifs, Armée, Héros : un toucher chacun ; la caméra suit les inactifs.
4. Groupes : appui long pour enregistrer, toucher pour rappeler, double toucher pour centrer ; sauvegarder, recharger, vérifier les groupes.
5. Assaut en 2 touchers ; Enchaîner A → B → C ; toucher un numéro au sol (Déplacer, Supprimer, Insérer avant) ; boucle ; vider ; pause active puis ordres.
6. Ouvriers : Enchaîner + 3 maisons ; récolter ici ; réparer ; Auto.
7. Pose en ligne de palissades ; pose multiple de maisons ; lire la raison d'un refus sur le fantôme.
8. Fiche de caserne : ×5, appui maintenu, Répéter, annuler un élément de la file ; « Former » depuis n'importe où.
9. Pouvoirs : viser (cercle au sol), lancer, Retour pour annuler. Héros : sélectionner, centrer, état « tombé ».
10. Alertes : « Voir » ; points rouges sur la mini-carte.
11. Passage d'âge (monument) : cérémonie courte, jeu non bloqué, toucher pour passer.
12. Réglages : thème fixe, sons, vibrations, main gauche, échelle 115 % et 130 %, réduire les animations.
13. Retour Android dans chaque situation ; mise en arrière-plan puis retour (pause automatique conservée).
14. Lisibilité en plein soleil et de nuit, absence d'ordres involontaires, fluidité ressentie.
