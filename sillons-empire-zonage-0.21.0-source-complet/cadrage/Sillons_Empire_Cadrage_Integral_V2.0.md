# SILLONS D’EMPIRE — CADRAGE INTÉGRAL DU JEU

**Document maître de conception (GDD), d'architecture technique (TDD), d'expérience mobile et de recette — version 2.0**  
**Date de cadrage :** 10 novembre 2026  
**Plateforme cible :** Android, orientation paysage — appareil de validation prioritaire : Samsung Galaxy S25 Ultra  
**Moteur existant :** Godot 4 / GDScript, rendu Mobile, jeu solo hors ligne  
**Baseline à préserver :** `sillons-empire-j678-correctifs-0.8.2-source-complet.zip`  
**Statut :** spécification détaillée et propositions de décisions. **Ce document ne constitue ni un développement J9–J12 ni une validation de fonctionnement Android.**

> **Promesse produit** — Bâtir une civilisation à partir d'un territoire sauvage ; la développer au fil de dix âges ; diriger directement ses batailles et déléguer ses autres fronts ; puis gouverner un empire de planètes, de systèmes stellaires et de routes galactiques, au sein d'un univers immense et cohérent, où le zoom change la représentation **sans réinitialiser le monde**.

## MODE DE LECTURE ET STATUT DES EXIGENCES

- **[EXISTANT 0.8.2]** : mécanisme ou donnée présent dans les sources inspectées ; ne signifie pas qu'il a été compilé, joué ou validé sur Android.
- **[CIBLE]** : comportement à obtenir pour le jeu complet après J9–J12.
- **[DÉCISION PROPOSÉE]** : arbitrage recommandé à adopter, avec migration et validation avant engagement irréversible.
- **[PARAMÈTRE EXPÉRIMENTAL]** : valeur d'équilibrage/de performance hypothétique ; jamais une capacité mesurée ni un standard garanti.
- **[HORS V1]** : fonction exclue de la première version galactique complète, susceptible d'être reprise ensuite.
- **[PORTAIL]** : critère bloquant qui doit réussir avant de qualifier une livraison.

### Inventaire exact du socle

| Domaine | Réalité identifiée dans les sources 0.8.2 | Limite majeure |
|---|---|---|
| Simulation | `Rules.TICK_RATE = 10`, campagne à pas fixe, `MAP_SIZE = 96`, deux camps, escouades de six | Pas de cartographie planétaire géante à chunks |
| Économie | Nourriture, bois, minerai ; âges, constructions et recherches | Stocks partagés entre les cartes d'un camp : logistique interplanétaire abstraite |
| Progression | Âges I–X définis ; bâtiments et unités associés | Équilibrage complet encore non confirmé en jeu |
| Spatial | `StarCampaign`, Val des Deux Gués, Aurore (système Sol), Némésis (système Proxima), navettes, frégates, satellites, vols | Trois secteurs prédéfinis, pas de génération de galaxie jouable |
| Commandement | IA, ordres, siège, deux fronts, interface tactile, laboratoires | Pilotage galactique et gestion d'alertes à grande échelle à créer |
| Robustesse | Sauvegarde de campagne, `.bak`, empreinte SHA-256, contrôles de recette, cinq vitesses | Compilation Godot, APK et essai sur S25 Ultra non démontrés dans cette livraison |
| Visuels | Scènes 3D, matériaux PBR, UI mobile existante | La performance et l'ergonomie ne sont pas certifiées sur appareil |

**Règle de compatibilité** : ne pas transformer ces intentions en affirmations de fonctionnalités déjà développées. Le nouveau système doit adapter la 0.8.2, conserver un mode « campagne héritée » et fournir des migrateurs plutôt que modifier silencieusement les sauvegardes.

---

# PARTIE A — PRODUIT, EXPÉRIENCE ET CONTRAT DE JEU

## 1. Identité, genre et proposition de valeur

**Genre principal :** RTS de développement, conquête, production et commandement militaire en temps réel. **Sous-genres :** grande stratégie, exploration spatiale, simulation logistique et gestion d'empire. L'interface et la partie ne sont pas un « 4X au tour par tour » : les décisions et les combats continuent en temps réel ; une pause et le commandement délégué évitent la surcharge.

**Invariants d'identité :**
1. **L'univers est unique et persistant** : toutes les cartes représentent une partie du même monde logique.
2. **Le joueur peut toujours intervenir** au niveau tactique lorsque des forces terrestres sont présentes ; les vues hautes ne remplacent pas l'action locale.
3. **Chaque échelle est jouable** : planète, orbite, système et galaxie disposent d'ordres, de risques, de ressources et de conflits propres.
4. **Dix âges et pas davantage** : les extensions J9–J12 approfondissent les échelles, sans ajouter d'âges XI–XIV.
5. **Deux camps avancent librement** : aucune synchronisation obligatoire des âges ; des écarts technologiques extrêmes sont autorisés.
6. **Le jeu reste intégralement jouable hors ligne**, sans connexion, compte ni microtransactions pour le mode de référence.
7. **Le mobile est la cible originelle** : jamais une interface PC réduite a posteriori.
8. **Les pertes et décisions ont des conséquences** : on ne duplique pas une armée en la faisant passer d'une carte à l'autre.
9. **L'IA et le joueur obéissent aux mêmes règles de connaissance, de coût et de transit** dans le mode équitable.
10. **La stabilité prime sur la taille affichée** : le joueur doit pouvoir finir une campagne, la sauvegarder et la reprendre avant de déployer une galaxie plus dense.

**Différenciation recherchée :** le même joueur peut suivre une escouade de lanciers, construire une capitale, surveiller un continent, déplacer une flotte vers une lune puis visualiser un corridor de guerre galactique — avec la même simulation sous-jacente et la même chaîne d'ordres.

**Expérience émotionnelle :** progression tangible (humble campement → empire), découverte (planètes inconnues), responsabilité (choix logistiques), puissance (flottes), tension (offensives sur plusieurs fronts) et satisfaction d'une stratégie lisible, jamais uniquement d'un clic répétitif.

## 2. Modes de jeu et durée des sessions

| Mode | Cible | Particularités | Statut |
|---|---|---|---|
| **Escarmouche classique** | Entrer vite en partie | Une région ou planète, deux camps, âges configurables, victoire locale | [CIBLE] héritier du RTS actuel |
| **Conquête galactique** | Mode principal longue durée | Départ à l'âge I, expansion jusqu'à l'âge X, plusieurs systèmes ; sauvegarde multi-session | [CIBLE] J9–J12 |
| **Partie rapide** | 20–45 min visées | Carte plus compacte, accélération de coûts/recherches, objectif local | [PARAMÈTRE EXPÉRIMENTAL] |
| **Campagne standard** | 1–3 h visées | Dix âges, région de départ, galaxie compacte, 2–4 grands fronts actifs | [PARAMÈTRE EXPÉRIMENTAL] |
| **Campagne épique** | 6 h et plus, réparties en sessions | Galaxie dense, économie locale, IA avancée, nombreuses colonies | [CIBLE], non garantie en V1 |
| **Observateur IA vs IA** | Équilibrage et spectacle | Deux IA autonomes, panneau explicatif des décisions, accélération | [EXISTANT partiel], à étendre |
| **Laboratoire / recette** | Développeur, recette Android | Seed fixe, préconfiguration, commandes scriptées, replay, assertions et rapports | [EXISTANT partiel], à étendre |
| **Tutoriel scénarisé** | Initiation sur tactile | Modules de 5–10 minutes, progression graduelle, contexte prérempli | [CIBLE] |

**[HORS V1]** : multijoueur réseau, matchmaking, économie réelle, cloud obligatoire, mods exécutables téléchargés, éditeur communautaire complexe, simulation physique astrophysique de précision, flotte intergalactique jouable. Le jeu ne doit pas attendre ces fonctions pour être complet.

### Paramètres de lancement

- Nom et seed de campagne, difficulté IA, taille de galaxie, nombre de camps (deux à la livraison initiale ; davantage seulement après validation des coûts), âge de départ, densité économique, niveau de brouillard, profil de vitesse, agressivité IA, fréquence de sauvegarde, règles de victoire.
- Sélections « rapide », « équilibrée », « épique » visibles ; options techniques avancées repliées pour éviter de surcharger le menu.
- Prévisualisation d'une carte **informative mais non omnisciente** : type de planète de départ et densité approximative ; les gisements ennemis et forces adverses restent cachés.
- Toute option non éprouvée est étiquetée « expérimental » ; aucun curseur de densité ne promet un nombre d'unités que l'appareil ne soutient pas.

## 3. Cadre fictionnel, cohérence des âges et identité du monde

**[DÉCISION PROPOSÉE]** : univers de civilisation uchronique / science-fiction, indépendant d'une chronologie terrestre réelle. Les noms hérités « Val des Deux Gués », « Aurore », « Némésis », « Sol » et « Proxima » sont conservés dans la carte de référence. Les nouvelles campagnes utilisent des noms générés selon un corpus contrôlé et reproductible.

- Les dix âges représentent la **capacité techno-industrielle de chaque camp**, non dix ères universelles imposées à toutes les factions.
- Une planète désertique n'a pas besoin de posséder une économie forestière miraculeuse : la génération garantit une substitution jouable, des réserves initiales ou une mécanique d'importation clairement annoncée.
- Le passage du monde médiéval au monde orbital doit être visible dans les bâtiments, voies de transport, armes, silhouettes et impacts environnementaux.
- Les anciennes fortifications, routes, villes et ruines sont conservées ; la carte ne se recompose pas lors d'un âge.
- Pas de scénario linéaire obligatoire : les événements de découverte et points d'intérêt peuvent donner une couleur narrative, mais n'empêchent jamais de jouer une escarmouche autonome.

## 4. Boucles de jeu par horizon de décision

**Chaque 5–20 secondes :** observer, sélectionner, ordonner une escouade, affecter un ouvrier, réagir à une attaque, consulter une alerte.  
**Chaque 1–5 minutes :** créer une chaîne de production, sécuriser un gué, lancer une recherche, ravitailler un front, protéger un convoi.  
**Chaque 5–20 minutes :** choisir un âge, ouvrir un nouveau front, fonder une colonie, déployer des défenses orbitales, décider quelle planète spécialiser.  
**Chaque 20–60 minutes :** franchir une frontière systémique, réorienter l'empire, soutenir une guerre lointaine, établir une nouvelle route interstellaire.

**Boucle générale :** explorer → observer les contraintes → récolter/produire → construire et sécuriser → rechercher → arbitrer attaque/défense → commercer/ravitailler → étendre → préserver la continuité de l'empire.

### Exemples de choix avec compromis réels

- Augmenter le débit d'une usine réduit les ressources disponibles pour une recherche.
- Traverser une montagne rallonge l'approvisionnement ; contourner par une rivière exige une infrastructure.
- Déplacer les meilleures unités vers une planète affaiblit le front d'origine pendant la durée du trajet.
- Construire une flotte sans logistique orbitale permet la puissance initiale, mais compromet la durée de la campagne.
- Une offensive interstellaire peut laisser un corridor commercial vulnérable ; un commandant délégué peut défendre ce corridor au prix d'une moindre concentration offensive.

## 5. Conditions de victoire, défaite et fin de partie

### Règle centrale

**[CIBLE]** Un camp est **définitivement éliminé** quand il a perdu **tous ses centres de commandement, sur toutes ses possessions, ET toutes ses forces réellement capables d'en reconstruire un**. L'existence d'un ouvrier embarqué, d'une colonie en fondation ou d'un convoi transportant un module de construction compte **si** ces moyens peuvent effectivement rejoindre un site viable avec les ressources et la logistique nécessaires. Une frégate armée mais incapable de construire ne suffit pas.

**[EXISTANT 0.8.2]** : la source comporte un délai de reconstruction de 180 secondes et des règles de capacité de reconstruction. Cette mécanique doit être harmonisée avec l'invariant galactique pour éviter un élimination erronée lorsque le seul reconstructeur est en transit interstellaire. **[DÉCISION PROPOSÉE]** : calculer la capacité de reconstruction sur le graphe global et n'appliquer un compte à rebours terminal qu'en l'absence de solution viable ou dans un mode spécifique annoncé.

**Victoire par conquête totale (par défaut) :** la dernière faction capable de reconstruire ses centres gagne.  
**Victoire par domination (option) :** contrôler simultanément un pourcentage paramétrable de centres stratégiques, puis tenir un compte à rebours visible ; toute contestation documentée annule ou suspend ce compteur.  
**Victoire par objectifs (laboratoire) :** détruire un fort, défendre une colonie pendant N ticks, livrer un convoi, sécuriser un corridor.  
**Abandon :** confirmation explicite ; ne jamais effacer la dernière sauvegarde par l'abandon.

**Prévention des impasses :** détecter les campagnes sans aucune trajectoire de reconstruction/attaque, proposer un diagnostic et une fin de partie négociée dans les modes non compétitifs, sans tuer artificiellement une faction encore viable.

## 6. Difficulté, équité et accessibilité stratégique

- **Initiation :** IA plus lente à coordonner, infobulles et alertes accompagnées, autosauvegarde fréquente ; même coût des unités.
- **Normal :** IA équilibrée, connaissance de terrain uniquement exploré, adaptation limitée et lisible.
- **Difficile :** planification multi-fronts, contre-espionnage, meilleure efficacité des routes et du ravitaillement.
- **Expert :** IA optimisant plusieurs objectifs simultanés, grandes campagnes, sans capacités de vision cachées.
- **Bonus de ressources optionnel uniquement** : si activé, affichage permanent d'un modificateur explicite ; ne jamais le présenter comme difficulté purement tactique.

La difficulté ne doit pas être définie par un simple multiplicateur de PV/dégâts. Les profils seront jugés sur équité, diversité des stratégies, durée et possibilité de contre-jeu.

---

# PARTIE B — PROGRESSION, FACTIONS, TECHNOLOGIES ET ÉCONOMIE

## 7. Progression des dix âges : objectifs et identité de jeu

| Âge | Intention dominante | Économie/infrastructures | Armée/renseignement | Décision structurante |
|---|---|---|---|---|
| **I Exploration** | Survivre et connaître sa vallée | Centre, ouvriers, ferme, entrepôt, maison, caserne | Éclaireur, lancier, brouillard | Où fonder la première chaîne de récolte ? |
| **II Commerce** | Connecter et sécuriser | Marché, relais, caravane, routes commerciales | Tireur, cavalier, escorte | Protéger le commerce ou produire la guerre ? |
| **III Forteresses** | Tenir le terrain et assiéger | Fort, palissade, atelier, gués stratégiques | Canon, guerre de position | Quel passage peut briser un front ? |
| **IV Industrie** | Industrialiser | Usine, chaînes de production, outillage | Fusilier, obusier | Économie ou production militaire ? |
| **V Empire** | Standardiser et centraliser | Académie, recherche, gouvernance | Grenadier, doctrine organisée | Spécialisation ou flexibilité ? |
| **VI Mécanisation** | Projeter la puissance | Dépôt, gare, aérodrome, rail | Char, avion, défense AA, train | Le réseau de ravitaillement supporte-t-il l'offensive ? |
| **VII Dissuasion** | Gérer menace et profondeur | Radar, silo, intercepteur | Missiles, reconnaissance à longue portée | Frapper ou intercepter, et à quel coût ? |
| **VIII Numérique** | Disputer l'information | Réseaux, contre-mesures | Drone, brouilleur, capteurs | Quel front connaît réellement la situation ? |
| **IX Ère orbitale** | Sortir de sa planète | Spatioport, satellite, station/colonie | Navette, reconnaissance orbitale | Où établir la première tête de pont ? |
| **X Ère interstellaire** | Tenir des systèmes | Chantier, réseau stellaire, flotte | Frégate, convois intersystèmes | Concentrer les flottes ou protéger l'empire ? |

**[EXISTANT]** : les noms et une partie de ces unités/bâtiments figurent dans `sim/rules.gd`. **[CIBLE]** : spécialisation, doctrine, infrastructures locales, stations détaillées, réseaux intersystèmes et décisions d'empire complètes.

### Contrat de passage d'âge

Un âge N+1 ne s'obtient que si : (a) objectifs satisfaits, (b) coût réservé atomiquement, (c) site/recherche requis disponible, (d) temps de recherche écoulé, (e) camp vivant. Les autres camps et les fronts continuent pendant cette attente. Annuler une recherche applique une règle de remboursement explicite, jamais un remboursement tacite différent selon la carte.

Les conditions existantes constituent le jeu de départ ; leur révision doit conserver une table de migration et une grille de tests pour chaque âge. Les paliers ne doivent ni supprimer les unités déjà produites, ni remplacer gratuitement leurs bâtiments, ni remettre à zéro les files de production.

### Spécialisations horizontales sans nouvel âge

**[CIBLE]** Chaque âge à partir de IV peut proposer une ou deux **doctrines à bénéfice/counterpart** : industrie « volume » ou « qualité », armée « mobilité » ou « défense », conquête « flotte » ou « colonies ». Une doctrine ne bloque pas arbitrairement le jeu ; elle ouvre une spécialisation et crée un coût de changement. Priorité J12 seulement après validation des boucles historiques, pour ne pas multiplier simultanément les variables de balance.

## 8. Classes d'unités et bâtiments

**Unités historiques** : ouvriers, éclaireurs, lanciers, tireurs, cavaliers, canons, caravanes.  
**Industrie et mécanisation** : fusiliers, obusiers, grenadiers, chars, avions, véhicules AA, trains.  
**Numérique** : lance-missiles, drones, brouilleurs.  
**Spatial initial** : navettes et frégates.  
**[CIBLE] Extensions proposées** : transports maritimes/amphibies, éclaireurs orbitaux, cargos longue distance, intercepteurs spatiaux, vaisseaux de soutien, vaisseaux de colonisation, drones miniers. Ils doivent tous être justifiés par une boucle de jeu distincte et ne sont pas « déjà dans la 0.8.2 ».

Chaque type possède : ID stable ; âge et prérequis ; coût et délai ; population/équipage ; santé/armure ; mobilité ; emport/capacité ; distance de vision/détection ; résistance et vulnérabilités ; alimentation logistique ; catégorie de collision ; gabarits visuels LOD ; commandes admissibles ; descriptions tactiles ; version d'équilibrage. Les unités ne peuvent changer d'ID à la suite d'une traduction ou d'un changement de sprite.

### Rôle des bâtiments

- **Production** : ferme, usine, caserne, aérodrome, chantier ; les files respectent capacité, ressources réservées, débit et éventuel réseau logistique.
- **Économie** : entrepôt, marché, relais, dépôt, centre orbital de stockage ; les biens possèdent une localisation.
- **Défense** : centre, fort, mur, radar, intercepteur ; détection et protection ne sont pas assimilées à des dégâts directs.
- **Sciences/âge** : académie, laboratoire, spatioport et chantier ; les recherches sont conservées à l'échelle du camp, mais leurs équipements restent locaux.
- **Commandement** : centres de commandement et relais ; leur perte pénalise le contrôle, pas nécessairement la possibilité immédiate de donner des ordres locaux si une chaîne secondaire existe.

### Capacité de population

**[CIBLE]** Différencier : population civile, équipages des véhicules, capacité de logement **locale**, capacité de soutien/logistique d'une colonie, et éventuellement plafond global de performance configurable. L'embarquement réserve des places ; le voyage conserve l'identité des unités ; un débarquement surchargé attend en orbite ou demande une infrastructure, sans apparition gratuite ni disparition. Le plafond local ne doit pas être contourné en changeant de vue.

## 9. Économie détaillée et ressources

### Ressources historiques à préserver

- **Nourriture (`food`)** : travailleurs, recrutement, entretien de l'expansion et coûts de certaines troupes.
- **Bois (`wood`)** : construction, palissades, infrastructure de base.
- **Minerai (`ore`)** : armes, industrie, électronique, véhicules et spatial.

Les trois ressources restent les **unités comptables canoniques de la V1**, même pour les technologies avancées. Les sous-produits raffinés peuvent être représentés initialement par **capacités de transformation** plutôt que par six nouveaux portefeuilles visibles.

### Passage des stocks partagés aux stocks locaux

**[EXISTANT]** : `StarCampaign.resources[team]` est partagé entre les secteurs.  
**[DÉCISION PROPOSÉE]** : introduire progressivement un grand livre par emplacement : `stock[team][location][resource]`, puis un **total impérial en lecture seule** = somme des stocks locaux + quantités en transit réservées (affichées séparément). Le stock total **n'est pas librement dépensable** depuis une planète distante : un transfert nécessite un trajet et des moyens de transport.

**Règles comptables impératives :**
1. Une ressource ne peut avoir qu'un propriétaire et un emplacement (stock, cargaison, réserve de commande ou bien consommé).
2. Un ordre valide réserve son coût **une seule fois** avant démarrage.
3. Une annulation crédite uniquement la portion remboursable selon l'état d'avancement.
4. Une cargaison détruite est débitée définitivement ; les rapports expliquent la perte.
5. Un transit arrivé ne peut être crédité qu'une fois (identifiant d'événement unique/idempotence).
6. Un stock négatif hors dette explicitement modélisée constitue une erreur de simulation, non un mécanisme toléré.
7. Un transfert est enregistré au tick de départ et finalisé au tick d'arrivée ; la caméra ne change jamais son résultat.

**Migration** : affecter le stock historique au secteur d'origine du camp, ou à un dépôt impérial fictif et transférer une fois ; ne jamais cloner la même ressource sur toutes les planètes. Cette option doit figurer dans un schéma versionné et un rapport de migration.

### Production, transformation et chaînes

**Production nette** par ressource et emplacement = récoltes + fabrications + importations − consommations − exportations − pertes ; chaque terme est journalisé.  
**Capacité industrielle** : vitesse de transformation bornée par matières premières, main-d'œuvre disponible, énergie/infrastructure (capacité de fonctionnement) et ravitaillement.  
**Énergie [CIBLE]** : d'abord une **capacité de réseau** de la colonie (kW abstraits, seuils, pannes), pas nécessairement une monnaie globale supplémentaire. La production sans réseau fonctionne à débit réduit lorsque cela a un sens.  
**Recherche [CIBLE]** : produit scientifique localement, mais avancées acquises au camp ; la connaissance se partage, les machines ne se téléportent pas.

### Exemple chiffré illustratif — non figé

Un port spatial local a 1 000 minerai ; lancer un transport réserve 350 minerai ; il reste 650 utilisables ; 120 minerai chargé dans un cargo passent du stock au transit ; à l'arrivée la planète B gagne 120 minerai, la planète A reste inchangée ; si le cargo est détruit, la perte est 120, non 240. Le total impérial vérifié doit correspondre à ce bilan à chaque tick.

## 10. Commerce, marchés et routes

- **Commerce terrestre** : caravanes entre marchés/relais, bonus lié à la distance mais diminué par risque et temps d'immobilisation, escortes et sécurité des routes.
- **Échanges internes** : stocks déplacés réellement, rendement des voies et capacités des dépôts.
- **Échange au marché** : taux transparent, évolutif dans des bornes connues ; éviter l'arbitrage infini (acheter/revendre pour générer de la richesse sans perte).
- **Commerce interplanétaire** : liaisons navette et cargos ; fenêtre de lancement abstraite, capacité d'emport, fuel/coût, exposition aux interceptions.
- **Commerce galactique** : réseau de corridors, hubs, prix/bonus éventuels propres au système, interdictions et embargos uniquement si une mécanique diplomatique exploitable les accompagne.

### Graphe logistique

Nœuds : dépôt, gare, port, station, planète, système ; arêtes : route, rail, vol orbital, voie interplanétaire, saut stellaire. Chaque arête possède coût, capacité par intervalle, délai, risque détecté, visibilité et autorisation. Un planificateur choisit le chemin selon objectif (« plus rapide », « plus sûr », « moins cher ») et non selon le plus court segment géométrique seul. Les itinéraires impossibles doivent produire un motif visible : `NO_PATH`, `NO_CAPACITY`, `NO_FUEL`, `FOG_UNKNOWN`, `HOSTILE_BLOCKADE`.

## 11. Recherche, technologies et risque de blocage

- **Prérequis visibles** dans un arbre compact, en une ou deux étapes, jamais une arborescence de cinquante icônes sur smartphone.
- **Trois catégories** : économie (productivité), militaire (protection/specialisation), stratégique (détection, transit, colonisation).
- **Découplage technologie / capacité matérielle** : savoir construire une frégate ne la construit pas automatiquement, et un spatioport hors ravitaillement ne peut pas en produire une à pleine cadence.
- **Anti-impasse** : chaque âge doit rester atteignable sur une carte de départ valide ; les objectifs indispensables ne peuvent dépendre d'une ressource impossible à obtenir ou d'une unique case inaccessible.
- **Coût d'opportunité** : la recherche occupe une file et des ressources, au lieu d'être un bouton gratuit. Les recherches perdues après destruction d'un bâtiment restent connues si elles étaient terminées ; une recherche en cours suit une politique explicite de suspension/reprise.
- **Doctrine asymétrique** : une technologie ancienne peut offrir une utilité spécialisée à un âge avancé sans faire d'une lance l'égal d'un missile orbital.

---

# PARTIE C — GÉOGRAPHIE PROCÉDURALE ET UNIVERS MULTI-ÉCHELLE

## 12. Modèle du monde : une simulation, plusieurs représentations

La **structure autoritative** de l'univers suit la hiérarchie `Campagne > Galaxie > Système > Corps céleste > Région > Chunk > Entité`. Un « écran » n'est pas une carte logique séparée : c'est une **vue** sur les entités de l'univers, avec un référentiel et un niveau de détail adaptés.

**Niveaux jouables** :

1. **Tactique** — site de construction et de combat : unités précises, pathfinding local, occupation, bâtiments, tirs et travaux.
2. **Planétaire** — globe et régions : sélection de front, armée, ressource stratégique, route, colonie, climat, ordre de mouvement à grande distance.
3. **Orbital** — autour d'une planète : stations, satellites, fenêtres de transit abstraites, menace, défense de débarquement.
4. **Système stellaire** — ensemble des corps autour des étoiles : flottes, itinéraires, ceintures d'astéroïdes, opérations lunaires, zones d'interception.
5. **Galactique** — graphe de systèmes jouables : exploration, routes, frontière et guerre interstellaire.
6. **Atlas des galaxies** — choix initial de seed/galaxie, **non jouable militairement en V1**. Ce sixième écran n'est pas un niveau de simulation supplémentaire.

**Contrat d'identité** : un ouvrier possède un ID unique, un camp, un emplacement (`sector/planet/flight`), une santé, un état d'ordre et une position locale ou un itinéraire. Le dézoom peut remplacer son modèle visible par un symbole de groupe ; il ne change aucun de ces attributs.

### Référentiels de coordonnées

- **Galaxie** : positions entières ou quantifiées de systèmes dans un repère galactique d'unité abstraite, pour les stratégies de routes.
- **Système** : repère stellaire centré sur l'étoile principale, positions orbitales de présentation et distances de gameplay.
- **Planète** : `planet_id`, coordonnées géodésiques quantifiées (latitude/longitude) et identité d'une face pour un maillage sphérique ; l'altitude est secondaire.
- **Région** : repère tangent local en mètres virtuels et origine recalée près de la caméra pour limiter les erreurs de précision.
- **Chunk** : indices entiers signés, cellules locales ; jamais une clé fondée sur le nom visible.
- **Entité** : ID 64 bits stable, emplacement typé et coordonnées dans le repère courant ; conversion contrôlée par un service unique.

**Invariants de conversion** : aller d'un chunk vers le globe puis revenir à la même position produit la même entité et la même région ; les coutures entre faces du globe sont parcourables ; aucune dérive due aux changements d'origine flottante ; pas de saut de simulation associé au passage d'un seuil de zoom.

## 13. Navigation par dézoom : comportement précis

### Gestes et seuils

Le joueur commence en vue tactique. Un **pinch-out** agrandit la zone visible jusqu'à une **zone de transition** ; l'image passe progressivement d'une carte détaillée à une région puis à une sphère. En continuant, il atteint l'orbite, le système, enfin la galaxie. Un pinch-in effectue le chemin inverse. Les transitions ne doivent pas se déclencher sur le moindre geste involontaire.

**[PARAMÈTRES EXPÉRIMENTAUX]** : bande de transition de 15–25 % de l'intervalle de zoom, temporisation/hystérésis de 100–200 ms, réouverture du contexte précédent si aucun nouvel objet n'est ciblé, animation 200–450 ms sauf option « réduire les animations ». Le prototype doit tester ces valeurs avec une seule main, doigts humides et interactions répétées.

### Règles de transition

- Avant changement, mémoriser `view_state = {layer, target_id, center, zoom, rotation, selection_ids, open_panel, timestamp}`.
- Afficher l'échelle cible sur le bord de l'écran dès l'entrée dans la bande de transition.
- Précharger les données nécessaires, puis préparer un remplacement visuel (crossfade/mesh globe/LOD) ; ne jamais arrêter la simulation durant ce remplacement.
- Conserver les sélections valides en tant que **sélections distantes** (icônes/localisation), sans faire croire qu'une armée située sur Mars se trouve à l'écran tactile de la Terre.
- Afficher « Retour à l'unité » et un fil d'Ariane : `Galaxie > Système > Planète > Région`.
- Un zoom sur une planète inexplorée affiche seulement ce que le camp sait ; les détails géographiques publics peuvent être visibles selon la technologie cartographique, les installations ennemies restent occultées.
- Les touches d'ordre sont neutralisées pendant le court passage de scène pour éviter qu'un ordre terrestre soit envoyé à un vaisseau spatial.
- Un retour après alerte ouvre le secteur et le point temporel **actuel**, pas l'image obsolète à l'origine de l'alerte.

**Cas limites obligatoires** : zoom pendant combat, bombardement, embarquement, destruction d'un bâtiment, unité morte, arrivée de cargo, planète récemment conquise, sauvegarde en cours, notifications multiples et Android mis en arrière-plan.

### Sélecteur de vue explicite

En complément du zoom, un sélecteur compact « Région / Planète / Système / Galaxie » est toujours disponible pour les utilisateurs qui ne souhaitent pas effectuer de longs gestes. Il peut être opéré à la voix d'accessibilité Android via son libellé, sans recours à une icône non décrite.

## 14. Génération galactique : architecture, paramètres, garanties

### Trois niveaux de densité

**[DÉCISION PROPOSÉE]** : distinguer visuellement des **étoiles d'arrière-plan** et les **systèmes interactifs**, plutôt que prétendre simuler physiquement chaque point lumineux.

| Profil | Systèmes interactifs visés | Étoiles décoratives potentielles | Statut |
|---|---:|---:|---|
| Compact | 16–32 | ~500–2 000 | [PARAMÈTRE EXPÉRIMENTAL] |
| Standard | 48–128 | ~2 000–10 000 | [PARAMÈTRE EXPÉRIMENTAL] |
| Étendu | 256–1 024, générés à la demande | ~10 000–50 000 | [PARAMÈTRE EXPÉRIMENTAL / objectif de charge] |

Ces nombres décrivent des **dimensions de contenu**, pas des performances démontrées. Un très grand graphe stellaire peut exister sous forme de données générées à la demande sans être simultanément simulé ni affiché. Le profil standard sera figé après un banc de charge.

### Processus de génération

1. À partir de la seed maître, calculer une graine stable par catégorie (`layout`, `names`, `resources`, `factions`, `points_of_interest`).
2. Choisir une topologie de galaxie fictive cohérente : disque, bras, amas, régions moins denses, cœur ; séparer aspect spectaculaire et véritable connectivité.
3. Placer les systèmes à partir de cellules spatiales indexées, avec distance minimale paramétrable ; aucun placement ne doit dépendre de l'ordre de visite.
4. Attribuer types stellaires et composition des systèmes sans formule astrophysique lourde ; conserver quelques corrélations crédibles (environnement, fréquence de corps, ressources).
5. Construire un **graphe de routes navigables** sur les systèmes jouables ; imposer connectivité des zones de départ et chemins alternatifs lorsque la carte l'autorise.
6. Introduire points de passage obligés, anomalies et corridors risqués mais fournir des contre-stratégies ; éviter qu'un unique verrou impossible bloque la campagne.
7. Placer les camps selon équité de ressources, potentiel d'expansion et délai de premier contact, non seulement selon une distance euclidienne.
8. Définir la connaissance initiale de chaque camp, distincte du contenu réel de la galaxie.
9. Produire un **rapport de validation de seed** (connectivité, accessibilité, nombre de corps colonisables, distances, richesse, risque).

### Découverte et frontières

L'espace inconnu n'est pas vide par défaut : un capteur ou un éclaireur en révèle progressivement les caractéristiques. Un système **détecté** peut ne pas être **cartographié** ; ses installations ne deviennent **connues** qu'après renseignement. Les frontières affichées sont des zones d'influence ou contrôles d'infrastructure ; elles ne changent pas la propriété d'une planète sans action de conquête.

### Points de passage et routes

Chaque arête du graphe possède `edge_id`, endpoints, durée minimale, coût/carburant, limite de débit, rayon d'interception abstrait, niveau de danger, état de blocage et confiance du renseignement. Un calcul d'itinéraire ne peut révéler des routes inconnues via son résultat ; la recherche de chemin utilise uniquement le graphe connu de la faction, puis la simulation découvre l'échec ou la réussite du plan.

## 15. Génération des systèmes stellaires

**Composants générés** : étoile(s), planètes, lunes, anneaux, ceintures d'astéroïdes, points d'intérêt, stations neutres, zones de transit, routes d'approche, conditions logistiques. Les orbites sont **modélisées pour le gameplay** (positions évolutives ou périodiques approximées), **pas** par un simulateur gravitationnel N-corps.

**Ordres possibles à cette échelle** : observer, affecter une flotte, patrouiller, escorter, intercepter, ravitailler, miner des astéroïdes, défendre un point orbital, établir un blocus, préparer un débarquement, installer une station, transférer des unités et choisir une autre planète.

**Conséquences des distances** : coût, délai, exposition, fenêtres tactiques ; pas de téléportation instantanée par changement de carte. Les positions de présentation et les calculs d'ETA doivent être dérivés du même trajet logique, avec une tolérance de visualisation explicite.

### Cartes de système réellement jouables

Une carte de système propose des ordres directs de flotte, une sélection d'orbite, des marqueurs de cargos en transit, une chronologie des trajets, une couverture de capteurs et une carte des risques. La vue étoile n'est pas un simple écran de sélection des planètes ; un siège orbital et un convoi intercepté doivent pouvoir s'y dérouler sans ouvrir une scène de combat différente.

## 16. Planètes immenses : génération et topologie

### Modèle recommandé

**[DÉCISION PROPOSÉE]** : représentation globe stratégique **cube-sphere / faces de quadtree**, avec terrains tactiques heightmap continus sur patches locaux. Les coordonnées logiques et seeds d'altitude sont indépendantes du maillage rendu. Cette solution privilégie un globe visible et des régions immenses streamées, sans lancer un moteur voxel destructible complet.

**Pourquoi pas une seule heightmap gigantesque ?** Une planète de plusieurs millions de cellules de côté exploserait les budgets mémoire, bande passante et sauvegarde ; une grille unique fixe rendrait aussi les transitions planétaires et les changements de résolution difficiles. On génère donc **les portions demandées** tout en conservant une fonction mondiale cohérente.

### Pipeline de génération planétaire

1. **Identité physique abstraite** : diamètre narratif, gravité relative, type rocheux/glacé/désertique, atmosphère, fraction d'eau, activité géologique.
2. **Macrogéographie** : continents, plaques fictives, lignes de côtes, bassins, chaînes de montagnes, zones volcaniques, mers intérieures, goulets.
3. **Climat** : latitude, altitude, proximité d'eau, vents simplifiés, gradients de pluie, température et éventuels effets saisonniers.
4. **Hydrologie** : bassin versant et direction d'écoulement calculés à résolution grossière, rivières et lacs projetés dans les chunks fins ; les rivières ne montent pas arbitrairement en amont.
5. **Biomes** : forêts, plaines, toundras, déserts, marécages, côtes, montagnes, roches extraterrestres crédibles ; limites progressives, pas de transitions carrées visibles.
6. **Ressources** : densités corrélées à géologie, végétation, accès et risques ; ressources stratégiques rares, stocks de départ garantis.
7. **Traversabilité** : pente, eau, nature du sol, obstacles, gués, passages, coûts de construction, ponts, routes.
8. **Points d'intérêt** : ruines, gisements, détroits, plaines défensives, emplacements de villes, anomalies et stations préexistantes si cohérents.
9. **Implantation** : départs équilibrés, zones constructibles, rayon initial accessible, ressources de progression et trajet viable jusqu'à un premier objectif.
10. **Décoration** : arbres, buissons, herbes, rochers, débris, traces et effets locaux ; toutes les décorations purement visuelles sont reconstruisibles depuis le même seed.

### Cohérence entre globe et terrain

Une chaîne de montagnes visible en vue globe existe au même emplacement tactique ; un fleuve représenté sur la carte régionale traverse la géométrie de terrain réelle ; une ville bâtie localement apparaît sur la carte planétaire en tant que marqueur. Le rendu peut **généraliser visuellement** un détail trop petit, mais ne peut inverser sa nature (mer devenue terrain sec, montagne devenue passage plat) lors d'un zoom.

### Forme et taille des chunks

**[PARAMÈTRE EXPÉRIMENTAL]** : chunk logique de 64×64 cellules à l'échelle tactique, avec cellule héritée de l'ordre de ~2 m visuels ; maillage simplifié à résolution 64/32/16/8 selon LOD. Les nombres ne constituent pas une dimension physique unique pour la planète : le moteur coordonne plusieurs niveaux d'échelle, y compris un maillage du globe beaucoup plus grossier. La taille et les rétentions de chunks seront fixées après profilage du S25 Ultra.

**Propriétés du chunk** : `planet_id`, `face_id`, `level`, `chunk_x`, `chunk_y`, `generator_version`, `terrain_hash`, `modifications`. Le générateur respecte les bordures partagées, fournit un masque de navigation et reste identique sous toute séquence de chargement.

### Gouvernance de la génération

Le générateur sépare 1) données essentielles de navigation et ressources, 2) matériaux et relief visuel, 3) décor à densité variable. **Réduire la qualité graphique** ne doit jamais modifier la connectivité d'une rivière ou l'emplacement d'un gisement réel.

## 17. Streaming, niveau de détail et persistance du terrain

**États d'un chunk :** `ABSENT` → `REQUESTED` → `GENERATING` → `READY_DATA` → `READY_RENDER` → `VISIBLE` → `DORMANT` → `EVICTED`. L'éviction libère les meshes, textures dérivées et caches ; elle **ne supprime pas** les données de simulation ni les modifications persistées.

### Politique de priorité

1. Zone sous la caméra et point ciblé par un ordre.
2. Zone où une armée ou un débarquement actif exige une représentation.
3. Anneau de préchargement selon mouvement caméra/zoom.
4. Miniatures ou LOD voisins.
5. Décor lointain sans interaction immédiate.

**Borne mémoire** : cache avec poids en octets (mesh, textures, collisions, données), LRU tenant compte des chunks épinglés par bataille/travaux et éviction graduée. Ne jamais mettre les queues de streaming en concurrence avec le tick critique sans quota temporel.

### Modifications du joueur

- **Delta terrain** : excavations mineures, tranchées, routes, ponts et destructions prévues par les règles ; impact physique limité et performant.
- **Construction** : bâtiment avec ID, propriétaire, position, état, points de vie, file de production, accès réseau et historique de dégâts.
- **Ressources épuisées** : quantité restante et état de régénération, indépendants du rendu de l'arbre.
- **Événements persistants** : ruine, cratère, incendie maîtrisé, barrage, pont détruit ; certaines traces peuvent être purgées selon une politique annoncée, jamais des données de gameplay.

**[HORS V1]** : creuser librement jusqu'au centre de la planète, modifier une planète cellule par cellule en 3D volumétrique, fracture géologique globale en temps réel.

## 18. Mers, rivières, montagne, altitude et météo

### Eau et déplacements

- Les rivières sont des obstacles ou couloirs selon leur largeur, le courant et la capacité des unités ; gués et ponts ont un rôle stratégique.
- Les lacs et mers arrêtent les unités terrestres ordinaires ; certains véhicules et navires futurs peuvent les franchir selon leurs tags.
- Les voies maritimes ont un intérêt économique et militaire, mais le **combat naval complet** est une **extension à mesurer** plutôt qu'une dépendance bloquante de J9.
- Un débarquement spatial ne doit pas placer un ouvrier sous l'eau, sur une falaise ou à l'intérieur d'un bâtiment. Si aucun site viable n'est disponible, le vaisseau attend avec une raison compréhensible.

### Altitude et terrain

Pente praticable, vitesse modifiée, lignes de vue et couverture sont calculées à partir des données de simulation du chunk, pas d'arbres purement graphiques. Les modèles LOD ne changent pas le résultat des tirs. Les engins lourds exigent parfois un accès routier, une plaine ou un pont ; les scouts peuvent exploiter les itinéraires secondaires.

### Cycles environnementaux

**[CIBLE progressive]** : jour/nuit et météo légère principalement visuels, puis impacts mesurés sur détection, mobilité et ressources. Les effets doivent être **annoncés** (boue, brouillard, tempête, sécheresse), bornés, déterministes par seed/tick et désactivables en mode performance sans modifier la logique ; si le joueur désactive uniquement le rendu pluie, la pénalité de terrain reste identique.

## 19. Carte globale, régions et propriété du territoire

**Terrain contrôlé** : zone sécurisée par bâtiment, patrouille ou garnison ; ce n'est pas automatiquement toute la surface coloriée d'un pays. Une carte planétaire montre centres, dépôts, routes, régions productives, fronts et influence, avec incertitudes de renseignement.

**Conquête locale** : destruction/neutralisation du dispositif militaire adverse + sécurisation et occupation effective des sites selon les règles de mission. **Conquête planétaire** : capacité à maintenir centres, logistique et domination des objectifs planétaires ; une navette survoleuse ne rend pas la planète conquise. **Conquête d'un système** : contrôle des nœuds permettant circulation, ravitaillement et projection ; distinguer « orbite contestée », « blocus » et « système sécurisé ».

**Marqueurs globaux** : ville (population/santé), front (risque), armée (force approximative si non scannée), route (capacité), alerte (priorité), site (intérêt), planète (contrôle). Les marqueurs sont agrégés à l'échelle de zoom sans devenir des pièces de monnaie graphiques illisibles.

## 20. Exploration, renseignements et secret de carte

États proposés, **par équipe et objet** :

- `UNKNOWN` — non révélé, aucune donnée exploitable.
- `DETECTED` — présence ou signature approximative, niveau de confiance inférieur à une identification.
- `MAPPED` — géographie et couloirs connus, pas forcément les forces ennemies.
- `IDENTIFIED` — type et position approximative ou exacte selon capteur.
- `LIVE_TRACK` — suivi récent avec âge de l'information et marge d'erreur.
- `STALE` — dernière observation datée ; position actuelle non confirmée.

Les satellites fournissent une **fenêtre de balayage** et une couverture caractérisée ; ils ne donnent pas vision permanente de toute la galaxie. Les brouilleurs agissent sur la **qualité/latence de renseignement**, pas sur le champ visuel physique d'un joueur qui possède déjà une unité sur place. Les leurres sont envisageables après validation des premières mécaniques.

**Cas de test** : changer de carte ne révèle rien de nouveau ; charger une sauvegarde ne recrée pas les ennemis depuis les positions de la seed comme s'ils étaient immobiles ; une armée masquée hors écran continue d'agir ; une information périmée affiche son âge.

---

# PARTIE D — COMBATS, TRANSPORTS ET COMMANDEMENT

## 21. Combat terrestre, aérien, maritime et siège

### Moteur de combat

**[CIBLE]** Chaque attaque suit une chaîne explicable : ordre valide → acquisition de cible autorisée → ligne de vue/capteur → portée et cadence → projectile ou résolution instantanée → couverture/armure/bonus → dégâts et états → événement de combat. Les classes historiques de `Rules.UNITS` conservent leur sémantique jusqu'à décision d'équilibrage versionnée.

Formule **illustrative, non contractuelle** : `dégâts_effectifs = dégâts_base × bonus_classe × modificateur_terrain × modificateur_technologie × réduction_armure`, avec bornes et arrondi déterministe. Les probabilités d'esquive/dispersion tirent dans un flux pseudo-aléatoire stable dépendant de l'ID de combat et du tick, jamais de l'ordre de rendu.

**Portée** : pas d'attaque instantanée à travers une montagne, une enceinte opaque ou une autre planète. **Munitions et ravitaillement** : introduire des stocks d'approvisionnement tactiques à partir des âges modernes sans imposer de microgestion des cartouches par soldat. **Morale [optionnelle]** : si implémentée, doit offrir un contre-jeu lisible (repli, commandement, repos), et non des fuites incompréhensibles.

### Triangle « unités / terrain / logistique »

- L'infanterie contrôle les objectifs et traverse certains milieux difficiles.
- La cavalerie et les véhicules exploitent la mobilité mais craignent les goulets et contre-unités.
- Le siège brise les fortifications, nécessite préparation, protection et ravitaillement.
- L'aviation ignore certains reliefs mais dépend de bases et peut être contrée par AA/détection.
- Les missiles ont une forte portée, un coût et des contre-mesures ; ils ne doivent pas pouvoir effacer une planète entière sans mécanique explicitement conçue.
- Les unités spatiales contrôlent les trajets et orbites ; elles ne deviennent pas automatiquement des troupes terrestres.

### Écart entre âges extrêmes

Un camp d'âge III ne doit pas **gagner frontalement à puissance égale** contre une flotte d'âge X par un ajustement artificiel des dégâts. Il peut néanmoins survivre en utilisant ravin, couverture, dispersion, guérilla, contrôle des ressources locales, attaque d'un dépôt non protégé et opportunités diplomatiques si actives. La tension vient du **rapport coût/terrain/logistique**, pas d'une égalité fictive des équipements.

### Siege et destruction

Le siège vérifie préparation et angle de tir, champ de vision, dommages aux murs, dégâts collatéraux maîtrisés, itinéraire de brèche, repli et reconstruction. Les bâtiments détruits produisent des ruines physiques et un changement permanent de l'occupation tactique, sans multiplier des rigid bodies non essentiels à l'échelle du mobile.

## 22. Ordres et comportements des unités

**Ordres fondamentaux :** sélectionner, se déplacer, attaquer, attaquer-déplacer, défendre, tenir, patrouiller, escorter, se replier, récolter, construire, réparer, charger/décharger, ravitailler, entrer en formation, se regrouper. Chaque ordre comporte des **prérequis et un statut** : `ACCEPTED`, `QUEUED`, `EXECUTING`, `BLOCKED`, `COMPLETED`, `CANCELLED`, `FAILED`.

**Priorités** : ordre manuel du joueur > ordre d'un commandant délégué > comportement automatique, sauf une règle de sécurité explicitement choisie (« préserver les civils » ou « retraite automatique »). Une commande devenue impossible doit avoir un motif (`TARGET_GONE`, `NO_ROUTE`, `NO_CAPACITY`, `NO_SUPPLY`) et ne pas laisser l'unité immobilisée silencieusement.

**Files d'ordres** : limitées, visualisables et annulables ; les ordres critiques doivent conserver l'ID de cible, pas seulement une position flottante. Sur une cible détruite, choisir une politique explicite : poursuivre à la dernière position, annuler ou réévaluer.

**Formations** : groupe logique d'environ six unités comme dans le socle, puis agrégation en bataillons/armées ; l'espacement tactique évite collision et empilement sans demander une simulation physique complète pour chaque soldat.

## 23. Commandement délégué et gestion de fronts simultanés

**Concept** : le joueur choisit des objectifs, une doctrine locale et une limite de prise de risque ; des subordonnés logiciels émettent les ordres de bas niveau. Ce système est **central** : sans lui, contrôler plusieurs planètes sur téléphone deviendrait pénible.

### Hiérarchie d'ordres

`Empire > Théâtre galactique > Système > Planète > Front > Groupe > Unité`. Chaque échelon reçoit un objectif, des ressources et des contraintes, puis renvoie un compte rendu.

**Objectifs proposés** : défendre colonie, tenir position, sécuriser route, attaquer avant-poste, protéger port, évacuer, renforcer front, patrouiller, explorer, construire infrastructure, ravitailler. **Contraintes** : rayon d'action, pertes maximales acceptables, pas de frappe sur objectif civil neutre, réserve minimale, priorité de construction, date limite en ticks, route interdite.

**Stratégies** : `PRUDENT`, `ÉQUILIBRÉ`, `OFFENSIF`. Un commandant prudent conserve des réserves et fuit un encerclement ; un commandant offensif tente plus vite les objectifs, mais n'ignore pas les impossibilités physiques ou économiques.

### Règle de non-usurpation

Un commandant délégué ne redirige pas une unité dont le joueur a pris le contrôle manuel, sauf réaffectation explicite. La reprise de contrôle affiche « Délégation suspendue sur ce groupe ». La délégation peut être réactivée au niveau armée ou théâtre.

### Rapport du commandement

Chaque front dispose d'une fiche : objectif, forces engagées, pertes, ravitaillement, progression, confiance renseignement, risques, ordres récents, raison d'un blocage. **Alerte critique** : signale action/choix utile (« Convoi bloqué en orbite — manque de capacité »), et non seulement « problème ». Un clic permet d'ouvrir la vue et l'objet correspondant.

## 24. Ravitaillement tactique et grande logistique

**[CIBLE]** Chaque armée possède un état de ravitaillement lié au réseau local : `OK`, `TENDU`, `CRITIQUE`, `COUPÉ`. Les malus portent sur vitesse de récupération, production de munitions ou cadence stratégique **selon type d'unité** ; une pénurie de nourriture ne désactive pas arbitrairement un radar spatial si sa chaîne énergétique demeure active.

Les trains/cargos relient des dépôts, les navettes relient les surfaces aux orbites, les flottes relient les systèmes. La chaîne complète d'une invasion nécessite production → stockage → acheminement → rassemblement → embarquement → transit → sécurisation orbitale → débarquement → logistique locale.

**Protection contre le spam de convois :** missions auto-répétées seulement si leurs contrats logistiques possèdent un budget et une capacité limités ; pas de départ gratuit illimité par simple tapotement. Une mission concurrente ne paie pas deux fois la même fondation de colonie.

## 25. Orbite, satellites et espace proche

**Tactiques orbitales** : contrôle d'une station, détection de vaisseaux, escorte, barrage, ravitaillement, choix d'un corridor de descente. Le joueur peut agir directement sur la carte orbitale : sélectionner une flotte, attribuer des trajets, choisir un point de stationnement et intercepter un ennemi identifié.

**Satellites :** reconnaissance, relais de communication, capacité d'observation ; coût, portée, temps actif, recharge, vulnérabilité. Les balayages ne révèlent que des zones et pour une durée/lisibilité connues. **[EXISTANT]** : coût de satellite et de scan et limites élémentaires sont présents en 0.8.2 ; **[CIBLE]** : orbites réellement manipulables, familles de satellites et contre-mesures.

**Stations :** point de réparation, stock local, relais de capteurs et nœud de contrôle. Elles ont un emplacement, de la santé, des besoins et peuvent être conquises/détruites ; elles ne sont pas une simple augmentation passive de statistiques.

**Contrôle du ciel** : le maître de l'orbite facilite le débarquement mais ne remplace pas une force terrestre d'occupation. Une planète peut être **assiégée orbitalement**, **occupée partiellement**, **colonisée** ou **conquise** ; ces statuts ne sont pas interchangeables.

## 26. Transports interplanétaires et interstellaires

### Cycle d'un transport

1. Choisir origine, destination, classe de vaisseau et soute.
2. Afficher les unités sélectionnées, leur nombre, le besoin de logement à destination, le carburant/coût, la route et l'ETA.
3. Vérifier accès aux infrastructures, capacité, ressources, connaissance de destination et absence de réservation concurrente incohérente.
4. Réserver transactionnellement coût, cargaison et emplacement de mission.
5. Débarquer la cargaison de la carte source dans l'état `IN_TRANSIT` ; elle existe encore avec ses identifiants, HP, expérience et équipement.
6. Avancer en temps de jeu déterministe (ticks), soumis aux interceptions, blocages et événements.
7. À l'approche, vérifier accès orbital, population, zone sûre, capacité de réception et statut de fondation.
8. Débarquer une seule fois ; sinon rester `HOLDING_ORBIT` ou `DIVERTED`, avec notification et choix possible de détour.
9. Créer un événement immuable d'arrivée et finaliser le grand livre logistique.

### Interceptions

Deux flottes ne s'interceptent que si leurs trajectoires/progressions les font se rencontrer dans une fenêtre cohérente, **avec acquisition de cible**. Une ETA semblable ne suffit jamais à déclencher une bataille à la première frame. Les flottes déjà engagées ne doivent pas être interceptées deux fois par deux traitements du même tick ; les pertes, cargaisons et récompenses ne s'appliquent qu'une fois.

### Trajets et carburant

**[CIBLE]** Coût et durée découlent de la longueur du corridor, de la propulsion, de la charge, de la sécurité et du ravitaillement. Les 160/420 ticks hérités de la 0.8.2 sont des paramètres de prototype, non une loi d'univers. Une technologie plus avancée peut réduire le temps, mais ne supprime pas les opérations de chargement, d'approche et d'occupation.

## 27. Flottes galactiques et guerre des routes

**Composition de flotte** : vaisseaux militaires, transport, soutien, éclaireur et éventuellement ravitailleur. Chaque flotte possède une doctrine, une vitesse limitée par sa composition, une autonomie, une signature, une ligne d'ordre, des pertes et une consommation en transit.

**Ordres** : rallier, patrouiller corridor, escorter convoi, défendre système, sécuriser orbite, attaquer flotte, intercepter contact, exploiter astéroïde, débarquer forces, retraite. Les ordres d'invasion peuvent être composés en étapes avec critères : « sécuriser orbite » → « envoyer 2 transports » → « établir centre » → « tenir 300 ticks » ; le joueur peut interrompre chaque étape.

**Dissuasion et contre-mesures** : les flottes lourdes dominent la force brute, mais les transports isolés, les relais d'information et les dépôts restent vulnérables. Un défenseur plus faible peut retarder une offensive en coupant une route, sans rendre invulnérable une planète archaïque.

**Gouvernance d'un système** : colonies, ports, routes, capacités industrielles et forces locales, jamais un simple changement de couleur par présence passagère de vaisseau.

## 28. Diplomatie, neutralité et événements

**[DÉCISION PROPOSÉE]** : conserver au premier lancement deux camps réellement adverses. Les **acteurs neutres** peuvent être des marchés, comptoirs et stations ; ils n'ont pas besoin d'une IA diplomatique complète pour rendre l'exploration intéressante.

**[HORS V1]** : négociations diplomatiques avancées, alliances multijoueurs et guerre entre dix factions souveraines. Les traiter comme une extension indépendante après J12, car ils augmentent fortement les états de victoire, l'IA et les migrations de sauvegarde.

**Événements** : ruine découverte, poste neutre, perturbation météo, détresse d'un convoi, système riche, corridor dangereux. Ils doivent être liés à une seed/tick/condition, avec répétition évitée, notification actionnable et conséquences transparentes. Un événement ne peut détruire une campagne irréversiblement sans avertissement ou possibilité stratégique raisonnable.

---

# PARTIE E — JOUEUR ANDROID, IDENTITÉ VISUELLE ET AMBIANCE

## 29. Interface : principes généraux de conception mobile

La première priorité de l'interface est de permettre **une décision juste en un ou deux gestes**. La profondeur stratégique ne doit pas s'accompagner d'un HUD permanent de trente boutons. La même tâche doit être opérable avec deux doigts, en mode paysage, sans clavier ni souris et sans exiger une précision de pixel.

**Hiérarchie visuelle** :
1. **Monde** : conserver la majorité de l'écran pour le terrain, planète ou système.
2. **Informations critiques** : danger, sélection active, ressources vitales, vitesse réelle, objectif en cours.
3. **Actions contextuelles** : déplacer, attaquer, construire, produire, déléguer, envoyer flotte.
4. **Gestion stratégique** : carte globale, notifications, empire, recherche, logistique et chronologie.
5. **Options / données techniques** : accès secondaire ; jamais au-dessus du bouton tactique en combat.

**Thème proposé** : science-fiction discrète et réaliste, panneaux translucides à arrière-plan flouté **uniquement si performant**, surfaces sobres, typographie nette, reliefs colorés par statut et touches de couleur pour le danger ; pas de néons omniprésents masquant les silhouettes. Les âges I–III peuvent garder un habillage inspiré de cartes anciennes sans changer la structure des commandes. La permanence ergonomique prime sur l'effet cosmétique de progression.

## 30. Gestes tactiles détaillés

| Geste | Situation | Action attendue | Protection contre les erreurs |
|---|---|---|---|
| Tap simple | Monde hors UI | Sélection d'unité/bâtiment/objet spatial | Hitbox généreuse ; cycle entre objets superposés |
| Tap sur sol avec groupe actif | Mode ordre de déplacement | Déplacement avec marqueur et prévisualisation | Désactivation sur UI ; vérification de zone viable |
| Tap sur ennemi | Groupe militaire sélectionné | Attaque ou panneau de choix selon mode d'ordres | Pas d'attaque automatique après simple inspection sans mode explicite |
| Appui long | Monde | Menu contextuel radial ou fiche d'objet | Seuil temporel configurable, retour haptique léger |
| Glisser un doigt | Caméra non en ordre | Pan horizontal/vertical | Capture du geste après seuil pour éviter le faux tap |
| Pincer/écarter | Monde | Zoom / dézoom, transitions d'échelle | Hystérésis et verrou d'interface |
| Double tap | Objet connu | Centrer / suivre la sélection | Pas de double ordre de déplacement |
| Glisser sur panneau | Menu ouvert | Défilement du panneau uniquement | Le jeu ne reçoit pas le drag tant que le panneau capture l'entrée |
| Tap sur mini-carte | Mini-carte | Déplacer caméra ou cibler lieu selon mode | Indication du mode actif |
| Deux doigts sur monde | Optionnel | Pan rapide, rotation restreinte, pas d'ordre | Fallback vers pan simple si ambigu |
| Tap sur alerte | Hors écran | Ouvrir lieu et événement lié | Pas de recentrage si événement expiré sans avertir |

**[PARAMÈTRES EXPÉRIMENTAUX]** : cible tactile visuelle d'au moins ~48 dp, marges d'erreur de 8–12 dp autour des unités fines, seuil d'appui long ~350 ms, annulation si l'utilisateur s'éloigne trop du point de départ. Les valeurs doivent être validées sur taille d'écran et densité réelles. Prévoir un mode « grandes commandes » et un mode gaucher.

### Sélection et ordres

- Sélection par tap et sélection multiple par mode dédié (cadre tactile ou pinceau de sélection), non par déplacement imprévisible de caméra.
- Barre de groupe : portrait/icône classe, nombre, état de ravitaillement, position et objectif ; agrégation automatique si plus de six unités.
- Le bouton principal change selon le contexte (« Déplacer », « Attaquer », « Construire », « Envoyer »). Il conserve sa position relative pour construire une mémoire gestuelle.
- Les actions irréversibles (démanteler bâtiment, frapper une zone stratégique, dissoudre armée) requièrent confirmation ; annuler ou quitter un panneau ne consomme rien.
- Afficher **prévisualisation avant ordre** : chemin probable, temps estimé, coût réservé, risque connu, emplacement final et motifs de refus.

## 31. HUD différencié selon l'échelle

### Vue tactique

Bandeau compact de ressources **locales**, âge, ordre actif, informations d'unités, mini-carte du secteur, bouton de délégation, vitesse/pause, alertes critiques. Un panneau radial ou bas d'écran présente les actions sans condamner un tiers de l'écran en permanence.

### Vue planète

Bandeau « planète / faction / logistique », carte des régions, filtres (ressources, fronts, colonies, routes, risques), composition des armées, commandes « renforcer / défendre / aller voir ». La carte globale masque la foule d'individus et représente des groupes, sans supprimer les individus de la simulation.

### Vue système

Sélection d'un corps, défilement des orbites, réserves et bases, flotte visible, routes/ETA, liste des missions, bouton « Ordre de flotte », préparation d'un débarquement et surveillance de corridor.

### Vue galaxie

Systèmes visibles selon renseignement, frontières d'influence, routes connues, alertes et besoins de transfert, vue de l'empire, listes de commandants. Une flotte ne peut être téléportée par tap sur une étoile : la ligne de route et les conditions sont présentées avant confirmation.

### Wireframe conceptuel — paysage (non contractuel)

```text
┌──────────────── Ressources locales | Âge | Recherche | Pause ×1 ────────────────┐
│ [Planète > région]                                   [ALERTES 3] [Empire] [⚙]  │
│                                                                              │
│                   CARTE TACTIQUE / GLOBE / GALAXIE                           │
│                                                                              │
│      [mini-carte]                                   [Sélection + états]       │
│      [fronts]                                      [Ordre principal] [···]    │
└─────[Vue: Région | Planète | Système | Galaxie]────────[Déléguer]─────────────┘
```

La forme exacte devra être maquettée et testée en paysage avec zones sûres Android, arrondis d'écran, barre de navigation et réglages système, avant intégration à tous les âges.

## 32. Vitesse de simulation, pause et mesure de la vitesse réelle

**[EXISTANT]** : choix 0,5× / 1× / 2× / 4× / 8× ; mécanisme de simulation à ticks de 0,1 s de jeu et limite d'étapes par frame. **[CIBLE]** : ajouter une pause clairement visible, distinguer la vitesse **demandée** et la vitesse **effectivement tenue**, et afficher une alerte douce en cas de surcharge.

**Contrat :**
- `sim_speed` change le taux auquel le jeu **consomme ses ticks logiques**, pas la fréquence de détection tactile ni la vitesse de navigation caméra.
- À ×8, 10 ticks/s de référence impliquent **jusqu'à 80 ticks logiques/s de temps mural** si le matériel suit ; 80 n'est pas un taux garanti.
- Aucun tick ne peut être sauté pour « rattraper » un FPS : la simulation peut ralentir en temps réel, jamais inventer un résultat logique.
- À nombre de ticks égal et ordres identiques, les états doivent correspondre entre ×0,5, ×1 et ×8.
- Une pause n'efface ni missions ni événements ; sauvegarder en pause produit un état cohérent.
- Le zoom, les panneaux et le bouton retour Android restent réactifs en surcharge ; le planificateur limite les ticks consommés par frame.
- Lorsque ×8 n'est pas tenu, le HUD peut afficher « ×8 demandé / ×5,6 effectif » mesuré sur une fenêtre stable ; aucun mensonge d'interface.

### Modes de vitesse proposés

- **Normal** : 1×, valeur par défaut.
- **Observation** : 2× ou 4×, utile pour voyages/production en période calme.
- **Accélération** : 8×, best effort, avec rappel « performances dépendantes du matériel ».
- **Précision** : 0,5×, pour le siège et les opérations délicates.
- **Pause** : 0×, autorise la consultation et la planification ; l'exécution d'ordres en pause sera définie explicitement (recommandation : mise en file, exécution à la reprise).

## 33. Alertes, événements et attention du joueur

**Niveaux d'alerte :** `INFO` (recherche terminée), `OPPORTUNITÉ` (ressource découverte), `IMPORTANT` (convoi retardé), `CRITIQUE` (centre attaqué, colonie sans défense), `TERMINAL` (faction éliminée, fin de partie). Une alerte comporte ID unique, origine, tick, camp destinataire, sévérité, statut, lien vers vue, action recommandée, compteur de répétition et durée de visibilité.

**Agrégation** : dix pertes mineures sur une planète pendant un siège deviennent « 10 unités perdues — Val », plutôt que dix popups ; une capitale attaquée reste visible malgré le regroupement. Un événement actif hors écran doit arriver dans le journal du joueur sans vider/écraser l'historique d'un autre secteur.

**Fonctions** : filtrer par planète, gravité, période et type ; ouvrir lieu ; marquer traité ; atténuer les événements faibles ; consulter cause et conséquence ; ne jamais révéler par notification des informations non connues par la faction.

## 34. Menu principal, sauvegardes et reprise mobile

Entrées principales : **Continuer**, Nouvelle partie, Laboratoire/Recette, Galerie des univers (seed et campagnes), Options, À propos/licences. Continuer affiche la dernière sauvegarde valide, la date et le niveau de progression, sans écraser les campagnes antérieures.

**Android** : passage en arrière-plan → pause du temps de simulation au plus tard au prochain tick cohérent ; sauvegarde de sûreté si fenêtre disponible, mais ne jamais supposer que le système laisse du temps pour écrire. Au retour, recalculer les ressources visuelles, vérifier les dimensions et reprendre **sans progression hors ligne automatique** dans le mode solo initial. Un verrouillage écran ne doit pas avancer les convois en « temps réel » pendant plusieurs heures.

**Contrat d'accessibilité** : réglage texte, contraste, gaucher, colorimétrie ami/ennemi non fondée sur la seule couleur, affichage des dégâts et temps en chiffres, sous-titres des événements sonores, options pour réduire les animations et le scintillement, désactivation des vibrations, aide gestuelle consultable hors tutoriel.

## 35. Tutoriel et découverte des mécaniques

**Parcours d'apprentissage** :
1. Déplacer caméra et sélectionner (30–60 secondes, objectif simple).
2. Récolter et construire, expliquer les trois stocks.
3. Former/guider une escouade, montrer la priorité d'ordre manuel.
4. Protéger un gué, réparer, utiliser le brouillard.
5. Développer commerce, sièges et recherches, passer un âge.
6. Gérer une usine, la logistique, une pénurie volontaire et un train.
7. Construire radar et satellite, comprendre « détecté » vs « identifié ».
8. Dézoomer sur la planète, visiter l'orbite et envoyer une navette.
9. Établir une colonie, vérifier la cargaison, contrôler deux fronts.
10. Dézoomer sur la galaxie, créer une route et ordonner une flotte.

Le tutoriel sera composé de **micro-scénarios indépendants**, rejouables dans le laboratoire ; le joueur expérimenté peut les ignorer. Les aides doivent expliquer le « pourquoi » du bouton au moment où le joueur en a besoin, pas multiplier les panneaux imposés.

## 36. Direction artistique et ambiance visuelle

**Style cible :** 3D réaliste lisible et optimisée pour smartphone ; proportions crédibles, équipements cohérents, matériaux PBR, terrain organique, silhouettes faciles à reconnaître depuis une caméra RTS. « Réaliste » ne signifie pas photogrammétrie intégrale ni visages ultra détaillés à l'écran.

### Évolution des environnements

- **Âges I–III** : sols terreux, routes, bois, pierres, tentes et constructions maçonnées, effets de poussière, fumée de cheminée, palissades, fortifications de gué.
- **IV–V** : usine, acier, cheminée, rail rudimentaire, panneaux de recherche, logements plus denses.
- **VI–VIII** : infrastructures lourdes, véhicules mécaniques, aérodromes, dépôts, antennes, radars, mobilier de guerre électronique.
- **IX–X** : spatioports fonctionnels, plateformes d'atterrissage, habitats modulaires, stations orbitales, chantiers spatiaux, signalétiques de flotte.
- **Planètes** : biomes générés distincts par couleur, sol, végétation, brume, roche, lumière atmosphérique ; éviter des planètes qui ne diffèrent que par une teinte.
- **Système/galaxie** : étoiles, poussières, orbites indicatives, rails de navigation, faisceaux de capteurs et arcs de transit sobres ; préserver les contrastes des objets sélectionnés.

### Règles pour les personnages

- Animation de déplacement ajustée à la vitesse **réelle de l'entité rendue**, pas au multiplicateur du jeu seul.
- Équipements adaptés à la classe et à l'âge ; silhouettes différenciées pour ouvrier, scout, siège, soldat, véhicule et drone.
- Pas de changement de classe visuel trompeur : un civil assimilé à un tank n'a pas de sens.
- Variations subtiles de vêtements, traces, usure et couleurs de camp sans créer de dizaines de draw calls séparés pour chaque soldat.
- Animations de tir, construction, impact, mort et repli synchronisées à l'événement logique, mais leurs effets secondaires restent uniquement visuels.

### Matériaux et lumière

Palette de matériaux contrôlée par âge et environnement : terre/pierre/bois/métal/tissu/verre ; rugosité crédible, détails par normal maps, variation d'usure et de salissure, ombres dynamiques limitées. Profil Android Mobile à shaders simples, pas de technique dépendante d'un effet absent du renderer de référence. Les effets avancés ne doivent pas différer les hits ou la visibilité logique.

### LOD et silhouettes

**Haut** : modèle animé proche, détails utiles à l'identification. **Moyen** : géométrie simplifiée et texture partagée. **Bas** : silhouette simple / impostor / sprite en vue stratégique. **Extrême** : icône d'armée/ville/flotte. L'objet garde un seul ID et les mêmes ordres. La chute de LOD ne change jamais la collision ou le rayon de tir simulé.

## 37. Effets, destruction, environnement animé

- **Effets de combat** : impacts, tirs, fumées, incendies stylisés réalistes, dégâts de bâtiment progressifs, débris limités, trajectoires lisibles.
- **Effets naturels** : herbes sous le vent, poussière, eau, nuages et pluie ; densité adaptative et absence de fausse information tactique.
- **Destruction** : trois à cinq états de dommage visuel par catégorie au lieu d'une physique de destruction complète sur chaque objet ; ruines persistantes liées au modèle de simulation.
- **Destruction spatiale** : coque endommagée, explosion localisée, débris temporaires et marqueur d'épave si ressource/renseignement utile.
- **Lisibilité** : pas de bloom excessif masquant les sélections et les trajectoires ; réduire particules pendant un siège très chargé, sans modifier les dégâts.

## 38. Audio, musique, retour haptique et identité sonore

**Système audio à niveaux** :
- Ambiance tactique : vent, eau, forêt, ville, machines, tirs, moteurs.
- Ambiance orbitale : silence spatial fictionnel contrôlé, vibrations de vaisseau lors de sa sélection, signaux radar et communication.
- Ambiance galactique : texture musicale discrète, interfaces et confirmation d'ordres ; pas de tirs sonores dans le vide supposés physiquement réalistes.
- Musique dynamique : exploration/calme, préparation, combat, siège, crise coloniale, expansion, victoire/défaite.
- Alerte critique : signal court, distinctif, réglable et non répété de manière anxiogène.

**Mixage** : volumes séparés musique/effets/UI/voix, ducking lors d'alertes majeures, limite de voix audio simultanées, catégories de spatialisation, suppression des sons hors champ sans conséquence de gameplay. **Haptique** : confirmation d'ordre court, erreur distincte, désactivable ; jamais condition indispensable pour comprendre une action.

**Droits** : musiques, textures, modèles, fontes et bruitages originaux ou sous licences compatibles vérifiées ; inventaire de provenances, versions et obligations d'attribution dans le projet. Aucun contenu sous licence ambiguë intégré sans preuve de droit de redistribution.

## 39. Texte, localisation, narration et interface d'aide

Français langue première ; architecture de localisation par clés stables (`ui.fleet.order.defend`, `error.route.no_fuel`). L'anglais pourra être ajouté sans refaire la mise en page. Les libellés affichent une **action** et un résultat attendu : « Envoyer 3 unités vers Aurore — arrivée dans 16 s de jeu », plutôt que « Mission 7 ».

**Narration légère** : description des biomes, découvertes, nommage des colonies et journaux de campagne générés à partir d'événements de jeu ; pas de texte procédural qui invente des faits non survenus. Le rapport de fin de partie raconte les étapes majeures (premier fort, premier vol, première colonie, bataille décisive) avec leur tick et leurs lieux.

---

# PARTIE F — ARCHITECTURE LOGICIELLE, DONNÉES ET FIABILITÉ

## 40. Architecture Godot 4 : évolution incrémentale

**Contraintes de base :** moteur Godot 4 présent dans les sources, GDScript typé, configuration actuelle du renderer `mobile`, 10 ticks logiques/s et tests de laboratoire déjà disponibles. Les warnings de typage doivent être traités comme bloquants dans cette branche ; éviter l'inférence `:=` depuis `Dictionary.get()` / valeurs JSON de type Variant sans cast explicite.

**Interdiction de principe** : réécrire complètement J1–J8 pour intégrer le procédural. L'architecture est étendue par adaptateurs et modules remplaçables, avec comparaisons déterministes et migration de format.

### Couches

**Simulation** : état autoritatif, règles, unités, économies, ordres, IA, bataille, route, temps. N'accède jamais à une caméra ou à un `Node3D` pour décider d'un combat.  
**Génération** : fonctions déterministes à entrée explicite (seed, version, planète, région, coordonnées), renvoyant données pures.  
**Stratégie multimonde** : index global, ordres interplanétaires, convoyage, renseignement, notifications, victoire et stocks.  
**Streaming** : chargement/éviction de données et ressources visuelles, budget cache, file de priorités.  
**Présentations** : scènes tactiques, globe, orbite, système, galaxie, animation, effets, interpolations.  
**Interaction** : gestes, sélection, projection écran→monde, HUD et cartes d'ordres, accessibilité.  
**Persistance** : sauvegarde versionnée, validation, migration, journal, sauvegarde de secours.  
**Recette** : tests automatisés sans rendu, tests avec scène, benchmarks et contrôles manuels Android.

### Arborescence cible (proposition, sans renommage immédiat des fichiers hérités)

```text
sillons/
  project.godot
  sim/                      # moteur historique conservé
    rules.gd
    match.gd
    star_campaign.gd       # adaptateur campagne héritée / stratégie globale
    campaign_save.gd
    ...
  core/
    universe_state.gd      # état autoritatif global
    entity_registry.gd     # identifiants, localisation, composants
    command_bus.gd         # validation/ordonnancement des commandes
    event_log.gd           # événements et rejeu
    resource_ledger.gd     # comptabilité locale + transit
    tick_scheduler.gd      # pas fixe et budgets
  procgen/
    generator_version.gd
    seed_derivation.gd
    galaxy_generator.gd
    system_generator.gd
    planet_generator.gd
    biome_rules.gd
    fairness_validator.gd
  spatial/
    coordinate_service.gd
    planet_quadtree.gd
    navigation_graph.gd
    transit_solver.gd
    orbital_sim.gd
  streaming/
    chunk_manager.gd
    data_cache.gd
    visual_cache.gd
    generation_jobs.gd
  ai/
    empire_director.gd
    logistics_planner.gd
    theater_commander.gd
    sector_commander.gd
    tactical_commander.gd
  game/
    game.gd                # contrôleur historique conservé
    main_menu.gd
    ...
  views/
    tactical_view.tscn
    planet_view.tscn
    system_view.tscn
    galaxy_view.tscn
    zoom_controller.gd
    strategic_markers.gd
  ui/
    mobile_input.gd
    scale_navigator.gd
    selection_panel.gd
    order_palette.gd
    alert_center.gd
    empire_dashboard.gd
    load_progress.gd
  save/
    save_schema.gd
    save_migrations.gd
    snapshot_writer.gd
    delta_store.gd
  lab/
    ...                    # scénarios historiques J1–J8 conservés
    j9_planet_test.gd
    j10_system_test.gd
    j11_galaxy_test.gd
    j12_campaign_test.gd
    stress_multiscale_test.gd
  tools/
    verify-j9.sh
    verify-j10.sh
    verify-j11.sh
    verify-j12.sh
    export-android-final.sh
  game-studio/
    decisions.md
    benchmarks/
    manifests/
    proof/
```

**[DÉCISION PROPOSÉE]** : après un prototype prouvant la compatibilité, remplacer progressivement les hardcodes `SECTORS = [val, aurore, nemesis]` par un registre de sites stables et un graphe ; conserver l'adaptateur trois secteurs pour charger les sauvegardes historiques.

## 41. Structures de données et identifiants

Une planète doit être reconnue par `planet_id` stable indépendamment de son nom localisé. Une entité doit pouvoir passer `ON_PLANET → IN_CARGO → IN_FLIGHT → HOLDING_ORBIT → ON_PLANET` sans recréation ni perte d'état.

### Entité type (exemple de schéma conceptuel)

```json
{
  "entity_id": "e_00000000874a",
  "team_id": 0,
  "kind": "unit",
  "type_id": "ouvrier",
  "location": {
    "space": "planet",
    "galaxy_id": "g_01",
    "system_id": "s_017",
    "planet_id": "p_017_02",
    "face": 2,
    "chunk_x": 18,
    "chunk_y": -4,
    "local_x_q": 12700,
    "local_y_q": 4250
  },
  "health_q": 50000,
  "cargo_id": null,
  "order_id": "o_9182",
  "version": 1
}
```

Le suffixe `_q` indique une grandeur **quantifiée en entier** à échelle définie ; l'exemple ne fixe pas son facteur. Les données de rendu (mesh, animation, position caméra) ne sont pas des données autoritatives à sauvegarder. Les valeurs JSON liées aux entités ont un schéma strict, des bornes et une taille maximum.

### État d'ordre type

```json
{
  "order_id": "o_9182",
  "issued_tick": 5820,
  "issuer": "player_0",
  "scope": "unit",
  "target_ids": ["e_00000000874a"],
  "action": "move_to_region",
  "target": {"planet_id":"p_017_02", "region_id":"r_026"},
  "priority": "manual",
  "state": "EXECUTING",
  "policy_on_failure": "notify_and_wait"
}
```

### Identifiants et noms

`entity_id` persiste même si l'unité est embarquée ; `flight_id`, `command_id`, `planet_id`, `system_id` et `event_id` sont distincts. Les noms affichés sont des attributs modifiables ; un changement de langue ne modifie jamais la clé d'une sauvegarde. Les entrées reçues (nom de campagne, seed, emplacement, ID) sont validées avant utilisation comme chemin ou référence.

## 42. Ordonnancement temporel et déterminisme

**Temps canonique :** compteur entier `tick`. Un tick de logique existant vaut 0,1 seconde de temps de jeu à ×1 (10 Hz). Les rendus 30/60 FPS sont indépendants ; les animations peuvent interpoler entre états logiques. Le passage de couche n'accélère ni ne ralentit la simulation.

### Ordre de traitement d'un tick (proposé)

1. Extraire commandes arrivées / planifiées pour le tick, triées par `tick`, `priority`, `command_id`.
2. Valider et réserver ressources/capacités (transactions idempotentes).
3. Appliquer événements déterministes à échéance (arrivées, recherches, aléas seedés).
4. Faire avancer économie, construction, technologies et logistique.
5. Faire avancer mobilités terrestres, flottes et trajectoires orbitales abstraites.
6. Déterminer perceptions/renseignements, attaques et dégâts dans un ordre défini.
7. Résoudre morts, destructions, prises, population, victoire et erreurs de livraison.
8. Mettre à jour IA à cadence explicitement planifiée et produire de nouveaux ordres pour ticks ultérieurs.
9. Générer notifications et hash de contrôle à intervalles choisis.
10. Publier un snapshot de lecture pour les vues ; incrémenter `tick`.

**Problème à anticiper :** `Dictionary` et itérations non triées, appels à un RNG global, `Time.get_ticks_msec()`, flottants de plateformes différentes et concurrence non déterministe peuvent altérer les replays. Réserver les décisions critiques à des séquences triées et des calculs quantifiés en entier ; les effets de rendu peuvent rester flottants. Chaque sous-système reçoit son propre RNG dérivé (`seed + component + scope + tick`) ; ne jamais réutiliser la source de hasard du rendu pour un combat ou un gisement.

### Vitesse et invariance

**Test majeur** : même seed, même liste d'ordres par tick, résultat logique identique après 10 000 ticks à 0,5×, 1× et 8×, même après plusieurs transitions de zoom et sauvegardes/reprises. Les performances peuvent varier, pas le bilan comptable ni le gagnant.

### Simulation hors écran

**Règle fondatrice** : hors écran, les **unités restent des entités**, même si leurs rendus et animations sont supprimés. Les tâches de pathfinding/IA peuvent être planifiées à moindre cadence ou agrégées **seulement** si leurs décisions restent logiquement équivalentes pour les scénarios couverts, ou si le jeu documente une abstraction stratégique volontaire. On ne peut affirmer simultanément « toutes les unités calculées au détail partout » et « une galaxie illimitée sur mobile » sans budget mesuré : le cahier de charge prévoit un régime mixte quantifié et testé.

**[DÉCISION PROPOSÉE]** : 3 catégories : `ACTIVE_DETAILED` (zone de combat/interaction), `ACTIVE_STRATEGIC` (entités conservées, décisions événementielles, résolution de certaines actions agrégées), `DORMANT` (aucune activité en cours, événements à échéance). Le changement de catégorie est fondé sur activité et dépendances, **jamais simplement sur la caméra**, afin d'éviter l'exploit « je dézoome pour gagner un combat autrement ». Les scénarios d'invariance comparent les mêmes combats avec et sans présence caméra.

## 43. IA multi-échelle et planification des tâches

### Niveaux

- **Directeur d'empire** : sécurité globale, âge, recherche, expansion, distribution de stocks, priorités des théâtres.
- **Planificateur galactique** : sélection des systèmes, routes, défense de corridors, déplacements de flottes.
- **Commandant de système** : flottes, stations, priorités orbitales, invasions et escortes.
- **Commandant planétaire** : ressources, bases, fronts, défense anti-débarquement.
- **Commandant tactique** : positions, cibles, formations, couverture, retraites et ravitaillement.

### Décisions et cadence

Chaque IA produit des **commandes dans le même bus** que le joueur, avec preuve qu'elle connaît la cible et possède les moyens requis. Les sous-directeurs ont des cadences en ticks et des budgets CPU mesurables (ex. tactique fréquent, empire moins fréquent), mais tous les éléments de gameplay critiques sont évalués selon leurs échéances, non l'ouverture de la vue.

**Fonction d'utilité (exemple)** : `score(action) = gain_objectif - coût_ressource - coût_transport - risque_pertes - exposition_logistique + bonus_doctrine`. Toutes les composantes sont normalisées, journalisables et limitées ; priorité à des heuristiques explicables plutôt qu'une IA opaque pour les premières versions.

**Mémoire** : dernières observations horodatées, actions adverses connues, pertes, routes éprouvées, capacités adverses estimées. L'IA ne connaît pas le terrain masqué ni les cargaisons cachées. Les entrées de l'IA et sa décision peuvent être affichées en laboratoire pour débogage.

**Déblocage sans triche** : si une action impossible est répétée, marquer `BLOCKED` et chercher une alternative après un délai raisonnable, éviter la boucle de création/suppression. Une IA ne paie jamais deux fois une colonie et n'envoie pas toutes ses unités de reconstruction en transport sans centre protégé.

### IA contre IA

Chaque camp contrôlé par IA doit bénéficier **des mêmes modules** : technologies, colonies, flottes, logistique, victoire et notifications. Des comparaisons symétriques avec échange de camps et seeds servent à détecter un biais d'index ou de position.

## 44. Pathfinding et mouvement multi-échelle

**Trois familles :**
- **Local** : navigation sur grille/graphes de chunk, pentes, obstacles, évitement simple entre groupes et bâtiments dynamiques.
- **Planétaire** : graphe de régions (routes, gués, ports, cols) ; décomposer un long déplacement en objectifs locaux au fur et à mesure.
- **Spatial** : graphe de voies/points d'approche, coût/délai/capacité ; interception sur progression commune.

**Cache** : les routes sont invalidées si pont détruit, zone envahie ou corridor bloqué. Éviter de recalculer un A* complet pour chaque soldat au même tick : mettre en commun les demandes par groupe et utiliser une file bornée. Le mouvement doit toujours vérifier la collision/navigation locale juste avant l'entrée sur un nouveau chunk.

**Changement de carte** : la caméra n'est pas responsable du mouvement ; si un groupe marche hors écran, son chemin logique avance. La première image après retour doit être alignée sur son état autoritatif. Recalculer les interpolations visuelles, pas les ordres.

## 45. Exécution en arrière-plan, threads et chargements

**[CIBLE]** Générer les données et préparer certaines ressources en tâches asynchrones, mais **ne pas modifier l'arbre de scènes actif depuis des threads de travail**. Le main thread instancie/applique les scènes, et des travaux limités à des données pures produisent des résultats atomiques. Utiliser les mécanismes de chargement en arrière-plan de Godot lorsqu'ils sont adaptés ; éviter d'attendre brutalement une ressource non prête dans un callback tactile.

**Portefeuille de travaux** : un job porte seed, cible, version, priorité, budget, identifiant et état d'annulation ; le résultat peut être invalidé si le joueur a changé de planète avant publication. Les données doivent être réentrantes et ne jamais dépendre de l'ordre de fin des threads pour le contenu de la carte.

**Règle de reprise** : un chargement interrompu par Android ne corrompt pas les données persistantes ; le job en cours se recommence depuis la seed. Les scènes réutilisables sont poolées quand leur création coûte cher, mais le pool est borné et nettoyable.

## 46. Rendu et architecture 3D sur Android

### Renderer

Le projet 0.8.2 sélectionne le rendu **Mobile** ; il doit rester la référence jusqu'à mesure comparative. **[CIBLE]** proposer niveaux « Économie / Équilibré / Détaillé », avec contrôle qualité d'ombres, résolution interne, densité de décor, texture LOD et effets. Ne pas dépendre de VoxelGI, SDFGI ou d'autres fonctions indisponibles dans le renderer Mobile pour le rendu essentiel.

### Instanciation et culling

**MultiMesh** pour rochers, arbres, herbes et éléments répétés, **découpé par chunk** afin de rendre possible l'élimination des zones invisibles. Une énorme MultiMesh à l'échelle de la planète est contre-productive : elle ne fournit pas une visibilité par instance aussi fine qu'un découpage spatial. Les unités animées et sélectionnables exigent une stratégie hybride (nœuds proches, agrégations/impostors éloignés).

### Budgets graphiques expérimentaux

| Palier de test | Unités simultanément visibles | Niveau attendu | Raison |
|---|---:|---|---|
| Référence | 100–150 | Tactique normal | Prouver 60 FPS sur scène calibrée |
| Charge | 250–300 | Bataille dense | Viser 30 FPS sans gel tactile |
| Stress | 500–600 | Scénario extrême | Mesurer où le moteur décroche, non garantir jouabilité |

Ces seuils concernent des **cibles de benchmark proposées**, pas des limites prouvées. Les modèles, effets, IA et taille des chunks seront figés par profilage. Les scènes galactiques utilisent des instances/icônes, non des vaisseaux haute résolution pour tous les systèmes en même temps.

## 47. Performance, mémoire et autonomie énergétique

### Objectifs à mesurer sur S25 Ultra

| Indicateur | Cible préliminaire | Condition de mesure |
|---|---|---|
| Fluidité standard | 60 FPS visés ; temps de frame moyen ≤ 16,7 ms | Scène de référence, appareil froid puis après chauffe |
| Bataille dense | ≥ 30 FPS visés ; temps de frame moyen ≤ 33,3 ms | Script de combat à charge constante |
| P95 / P99 frame | Mesurer, définir seuils de validation après première série | 5 minutes de jeu non interrompu |
| Réactivité tactile | Aucun gel prolongé perceptible ; mesurer p95 des réponses | Sélection et ordres répétés pendant streaming |
| Accélération ×8 | Mesurer ticks/s demandés et atteints, sans tick perdu | Plusieurs niveaux de charge sur carte identique |
| RAM / mémoire graphique | Pic et stabilisation mesurés ; plafond fixé ensuite | 30 minutes + transitions répétées |
| Streaming | Durée d'apparition des chunks, pauses et nombre de jobs | Pan/zoom rapide, planètes déjà visitées et nouvelles |
| Énergie / thermique | Dégradation en FPS et niveau de chauffe consignés | Partie 30–60 min, appareil non branché si possible |
| Sauvegarde | Temps, taille, réussite atomique, reprise et `.bak` | Campagne chargée en unités, itinéraires et deltas |

**Méthode** : appareil identifié, build, renderer, qualité, seed, état de batterie, mode de performance, luminosité, température ambiante approximative, éventuelle chauffe initiale, durée, outils utilisés. Comparer **même scène / même nombre de ticks** entre versions pour éviter les conclusions trompeuses. FPS moyen seul ne suffit pas : noter blocages, p95/p99 et pertes de réponse tactile.

**Dégradation ordonnée** : réduire d'abord herbe/effets/postprocessing/ombres/résolution, ensuite fréquence d'actualisation des marqueurs et requêtes visuelles ; **ne jamais réduire les coûts, ignorer un combat ou supprimer des ticks pour préserver des FPS**. Si le CPU ne suit pas le ×8, annoncer un ×effectif inférieur.

## 48. Sauvegardes, migrations et reprise après incident

### Format versionné

**Contenu obligatoire** : version du moteur logique, version du générateur, identifiants, seed maître, tick, options de campagne, âge et technologies par faction, stocks locaux et en transit, unités et bâtiments, ordres, trajectoires, états IA, brouillard/renseignement, modifications de terrain, événements nécessaires, notes d'alerte et conditions de victoire.

**Périmètre exclu** : meshes générés, instances graphiques, textures temporaires, fenêtres UI non nécessaires, position de curseur pendant une pression en cours.

### Processus transactionnel

1. Capturer un snapshot cohérent entre ticks.
2. Écrire dans un fichier temporaire dans le même stockage.
3. Valider schéma, longueur, bornes, version, références et checksum ; éventuellement calculer un hash de l'état canonique.
4. Synchroniser et finaliser le fichier selon les capacités de l'OS, remplacer l'ancien de façon contrôlée et conserver un `.bak` validé.
5. À la lecture, tester le principal ; sur échec, proposer la sauvegarde de secours avec date/version/tick, jamais silencieusement basculer sur une autre campagne.
6. Appliquer une migration de **copie** vers la nouvelle version ; préserver le fichier d'origine pour retour arrière.
7. Journaliser toutes les erreurs sans inclure de secrets système ni de fichiers arbitraires.

**Fichiers tiers/importés** : taille plafonnée, validation stricte de JSON/binaire, aucune désérialisation d'objets exécutables non fiables, chemins canoniques et zéro sortie du répertoire de sauvegardes. Les sauvegardes corrompues doivent être rejetées sans crash.

### Compatibilité 0.8.2

- La campagne héritée (`val`, `aurore`, `nemesis`) demeure chargeable dans un format `legacy_campaign` et ses trois secteurs conservent leurs positions et vols.
- La migration associe des IDs planétaires aux noms historiques et conserve les volumes de ressources sans duplication.
- Les champs anciens absents sont reconstruits **avec une valeur définie par politique** et la décision consignée ; un convoi incomplet ne devient pas « valide par défaut » si le champ absent est nécessaire à un débarquement sûr.
- Migration récursive testée `0.8.1 → 0.8.2 → J9 → J12` sur copies ; retour à une version ancienne possible uniquement avec sauvegarde conservée ou export compatible explicite.

## 49. Résilience de campagne, sécurité et confidentialité

**Fiabilité** : capture de crash non intrusive si disponible localement, journal circulaire limité, code erreur visible, récupération `.bak`, détection manque d'espace disque, autosave à ticks cohérents, reprise après fermeture forcée et stress de zoom.  
**Vie privée** : aucune connexion réseau requise, aucune télémétrie personnelle envoyée par défaut ; logs de diagnostic exportés sur action explicite, possiblement pseudonymisés.  
**Fichiers** : manifests/checksums pour les builds source, versions de dépendances documentées, archives contrôlées, assets de provenance connue.  
**Intégrité** : générateur versionné, checksum du snapshot, références vérifiées, pas de collision d'identifiants, protection des écritures concurrentes et verrou d'une sauvegarde en cours.  
**Portabilité** : chemins `user://` contrôlés, export via partage/copier pour rapports, pas de droit de stockage global supposé acquis.

## 50. Qualité de code, intégration et conduite de versions

- Baseline 0.8.2 **immuable**, archive + SHA-256 dans le rapport de livraison.
- Branches J9, J10, J11, J12 avec incréments conservant les tests antérieurs.
- Les warnings GDScript pertinents bloquent la validation ; typages Variant explicites, analyseur Godot utilisé, pas seulement analyse de texte Python.
- Contrat d'API testé pour `UniverseState`, `CommandBus`, `SeedDerivation`, `SaveMigration`, `ZoomController` ; le code de rendu ne doit pas écrire dans la simulation.
- Toute option destructive/modifiante (migration, suppression de save) doit disposer d'une sauvegarde et d'une possibilité de retour à la baseline.
- Aucun « PASS » fabriqué si Godot/SDK Android absents : `NOT_RUN` est distinct de `PASS`, `FAIL` et `SKIP` justifié.
- Le ZIP source complet accompagne chaque jalon majeur ; fichiers sources, README de changement, limites, commande d'import/export et rapport de preuves.

---

# PARTIE G — QUALIFICATION, ÉQUILIBRAGE ET FEUILLE DE ROUTE

## 51. Stratégie globale de validation : quatre niveaux

**Niveau 1 — Statique** : intégrité archive, structure, nomenclature, typage par analyse de code, manifeste, configuration de build, versions, cohérence des formats. Utile, **insuffisant à lui seul**.  
**Niveau 2 — Godot sans rendu** : import et parse réel, exécution des laboratoires J1–J12, comparaison de hash/replays, assertions de logique et de migration.  
**Niveau 3 — Godot avec rendu** : instantiation des scènes, capture d'erreurs, navigation zoom, gestes simulés, rendu de globe/terrain et tests d'intégration des ressources.  
**Niveau 4 — APK sur S25 Ultra** : installation, ouverture, campagne, tactile, performances, mise en arrière-plan, reprise, chauffe, rapport et validation humaine des scènes.

Une version est **candidate** tant que l'un de ces niveaux nécessaires n'a pas réussi. Chaque résultat porte : `run_id`, version et hash du ZIP, version Godot/export templates, modèle/OS, seed, tick de départ/fin, profil graphique, vitesse, scénario, assertion, valeur attendue, valeur réelle, `PASS/FAIL/SKIP/NOT_RUN`, durée et éventuels logs.

## 52. Recette automatisée « De la vallée aux étoiles »

### Préconditions

**Seed de référence proposée :** `847291` (**[PARAMÈTRE EXPÉRIMENTAL]**, ne sera définitive qu'après validation par le générateur). Deux camps, profils de ressources fixes et contraintes documentées. La recette ne doit ni écraser une sauvegarde normale ni réutiliser une ancienne validation manuelle. Le joueur peut accélérer jusqu'à ×8 si la simulation reste valide et mesurable.

### Étapes intégrales

| ID | Phase | Action/scénario | Résultat exigé |
|---|---|---|---|
| R01 | J1 | Spawn, centre, ouvriers, éclaireur | Positions valides, ressources initiales attendues |
| R02 | J1 | Récolte, dépôt et construction | Bilan conservatif ; aucune ressource négative |
| R03 | J2 | Commerce entre relais | Gain calculé, traçable, non duplicable |
| R04 | J2 | Gué, fort, canon, siège | Ciblage, destruction et occupation cohérents |
| R05 | J2 | Ordre manuel puis délégation | Ordre manuel prioritaire, délégation réversible |
| R06 | J3 | Recherche et usine | Coûts/délais exacts, production industrielle |
| R07 | J4 | Train, dépôt, chars et aviation | Réseau, ravitaillement, contre-unités |
| R08 | J5 | Radar, missile, AA, brouillage | Détection, tir et contre-mesure cohérents |
| R09 | J6 | Satellite orbital et balayage | Durée, coût, révélation limitée, rechargement |
| R10 | J7 | Transport vers Aurore | Cargaison sélectionnée et état unitaire conservés |
| R11 | J7 | Deux transports concurrents | Une fondation payée, capacité d'accueil respectée |
| R12 | J8 | Frégate vers Némésis | Trajet non instantané, mêmes identifiants à l'arrivée |
| R13 | J8 | Deux convois opposés | Interception à la rencontre logique, pas au départ |
| R14 | J8 | Attaque sur secteur masqué | Alerte enregistrée, retour vers le bon secteur |
| R15 | J9 | Génération de planète | Même seed et version → même hash de terrain |
| R16 | J9 | Deux chunks adjacents | Bordures, fleuve, pathfinding et LOD cohérents |
| R17 | J9 | Construction puis éviction du chunk | Retour inchangé : bâtiment, HP, gisement, ordre |
| R18 | J9 | Traversée d'une couture sphérique | Position et mouvement sans saut, sélection préservée |
| R19 | J9 | 1 000 seeds de planète | Absence de départ bloqué selon invariants de carte |
| R20 | J10 | Zoom tactique→globe→orbite→système | Aucune altération de l'état logique |
| R21 | J10 | Route planète→lune→planète | Coût, transit, ravitaillement, arrivée traçables |
| R22 | J10 | Débarquement sur site invalide | Mise en attente/retour, sans perte ni duplication |
| R23 | J10 | Destruction de station en mission | Réacheminement, blocage ou perte selon règles |
| R24 | J11 | Galaxie et graphe stellaire | Même seed → mêmes systèmes et routes |
| R25 | J11 | Exploration et brouillard | Aucune divulgation de route ennemie inconnue |
| R26 | J11 | Flotte et combat intersystèmes | Rencontre/ressources/événements cohérents |
| R27 | J11 | Deux théâtres actifs simultanés | Commandes locales et distantes compatibles |
| R28 | J12 | Reprise après changement d'échelle | Hash de simulation identique à ticks égaux |
| R29 | J12 | Reprise sauvegarde au milieu du transit | Une seule arrivée, aucun cargo fantôme |
| R30 | J12 | Corruption principale, `.bak` valide | Restauration contrôlée avec provenance affichée |
| R31 | J12 | Migration 0.8.2→nouveau format | Pas de duplication de stocks/identifiants |
| R32 | J12 | IA contre IA, camps inversés | Expansion et coût appliqués aux deux camps |
| R33 | J12 | Centres détruits, reconstructeur spatial existant | Défaite refusée tant que reconstruction viable |
| R34 | J12 | Toutes capacités de reconstruction perdues | Défaite globale reconnue sans regarder la caméra |
| R35 | Mobile | Tap, long tap, pinch et navigation | Aucun ordre involontaire critique |
| R36 | Mobile | Changement d'application / verrouillage | Temps de jeu arrêté, reprise exacte |
| R37 | Mobile | 30–60 min de jeu avec transitions | Pas de crash, fuite mémoire ou chauffe anormale |
| R38 | Mobile | ×0,5, ×1, ×2, ×4, ×8 | Hash identique par tick, vitesse réelle mesurée |
| R39 | Mobile | Copie/export du rapport | JSON complet accessible hors espace privé |
| R40 | Final | Partie complète et victoire | Tous les âges et échelles atteignables depuis un départ normal |

**Condition de réussite globale** : aucun échec bloquant sur R01–R40 ; les tests qui exigent Android ne peuvent être marqués PASS par une simulation headless. Les tests de charge « stress » peuvent échouer sur un profil expérimental à condition de documenter une limite et de verrouiller un profil certifié inférieur.

## 53. Matrice de validations transverses

**État** : aucune information sur la caméra ni sur le rendu ne doit changer les décisions au tick N.  
**Économie** : masse conservée à production/perte près ; réservation unique ; transit débité/crédité une seule fois.  
**Combat** : même résultat pour seed/ordres/ticks fixés ; pas d'attaque sans capteur ni à travers un obstacle logique.  
**Pathfinding** : start→goal validé, absence de murs traversés, résilience après destruction de pont et chargement de chunk.  
**IA** : même règle pour équipes 0/1 et états symétriques ; aucune triche de vision.  
**Zoom** : aucune perte de cible, flotte, sélection distante ou ordre ; rendu réinitialisé sans déplacement logique.  
**Sauvegarde** : vérification avant chargement, `.bak`, migrations, statut de chargement exposé, aucune écriture partielle acceptée.  
**Performance** : mesure reproductible sous seed/charge fixe, notamment réactivité pendant streaming.  
**Tactile** : distinction pan/pinch/tap, zones UI sûres et prise en charge du mode gaucher.  
**Qualité visuelle** : variation de biomes, LOD et modèles sans différences de collision/tirs.  
**Conquête** : capacité de reconstruction globale, fronts inactifs et cargos en vol comptés.

## 54. Batteries de tests procéduraux et métamorphiques

La simple validation de dix seeds ne suffit pas pour déclarer un générateur robuste. Définir des campagnes de seeds aléatoires mais **reproductibles** : au moins 1 000 seeds par profil de planète pour le premier portail J9 (valeur initiale), puis 100 seeds galactiques avec analyses de connectivité et 10 campagnes de bout en bout pour J11–J12 (valeurs expérimentales à augmenter selon durée de test).

### Invariants vérifiables automatiquement

- Tous les départs disposent d'une zone d'implantation et des ressources/chemins indispensables pour les premiers objectifs.
- Aucune route indispensable n'est coupée sans alternative ou outil technique accessible dans le temps voulu.
- Les embouchures et fleuves sont compatibles entre LOD/chunks ; aucun « mur » de hauteur à une couture.
- Une unité n'apparaît pas dans l'eau ni dans le volume solide d'un bâtiment au spawn/débarquement.
- Un chunk généré dans un ordre différent garde le même hash de contenu de gameplay.
- Un seed différent produit une diversité mesurable de configuration, sans forcer tous les mondes à être identiques.
- Les zones de départ de factions symétriques sont comparables en richesse et distance d'accès, dans une tolérance à fixer.
- Aucune save écrite au tick N ne dépend de la taille des fenêtres ou du niveau de qualité graphique.
- Les conflits sur deux planètes donnent les mêmes résultats si le joueur regarde alternativement l'une, l'autre ou la galaxie, à ordres identiques.

## 55. Équilibrage quantitatif et télémétrie locale de laboratoire

**Mesures minimales :**
- Temps médian de passage de chaque âge, taux d'échec d'objectif, durée des recherches et bâtiments sous-utilisés.
- Production/minute par ressource, stock inutilisé, fréquence de pénuries, nombre de transferts nécessaires.
- Taux de victoire par camp de départ, âge atteint au premier contact, nombre de centres restants, longueur de front.
- Rapport d'échange coût détruit / coût perdu, efficacité par classe, effet du terrain et des contres.
- Trajets moyens par type, fraction du temps en transit, taux d'interception, temps de construction de colonie.
- Nombre de fronts simultanés gérables sans intervention et temps de réponse de la délégation.
- Temps de mission idle/blocked, fréquence de notifications critiques, taux de clic sur alertes.
- FPS p50/p95/p99, mémoire, temps de chargement chunk, latence tactiles, vitesse effective.

**Protocole d'équilibrage** : jouer / simuler la même configuration avec changement d'un seul paramètre, 20–100 seeds ou matchs symétriques selon coût, comparer moyennes et intervalles, garder les cas extrêmes, documenter décision et résultat. Ne pas « équilibrer » uniquement avec une victoire spectaculaire choisie à la main.

**Pertes acceptables** : par exemple un camp plus ancien peut coûter moins cher et se reproduire plus vite, mais doit subir une supériorité matérielle crédible de la technologie avancée dans les affrontements directs. Les parties face à un âge très supérieur restent possibles par économie, terrain, sabotage et temps, non grâce à un bonus miraculeux.

## 56. Feuille de route détaillée J9–J12

### J9 — Grandes planètes procédurales, régions et chunks

**But** : une grande planète réellement jouable, liée à la simulation RTS historique, sans régression J1–J8.

| Sous-lot | Livrable | Critère de sortie |
|---|---|---|
| J9-A | Générateur mondial versionné : seed, macrogéographie, biomes, eau | Même seed/version = hash identique ; connectivité valide |
| J9-B | Terrain tactique en chunks, LOD, cache et navigation | Déplacements traversant plusieurs chunks sans perte d'ordre |
| J9-C | Vue planétaire/globe et carte de régions | Zoom tactique↔planète, repères de villes et fronts corrects |
| J9-D | Persistance des constructions, dégâts et gisements par delta | Éviction/rechargement ≡ aucune éviction |
| J9-E | Générateur de départ équitable et banc multi-seed | Aucun départ impossible dans la batterie convenue |
| J9-F | Optimisation Android et tests d'interaction | Cible qualité mesurée, aucune erreur de compilation |

**Anti-scope** : ne pas bâtir la galaxie complète pendant J9. **Vertical slice** : Val des Deux Gués transposé en planète de référence, une région proche, une région éloignée, un gué, un site de ressource et une base. Le mode héritage 96×96 reste sélectionnable pour comparaison.

### J10 — Orbite, systèmes stellaires et zoom multi-échelle

| Sous-lot | Livrable | Critère de sortie |
|---|---|---|
| J10-A | Générateur de système : étoile, planètes, lunes, astéroïdes, noms | Même seed/version = même système |
| J10-B | Vue orbitale et carte système jouables | Ordres de flotte, scan, station, route, danger actifs |
| J10-C | Pont de zoom tactique↔globe↔orbite↔système | Aucune perte d'unité, ordre ou référence |
| J10-D | Transports, débarquement, ravitaillement par corps | Pas de téléportation/duplication ; refus et ETA explicites |
| J10-E | IA et notifications interplanétaires | Deux IA peuvent coloniser, défendre et intercepter |
| J10-F | Rendu/recette Android multi-vues | Pas de crash au zoom répété, simulation inchangée |

**Vertical slice** : une planète habitée, deux autres planètes et une lune réellement atteignables, deux points orbitaux de conflit et une mission de ravitaillement aller-retour.

### J11 — Galaxie procédurale et guerre interstellaire

| Sous-lot | Livrable | Critère de sortie |
|---|---|---|
| J11-A | Graphe galactique, zones, seeds et points stratégiques | Connectivité, diversité, validation de 100 seeds |
| J11-B | Vue galaxie jouable, brouillard, routes, sélection de systèmes | Ordres, risques et déplacements effectivement simulés |
| J11-C | Flottes interstellaires, logistique de corridors | Voyage, interception, retraite, escorte sans doublon |
| J11-D | Gouvernance, conquête et défense de plusieurs systèmes | Victoire calculée sur toutes les possessions |
| J11-E | IA galactique et commandement délégué | Deux camps autonomes, mêmes règles de vision/coût |
| J11-F | Sauvegarde et tests des systèmes jamais visités | Géographie stable et progression préservée |

**Vertical slice** : deux systèmes distants, colonie sur chacun, deux flottes antagonistes, une ligne commerciale, un blocus et une bataille planétaire simultanée à une interception stellaire.

### J12 — Empire multi-échelle, finition et version de référence Android

| Sous-lot | Livrable | Critère de sortie |
|---|---|---|
| J12-A | Grand livre des stocks locaux et migration 0.8.2 | Masse conservée ; aucun stock dupliqué |
| J12-B | Commandement empire/front, notifications consolidées | Plusieurs théâtres tenus sans microgestion constante |
| J12-C | Tutoriel, menus, accessibilité, aides et visuels finaux | Parcours complet sans clavier ni souris |
| J12-D | Banc de charge, LOD, streaming, stabilité thermique | Profil de qualité certifié par mesures S25 Ultra |
| J12-E | Recette J1–J12 et migrations de sauvegarde | R01–R40 valides dans les conditions requises |
| J12-F | APK, signature debug/test, documentation de release | APK installable ; absence de crash bloquant ; rapport de recette |

**Règle de promotion** : la publication V1 ne dépend pas d'une densité galactique arbitraire ; elle dépend d'un **mode compact complet, stable et performant**, puis de profils plus grands activés seulement après preuves.

## 57. Portails de qualité entre les jalons

**P0 — Baseline** : ZIP 0.8.2 intact, manifeste et écarts documentés, tests existants identifiés.  
**P1 — Déterminisme** : état canonique et replay de référence, sans dépendance caméra.  
**P2 — Procédural** : planète/carte reproductible, pas de spawn impossible, cohérence des coutures.  
**P3 — Zoom** : transitions réversibles et no-loss, sélection conservée, monde toujours actif.  
**P4 — Spatial** : itinéraires et interceptions valides, flotte non clonable, débarquement sécurisé.  
**P5 — Galaxie** : routes jouables, connaissance partielle, conquête multisystème, IA équitable.  
**P6 — Persistance** : sauvegarde/reprise/migration/backup dans les états extrêmes.  
**P7 — Appareil** : APK importable/installable, performance, tactile, chauffe et stabilité S25 Ultra.  
**P8 — Release** : recette finale, licences, rapport, versions et rollback validés.

Un portail non réussi bloque la promotion, mais pas la création d'une **candidate de laboratoire** clairement nommée.

## 58. Risques structurants, causes et parades

| ID | Risque | Gravité | Signal précoce | Prévention et solution de repli |
|---|---|---|---|---|
| K01 | Galaxie trop grande pour la RAM | Critique | Pics et GC, fermeture Android | Génération paresseuse, caches bornés, profils compact/standard |
| K02 | Charge CPU des unités hors écran | Critique | ×1 déjà non tenu, longs ticks | Planification événementielle, zones d'activité, mesure d'invariance |
| K03 | Fausse continuité au zoom | Critique | Sauts d'unités, états disparus | Référentiels stables, événement unique, tests caméra-indépendants |
| K04 | Génération de carte injuste | Élevée | Départ sans minerai / aucun passage | Validation de seed, correction déterministe, test massif |
| K05 | Changement économique cassant 0.8.2 | Critique | Stocks doublés à migration | Grand livre transactionnel, snapshots avant/après, migrateur éprouvé |
| K06 | Exports Godot instables | Critique | Erreur parser, APK manquant | Pin moteur/export templates, tests headless, CI, APK quotidien quand possible |
| K07 | Tactile saturé par les menus | Élevée | Nombreux taps involontaires | HUD contextuel, cible généreuse, tests sur appareil |
| K08 | IA omnisciente ou asymétrique | Élevée | Expansion camp 1 seule, vision parfaite | Bus d'ordres commun, brouillard par faction, tests IA vs IA |
| K09 | Convois dupliqués/perdus | Critique | Ressources négatives, cargos fantômes | États de transit, ID unique, idempotence, tests crash/reprise |
| K10 | Monde graphiquement terne malgré ampleur | Moyenne | Biomes identiques, repères pauvres | Direction artistique de planète, landmarks, variation contrôlée |
| K11 | Chauffe et baisse de FPS sur sessions longues | Élevée | 60→20 FPS après 20 min | Profils LOD, adaptive rendering, benchmarks thermiques |
| K12 | Dérive scope J9–J12 | Critique | Chaque jalon introduit un nouveau système majeur non testé | Vertical slice, exclusion explicite, portail de qualité |
| K13 | Sauvegardes incompatibles | Critique | Crash au chargement des anciennes parties | Schémas versionnés, fichiers source intacts, migrateurs et `.bak` |
| K14 | Erreurs de type Variant | Élevée | GDScript n'importe pas, warnings bloquants | Cast explicite, analyse Godot, build d'intégration |
| K15 | Sources d'assets non redistribuables | Élevée | Licences manquantes | Inventaire/attribution, contrôle préalable aux exports |
| K16 | Défaite alors qu'une force de reconstruction est en transit | Critique | Fin de partie prématurée | Vérificateur global de reconstruction et scénarios edge-case |

## 59. Priorités produit : MoSCoW

**MUST (indispensable V1 galactique)** : dix âges accessibles ; campagne hors ligne terminable ; planète procédurale jouable ; orbite et système interactifs ; galaxie interactive ; transports physiques/logiques ; simulation hors vue ; délégation ; IA parité ; sauvegarde ; rapports recette ; vitesse ; tactile Android ; performance validée.

**SHOULD (très souhaitable)** : économie locale et routes à capacités, stations orbitales, alertes consolidées, divers biomes, gouvernance de système, profils graphiques, tutoriel complet, ordres composés d'invasion.

**COULD (si marge démontrée)** : météo tactique approfondie, doctrines multiples, marine militaire complète, événements narratifs, diplomatie, conquête de centaines de systèmes en campagne longue, modèles de vieillissement de villes.

**WON'T pour V1** : PvP en ligne, moteur voxel destructible intégral, reproduction à l'échelle 1:1 de la dynamique orbitale, simulation détaillée simultanée de millions d'unités, voyages jouables entre galaxies, générateur d'assets 3D en temps réel côté téléphone.

## 60. Décisions directrices à figer et questions ouvertes

| Référence | Proposition actuelle | Motif | Vérification avant gel |
|---|---|---|---|
| D01 | Dix âges stricts I–X | Continuité et scope | Âge X atteignable en jeu normal |
| D02 | Solo hors ligne | Fiabilité et autonomie Android | Mode avion, reprise app |
| D03 | Deux camps en V1 | Maîtrise IA/simulation | Parité IA, performance |
| D04 | Atlas de galaxies = choix de seed, pas combat | Éviter un étage de complexité sans gameplay | Maquette et tutoriel |
| D05 | Carte planétaire sphérique avec chunks de heightmap | Grande taille sans allocation globale | Seam tests + mémoire |
| D06 | Multi-vues distinctes, transition fluide perçue | Godot mobile réalisable | Tests zoom 1 000 cycles |
| D07 | Pas fixe 10 Hz de départ | Préserve le moteur historique | Invariance et fluidité interpolée |
| D08 | Stocks impériaux deviennent locaux par migration | Donne du sens à la logistique | Grand livre, non-duplication |
| D09 | Visual LOD séparé de logique | Stabilité | Hash caméra-indépendant |
| D10 | IA hiérarchique explicable et équitable | Jeu solo crédible | IA vs IA, tests brouillard |
| D11 | Vitesse ×8 best effort, non garantie | Respect contraintes CPU | Mesurer vitesse effective |
| D12 | Défaite après disparition globale de toute reconstruction viable | Règle de campagne cohérente | Convoi/reconstructeur en vol |
| D13 | Niveau graphique Mobile comme référence | Code 0.8.2, appareil Android | Profilage sur S25 Ultra |
| D14 | Taille galaxie profilée, pas « illimitée » promise | Eviter crash et marketing trompeur | Benchmark 16/64/256 systèmes |
| D15 | Sauvegarde d'état + deltas et backups | Reprise robuste | Crash au milieu d'écriture |
| D16 | Warnings critiques GDScript bloquants | Préserve import Godot | Exécution réelle du moteur |
| D17 | Effets visuels adaptatifs, jamais règles de combat | Réactivité vs équité | Benchmark LOD |
| D18 | Départ équitable vérifié sur plusieurs seeds | Évite parties injouables | Tests 1 000 seeds |
| D19 | Naval complet non bloquant J9 | Focalisation multiscalaire | Première verticale terminable |
| D20 | No-go V1 si Android non validé | Qualité produit | APK + recette physique |

### Arbitrages qui devront réellement être décidés par le développement

**Taille du profil standard** : choisir après test entre 32/64/128 systèmes interactifs ; ne pas promettre 1 024 combats actifs simultanément.  
**Projection planétaire** : confirmer cube-sphere/quadtree vs partition régionale simplifiée selon coût GPU et qualité de zoom.  
**Rendu réaliste** : vérifier si le S25 Ultra maintient 60 FPS dans un RTS dense avec plusieurs centaines d'acteurs ; sinon priorité à 30 FPS stable et lisibilité.  
**Économie locale** : décider date de bascule et règle de migration des anciennes campagnes, avec possibilité de tester en mode expérimental séparé.  
**Victoire sans centre** : l'ancien délai de reconstruction ne doit pas contredire la règle de possession d'une force reconstruisant depuis une autre planète.  
**Niveaux de détail de simulation** : formaliser ce qui peut être agrégé hors scène sans divergences tactiques exploitables.  
**Marine, atmosphères et météo** : approfondir seulement si vertical slice J9–J10 prouve une contribution au gameplay.

## 61. Définition d'une V1 complète et critère de qualité de jeu

La version est **complète** seulement si un nouveau joueur peut : démarrer sans tutoriel forcé ; construire sa première colonie ; progresser jusqu'à l'industrie ; combattre ; lancer son premier satellite ; dézoomer sur sa planète ; visiter une lune ; fonder une seconde colonie ; consulter un système entier ; accéder à la galaxie ; découvrir un second système ; y envoyer une flotte ; gérer un combat local pendant qu'une flotte voyage ; sauvegarder ; quitter Android ; reprendre ; conclure une victoire ou une défaite dont la cause est compréhensible.

Ce parcours doit être **agréable**, pas seulement exécutable. Lors de tests humains, vérifier l'absence de microgestion excessive, la compréhension des icônes et des transferts, le niveau de contrôle sur la délégation, le nombre de gestes nécessaires et la lisibilité du zoom. Une fonctionnalité technique réussie qui impose une interface inutilisable ne satisfait pas le cadrage.

---

# PARTIE H — RÉFÉRENCES, TRAÇABILITÉ ET ANNEXES

## 62. Glossaire

**Âge** : palier techno-industriel indépendant d'une faction. **Biomes** : zones écologiques/visuelles cohérentes. **Chunk** : portion générée/chargée à la demande. **Convoi** : groupe d'unités/ressources déplacé entre emplacements. **Déterminisme** : mêmes états/ordres/seed → même évolution logique. **Délégation** : objectif donné à une IA subordonnée. **Deltas** : modifications persistantes par rapport à une génération procédurale. **Emplacement** : état spatial autoritatif d'une entité. **Fog of war** : limite de connaissance d'une faction. **Graine/seed** : clé d'un univers reproductible. **Hystérésis** : marge empêchant l'aller-retour intempestif de zoom. **LOD** : niveau de détail visuel. **P95/P99** : centiles de distribution d'une mesure ; ici, les temps de frame où 95/99 % des frames ont une durée inférieure ou égale à la valeur. **Quadtree** : partition hiérarchique spatiale. **Snapshot** : instantané cohérent de la simulation. **Tick** : pas logique discret. **Transit** : entités existantes entre origine et destination. **Vertical slice** : petite partie du jeu intégrant tous les niveaux critiques d'une fonctionnalité de bout en bout.

## 63. Contrats invariants de développement

```text
INV-001 : la caméra n'affecte pas le résultat de la simulation.
INV-002 : toute entité logique possède un identifiant stable unique.
INV-003 : une cargaison est toujours localisée : origine / vol / attente / destination.
INV-004 : aucune ressource dépensée n'est débitée deux fois.
INV-005 : une ressource transférée n'est pas créditée avant arrivée validée.
INV-006 : un passage d'âge conserve les unités, files et constructions existantes.
INV-007 : une planète non affichée conserve ses fronts et leurs événements critiques.
INV-008 : même seed + version du générateur = mêmes données fondamentales.
INV-009 : changement de qualité graphique = aucun changement de règle métier.
INV-010 : un zoom/chargement/retour Android n'émet aucun ordre de jeu par lui-même.
INV-011 : une IA n'utilise pas une information que son camp ne possède pas.
INV-012 : chaque déplacement spatial consomme une durée logique positive.
INV-013 : une interception ne peut être résolue plusieurs fois pour une rencontre.
INV-014 : un débarquement invalide n'entraîne ni perte ni duplication.
INV-015 : défaite globale = absence de centre ET de reconstruction viable.
INV-016 : un tick ne peut être sauté pour maintenir un FPS.
INV-017 : sauvegarde non validée = jamais installée silencieusement comme état courant.
INV-018 : les migrations sont versionnées, réversibles par sauvegarde intacte.
INV-019 : rapport « PASS » seulement après exécution réelle du test concerné.
INV-020 : un build Android non testé reste étiqueté « candidate ».
```

## 64. Références techniques publiques vérifiées

Ces références cadrent les choix de moteur, **elles ne prouvent pas que le code du projet utilise déjà ces fonctionnalités** :

1. Godot — [Overview of renderers](https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html) : différences Mobile / Forward+ / Compatibility ; les fonctions de rendu doivent être choisies selon la plateforme.
2. Godot — [Background loading](https://docs.godotengine.org/en/stable/tutorials/io/background_loading.html) : chargement asynchrone de ressources via `ResourceLoader`.
3. Godot — [Thread-safe APIs](https://docs.godotengine.org/en/stable/tutorials/performance/thread_safe_apis.html) : arbre de scène actif non thread-safe ; précautions de concurrence.
4. Godot — [Optimization using MultiMeshes](https://docs.godotengine.org/en/stable/tutorials/performance/using_multimesh.html) : bénéfices d'instanciation et limites du culling par instance, justifiant le découpage par chunks.
5. Godot — [Introduction to physics interpolation](https://docs.godotengine.org/en/stable/tutorials/physics/interpolation/physics_interpolation_introduction.html) : distinction ticks fixes et rendu/interpolation.
6. Godot — [Exporting for Android](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html) : chaîne d'export, SDK et modèles d'export adaptés.

## 65. Sources internes de référence

- `sillons-empire-j678-correctifs-0.8.2-source-complet.zip` : dernière candidate source J1–J8 à préserver ; état Android non démontré.
- `sillons/README-CORRECTIFS-0.8.2.md` : correctifs des anomalies 0.8.1, fonctions livrées, limites et scripts de validation.
- `sillons/README-J678.md` : sectorisation spatiale, satellite, transport, recherche, trois secteurs et règles provisoires.
- `sillons/sim/rules.gd` : noms des dix âges, trois ressources, `TICK_RATE`, types d'unités et bâtiments existants.
- `sillons/sim/star_campaign.gd` : secteur courant, ressources et technologies partagées, transit, simulation multicarte.
- `sillons/sim/campaign_save.gd` : snapshot de campagne, contrôle d'intégrité et restauration.
- `sillons/game/game_config.gd` : vitesses, réglages, état de recette en session.
- `Sillons_Empire_Cadrage_Global_V1.0.md` : première vision de J9–J12, reprise et considérablement développée ici.

## 66. Livrables associés et mode d'emploi du cadrage

Ce document constitue la **source métier maîtresse**. Les tables annexes `Matrice_Recette_J1_J12_V2.0.csv` et `Registre_Decisions_Sillons_V2.0.csv` sont destinées au suivi opérationnel. **Toute réalisation doit annoter le statut de chaque exigence** (`proposé`, `développé`, `testé Godot`, `testé Android`, `accepté`) et ne pas confondre ces étapes.

**Ordre recommandé de lecture :** promesse et jeu (A) → économie et âges (B) → géographie (C) → combats/commandement (D) → expérience (E) → architecture (F) → validation/roadmap (G). Pour développer J9, traiter d'abord INV-001, INV-002, INV-008, INV-017, P0 et P1.

### Verdict de cadrage

*Sillons d’Empire* doit être pensé comme **un RTS persistant hiérarchique, pas une juxtaposition de cartes**. Le monde peut être immense, généré à la demande et visuellement continu sans être intégralement simulé en 3D au même niveau. Le succès de J9–J12 dépend du **contrat de déterminisme**, de la **persistance des entités**, de la **comptabilité des déplacements**, du **commandement délégué**, et d'une **vraie recette Android**. L'ambition procédurale ne doit jamais masquer ces obligations.
