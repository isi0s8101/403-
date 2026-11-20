# Sillons d’Empire — 0.13.4 — correctif d’import Android (candidate)

Ouvrir **`sillons/project.godot` dans Godot 4.7.2**, après extraction complète dans un **nouveau dossier**. Ne pas importer un ancien projet déjà présent dans la liste de Godot.

La capture du blocage montre l’éditeur pendant l’import de `veh_ground_jeep_a07.glb`, avant le démarrage du jeu. La cause exacte de l’arrêt n’est pas confirmée sans journal Android. Cette version retire cette phase lourde : les 800 modèles du catalogue sont livrés dans un paquet natif déjà préparé, chargé à la demande.

- **Aucun GLB à importer dans le projet jouable** ; 12 images et icônes seulement lors de l’import vierge mesuré.
- Les 2 400 scènes de détail et les 174 textures du catalogue sont incluses dans `sillons/data/assets_3d.pck`.
- Tous les fichiers de la version précédente sont conservés. Les originaux 3D et leurs aperçus sont dans `sources-3d/`, à côté de `sillons/`, hors du dossier analysé par Godot.
- La refonte 0.13.3 de l’interface, du tactile et du rendu est conservée. Les 32 fichiers de simulation restent identiques à la 0.13.2 fournie.

**Vérification :** 33 scénarios Godot PASS sous 4.7.2, catalogue complet, jeep instanciée, animations/LOD/collisions contrôlés, chargement du paquet depuis un paquet de jeu autonome PASS. Menu et terrain capturés dans le moteur OpenGL logiciel. Les preuves 0.13.3 restent identifiées comme historiques.

**Limites :** correctif testé sous Linux, pas encore sur le téléphone ; aucun APK exporté, aucune mesure de FPS/RAM/chauffe Android. La version reste candidate. La géométrie héritée reste souvent low-poly.

Lire **`README-IMPORT-ANDROID-0.13.4.md`** pour reprendre sur Android. `APERCU-VISUEL.html` montre les deux captures actuelles et donne accès à la galerie historique. Les empreintes de l’archive complète figurent dans `MANIFEST-SOURCE.sha256`. Les caches Godot et métadonnées d’import générées sont exclus du ZIP ; toutes les sources sont conservées.
