# Validation 0.13.5 — candidate graphique

Session du 14 novembre 2026. Godot **4.7.2.stable.official.ed1daf0bf**, Linux x86_64.

| Contrôle | Résultat |
|---|---|
| Scénarios historiques et nouveaux | **34/34 PASS**, journaux finaux sans erreur de script |
| Nouvelle recette de réalisme | PASS 148 contrôles |
| Recette de présentation / modalités tactiles | PASS 140 et 4 contrôles |
| Modèles originaux | PASS 800 modèles, 2 400 scènes |
| Modèles supplémentaires | PASS 57 scènes natives intègres et autonomes |
| Personnages supplémentaires | Six figures ; idle / walk / work / attack présents |
| Matières photographiques | 27 images 1K ; sources, licence et empreintes fournies |
| Simulation comparée à la 0.13.4 | 32 fichiers identiques ; empreinte inchangée lors des passes visuelles |
| Import vierge | PASS, aucun GLB ; 39 images/icônes |
| Paquets natifs dans un paquet de jeu autonome | PASS |
| Outil de reconstruction sur ordinateur | PASS ; artefact de contrôle distinct du paquet livré |
| Captures du moteur | Six captures finales OpenGL logiciel, 1280×600 |
| Sonde GPU héritée J2.1-C | 1 SKIP headless |
| Android / Vulkan mobile / APK / FPS / chauffe appareil | **NOT_RUN** |

Les journaux actuels sont dans `preuves/realisme-0.13.5/`. Le contrôle statique complet est effectué à l’assemblage et répété sur l’archive extraite. Les preuves 0.13.3/0.13.4 restent historiques.

Le coût géométrique de proximité augmente avec le détail. Les statistiques de dessin sont des observations locales sous llvmpipe, pas une mesure de débit Android. La version reste candidate ; le photoréalisme intégral et la refonte de tous les modèles hérités ne sont pas déclarés atteints.
