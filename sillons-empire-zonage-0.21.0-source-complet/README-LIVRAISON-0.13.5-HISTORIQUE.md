# Sillons d’Empire — 0.13.5 — priorité réalisme (candidate)

Ouvrir **`sillons/project.godot` dans Godot 4.7.2**, après extraction complète du ZIP dans un **nouveau dossier**. Le menu affiche 0.13.5.

Cette version donne la priorité au rendu : nouvelles architectures, personnages articulés, végétation, rochers et matériaux photographiques. Les évolutions politiques et stratégiques cadrées précédemment restent prévues pour la suite.

- **57 modèles originaux supplémentaires** : 44 bâtiments (11 familles, quatre styles d’âges), trois arbres, un arbuste, trois rochers et six personnages articulés.
- **27 cartes PBR photographiques CC0**, avec albédo, normales OpenGL et occlusion/rugosité/métal. Source, licence et empreintes documentées.
- Façades, huisseries, couvertures, poutres, gouttières, cheminées et équipements en volume ; modèles de proximité équipés de quatre animations.
- Feuilles et brins d’herbe animés, instances de ressources compactées selon le brouillard, pierres irrégulières et contacts au sol.
- Terrain et eau revus, éclairage solaire/ambiant ajusté ; globe 1024 × 512 progressif, nuages et atmosphère.
- Bibliothèques natives conservées : **aucun GLB dans le projet jouable**, aucun import de modèle sur téléphone.
- Les 32 fichiers de simulation restent identiques à la 0.13.4. Les règles, commandes, coûts et sauvegardes restent ceux de cette candidate.

Le détail des validations est dans `sillons/game-studio/J13-validation.md`. Les captures du vrai moteur et la comparaison avec la 0.13.4 sont dans **`APERCU-VISUEL.html`**.

**Limites :** rendu vérifié sous Godot 4.7.2 Linux/OpenGL logiciel. Appareil Android, Vulkan mobile, APK, FPS et chauffe sur S25 Ultra non testés. Cette version reste candidate. Les modèles sont plus détaillés ; il reste du travail artistique sur une partie des véhicules, des animations et de la bibliothèque héritée. Le photoréalisme complet n’est pas certifié.

Lire `README-REALISME-0.13.5.md` pour l’installation, les réglages, les sources et le retour arrière. Conserver la 0.13.4 et sa sauvegarde avant les essais.
