# Reprise — Sillons d’Empire 0.13.3 candidate

Base : archive 0.13.2 fournie, SHA-256 69c4669b14e2b1d4f87580eaac4c6cfd57d3a7cd378df6c40a2ef657753a0ea8.

Lire d’abord `README-LIVRAISON.md`, puis `sillons/README-REFONTE-0.13.3.md` et `sillons/game-studio/J13-validation.md`.

## Invariants

Le simulateur `sim/` (32 fichiers) reste identique. Ne pas déplacer les décisions économiques dans les vues. Conserver âges locaux, stocks locaux, validation des commandes et refus sans effet. Les recettes d’installation et de jeu ne doivent pas inventer des ressources ; les dotations de `capture-refonte.gd` sont exclusivement des fixtures de laboratoire.

## Ajouts de la refonte

`game/mobile_ui.gd` : thème et zones sûres. `game/render_profile.gd` : résolution 3D et ombres. `game/tactical_models.gd` : correspondances d’assets et animation. `game/asset_library.gd` : caches et fusion par matériau. `game/world_view.gd` : LOD et lots GPU régionaux. `game/hud.gd` : panneaux, icônes et voile modal. `views/planet_globe_view.gd` : texture progressive, cache de trois planètes, calques. `views/colony_panel.gd` : onglets et commandes métier.

## Validation et reprise technique

Godot 4.7.1 ; `GODOT_BIN=/chemin/godot bash tools/verify-refonte.sh`. 32 scénarios PASS, dont refonte 140 contrôles et modalités tactiles 4 contrôles. Une sonde héritée reste SKIP en headless. Les captures sont du moteur OpenGL logiciel, pas d’Android. Les résultats de rendu du benchmark ne sont pas des résultats de FPS sur téléphone.

Toujours lire les métadonnées de validation et ne pas déclarer la version stable. Aucun APK, SDK Android ni appareil n’a été utilisé. Les nouveaux scripts utilisent des types explicites pour les valeurs issues des dictionnaires.

## Travail restant

Validation Mobile/Vulkan et S25 Ultra ; revue artistique des 42 modèles à reprendre et des 220 non revus ; amélioration des modèles trop simples, végétation et animations mécaniques ; équilibrage réel ; limites métier documentées de J13. La chaîne historique `assets_pipeline/` n’est pas dans la source fournie ; seul le générateur des nouvelles textures est inclus ici.

Conserver cette archive et la 0.13.2. Fournir les versions suivantes sous forme d’archives sources complètes avec manifeste et preuves ; ne pas substituer des tests statiques aux exécutions Godot/Android.
