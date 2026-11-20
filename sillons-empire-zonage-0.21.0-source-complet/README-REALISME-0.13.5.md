# Refonte du rendu — 0.13.5

## Ouvrir sur Android

1. Fermer Godot.
2. Extraire **l’archive complète dans un nouveau dossier**, en conservant l’ancienne version.
3. Importer **`sillons/project.godot`** dans Godot **4.7.2**.
4. Laisser terminer l’import des images puis lancer le jeu. Vérifier **0.13.5** dans le menu.

Ne pas déplacer `sources-3d/` ou `art-source/` à l’intérieur de `sillons/`. Les modèles utilisés en jeu sont déjà préparés dans `data/assets_3d.pck` et `data/realism_models.pck`. Aucune conversion Blender ou GLB n’est nécessaire sur le téléphone.

Les fichiers `.jpg.import` du nouveau dossier de textures sont volontairement livrés : ils fixent la génération des mipmaps et l’import portable. Les fichiers de cache `.godot/` restent exclus. Les anciens imports automatiques sans réglage artistique ne sont pas ajoutés au ZIP.

## Changements visibles

### Architecture

44 nouveaux modèles répartis entre centre, maison, caserne, entrepôt, atelier, marché, usine, académie, dépôt, fort et palissade. Quatre styles visuels correspondent aux âges I–II, III–V, VI–VIII et IX–X. Les familles ne constituent pas toutes de nouveaux types de gameplay : il s’agit de remplacements visuels de producteurs existants, avec leurs emprises et prérequis conservés.

Les façades, fenêtres, portes, encadrements, poutres, fondations, couvertures, cheminées et équipements sont modélisés. Les matériaux photographiques sont partagés. Les panneaux solaires du jeu de modèles sont réservés au style futur ; les bâtiments industriels conservent un vocabulaire de maçonnerie et de toiture adapté.

Les autres familles gardent les modèles hérités. Leurs matériaux physiques compatibles peuvent recevoir les nouvelles textures ; leurs identités, émissions et marquages de camp restent préservés.

### Personnages et environnement

Six figures articulées originales : ouvrier, colon, lancier, tireur, fusilier et grenadier. Proportions, visage, mains, bottes, vêtements et équipements ont une géométrie plus détaillée. Les quatre clips `idle`, `walk`, `work`, `attack` sont conservés dans le chargement natif. Les animations restent pilotées par les états et la vitesse de la simulation.

Les représentations lointaines et les lots régionaux restent disponibles. Les personnages proches sont limités par le profil graphique existant. Les autres types d’unités, notamment plusieurs véhicules et unités montées, restent hérités ; cette livraison ne prétend pas avoir reconstruit les 800 modèles.

Trois arbres aux branches et feuilles individuelles, un arbuste à baies, trois rochers irréguliers et des touffes d’herbe remplacent les volumes les plus simples. Le vent est cosmétique. Les ressources inconnues ne sont pas envoyées au rendu et le masque de brouillard reste appliqué au feuillage.

### Matériaux, terrain, eau et globe

Neuf ensembles PBR 1K, soit 27 images : sol herbeux, terre, sol forestier, pierre, écorce, bois, maçonnerie, toiture et sable. Les références exactes sont dans `sillons/game/realism/texture-sources.json` ; certains jeux servent de référence ou de réserve artistique. Leurs noms décrivent leur usage dans le projet, pas une garantie de rendu photoréaliste à toute échelle.

Le terrain utilise un mélange de couches, des normales et des cartes d’occlusion/rugosité, des zones de passage et une occlusion de contact analytique. Ce dernier effet n’est pas du SSAO ou du ray tracing. L’eau opaque utilise les normales animées, la couleur de profondeur et les reflets de l’environnement ; elle ne simule pas une réfraction écran complète.

Le globe reçoit une texture procédurale 1024 × 512 calculée progressivement et conservée dans un cache borné, une différenciation optique terre/océan, une couche nuageuse et une atmosphère. Sa géographie reste celle du générateur ; aucun relevé réel de planète n’a été substitué aux données de jeu.

## Réglages et coût

Le renderer Mobile est conservé. Les nouveaux effets n’exigent pas SSAO, SSR, brouillard volumétrique ou GI temps réel de Forward+. Les profils Économie/Équilibré/Détaillé et le gouverneur de qualité restent disponibles.

Les nouveaux détails augmentent la géométrie de proximité. La compaction des ressources cachées évite de soumettre tous les arbres inconnus aux passes de rendu et d’ombre. Aucun gain de FPS Android n’est revendiqué. Les limites réelles seront fixées par la recette sur le téléphone.

## Sources et reconstruction sur ordinateur

- `art-source/blender/build_realism.py` : géométrie originale, Blender 4.3.2 utilisé pour cette livraison.
- `art-source/models/` : les 57 GLB sources et le catalogue de géométrie.
- `sources-3d/` : bibliothèque 3D historique complète, préservée.
- `sillons/tools/prepare-realism.gd` et `compile-realism.py` : préparation native avec Godot 4.7.2.
- `sillons/game/realism/` : matériaux, shaders et sources des textures.

Depuis la racine de l’archive, pour régénérer la géométrie sur un ordinateur équipé de Blender :

```bash
blender -b --factory-startup --python art-source/blender/build_realism.py -- "$PWD/art-source/models"
cd sillons
python3 tools/compile-realism.py --godot /chemin/vers/godot --replace
```

Le second outil importe les GLB dans un projet temporaire, prépare des scènes autonomes et sauvegarde le paquet existant avant remplacement. Les textures sont déjà incluses ; aucun accès réseau n’est requis pour jouer ou reconstruire les modèles.

Après modification, régénérer les manifestes de livraison. Les identifiants internes de ressources Godot peuvent faire varier les octets d’une régénération ; les empreintes vérifiées portent sur le paquet effectivement livré.

Recette :

```bash
GODOT_BIN=/chemin/vers/godot bash tools/verify-refonte.sh
```

## Preuves et retour arrière

Les journaux actuels et six captures sont dans `sillons/game-studio/preuves/realisme-0.13.5/`. Les séries 0.13.3 et 0.13.4 sont conservées comme historiques. Les scènes d’inspection de bâtiments et de charge sont des fixtures de laboratoire ; elles ne donnent pas ces bâtiments ni leurs ressources aux parties normales.

Pour revenir en arrière, rouvrir la 0.13.4 conservée dans son dossier et utiliser sa copie de sauvegarde. Ne pas supprimer les anciennes sources ou les sauvegardes pour installer cette version.

Le démarrage et les performances Android restent à vérifier. Aucun APK n’a été produit par cette livraison.
