# Résultats 0.15.1 R2

## Validation effective

- 50/50 scénarios source Godot : PASS, Linux headless.
- Signature, manifeste et lanceur Android : PASS.
- Alignement ZIP et segments ELF : 16 Ko vérifiés.
- 1 592 entrées hors manifeste/signature inchangées par la normalisation AXML.
- Deux bibliothèques graphiques embarquées : contenu identique aux paquets source.
- Trois parcours des ressources compilées extraites de l’APK : PASS sous Linux.
- Aucun appareil ADB connecté : Android natif, démarrage S25, tactile, FPS, mémoire et chauffe non mesurés.

## Campagne complète — CPU sans rendu

500 ticks par scénario ; graine 15101 ; un processus de benchmark, sans autre scénario Godot concurrent. Les trois cartes font 256 × 256 cases.

| Charge | Effectif initial | Tick p50 | Tick p95 | Tick maximum | RSS observée après scénario |
|---|---:|---:|---:|---:|---:|
| Grande carte | 12 unités | 0.340 ms | 2.430 ms | 19.354 ms | 174.1 MiB |
| Trois fronts | 372 unités | 8.863 ms | 31.213 ms | 50.951 ms | 204.8 MiB |
| Batailles orbitales | 120 vaisseaux | 1.741 ms | 4.383 ms | 33.277 ms | 205.0 MiB |

Cette RSS concerne le benchmark sans scène graphique ; elle n’est ni la consommation de l’application complète ni la PSS Android. Les scénarios se succèdent dans le même processus : l’allocateur peut conserver des réserves. Les effectifs diminuent pendant les combats ; le JSON fournit début, fin et les 100 premiers ticks. Les pointes de trois fronts empêchent de conclure à une fluidité garantie.

## Protocole historique des dimensions

Trois mondes, 500 ticks par dimension, graine 14040, sans rendu. Mémoire statique Godot uniquement.

| Dimension | Initialisation CPU | Tick p95 | Tick max | Mémoire statique Godot |
|---|---:|---:|---:|---:|
| 96 × 96 | 27.063 ms | 2.764 ms | 13.485 ms | 51.8 MiB |
| 256 × 256 | 187.452 ms | 3.312 ms | 24.760 ms | 86.5 MiB |
| 512 × 512 | 883.435 ms | 6.065 ms | 85.620 ms | 225.1 MiB |

Le profil 512 reste expérimental, 256 reste le profil de campagne par défaut. Les graines et scénarios diffèrent : ne pas comparer ces nombres comme des répétitions du même test.

## Calcul orbital isolé

Trois orbites, 120 vaisseaux, 150 ticks : p50 3.203 ms, p95 4.655 ms, maximum 7.605 ms. Cette mesure porte sur OrbitalTactics.step, sans rendu ni campagne complète.

## Rendu et téléphone

La capture du panneau de diagnostic est produite à 1280 × 600 avec OpenGL Compatibility / Mesa llvmpipe logiciel. Elle contrôle la disposition de l’interface, pas les performances du GPU mobile Vulkan.

La recette embarquée enregistre les intervalles réels d’images, les temps bruts des ticks, la résolution adaptative et la RSS si accessible. La préparation du rendu et les interruptions sont distinguées. Le script ADB ajoute les métriques mémoire et thermiques exposées par le téléphone. Température batterie et températures CPU/GPU ne sont pas confondues. Les valeurs inconnues restent null.

Voir le guide racine pour les séries de 60 secondes puis dix minutes. Les mesures Linux ne sont pas des prédictions de FPS Android.

## APK

Fichier : `sillons-empire-test-0.15.1-r2-arm64.apk`

Paquet : `fr.sillons.empire.recette.r2` ; versionCode 151 ; 134881056 octets.

SHA-256 : `ad0afdc249864bd7313f4d520a6f87240443ba945db2b1a59056ec5da9dd9613`
