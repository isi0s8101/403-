# Validation — Sillons d'Empire 0.20.0 (zonage dynamique, LOT B)

Environnement : Godot **4.7.2.stable.official** (Linux x86_64), sans téléphone. Captures : xvfb + `--rendering-driver opengl3`.
Règle : ce qui n'a pas tourné est **NOT_RUN**. Graines fixes dans toutes les recettes. LOT A : `VALIDATION-ZONAGE-0.19.0.md`.

## 1. Exécuté

| Contrôle | Résultat |
|---|---|
| Contrôles statiques (`verify-refonte-static.py`, 17 suites ; `verify-urbain-static.py` étendu au LOT B) | PASS |
| Compilation de chaque script (`tools/check-scripts.gd`) | PASS — 107 scripts |
| Caractères d'interface présents dans les polices (`tools/check-glyphs.gd`) | PASS — 42 caractères, 0 absent |
| `verify-refonte.sh` 0.20.0 (import, compilation, **64 scénarios**, paquet natif) | PASS — **64/64** en un seul passage (`REFONTE_GODOT=PASS scenarios=64`, `NATIVE_PACKAGED_RUNTIME=PASS`) |
| `urban_lotb` (nouveau : événements, calcul réparti, villes lointaines, IA, coûts) | PASS — 36 vérifications |
| `ui_zoning` (mode Zonage, au doigt ; + filtres et villes de chaque monde) | PASS — 34 vérifications |
| `zoning` | PASS — 79 vérifications |
| `urban_city` (A01 adapté, raison écrite dans le fichier) | PASS — 70 vérifications |
| `ui_city` | PASS — 25 vérifications |
| Captures réelles : 10 âges, filtre « État » | `preuves/zonage-0.20.0/` |

## 2. Les 24 tests demandés (état après les deux lots)

| # | Test | Vérifications | Statut |
|---|---|---|---|
| 1–3 | Zones résidentielle, commerciale, industrielle | Z01–Z04, A07, A09, A10 | PASS |
| 4 | Sélection tactile | A03, A07–A11, A15, A16, A25 ; filtres au doigt F01–F04 | PASS |
| 5–6 | Modification, suppression d'une zone | Z06, Z07, Z52–Z53, A12–A14 | PASS |
| 7–8 | Construction automatique ; pas de construction sans conditions | Z20–Z35, A17 | PASS |
| 9–10 | Évolution des bâtiments ; densification | Z41, Z44, Z45, Z49, A19 | PASS |
| 11 | Évolution selon l'âge | Z42, Z43, Z46–Z48, A18 ; capture des 10 âges (palette et toiture propres à chaque âge) | PASS |
| 12 | Criminalité | Z54–Z61 ; exode lié à l'insécurité E14 | PASS |
| 13–16 | Incendie, propagation, destruction, reconstruction | Z70–Z78 ; séisme qui allume des feux E04 ; tempête qui les éteint E06 | PASS |
| 17–18 | Sauvegarde, chargement | Z75, Z82–Z85 ; événement en cours et inondation sauvegardés E18–E19 | PASS |
| 19 | Migration des sauvegardes | Z86–Z88 | PASS |
| 20 | Simulation IA | Z91–Z93 (après l'électricité) ; I01–I03 (âge II, avant l'électricité, surplus seulement) ; E20 | PASS |
| 21 | Simulation hors écran | M01–M04 : ville d'un monde lointain calculée une période sur 3, production à ±30 % et croissance équivalentes au calcul détaillé | PASS |
| 22 | Changement d'échelle | M06 (aller-retour sans perte), M07 (résumé d'une ville), M20–M21 (toutes les villes du camp dans le panneau Ville, dans la vraie campagne) | PASS |
| 23 | Performance Android | seuils mesurés sous Linux : P01, P02, M05, Z99, Z99b | **NOT_RUN sur Android** |
| 24 | Pas de régression | `verify-refonte.sh` : 61 anciens scénarios + 3 nouveaux | PASS (64/64) |

## 3. Nouvelles vérifications du LOT B

- **Événements**
  - E01 : catalogue décrit par des données.
  - E02–E05 : séisme (dégâts atténués, jamais rasé d'un coup, feux comptés) ; événement inconnu refusé.
  - E06–E07 : tempête (feux éteints, bois plus fragile).
  - E08–E10 : inondation (seulement au bord de l'eau, production arrêtée puis reprise).
  - E11–E12 : crise (demande et production du commerce en baisse, fin après 2 minutes).
  - E13–E14 : migration et exode.
  - E15–E17 : rien pendant les 15 premières minutes ; tirage naturel ensuite, déterministe.
  - E18–E19 : sauvegarde.
  - E20 : l'IA est soumise aux mêmes événements.
- **Calcul réparti** : S01 (camps décalés), S02 (mondes décalés), S03 (un calcul par période à l'écran).
- **Villes lointaines** : M01–M08, dont M05 (coût mesuré 40 % du calcul détaillé) et M08 (l'échelle de temps revient à 1).
- **IA** : I01–I03.
- **Coûts** : P01 (accès à la route de 137 bâtiments en un tick : 1,9 à 2,2 ms), P02 (ville de 136 bâtiments : 9 à 11 ms).
- **Interface** : F01–F06 (filtres, calque du zonage hors du mode), M20–M21 (villes de chaque monde).

## 4. Performance (mesures Linux, CPU partagé)

| Indicateur | 0.19.0 | 0.20.0 | Seuil |
|---|---|---|---|
| Calcul complet d'une ville de 136 bâtiments | 15–16 ms | 9–11 ms | 20 ms (P02) |
| Accès à la route de tous les bâtiments en un tick | coût au carré | 1,9–2,2 ms | 6 ms (P01) |
| Ville d'un monde lointain (1 min de jeu) | identique au détail | 40 % du détail | 50 % (M05) |
| Camps d'un même monde | même tick | ticks 7 et 17 | S01 |

Cause du gain : chaque vérification d'accès à la route reparcourait tous les bâtiments de la carte. Le résultat est maintenant gardé pour le tick en cours.

Sur téléphone : **NOT_RUN**.

## 5. Recette existante adaptée (raison écrite dans le fichier)

- `lab/urban_city_test.gd`, A01 : les camps sont désormais calculés à des ticks différents. La partie évolue donc autrement, et un incendie peut ensuite détruire un bâtiment d'une IA à court de bois. A01 vérifie maintenant ce que l'IA a bâti (le plus grand nombre atteint pendant la partie), et non ce qui a survécu aux incendies.

## 6. NOT_RUN et limites

- **Android / Galaxy S25 Ultra** : aucun téléphone et aucun APK (pas de SDK Android ni de modèles d'export ici, réseau coupé).
- **Équilibrage** : les fréquences des événements et le rythme des villes lointaines sont provisoires.
- **IA après l'électricité** : elle dépense beaucoup de bois pour son armée (comportement antérieur), ce qui laisse sa ville sans réparations.

## 7. Recette manuelle Android (à faire, statut NOT_RUN)

1. Mode Zones → Filtre : passer en revue les 10 filtres. Vérifier que les couleurs restent lisibles en plein soleil.
2. Laisser tourner une partie plus de 20 minutes avec une ville : un événement arrive. Lire l'alerte, la barre et le panneau Ville.
3. Fonder une colonie dans un autre monde, revenir au monde principal, puis ouvrir le panneau Ville : la section « Toutes vos villes » apparaît.
4. Contre l'IA à l'âge I ou II : vérifier qu'un petit quartier apparaît chez elle.
5. Mesurer la fluidité avec deux villes de plus de 100 bâtiments (une par camp) : aucune saccade toutes les 2 s.
