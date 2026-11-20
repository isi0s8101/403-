# Sillons d’Empire — J10 0.10.0 — Systèmes stellaires procéduraux

**État : candidate source, non certifiée Godot ou Android.** Dérivé de J9 0.9.1 sans perte des cartes existantes.

## Ajouts fonctionnels

- Catalogue déterministe à partir de la graine existante : **Sol / Proxima**, anciens secteurs `val`, `aurore`, `nemesis` inchangés, nouvelles planètes et deux lunes générées (identifiants stables).
- Cartes tactiques générées à la demande pour les nouveaux astres. Pas de colonie, armée ou ressources fictives sur les nouvelles destinations ; elles sont colonisées par un **convoi réel** contenant un ouvrier.
- Dézoom **terrain → globe → orbite → système stellaire** ; actions inverses pour revenir à l’astre choisi. La vue spatiale représente les orbites, les lunes, les satellites et les convois progressant par tick ; les âges IX et X conditionnent l’accès tactique aux mondes supplémentaires.
- Carte spatiale tactile avec sélection d’astre et planification de convoi : choix du port, du navire et de 1–6 unités ; coût, durée, capacité, interception et validation restent gérés par `StarCampaign.dispatch()`.
- Sauvegarde compatible avec les instantanés 0.9.1 : ajouts optionnels `star_catalog_version`, `extra_maps` et validation d’intégrité des graines des secteurs ; restauration protégée du `.bak` conservée.
- Mondes générés inhabités : horloge logique conservée sans calcul du pathfinding tant que le monde reste inoccupé. Simulation à pas fixe des théâtres et régions habités, quel que soit le zoom ou la vitesse ×0,5–×8.

## Procédure utilisateur

1. Lancer une partie J9 depuis le menu (ou charger la campagne existante).
2. Depuis la carte tactique, dézoomer complètement pour ouvrir le globe.
3. Dans l’atlas, toucher **Zoom − · Orbite**. La scène orbitale apparaît.
4. Toucher **Zoom − · Système stellaire** pour visualiser l’étoile et ses planètes ; toucher une planète pour la sélectionner.
5. **Zoom +** revient à l’orbite de l’astre ; la commande **Descendre sur la surface** ouvre sa carte tactique si son âge est débloqué.
6. Pour conquérir un nouveau monde, revenir au secteur doté d’un spatioport, sélectionner sur la vue système la destination, puis **Préparer une expédition**. Choisir explicitement plateforme, vaisseau et ouvriers, confirmer ; les troupes ne sont pas téléportées.

**Gestes :** pincement vers l’intérieur = dézoom, vers l’extérieur = zoom ; molette compatible sur ordinateur. Les boutons restent utilisables indépendamment du geste.

## Vérification

Godot **4.7.2** Linux/Windows et Python 3 sont requis pour la recette complète. Depuis le dossier `sillons/` :

```bash
./tools/verify-j10.sh
```

L’outil exécute les contrôles statiques, importe le projet avec Godot puis les tests headless des jalons précédents et les deux scénarios J10. **S’il manque Godot, retour 127 (pas de PASS d’exécution).**

Pour exporter Android : installation des templates Godot correspondants, Java SDK, Android SDK et clés de debug ; ensuite :

```bash
./tools/export-android-j10.sh
```

APK attendu seulement après exécution réussie : `build/sillons-empire-j10-debug-0.10.0.apk`.

## Recette manuelle Galaxy S25 Ultra

- Vérifier écran paysage, lecture des noms, UI sans chevauchement, mouvements tactiles/pinces dans tous les niveaux.
- Tester le dézoom jusqu’au globe puis l’orbite et le système ; choisir un autre astre puis revenir ; absence de téléportation de troupes.
- À l’âge IX lancer un convoi vers une planète locale générée ; vérifier coût, ETA, carte destination, ouvriers, bâtiments et populations. Tester une lune.
- À l’âge X, afficher Proxima depuis la carte du système Sol puis lancer une frégate vers une planète Proxima ; tester interception de deux flottes ennemies et alertes hors écran.
- Rejouer les tests accélérés ×0,5/×1/×2/×4/×8, pendant un combat local et une opération interplanétaire.
- Sauvegarder en voyage, fermer l’application, restaurer ; même graine, identités, actifs, ETA et issue du combat.
- Mesurer FPS, temps du tick (p95/p99), RAM, température et stabilité sur au moins 20 minutes de campagne.

## Limites connues

- **Le rendu des niveaux est une transition de scène, pas un morphing géométrique continu.** Le réglage de distance et de rendu sur smartphone n’est pas certifié.
- Val conserve l’atlas J9 de 512×256 régions logiques. Les autres astres sont actuellement dotés d'une **carte régionale tactique procédurale 96×96**, sans déplacement interrégional planétaire complet. Étendre les régions à chaque planète est un chantier supplémentaire.
- Les affrontements spatiaux utilisent encore les interceptions déterministes J8 et non une bataille RTS 3D avec déplacement individuel des frégates. Les trajectoires sont des orbites stylisées pour le gameplay, pas une simulation N-corps. Les distances physiques ne sont pas à l’échelle ; les coûts/ETA sont ceux des règles J6–J8.
- La carte limite le rendu simultané à **64 marqueurs de convois** pour préserver l’interface mobile ; les convois supplémentaires continuent d'être simulés. Le catalogue est limité à **deux systèmes** pour J10. La galaxie entière est réservée à J11.
- Les ressources restent communes entre secteurs comme en J6–J9. La logistique locale et les capacités de simulation massives restent à améliorer en J12.
- Godot, Android et le S25 Ultra doivent valider les interactions, la compilation, les performances et le confort visuel.

## Retour arrière

Conserver l’archive 0.9.1 et une sauvegarde des données `user://`. Les nouveaux instantanés avec `extra_maps` ne sont **pas rétrocompatibles** avec l’ancien binaire, même si la version du format historique reste 1. Une sauvegarde J9 ancienne est lisible par J10, pas l’inverse.
