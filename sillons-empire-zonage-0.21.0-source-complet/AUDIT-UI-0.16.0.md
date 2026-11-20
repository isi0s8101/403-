# Audit de l'interface et des commandes — Sillons d'Empire 0.16.0 (avant la 0.17.0)

Constat fait **avant** de développer, sur l'archive reçue (`sillons-empire-civilisation-0.16.0-source-complet`, 4 morceaux), avec **Godot 4.7.2** sous Linux.
Ce qui touche Android est **NOT_RUN** (aucun téléphone n'a servi).

> Remarque : le fichier `sillons/CLAUDE.md` cité par la commande **n'est pas dans l'archive reçue** (le dépôt GitHub n'était pas accessible depuis cette session). Les règles ont été reprises de la commande elle-même et des rapports présents (`RAPPORT-REPRISE.md`, `README-LIVRAISON.md`, `README-CIVILISATION-0.16.0.md`, `AUDIT-0.15.1-R2.md`).

## 1. Vérification de départ (exécutée)

| Contrôle | Résultat |
|---|---|
| `bash tools/verify-refonte.sh` sur la 0.16.0 intacte | **PASS** — contrôles statiques 15 suites, import, **52 scénarios sur 52** |
| Captures réelles (xvfb + `--rendering-driver opengl3`) | 7 écrans × 2 résolutions (1600×740 et 2400×1110) = 14 captures, dans `sillons/game-studio/preuves/interface-0.17.0/avant/` |

Écrans capturés : début de partie, armée sélectionnée, fiche de caserne, placement d'un bâtiment, panneau Civilisation, bataille, globe.
Outil : `tools/capture-ui-017.gd` (mêmes réglages pour l'avant et l'après).

## 2. Tableau « avant » : nombre de touchers (0.16.0)

Mesuré en suivant le code réel de la 0.16.0 (`game/game.gd`, `game/hud.gd`, `interface/building_drawer.gd`) et vérifié dans la scène pour les actions qui existent.

| Action | 0.16.0 | Cible 0.17 |
|---|---|---|
| Sélectionner tous les ouvriers inactifs | **impossible** (compteur « Inactifs » non cliquable) | 1 toucher |
| Toute l'armée / tous les mêmes à l'écran | **impossible** directement ; rectangle seulement après le bouton « Choisir » (1 toucher + 1 glissé), pas de « même type » | 1 à 2 touchers |
| Rappeler un groupe de contrôle | **impossible** (pas de groupes) ; escouade via « Armées » : 2 touchers | 1 toucher |
| Ordre « assaut » vers un point | 2 touchers (appui long au sol + « Assaut ») | 2 touchers maximum |
| Programmer un trajet A → B → C | **impossible** (une seule étape ; « Pause 10 s » = 2 étapes) | 1 bascule + 1 toucher par point |
| Faire bâtir 3 bâtiments à la suite par les mêmes ouvriers | **impossible** (ouvriers automatiques, aucun ordre « bâtir ce chantier ») | 1 bascule + 3 poses |
| Former 5 unités d'un coup | 5 touchers (1 par unité) | 1 toucher |
| Poser une ligne de murs ou 3 maisons | 12 touchers (Bâtir + carte + emplacement + Valider, × 3) | 1 glissé + 1 validation |
| Aller à la dernière alerte | **impossible** (messages textuels sans position) | 1 toucher |
| Lancer un pouvoir de commandement | 3 touchers au moins (Civilisation, défiler jusqu'au pouvoir, pouvoir, cible) | 2 touchers |
| Ordres involontaires (pincement, glissé, panneau ouvert) | 0 (couvert par `touch`, `modal_touch`) | 0 |
| Thèmes d'interface distincts | 1 seul (charte sombre identique de l'âge I à l'âge X) | 10 |

## 3. Constats d'ergonomie

**Cibles tactiles.** Les boutons existants respectent 48 px logiques (base 1280×600). Pas de cible plus petite repérée dans les barres.

**Textes de moins de 13 px logiques** : description des cartes (12 px), raison du verrou sur les cartes (11 px), état et file de la fiche de bâtiment (12 px), ligne « ouvriers » des puces de ressources (12 px), étiquettes de débogage (12-13 px, hors jeu normal).

**Centre de l'écran.** Aucun panneau permanent ne le couvre. La fiche de bâtiment occupe toute la colonne droite (484 px) quand un bâtiment est choisi ; le panneau Civilisation est plein écran (modal).

**Gestes.** Un doigt = caméra, même en partant d'une unité ; le rectangle exige le bouton « Choisir » ; appui long = menu circulaire ; deux doigts = zoom, rotation, déplacement. Pas de double appui, pas de sélection additive, pas de groupes.

**Ordres.** La simulation sait suivre une file de 1 à 16 étapes (`ArmyPlans.queue_orders`), mais l'interface n'en envoie qu'une (ou deux), invisible à l'écran ; l'unité passe en contrôle direct sans que ce soit affiché. Aucune commande Arrêt, Tenir (exposée), Posture, Formation choisie, Repli (joueur), Garnison, Réparation, ordres manuels aux ouvriers, Démolition (carte tactique), Cible prioritaire, Suivre, Exploration, Production répétée, Ralliement sur ressource.

**Informations.** Les messages (toasts) disparaissent en 4 s, sans « aller voir » ; pas de signal d'attaque sur la mini-carte ; les héros et pouvoirs sont au fond du panneau Civilisation.

**Style.** Un seul `Theme` (couleurs fixes dans `game/mobile_ui.gd` et plusieurs fichiers), police par défaut de Godot, aucune texture d'interface, fondus seulement.

## 4. Vérification du tableau « État actuel » de la commande (§ 1)

Toutes les lignes ont été vérifiées dans le code 0.16.0 et sont **exactes**, avec deux précisions :
- l'ordre interne `hold` existe (utilisé par `take_unit`) mais n'était pas une commande du joueur ;
- les tirs (`tir`) sont consommés par `game.gd` avant le HUD : une alerte d'attaque ne pouvait pas en naître sans modification.

## 5. Choix de produit faits sans attendre (documentés)

- **Groupes de contrôle** : 6 emplacements, gardés pendant toute la partie et enregistrés **avec la sauvegarde** dans un fichier compagnon (`user://sillons-groupes.cfg`), relus seulement avec cette même sauvegarde.
- **File d'un groupe ou d'une escouade** : les unités passent en **contrôle direct** (comme en 0.16), gardent leur place dans la formation et **attendent les retardataires** à chaque point (20 s au plus) ; c'est **affiché** (« contrôle direct », « file 2/5 ») et le bouton **Rendre** les rend à l'armée.
- **Double appui** = tous les mêmes à l'écran ; le **deuxième toucher lent** garde son sens « unité seule ».
- **Démolition** : chantier inachevé remboursé à 50 %, bâtiment achevé sans remboursement ; le dernier centre ne peut pas être démoli.
- **Rotation des bâtiments** : toutes les emprises sont carrées, la rotation ne changerait rien.
