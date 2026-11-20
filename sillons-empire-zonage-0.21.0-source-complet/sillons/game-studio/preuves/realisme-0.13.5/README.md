# Preuves actuelles — réalisme 0.13.5

`tests-godot.json` regroupe les 34 scénarios. Les quatre recettes de présentation ont été rejouées après les derniers ajustements ; leurs journaux finaux remplacent les passages initiaux. Le test hérité J2.1-C vérifie désormais les textures 1K ; sa sonde de readback GPU reste SKIP en mode sans écran.

`native-models.json` correspond aux 57 scènes effectivement livrées. `native-pack.log` et `blender-build.log` retracent leur préparation. `builder-tool-test.log` valide séparément le wrapper de reconstruction dans un dossier temporaire ; ce paquet de contrôle n’est pas livré.

`cold-import.*` provient d’un projet neuf sans cache : 0 GLB sous la racine jouable, 39 images/icônes importées. Temps et mémoire sont Linux, pas Android. `packaged-runtime.log` teste les deux paquets natifs contenus dans un paquet de jeu autonome, sans sources ni cache de développement.

Les six PNG actuels et `captures.json` proviennent du vrai moteur Godot 4.7.2 sous OpenGL Compatibility / Mesa llvmpipe, en 1280×600. Les scènes d’inspection industrielle/futuriste, le globe développé et l’armée de charge sont des fixtures documentées ; elles ne changent pas la dotation des parties normales.

`avant-0.13.4.png` est une capture historique de comparaison, pas une preuve de la nouvelle version. Les preuves des versions voisines sont elles aussi historiques. Aucun fichier ne constitue une recette téléphone ou un export APK.
