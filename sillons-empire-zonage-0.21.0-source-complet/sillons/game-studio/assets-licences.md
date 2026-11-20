> Ajout 0.13.5 : consulter `../../LICENCES-REALISME.md` pour les textures photographiques CC0 et leurs empreintes. Les mentions historiques ci-dessous restent conservées.

# Sources d'assets et licences

| Élément | Source | Licence | Statut |
|---|---|---|---|
| Modèles 3D (unités, bâtiments, arbres, roches) | Générés par code (`game/assets.gd`) à partir de primitives Godot | Propriété du projet | PROVISOIRE |
| Terrain, eau | Maillage et shaders écrits pour le projet (`assets.gd`, `world_view.gd`) | Propriété du projet | PROVISOIRE |
| Textures | Bruit procédural Godot (`NoiseTexture2D`) généré à l'exécution | — | PROVISOIRE |
| Icône | `icon.svg` dessinée pour le projet | Propriété du projet | PROVISOIRE |
| Police | Police par défaut intégrée à Godot | MIT / OFL selon Godot | — |
| Moteur | Godot 4.4.1 | MIT | — |

Aucun nom, élément graphique, carte ou contenu n'est repris d'un jeu existant. La référence au genre et au rythme
(prompt maître) ne se traduit par aucun emprunt d'identité.


## Textures J2.1-C (0.2.2)
`game/textures/{grass,soil,sand,rock}_pbr.png` et `terrain_normal.png` ont été générées intégralement pour ce projet par `tools/generate_j21c_textures.py` (synthèse procédurale, sans source ni élément tiers). Aucune nouvelle licence externe ni attribution obligatoire introduite. Dépendances NumPy, SciPy et Pillow requises uniquement pour regénérer ces PNG sur une station de développement ; elles ne sont pas requises à l'exécution du projet Godot ni dans l'APK.

## Lot 0.2.3 J2.1-D/E/F
Les personnages articulés (`game/unit_visual.gd`), les détails de bâtiments et dégâts (`game/building_visual.gd`) et les animations/effets de `game/world_view.gd` sont créés procéduralement pour ce projet à partir de primitives Godot, sans modèle, texture, police ou bibliothèque tierce ajoutée dans ce lot.

## Lot 0.17.0 — Interface « grand RTS » et thèmes par âge
**Polices intégrées** (`interface/fonts/`, fichiers originaux non modifiés, licence jointe à côté de chaque famille) :
- **Fira Sans** Regular, SemiBold, Light — © 2012-2015 The Mozilla Foundation et Telefonica S.A. — SIL Open Font License 1.1 (`OFL-FiraSans.txt`). Texte courant de tous les âges, titres des âges VIII à X.
- **Cardo** Bold — © 2002-2011 David J. Perry — SIL Open Font License 1.1 (`OFL-Cardo.txt`). Titres et boutons des âges I à V.
- **Anonymous Pro** Bold — © 2009 Mark Simonson, nom de police réservé « Anonymous Pro » — SIL Open Font License 1.1 (`OFL-AnonymousPro.txt`). Titres des âges VI et VII ; Fira Sans sert de police de secours pour les signes absents (« → »).
Les polices ne sont ni renommées ni sous-ensemblées (aucune « version modifiée » au sens de l'OFL). Accents français vérifiés par script (fontTools) : aucun glyphe manquant pour le texte courant.

**Habillages et sons d'interface des 10 âges** (`interface/ui_skins/age_01` … `age_10` : `panel.png`, `button.png`, `tap.wav`, `open.wav`, `alert.wav`, `age.wav`) : générés intégralement pour ce projet par `tools/generate-ui-skins.py` (Pillow et module standard `wave`, synthèse procédurale). Aucune source, image, son ou motif tiers ; aucune imitation d'un jeu existant. Pillow n'est requis que pour régénérer ces fichiers, pas à l'exécution.
