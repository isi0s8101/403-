# SILLONS D’EMPIRE — CADRAGE INTÉGRAL EXPERT V3.0
## GDD · Architecture Godot 4 · Direction artistique 3D Android · Spécification J13 · Plan de validation

**Référence produit :** Sillons d’Empire — RTS 3D Android / solo hors ligne / dix âges I–X / simulation multi-échelle.  
**Référence source inspectée :** `sillons-empire-j12-chantier-naval-orbital-0.12.3-source-complet.zip` ; SHA-256 `ee6b0dda0a76b03816035139726f98d180b2329dffb835c53b7fbcaeaf4e367e`.  
**Date :** 13 novembre 2026. **Statut :** spécification de référence, **pas une livraison de code J13**.  
**Appareil de recette principal :** Galaxy S25 Ultra, orientation paysage. **Moteur :** Godot 4 / GDScript / renderer Mobile.  
**Hiérarchie :** règles explicitement validées par l’utilisateur > données constatées dans 0.12.3 > décisions recommandées ici > paramètres expérimentaux.  
**Rappel impératif :** les passes statiques de 0.12.3 ne démontrent ni compilation Godot ni fonctionnement en jeu Android. Ne pas qualifier ce jalon de stable sans tests réels.

### Légende de traçabilité

- **[EXISTANT-0.12.3]** : identifié dans le code ou les README de l’archive source (présence ≠ test d’exécution validé).
- **[VALIDÉ-J13]** : exigence expressément retenue par le porteur de projet, à développer.
- **[PROPOSÉ]** : arbitrage détaillé proposé par ce cadrage ; peut être ajusté après simulation et tests de gameplay.
- **[CIBLE-TEST]** : seuil de performance ou équilibrage destiné à être mesuré, jamais présenté comme résultat.
- **[HORS-J13]** : fonctionnalité non nécessaire pour valider le premier socle de J13.

---

# PARTIE I — VISION, PÉRIMÈTRE ET INVARIANTS

## 1. Promesse du jeu

Diriger une civilisation depuis ses premiers ouvriers jusqu’à un empire interstellaire. Le joueur peut bâtir, produire, explorer, commercer, mener des batailles tactiques et déléguer progressivement la gestion civile et militaire. Un seul univers logique persistant relie les vues terrain, globe, orbite, système et galaxie. L’expansion finale n’élimine pas les décisions tactiques : elle les rend plus rares, plus importantes et mieux assistées.

**Genre :** RTS historique/futuriste, construction de civilisation, économie industrielle et commerciale, city builder stratégique, grande stratégie 4X temps réel, logistique spatiale. **Priorité :** boucle jouable et déterministe, stratégie compréhensible, IA honnête, ergonomie tactile, intégrité des sauvegardes, performance Android, puis richesse visuelle.

## 2. Règles immuables

1. Dix âges I–X, progression initialement indépendante par camp. J13 introduit en plus une **progression locale par planète** ; une colonie fondée par un empire âge X commence à l’âge VII.
2. Les renforts avancés sont autorisés sur les colonies jeunes, mais chaque transfert nécessite un véhicule réel ou une mission de transport abstraite **avec unité identifiable, origine, destination, capacité, chargement, ETA, risque et arrivée vérifiée**. Les renforts conservent leur âge de fabrication, statistiques et équipement.
3. **Produire ou rechercher localement** une troupe/un bâtiment exige l’âge, la technologie, le producteur et les ressources de la planète concernée. Une frégate importée ne débloque pas l’arsenal local.
4. Les **zones résidentielle (R), commerciale (C), industrielle (I)** et leur équilibre cible sont paramétrables. Elles alimentent démographie, bénéfices, fabrication et économie militaire.
5. À l’âge X **local**, un gouverneur civil planétaire est activé par défaut et construit progressivement jusqu’à l’occupation de **100 % des surfaces constructibles et autorisées**, sans convertir océans, pentes interdites, territoires adverses ou réserves réglementées ; la gestion reste suspendable/reconfigurable.
6. Hôpitaux, police, pompiers, eau, électricité et voies de communication ont des **capacités et zones de service vérifiables**, avec implantation automatique recherchant la couverture complète des zones habitées.
7. Avant toute **attaque terrestre/débarquement** d’une planète, toutes les stations de commandement orbital ennemies **opérationnelles** qui la protègent doivent être détruites. Les attaques spatiales contre ces stations restent possibles. Sans station opérationnelle, aucun verrou orbital n’existe.
8. Le chantier naval orbital de l’âge IX est un **centre de commandement spatial**, producteur de drones, sondes, navettes et modules. La frégate reste liée aux prérequis âge X.
9. Les **bénéfices monétaires nets** remontent à une trésorerie impériale centralisée. Les **ressources physiques** restent localisées, sans téléportation ; transferts réels et inventaires traçables.
10. Le jeu fonctionne hors ligne. La caméra, le zoom, les menus et la vitesse de rendu ne changent jamais les règles de simulation.
11. Pas de duplication de ressources, de colons, de troupes ni de bâtiments pendant les transferts, changements d’échelle, chargements et reprises.
12. L’élimination d’un camp exige la perte de tous les centres de commandement terrestres/orbitaux et de toutes les **forces capables d’en reconstruire**, selon une capacité de reprise clairement définie et testée.
13. L’IA est soumise aux mêmes règles de connaissance, coûts, logistique, production, technologie et verrou orbital que le joueur, hors handicaps explicitement signalés par le niveau de difficulté.

## 3. Statuts de développement : réalité vs cible

| Domaine | 0.12.3 : état observé | J13 : développement à produire |
|---|---|---|
| Simulation | `SimWorld`, `StarCampaign`, pas logique `Rules.TICK_RATE=10`, monde historique, régions et étoiles procédurales | Planètes avec districts macro, développement civil persistant à l’échelle mondiale |
| Âges | `StarCampaign.ages`, recherches de vues, `AgeProgression` et niveaux de producteurs | `ColonyTechState` local par planète, règles de migration et de compatibilité |
| Économie | `food/wood/ore` par système via `system_stocks` ; alias `resources` pour Sol | Stocks par planète + entrepôts/relais systémiques, matériaux transformés, crédits centraux |
| Habitat | `maison` fournit capacité de population ; pas de zonage économique complet | Maisons, immeubles, naissances/arrivées, employés, recrutement, saturation |
| Commerce | Marché historique et commerce existant simplifié | Petits commerces, marchés, centres commerciaux, chaînes de vente et bénéfices nets |
| Industrie | `usine` et producteurs militaires | Raffineries, aciéries, électronique, composants génériques, fabrication civile/militaire |
| Services | Pas de police/pompiers/hôpitaux mondiaux à couverture garantie | Services avec temps de réponse, capacité, réseaux et diagnostic des zones découvertes |
| Orbite | `OrbitalIndustry` : chantier IX, drones, modules, navettes, intercepteurs, frégates X | Règle globale d’interdiction de débarquement tant qu’un commandement orbital défensif subsiste |
| Flottes | Missions avec ETA, interception/combat simplifiés | Transport militaire auditable, siège orbital/atterrissage en phases, escorte et ravitaillement |
| Gouvernement | Directives `observe/defend/supply/explore` par système | Gouverneur planétaire civil, priorités, sécurité, budgets, explications et interventions |
| Graphisme | Terrain 3D, globe, carte spatiale, éléments procéduraux, HUD tactile | Ville 3D modulaire réaliste, bâtiments de services, overlays, HLOD, streaming planétaire |
| Recette | Vérifications statiques + scénarios Godot fournis mais non exécutés ici | Tests de migrations, budgets, graphes, conquête, IA, longévité, rendu Android réel |

**Point de rupture à traiter en premier :** dans 0.12.3, l’âge demeure global au camp et le stock principalement systémique. Ne **jamais** ajouter le zonage comme simple effet de caméra ou dupliquer les stocks existants : la simulation doit être refactorisée par couches en conservant les IDs et sauvegardes hérités.

## 4. Boucles de jeu

- **Micro (secondes)** : sélectionner, ordonner, construire, lancer une recherche, commander escouade, lancer navette, consulter état d’un district.
- **Méso (minutes)** : urbaniser quartier, équilibrer R/C/I, ouvrir service, produire équipements, défendre front, organiser convoi, sécuriser une orbite.
- **Macro (heures)** : progresser d’âge, industrialiser planète, ouvrir routes interstellaires, capturer système, installer colonie âge VII, développer plusieurs gouverneurs.
- **Très long terme (sessions)** : répartir population et industrie entre mondes, sécuriser corridors stratégiques, arbitrer budgets civils/militaires, compléter la colonisation de la galaxie sélectionnée.

La croissance doit générer des décisions (où produire ? où importer ? quelle orbite défendre ?) sans exiger de vérifier chaque carrefour une fois l’automatisation débloquée.

## 5. Modes de partie

Escarmouche solo contre IA (prioritaire), campagne civilisation longue durée, partie rapide avec vitesse/recherche ajustées, observation IA vs IA, laboratoire de reproduction sur seed fixe. Multijoueur, cloud obligatoire et économie payante exclus de J13. Paramètres : seed, taille de monde, densité de ressources, IA, âge de départ, démarrage colonie, nombre de systèmes, ratio R/C/I, rythme des catastrophes, difficulté militaire et financière, vitesse, protections environnementales.

## 6. Conditions de victoire/défaite

- **Victoire militaire** : camp adverse sans centres de commandement terrestres ou orbitaux encore opérationnels, sans drone/ouvrier/transport capable, selon un chemin plausible et financé, d’en rebâtir dans un délai borné. Une flotte seule sans constructeurs ne préserve pas indéfiniment l’empire.
- **Victoire économique/civilisationnelle** : option de scénario, jamais imposée dans une escarmouche militaire ; seuils paramétrables (colonies, population, production, réseau commercial) avec maintien dans le temps.
- **Planète conquise** : la défense orbitale a été neutralisée, le débarquement effectué, puis les objectifs terrestres effectivement occupés/détruits selon les règles du scénario. La destruction de la station **ne conquiert pas automatiquement** la planète.
- **Population civile** : indicateurs et conséquences de guerre simulés sans mise en scène graphique gratuite. Préférer la lisibilité stratégique et la réparation des infrastructures.

---

# PARTIE II — CHRONOLOGIE, TECHNOLOGIES ET DOCTRINES

## 7. Les dix âges : identité ludique et transitions

| Âge | Nom source | Identité et production | Transformation graphique | Échelle de décision |
|---|---|---|---|---|
| I | Exploration | Centre, ouvriers, éclaireurs, maisons, caserne, lanciers | Architecture rudimentaire, bois, terre, matériaux locaux | Village/région tactique |
| II | Commerce | Marché, caravanes, tireurs/cavaliers, cartographie | Routes, places marchandes, premières façades cohérentes | Région et globe après recherche |
| III | Forteresses | Forts, ateliers, canons, siège | Maçonnerie lourde, remparts, fumées et dégâts | Défense et siège |
| IV | Industrie | Usines, fusiliers, obusiers, ateliers de transformation | Brique/métal, chaudières, cheminées, réseaux | Chaîne de production |
| V | Empire | Académie, grenadiers, standardisation administrative | Architecture monumentale, réseau urbain dense | Intégration économique |
| VI | Mécanisation | Chars, avions, trains, logistique terrestre, aérodromes | Acier, béton, routes/rails, équipements motorisés | Fronts mécanisés |
| VII | Dissuasion | Missiles, radars, antimissiles ; âge de départ des colonies | Complexes modernes, zones sécurisées, électronique | Colonies technologiques naissantes |
| VIII | Numérique | Drones, brouilleurs, automatisation de production | Façades intelligentes, capteurs, panneaux, drones | Détection/contre-mesures |
| IX | Ère orbitale | Spatioport, navettes, satellites, **chantier naval orbital** | Architecture aero-spatiale, hangars, modules en orbite | Planète/orbite/système |
| X | Ère interstellaire | Frégates, navigation stellaire, carte galactique, **gouverneur planétaire** | Mégapoles cohérentes, réseaux régionaux, infrastructures spatiales | Plusieurs planètes/systèmes |

La liste reprend les noms d’âge de `Rules.AGES`. Les technologies locales J13 ne doivent pas supprimer les acquis des parties existantes. Les prérequis restent des tables versionnées, jamais des contrôles éparpillés dans l’interface.

## 8. Deux niveaux technologiques simultanés

**Niveau impérial** : routes galactiques découvertes, connaissance stratégique, doctrine générale, recherche interstellaire, trésorerie et diplomatie. **Niveau colonial** : `local_age`, bâtiments/industries effectivement développés, arbres de recherche et chaîne de fabrication accessibles. `empire_age` vaut au maximum le palier stratégique atteint par la civilisation ; `colony_age` peut rester inférieur.

Règle : `can_produce(planet, unit)` requiert `planet.local_age >= unit.required_age`, technologies locales, site producteur, matériaux, main-d’œuvre, énergie et éventuellement capacité de transport. Une unité **déjà créée et importée** conserve son droit d’exister, de combattre et d’utiliser son équipement sans contraindre la colonie réceptrice à connaître sa technologie. Entretien : carburant, munitions et composants spéciaux doivent être importés si la colonie ne sait pas les fabriquer ; une maintenance dégradée peut réduire progressivement sa disponibilité, sans détruire arbitrairement l’unité.

**Nouvelle planète fondée par un empire âge X** : âge VII local, tronc de connaissance civil minimale (construction du centre, eau, énergie, habitats, sécurité, accès au spatioport à déverrouiller). Progression VII → VIII → IX → X locale, avec coûts, capacités industrielles et recherches vérifiables. Une planète conquise **ne doit pas être réinitialisée automatiquement** à VII : conserver les bâtiments capturés, résoudre les dégâts, définir des règles séparées d’occupation et de reprise technologique. Cette distinction est un ajout recommandé important.

## 9. Arbre de vues

`Terrain (I) → Globe (II + Cartographie terrestre) → Orbite (IX + Observation orbitale) → Système (IX + Navigation interplanétaire) → Galaxie (X + Navigation stellaire + Cartographie galactique)`.

Le joueur peut revenir vers les vues déjà maîtrisées. En J13, distinguer **technologie de navigation impériale** (caméra globale) et **infrastructure locale** (possibilité d’agir sur une orbite) : une nouvelle colonie âge VII peut être affichée depuis la carte galactique de son empire âge X, sans pouvoir produire des frégates. Ne jamais rendre une planète invisible parce que son âge local est trop bas ; masquer les commandes de construction non autorisées, pas la connaissance existante.

## 10. Arbre d’évolution par bâtiment

`AgeProgression` existe avec tiers I/II/III locaux et évolutions par type d’unité : niveaux bâtiment II (+20 % PV, +10 % production) et III (+40 % PV, +20 % production) ; troupes II (+12 % PV, +10 % attaque), III (+24 % PV, +20 % attaque). Ces bonus sont provisoires. J13 conserve ce contrat pour une caserne ou une usine nouvellement construite sur une colonie.

L’origine de production a une identité globale `planet_id/building_id` pour éviter collision de clés entre régions. Les unités déplacées gardent leur tier et ne reçoivent plus rétroactivement une évolution locale de caserne distante, sauf protocole de modernisation/retour en atelier. Une installation capturée ne donne pas immédiatement accès aux recherches de son ancien propriétaire ; elle peut fonctionner en mode dégradé, être démantelée ou réparée après appropriation.

## 11. Doctrines stratégiques recommandées

- **Développement** : population / industrie / commerce ; modifie l’ordre de priorité du gouverneur, pas les règles physiques.
- **Militaire** : défense de zone / expansion / supériorité orbitale / reconquête ; autorisations par objectif et budget.
- **Commerce** : taxation basse pour croissance / taxation modérée / extraction de trésorerie ; externalités sur emploi, stabilité et profit.
- **Colonisation** : base légère / base fortifiée / colonie industrielle ; les trois démarrent âge VII, mais diffèrent dans la cargaison de départ financée et transportée.

Ne pas rendre une doctrine irréversible sans avertissement. Tester les stratégies dominantes et éviter que le choix « plus d’industrie » donne simultanément le meilleur revenu, la meilleure armée et la meilleure population.

---

# PARTIE III — ÉCONOMIE PLANÉTAIRE ET URBANISATION J13

## 12. Modèle de territoire planétaire

Chaque planète a un masque géographique immuable et versionné : océan, lac, cours d’eau, relief, pente, biome, climat, gisements, surface constructible, espace protégé, risques, frontières administratives/territoires contestés, réseaux préexistants. Les secteurs dynamiques sont représentés par un **graphe de districts** ; un district contient des **parcelles** d’occupation, des tronçons de réseau et des agrégats de population/production. Les façades 3D détaillées ne constituent pas l’état canonique du jeu.

**[PROPOSÉ]** Employer une partition géodésique ou des cellules hiérarchiques quasi égales en surface (par exemple cube-sphere et subdivisions) ; éviter de compter directement les cellules d’une grille longitude/latitude comme des surfaces égales, surtout près des pôles. L’identité `planet_id/tile_id/district_id/parcel_id` est stable entre zooms et sauvegardes. Un terrain 3D tactique chargé correspond à une fenêtre sur ces cellules.

Règle de conquête/gestion : la fraction de planète développée se calcule sur les parcelles **contrôlées, constructibles et autorisées** ; ne jamais lancer de chantiers sur l’océan ou une colonie ennemie pour satisfaire artificiellement « 100 % ».

## 13. Les trois zones et leurs bâtiments

| Zone | Bâtiments de base | Niveaux avancés | Apports | Limites |
|---|---|---|---|---|
| R — Habitation | Maison, pavillon, petit collectif, résidence de colons | Immeuble, tour résidentielle, mégabloc, habitat intelligent | Population, capacité, main-d’œuvre, candidats aux recrutements, demande de biens/services | Besoin de nourriture, eau, électricité, sécurité, emplois |
| C — Commercial | Petit commerce, comptoir, marché, atelier de service | Supermarché, centre commercial, pôle tertiaire, réseau d’échanges | Ventes, crédits, attractivité, redistribution, flux marchand | Clients solvables, produits fabriqués, logistique, personnel |
| I — Industrielle | Atelier, scierie, fonderie, raffinerie, usine | Complexe industriel, électronique, chimie, mécatronique, chantier de haute technologie | Matériaux transformés et composants de bâtiments/unités | Matières, énergie, eau, travailleurs, transport, maintenance, pollution |

**Important :** une maison **ne produit pas gratuitement des soldats**. L’habitation crée une capacité démographique ; les recrues sont prélevées dans la population disponible et entraînées dans une caserne, une académie ou une autre installation militaire. Des colons naissent/arrivent dans les quartiers résidentiels, puis sont sélectionnés, préparés et embarqués pour une mission coloniale. À l’âge IX–X, l’habitat orbital peut compléter la capacité de vie spatiale ; il ne se substitue pas automatiquement à la population terrestre.

**Chaînes d’unités :** habitations → population/formation → producteur militaire → matériaux/composants → unité entraînée → entretien/logistique → mission. **Chaînes d’infrastructure :** extraction → transformation → composants → transport local → constructeur → bâtiment → service/rentabilité.

## 14. Équilibre R/C/I configurable

Paramètre proposé `zoning_target = {"R":0.45,"C":0.25,"I":0.30}` ; la somme doit valoir exactement 1 (tolérance numérique définie) avec bornes configurables. Ces pourcentages désignent **les surfaces effectivement zonées et construites**, **hors** routes, services publics, défense, espaces verts et réserves foncières. Le gouverneur optimise l’écart à la cible sans imposer sa réalisation si elle crée une famine ou une rupture énergétique.

Écart de zonage : `E_z = |R_act-R_target| + |C_act-C_target| + |I_act-I_target|`; indicateur `balance = max(0, 1 - E_z/2)` avec toutes les parts dans [0,1]. Le simple ratio **ne suffit pas** : une zone résidentielle de gratte-ciel peut loger bien plus de population par hectare qu’un village ; utiliser séparément densité, population/logement, capacité d’emploi et production par surface.

**Ordre de sûreté** : (a) survie eau/nourriture/énergie, (b) sécurité incendie/santé, (c) solvabilité et stocks critiques, (d) emplois et flux industriels, (e) équilibrage R/C/I, (f) esthétique et expansion. Si la cible industrielle est trop faible pour soutenir la flotte, alerter puis proposer un ajustement explicite ; **ne pas modifier silencieusement** le ratio choisi.

Exemples de profils : équilibré 45/25/30 ; résidentiel 60/20/20 ; industriel 25/20/55 ; commerce 40/45/15. Ce sont des presets de conception non validés par des playtests. Tous doivent rester accessibles et réversibles.

## 15. Demande résidentielle et démographie

Variables : `population_total`, `housing_capacity`, `births`, `immigration`, `emigration`, `working_age`, `employed`, `available_workers`, `military_recruits`, `colonists_reserved`, `health`, `stability`, `education`, `food_access`, `water_access`, `power_access`. Le modèle peut rester agrégé par district ; pas de simulation individuelle de milliards d’habitants.

Chaque tick économique : naissance/immigration sous conditions, sortie d’emploi, mortalité abstraite et pénuries (mécanique de simulation non graphique). Les militaires recrutés diminuent réellement la main-d’œuvre civile disponible ; les colons en transit sont réservés et ne travaillent plus sur la planète d’origine. Les démobilisations peuvent réintégrer la population, jamais la dupliquer.

**Formule indicative** : `population_next = population + births + arrivals - departures - losses`; toutes les composantes sont positives et produites une seule fois par événement. `available_workers = max(0, working_age - employed - recruited - travelers_reserved)`. Limites d’intensité recommandées pour que le joueur n’ait pas besoin de gérer des ménages individuels.

## 16. Commerce, marchés et bénéfices

Chaîne : produits disponibles → acheminement → salariés/vendeurs → clientèle → volume vendu → chiffre d’affaires → charges salariales + consommation + maintenance + impôts locaux éventuels → **bénéfice net**. Seul le bénéfice disponible après obligations et réserve opérationnelle est transféré à `ImperialTreasury` par écriture équilibrée, à une cadence discrète et documentée. Ne pas compter simultanément la même valeur en prix d’exportation et en ventes locales.

Commerces : petit magasin (basse capacité mais faible coût), marché (chaîne locale), centre commercial (haut débit mais dépendance au réseau), bourse/terminal d’échanges (âge tardif, commerce interplanétaire). Les crédits financent administration, construction et stratégies ; **acheter des crédits ne crée pas de minerai**. Les importations exigent une commande de fret payée et un manifeste de matériaux.

Calcul indicatif : `net_profit = sales_revenue - input_cost - payroll - utility_cost - maintenance - transport_cost`; `transfer_to_empire = max(0, net_profit - local_reserve_allocation)`. Éviter de comptabiliser deux fois `input_cost` si les matériaux sont valorisés en stock au débit. Le livre de comptes doit équilibrer chaque transfert.

## 17. Industrie et recettes

Conserver le stock historique `food/wood/ore` pour compatibilité ; étendre la gestion J13 à des marchandises manufacturées versionnées : `alloy`, `concrete`, `electronics`, `machinery`, `fuel`, `medical_supplies`, `consumer_goods`, `ship_parts` (noms internes **proposés**, à valider). Chaque recette décrit entrées, sorties, temps, énergie, eau, travailleurs, site requis, âge local, technologie et pollution. La nourriture est produite par agriculture/hydroponie et peut être transformée en rations sans générer de nourriture gratuite.

| Industrie | Entrées indicatives | Sorties indicatives | Usage |
|---|---|---|---|
| Scierie | `wood` brut + énergie | Matériaux bois | Habitats, réseaux, bâtiments anciens |
| Fonderie | `ore` + énergie + main-d’œuvre | `alloy` | Armes, chars, infrastructures métalliques |
| Bétonnerie | Minerai/agrégats + eau + énergie | `concrete` | Immeubles, routes, hôpitaux, tours |
| Électronique | Alliage + intrants rares + énergie | `electronics` | Radar, drones, réseaux numériques |
| Usine mécanique | Alliage + électronique + carburant | `machinery` | Véhicules, bâtiments industriels, constructeurs |
| Raffinerie | Ressources énergétiques / imports | `fuel` | Transports, aviation, navettes |
| Chantiers spatiaux | Alliage + électronique + pièces + énergie | `ship_parts`, modules, vaisseaux | Station IX, frégates X |
| Usine civile | Matières transformées + travailleurs | `consumer_goods` | Commerces, stabilité et crédits |

**Aucun cycle de recettes ne doit créer des ressources à partir de zéro** ; les conversions de masse sont schématiques mais économiquement conservatrices. Garantir des chemins de substitution si une planète n’a ni forêt ni minerais faciles : réserves initiales crédibles, industrie de recyclage, importation payante, extraction orbitalement autorisée. Les stocks physiques sont limités par capacité et emplacement ; un stock plein suspend la production et explique pourquoi.

## 18. Énergie, eau et maintenance

Une centrale produit une puissance disponible ; chaque bâtiment consomme de l’énergie selon charge. L’eau est produite/captée, traitée, stockée et distribuée. Ces deux services reposent sur **réseaux connectés**, capacité, pertes et priorité, pas sur un cercle magique autour de la centrale. Routes/rails/conduites/câbles ont un coût, un état de réparation et des débits. Des générateurs et citernes autonomes rendent possibles des colonies isolées à petite échelle.

En cas de pénurie, ordre de priorité configurable : centre de commandement, hôpitaux, eau, pompiers, zones résidentielles, industrie critique, commerce non essentiel. Ce schéma doit être transparent et limité par des capacités physiques. Les incendies peuvent couper une ligne et faire basculer les districts sur réserve. Conserver un plan d’arrêt sûr et de reprise sans effacer les commandes en cours.

## 19. Couverture : hôpitaux, police, pompiers

| Service | Capacité | Mesure de couverture | Échec et conséquence |
|---|---|---|---|
| Hôpital / dispensaire | Patients/tick, effectifs, énergie, stocks médicaux | Temps d’accès sur routes + capacité de soins | Pénalité de santé et croissance, alertes |
| Police / sécurité civile | Agents/patrouilles, compétence, énergie | Temps de patrouille, population couverte, charge | Instabilité locale, vols/sabotages abstraits |
| Pompiers / secours | Véhicules, équipes, réserve d’eau | Temps de trajet effectif jusqu’aux parcelles | Risque de propagation, pertes immobilières |
| Eau | Débit, pression, réservoirs | Connexion, débit suffisant, qualité | Rupture d’habitation et industries |
| Électricité | Production, lignes, stockage | Connexion, tension/capacité simplifiée | Arrêt partiel, secours critiques |

**Algorithme spatial** : chaque district est un nœud d’un graphe routier ; arêtes pondérées par distance, vitesse, charge et dommages. Pour les services mobiles, calculer une plus courte durée de trajet depuis chaque caserne/hôpital/poste vers les zones de demande ; intégrer la capacité par station et répartir les charges. `served(district, service) = reachable && travel_time <= threshold && capacity_allocated >= demand`. Les services réseau utilisent un graphe de flux/coût et non un temps de déplacement.

**[CIBLE-TEST]** couverture >= 99 % de la population pour déclencher « ville desservie » ; **objectif final 100 %** des zones habitables accessibles, sauf secteurs explicitement non aménageables. Un district inaccessible ou sous-capacité reste rouge, avec cause et solution. Les temps cibles sont des unités de gameplay paramétrables, non des minutes légales ou réalistes affirmées.

**Placement automatique** : résoudre approximativement un problème de localisation capacitaire avec coût d’implantation, connexité, contraintes de terrain et couverture restante ; une heuristique gloutonne déterministe + amélioration locale est suffisante en premier lot, puis tests comparatifs contre solution exhaustive sur petits jeux. La simple superposition de rayons de cercle **ne satisfait pas** la couverture. Le système doit reconstruire des postes si routes et population évoluent.

## 20. Risques, incendies, catastrophes et cohérence civile

Feu urbain et industriel selon densité, matériaux, prévention, météo et distance ; panne électrique, contamination d’eau, accident industriel, catastrophe naturelle dépendant du biome. Les simulations hors écran agrègent les probabilités et dégâts sur une période déterministe, sans créer de dizaines de milliers d’entités physiques. Les pompiers protègent les parcelles par capacité réelle ; aucune animation d’incendie ne doit être le seul indicateur d’un risque économique.

**[PROPOSÉ]** Réserver espaces verts, zones tampon autour d’industries polluantes, couloirs de secours et aires de stockage, plutôt que recouvrir aveuglément chaque cellule par des immeubles. L’objectif 100 % signifie planification/occupation utile de la surface urbanisable dans les limites choisies, pas bétonisation intégrale de tous les biomes.

## 21. Réseaux, transport urbain et circulation

Graphe routier hiérarchique (voies locales, artères, autoroutes, rails), approvisionnement d’usine, distribution vers commerces, trajet d’équipes d’intervention. À petite échelle, véhicules visibles échantillonnés ; à grande échelle, flux agrégés par lien et congestion. Chaque bâtiment exposera : `connected`, `route_to_depot`, `effective_throughput`, `power`, `water`, `service_coverage`. Une route coupée doit pouvoir interrompre une chaîne de production ou une intervention, jamais seulement changer la texture de carte.

## 22. Objectif « toute la planète » et mesure de progrès

`buildable_area = all_land - excluded_ocean - prohibited_relief - protected_biome - enemy_land - reserved_strategic`; les exclusions doivent être affichables et modifiables dans les règles de campagne, avec justification. `developed_ratio = developed_eligible_area / total_eligible_area`. Ne jamais confondre **100 % de ce périmètre** avec 100 % de la surface sphérique.

Trois phases : (1) métropole (capacité d’approvisionnement, services et industrie) ; (2) maillage de districts et réseaux jusqu’aux régions nouvelles ; (3) densification/renouvellement, reconversion R/C/I et soutien écologique. La planète n’est « complétée » que si le réseau fonctionne et si les ratios et services sont dans les tolérances, pas seulement si toutes les parcelles portent une structure.

## 23. Gouverneur automatique à l’âge X

**Activation** : quand `colony_age` passe à X, proposer une notification informative et activer par défaut le gouverneur civil. Le joueur peut suspendre ou reprendre, mais ne perd jamais les commandes militaires directes. L’automatisation est disponible planète par planète ; la planète mère peut être automatisée et une colonie VII reste pilotée par joueur ou routines limitées (pas d’urbanisation mondiale autonome complète avant son X).

**Contrat de gouvernance** : choisir priorités, budget, cible de zonage, réserves vitales, plafonds de dépenses, règles environnementales, interdictions, niveau d’alerte ; émettre plan et prévisions avant dépenses importantes ; conserver journal auditable des décisions. Aucun choix d’expansion ne doit ignorer une menace de siège, la reconstruction d’un centre ou un besoin vital.

**Boucle déterministe de décision** (par exemple tous les 50–200 ticks selon granularité) :

1. Collecter snapshot immuable : districts, stocks, services, population, construction, ordres, threats, budget et interdictions.
2. Calculer déficits classés : famine/eau/énergie/secours → capacité industrielle → sous-emploi → ratio R/C/I → extension.
3. Énumérer des actions candidates vérifiées : route, générateur, réserve d’eau, hôpital, caserne pompier, police, logement, commerce, usine, import, mise en sommeil.
4. Scorer chaque action selon gain réel, couverture, risque, coût, temps, terrain, impact ratio, contribution stratégique et dette de maintenance.
5. Réserver atomiquement ressources/crédits et la parcelle ; une action refusée ne débite rien. Ne construire qu’un nombre borné d’objets par cycle.
6. Exécuter via la **même commande métier** que le joueur ; inscrire événement décision avec raisons et contraintes.
7. Réévaluer après achèvement, pénurie, attaque, coupure réseau ou modification manuelle du ratio ; ne pas redémarrer l’intégralité du plan à chaque frame.

**Fonction de score illustrative (non équilibrée)** : `Score = 5*survival + 4*service_deficit + 3*production_bottleneck + 2*zoning_improvement + 1*economic_roi - 3*risk - 2*cost_penalty`; tous les termes normalisés, coefficients à valider. Ajouter hystérésis pour empêcher l’alternance démolition/construction de deux types de zones. Les investissements militaires ne sont jamais dépensés par le gouverneur civil hors budget explicitement accordé.

**Arrêt contrôlé** : si pénurie persistante, manque de trésorerie, route hostile ou absence de terrain, stabiliser le système, annoncer la cause et proposer actions. **Ne jamais** contourner les ressources, construire gratuitement ou simuler une « réussite 100 % » fictive. Les bâtiments manuels sont protégés contre démolition automatique, sauf accord explicite.

## 24. Économie anti-exploit et résilience

Chaque bien, crédit, unité et personne suit une trajectoire unique `produit/acheté → stocké → réservé → en transit → consommé/livré/perdu`. Réservations atomiques par `command_id`, idempotence d’événement, écritures équilibrées de comptabilité. Les recettes, destructions, captures, sauvegardes et retours de missions n’autorisent ni double livraison ni remboursement multiple. Tests de conservation de matériaux, de population et de trésorerie sur 10 000+ cycles accélérés.

---

# PARTIE IV — COLONISATION, ORBITE ET GUERRE PLANÉTAIRE

## 25. Cycle complet d’une colonie

1. **Détection** : exploration et relevé d’un système/monde ; brouillard et sources cohérents.
2. **Autorisation** : monde atteignable, place orbitale, transport et ressources mobilisables.
3. **Préparation** : réserver colons, équipes, constructeurs, vivres, pièces, unités d’escorte et crédits ; retirer ces ressources du stock de départ à l’embarquement.
4. **Trajet** : navette(s)/convoi, route calculée, ETA, capacité et carburant ; interception possible selon les combats réellement intégrés.
5. **Atterrissage** : planète vierge/alliée sans défense orbitale ennemie active ; colonie initialisée `local_age=7` si colonisation nouvelle par empire X. Pas de génération gratuite d’armée à l’arrivée.
6. **Fondation** : commandement terrestre, réserves, générateur, eau, habitation, premières industries/imports ; village vulnérable à attaque si aucune station en orbite.
7. **Croissance** : âge VII → VIII → IX : construire spatioport, infrastructures et **station de commandement orbitale locale** avec coût et délai ; naissance du verrou anti-invasion.
8. **Maturité** : âge X local : lancement du gouverneur R/C/I, intégration à la trésorerie impériale et aux itinéraires de fret.

La planète mère reste au niveau X. Les unités importées de niveau X restent utilisables et ravitaillées ; **aucun déblocage de production locale par simple possession**.

## 26. Types de transfert et capacité

- **Civils** : colonisateurs, travailleurs, spécialistes ; coût en habitat, vivres et capacité passagers.
- **Militaires** : unités embarquées avec identité, équipements et santé conservés ; navette/transport configurable selon masse/volume et port d’arrivée.
- **Fret** : minerai, alliage, carburant, électronique, nourriture ; stocks et réceptions atomiques.
- **Drones** : constructeurs spatiaux et sondes selon besoins des chantiers.
- **Crédits** : transfert de livre de comptes à distance sans fret physique, puisque financement et matériaux sont distincts.

Chaque mission enregistre `id`, `owner`, `origin`, `destination`, `cargo`, `reserved_capacity`, `route`, `state`, `departure_tick`, `arrival_tick`, `escort_ids` éventuels, `fuel`, `failure_reason`, `delivered_once`. Les transferts multi-sauts n’inventent pas d’arrivée immédiate : jalons, relais, ETA, interruptions, retour sécurisé ou perte explicite. Un transport sans destination valide ne doit pas débiter les stocks.

## 27. Station de commandement orbital âge IX

**[EXISTANT-0.12.3]** `OrbitalIndustry` introduit le chantier naval spatial qui peut assembler/modules, produire drones, sondes, navettes, intercepteurs et frégates X ; le premier chantier d’un camp est lié à son âge IX et assemblé en 180 ticks. Le vieux `chantier_orbital` terrestre âge X subsiste comme compatibilité.  
**[VALIDÉ-J13]** chaque nouvelle planète colonisée à VII doit progresser jusqu’à fabriquer **sa propre station orbitale**. Il ne faut pas accorder une station gratuitement à toute nouvelle planète parce que l’empire en possède déjà une ; l’attribution initiale automatique de 0.12.3 demeure au plus l’amorçage historique de la planète fondatrice et doit être migrée sans double apparition.

Stations : état `planned → assembling → operational → disabled → destroyed`, propriétaire, planète d’attache, modules, puissance défensive, capacités, réserve d’énergie/carburant, équipage, points de vie, ordres, file de production. Renommage joueur libre, ID stable. La distinction entre **chantier** (fabrique) et **station de commandement** (protège) peut être abstraite en un même noyau initial, puis modules spécialisés ; pas de duplication d’une seconde structure gratuite.

## 28. Verrou orbital des invasions

**Règle absolue** : `may_land_hostile(attacker, planet) = false` si au moins une station de commandement **ennemie et opérationnelle** protège la planète. Il faut **détruire toutes** les stations défensives en service appartenant à un ennemi contrôlant la planète pour ouvrir le débarquement. Une simple perte de bouclier/temporaire ne suffit pas : l’utilisateur a imposé une **destruction**, pas une désactivation arbitraire.

La station peut être attaquée depuis l’espace même si l’invasion terrestre est interdite. Les reconnaissances orbitales et attaques spatiales ne comptent pas comme « débarquement ». En première version, toute attaque hostile de surface (bombardement, missiles tirés depuis l’espace contre le sol, déploiement de troupes, raids) doit être interdite tant que le verrou actif existe, pour éviter de contourner la règle par une capacité spéciale. Les missions pacifiques peuvent être autorisées par traité, sans devenir un cheval de Troie militaire.

Ordre obligatoire : `approche → bataille orbitale → destruction station(s) → ouverture fenêtre de débarquement → descente sous protection → bataille terrestre → occupation → stabilisation/gestion`. Si la station est reconstruite alors qu’un débarquement est déjà engagé : les troupes déjà au sol restent, mais **les nouveaux renforts** sont bloqués ; ne pas téléporter les troupes ou annuler rétroactivement une attaque légale. Si aucune station n’a jamais été érigée (colonie VII), le verrou est absent et la planète est assaillable.

**Cas limites** : plusieurs stations, propriétaire neutre/allié, bâtiment achevé mais hors énergie, commande de destruction dans même tick, station désactivée puis reconstruite, joueur change de vue, IA attaque, sauvegarde avant/après explosion, station détruite avec drones survivants, centre terrestre seul, conquête du spatioport, guerre multi-camps future. La station ne doit jamais rendre l’empire techniquement invincible sans recours militaire prévu.

## 29. Doctrine de défense et offensive

La flotte doit pouvoir adopter **protéger orbite**, **intercepter flotte**, **escorter convoi**, **assaut station**, **préparer débarquement**, **retrait**, **réparer/ravitailler**. Tous ces ordres ont coût, conditions, cible, validation et compte rendu. L’IA ne contourne jamais la destruction stationnelle ; l’échec de tentative doit renvoyer « commandement orbital adverse encore opérationnel » et proposer un objectif de siège, pas générer un débarquement caché.

**[PROPOSÉ]** Simulation orbitale tactique détaillée différée après réalisation d’un modèle déterministe cohérent : même dégâts, consommation, portée, retraite et pertes dans les vues rapprochées et hors écran. Aucun combat « cosmétique » ne doit produire un résultat différent du calcul canonique.

## 30. Population, ravitaillement et occupation après conquête

L’invasion n’augmente pas automatiquement la population amie. Définir statut `contested`, `occupied`, `secured`, `integrated`; affecter garnison, travaux de remise en service, circuits de nourriture et administration. Les entreprises capturées ne créditent pas instantanément le trésor avant sécurisation et reprise. Les technologies locales capturées ne modifient pas rétroactivement la maîtrise impériale ; conserver trace de l’origine des équipements et possibilité de réhabiliter les usines.

## 31. Économie impériale centralisée

**Compte unique par empire** `ImperialTreasury`: crédits, réserves stratégiques monétaires, crédits alloués par planète, créances, dépenses, bénéfices nets et taxes/quotas. **Stocks physiques** : par planète, éventuellement rassemblés dans un entrepôt systémique mais toujours situés à un endroit et accessibles par trajet validé.

Flux : `vente locale → profit net → réserve d’exploitation locale → virement trésorerie impériale`. Dépenses de construction `trésorerie → budget colonial`, puis achat/réservation de matériaux sur place ou ordre d’import. Le joueur peut fixer un budget de développement, de défense, de maintenance et un seuil minimal de provisions. Les ressources physiques **ne sont pas centralisées instantanément** au simple prétexte que les gains financiers le sont.

**Exemple** : une planète industrielle produit 400 unités d’alliage. 120 consommées localement, 80 réservées, 200 exportables. Le centre galactique n’affiche pas « 400 utilisables partout » : il agrège 200 **disponibles à l’export** avec un délai de transport. Le centre impérial reçoit séparément la marge financière nette et peut commander des transports réels.

---

# PARTIE V — MONDE, ÉCHELLES ET LOGISTIQUE

## 32. Une réalité, plusieurs représentations

Échelles : scène tactique (unités, bâtiments, ouvrages) ; région/planète (districts, ressources, couvertures, propriétés) ; orbite (stations, satellites, flottes proches) ; système (planètes, corridors, sièges) ; galaxie (routes, exploration, fronts, finances). Chaque changement de vue ne fait que changer la représentation ; toutes les actions aboutissent à des commandes validées dans la simulation, jamais à l’édition directe de nœuds graphiques.

Séparer `world_sim_tick` fixe et `render_frame` variable. Un changement de caméra/LOD ne modifie jamais les sorties RNG, la cadence de production, la population, les revenus ou les dégâts. Le joueur peut sélectionner puis suivre une planète par ID stable à travers tous les zooms ; les marqueurs sont réutilisables.

## 33. Géographie procédurale

Conserver les seeds des générateurs de planète, système et galaxie. Garantir au moins un chemin de progression : ressources accessibles ou importables, terrain constructible initial, position de base non isolée, rayon de navette utile et passage d’expansion atteignable. Les biomes influencent production, énergie, ressources, urbanisation, menaces et graphismes. Les océans, reliefs et glaciers ont des coûts de construction crédibles ; les bâtiments spatiaux ne doivent pas apparaître au niveau du sol par simple changement de catégorie.

Modèle cible planète : `PlanetDefinition(seed, radius, climate, biomes, height, hydrology, deposit_map, forbidden_mask, tiles, local_age, owner, station_ids, population, inventories, governor_state)`. La planète vide n’occupe presque pas de mémoire au démarrage : seules les cellules modifiées et les agrégats persistants sont stockés.

## 34. Streaming hiérarchique

- **LOD simulation S0** : carte tactique active (escouades individuelles, collisions, bâtiment précis).
- **S1** : régions non visibles mais proches/menacées (formations, stocks et production réduite en fréquence).
- **S2** : planète éloignée (districts agrégés, événements de changement d’état, production/networks à cadence lente).
- **S3** : système non visité (stockage minimum, états macros et convois toujours réels).

Le **LOD de simulation ne doit pas altérer les résultats** : quand possible, intégrer analytiquement production périodique ; pour incidents discrets, utiliser événements préplanifiés par seed/tick ; au retour actif, réhydrater les unités réellement nécessaires sans duplication. Les autres planètes continuent pendant les combats locaux. Budget de travail borné par tick ; backlog signalé si risque de ralentissement.

## 35. Brouillard, reconnaissance et informations

Brouillard par camp, par échelle, avec connaissance persistante des étoiles révélées et informations datées sur les forces adverses. Le gouverneur ne peut pas planifier une route à travers un territoire inconnu comme s’il connaissait un graphe complet ; il peut proposer une mission de reconnaissance. Un commerce avec planète non reconnue est bloqué ou explicitement dépendant d’accord de transit. Les renseignements périmés apparaissent visuellement comme tels.

## 36. Routes et transports intersystèmes

Le graphe stellaire a arêtes de longueur/coût, relais sous contrôle, temps de vol, embargo/hostilité et limite de fret. `ship_supplies` J12 existe sur stocks systémiques avec frais alimentaires par saut ; J13 introduit sous ce système une couche planète/orbite : `PlanetInventory → Spaceport/OrbitalDepot → SystemHub → MultiHopFreight → ArrivalOrbitalDepot → PlanetInventory`. Un cargo intersystème ne dépose pas directement du béton dans un immeuble terrestre sans chaîne d’accès. Un trajet en plusieurs sauts reprend après réparation de relais si cela est autorisé, mais doit conserver le stock débité une seule fois.

## 37. Météo, relief et contraintes environnementales

Climat et saisons selon planète, impact sur récoltes et consommation électrique, incendie, visibilité et mobilité. Pas de simulation météorologique lourde par habitant. Relief/dénivelé influencent routes, réseaux d’eau, temps de pompiers et implantation industrielle. Les zones écologiques réservées ont bénéfices et coût d’opportunité ; aucune pénalité sans affichage de causalité.

---

# PARTIE VI — SYSTÈMES MILITAIRES, IA ET ÉQUILIBRAGE

## 38. Combat terrestre et militaire hérité

Préserver unités/escouades, commandement délégué, formations, siège, terrain, brouillard, munition/approvisionnement déjà implémentés. La distinction terrestre/orbital/interstellaire est systémique : seuls les moyens de transport appropriés franchissent les échelles. Les troupes de générations anciennes restent jouables contre des adversaires avancés grâce au terrain, aux fortifications, au nombre et à la logistique, sans équilibrage irréaliste garantissant une victoire aux lanciers contre une frégate.

## 39. Développement militaire issu de la population

Une caserne de colonie réclame population recrutée, nourriture, équipements (acier/fusils/munitions), crédits et temps. La formation tire un enregistrement de candidats et réduit le pool de travailleurs jusqu’à démobilisation ou retour. Des bâtiments de quartier (habitation) définissent la **capacité de mobilisation**, pas le type d’arme débloqué. Les usines fabriquent les kits, moteurs, véhicules ; les casernes/aérodromes produisent les unités à partir de ces kits. Une même planète peut importer une arme avancée mais ne pas savoir fabriquer les pièces nécessaires à sa maintenance.

## 40. IA civile et militaire séparées

**Gouverneur civil** : optimisation de survie, services, zonage, emploi, crédits, production. **Commandement militaire local** : gardes, patrouilles, réserves, protection de points. **Commandement stratégique** : objectifs galactiques, routes, reconnaissance, siège et défense de stations. Les trois modules échangent des demandes et réservations explicites, sans modifier directement les mêmes stocks en parallèle. Privilégier des politiques explicables et invariants à une optimisation opaque.

Ordre d’autorité : commande directe joueur > interdiction/protection définie par joueur > directive impériale > ordre tactique délégué > gouverneur civil > rééquilibrage automatique. Une IA ne doit pas détourner une frégate sélectionnée par le joueur pour faire du commerce. Le bouton « reprendre la main » est toujours disponible.

## 41. Équilibrage macroéconomique

Paramètres à simuler : taux de croissance, coût du logement, revenu/travailleur, marge commerciale, prix des intrants, consommation énergétique, disponibilité de minerai, coût de maintenance, amortissement industriel, capacités de secours, soutien de garnison. L’industrialisation doit avoir une phase de coût : plus d’usines augmente production et richesse potentielle, mais consomme énergie, eau, employés et matières. Le commerce exige un produit réel à vendre, la population exige nourriture/eau/soins ; aucun pilier R/C/I n’est autosuffisant isolément.

Comparer au minimum quatre styles : 60/20/20 R/C/I, 45/25/30, 25/20/55, 40/45/15. Mesures : survie, soldat/temps, revenus nets, colonie/temps, dépenses de réparation, couverture, besoin de transport, vulnérabilité au siège. Aucun preset ne doit être strictement supérieur sur tous les axes.

## 42. IA ennemie et conquête orbitalement verrouillée

Avant offensive : scout → estimation défenses → acquisition flotte et transports → priorisation station → suppression de toutes stations opérationnelles → débarquement → objectifs au sol → occupation. Les erreurs de pathfinding, navettes vides ou stations invulnérables doivent être détectables par logs. L’IA ajuste ses opérations à la destruction/reconstruction des stations, sans céder à un blocage infini. Elle ne connaît pas les fonds ou unités adverses cachés.

## 43. Alertes et priorité stratégique

Priorité critique : perte imminente centre/station, pénurie eau/énergie critique, convoi colonial détruit, invasion bloquée, feu industriel étendu. Haute : pénurie industrielle, couverture hospitalière insuffisante, planète isolée. Information : nouveau commerce, quartier terminé, jalon de densification. Alertes regroupées par planète ; pas de spam à chaque tick. Une alerte contient cause, objet, conséquence et action rapide disponible.

---

# PARTIE VII — DIRECTION ARTISTIQUE ET INGÉNIERIE GRAPHIQUE

## 44. Direction artistique cible

**Réalisme 3D crédible** — géométrie et matériaux cohérents, échelle plausible des maisons/humains/véhicules, végétation organique, éclairage atmosphérique et architecture par âge. Pas de personnages semi-réalistes ou de villes purement abstraites pour les vues tactiques. La priorité n’est pas une densité de polygones maximale mais une silhouette identifiable, une scène lisible sur smartphone et une cohérence des proportions.

L’évolution visuelle est progressive : bois/terre (I) → pierre/enduits (II–III) → fer/brique/vapeur (IV–V) → béton/acier/verre (VI–VIII) → alliages composites, panneaux énergétiques et structures orbitales (IX–X). Ne pas remplacer toutes les anciennes maisons lors d’un changement d’âge : conserver quartiers historiques, opérations de rénovation visibles et contrastes de développement. Une colonie neuve VII emprunte le langage visuel contemporain mais reste peu dense ; elle ne ressemble pas à un village médiéval.

## 45. Kit modulaire de bâtiments

Assets par famille `residential`, `commercial`, `industrial`, `civic`, `power`, `water`, `transport`, `military`, `orbital` ; modules `base`, `facade`, `roof`, `utility_attachment`, `street_furniture`, `damage_stage`, `emissive_details`. Variations seedées (matériaux, nombre d’étages, enseignes, tuyauteries, fenêtres) sans changement des collisions ni capacités de gameplay. Toutes les variantes d’une catégorie respectent des volumes d’occupation, points de connexion et repères d’animation standardisés.

**Cible d’identification à distance** : R = silhouette de vie/terrasses, C = vitrines/enseignes/flux, I = cheminées/convoyeurs/réservoirs, hôpital = croix/antenne claire, police = poste et véhicules, pompiers = garage et tours, centrale = volume technique, station orbitale = silhouette centrale protégée. Ajouter pictogrammes et contours d’état pour ne pas dépendre uniquement de la couleur.

## 46. Matériaux PBR et textures

Pipeline textures avec base color, roughness, metallic, normal, AO si pertinent. Matériaux réutilisables par palette : bois, pierre, brique, béton, acier peint, métal usé, verre, polymère, tissu, terre/roche, panneaux solaires. Ajuster valeurs d’intensité/roughness pour éviter un rendu plastique, normes de couleur constantes, mipmaps et compression mobile. Dégradations par decals/masques peu coûteux, pas multiplication de matériaux uniques pour chaque bâtiment.

Conserver la bonne lisibilité sous faible luminosité et à l’ombre. Les fenêtres éclairées la nuit doivent être des masques émissifs simples ou instanciés, pas une OmniLight3D par fenêtre. L’eau utiliserait shader limité et LOD, sans réflexion écran coûteuse disponible uniquement dans d’autres profils.

## 47. Éclairage et atmosphère

Une lumière directionnelle dominante soleil + lumière ambiante/sky calibré par planète, cycle de jour/nuit cohérent avec sa rotation et son système. Ombres dynamiques limitées et adaptées au zoom ; bâtiments lointains sans ombres individuelles détaillées. Hôpitaux, quartiers et usines possèdent éclairage de signalisation principalement émissif. Nuages de globe, brume de vallée et lumière orbitale via couches procédurales peu coûteuses ; pas de dépendance à des effets Forward+ non disponibles en renderer Mobile.

**Source Godot officielle :** le renderer Mobile vise les appareils récents et n’offre pas tous les effets de Forward+ ; profil visuel à valider sur l’appareil, pas uniquement dans l’éditeur. https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html

## 48. Végétation et planète vivante

Arbres à variantes organiques, herbe par plaques, rochers PBR, berges, rivières, micro-relief, nuages/atmosphère ; chaque biome a palette, espèces et densité. Le développement urbain réduit la végétation **sur les parcelles réellement bâties**, mais conserve parcs/protections. Les villes produisent lumières nocturnes et traçage visible depuis le globe, dérivés des districts réellement habités. Pas de texture de mégapole plaquée sur une planète sans population.

## 49. Animations d’unités et bâtiments

Personnages : idle, marche/course, combat, portée d’arme, mort, construction, transport/embarquement ; vitesse du déplacement synchronisée au cycle d’animation. Véhicules : chenilles/roues, suspension crédible, tourelles, fumée conditionnelle. Ville : portes, ascenseurs abstraits, petites livraisons, enseignes, flux de piétons échantillonnés. Les animations distantes peuvent passer à fréquence réduite, être regroupées ou arrêtées ; simulation sous-jacente inchangée.

## 50. VFX, destructions et événements

Effets particulaires bornés : poussière de chantier, étincelles, incendie, fumée, bouclier orbital, impact projectile, explosion stationnelle. La station passe par des états de dégâts lisibles avant explosion/destruction ; **l’état logique de destruction** précède ou accompagne l’effet, jamais après une animation dont la durée changerait les règles. Les débris spatiaux visuels ne doivent pas déclencher de collisions coûteuses non nécessaires. Des bâtiments endommagés changent d’apparence sans recréer chaque mesh à chaque tick.

## 51. LOD visuel multi-échelle

- **Tactique proche** : modèle complet, animations critiques, détails de façade et ombres sélectionnées.
- **Quartier** : LOD meshes, fusion logique de petites décorations, MultiMesh par bloc pour éléments répétitifs.
- **Planète** : HLOD de quartiers, imposteurs/empreintes volumétriques de villes, densité lumineuse agrégée.
- **Orbite** : marqueurs 3D de station/flotte et planètes en niveaux de détails ; aucune ville individuelle à reconstruire.
- **Système/Galaxie** : représentations dérivées de données (systèmes, routes, empires, flux), pas rendu de bâtiments.

**MultiMesh** accélère les répétitions, mais sa culling est global au groupe. Répartir les instances en petits groupes géographiques à visibilité indépendante ; ne pas placer toutes les maisons d’une planète dans un MultiMesh unique. Source : https://docs.godotengine.org/en/stable/tutorials/performance/using_multimesh.html . Mesh LOD, visibility ranges et prudence sur les transparences/shadows suivent la documentation officielle : https://docs.godotengine.org/en/stable/tutorials/performance/optimizing_3d_performance.html .

## 52. Profil Android — objectifs mesurables, non promesses

- **[CIBLE-TEST]** 60 FPS dans les situations ordinaires sur Galaxy S25 Ultra ; repli stable à 30 FPS dans une scène très chargée plutôt que saccades permanentes. Mesurer médiane/p95/p99 de frame time et pas seulement FPS instantané.
- Budget de frame cible à 60 FPS : **16,67 ms** ; à 30 FPS : **33,33 ms**. Budget CPU/GPU détaillé à déterminer par profilage sur vrai appareil ; ne pas inventer de marges mesurées.
- Pas logique hérité 10 Hz (`100 ms` par tick) à préserver ; modes 0,5×/1×/2×/4×/8×. À vitesse 8×, éviter des nœuds/draw calls proportionnels aux huit ticks simulés si la caméra n’a pas changé.
- Surveiller RAM native, mémoire GPU, temps import/décodage, p95 du temps de sauvegarde, premier chargement, surchauffe et throttling à 20–45 minutes de session.
- **[PROPOSÉ]** budget dynamique : plafond de districts tactiques affichés, lots de MultiMesh, distance LOD, densité de petits véhicules civils, fréquence d’overlays ; jamais réduire les revenus, dégâts ou population en réaction à une chute de FPS.

## 53. Budget d’assets proposé

Toutes les valeurs ci-dessous sont des objectifs de départ à **mesurer**, pas des limites matérielles universelles : personnages proches 3–10 k triangles par figurant stratégique, bâtiments proches 1–15 k selon empreinte, props 100–1 500, LOD distant 10–25 % du mesh proche ; textures souvent 512–1024 px pour modulaires répétés, 2K réservé aux assets héros. Préférer atlases et matériaux partagés ; définir un budget de VRAM par vue après capture GPU. Réexaminer selon camera altitude, quantité d’unités visibles et rendu réel du S25 Ultra. Ne pas sacrifier les silhouettes de combat pour réduire arbitrairement les triangles.

## 54. Son et rétroaction

Audio contextuel selon âge et environnement : forge, marché, ville, usine, vent, moteurs, ambiance orbitale, trafic spatial ; spatialisation modérée pour les vues tactiques. Notification sonore réservée aux alertes importantes, volume et vibration optionnels, aucune dépendance audio à la validation d’ordres. Le tutoriel doit être utilisable sans son.

---

# PARTIE VIII — UX MOBILE ET COMMANDEMENT

## 55. Principes de HUD

UI premium sobre, hiérarchie stable, contraste correct, panneaux semi-transparents modérés et lisibles, cible tactile de taille suffisante, boutons avec pictogramme + texte optionnel, peu de manipulations simultanées. L’écran reste majoritairement consacré au monde. Un panneau contextuel apparaît à la sélection (unité, bâtiment, district, planète, station, flotte) et expose actions **disponibles**, **verrouillées avec raison**, en cours, coût, délai, conséquences.

Pour les gestes : appui court sélectionner, appui long ouvrir menu, glissement déplacer caméra/trajectoire selon contexte, pincement zoomer, double tap centrer, deux doigts panoramique/rotation calibrée. Éviter qu’un pinch déclenche un ordre ou qu’un panneau masque la cible d’un débarquement. Une transition de vue verrouillée indique l’âge/recherche manquante.

## 56. Vue tactique

Barre supérieure : ressources locales utiles, crédits empire, âge local/empire, population et énergie ; commandes en bas : construire, produire, évoluer, ordres, alertes. Zones R/C/I peuvent être dessinées au pinceau, par rectangle ou attribuées à un district existant ; aperçus indiquent coûts, routes et couverture avant validation. Les unités importées X portent un badge « importée / maintenance dépendante » sur planète VII.

## 57. Vue planétaire

Globe 3D + couches : propriété, R/C/I, densité, emploi, ressources, énergie, eau, santé, incendie, police, industrie, pollution, routes et frontières. Toucher une région donne population, demande, couverture, projets et ETA. Tableau gouverneur : ratio cible et réalisé, zones desservies, budget, ordres en cours, expansion, sources de risque ; commandes « automatiser », « suspendre », « protéger cette région », « construire en priorité », « exporter/importer ».

## 58. Vue orbite

Stations de commandement, état (assemblage/opérationnelle/détruite), modules, batteries, hangars, flotte, défense, production, ETA, contrôle de surface. Pendant une offensive, afficher explicitement **« INVASION BLOQUÉE : 2 STATIONS DE COMMANDEMENT ENNEMIES »** avec localisations connues et action « cibler station ». La couleur ne doit pas être seul signal ; indicateurs texte/icône.

## 59. Vue système et galaxie

Carte claire des mondes, routes, stocks, navettes, convoi bloqué, forces connues, âge local de chaque planète, état de ses services, crédit net et ordre stratégique. Une planète peut apparaître sous une bannière « Empire X / Colonie VII ». Les bénéfices agrégés sont accessibles par tap sur la trésorerie et filtrables par monde. Les convois donnent ETA et cargaison, pas seulement une ligne lumineuse.

## 60. Notifications et accessibilité

Typographie lisible, zoom UI, taille des touches, couleurs doublées de symboles, sous-titres, reprise après verrouillage écran, pause automatique appropriée, confirmation pour abandon/démolition massive, annulation d’ordre si aucune ressource irréversiblement consommée. Notification d’achèvement du chantier IX, passage X de planète, couverture 100 % des services, pénurie critique, station ennemie détruite, débarquement ouvert.

---

# PARTIE IX — ARCHITECTURE TECHNIQUE GODOT

## 61. Constat technique et stratégie de migration

Classes source vérifiées : `Rules`, `SimWorld`, `StarCampaign`, `OrbitalIndustry`, `CampaignSave`, `AgeProgression`, `ViewTechnology`, `PlanetRegions`, `PlanetGenerator`, `StarSystemGenerator`, `GalaxyGenerator`, `MobilePerfBudget`, vues HUD terrain/planète/orbite/galaxie. `StarCampaign.ages` et `StarCampaign.technologies` sont globaux à l’équipe ; `system_stocks` agrège `food/wood/ore` au système. Ne pas recoder le RTS. Évoluer **par composition**, avec adaptateurs, API de commandes et migrations testées.

### Architecture logique J13 recommandée

```text
Game/Presentation (Godot UI, 3D, audio, caméras, overlays)
    ↓ commandes métier / ↑ événements en lecture seule
CampaignFacade / CommandBus (validation centrale, audit, ID)
    ├─ StarCampaign (galaxie, routes, découverte, directives)
    ├─ PlanetCampaign (colonies, âge local, territoires, conquête)
    │    ├─ ColonyTechState (recherche locale, doctrine)
    │    ├─ ZoningModel (R/C/I, districts, parcelles)
    │    ├─ PopulationModel (logement, travail, colons, recrutement)
    │    ├─ IndustryModel (recettes, inventaires, énergie, eau)
    │    ├─ CommerceModel (vente, profits, budgets)
    │    ├─ ServicesModel (hôpitaux, police, pompiers, graphes)
    │    └─ PlanetGovernor (planification civile déterministe)
    ├─ ImperialTreasury (crédits / écritures à double entrée)
    ├─ TransportLedger (cargaisons, passagers, équipes, ETA)
    ├─ OrbitalIndustry (stations, modules, fabrication et combat)
    └─ SimWorld (combat tactique, unités/bâtiments/escouades)
         ↓ snapshot déterministe et journaux
    CampaignSave (migrateurs versionnés, checksum, backup)
         ↓ modèles de lecture diff/agrégés
    ViewAdapters (terrain, globe, orbite, système, galaxie)
```

Toutes ces classes nouvelles sont **proposées**, pas présentes sous ces noms dans 0.12.3. Conserver les chemins historiques de scènes ; n’ajouter des `class_name` que si leur chargement est vérifié sans collision. Traiter les warnings GDScript comme erreurs, conversions explicites des `Variant` issus de JSON/Dictionary (`int()`, `String()`, `as Dictionary`), aucune inférence `:=` depuis `Dictionary.get()`.

## 62. Modèle de données canonique — schéma conceptuel

```json
{
  "schema": 13,
  "campaign_id": "seed-based-stable-id",
  "tick": 168000,
  "empire": {
    "team_id": 0, "global_age": 10,
    "global_technologies": ["cartographie_galactique"],
    "treasury": {"credits": 135000, "ledger_seq": 483},
    "directives": {"sol": "defend", "proxima": "supply"}
  },
  "planets": {
    "sol-3": {
      "owner": 0, "local_age": 10,
      "local_research": ["refining", "automated_city"],
      "development": {"R": 0.44, "C": 0.26, "I": 0.30},
      "zoning_target": {"R": 0.45, "C": 0.25, "I": 0.30},
      "population": {"residents": 172000, "workers": 92000},
      "stocks": {"food": 3400, "ore": 1200, "alloy": 880},
      "services": {"medical": 0.97, "fire": 0.99, "police": 0.98},
      "governor": {"enabled": true, "budget_limit": 2500},
      "orbital_station_ids": [42]
    }
  },
  "transports": [
    {"id": 723, "from": "sol-3", "to": "proxima-2",
     "state": "en_route", "departure_tick": 168000,
     "eta_tick": 169400, "passengers": 12, "cargo": {"alloy": 30}}
  ]
}
```

C’est un **schéma illustratif**, non le format réel de sauvegarde 0.12.3 et **non un fichier à charger tel quel**. Le format réel doit conserver `CampaignSave` avec migrateurs, signatures, bornes strictes et maintien des alias nécessaires.

## 63. IDs, ownership et assertions

IDs globaux stables `campaign/team/system/planet/region/entity`; aucun ID local de bâtiment ne doit être utilisé seul lors d’un transfert. Les propriétés de propriétaire et d’âge local ne se déduisent pas de la vue. Invariants : stock non négatif ; somme des ratios 1 ; résidence ≤ capacité avec tolérance migratoire ; station rattachée à planète connue ; convoyeur à origine/destination distinctes ; débits d’énergie et d’eau bornés ; unité unique dans monde ou transit ; profit crédité une fois ; travaux en cours ≤ parcelles réservées ; commande de débarquement validée avec verrou orbital.

## 64. API métier recommandée

```text
zone_planet(team, planet_id, parcel_ids, zone_type, expected_revision)
build_civic(team, planet_id, parcel_id, facility_type)
set_zoning_balance(team, planet_id, r, c, i)
set_governor_policy(team, planet_id, policy, budget_cap)
queue_industrial_batch(team, planet_id, recipe_id, count)
recruit_units(team, planet_id, producer_id, unit_type, count)
found_colony(team, transport_id, planet_id, landing_site)
advance_colony_age(team, planet_id)
start_orbital_station(team, planet_id, constructor_id)
attack_orbital_station(team, fleet_id, station_id)
request_hostile_landing(team, transport_id, planet_id, landing_zone)
transfer_materials(team, origin_planet, dest_planet, cargo_manifest)
transfer_credits(team, from_budget, to_budget, amount)
```

Tous les appels renvoient `ok`, `reason_code`, `cost_reserved`, `created_ids`, `eta`, `event_id`; échec = **zéro effet économique**. La même API doit être utilisée par joueur, IA, gouverneur, import de sauvegarde et recette ; éviter une « commande IA » privilégiée contournant les coûts.

## 65. Planification par tick et déterminisme

Distinguer simulation tactique 10 Hz, économie locale par tranche de ticks (par exemple 10–50), gouverneur par 50–200 ticks, chemins de secours uniquement quand réseau/charge change, streaming graphique à cadence de frame. Les tranches sont entières et déterministes ; à 8×, toutes les transitions de l’économie sont réalisées même si aucun frame n’est rendu. **Ne pas invoquer les décisions du gouverneur depuis `_process(delta)`**. RandomNumberGenerator seedé par `campaign_seed + planet_id + event_seq` de manière indépendante des caméras, plutôt qu’un RNG global dépendant de l’ordre d’affichage.

Les flux réseaux sont recalculés par version de graphe modifiée : `roads_revision`, `power_revision`, `water_revision`, `service_revision`. Les corrections d’occupation ne forcent pas un recalcul complet de toute la planète dans la même frame. Établir une borne de temps de travail par tick et un mécanisme de progression incrémental, sans saut économique.

## 66. Sérialisation, migration et atomicité

Sauvegarde à schéma versionné, checksum global, `.bak` et fichier temporaire : `serialize → validate(snapshot) → write(tmp) → fsync si supporté → atomic rename → verify/load`. En mode Android, vérifier les limites réelles des opérations de fichiers Godot et prévoir rollback si renommage/écriture échoue. Les secrets éventuels ne sont pas impliqués dans les sauvegardes solo, mais aucun chemin non validé ne doit pouvoir écrire hors `user://`.

**Migration 0.12.3 → J13** :

1. Charger sans modifier le fichier original ; valider les champs antérieurs et conserver backup.
2. Créer état planétaire pour chaque monde matérialisé et connu ; attribuer `local_age = legacy_age` aux planètes **déjà établies** du camp afin de ne pas les rétrograder artificiellement. Les **nouvelles** colonies post-J13 naîtront à VII.
3. Créer un **dépôt physique principal par système** contenant la valeur historique de `system_stocks`. Ne pas répartir en copie identique sur toutes les planètes ; le dépôt est accessible par règles explicites de logistique locale. Maintenir un adaptateur `system_stocks` jusqu’à migration complète des consommateurs.
4. Convertir `orbital_sites`, modules, garnisons et vols sans génération d’une nouvelle station gratuite. Conserver l’indicateur `orbital_initial_granted` et prévoir un champ par planète `local_orbital_grant` pour nouveaux scénarios, sans cumul.
5. Initialiser crédit impérial à un montant scénarisé et traçable (par défaut 0 pour parties migrées, sauf règles historiques explicitement documentées), **jamais** à partir du simple nombre de marchés × montant gratuit non justifié.
6. Associer les producteurs et unités à un identifiant planétaire stable, conserver niveaux/recherches de J12.2.
7. Valider hash de cohérence et invariants ; en cas de problème, conserver l’ancienne sauvegarde et signaler l’erreur ; ne pas écraser le backup.

Recharger trois fois la même sauvegarde sans mouvement ne doit pas produire plus de population, revenus, ressources, stations ou transports.

## 67. Compatibilité et politique de rollback

Conserver séparément l’archive source 0.12.3 et un jeu de sauvegardes tests : J1–J8, J9, J10, J11, J12.0, J12.2 et J12.3. Une sauvegarde migrée vers J13 **n’est pas nécessairement relisible par 0.12.3** ; rollback = binaire source d’origine + fichier sauvegarde d’avant migration, pas simple downgrade d’exécutable. Ne jamais livrer un ZIP tronqué contenant seulement des patches pour une version demandée comme complète.

## 68. Sécurité et robustesse des données de joueur

Valider bornes numériques, NaN/infinis, IDs, propriétaires, type des structures, nombre de parcelles, route, ETA, taux, budget, taille de sauvegarde, longueurs de listes. Un fichier corrompu ne doit pas allouer des milliards d’objets ni planter la partie. Les ordres multi-factions refusent permissions invalides. Les chemins de scripts internes ne doivent pas être construits à partir de noms libres de planètes. Les commandes de démolition globale doivent être confirmées, consignées et testées avant mise en production.

---

# PARTIE X — RECETTE, ACCEPTATION ET ROADMAP

## 69. Stratégie de tests

**Static** : syntaxe heuristique/manifest/diff sans prétendre valider GDScript. **Godot headless réel** : import, vérification parse/load, tests par scénario. **Simulation** : invariants économiques et stratégiques, seed déterministe et hash, répétitions. **Android réel** : tactilité, qualité 3D, mémoire, batterie, throttling, sauvegarde/reprise après interruption. Tous les rapports portent version Godot, version projet, OS, modèle, seed, tick, résultat, durée, hash et classification PASS/FAIL/NOT_RUN.

## 70. Tests minimaux bloquants — J13

**Technologies et colonie** : empire X colonise planète VII ; age local égal VII ; unité X importée fonctionne mais ne se fabrique pas ; VII→VIII→IX→X exige recherches et ressources ; construire station seulement âge IX local ; l’existant 0.12.3 conserve son âge après migration.

**Zonage** : somme R+C+I=100 ; paramètres refusés hors bornes ; deux districts R produisent capacité/population selon densité ; passage usine sans eau/énergie refuse production ; centre commercial sans produits n’invente pas de crédits ; croissance contrainte par nourriture et emploi ; constructions à budget zéro refusées ; ratio non modifié par gouverneur sans ordre.

**Services** : zone dans un rayon visuel mais hors accès routier = non desservie ; station incendie saturée = quartier sous-couvert ; centrales raccordées insuffisantes = déficit ; reconstruction d’une route rétablit service ; suppression de pompe à eau diminue production ; couverture à 100 % est calculée sur le périmètre éligible uniquement.

**Gouverneur** : activation locale à X ; pas à VII ; sauvegarde/reprise du plan ; respect des zones interdites et bâtiments manuels ; aucune construction gratuite ; stabilité après 1 000 cycles ; pas de démolition/reconstruction répétée ; extension vers des régions adjacentes validées ; progression jusqu’à 100 % éligible sous ressources infinies de laboratoire.

**Orbital** : station ennemie opérationnelle bloque débarquement ; destroy ouvre ; deux stations exigent deux destructions ; construction d’une nouvelle station referme pour nouvelles vagues ; unités déjà au sol restent ; planète VII sans station vulnérable ; tentative IA suit mêmes règles ; frégate X importée ne débloque pas arsenal local.

**Transport** : 1 seule réservation de 12 colons dans départ ; embarquement ; vol ETA ; 12 arrivées pas 24 ; interruption/relance ; sauvegarde au milieu du saut ; destruction explicite d’un transport et état des passagers ; même ID non présent simultanément au sol et en vol.

**Trésorerie** : bénéfice positif → 1 virement ; déficit → aucun profit fictif ; import payé ne téléporte pas matériau ; planète A vend 100 unités tandis que B ne reçoit du stock que par navette ; sauvegarde et rechargements ne recréditent pas.

**Régression** : siège J1–III, IA J3–VIII, planète J9, système J10, galaxie J11, fret J12.0, évolution J12.2, station J12.3, vitesses ×0,5→×8, commandement délégué, écrans de recette, permutations de vues.

## 71. Mesures de performance et critères de sortie

Seuils proposés, non mesurés : scène de départ stable 60 FPS après chauffe ; métropole locale cible 45–60 FPS avec repli acceptable à 30 ; pas de crash sur 30 minutes et 3 changements de vue ; capacité de reprendre session après application minimisée ; production hors écran identique à une simulation avec vue ouverte ; temps de sauvegarde et pic de mémoire bornés par mesures S25 Ultra. Au moins 3 densités de population/industrie et 3 vitesses testées. Chaque optimisation doit disposer d’un benchmark avant/après, d’une validation de hash de simulation et d’un rollback.

## 72. Roadmap recommandée — jalons indépendants et dépendances

| Lot | Livraison vérifiable | Dépend de | Critère de sortie |
|---|---|---|---|
| **J13-0** | Réparer/importer réellement la 0.12.3, figer tests, sauvegardes et hashes | ZIP 0.12.3 | Godot parse/load et recette J1–J12 réelles PASS ou défauts documentés |
| **J13-A** | `ColonyTechState`, âge local VII, compatibilité global/local, renforts | 13-0 | Colonie X→VII, renfort X utilisable, production X locale refusée |
| **J13-B** | Inventaires planétaires, réserve de fret, matériaux intermédiaires, treasury | 13-A | Aucun double compte, migration et flux crédit/matériaux validés |
| **J13-C** | Districts, parcelles, zonage R/C/I, habitation, commerce, industrie | 13-B | Ratio configurable, emplois, consommation, fabrication et bénéfices réels |
| **J13-D** | Réseaux eau/électricité, voirie, santé/police/pompiers | 13-C | Couverture/temps/capacité recalculés et contrôlés, déficits expliqués |
| **J13-E** | Gouverneur civil X, expansion mondiale par districts | 13-D | 100 % de surface éligible en seed test, zéro commande gratuite |
| **J13-F** | Guerre orbitale verrouillée, étapes de siège/débarquement | 13-A, 0.12.3 orbital | Invasion impossible avant destruction de toute station ennemie |
| **J13-G** | Modèles 3D urbains réalistes, VFX, overlays et LOD Android | 13-C–F | Tests de lisibilité, mémoire et frame-time sur appareil réel |
| **J13-H** | Recette J1–J13, IA civil/militaire, migration, documentation, ZIP/APK | Tous | Toutes les portes automatiques + tests manuels Android effectués |

Chaque lot doit livrer **ZIP source complet**, rapport de diff, manifeste SHA-256, tests Godot et Android lorsque disponibles, preuves PASS/FAIL/NOT_RUN, instructions de rollback et, si possible, APK test. Ne pas fusionner la branche alternative Age of War J56 ni réécrire `sim/` en perdant les règles de siège/sauvegarde.

## 73. Risques majeurs et mitigations

| Risque | Effet | Mesure impérative |
|---|---|---|
| Âge global actuel | Nouvelle colonie VII fabrique X par erreur | Séparation globale/locale dès J13-A et API centralisée |
| `system_stocks` vs planet stocks | Duplication ou insolvabilité | Dépôt primaire migré une fois, ledger transactionnel |
| Expansion intégrale | Explosion RAM/CPU et sauvegardes | Chunks géodésiques, districts agrégés, simulation à événements |
| Services 100 % | Surcoût du graphe et couverture impossible | Graphe cache/version, heuristique, exclusions expliquées |
| IA gouverneur | Oscillation zonage, famine ou dépenses infinies | Priorités vitales, hystérésis, budget, invariants et journaux |
| Combat orbital | Contournement de l’obligation de détruire station | Validation unique de `request_hostile_landing` et armes de surface |
| Multiples planètes | Perte d’identité des unités/imports | IDs globaux, cargo unique, vérification d’existence par état |
| Graphismes réalistes | Throttling, chutes FPS, crash mémoire | LOD hiérarchique, MultiMesh par zone, rendus testés matériellement |
| Migration sauvegarde | Perte campagne longue durée | Versionnage, backup, tests de conservation, rollback ancien binaire+save |
| Godot parse | Scripts non chargés malgré « tests statiques PASS » | Import headless Godot bloquant, warnings comme erreurs |

## 74. Liste de décisions validées et propositions à tester

### Validées par le porteur du projet

- Dix âges I–X, empire galactique multi-échelle, Galaxy S25 Ultra, 3D réaliste, RTS solo hors ligne.
- Chantier naval orbital équivalent centre de commandement dès IX ; chaîne spatiale distincte du terrestre.
- Chaque bâtiment producteur a ses propres niveaux et améliorations de troupes.
- Nouvelle colonie créée par un empire âge X démarre localement à **VII**.
- Renforts militaires avancés transportables physiquement ; production locale strictement limitée à l’âge et aux recherches de la colonie.
- Zones R/C/I, équilibre paramétrable, bâtiments d’habitation/commerciaux/industriels.
- Dès l’âge X local, gestion automatique du développement jusqu’à couvrir toute surface constructible autorisée.
- Hôpitaux, police, pompiers, eau, électricité, couverture territoriale.
- Station(s) orbitale(s) ennemie(s) détruite(s) avant attaque terrestre de la planète.
- Gains économiques générés par les planètes centralisés à l’échelle impériale.

### Arbitrages de conception proposés et modifiables

- Équilibre par défaut R45/C25/I30 ; les pourcentages portent sur surface zonée construite, pas les services/voiries.
- Trésorerie uniquement financière centralisée ; matériaux maintenus sur leurs planètes et fret réel.
- Acquisition d’une planète ennemie ≠ fondation nouvelle colonie : technologie et population conservées/occupées, pas retour à VII automatique.
- Protection contre attaques de surface totale tant qu’une station est opérationnelle ; combat orbital autorisé.
- L’auto-gouverneur peut être suspendu ; districts militaires et réserves naturelles protégés.
- Pas de simulation individuelle de chaque habitant à l’échelle planétaire ; population agrégée par district.
- Presets de développement et coefficients économiques à calibrer, non figés.
- Victoires alternatives économiques optionnelles ; diplomatie profonde/hors V1 J13.

## 75. Définition de « J13 terminé »

J13 ne sera **terminé** que lorsque les huit conditions suivantes sont prouvées : (1) compile/import Godot sans erreur, (2) source J1–J12 non régressée, (3) planète mère X → nouvelle colonie VII avec production locale verrouillée, (4) fret réel de renforts/ressources et trésorerie sans duplication, (5) R/C/I et services intégrés à une économie qui peut échouer ou réussir selon ressources, (6) gouverneur X expansion sur tout périmètre éligible avec couverture lisible, (7) verrou orbital et débarquement contrôlé y compris IA, (8) recette et performance Android réelles documentées. Tout scénario non exécuté est `NOT_RUN`, pas `PASS`.

---

# ANNEXE A — EXEMPLES DE JOURNÉE DE JEU

**A1. Planète mère âge X**. Ratio cible 45/25/30. Une région industrielle tombe en panne d’eau : les usines de composants s’arrêtent, le commerce manque de marchandises, les bénéfices diminuent. Le gouverneur répare le réseau et alloue un import d’eau/équipement si nécessaire. Le joueur peut ordonner une priorité au spatioport, en sachant que les crédits existent mais pas forcément le carburant sur place.

**A2. Colonie Proxima VII**. Le joueur envoie 12 colons, un constructeur, 3 unités de niveau X et 50 alliages par navette depuis Sol. La mission part après réservation. À l’arrivée, la colonie peut installer une base VII avec ses provisions, les unités X combattent et s’entretiennent avec les pièces importées, mais la colonie ne peut pas entraîner une frégate. Elle construit installations industrielles → VIII → spatioport IX → chantier orbital ; alors seulement la planète obtient sa défense orbitale.

**A3. Offensive ennemie**. Une planète possède 2 stations de commandement orbital. L’IA en détruit une ; invasion toujours interdite. Après destruction de la deuxième, sa navette descend et tente de conquérir la base terrestre. Le défenseur construit une station de remplacement depuis un drone ; les renforts ennemis suivants sont bloqués, mais les unités déjà débarquées restent sur place. Les alertes indiquent les causes et ordres possibles.

**A4. Monde presque urbanisé**. 99 % des surfaces éligibles sont développées mais 3 % de population n’a pas accès aux pompiers par route. La planète n’est pas considérée totalement couverte. Le gouverneur identifie un goulot routier, réserve un passage, ajoute un poste de secours, réévalue et clôture l’alerte si la capacité devient suffisante. Il n’urbanise pas l’océan restant pour afficher artificiellement 100 %.

# ANNEXE B — COMMANDES DE RÉFÉRENCE POUR LES RECETTES (NON EXÉCUTÉES DANS CE CADRAGE)

Contexte : environnement de développement avec Godot installé, dossier extrait `sillons/`, outils Android en place pour export ; commandes à lancer sur la copie de travail, pas sur la baseline préservée.

```bash
./tools/verify-j12.sh
./tools/export-android-j12.sh
```

**Attention** : ces scripts appartiennent à la source **0.12.3**. La recette J13 devra introduire ses propres scénarios et un nouveau lanceur (`verify-j13.sh`) ; ces nouveaux fichiers ne sont pas encore livrés. Si Godot manque, le code de retour 127 de `verify-j12.sh` signifie qu’aucune validation runtime n’a été faite.

# ANNEXE C — RÉFÉRENCES EXTERNES

1. Godot — renderers Mobile, Compatibility et Forward+ : https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html
2. Godot — MultiMesh et limites de culling : https://docs.godotengine.org/en/stable/tutorials/performance/using_multimesh.html
3. Godot — optimisation 3D, transparence, LOD, occlusion et éclairage : https://docs.godotengine.org/en/stable/tutorials/performance/optimizing_3d_performance.html
4. Source projet inspectée : archive `sillons-empire-j12-chantier-naval-orbital-0.12.3-source-complet.zip` et ses README J9–J12.3.
5. Cadrage historique distinct : `Sillons_Empire_Cadrage_Integral_V2.0.md`, daté du 10 novembre 2026, rédigé sur la base 0.8.2 et conservé **uniquement pour comparaison**, ses statuts « EXISTANT » ne sont pas applicables à la source 0.12.3.

**Fin du cadrage expert V3.0.**
