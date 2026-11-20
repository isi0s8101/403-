# État de validation — J2.1-C 0.2.2

| Contrôle | Statut |
|---|---|
| Provenance J2.1 FIX1 | PASS (diff et copies de travail) |
| Source `sim/` identique à baseline J2 | PASS (octets comparés) |
| Intégrité des 5 PNG 512x512 | PASS |
| Références de scènes `.tscn` | PASS statique |
| Compatibilité J2.1 UI (contrôles statiques) | PASS |
| Compilation/parseur Godot 4.7.2 | NOT_RUN (moteur absent) |
| Shader Mobile et rendu visuel réel | NOT_RUN |
| `lab/visual_j21c_test.gd` | NOT_RUN |
| 23 scénarios J2 / 99 assertions | NOT_RUN sur cette version (preuves précédentes historiques) |
| Bench deux fronts sur S25 Ultra | NOT_RUN |
| APK Android | NON_PRODUIT (export SDK absent) |

La validation statique ne signifie pas compatibilité moteur : vérifier les logs du parseur et du compilateur de shaders avant toute promotion.
