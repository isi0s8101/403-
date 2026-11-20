# Validation — Sillons d'Empire 0.19.0 (zonage dynamique, LOT A)

Environnement : Godot **4.7.2.stable.official** (Linux x86_64), sans téléphone. Captures : xvfb + `--rendering-driver opengl3`.
Règle : ce qui n'a pas tourné est **NOT_RUN**. Graines fixes dans toutes les recettes (partie reproductible).

## 1. Exécuté

| Contrôle | Résultat |
|---|---|
| Contrôles statiques (`verify-refonte-static.py`, 17 suites ; `verify-urbain-static.py` étendu au zonage) | PASS |
| Compilation de chaque script (`tools/check-scripts.gd`) | PASS — 105 scripts |
| Caractères d'interface présents dans les polices (`tools/check-glyphs.gd`) | PASS — 42 caractères, 0 absent |
| `verify-refonte.sh` 0.19.0 (import, compilation, **63 scénarios**, paquet natif) | PASS — **63/63**, en deux passages : contrôles statiques, import, compilation, glyphes et 43 scénarios ; puis les 20 derniers et le paquet natif (`NATIVE_PACKAGED_RUNTIME=PASS`). Entre les deux : portraits ajoutés pour le puits, l'exploitation agricole et les ruines (`interface_interaction`, `interface_portraits` les exigeaient) ; `refonte_visual` relancé ensuite : PASS (187). |
| `zoning` (simulation du zonage) | PASS — 79 vérifications |
| `ui_zoning` (mode Zonage dans la vraie scène, au doigt) | PASS — 26 vérifications |
| `urban_city` (ville 0.18, adaptée) | PASS — 70 vérifications |
| `ui_city` (panneau Ville, adapté) | PASS — 25 vérifications |
| `ui_portrait` (paysage et portrait) | PASS — 44 vérifications |
| Captures réelles (quartier, mode Zonage en paysage et en portrait) | `preuves/zonage-0.19.0/` |

## 2. Les 24 tests demandés

| # | Test | Vérifications | Statut |
|---|---|---|---|
| 1 | Zone résidentielle | Z01, A07, A09 | PASS |
| 2 | Zone commerciale | Z02, A10 | PASS |
| 3 | Zone industrielle | Z03 (et agricole : Z04) | PASS |
| 4 | Sélection tactile | A03 (un toucher), A07–A11 (pinceau, taille, rectangle, parcelle), A15 (deux doigts : caméra, pas de peinture), A16 (inspecter), A25 (boutons ≥ 44 points) | PASS |
| 5 | Modification d'une zone | Z06, A14 (rezonage), A13 (annuler) | PASS |
| 6 | Suppression d'une zone | Z07, A12, Z52–Z53 (bâtiment abandonné puis démoli) | PASS |
| 7 | Construction automatique | Z20–Z29, A17 | PASS |
| 8 | Pas de construction sans les conditions | Z30 (sans route), Z31 (route non reliée), Z32 (sans bois), Z33 (ennemi), Z35 (sans demande), Z08–Z10, Z15–Z16 (refus) | PASS |
| 9 | Évolution des bâtiments | Z44, Z45, Z49, A19 | PASS |
| 10 | Densification | Z41 | PASS |
| 11 | Évolution selon l'âge | Z42, Z43, Z46, Z47 (transformation progressive), Z48 (quartier historique), A18 | PASS (silhouettes plus marquées des 10 âges : LOT B) |
| 12 | Criminalité | Z54–Z61 (garde, commissariat, dégradation, pillages, émeute, départs, fin d'émeute, dégâts limités) | PASS |
| 13 | Incendie | Z70–Z72, Z77, Z78 | PASS |
| 14 | Propagation | Z73 | PASS |
| 15 | Destruction | Z74 | PASS |
| 16 | Reconstruction | Z76 | PASS |
| 17 | Sauvegarde | Z75, Z82 | PASS |
| 18 | Chargement | Z83, Z84 (reprise déterministe), Z85 | PASS |
| 19 | Migration des sauvegardes | Z86–Z88 (partie 0.18 convertie une seule fois) | PASS |
| 20 | Simulation IA | Z91–Z93 (routes, zones, croissance par les mêmes commandes) | PASS |
| 21 | Simulation hors écran | la ville est calculée par la simulation, sans lien avec la caméra : Z91–Z93 (ville de l'IA jamais affichée), toutes les recettes `zoning` tournent sans écran | PASS (villes lointaines abrégées : LOT B) |
| 22 | Changement d'échelle | — | **NOT_RUN** (LOT B) |
| 23 | Performance Android | Z98–Z99b mesurés sous Linux | **NOT_RUN sur Android** |
| 24 | Pas de régression | `verify-refonte.sh` : 61 anciens scénarios + 2 nouveaux | PASS (63/63) |

## 3. Performance (mesures Linux, CPU partagé)

| Indicateur | Mesure | Seuil |
|---|---|---|
| 20 ticks (2 s de jeu) avec 136 bâtiments de zone | 24,6 ms | 250 ms (Z99) |
| Tick qui calcule la ville (une fois toutes les 2 s) | 16,0 ms | 60 ms sous Linux (Z99b) |
| Tick ordinaire | 0,6 ms | — |
| Routes et calque du zonage | dessinés par le terrain : 0 objet ajouté | contrôle A06 |
| Modèles de la ville | reconstruits seulement si la catégorie, le niveau, l'âge ou l'état changent | contrôle A19 |

Limite connue : sur un téléphone, le tick de la ville pourrait coûter 3 à 4 fois plus (estimation, **non mesurée**) et provoquer une petite saccade toutes les 2 s dans une très grande ville. Le LOT B répartira ce calcul sur plusieurs ticks et fixera un seuil Android mesuré.

## 4. Recettes existantes adaptées (comportement voulu changé, raison écrite dans le fichier)

- `lab/urban_city_test.gd` (U04, U18–U20, G06) : les zones ne se posent plus à la main (elles poussent sur le zonage) ; les vérifications passent par les zones peintes et les routes.
- `lab/ui_city_test.gd` (C09, C14) : même raison ; la vérification de la fiche utilise une case libre de la ville (`open_cell`).

## 5. Valeurs provisoires

Toutes les valeurs de `sim/urban_rules.gd` et les coûts de route de `sim/urban_zoning.gd` sont **PROVISOIRES** et doivent être équilibrées en partie réelle.

## 6. NOT_RUN

- **Android / Galaxy S25 Ultra** : aucun téléphone ; aucun APK (pas de SDK Android ni de modèles d'export ici, réseau coupé).
- Changement d'échelle et villes lointaines abrégées (LOT B).
- Équilibrage d'une partie complète avec le zonage.

## 7. Recette manuelle Android (à faire, statut NOT_RUN)

1. Nouvelle campagne ; dès l'âge I : Bâtir → Zones ; tracer une route depuis le centre, peindre de l'habitat le long de la route.
2. Vérifier que des chantiers s'ouvrent seuls ; peindre du commerce et de l'agricole ; suivre les barres de demande.
3. Pinceau 1, 2, 3 ; rectangle ; parcelle ; gomme ; annuler ; deux doigts pour déplacer la caméra pendant le mode.
4. Inspecter un quartier ; ouvrir la fiche d'un bâtiment ; « Conserver l'architecture ».
5. Passer un âge ; vérifier que seuls les nouveaux bâtiments changent d'architecture.
6. Laisser un quartier de bois sans puits pendant la saison sèche : feu, propagation, ruines, reconstruction.
7. Charger une partie 0.18 : zones converties.
8. Tourner le téléphone avec le mode Zonage ouvert.
9. Mesurer la fluidité avec une grande ville (plus de 100 bâtiments).
