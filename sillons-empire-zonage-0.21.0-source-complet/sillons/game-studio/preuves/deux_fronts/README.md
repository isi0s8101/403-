# Preuves — essai deux fronts (J2)

| Fichier | Contenu |
|---|---|
| `invariance.txt` / `invariance.json` | Test d'invariance : A (sans vue) contre B (bascule / 100 ticks) et C (bascule / 37 ticks, deux vues synchronisées), niveaux 100 (1 500 ticks) et 400 (300 ticks), empreintes par tick, journaux, suites d'ordres, état individuel des unités ; contrôle négatif. |
| `ordres_front_A_niveau100_1500ticks.json`, `ordres_front_B_…` | Suites d'ordres complètes du run de référence (placements de laboratoire et ordres émis par les IA, avec tick, résultat et cause de refus). |
| `reference_conteneur_headless.json` | Protocole automatique sur le conteneur de build, sans GPU : simulation seulement (rendu non mesuré). |

## Rejouer

```bash
# invariance (code de sortie 0 = PASS) ; réécrit les fichiers de ce dossier
godot --headless --path . -s res://lab/fronts_test.gd
# une autre charge / durée
godot --headless --path . -s res://lab/fronts_test.gd -- 200 900
# protocole de mesure automatique (40 s par niveau)
godot --headless --path . -- --fronts-auto --fronts-sec=40 --fronts-quit
```

Graines : front A 3101 (`lab/fronts/front_a_gue.json`), front B 3202 (`lab/fronts/front_b_plaine.json`).
Les groupes marqués `"scalable": true` sont multipliés pour atteindre le niveau visé (`Theater.build(niveau)`).
Les deux fronts sont pilotés par des IA (les ordres sont donc produits par la simulation elle-même et archivés).
