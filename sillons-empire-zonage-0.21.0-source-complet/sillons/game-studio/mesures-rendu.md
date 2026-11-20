# Zone témoin — conditions et mesures de rendu

Accès : menu > « Zone témoin ». Contenu : centre, maison, caserne, marché, ferme, relais, 12 unités des deux camps
(lanciers, tireurs, cavalier, éclaireur, ouvriers, caravane), 10 arbres, au zoom de jeu par défaut (distance 24).

Réglages comparables en direct : ombres oui/non, échelle 3D 1,0 / 0,75 / 0,5, MSAA non/2x/4x, densité x1 à xN
(duplique la scène), zoom. « Mesurer 10 s » enregistre : appareil, OS, GPU, rendu, résolution, durée, nombre d'images,
temps d'image moyen et p95, FPS moyen, appels de dessin, primitives, VRAM, mémoire statique et réglages, dans
`user://mesures/temoin_<date>.json` (le chemin complet est affiché).

| Mesure | Conditions | Résultat |
|---|---|---|
| S25 Ultra, réglages par défaut | ombres oui, échelle 1,0, MSAA 2x, densité x1 | NOT_RUN |
| S25 Ultra, sans ombres | | NOT_RUN |
| S25 Ultra, échelle 0,75 | | NOT_RUN |
| S25 Ultra, densité x4 | | NOT_RUN |

Lisibilité au zoom de jeu (capture `preuves/captures/04-zone-temoin.png`, rendu Mobile logiciel) : rôles distincts
par silhouette (lance haute et bouclier, arme d'épaule et chapeau, cheval, chariot, outil et charge),
couleur de camp sur le torse et les bannières. Les modèles restent des primitives stylisées (réserve P-01 / D-12).

Les budgets chiffrés (FPS, ms/image, mémoire, chauffe) seront proposés après ces premières mesures physiques.

---

# Essai technique « deux fronts » (J2) — conditions et mesures

Accès : menu > « Test technique : deux fronts (mesures) ». Lancement automatique possible :
`godot -- --fronts-auto [--fronts-sec=40] [--fronts-quit]`.

**Conditions** : deux simulations complètes et indépendantes au pas fixe de 10 ticks/s, avancées dans le même ordre à
chaque tick. Front A « siège du gué sud-est » (graine 3101) : fort + ligne de palissades + lanciers/tireurs (IA défensive)
contre canons, lanciers et cavaliers (IA d'assaut). Front B « bataille du gué nord-ouest » (graine 3202) : deux armées IA
(lanciers, tireurs, cavaliers). Niveaux : 40 / 100 / 200 / 400 unités **par front** au départ (ouvriers et éclaireurs
compris), soit jusqu'à 800 unités simulées. Une seule carte est attachée au rendu ; l'autre continue sans vue.
Caméra fixe au-dessus du front affiché (distance 34), ombres directionnelles 2 cascades, rendu Mobile.

**Protocole automatique** : pour chaque niveau, 40 s de jeu, bascule de front à 10, 20 et 30 s. Échantillon chaque seconde :
unités par front, siège en cours (canon en batterie ou en tir), simulation moyenne et pic par front (ms/tick), ticks
perdus (rattrapage limité à 3 ticks par image), rendu CPU et GPU moyen/pic (`viewport_get_measured_render_time_*`),
images/s, pire image, appels de dessin, mémoire statique et vidéo, température si lisible, bascule. Résumé par niveau
avec pics pendant le siège (`front0_sim_ms_pic_siege`) et lors des bascules (`image_ms_pic_bascule`, `bascules[].cpu_ms`).
Fichier : `user://mesures/deux_fronts_<date>.json` (Android : `/sdcard/Android/data/fr.sillons.empire.j1/files/mesures/`).

## Référence conteneur (sans GPU, sans rendu : simulation seulement, non représentative du S25 Ultra)

`preuves/deux_fronts/reference_conteneur_headless.json` — Xeon 2,1 GHz, 4 cœurs, Godot sans rendu.

| Unités / front (départ) | Sim. front A moy. / pic (ms) | Pic pendant siège | Sim. front B moy. / pic (ms) | Bascule (ms CPU) | Mémoire statique (Mo) |
|---|---|---|---|---|---|
| 40 | 2,9 / 29,1 | — | 1,3 / 6,0 | 2,8 à 5,5 | 38 |
| 100 | 6,5 / 51,6 | 51,6 | 2,5 / 12,2 | 8 à 19 | 43 |
| 200 | 12,8 / 71,7 | 71,7 | 5,3 / 26,0 | 10 à 29 | 51 |
| 400 | 26,4 / 84,6 | 84,6 | 14,1 / 45,1 | 29 à 64 | 70 |

Budget à 10 ticks/s : 100 ms par tick pour les deux fronts **et** le rendu. Aucun tick perdu sur le conteneur.

## S25 Ultra

| Niveau | Sim. A / B moy. (ms) | Pics siège / bascule | Rendu CPU / GPU (ms) | i/s moy. / min | Mémoire | Chauffe (1-5) | Statut |
|---|---|---|---|---|---|---|---|
| 40 | | | | | | | NOT_RUN |
| 100 | | | | | | | NOT_RUN |
| 200 | | | | | | | NOT_RUN |
| 400 | | | | | | | NOT_RUN |

**Limite observée et budgets de référence** : à établir avec ces mesures. Proposition de méthode : le niveau limite est
le plus haut niveau où (a) aucun tick n'est perdu, (b) les i/s restent ≥ 30 hors bascule, (c) le pic de bascule reste
< 100 ms, (d) la chauffe reste ≤ 3/5 après deux protocoles d'affilée. Le budget de référence des jalons suivants sera
fixé à ce niveau moins 25 % de marge.
