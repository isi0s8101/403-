# Validation — Sillons d'Empire 0.18.0 (ville de l'âge de l'électricité, paysage et portrait)

Environnement : Godot **4.7.2.stable.official** (Linux x86_64), sans téléphone. Captures : xvfb + `--rendering-driver opengl3`.
Règle : ce qui n'a pas tourné est **NOT_RUN**.

## 1. Exécuté

| Contrôle | Résultat |
|---|---|
| Contrôles statiques (`verify-refonte-static.py`, 17 suites dont la nouvelle `verify-urbain-static.py`) | PASS |
| Compilation de chaque script (`tools/check-scripts.gd`) | PASS |
| `verify-refonte.sh` 0.18.0 (import, compilation, **61 scénarios**, paquet natif) | PASS — **61/61**, en trois passages : contrôles statiques, import, compilation et 23 scénarios ; puis 34 ; puis les 4 derniers et le paquet natif (`NATIVE_PACKAGED_RUNTIME=PASS`). Entre les passages : deux recettes rendues robustes (voir ci-dessous), sans changer le comportement attendu. |
| `urban_city` (simulation de la ville, sauvegarde, déterminisme, IA) | PASS — 70 vérifications |
| `ui_city` (ville dans la vraie scène : recherche, conversion, Bâtir, pose, fiche, panneau Ville, vues, alertes) | PASS — 25 vérifications |
| `ui_portrait` (paysage et portrait dans la vraie scène, téléphones, tablette, rotations, menus, globe, espace) | PASS — 40 vérifications |
| Captures réelles (ville en paysage, vues au sol, panneau Ville, jeu en portrait) | `preuves/ville-0.18.0/` |

Ce que couvre `urban_city` : ancien mode inchangé (U01–U03, A06) ; recherche refusée avant l'âge IV et hors de l'usine ; conversion des maisons sans perte de place d'unité ; arrêt des fermes et de la récolte ; anciens bâtiments plus constructibles ; zones posées par la commande « build » habituelle ; réseau électrique (portée, postes en chaîne, délestage avec l'hôpital prioritaire) ; eau (château d'eau sans électricité = pas d'eau) ; police (criminalité plus basse), capacité des pompiers, pollution et décharge ; densité, amélioration payée, habitants, places d'unité, production commerce / industrie, emplois, bien-être à 7 facteurs, industrie sans électricité à l'arrêt ; incendies (dégâts, destruction sans pompiers, extinction avec pompiers, départs spontanés) ; épidémies et hôpital ; sauvegarde identique et reprise déterministe ; IA qui bâtit une ville qui produit, sans ordre refusé.

Recettes existantes adaptées (comportement voulu inchangé, raison écrite dans le fichier) :
- `lab/modern_ui_test.gd` pose tous les bâtiments des âges IV à VIII sur une seule rangée ; avec les 13 bâtiments urbains ajoutés, la rangée dépassait la carte de 96 cases (erreurs « hors limites »). La recette passe désormais à la ligne toutes les 16 poses.
- `lab/ui_theme_test.gd` (T17–T20) jouait une cérémonie vers l'âge 8 alors que la partie était à un autre âge ; le contrôle périodique du HUD (toutes les 0,2 s) ramenait parfois le thème à l'âge réel avant la vérification (échec aléatoire). La partie est désormais mise à l'âge joué par la cérémonie ; trois passages de suite au vert. En jeu réel, la cérémonie vise toujours l'âge réel : pas de conflit.

## 2. Indicateurs

| Indicateur | Mesure |
|---|---|
| Écrans testés en portrait sans élément hors écran ni chevauchement des barres | téléphone 740×1600 et 1110×2400, tablette 2560×1600 et 1600×2560, main gauche, grande échelle |
| Taille des boutons en portrait | ≥ 52 points (cible : 44) |
| Rotation en cours de partie | fiche, panneau Civilisation et panneau Ville restent ouverts ; simulation identique ; retour exact à la disposition paysage |
| Toucher pour sélectionner / donner un ordre en portrait | 1 toucher pour sélectionner, Marcher + 1 toucher au sol |
| Partie reproductible avec la ville | même état après sauvegarde et reprise (D01–D03) |
| Privilège de l'IA | aucun : mêmes commandes, aucune ressource donnée (contrôle statique + A05) |

## 3. Valeurs provisoires

Toutes les valeurs de `sim/urban_rules.gd` (coûts, rayons, capacités, production, criminalité, incendies, santé, croissance) sont **PROVISOIRES** et doivent être équilibrées en partie réelle.

## 4. NOT_RUN

- **Android / Galaxy S25 Ultra** : aucun téléphone n'a servi ; aucun APK n'est fourni.
- Rotation réelle de l'appareil (capteur) : simulée en changeant la taille de la fenêtre.
- Équilibrage d'une partie complète avec la ville (durée, difficulté, IA) : à juger en jouant.

## 5. Recette manuelle Android (à faire, statut NOT_RUN)

1. Campagne « deux systèmes » jusqu'à l'âge IV ; usine → Électricité ; vérifier la conversion des maisons et l'arrêt des fermes.
2. Poser 4 habitations, 2 commerces, 2 industries, une centrale, un château d'eau ; suivre le panneau Ville pendant 5 minutes.
3. Vues au sol : électricité, eau, sécurité, pompiers, santé, pollution, bien-être.
4. Laisser une industrie sans pompiers jusqu'à un incendie ; poser une caserne ; vérifier l'alerte et « Voir ».
5. Améliorer une zone au niveau II puis III.
6. Tourner le téléphone pendant la partie : panneau ouvert, sélection, pose en cours ; vérifier que rien ne se ferme.
7. En portrait : sélectionner, donner des ordres, bâtir, ouvrir la fiche d'un bâtiment, le panneau Ville, le globe.
8. Lisibilité au soleil, confort au pouce dans les deux sens.

## 6. Correctif 0.18.1 (capture de l'auteur sur Android)

| Défaut vu sur téléphone | Correction | Vérification |
|---|---|---|
| Bouton d'ajout affiché comme un carré « FF0B » | « + » ordinaire ; 33 symboles absents des polices remplacés ; bouton lecture dessiné ; menus et étiquettes 3D en Fira Sans | `tools/check-glyphs.gd` : 42 caractères d'interface, 0 absent ; étape REFONTE_GLYPHS de `verify-refonte.sh` ; `ui_portrait` R03c |
| Mini-carte étirée en hauteur | carte carrée (108 points en paysage, 188 en portrait) | `ui_portrait` R03b, R06b, R06c (le toucher vise toujours le bon endroit) |

Passage complet 0.18.1 : **PASS 61/61 en un seul passage** (statique 17 suites, compilation, caractères, 61 scénarios, paquet natif). Capture après correctif : `preuves/ville-0.18.0/portrait-debut-0181-740.png`.
