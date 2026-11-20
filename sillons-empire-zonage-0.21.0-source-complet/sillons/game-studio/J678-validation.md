# J6–J8 : compte rendu, statut et recette de validation

**Cible :** jeu « Sillons d'Empire », Godot 4, Android ARM64, Galaxy S25 Ultra.  
**Branche :** `0.8.0-j678-candidate`, source dérivée de J345 0.5.0.  
**Baseline :** J345 conservée hors archive de livraison, original jamais modifié.  
**Portée :** code des âges IX–X, systèmes orbitaux et campagnes de plusieurs cartes, interface, sauvegardes.  
**Statut :** code écrit ; tests statiques vérifiables ; vérification Godot et Android **non réalisée faute d'outils**.

## Essais automatisés

Exécuter `tools/verify-j678.sh` dans le projet, avec `GODOT_BIN=godot` (ou le chemin de l'exécutable Godot). Le script :

- importe les ressources et inspecte les erreurs de parse/compilation ;
- exécute `lab/strategic_test.gd`, qui couvre : trois planètes, verrouillage des âges, autorisation de port, satellite, scan et expiration, un convoi intra-système, l'absence de victimes fictives au départ, colonie créée, frégate interstellaire, simulation des trois mondes, reprise déterministe, interceptions multiples, sauvegarde SHA-256 et rejet des corruptions ;
- exécute `lab/strategic_ui_test.gd` qui instancie la vraie scène, le panneau tactile et bascule entre planètes ;
- rejoue tous les tests modernes J345, le test UI J2.1, les tests visuels sans mesure GPU, le laboratoire général et les tests deux fronts.

Seule la sortie **PASS avec code retour zéro** de ces scripts prouve que le lot passe le banc d'essai. Sans binaire Godot, afficher **SKIP** plutôt qu'un faux PASS.

## Recette manuelle Android (à exécuter)

| Essai | Action | Attendu | Mesure à consigner |
| --- | --- | --- | --- |
| Installation | Charger l'APK debug et ouvrir l'accueil | Menu utilisable en paysage, aucune fenêtre d'erreur | Version Android, Godot, logcat |
| J1–J5 | Partie normale à graine fixe, construction/IA/combat | Mécaniques historiques conservées, compteurs normaux | FPS et logs |
| Âge IX | Aller de VIII à IX avec objectif silo atteint | Âge IX débloqué, coûts réels, spatioport disponible | Temps simulation |
| Satellite | Sélectionner spatioport, lancer puis relancer | 1er succès, recharge/limite interdisent le suivant | Coût, délai, messages |
| Balayage | Scanner Aurore, observer puis attendre 180 ticks | Brouillard temporaire ; mémoire du terrain conservée | Captures avant/après |
| Colonisation | Navette + ouvrier → Aurore | Unités disparaissent de Val, apparaissent après 160 ticks sur Aurore ; centre construit | Population, inventaire, coût |
| Âge X | Construire spatioport, atteindre X et chantier | Technologies et frégate proposées | Ressources, UI |
| Interstellaire | Frégate + ouvrier → Némésis | Débarquement après 420 ticks sans blocage écran | Temps, FPS |
| Multicarte | Laisser des soldats combattre sur Val ; regarder Aurore | Combats continuent hors écran et la carte reprend son état | Hash/log/compteurs |
| Sauvegardes | Sauvegarder pendant un vol, quitter et reprendre | Position, unités, vols, âges et technologies inchangés | Hash et écrans |
| Victoire | Perdre tous les centres et ouvriers des trois cartes | Défaite globale, pas de verdict local prématuré | Log d'événements |
| Stress | Unités nombreuses, trois cartes occupées, vitesse accélérée | Pas de crash, de fuite mémoire, ni d'entrée tactile perdue | RAM, FPS, température batterie |

### Mesures et critères d'acceptation

- Aucun `SCRIPT ERROR`, `Parse Error`, `Compile Error` ni crash.
- Tous les scénarios `strategic_test`, `strategic_ui_test` et les laboratoires J1–J5 passent.
- Absence de double dépense ou de duplication d'unités au chargement, débarquement et transfert.
- Objectif UX : toutes les commandes importantes du panneau stratégique atteignables au doigt sans masquer durablement la carte ; vérifier visuellement sur Galaxy S25 Ultra.
- Objectif de performance indicatif à **mesurer et adapter** : viser 30 FPS minimum en bataille type et surveiller les 1 % low, les pauses de > 100 ms, la RAM et la température. Aucun chiffre mesuré n'est fourni par cette livraison.
- Ne pas déclarer VALIDÉ tant que la recette terrain n'est pas signée.

## Retour arrière

Conserver le projet J345 dans son ZIP d'origine. Ne pas écraser ses fichiers : importer J678 dans un répertoire séparé. Les sauvegardes campagne utilisent `user://sillons-j678.save` et une copie `user://sillons-j678.save.bak` ; l'ancien `SaveGame.PATH` n'est pas écrasé par cette version. Si une installation Android se révèle instable, conserver/extraire les sauvegardes avant toute réinstallation, puis revenir à l'APK d'origine avec une signature et un numéro de version compatibles.
