# Sillons d'Empire 0.2.2 — Lot J2.1-C (graphismes / Android)

## Périmètre livré

Développé **uniquement** à partir de `sillons-empire-j21-ui-tactile-0.2.1-fix1-source-complet.zip`.

- Terrain : quatre textures RGBA procédurales originales, répétables (herbe, sol, sable, roche), l'alpha encodant la rugosité ; un normal map original. Toutes les images sont livrées en PNG 512x512, aucun téléchargement ni asset tiers.
- Matériau du terrain : shader spatial Godot avec mélange PBR, rugosité, normales, macrovariations, berges progressives, sols tassés autour des bâtiments initiaux et **même texture de brouillard de guerre** qu'en J2.
- Eau : variations et petites vaguelettes procédurales avec reflet diffus et atténuation par le brouillard. Pas de réfraction coûteuse ni SSR.
- Végétation : silhouettes d'arbres plus organiques ; herbe et cailloux décoratifs instanciés par `MultiMesh` (deux lots par front), sans collision ni IA. Cache selon visibilité et occupation dynamique des cases. **Ne pas** confondre avec les arbres de récolte, qui restent gérés par la simulation J2.
- Éclairage : palette du ciel plus naturelle, soleil chaud et ombres rapprochées ; banc de deux fronts simplifié pour mesures cohérentes.
- LOD : les décorations légères disparaissent lorsque la caméra s'éloigne au-delà de 46 unités. Ressources, bâtiments, unités et brouillard restent présents.
- Zone témoin : sol utilisant la texture herbe et éclairage mis à jour.

## Points non modifiés

- **Tous les octets de `sim/`** (économie, combat, IA, siège, déterminisme) ; tous les scénarios de simulation.
- `game/hud.gd`, gestes et sélection dans `game/game.gd` inchangés sauf l'ajout du LOD et l'ajustement de la lumière.
- Sauvegardes / règles / unités de combat inchangées.
- Aucun APK généré sans SDK Godot et Android.

## Prérequis et commandes

- Godot 4.4+ (Android ou PC avec rendu Mobile) ; **Godot 4.7.2 est la version cible de validation utilisateur, non testée automatiquement ici**.
- Dézipper dans un répertoire neuf. Importer `sillons/project.godot`, laisser Godot importer les nouveaux `.png`.
- Exécuter depuis le répertoire `sillons` :

```sh
godot --headless --editor --path . --quit
godot --headless --path . -s res://lab/visual_j21c_test.gd
godot --headless --path . -s res://lab/ui_j21_test.gd
```

Puis lancer les tests historiques J2 selon `game-studio/recette.md` et un essai manuel sur le S25 Ultra.

## Recette visuelle Galaxy S25 Ultra

1. À l'ouverture de l'escarmouche, vérifier le sol, l'eau et les berges près des deux gués. Le sol doit être texturé, non noir ou rose, sans erreur de shader.
2. Zoomer progressivement de près à loin : herbes et petites pierres doivent disparaître au-dessus du seuil LOD, mais les gisements / armées restent visibles.
3. Explorer une nouvelle zone puis la perdre de vue : aucune décoration inconnue ne doit être visible à travers le brouillard.
4. Construire un bâtiment : les herbes et pierres doivent disparaître de son emprise à la mise à jour suivante (environ une seconde).
5. Tester un siège à 200 et 400 unités et basculer les deux fronts. Contrôler FPS (moyen et 1 % low), frametime, mémoire vidéo et chaleur. Comparer à la baseline J2 avec même scénario, graine et caméra.
6. Vérifier mini-carte, sélection, ordre de déplacement, menu radial, rotation et zoom à deux doigts ; aucune modification de comportement attendue.

## Budgets cibles indicatifs (non mesurés)

- Viser 60 FPS en escarmouche standard et 30+ FPS en scène lourde sans garantir le résultat ; tester des sessions prolongées pour la chauffe.
- Masque CPU : 96x96 RGBA8 (~36 Kio) par front ; textures PNG 512x512 importées avec mipmaps par Godot ; couleur, rugosité et relief stockés par texture.
- Décor : normalement ~1 000 touffes + ~120 pierres par carte (variable avec la graine et l'occupation), pour deux `MultiMesh` et sans milliers de nœuds individuels.
- Coût GPU terrain : plusieurs lectures de textures et normal mapping ; mesurer obligatoirement les effets à 200/400 unités.

## Désactivation / retour arrière

- Réinstallation sûre : réimporter `sillons-empire-j21-ui-tactile-0.2.1-fix1-source-complet.zip` dans un autre répertoire.
- Les modifications sont confinées à `game/assets.gd`, `game/world_view.gd`, `game/game.gd` (éclairage et LOD uniquement), `game/fronts.gd` (éclairage et LOD), `game/witness.gd`, `project.godot`, nouveaux PNG, nouveaux tests/documentation. Aucun fichier `sim/` modifié.

## Niveau de validation

- Vérification statique et intégrité de l'archive : à renseigner par les outils de préparation.
- Compilation Godot, tests exécutables, APK Android, mesures sur téléphone : **NOT_RUN** tant que les commandes et les essais physiques n'ont pas été réalisés.
