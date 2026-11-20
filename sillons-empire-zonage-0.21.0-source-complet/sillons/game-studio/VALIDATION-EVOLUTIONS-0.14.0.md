# Validation 0.14.0 — 14 novembre 2026

**42 scénarios PASS**, dont les **34 scénarios historiques** et **8 nouveaux scénarios**. Moteur Godot 4.7.2 officiel, Linux. Aucun message `SCRIPT ERROR`, `ERROR:` ou `FAIL` dans les journaux retenus. Le test GPU historique de lecture du framebuffer reste explicitement SKIP en headless. Trois nouvelles captures OpenGL réelles ont été inspectées ; elles ne remplacent pas une recette appareil.

| Lot | Preuve exécutée | Portée |
|---|---|---|
| Ralliement R01–R04 | `evolution_rally_test` | Ordre à la création, ancienne destination conservée, eau/NaN refusés, groupe atomique, ouvriers autonomes, sauvegarde et continuation identiques |
| Plans R05–R06 | `evolution_rally_test`, `evolution_logistics_test` | Deux producteurs, cible bornée, vagues, ordres successifs, cible perdue, vrais vaisseaux, un seul débarquement et stock porté conservé |
| Factions F01 | `evolution_politics_test`, `evolution_diplomacy_test` | Neutralité, guerres distinctes, identité d'une commune conservée, deux sécessions simultanées distinctes |
| Départ M01–M02 | `evolution_campaign_test`, `evolution_progression_test` | Deux systèmes, deux départs I, connaissances propres, progression des deux IA vers IV sans découverte interdite (8 653 ticks, une graine) |
| Carte M03–M05 | Tests J9 conservés, `evolution_campaign_test`, `evolution_ui_test` | Franchissement historique des régions, carte 256, rendu par secteurs 32, cache de 16, simulation indépendante de la vue et brouillard compact égal à la référence dense |
| Rendement P01–P02 | `evolution_politics_test` | Besoins adaptés, bornes du coefficient, extraction conservatrice et recettes proportionnelles |
| Crises P03–P08 | `evolution_politics_test` | Tolérance, ultimatum, contre-offre, stabilisation, stocks, population, allégeances, réserves et reprise d'une sécession |
| Reconquête P09–P10 | `evolution_diplomacy_test`, `evolution_politics_test` | Verrou orbital, trêve sans accès, aide réservée puis livrée une fois, autonomie, réunification différée, occupation après maintien terrestre |
| Hors écran P11 | `evolution_campaign_test` | État des mondes et de l'économie identique avec deux caméras actives différentes |
| Sauvegardes S01–S02 | Nouveaux tests + suites historiques J13 | V1 conservé, V2 déterministe, SHA, remplacement atomique, backup, stocks négatifs et positions non finies refusés |
| Interface U01 | `evolution_ui_test`, tests tactiles historiques | Conseil ouvert par toucher simulé, entrée politique, aménagement préspatial, atlas, retour, blocage du terrain et drapeau visible |
| Progression D01–D02 | 10 âges historiques et nouveaux départs | Dix âges et colonies VII conservés ; nouvelle IA I → IV vérifiée. Nouvelle campagne autonome complète I → X : non certifiée |
| Android A01–A02 | Aucun appareil disponible | **NOT_RUN** : FPS matériels, mémoire maximale, charge thermique, tactile réel, Vulkan et APK |

Les tests de crise utilisent des états initiaux contrôlés pour rendre les pénuries et sécessions reproductibles. Les dotations de ces fixtures ne sont pas appliquées aux nouvelles parties. Le banc de performance mesure des débuts de partie, pas une limite maximale d'unités.

## Mesures CPU de référence

Trois mondes simulés, deux IA, 500 ticks par profil, sans rendu. Le p95 est le temps sous lequel se trouvent 95 % des ticks mesurés. Le CPU est partagé ; ces chiffres ne sont pas une promesse de FPS Android.

| Profil | Création (ms) | Tick médian (ms) | Tick p95 (ms) | Tick max (ms) | Mémoire statique Godot (MiB) |
|---|---:|---:|---:|---:|---:|
| 96 | 40.7 | 0.70 | 4.65 | 10.68 | 51.3 |
| 256 | 390.0 | 0.55 | 5.15 | 24.68 | 86.1 |
| 512 | 1473.5 | 0.59 | 8.34 | 57.91 | 224.6 |

Le profil principal reste 256. Le profil 512 existe pour les expériences de simulation ; sa mémoire et son rendu doivent être validés sur la cible avant toute activation par défaut.

## Reproduire

Depuis `sillons` :

```bash
GODOT_BIN=/chemin/vers/godot bash tools/verify-refonte.sh
```

La commande importe le projet, exécute les 42 scénarios et contrôle le chargement autonome des deux paquets natifs. Les preuves incluent les sorties individuelles, les données de performance et les captures.
