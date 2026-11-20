# Sillons d'Empire — J9 0.9.1 : planète interrégionale — candidate technique

**Source :** archive 0.9.0 J9, elle-même issue de 0.8.2. **Portée :** J9-A à J9-F, extension du jeu existant J1–J8, sans migration irréversible des sauvegardes historiques. **Statut :** fonctionnalités codées et contrôles statiques PASS ; **compilation Godot, tests de simulation Godot et recette Android non exécutés ici**.

## Nouvelles fonctions livrées

- **Planète traversable en régions :** atlas logique 512 × 256 régions de 96 × 96 cellules, adressables par latitude/longitude, identifiants stables `(x,y)` et boucle de longitude. Les régions sont construites seulement lorsqu'elles sont utilisées ; **il ne s'agit pas d'1,2 milliard de cellules stockées**.
- **Relief/biomes déterministes :** sphère basée sur seed + variations à haute résolution, sommets communs aux quatre frontières, y compris jointure ±180°. La grille tactique ne répète plus les deux gués artificiels dans chaque région. Les bâtiments de départ et les comptoirs garantissent une escarmouche jouable sur la première région.
- **Continuité du déplacement :** sélectionner des unités et demander N/S/E/O depuis les boutons « RÉGION » sur la vue tactique ; un itinéraire jusqu'à une frontière terrestre est validé avant l'ordre. Le changement n'intervient qu'au passage physique de l'unité sur la limite (arrivée sur la case adjacente de la région voisine). Impossible de passer par-dessus l'océan sans autre système de transport. Les trains sont exclus des déplacements interrégionaux terrestres J9.
- **Persistance :** chaque région visitée ayant des unités, constructions, ressources consommées, brouillard exploré ou balayages est conservée avec son état (entités, PV, ordres locaux, ressources, brouillard). Les régions vierges sont régénérées avec la même seed sans être conservées en mémoire. Identité `planet_uid` stable même si l'ID local d'unité évolue lors d'une traversée.
- **Simulation hors écran :** les régions habitées chargées avancent au même nombre de ticks que la région visible, avec économies et combats locaux. Pas de faux saut d'unités. Le coût CPU est proportionnel au nombre de régions actives : le traitement agrégé de grands empires appartient au jalon J12.
- **Atlas interactif :** sélectionner une région émergée sur le globe, puis « EXPLORER CETTE RÉGION » : la caméra s'y rend, sans téléporter de troupe. Retour à la carte précédente en choisissant sa région dans l'atlas. La vue tactique recharge les chunks et rétablit les interactions.
- **Navettes/orbital J6–J8 :** lorsqu'un vol vise la première planète, sa région d'arrivée est figée dès le départ, indépendamment des mouvements ultérieurs de caméra. Les alertes militaires des autres régions restent consultables. Âge II : comptoirs neutres présents ; âge III : ouvrage défensif sur une frontière régionale à la place d'un gué fictif. Les autres âges et coûts conservent les règles J1–J8.
- **Sauvegarde :** `user://sillons-j9-planet.save` contient le cache des régions et les traversées en cours. Les sauvegardes 0.9.0 J9 dépourvues de cette extension sont reprises dans leur région originale (ancienne topographie conservée, sans promesse de raccord géométrique parfait aux nouvelles régions). J1–J8 continuent d'utiliser leur slot indépendant.

## Commandes en jeu

1. Menu « J9 · Nouvelle planète procédurale », choisir une terre émergée puis « JOUER ICI ».
2. Sur la carte : sélectionner un ou plusieurs ouvriers ou soldats, puis utiliser les boutons **NORD / SUD / EST / OUEST**. Le jeu trace le trajet vers une frontière praticable. Si l'interface signale « passage impossible », explorer un autre côté ou contourner le relief.
3. Dézoom maximal → globe, toucher une région et sélectionner **EXPLORER CETTE RÉGION** (caméra uniquement). Pour déplacer une troupe, revenir à sa région et utiliser les boutons de frontière.
4. Panneau Secteurs : voyager vers Aurore et Némésis avec les fonctions J6–J8 habituelles. Conserver les bâtiments orbitaux sur la région où les unités sont embarquées.
5. Bouton Vitesse : 0,5× / 1× / 2× / 4× / 8× (temps de simulation, pas déplacements de caméra).

## Vérification

Depuis un poste Linux avec **Godot 4.7.2** standard installé et le projet extrait :

```bash
cd sillons
./tools/verify-j9-complete.sh
```

Le script exécute les audits statiques, l'import/compilation Godot en mode headless, puis les scénarios `lab/j9_planet_test.gd`, `lab/j9_regions_test.gd` et les recettes historiques. Code retour **127** si Godot absent : ce n'est pas un PASS.

Pour exporter un APK, configurer les templates Godot/SDK Android/JDK puis exécuter :

```bash
./tools/export-android-j9-complete.sh
```

APK attendu **uniquement après export réussi** : `build/sillons-empire-j9-debug-0.9.1.apk`.

### Recette matérielle S25 Ultra (non effectuée)

- Nouvelle partie J9 : bâtiments/ouvriers/IA combat fonctionnels, passage âges I–IV.
- Franchissement réel de plusieurs régions (y compris retour et passage de la couture x=511 → x=0), sans duplication d'unité/ressource ni désynchronisation de la caméra.
- Construction et destruction dans région A, voyage dans B, 2–5 minutes de simulation, retour : mêmes états et pertes correctement appliquées.
- Dézoom/zoom, globe, sélection région, sauvegarde au milieu d'une traversée puis reprise de la campagne.
- Passage J9 à J6–J8 (spatioport, vol, débarquement), avec changement de vue avant arrivée.
- Scénario avec adversaire IA + régions multiples et captures FPS/mémoire à ×1, ×4, ×8. Vérifier les alertes hors écran.
- Sauvegarde J1–J8 préexistante lisible et inchangée, aucun bug de commandes tactiles.

## Limites clairement ouvertes

- **Non testé sous Godot ni Android dans cet environnement** : un défaut de compilation ou de comportement peut subsister ; il faudra rejouer les rapports de recette et corriger les échecs avant promotion.
- Les régions sont instanciées **synchroniquement lors du premier accès** ; pas encore de chargement multithread de données/rendu ni garantie de transition sans image lente.
- Le cache des régions habitées conserve une simulation complète à 10 ticks/s ; les grandes colonies (> quelques régions actives) nécessiteront le moteur d'agrégation J12 pour respecter un budget Android mesuré.
- La planète initiale est couverte par ce système. L'extension géographique complète aux planètes de J6–J8 et aux systèmes stellaires relève de J10/J11.
- Océans : traversée terrestre bloquée. Les transports navals interrégionaux ne sont pas intégrés ici.

**Rollback :** conserver le ZIP 0.9.0 et une copie des `user://` Android avant remplacement ; ne pas ouvrir une sauvegarde 0.9.1 avec une 0.9.0.
