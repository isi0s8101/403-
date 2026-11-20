# Sillons d'Empire — rapport de reprise pour un nouvel agent IA

État au 13 novembre 2026 : version **0.13.2 (J13, candidate)**. Branche `claude/new-session-sqs1d2`, dépôt `HRY-100/teste112313`, dossier `sillons/`.
À lire d'abord : `sillons/CLAUDE.md` (règles), puis ce rapport, puis `sillons/sillons/README-J13.md` et `sillons/sillons/game-studio/J13-validation.md`.

## 1. Le projet en deux phrases

Jeu de stratégie Android (Godot 4, GDScript, rendu Mobile), solo hors ligne, dix âges I–X, du village à l'empire interstellaire. L'utilisateur n'est pas développeur : réponds en français, simplement ; il envoie des archives zip et des documents de cadrage, et reçoit des archives complètes en retour.

Le dépôt contient aussi deux autres projets sans rapport (BLACKLINE, app Expo à la racine ; `n0c0dap/`). Ne jamais les mélanger avec `sillons/` : BLACKLINE les ignore (`metro.config.js`, `tsconfig.json`, zip complet).

## 2. Organisation du dépôt (`sillons/`)

| Chemin | Contenu |
|---|---|
| `CLAUDE.md` | consignes du projet, commande de vérification, procédure de livraison |
| `README-LIVRAISON.md` | résumé de la dernière version |
| `cadrage/` | `CADRAGE-INTEGRAL-EXPERT-V3.0.md` (fait foi), V2.0 (comparaison seulement), registre de décisions, matrices de recette |
| `sillons/` | **le projet Godot** (c'est lui qu'on ouvre dans Godot) |
| `assets_pipeline/` | chaîne de production des modèles 3D (Python, numpy, Pillow ; pas de Blender) |
| `RAPPORT-REPRISE.md` | ce fichier |

Dans le projet Godot : `sim/` (simulation à pas fixe), `game/` (scène de jeu, HUD, chargeur d'assets), `views/` (globe, orbite, système, galaxie, panneau de colonie), `procgen/` (planètes, étoiles, galaxie), `lab/` (recettes exécutables hors rendu), `tools/` (contrôles et export), `assets_3d/` (bibliothèque 3D), `game-studio/` (notes, preuves, manifeste SHA-256).

## 3. Historique des versions

| Version | Apport |
|---|---|
| 0.12.3 | source reçue (chantier naval orbital) ; jamais exécutée dans Godot avant J13-0 |
| 0.13.0 | J13-0 : import réel, 4 défauts corrigés, 3 recettes fausses corrigées ; colonies à âge local, zonage R/C/I, services, gouverneur, verrou orbital, trésorerie, transports, migration 0.12.3 |
| 0.13.1 | chaîne d'approvisionnement : habitants → troupes et colons, industrie → équipements et bâtiments ; intendant IA |
| 0.13.2 | 800 modèles 3D + chargeur ; colonie affichée en 3D sur le globe |

## 4. Architecture de la simulation (à connaître avant de toucher)

- `sim/sim_world.gd` : une carte tactique (unités, bâtiments, combat). `sim/star_campaign.gd` : campagne multi-planètes, âges, stocks par système, vols, fret, découverte. Tout avance dans `StarCampaign.step()` à 10 ticks/s ; jamais depuis une vue ni `_process`.
- **J13, par composition** (on n'a pas réécrit le RTS) :
  - `sim/j13_rules.gd` : toutes les tables (recettes, coûts, âges, densité, besoins unités/bâtiments). Valeurs **provisoires**.
  - `sim/planet_campaign.gd` (`StarCampaign.planets`) : colonies, âge local, 72 districts d'aire égale par planète (12×6), routes, zonage, population, industrie, commerce, services par graphe, trésorerie à écritures, transports, stations, verrou orbital, IA de siège, API métier.
  - `sim/planet_governor.gd` : gouverneur civil (âge X local) et intendant des IA. Décision pure, mêmes commandes que le joueur.
  - `sim/colony_gate.gd` + `SimWorld.supply_gate` : branche habitants et matériaux sur `train_check`/`build_check` (actif si `GameConfig.supply_chain`, vrai par défaut sur les nouvelles parties).
  - `sim/j13_save.gd` : bloc `j13` de la sauvegarde, validé champ par champ ; migration d'une sauvegarde 0.12.3 (trésorerie 0, aucune station offerte).
- API métier unique dans `StarCampaign` : `zone_planet`, `build_road`, `build_civic`, `set_zoning_balance`, `set_governor_policy`, `advance_colony_age`, `start_orbital_station`, `attack_orbital_station`, `request_hostile_landing`, `transfer_materials`, `found_colony`, `transfer_credits`. Chacune renvoie `{ok, reason, reason_code}` ; un refus n'a aucun effet (testé par empreinte d'état).
- Règles voulues par l'utilisateur (ne pas les contourner) : une colonie fondée naît à l'âge VII ; la production locale exige l'âge et les ressources **locaux** (une frégate importée ne débloque rien) ; les matériaux restent sur leur planète, seuls les crédits sont centralisés ; aucune attaque terrestre tant qu'une station de commandement ennemie opérationnelle protège la planète ; le gouverneur ne construit jamais gratuitement, ne démolit pas, ne touche ni océan, ni relief, ni réserves.

## 5. Assets 3D

- `sillons/assets_3d/` : 800 modèles × 3 niveaux de détail (2 400 GLB), 58 matériaux PBR, 174 textures partagées, `manifest.json`, `catalog.csv`, `report.html`, planches dans `previews/`. Les 30 GLB urbains d'origine restent intacts dans `sources/`.
- Régénération déterministe : `GODOT_BIN=… sillons/assets_pipeline/run_all.sh`, puis `python3 sillons/assets_pipeline/package.py` depuis la racine du dépôt (archives dans `livraison/assets/`, non versionnées).
- Chargeur : `game/asset_library.gd` (`find(catégorie, famille, âge)`, `instantiate(id, lod)`, matériaux partagés, couleur de camp). Branché **uniquement** sur le globe (`views/planet_globe_view.gd`, `show_districts`).
- **Honnêteté sur la qualité** : ce sont des volumes « low-poly » générés par code, pas du réalisme. Revue visuelle partielle : 538 vus et corrects, 42 à reprendre (frégate/destroyer/croiseur trop proches, drones constructeurs Mk1–3, carrefours industriels), 220 jamais regardés (`assets_pipeline/visual_review.json`, `assets_3d/report.json`).

## 6. Vérification

Godot n'est pas préinstallé. Télécharger 4.7.1 :
`https://github.com/godotengine/godot/releases/download/4.7.1-stable/Godot_v4.7.1-stable_linux.x86_64.zip`

```bash
cd sillons/sillons
GODOT_BIN=/chemin/Godot_v4.7.1-stable_linux.x86_64 ./tools/verify-j13.sh     # ~6 min, tout doit finir par J13_GODOT_HEADLESS=PASS
```

Dernier résultat complet (0.13.2) : 11 contrôles statiques PASS ; import PASS ; 15 scénarios J9–J13 PASS, dont recette intégrale J1–J8 (202), `j13_colony_test` (128), `j13_supply_test` (22), `assets_3d_test` (800/800 modèles, 2 400/2 400 fichiers), `j13_globe_test`, `j13_ui_test`. 12 anciens scénarios (fronts, modern, UI tactile, visuels J21) PASS à la 0.13.0, non relancés depuis 0.13.1.

Capture d'écran réelle possible : `xvfb-run -a -s "-screen 0 1280x600x24" $GODOT_BIN --rendering-driver opengl3 --path . --script res://lab/<script>.gd`, puis `root.get_texture().get_image().save_png(...)` (rendu logiciel, pas Android).

Pièges rencontrés :
- Après l'ajout d'un script avec `class_name`, relancer `--headless --path . --editor --quit` avant les tests (≈ 2 min avec les 2 400 GLB).
- Le manifeste `game-studio/manifest-j13.sha256` se régénère depuis `git ls-files .` (tout sauf lui-même) ; `git add` d'abord, sinon le contrôle statique échoue.
- À chaque version : `project.godot`, `export_presets.cfg` (`version/code`, `version/name`), les contrôles `tools/verify-*-static.py` (ils épinglent la version), `README-J13.md`, `J13-validation.md`, `changelog.md`, `CLAUDE.md`.
- `.godot/`, `*.import`, `livraison/`, `__pycache__` sont ignorés ; ne pas les versionner.
- GDScript : types explicites, jamais `:=` sur une valeur issue d'un `Dictionary`. Les instantanés de sauvegarde doivent être des copies profondes (défaut hérité corrigé).
- Les tests alimentent l'économie avec `c.planets._mint(...)` (dotation de laboratoire) ; ne pas le faire dans le jeu.

## 7. Ce qui n'a PAS été fait (ne pas le présenter comme fait)

- **Android** : aucun APK, aucun essai sur Galaxy S25 Ultra, aucune mesure de fluidité, mémoire ou chauffe. Tout ce qui touche Android est `NOT_RUN`.
- Rendu avec le moteur Mobile et une vraie carte graphique : une seule capture en OpenGL logiciel, à l'âge X ; couleurs très pâles, les trois types de zone se distinguent mal de loin.
- Modèles 3D sur la **carte tactique** (unités, bâtiments), la vue orbite, les vols : anciens visuels toujours en place. Pas de calques (énergie, eau, secours, zonage) sur le globe. Seule la colonie du joueur est affichée.
- Équilibrage : tous les coûts, rendements et besoins sont des premiers réglages, jamais joués. Les quatre préréglages R/C/I ne sont pas comparés.
- Absents du cadrage V3.0 : incendies et catastrophes, pollution, doctrines, rail dans la logique de jeu, diplomatie. L'IA assiège les stations mais ne gère le zonage que via l'intendant.
- Annuler une formation en file rend le coût historique mais pas les habitants ni les équipements.
- Modèles : pas de modules d'extension par emprise (2×1, 4×2), skinning rigide, véhicules sans animation enregistrée (pivots prêts), textures 128 px.
- Sauvegardes réelles de joueurs jamais essayées (seule une migration fabriquée en test).

## 8. Suite recommandée (ordre proposé à l'utilisateur)

1. Rendre les zones R/C/I reconnaissables de loin sur le globe (repère de couleur ou symbole par type) ; vérifier sur capture aux âges I, V et X.
2. Brancher `AssetLibrary` sur la carte tactique (`game/unit_visual.gd`, `game/building_visual.gd`), puis la vue orbite.
3. Reprendre les 42 modèles `needs_work`, regarder les 220 non vus, mettre à jour `visual_review.json`.
4. Calques du globe (énergie, eau, secours, zonage), colonie adverse.
5. Export Android et mesures réelles dès qu'un poste avec SDK et un appareil sont disponibles (`tools/export-android-j13.sh`).
6. Équilibrage par parties longues (IA contre IA à différents ratios R/C/I).

## 9. Livraison attendue par l'utilisateur

Toujours une archive **complète** (jamais un lot de correctifs), avec SHA-256, un résumé en français simple de ce qui marche, de ce qui n'a pas tourné et de ce qui reste. Commande, depuis la racine du dépôt (le dossier `livraison/` y est ignoré par git) : `N=sillons-empire-j13-colonies-<version>-source-complet; git archive --format=zip --prefix=$N/ -o livraison/$N.zip HEAD:sillons -- README-LIVRAISON.md cadrage sillons` (après `git add` et commit). Vérifier l'archive en l'extrayant et en relançant `python3 -I tools/verify-j13-static.py`. Dernière archive : `sillons-empire-j13-colonies-0.13.2-source-complet.zip`, SHA-256 `69c4669b14e2b1d4f87580eaac4c6cfd57d3a7cd378df6c40a2ef657753a0ea8`.
Ne jamais écrire « validé » ou « stable » pour ce qui n'a pas été exécuté ; ne pas créer de pull request sans demande explicite ; pousser sur `claude/new-session-sqs1d2`.
