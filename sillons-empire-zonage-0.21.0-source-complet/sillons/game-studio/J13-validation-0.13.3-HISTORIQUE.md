# Validation 0.13.3 — candidate

Session du 13 novembre 2026. Godot **4.7.1.stable.official.a13da4feb**, Linux x86_64.

| Contrôle | Résultat |
|---|---|
| Import Godot et chargement des scènes | PASS |
| Scénarios historiques et nouveaux | **32/32 PASS**, aucune erreur de script dans les journaux finaux |
| Recette intégrale J1–J8 | PASS 202/202 |
| Colonies J13 | PASS 128/128 |
| Approvisionnement J13 | PASS 22/22 |
| Nouvelle recette de refonte | PASS 140/140 |
| Parcours tactile pause → aide → menu → reprise | PASS 4/4 |
| Catalogue GLB | PASS 800/800 modèles, 2 400/2 400 fichiers |
| Simulation comparée à la 0.13.2 | 32 fichiers identiques |
| Contrôles structurels et empreintes | PASS : 13 suites (11 suites, 1 172 conditions ; 2 contrôles d’intégrité) ; `validation-statique.json` |
| Captures réelles du moteur | OpenGL Compatibility, llvmpipe logiciel, 1280×600 |
| Sonde GPU du scénario J2.1-C | 1 SKIP en headless |
| Android / APK / S25 Ultra / FPS / RAM / chauffe | **NOT_RUN** |

Dans `preuves/refonte-0.13.3/` : journaux par scénario, `tests-godot.json`, captures, `captures.json`, benchmark local et preuves de déterminisme à deux fronts.

La comparaison de rendu (scène de 100 renforts) donne 1 778 → 137 appels de dessin sous OpenGL logiciel. Elle ne valide ni les FPS ni la consommation Android.

Les résultats de la version précédente sont archivés dans `J13-validation-0.13.2-HISTORIQUE.md`. Les valeurs d’équilibrage restent provisoires. La validation physique Android manque ; la version ne doit pas être qualifiée de stable.
