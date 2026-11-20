# Sillons d'Empire — J6/J7/J8 (0.8.0 candidate, source Godot 4)

Cette archive est une évolution **complète du projet source** `sillons-empire-j345-0.5.0-source-complet.zip`. Le répertoire `sillons/` contient `project.godot` et tous les jalons antérieurs. Il ne s'agit ni d'un APK ni d'une reconstruction isolée. Le code historique non concerné par J6–J8 a été conservé.

## Fonctionnalités livrées dans le code source

| Niveau | Contenu technique | Accès |
| --- | --- | --- |
| Âge IX, J6 | spatioport, navette de transport, satellites (3 maximum par camp), balayage cartographique temporaire, recherche de propulsion orbitale | Construire un silo pour franchir l'âge VIII → IX, puis construire un spatioport |
| J7, interplanétaire | Carte **Aurore**, zone jouable et persistante, transport d'une navette avec un à six colons, trajet de 160 ticks, première colonie construite si un ouvrier est embarqué, approvisionnements communs | Secteur Aurore accessible au camp dès l'âge IX |
| Âge X, J8 | chantier orbital, frégate, recherche de navigation stellaire, carte **Némésis** dans un autre système, voyage interstellaire (420 ticks), rencontre de convois ennemis, victoire à l'échelle des trois théâtres | Construire un spatioport pour franchir IX → X, puis construire le chantier orbital |

La carte historique **Val des Deux Gués** est le théâtre initial. Les trois cartes se simulent à pas fixe, y compris hors écran. Chaque camp possède ses propres âges/technologies/ressources ; les cartes disposent d'unités, de bâtiments et de brouillards distincts. Les autres fonctionnalités historiques — IA, siège, trains, missiles, radars, brouillage, laboratoires et commandes mobiles — restent dans le projet.

### Panneau stratégique sur Android

1. Dans le menu principal, choisir **Atelier J6–J8 · essai âge X** pour tester directement avec les ressources, unités et bâtiments préparés ; ou **JOUER** pour une progression complète depuis l'âge I.
2. Pendant la partie, toucher **◈ SECTEURS** (zone droite) ; choisir Val des Deux Gués, Aurore ou Némésis. Un secteur ne devient sélectionnable que lorsque le camp atteint l'âge requis. La caméra revient sur la dernière position connue pour chaque carte.
3. Sélectionner un **spatioport** terminé, puis toucher **Placer un satellite**. Toucher ensuite **Balayage orbital** et viser la carte ; l'observation dure 180 ticks (18 secondes à 10 ticks/s), mais le terrain exploré reste mémorisé.
4. Pour une expédition vers Aurore, rapprocher du spatioport une **navette** et un à six colons, dont un **ouvrier** au premier voyage, sélectionner le spatioport, puis toucher **Envoyer → Aurore**. Les unités quittent physiquement la carte source, le coût est déduit et le convoi voyage avant de débarquer.
5. Pour Némésis, atteindre l'âge X, construire un **chantier orbital**, placer une **frégate** avec un ouvrier et envoyer vers Némésis. Les 420 ticks de trajet sont simulés, sans téléportation instantanée.
6. Les commandes **Sauvegarder** et **Charger** enregistrent et rétablissent désormais les trois planètes, les convois, les satellites, les recharges, les technologies et les ressources.

La limite de **1 à 6 unités par voyage**, le coût des voyages et les durées sont des paramètres de gameplay provisoires, modifiables dans `sim/star_campaign.gd`. Cette V1 du volet spatial est une **simulation sectorielle RTS** (trois cartes/systèmes persistants), et non une carte de galaxie 3D librement navigable ni un simulateur balistique orbital.

## Structure

- `sim/star_campaign.gd` : moteur stratégique déterministe, simulation et progression multicarte, convois, satellites et victoire globale.
- `sim/campaign_save.gd` : sauvegarde atomique, empreinte SHA-256, restauration validée, maintien d'une copie `.bak`.
- `sim/rules.gd` : âges IX/X, unités, constructions et recherches.
- `game/strategic_hud.gd` : interface tactile de navigation, satellite, scan et expédition.
- `game/game.gd` et `game/main_menu.gd` : intégration de la campagne, scènes, commandes, reprise des parties J345.
- `lab/strategic_test.gd` et `lab/strategic_ui_test.gd` : tests automatisables hors rendu/avec scène.
- `tools/verify-j678-static.py` : contrôles structuraux reproductibles (ne remplace pas la compilation).
- `tools/verify-j678.sh` : lancement de la compilation et de tous les laboratoires J345/J678 sur ordinateur équipé de Godot.
- `tools/export-android-j678.sh` : export de l'APK Android **si** Godot, SDK et modèles d'export Android sont installés.

## Contrôle et compilation

Depuis le répertoire `sillons/` (ordinateur Linux/macOS/Windows avec Godot installé, commandes Bash) :

```bash
python3 tools/verify-j678-static.py
GODOT_BIN=godot ./tools/verify-j678.sh
```

Sur un poste doté du SDK Android, du JDK et des modèles d'export Godot :

```bash
GODOT_BIN=godot ./tools/export-android-j678.sh
```

Le résultat visé est `build/sillons-j678-debug-0.8.0.apk`. Le nom du paquet Android existant `fr.sillons.empire.j1` est conservé pour permettre une mise à jour installable en conservant les données utilisateur ; vérifier la signature, la compatibilité du SDK et la version du package sur le téléphone avant d'installer. Les sauvegardes J345 peuvent être reprises depuis le menu, dans la mesure où leur format d'origine est resté compatible.

⚠️ Avant toute installation sur une partie importante, conserver une copie de la sauvegarde actuelle. Ne pas désinstaller l'application sans avoir préalablement sauvegardé `user://`.

## Limites de cette livraison

**Source candidate, validation runtime en attente.** Dans l'environnement de construction utilisé ici, aucun binaire Godot et aucun SDK Android n'étaient disponibles ; l'import, l'exécution des scripts GDScript et la génération de l'APK n'ont donc **pas** pu être réalisés. Les contrôles statiques ne démontrent pas l'absence de bogues à l'exécution et aucune mesure FPS/énergie/chauffe n'a été effectuée sur Galaxy S25 Ultra. La validation J1–J8 doit être exécutée avec `tools/verify-j678.sh` sur un poste équipé, puis sur téléphone. Consulter `game-studio/J678-validation.md` pour la recette complète.
