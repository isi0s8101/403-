# Sillons d'Empire 0.21.0 — Terre réelle + Nouvelle partie

Base : 0.20.0 (zonage, LOT B). Deux ajouts.

## 1. La vraie Terre
- Graine **1789** = Terre réelle (relief, océans, biomes ; Natural Earth + modèle numérique de terrain). Toute autre graine reste procédurale.
- `procgen/earth_data.gd`, `data/terre_2048.bytes` (3,5 Mo, gzip), branchement dans `PlanetGenerator.sample()`.
- Test : `godot --headless --path . --script res://lab/earth_test.gd` (16/16 PASS validé).

## 2. Menu « Nouvelle partie »
- `game/new_game_screen.gd` + `.tscn`, données dans `game/game_setup.gd`. Bouton principal du menu ; l'ancien lancement devient « Partie rapide ».
- Réglages : mode, monde (Terre / aléatoire / graine), taille de carte, durée, vitesse, ressources, ouvriers, éclaireurs, carte explorée, IA (comportement, dotation, démo), civilisation, chaîne d'approvisionnement, événements ; 5 préréglages ; réglages mémorisés.
- Règles ajoutées au monde : `cost_mult`, `research_mult`, `start`, `start_ai`, `ai_attack_mult`, `events_scale`, `reveal_map`. Sans le menu, aucune règle n'est ajoutée.
- Test : `godot --headless --path . --script res://lab/new_game_test.gd` (**NOT_RUN** : écrit, jamais exécuté).

## À faire avant livraison
`verify-refonte.sh` (64 scénarios) n'a pas été relancé sur cette version. Le manifest SHA256 est régénéré ; les APK/preuves de 0.20.0 ne correspondent plus.
