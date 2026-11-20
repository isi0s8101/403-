# Sillons d'Empire — J9 0.9.0 — candidate technique

**Base :** version J1–J8 `0.8.2-correctifs`, conservée pour comparaison. **État :** source candidate non compilée et non validée sur Android. **Moteur :** Godot 4.x, projet original réglé pour 4.7 Mobile.

## Livré dans ce jalon

1. **J9-A — Monde reproductible :** `procgen/planet_generator.gd` calcule un relief sphérique déterministe, eau, climat, humidité, 7 biomes et couleurs. Échantillonnage à la demande, coordonnées lat/lon, aucune allocation d'une carte géante dans la mémoire.
2. **J9-B — Terrain tactique à chunks :** `streaming/terrain_chunk_streamer.gd` remplace le maillage monolithique pour **les nouvelles parties J9 uniquement**. Chunks 24×24 dans la grille tactique de 96×96, LOD 1/2/4, 2 constructions de maillage par frame, cache plafonné à 16 chunks. Les hauteurs sur les frontières utilisent des coordonnées globales communes. La simulation, le pathfinding, les ordres et les unités historiques restent inchangés.
3. **J9-C — Globe et zoom :** globe 3D procédural avec relief, biomes, atmosphère et marqueur de région ; rendu progressif par latitude. En partie, dézoomer au maximum ouvre le globe ; retour par bouton et écartement de deux doigts. Les unités continuent d'être simulées en vue globe.
4. **J9-D — Région jouable procédurale :** dans le menu, choisir « J9 · Nouvelle planète procédurale », tourner le globe, toucher une région émergée puis « Jouer ici ». Le RTS historique entier démarre sur un terrain tactique variant avec la région et la graine. Démarrage sur l'océan refusé. Cartographie symétrique héritée pour préserver l'équilibre des deux camps.
5. **J9-E — Sauvegarde isolée :** `user://sillons-j9-planet.save`, option de reprise séparée des fichiers `sillons-j678.save`. Sauvegarde de la seed, des coordonnées et des modifications du théâtre tactique via le schéma précédent.
6. **J9-F — Recette :** `lab/j9_planet_test.gd`, `tools/verify-j9.sh`, contrôles statiques. L'export APK est conditionnel à une vraie compilation Godot.

## Périmètre non livré / à développer avant de valider J9 complet

- Une planète **entièrement jouable et traversable** au-delà des 96×96 cellules : l'atlas J9 représente un globe immense, mais seul le secteur tactique choisi est actuellement instancié et jouable.
- Les transferts physiques entre régions, la conservation des unités lors de la traversée des limites, le streaming de la **simulation** et le cache persistant des régions distantes.
- Alignement géométrique exact entre océans, chaînes de montagnes et terrain tactique (le prototype respecte les classes de biome et quelques variations, mais pas une heightmap globale continue par région).
- Tests de 1 000 graines **exécutés sous Godot**, benchmarks sur Galaxy S25 Ultra, import/compilation et APK Android.

## Utilisation

**Nouveau jeu :** menu > « J9 · Nouvelle planète procédurale » > toucher une terre > « Jouer ici ». Dézoom maximal de la caméra dans le jeu pour afficher la planète. Le bouton « Retour au terrain tactique » ramène à l'escarmouche. La vitesse ×0,5 / ×1 / ×2 / ×4 / ×8 et le panneau Secteurs restent disponibles en tactique.

**Lancer les tests sur PC Linux :** dans `sillons/`, `./tools/verify-j9.sh`. Le code `127` signifie que Godot est absent : aucun PASS runtime ne doit être annoncé.

**Exporter Android :** avec Android SDK, JDK et template d'export Android Godot installés, `./tools/export-android-j9.sh`. Le script **ne promet pas** de générer un APK si l'export échoue.

**Validation Galaxy S25 Ultra :** nouvelle campagne J9, emplacement initial, déplacement/attaque/récolte/construction, zoom jusqu'au globe, rotation et picking, retour par bouton puis pincement, reprise de sauvegarde, transition vers J6–J8 après montée d'âge ; noter FPS/mémoire sur ×1 / ×4 / ×8, absence de gel lors du streaming et cohérence des chunks. Les tests visuels/ergonomiques doivent être validés par l'utilisateur sur l'APK.

**Rollback :** réinstaller l'archive 0.8.2. Les anciennes sauvegardes `user://sillons-j678.save` restent indépendantes et ne sont pas écrasées par les parties J9 ; ne pas essayer d'ouvrir la sauvegarde J9 avec une ancienne version sans copie.
