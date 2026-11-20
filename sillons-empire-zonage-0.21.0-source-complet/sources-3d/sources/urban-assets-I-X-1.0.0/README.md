# Sillons d’Empire — 30 bâtiments urbains 3D (âges I–X)

30 fichiers GLB originaux : résidentiel, commercial et industriel, un modèle par âge.

## Import Godot 4
Copier `glb/` dans `res://assets/urban/`, puis importer les `.glb` comme scènes 3D. Les modèles ont une emprise de référence variable : ajuster les parcelles dans le moteur, sans étirement non uniforme.

## Limites et vérification
Géométries procédurales avec couleurs par sommet (pas de textures PBR externes). Ces modèles constituent un premier lot de production architectural optimisé et non des modèles photoréalistes finis. Aucune compilation Godot, vérification Android, animation ni mesure de FPS n'a été effectuée.

Le manifeste contient les SHA-256 et les noms des fichiers. Vérifier avec `sha256sum -c SHA256SUMS.txt` depuis le dossier racine.
