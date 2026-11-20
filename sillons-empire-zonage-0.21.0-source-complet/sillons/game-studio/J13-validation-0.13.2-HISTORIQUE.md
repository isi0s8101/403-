# J13 — État des validations (0.13.2-j13-candidate)

Environnement : Linux x86_64, **Godot 4.7.1.stable.official.a13da4feb**, mode `--headless`, 13 novembre 2026.
Journaux : `game-studio/preuves/j13/`.

## Exécuté réellement

| Contrôle | Résultat |
|---|---|
| Import du projet (`--editor --quit`), aucune erreur de script | PASS |
| `lab/j13_colony_test.gd` (colonie, zonage, services, gouverneur, verrou, transports, trésorerie, migration) | PASS 128/128 |
| `lab/j13_supply_test.gd` (0.13.1 : habitants → troupes, industrie → équipements et bâtiments, IA contre IA) | PASS 22/22 |
| `lab/assets_3d_test.gd` (0.13.2 : import et instanciation des 2 400 GLB de la bibliothèque) | PASS 800/800 |
| `lab/j13_globe_test.gd` (0.13.2 : districts en 3D sur le globe, bon âge, lecture seule) | PASS |
| Capture du globe par Godot en OpenGL logiciel (xvfb), examinée | faite — `preuves/j13/globe-districts-age-x.png` |
| `lab/j13_ui_test.gd` (panneau de colonie dans la vraie scène) | PASS |
| `lab/recette_integrale_test.gd` (recette J1–J8 embarquée) | PASS 202/202 |
| `j9_planet`, `j9_regions`, `strategic`, `j10_systems`, `j10_ui`, `j11_galaxy`, `j11_ui`, `j12_empire`, `j12_perf`, `view_technology`, `age_progression`, `j12_orbital_shipyard` | PASS (12/12) |
| Anciens scénarios `fronts`, `modern`, `modern_ai`, `modern_catalog`, `modern_sandbox`, `modern_ui`, `strategic_ui`, `speed_ui`, `touch`, `ui_j21`, `visual_j21c`, `visual_j21def` | PASS (12/12) |
| 11 contrôles statiques Python + manifeste SHA-256 | PASS |

## État de la 0.12.3 avant correction (même moteur)

Import OK. Sur les 13 scénarios de `verify-j12.sh` : 5 PASS, 8 FAIL (`j9_planet`, `j9_regions`, `strategic`, `recette_integrale` en boucle d'erreur, `j10_systems`, `j11_galaxy`, `j12_empire`, `j12_perf`).

| Cause | Nature | Correction |
|---|---|---|
| Instantané de sauvegarde partagé avec la partie vivante | défaut du jeu | copies profondes dans `SaveGame` et `CampaignSave` |
| Couture +π/−π des hauteurs | défaut du jeu | longitude ramenée par `fposmod` |
| Ordre « défendre » refusé sur un système contesté | défaut du jeu | `StarCampaign.system_held` |
| `TerrainChunkStreamer._height` sans générateur | défaut du jeu | création à la demande |
| `strategic_test` : embarquement sans désigner l'équipage (les 6 premières unités proches partaient) | recette fausse | identifiants passés explicitement |
| `j9_planet_test` : attendait la grille de régions sans la demander | recette fausse | règles de région fournies comme le fait `StarCampaign.create` |
| `j12_perf_test` : 480 images pour remonter 2 paliers qui demandent 6 fenêtres de 2 s | recette fausse | 800 images |

## NON exécuté — bloque toute qualification « stable »

- Export Android / APK : `NOT_RUN` (ni SDK ni modèles d'export dans l'environnement).
- Galaxy S25 Ultra : tactile, lisibilité du panneau, FPS, mémoire, chauffe, reprise après verrouillage : `NOT_RUN`.
- Rendu : une seule capture en OpenGL logiciel (pas le moteur de rendu Mobile, pas de carte graphique) ; aucune mesure de fluidité.
- Parties réelles longues, équilibrage des quatre préréglages R/C/I : `NOT_RUN`.
- Sauvegardes réelles de joueurs J1–J12.3 : seule la migration d'un instantané 0.12.3 fabriqué en recette a été testée.

## Les 8 conditions de « J13 terminé » (cadrage §75)

| # | Condition | État |
|---|---|---|
| 1 | Import/compilation Godot sans erreur | PASS |
| 2 | J1–J12 non régressés | PASS sur les recettes automatiques ; `NOT_RUN` en jeu réel |
| 3 | Monde X → colonie VII, production locale verrouillée | PASS (simulation) |
| 4 | Fret réel et trésorerie sans duplication | PASS (simulation) |
| 5 | R/C/I et services dans une économie qui peut échouer | PASS (simulation), équilibrage `NOT_RUN` |
| 6 | Gouverneur X jusqu'à 100 % du périmètre éligible | PASS en laboratoire à ressources abondantes ; lisibilité 3D non livrée |
| 7 | Verrou orbital, IA comprise | PASS (simulation) ; combat orbital toujours simplifié |
| 8 | Recette et performance Android réelles | `NOT_RUN` |

**Conclusion : J13 n'est pas terminé au sens du cadrage.** Les lots 0, A, B, C, D, E, F sont livrés et vérifiés en simulation ; le lot G (ville 3D, calques, LOD) n'est pas commencé ; le lot H est partiel (pas d'Android).
