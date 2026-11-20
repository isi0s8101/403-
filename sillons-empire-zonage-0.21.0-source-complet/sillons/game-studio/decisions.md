# Décisions

## Approuvées (créateur)

Les invariants du prompt maître V2, le périmètre des prompts J1 et J2, et :

| Id | Décision | Date | Mise en œuvre |
|---|---|---|---|
| D-07 | **Conquête : « ouvrier + moyens + minuteur »**. Règle `batisseur_et_moyens` conservée (ouvrier vivant ET stock ≥ coût d'un centre OU fondation OU dépôt) **et** élimination d'un camp resté sans centre achevé plus de `REBUILD_TIMEOUT` secondes, même s'il garde des moyens. | 2026-11-09 | J2 : `Rules.REBUILD_TIMEOUT = 180` s (valeur du minuteur PROVISOIRE, surchargeable `rebuild_timeout`) ; annonce « n'a plus de centre : N s pour en rebâtir un » ; scénario R05e PASS. |

## Provisoires (prises au J1 dans le cadre du mandat d'initiative, réversibles)

| Id | Décision | Justification | Preuve | Paramètre |
|---|---|---|---|---|
| D-01 | Simulation à pas fixe 10 ticks/s, déterministe, séparée du rendu (interpolation visuelle). | Rejeu exact, invariance de la vue (J2+), coût maîtrisé. | R09 déterminisme PASS | `Rules.TICK_RATE` |
| D-02 | Carte 96×96 cases, rivière NO→SE, deux gués, lac central avec îlot de minerai inaccessible, symétrie par échange x/y. | Lisibilité, équité, cas « gisement inaccessible » reproductible. | R02b PASS | `sim_map.gd` |
| D-03 | **Objectif de passage I→II : découvrir un comptoir neutre** — règle de recette PROVISOIRE (proposition du prompt non approuvée). Alternatives prêtes : `batiments_2`, `aucun`. | Lie l'exploration (âge I) au commerce (âge II). | R03, R03b PASS | `Rules.AGE_UP[2].objective` ou surcharge `age_up_2` |
| D-04 | Coût I→II : 400 nourriture, 200 bois ; durée 35 s. | Valeurs de test pour une partie prototype ≈ 15-30 min. | R03 | `Rules.AGE_UP` |
| D-05 | Économie : priorités 0-3 par ressource, répartition proportionnelle à reste le plus fort, réaffectation minimale toutes les 1 s, gisements explorés et atteignables uniquement, pénurie signalée. | Lecture claire d'une pénurie ou d'un trajet interrompu. | R01, R02, R02b PASS | `_economy()` |
| D-06 | Escouades de 6 formées à la production ; priorité : ordre direct unité > ordre direct escouade > délégation d'armée. « Rendre la main » rétablit le niveau inférieur. | Invariant « priorité des ordres directs ». | R04 PASS (16/16), recette tactile PASS | `SQUAD_SIZE` |
| D-07 | *Tranchée le 2026-11-09, voir « Approuvées ».* | | R05, R05b, R05c, R05d, R05e PASS | `rebuild_rule`, `rebuild_timeout` |
| D-08 | Ouverture commerce : relais marchand bâti contre un comptoir découvert + marché + caravanes ; gain par aller-retour = 1,15 × distance relais-marché. Échanges au marché, taux dégressif. | Le commerce accélère l'économie en exposant un investissement (relais, caravanes). | R07 PASS | `TRADE_PER_TILE`, `EXCHANGE_*` |
| D-09 | Ouverture assaut : seconde caserne, tireurs/cavaliers/lanciers, attaque dès le seuil d'armée. | Mobilise les ressources du développement. | R08 PASS | seuils IA |
| D-10 | IA : informations du camp uniquement (brouillard, mémoire des structures vues), mêmes ordres que le joueur ; réévaluation après pertes ≥ 60 % ou passage bloqué ; état exposé (objectif, cible, infos, abandon). | Exigence du prompt maître. | R06, R06b PASS | `ai_controller.gd` |
| D-11 | Commandes tactiles : tap = sélection/ordre, 2e tap sur une unité de l'escouade sélectionnée = unité seule (aussi appui long), glisser au-delà d'un seuil ≈ 3 mm = caméra, pincer = zoom, touchers commencés sur l'interface ignorés par le jeu. | « Commander sans déplacer la caméra par erreur ». | `touch_test.gd` PASS | `TAP_MAX_TIME`, `drag_threshold_px`, `PICK_RADIUS_PX` |
| D-12 | **Assets 3D procéduraux provisoires** (primitives + matériaux PBR générés), y compris la zone témoin. | Aucun asset tiers ni licence au J1. Ne satisfait pas encore la direction « 3D réaliste » : filière d'assets à arbitrer. | Captures `preuves/` | `game/assets.gd` |
| D-13 | Rendu Mobile (Vulkan), MSAA 2x, ombres directionnelles 2 cascades, échelle 3D 1,0 ; réglables dans la zone témoin. | À mesurer sur S25 Ultra avant de fixer les budgets. | NOT_RUN sur appareil | `project.godot` |
| D-14 | Profil de durée « prototype_j1 » séparé de la cible « cible_60min » (multiplicateurs de coûts et de durées). | Le prompt exige la séparation prototype / cible 60 min. | — | `Rules.DURATION_PROFILES`, `cost_mult`, `research_mult` |
| D-15 | Pause explicite en solo : la pause arrête toute la simulation (bouton II). | Conforme au maître (pause globale). | — | `game.paused` |

## Provisoires prises au J2 (mandat d'initiative, réversibles)

| Id | Décision | Justification | Preuve | Paramètre |
|---|---|---|---|---|
| D-16 | **Âge III « Forteresses »** : coût 700 nourriture, 450 bois, 300 minerai ; 45 s ; **objectif provisoire « tenir un gué »** = achever un bâtiment (tout type) à moins de 9 cases d'un gué. Alternatives : `batiments_2`, `aucun`. | Lie l'âge III au contrôle des passages, comme l'âge II à l'exploration. Ressources et objectif indépendants par camp. | R14 PASS (7/7) | `Rules.AGE_UP[3]`, surcharge `age_up_3`, `FORD_RADIUS_OBJECTIVE`, `max_age` |
| D-17 | **Palissade** (âge II, 1 case, 900 PV, 25 bois, 6 s), constructible **sur un gué**. Une ligne dans l'axe de la rivière suffit à fermer un gué. | Rend un passage fermable à faible coût ; contre-jeu : siège ou autre gué. | R11, R12, R13 PASS | `BUILDINGS.palissade`, `on_ford_ok` |
| D-18 | **Fort** (âge III, 3×3, 3 500 PV, 250 bois + 250 minerai, 50 s), tire à 8 cases (14 dégâts / 2 s), constructible sur un gué. Dégâts réduits contre les bâtiments pour tireurs (×0,35), cavaliers (×0,6) et ouvriers (×0,5). | Tenir un passage sans armée permanente ; seul le siège le fait tomber efficacement. Le laboratoire a montré qu'un fort mal placé (à 9 cases de l'extrémité du gué) ne couvre pas la palissade attaquée : le placement compte. | R11 PASS (fort intact, assaut repoussé avec pertes) | `BUILDINGS.fort`, `BUILDING_DAMAGE` |
| D-19 | **Canon de siège** (âge III, atelier ; 150 bois + 150 minerai ; 3 pop.) : 70 dégâts, ×3 contre bâtiments, ×0,25 contre unités ; portée 9, **portée minimale 3** (trop près : recule, état « cible trop proche ») ; **mise en batterie 3 s** à chaque arrêt avant le premier tir (état visible, fût qui se relève) ; lent (1,3). Les cavaliers ont ×2,5 contre le siège. Préfère les bâtiments à portée. | Siège lisible et décisif, avec contraintes observables : il faut le protéger, l'arrêter à distance, et il est vulnérable au contact. | R16 PASS (batterie, aucun tir avant 3 s, 210 dégâts, recul) ; R12 PASS | `UNITS.canon` (`setup`, `min_range`, `unit_mult`) |
| D-20 | **IA et passages** : avant chaque attaque, rapport de route (directe / détour ≥ 30 % / bloquée) ; si bloquée, elle identifie la première structure ennemie sur le chemin terrestre ; avec canons ou face à une palissade, elle l'assiège, puis reprend la marche quand le passage s'ouvre (« passage ouvert ») ; sans artillerie face à un fort, budget de siège (75 s ou 30 % de pertes) puis réévaluation « Préparer l'artillerie » (atelier et canons). Une palissade n'est jamais une cible d'attaque en soi. | Exploite chemins et positions fortifiées avec les seules informations du camp. | R11, R12, R13 PASS | `ai_controller.gd` (`_follow_attack`, `_fortify`, `_route_text`) |
| D-21 | **IA défensive** : à l'âge II, une palissade près de son gué (objectif d'âge III) ; à l'âge III, atelier, fort au gué (si minerai > 200), 2 à 4 canons ; l'armée se rallie au fort. | Rend les positions fortifiées utiles aussi pour l'IA. | R10 (graine 2001) : palissades des deux camps à 6 min 12 / 6 min 26, âge III à 11 min / 12 min, ateliers et 4 canons ; **aucun fort** dans cette partie (minerai jamais > 200 au bon moment) — à revoir à l'équilibrage | `_fortify` |
| D-22 | **Armée déléguée** : un poste inaccessible est remplacé par le point accessible le plus proche vers le centre du secteur (« repli, accès bloqué ») ; un poste atteignable seulement par un détour ≥ 30 % est signalé « autre accès ». | « Tenir une position ou trouver un autre accès lorsqu'une route praticable existe. » | R15 PASS | `_army()` |
| D-23 | **Budget de recherches de chemin : 24 par tick** ; au-delà, l'unité attend le tick suivant (ordre des identifiants, déterministe). | Un ordre de masse (250 unités) coûtait 250-310 ms en un tick. Comparaison même graine : budget illimité 39,9 ms moy. / 320 ms pic, 48 → 33 / 112, **24 → 25,7 / 72,5**, 12 → 21 / 64 ; R12 identique dans les quatre cas (passage ouvert à 39,8 s, franchissement à 83 s). 24 retenu : pic divisé par 4,4 sans changer la recette ; 12 n'apporte presque plus rien. | `preuves/comparaison_reglages.txt` | `PATH_BUDGET`, surcharge `path_budget` |
| D-24 | **Grille spatiale** pour la recherche de cibles (cases de 8, marge d'une case). Résultat strictement identique au parcours complet. | Coût de recherche de cibles quadratique à 400 unités. | 23 empreintes de scénarios identiques avant/après | `UGRID` |
| D-25 | **Test deux fronts** : deux simulations indépendantes (deux graines, mêmes règles), avancées au même pas fixe, une seule vue attachée au rendu ; niveaux de charge 40 / 100 / 200 / 400 unités par front ; protocole automatique de 40 s par niveau avec bascule toutes les 10 s ; mesures à la seconde enregistrées en JSON. | Mesurer séparément simulation et rendu, et l'effet de la bascule. | Invariance PASS ; `preuves/deux_fronts/` | `lab/theater.gd`, `game/fronts.gd`, `lab/fronts/*.json` |
| D-26 | `lab_block_ford` : par défaut une **ligne** de palissades dans l'axe de la rivière (`"full": true` = gué rempli). | Une ligne suffit à fermer et rend le siège mesurable ; le verrou épais sert au cas « fort + verrou sans artillerie ». | R11 (épais), R12, R13 (ligne) | commande de labo |

## Arbitrages demandés au créateur

1. **D-03 Objectif de passage I→II** : approuver « découvrir un comptoir neutre » ou choisir une autre règle.
2. **D-16 Objectif de passage II→III** : approuver « achever un bâtiment à moins de 9 cases d'un gué » (ou autre).
3. **D-12 Assets réalistes** : filière (modélisation dédiée, achat sous licence, génération) et budget. Les mesures
   deux fronts sur S25 Ultra fixeront le budget de rendu disponible ; à décider avant J3.
4. **Budgets de référence** (unités par front, ms de simulation, ms d'image, mémoire) : proposés dans
   `mesures-rendu.md` après les mesures physiques J2 ; à approuver.
