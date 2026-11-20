# Sillons d’Empire — Interface et orbite 0.15.0

Projet Godot complet, à importer par `sillons/project.godot` après extraction de **toute** cette archive. Version candidate, testée sous Godot 4.7.2 sur Linux.

## Ce qui change

- Accueil avec décor 3D, campagne, reprise, paramètres, aperçu de quatre âges et accès aux anciens ateliers.
- Interface bleu nuit, accents or et turquoise, panneaux rétractables et transitions courtes. Option de réduction des animations.
- Toucher un bâtiment allié ouvre sa fiche : **Unités**, **Bâtiments**, **Évolutions**. Photos des modèles, noms, coûts, blocages, production et ralliement.
- **Orbite : véritable carte jouable de 160 × 160**. Sélection individuelle ou multiple, mouvement autour de la planète, assaut, arrêt, production, implantation de modules, recherche d’équipement et voyages avec délais.
- **Système et galaxie : observation uniquement**. Trafic, destinations et délais des flottes, expéditions, sondes, transports et convois ; navigation vers les cartes jouables.
- Positions, chemins, dégâts, points de ralliement et constructions orbitales enregistrés. Les sauvegardes 0.14 sont migrées sans dotation de vaisseaux.

## Démarrage

1. Extraire le ZIP complet dans un nouveau dossier.
2. Dans Godot, importer `sillons/project.godot`.
3. Lancer le projet, puis **Commencer une campagne**. Les parties commencent toujours à l’âge I.
4. Le laboratoire conserve **Atelier empire · âge X** pour essayer directement l’orbite. Cet atelier est distinct d’une campagne normale.
5. Consulter `APERCU-VISUEL.html` pour six captures réelles du moteur, et `README-INTERFACE-0.15.0.md` pour les commandes.

Conserver `sillons/data/assets_3d.pck` et `sillons/data/realism_models.pck`. Les sources GLB restent hors du projet jouable : aucune nouvelle réimportation massive de GLB n’est nécessaire. Les 390 nouvelles photos sont de petites données PNG `.bytes`, chargées à la demande.

## Vérification et limites

Les résultats, journaux et captures sont dans `sillons/game-studio/preuves/interface-orbite-0.15.0/`. La suite comprend les 42 scénarios précédents, dont quatre assertions de navigation/repli adaptées à la nouvelle interface, et six nouveaux scénarios. Les originaux des tests modifiés sont conservés dans `sillons/game-studio/historique-0.14-*`.

Pour relancer les contrôles depuis `sillons/` :

```bash
GODOT_BIN=/chemin/godot bash tools/verify-refonte.sh
```

Il s’agit des sources du jeu, **pas d’un APK**. L’exécution Android, le rendu Vulkan, les performances sur téléphone, une longue campagne I à X et une bataille orbitale de capacité maximale ne sont pas certifiés ici. Les captures viennent d’OpenGL logiciel sur Linux.

Les modèles, textures, sources 3D, cadrages et preuves des versions antérieures restent fournis. Cette livraison ne modifie pas l’archive 0.14.
