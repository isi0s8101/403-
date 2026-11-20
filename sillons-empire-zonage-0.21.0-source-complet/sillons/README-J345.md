# Sillons d’Empire — J3 + J4 + J5 — 0.5.0 candidate

Livraison source complète du 9 novembre 2026, dérivée exclusivement de
`sillons-empire-j21def-0.2.3-source-complet.zip`. L’archive fournie reste intacte.
La branche distincte Age of War J5/J6 n’a pas été fusionnée.

**Statut : implémenté et testé sans affichage dans Godot 4.5.1 ; validation visuelle,
équilibrage, ergonomie et performances Android à effectuer. Aucun APK livré.**
Les jalons J6 (orbital), J7 (interstellaire) et J8 (finalisation) ne sont pas inclus.

## Démarrer

Extraire dans un nouveau dossier et importer `project.godot` dans Godot.
Lancer la scène principale. Deux entrées utiles :

- **Jouer — Escarmouche solo** : départ à l’âge I, progression indépendante jusqu’à VIII.
- **Atelier J3–J5 — essai âge VIII** : bâtiments modernes, unités et ressources disponibles,
  sans IA adverse automatique, pour tester immédiatement les commandes. Sauvegarde autorisée.

Les modèles de véhicules et bâtiments sont procéduraux, originaux et simplifiés.
Ils ne sont pas présentés comme des assets artistiques réalistes finalisés.
Les fusiliers/grenadiers réutilisent le personnage armé et articulé existant.

## Fonctionnalités

| Lot | Fonctionnement |
|---|---|
| J3 — IV/V | Usine, fusilier, obusier, grenadier, académie ; conversion industrielle ; recherches ; sauvegarde/reprise |
| J4 — VI | Char, avion, antiaérien, dépôt, gares, train automatique, aérodrome ; réseau et réserve de ravitaillement |
| J5 — VII/VIII | Radar, lance-missiles, silo, missile retardé, alerte, batterie antimissile ; drone, brouilleur et contre-mesures |
| Transversal | IA étendue, menu de construction défilant, commandes contextuelles, modèles 3D, tests et atelier |

### Progression et industrie

Les trois ressources existantes sont conservées : nourriture, bois et minerai.
L’industrie est une abstraction : chaque usine achevée transforme **2 bois par seconde
contre 1,5 minerai**, seulement si le bois est disponible. Pas de ressource acier ou carburant supplémentaire.

IV demande deux bâtiments hors centre ; V une usine ; VI une académie ; VII un aérodrome ;
VIII un radar. Coûts, temps et objectifs apparaissent dans le panneau d’âge.
Les anciennes unités restent disponibles : les âges coexistent.
Les valeurs de combat restent provisoires ; les bonus antiaériens et anti-véhicules
fournissent des réponses tactiques, sans validation globale de l’équilibrage.

Recherches accessibles en sélectionnant leur bâtiment :

- Usine, IV : outillage, collecte +25 %.
- Académie, V : standardisation, vitesse de production +25 %.
- Usine, VI : blindage, dégâts reçus par les véhicules -20 %.
- Radar, VIII : contre-mesures, efficacité sous brouillage de 85 % au lieu de 50 %.

Une seule recherche technologique simultanée par camp. Une technologie n’est achetable
qu’une fois. Détruire le bâtiment de recherche annule celle-ci sans remboursement.
Le passage d’âge est une recherche séparée.

### Logistique et trains

Centres, dépôts, gares et aérodromes forment automatiquement des liaisons entre voisins
à **24 cases maximum**, avec un chemin praticable de **32 cases maximum**.
Les bâtiments et les passages bloqués peuvent couper ces chemins. Le réseau est recalculé
une fois par seconde de simulation. Une chaîne doit rejoindre un centre achevé.

Les lignes bleues matérialisent la logistique ; les lignes dorées entre deux gares sont
les liaisons ferroviaires. Seul le réseau du joueur est affiché, sur le terrain exploré.
Il s’agit d’un réseau automatique abstrait : pas d’outil de pose manuelle de rails,
ni de cargaisons individualisées, horaires ou réservation des voies.

Un train formé dans une gare circule automatiquement entre une paire de gares reliées.
Il ne peut pas recevoir un ordre de déplacement libre. Une gare détruite ou une rupture
ferroviaire immobilise le train. La nourriture reste un stock de camp ; le train étend
la couverture de ravitaillement dans un rayon de 8 cases, sans caisse de fret simulée.

Véhicules et aéronefs ont une réserve de 100 : elle baisse de 1/s hors ravitaillement.
À moins de 12 cases d’un relais relié au centre, ou de 8 cases d’un train actif, une unité
consomme 1 nourriture/s et récupère 10 points/s, plafonnés à 100. À zéro : vitesse et dégâts
réduits de moitié. L’information apparaît dans la sélection individuelle.

Les avions et drones survolent les obstacles. Les forces terrestres ordinaires ne peuvent
pas tirer sur les aéronefs ; antiaériens et aéronefs le peuvent.

### Missiles et électronique

- Sélectionner un silo → **Missile : 250 minerai** → toucher une position actuellement visible.
- Recharge du silo : 60 s. Impact après 5 s, rayon de 5 cases, dégâts décroissants avec la distance.
- Les dégâts touchent aussi les alliés ; ce sont des armes fictives de gameplay.
- Le défenseur reçoit une alerte. Une batterie prête à moins de 14 cases de la cible
  intercepte un missile, puis recharge 20 s. Plusieurs missiles peuvent saturer cette défense.
- Le radar apporte une vision étendue de 20 cases, augmentée de son emprise selon la règle de vision existante.
- Un brouilleur à 10 cases d’une unité électronique ennemie réduit son efficacité.
  Les brouillages ne se cumulent pas. Le drone et le brouilleur portent ce tag ;
  le radar n’est pas brouillé dans cette version. Les contre-mesures atténuent la pénalité.

### Sauvegarde

Pause → **Sauvegarder**, puis **Charger la sauvegarde**, ou **Reprendre la sauvegarde** au menu.
Un emplacement local versionné `user://sillons-j345.save`, plus une copie précédente `.bak`.
L’écriture passe par un temporaire puis un renommage ; l’intégrité est contrôlée en SHA-256.
Le décodage n’autorise pas d’objets exécutables. Un fichier absent/corrompu/incompatible ne remplace pas
la partie active. La sauvegarde d’une recette de laboratoire est refusée pour conserver ses assertions.

Sont conservés : terrain, entités, ressources, technologies, files, ordres, chemins,
brouillard, état de l’IA, générateur aléatoire, réseau et missiles. Caméra, sélection et panneaux
sont réinitialisés au chargement. Les sauvegardes des anciennes versions ne sont pas migrées.
La copie `.bak` peut être recopiée sur `.save` depuis le gestionnaire de fichiers du dossier utilisateur
Godot sur ordinateur ; aucune fonction de restauration de cette copie n’est exposée dans l’UI.

## Vérifier sur ordinateur

Depuis le dossier extrait, utilisateur standard, avec Godot installé :

```bash
GODOT_BIN=/chemin/vers/godot ./tools/verify-j345.sh
```

Un contrôle graphique MultiMesh est SKIP en mode sans affichage : voir `game-studio/J345-validation.md`.
Les preuves de cette livraison sont dans `game-studio/preuves/j345/` et
`game-studio/preuves/j345-regression/`. Le script recrée des preuves dans `j345-local/`.
Les anciens manifestes J2/J2.1 sont historiques et ne décrivent plus `sim/` après J3–J5.
Le nouveau manifeste est `game-studio/manifest-j345.sha256`.

## Recette Galaxy S25 Ultra

1. Ouvrir l’atelier VIII, balayer le menu de construction et les actions horizontales ; vérifier
   les zones tactiles, le pincement, le déplacement caméra et la sélection sans ordres parasites.
2. Former chaque nouvelle unité ; vérifier silhouette, orientation, mouvement et sélection des aéronefs.
3. Placer deux gares reliées au centre, former un train ; vérifier le trajet, puis couper une liaison
   en combat et contrôler l’arrêt du train et la perte du ravitaillement.
4. Faire sortir un char de la couverture, attendre l’épuisement, puis le ramener près d’un dépôt.
5. Explorer une cible ennemie, tirer un missile ; vérifier l’alerte et les effets. Tester avec puis sans batterie adverse.
6. Tester un drone près d’un brouilleur, avant/après recherche des contre-mesures.
7. Sauvegarder pendant une formation et une recherche, recharger, vérifier la continuité.
8. Jouer une escarmouche complète et vérifier que l’IA progresse. Tester les deux fronts.
9. Relever FPS, temps de simulation, chauffe et réactivité pendant au moins 20 minutes.

**Non mesurés ici :** FPS GPU, consommation mémoire Android, chauffe, autonomie, rendu réel et latence tactile.
Le test deux fronts réalisé dans cet environnement est une vérification d’invariance, pas une mesure Android.
Le SDK Android et les modèles d’export n’étaient pas prêts dans cet environnement : aucun APK exporté.

## Retour arrière

Conserver les dossiers séparés. Réimporter la 0.2.3 fournie pour comparer, ou la dernière version
confirmée sur l’appareil (J2.1 FIX1) pour revenir au fonctionnement connu.
La candidate 0.5.0 ne remplace pas automatiquement la baseline J2 protégée.
