# Reprise — 0.16.0

Base : 0.15.1 R2 reçue en archive (SHA-256 `c4c25119aff929a0271508878ce593d56582fc791e2fd358511c4a4ee3f061b3`), intégrée dans le dépôt `HRY-100/teste112313`, branche `claude/new-session-sqs1d2`, dossier `sillons/`. Audit : `AUDIT-0.15.1-R2.md` (50/50 scénarios reproduits).

Ajout de la 0.16.0 : évolution de la civilisation demandée par l'utilisateur (« améliorer la partie évolution en se référant à des RTS comme Age of Empires ou le Seigneur des Anneaux »), selon ses choix : voies au choix (pas de civilisations fixes), monument au choix pour passer d'âge, améliorations d'armée, héros et pouvoirs de commandement (la vétérance n'a pas été retenue). Inspiration de genre seulement, aucun contenu repris.

Fichiers : `sim/civ_rules.gd`, `sim/civ_evolution.gd`, `sim/civ_ai.gd`, `interface/civ_panel.gd`, recettes `lab/civ_evolution_test.gd` et `lab/civ_ui_test.gd`. Activation : règle de monde `civ_evolution` posée par `CampaignSetup` (`GameConfig.civ_evolution`). Changement J13 : `J13Rules.FOOD_SALE_FLOOR` (les commerces gardent 400 vivres).

Vérifier : `cd sillons/sillons && GODOT_BIN=… bash tools/verify-refonte.sh` (52 scénarios). Après un ajout de fichier suivi par git dans le projet : `git add` puis `python3 -I tools/update-manifest-j13.py`.

Reste à faire : équilibrage en partie réelle, effets visuels des pouvoirs et des auras, modèles propres aux héros, export APK et recette sur Galaxy S25 Ultra (NOT_RUN), navigation de l'IA sur la carte de 96 cases.
