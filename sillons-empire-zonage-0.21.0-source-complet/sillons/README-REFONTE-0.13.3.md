> Historique de la refonte 0.13.3. La version courante est 0.13.4 ; voir `../README-IMPORT-ANDROID-0.13.4.md`. Les sources 3D sont désormais à côté du projet.

# Refonte 0.13.3 — présentation, commandes et coût du rendu

Statut : **candidate**, session du 13 novembre 2026. Base : `sillons-empire-j13-colonies-0.13.2-source-complet.zip`, SHA-256 `69c4669b14e2b1d4f87580eaac4c6cfd57d3a7cd378df6c40a2ef657753a0ea8`.

## Lancer et essayer

1. Extraire l’archive complète dans un nouveau dossier. Conserver la 0.13.2.
2. Dans Godot **4.7.1**, importer `sillons/project.godot` puis attendre le premier import des GLB.
3. Lancer le projet : le menu propose l’escarmouche, la reprise et une nouvelle planète. Le laboratoire reste accessible séparément.
4. Commencer en profil **Équilibré**, puis comparer les autres profils dans le menu de pause. L’adaptation automatique peut être désactivée.

La construction et les déblocages continuent d’exiger l’âge et les ressources locaux. L’export Android n’a pas été réalisé dans cette session.

## Commandes

| Geste ou bouton | Résultat |
|---|---|
| Toucher une unité | Sélectionner son escouade ; un second toucher isole l’unité |
| Toucher le sol avec une sélection | Donner un ordre de déplacement |
| Toucher un ennemi | Donner un ordre d’attaque |
| Glisser | Déplacer la caméra, avec inertie amortie |
| Deux doigts | Zoomer et tourner |
| Choisir, puis glisser | Sélection rectangulaire |
| Appui long | Ordres contextuels |
| Icône maison | Recentrer sur le commandement |
| Retour Android / Échap | Fermer le panneau actif, remonter au menu parent, puis reprendre |
| Bâtir | Catalogue des bâtiments, placement puis validation explicite |

Une annulation du toucher, un relâchement sur l’interface ou une perte du focus remet les gestes à zéro. Les menus modaux bloquent les commandes situées derrière eux.

## Présentation

- Charte graphite et accent doré ; contraste stable ; icônes SVG originales ; boutons de jeu de 48–52 unités d’interface.
- Menu principal recentré sur le jeu. Scénarios, démonstrations et bancs d’essai sont conservés dans le laboratoire.
- Le panneau de colonie est réparti entre **État**, **Zones**, **Services** et **Gestion**. Son contenu défile dans les limites de l’écran.
- Marquages R/C/I combinant couleur et forme : triangle habitat, carré commerce, hexagone industrie.
- Calques électricité, eau, hôpital, pompiers et police. Les calques reprennent les résultats réels du moteur de services ; le gris signifie qu’un district n’est pas un logement à couvrir pour les secours.
- Globe : couleur de surface 512×256 générée par étapes ; géométrie des bandes regroupée après génération ; cache de trois planètes.
- Matériaux de terrain originaux 512 px, éclairage et exposition ajustés. L’eau reste une représentation opaque à faible coût, sans réfraction.
- Le brouillard de guerre conserve la confidentialité de la carte. Une zone inconnue reste sombre.

## Rendu et performances

| Mécanisme | Fonctionnement |
|---|---|
| Modèles proches | Bibliothèque GLB, matériaux partagés, animations des personnages |
| Unités éloignées | Pose statique, géométrie fusionnée ; regroupement GPU par modèle, camp et région de 16×16 cases |
| Visibilité | Seules les unités connues du camp alimentent les lots ; limites régionales pour le culling |
| Caches | 64 scènes et 64 maillages compacts par bibliothèque ; caches des lots également bornés |
| Animation | Plafond de personnages détaillés, marche liée à la vitesse ; animation immobilisée à la pause |
| Profils | Résolution 3D 0,72 / 0,88 / 1,00 ; interface conservée à sa résolution ; adaptation progressive sous surcharge |
| Ombres | Distance et activation réglées selon le profil et la charge ; rendu à deux cascades |
| Terrain | Calcul du masque de berges par deux balayages, au lieu d’un voisinage 9×9 pour chaque case |
| Cadence | Cible de rendu 60 FPS ; simulation à pas fixe conservée |

**Mesure de laboratoire**, même graine 4242, âge I, caméra à 56, 100 renforts, 112 unités simulées, profil détaillé, 1280×600, Godot 4.7.1 / OpenGL Compatibility / llvmpipe :

| Mesure de rendu | 0.13.2 | 0.13.3 |
|---|---:|---:|
| Appels de dessin | 1 778 | 137 |
| Primitives déclarées par le moteur | 324 280 | 274 568 |

Réduction des appels de dessin de **92,29 % dans cette scène**. Les 106 unités éloignées sont réunies en 4 lots régionaux. Il ne s’agit pas d’un gain mesuré de FPS, de consommation ou de chauffe sur Android. Les mesures et captures sources se trouvent dans `game-studio/preuves/refonte-0.13.3/benchmark.json`.

## Vérifier

Contexte : utilisateur standard, Bash + Python 3 + Godot 4.7.1, depuis le dossier du projet Godot. Aucune installation système requise par les scripts de contrôle.

```bash
python3 -I tools/verify-refonte-static.py
GODOT_BIN=/chemin/vers/godot bash tools/verify-refonte.sh
```

Résultat attendu : `REFONTE_GODOT=PASS scenarios=32 ; ANDROID=NOT_RUN`.
Les recettes enregistrent leurs données temporaires sous `user://`, sans modifier les preuves ni le manifeste du paquet. Les contrôles statiques ne remplacent pas l’exécution du moteur.

Reproduire les nouvelles textures, si nécessaire seulement :

```bash
python3 tools/generate-presentation-textures.py
```

Cette opération utilise NumPy et Pillow sur le poste de génération ; ces bibliothèques ne sont pas nécessaires dans le jeu. Les textures et tous les GLB nécessaires sont déjà inclus. La chaîne historique `assets_pipeline/` de production des 800 modèles n’était pas fournie dans l’archive 0.13.2.

## Vérifications effectuées et limites

- Import et chargements sous Godot 4.7.1 ; **32 scénarios hors rendu PASS**, dont les scénarios historiques J1–J13 et les nouveaux contrôles visuels et tactiles.
- Recette de refonte : **140/140** ; interaction avec les panneaux modaux : **4/4**.
- Catalogue : **800 modèles / 2 400 fichiers de LOD**, contrôlés par le moteur et par leurs empreintes.
- Simulation : les 32 fichiers de `sim/` sont inchangés par rapport à la source fournie.
- Captures du moteur sous OpenGL logiciel, examinées : menu, terrain I/V/X, globe I/V/X, sélection, construction, pause, armée et rivière. Le globe I est une fixture visuelle ; il reste verrouillé en partie avant l’âge II et la technologie requise.
- Le scénario visuel J2.1-C conserve une sonde `SKIP` en mode headless ; cela ne constitue pas une validation du GPU Android.

**Non exécuté :** rendu Mobile/Vulkan sur appareil, export APK, recette tactile physique sur Galaxy S25 Ultra, FPS/p95, RAM, chauffe, autonomie, reprise après verrouillage et équilibrage en parties longues.

**Qualité artistique restante :** les formes procédurales de nombreux personnages, arbres et bâtiments sont encore low-poly. Le pack n’est pas devenu photoréaliste. Les 42 entrées `needs_work` et les 220 entrées `not_reviewed` du catalogue restent dans leur état déclaré. Pas de nouvelle animation mécanique complète pour tous les véhicules ; les combats orbitaux restent simplifiés. Les limites métier du J13 ne sont pas effacées par cette refonte (dont le remboursement incomplet des habitants et équipements à l’annulation d’une formation).

## Recette S25 Ultra à réaliser

| Essai | À contrôler |
|---|---|
| Paysage, encoche, gestes système | Aucun bouton masqué ; retour ferme le panneau attendu |
| Déplacement, zoom, rotation, relâchement sur UI | Aucun ordre parasite ni doigt bloqué |
| 50, 100 puis 400 unités visibles | FPS et temps d’image p95, lecture des silhouettes, absence de disparition aux limites des lots |
| Profils et adaptation automatique | Différence de netteté 3D, lisibilité intacte de l’interface, stabilité des ombres |
| 15–30 minutes de partie | RAM, chauffe, autonomie, sauvegarde/reprise et navigation entre les vues |

Pour revenir en arrière, rouvrir la 0.13.2 avec une copie de sauvegarde conservée avant les essais. Aucun changement de schéma de sauvegarde n’est introduit ici.

## Sources techniques

- [Godot : optimisation avec MultiMesh](https://docs.godotengine.org/en/stable/tutorials/performance/using_multimesh.html)
- [Godot : Viewport et échelle du rendu 3D](https://docs.godotengine.org/en/stable/classes/class_viewport.html)
- [Godot : optimisation 3D](https://docs.godotengine.org/en/stable/tutorials/performance/optimizing_3d_performance.html)
