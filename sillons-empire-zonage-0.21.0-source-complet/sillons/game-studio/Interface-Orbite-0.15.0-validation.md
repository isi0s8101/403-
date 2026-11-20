# Validation interface et orbite 0.15.0

Le détail des exécutions est conservé dans `preuves/interface-orbite-0.15.0/`. Les anciens journaux restent attachés à leur version d’origine.

## Nouveaux scénarios

- `interface_menu_test` : décor, boutons, reprise indisponible sans sauvegarde, paramètres tactiles modaux, économie graphique, réduction des animations, fermeture et réouverture rapide.
- `interface_interaction_test` : toucher le toit et les photos, production réelle, ralliement, onglets, panneaux repliables, ordres orbitaux, pincement, retour et lecture seule des vues système/galaxie.
- `interface_portraits_test` : 405 accès aux photos de bâtiments, unités et installations, sans image manquante.
- `orbit_tactical_test` : inventaire réel, détour planétaire, voyages, dégâts, sauvegarde déterministe, combat, destruction, verrou de débarquement, placement, production et ralliement automatique.
- `orbit_save_test` : reprise, migration et refus propre des données altérées, intégrité des vaisseaux en transit, âge local et flotte importée.
- `orbit_performance_test` : échantillon de 150 ticks orbitaux sur trois cartes et 120 vaisseaux, hors rendu et hors bataille maximale.

## Adaptations des recettes historiques

`j10_ui_test` et `j11_ui_test` recherchent désormais `OrbitalBattleView` et `OrbitalBattleHud` pour l’orbite. `ui_j21_test` et `refonte_visual_test` vérifient la fermeture logique immédiate du tiroir, suivie de son fondu court. Leurs anciennes versions sont conservées dans `historique-0.14-*`.

Les audits statiques suivent le déplacement des commandes vers l’orbite et le passage de version. Ils ne remplacent pas l’exécution de Godot.

## Rendu

Six captures réelles 1280 × 600 : accueil, unités du bâtiment, bâtiments, orbite, système et galaxie. Les niveaux avancés utilisent une fixture d’atelier afin d’inspecter l’interface ; aucune partie normale n’est créée directement à l’âge X.

## Limites

Aucun APK construit, aucun essai sur appareil Android, aucun rendu Vulkan, aucune certification d’une bataille maximale ni d’une longue campagne I à X. Les mesures de simulation sur Linux ne sont pas des FPS Android.
