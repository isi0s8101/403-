# Validation J2.1 — 2026-11-09

| Test | Résultat | Justification |
|---|---|---|
| ZIP source complet / CRC ZIP | PASS (contrôle après packaging) | Archive préparée depuis la baseline J2 |
| Intégrité des fichiers `sim/` | PASS | Octets identiques à J2, vérifiés par `verify_j21_static.py` |
| Scènes et fichiers GDScript référencés | Statique | Vérification des chemins à l'empaquetage |
| Compilation Godot 4.4.1 | NOT_RUN | Moteur non disponible |
| 23 scénarios J2 / 99 assertions | NOT_RUN sur J2.1 | Preuves embarquées J2 historiques uniquement |
| `lab/touch_test.gd` original | NOT_RUN sur J2.1 | Recette préservée |
| `lab/ui_j21_test.gd` | NOT_RUN | Nouveau test ; exécuter sous Godot |
| `lab/fronts_test.gd` | NOT_RUN sur J2.1 | Banc deux fronts préservé |
| Export APK | NOT_RUN | SDK/export Godot absents |
| Galaxy S25 Ultra | NOT_RUN | Recette détaillée dans J21-mobile-ui.md |

**Ne pas promouvoir J2.1 au rang de baseline validée avant compilation et tests sur l'appareil cible.**
