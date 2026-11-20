# Reprendre sur Android — version 0.13.4

## Installation

1. Fermer complètement Godot.
2. Extraire **tout le nouveau ZIP dans un nouveau dossier**. Conserver les anciens dossiers et les sauvegardes.
3. Dans Godot **4.7.2**, choisir **Importer**, puis sélectionner **`sillons/project.godot` du nouveau dossier**.
4. Laisser terminer le petit import des images et icônes, puis appuyer sur **Jouer**.

Le menu doit afficher **0.13.4**. Si l’éditeur affiche encore un nom de fichier `.glb` pendant l’import, le projet ouvert n’est pas celui de ce correctif, ou les sources 3D ont été replacées dans `sillons/`.

Ne pas déplacer `sources-3d/` à l’intérieur de `sillons/`. Ne pas supprimer `sillons/data/assets_3d.pck` : c’est la bibliothèque utilisée par le jeu. Aucune conversion, commande ou régénération n’est nécessaire sur le téléphone.

## Ce qui change

La capture reçue montre une réimportation des modèles dans l’éditeur, bloquée visuellement sur `veh_ground_jeep_a07.glb`. Elle ne fournit pas le message qui expliquerait l’arrêt. Le correctif évite l’import de tous les GLB sur Android : 800 modèles, 2 400 scènes natives et 174 images RGBA8 avec mipmaps sont déjà préparés dans un seul paquet. Les scènes sont chargées à la demande, avec les caches bornés de la refonte.

Les modèles, niveaux de détail, collisions, squelettes, animations et matériaux partagés sont conservés. Tous les originaux restent dans `sources-3d/`, hors du projet importé. Les 30 GLB de référence hors catalogue y sont également conservés.

Les règles, coûts, progression et fichiers de sauvegarde ne changent pas. La correction ne supprime ni ne réinitialise la sauvegarde. Le dossier neuf permet de revenir à l’ancienne version sans écraser ses sources.

## Résultats et limites

- Godot 4.7.2 Linux : import d’un projet sans cache, **0 import GLB**, 12 images/icônes importées, aucune erreur de script.
- 33 scénarios automatisés PASS ; une sonde GPU héritée reste SKIP en mode sans écran.
- 800 modèles et 2 400 scènes instanciés et contrôlés ; 174 images intègres ; la jeep de la capture se charge.
- Test isolé sans sources ni cache : la bibliothèque se charge aussi depuis un paquet de jeu contenant le paquet 3D.
- Menu et terrain capturés sous OpenGL logiciel.

Le démarrage réel sur téléphone et l’export APK restent **non testés**. Si cette version se ferme encore, le journal **Sortie / Débogueur** ou le journal de plantage Android permettra d’identifier l’étape restante ; la capture seule ne permet pas d’attribuer l’arrêt à la mémoire ou au pilote.

## Développement sur ordinateur

Le paquet est fourni prêt à l’emploi. Pour le régénérer après une modification des sources, avec Python 3.10+ et Godot 4.7.2 :

```bash
cd sillons
python3 tools/prepare-native-assets.py --godot /chemin/vers/godot --replace
```

L’outil vérifie les empreintes du catalogue, importe les sources dans un projet temporaire sur ordinateur, prépare des scènes autonomes et sauvegarde le paquet précédent avant remplacement. Après édition d’un GLB, mettre d’abord son empreinte à jour dans le catalogue. La chaîne de génération artistique historique n’était pas dans l’archive initiale ; l’outil inclus ici prépare les sources existantes.

Recette complète :

```bash
GODOT_BIN=/chemin/vers/godot bash tools/verify-refonte.sh
```

Les contrôles structurels et le chargement du paquet sont reproductibles. Le manifeste complet doit être régénéré après une modification du projet.
