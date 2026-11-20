# Sillons d’Empire — Cadrage des évolutions V1.0

**Date :** 14 novembre 2026, Europe/Paris.  
**Objet :** jouabilité tactile, organisation des armées, grandes cartes, départs interstellaires et politique planétaire.  
**Statut :** spécification de conception ; ces évolutions ne sont pas livrées par ce document.  
**Cible :** Godot 4 / GDScript, Android paysage, solo hors ligne, recette principale sur Galaxy S25 Ultra.

## 1. Résultat recherché

Passer d’une gestion où le joueur répète les mêmes manipulations à un commandement d’empire : les bâtiments envoient leurs recrues à destination, les armées reçoivent des objectifs, les territoires ont une profondeur logistique et les populations réagissent aux décisions du pouvoir.

La campagne principale commence avec deux civilisations dans des systèmes stellaires différents. Chacune développe son monde, découvre son voisinage et organise ses colonies. Leur rencontre résulte de l’exploration et des technologies acquises. Une planète négligée peut formuler des revendications, faire sécession et devenir une faction autonome hostile. La réunification peut être militaire, économique ou politique.

Le joueur doit pouvoir répondre à quatre questions à chaque échelle : **que se passe-t-il, pourquoi, que puis-je ordonner, et quel sera le coût ?**

### 1.1 Statut des décisions

| Marque | Sens |
|---|---|
| **D — Direction demandée** | Demande explicite de l’utilisateur ou invariant antérieurement établi |
| **P — Proposition de cadrage** | Règle recommandée pour rendre la direction jouable ; arbitrage de conception modifiable |
| **T — Cible de validation** | Valeur à mesurer ou à équilibrer ; aucun résultat de performance n’est promis |

Les demandes D priment sur les propositions P. Les exemples de seuils, durées, tailles et coefficients restent T tant que les recettes ne les ont pas validés. Le périmètre couvre les idées de cet échange ; il complète les cadrages historiques sans prétendre remplacer l’intégralité du GDD.

### 1.2 Directions demandées et propositions associées

| Référence | Direction | Statut |
|---|---|---|
| D01 | Améliorer la jouabilité et les commandes tactiles | D |
| D02 | Envoyer automatiquement les unités militaires nouvellement produites vers un point défini | D |
| D03 | Disposer de cartes beaucoup plus grandes | D |
| D04 | Faire commencer l’adversaire principal dans un autre système stellaire | D |
| D05 | Faire dépendre le rendement économique du bien-être de la population | D |
| D06 | Permettre une révolte avec revendications et conditions à respecter | D |
| D07 | Transformer une planète en adversaire si les conditions de sortie de crise ne sont pas respectées | D |
| D08 | Permettre la reprise par la force et par d’autres moyens | D |
| D09 | Conserver les dix âges, la progression locale et la simulation des unités hors écran | D, invariants du projet |
| P01 | Renfort automatique d’une armée, vagues, compositions cibles, patrouilles et réserves | P |
| P02 | Distinguer bien-être et loyauté, proposer autonomie, fédération et réunification négociée | P |
| P03 | Proposer des factions locales optionnelles pour les conflits avant l’interstellaire | P ; activation distincte du mode principal |

## 2. Point de départ réellement inspecté

La référence technique immédiate est `sillons-empire-j13-import-mobile-0.13.4-source-complet.zip`, candidate, SHA-256 :

```text
db7d425a8905c8d563e9f100a14dd346d7830361a58c1823caf6bd10dbd54783
```

Ses preuves de livraison rapportent 33 scénarios PASS sous Godot 4.7.2 Linux et un chargement natif des modèles. Elles ne valident pas le démarrage sur téléphone, les grandes cartes ou les systèmes politiques décrits ici. L’export APK et la recette Android restent NOT_RUN. Le blocage Android signalé concernait l’import des GLB ; sa cause précise n’a pas été établie par la capture.

### 2.1 Fondations existantes à étendre

| Source inspectée | Constat | Conséquence pour cette évolution |
|---|---|---|
| `sillons/sim/sim_world.gd` | Simulation distincte du rendu ; ordres via `issue()` ; files de production, escouades et ralliement basique | Étendre le contrat existant plutôt que recréer la production |
| `Building.rally`, commande `rally`, `_production_and_research()`, `_join_squad()` | La destination influence déjà la sortie et le regroupement des unités | Vérifier les escouades en formation, rendre le réglage accessible et fiabiliser son comportement |
| `game/` et `views/`, recherche des références au ralliement | Aucune commande tactile dédiée identifiée dans cette inspection | Ajouter le parcours sélectionner → drapeau → destination, puis le tester réellement |
| `sillons/sim/rules.gd` | Carte tactique historique de 96 × 96 cases ; tick logique de 10 Hz | Dimensionner les mondes par configuration et retirer les hypothèses de taille fixe |
| `sillons/sim/star_campaign.gd` | Création historique des deux camps dans le théâtre initial ; plusieurs états sous forme de tableaux de deux éléments | Créer des origines séparées pour les nouvelles campagnes et généraliser les factions |
| `SimWorld.enemies_of()` | Adversaire calculé par `1 - team_id` pour les deux camps principaux | Une faction rebelle exige un registre de factions et des relations explicites |
| `sillons/sim/j13_rules.gd` | Âges locaux, R/C/I, routes, services, gouverneur ; âge initial colonial fixé à VII | Conserver ces règles ; la nouvelle géopolitique ne change pas implicitement l’âge des colonies |
| `sillons/sim/j13_save.gd` | Validation limitée notamment aux camps 0 et 1 et aux statuts historiques | Versionner et migrer les sauvegardes avant d’activer les sécessions |
| `sillons/game/asset_library.gd` | Modèles natifs en PCK et caches bornés | Conserver cette séparation pour éviter le retour des imports massifs sur Android |

La présence d’un champ dans la simulation ne démontre pas une interaction complète et validée sur Android. Les constats ci-dessus sont une lecture ciblée des sources disponibles, pas un audit exhaustif.

## 3. Invariants à préserver

1. Solo hors ligne ; aucun service distant nécessaire à la simulation, aux sauvegardes ou à la diplomatie IA.
2. Dix âges I–X ; chaque camp progresse à son rythme. La production locale reste soumise à l’âge, aux technologies, au producteur et aux ressources disponibles localement.
3. Le départ historique des nouvelles colonies à l’âge VII reste la règle de la source inspectée. Un changement de cette règle ferait l’objet d’un arbitrage distinct.
4. Le joueur et l’IA principale commencent à l’âge I dans le nouveau scénario long proposé. Les anciens scénarios conservent leur configuration.
5. Aucun transfert ne crée de ressources ou d’unités. Les ressources physiques restent localisées ; les crédits suivent la comptabilité impériale existante.
6. Le transport interplanétaire et interstellaire respecte les capacités, technologies, coûts, itinéraires et délais. Un ralliement ne contourne pas ces règles.
7. Un débarquement hostile respecte le verrou des stations de commandement orbital ennemies opérationnelles. Une station détruite ne donne pas automatiquement le contrôle terrestre.
8. Les unités continuent d’agir dans les mondes hors écran selon les mêmes règles. Le changement de caméra n’altère ni leurs décisions ni leurs résultats.
9. La défaite conserve la règle des centres de commandement et des moyens capables de les reconstruire. Une sécession ne déclenche pas un résultat global par simple changement d’étiquette.
10. Les coûts, refus et causes d’arrêt restent explicables. Une commande invalide n’a aucun effet partiel.
11. Les sauvegardes et identités d’entités sont préservées par migration ; les versions antérieures restent disponibles pour retour arrière.
12. La simulation évoluera nécessairement pour porter ces nouvelles règles. Préserver les comportements historiques dans leur mode de compatibilité et documenter chaque changement intentionnel ; l’identité octet pour octet des 32 fichiers de simulation de la candidate n’est pas une contrainte pour les futurs développements.

## 4. Boucles de jeu et progression

| Phase | Décisions principales | Aides à la gestion |
|---|---|---|
| Fondation | Construire, relier, nourrir, explorer et former les premières unités | Prévisualisation, routes au doigt, causes de blocage, ralliement simple |
| Développement | Spécialiser les quartiers, protéger les routes et améliorer les producteurs | Production regroupée, objectifs facultatifs, formations et alertes |
| Industrialisation | Organiser les chaînes de matières, la logistique et les budgets | Compositions militaires cibles, dépôts et priorités civiles/militaires |
| Expansion spatiale | Explorer, coloniser et ravitailler des mondes éloignés | Gouverneurs configurables, missions de transport et renforts tracés |
| Confrontation des empires | Contrôler les corridors, défendre les colonies et mener des campagnes | Armées déléguées, réserves, diplomatie et journal des engagements |
| Consolidation politique | Équilibrer prélèvements, services, autonomie et effort de guerre | Tableaux de bien-être, anticipation des crises et accords de réunification |

Le départ dans un autre système repousse la rencontre avec l’adversaire principal jusqu’aux moyens de contact et de déplacement appropriés. Les premiers âges doivent proposer des décisions économiques, territoriales et d’exploration suffisantes. Des factions locales indépendantes peuvent être ajoutées comme option annoncée à la création de partie ; elles ne remplacent pas secrètement le départ séparé demandé.

Les objectifs facultatifs orientent vers des actions pertinentes et disponibles à l’âge courant. Ils ne fabriquent pas de ressources gratuites pour contourner une économie en panne.

## 5. Gestion des unités et production

### 5.1 Ralliement obligatoire du premier lot

**Parcours tactile :** sélectionner un bâtiment producteur → toucher l’icône drapeau → choisir une destination → obtenir une confirmation visuelle. Le panneau indique le type d’ordre et la destination. Annuler le mode de placement n’altère aucun ordre.

**Contrat de simulation :**

- La destination est une référence au monde, à la région et à la position, avec un domaine de déplacement valide.
- La modification prend effet à un tick identifié. Toute unité terminée à partir de ce tick reçoit le ralliement effectif ; aucune unité ne reçoit deux ordres concurrents de création.
- Une destination individuelle a priorité sur le ralliement commun du groupe de producteurs ; en son absence, utiliser le rassemblement local par défaut.
- Le déplacement direct constitue le comportement initial. La marche offensive est une option explicite avec engagements limités aux ennemis détectés.
- Le nouveau ralliement n’écrase pas les ordres des unités déjà parties. Une action distincte redirige les renforts en transit quand leur état le permet.
- Dans une escouade en formation, rattacher la recrue à un groupe compatible avec le ralliement courant. Un ancien ordre d’escouade ne doit pas annuler la destination nouvellement choisie.
- Les ouvriers conservent leur fonctionnement économique tant qu’un ordre explicite ne leur est pas destiné.
- Un point hors limites ou d’un domaine incompatible est refusé. Un point temporairement inaccessible laisse les recrues au rassemblement local, avec une seule alerte regroupée et une possibilité de réessai.
- Une cible mobile disparue déclenche le repli configuré ; aucune poursuite d’un identifiant réutilisé.
- Le drapeau et les traits de trajet sont contextuels. Le brouillard continue de masquer les informations ennemies non connues.
- Ralliements, sources d’héritage, groupes en formation et ordres en cours sont sauvegardés.

### 5.2 Renforts et automatisations proposées

| Fonction | Contrat recommandé |
|---|---|
| Renforcer une armée | Affecter les nouvelles recrues à l’identité persistante de l’armée ; rejoindre un point d’interception recalculé à cadence bornée |
| Ralliement commun | Appliquer une destination à plusieurs producteurs autorisés ; préserver les exceptions individuelles affichées |
| Départ par vagues | Attendre une composition ou un délai maximum ; permettre un départ manuel immédiat |
| Composition cible | Exprimer un effectif souhaité par rôle/type ; compter les survivants et les recrutements déjà réservés avant de lancer un remplacement |
| Production récurrente | Activable et suspendable ; respecter réserve minimale, population, ressources et plafond demandé |
| Réserves de défense | Affecter une proportion ou un effectif minimal à la défense locale, puis envoyer les autres recrues |
| Ordres successifs | Déplacer, attendre, défendre, patrouiller, escorter ; les étapes sont éditables et disposent de conditions d’arrêt |
| Formations | Ligne, colonne, dispersion ; adaptation aux passages et regroupement des retardataires par domaines compatibles |
| Tableau de production | Producteur, unité, temps, ressources réservées, blocage et destination ; accès direct à la cause |

L’ordre manuel du joueur prime sur l’automatisation pour les entités visées. La délégation ne se réactive qu’à la fin du contrat manuel ou par restitution explicite. L’automatisation ne doit pas racheter indéfiniment des troupes détruites au-delà du budget.

### 5.3 Renforts entre mondes

Le ralliement distant produit une demande logistique : rassemblement local, attente d’un transport compatible, chargement, trajet, arrivée, débarquement autorisé puis intégration à l’armée. Chaque étape possède un état, une origine, une destination et une cause d’attente.

La production n’est débitée qu’une fois. Une unité chargée n’existe plus simultanément sur le terrain d’origine. L’annulation ou la perte du transport applique les règles de cargaison prévues, avec journal comptable. Les détails d’un itinéraire peuvent évoluer selon la connaissance et les risques connus du camp.

## 6. Construction, économie et commandes tactiles

| Domaine | Évolution cadrée | Validation attendue |
|---|---|---|
| Placement | Fantôme du bâtiment, emprise, coût, raccordement et couverture de services | Le verdict affiché concorde avec la validation logique au moment de confirmer |
| Routes | Tracé au doigt et coût total prévisionnel ; annulation avant validation | Aucun débit pendant la prévisualisation ; aucun tronçon invalide payé silencieusement |
| Empreintes | Respect des tailles pertinentes de 1, 2, 4 ou 8 carrés et du catalogue du projet | Pas de multiplication systématique des variantes sans besoin fonctionnel |
| Zones R/C/I | Besoins, emplois, habitants, débouchés et équilibre cible visibles | Le joueur identifie le goulot dominant et l’action accessible pour y répondre |
| Services | Couverture, capacité, accès routier et saturation distincts | Une zone colorée comme couverte n’est pas présentée comme servie si la capacité manque |
| Commandes | Barre contextuelle courte avec actions valides et retours d’ordre | Les gestes de caméra et les panneaux modaux n’émettent pas de commandes de terrain parasites |
| Technologie | Prochains déblocages, prérequis et améliorations du producteur | La connaissance impériale ne contourne pas les capacités de production locales |
| Armées déléguées | Objectif, état, obstacle et reprise en main accessibles | Aucun ordre caché n’annule une intervention manuelle |
| Alertes | Gravité, monde, cause, regroupement et bouton d’action | Une crise distante reste visible sans répétition d’alertes identiques à chaque tick |
| Gouverneur | Budget, réserve, objectif économique et explication des décisions | Il respecte les engagements politiques et les protections territoriales |

Une modification de réseau peut rendre une prévisualisation périmée : confirmer revalide l’ensemble et explique le refus sans débit. La qualité graphique et les options de confort restent indépendantes des règles métier.

## 7. Grandes cartes et territoire continu

### 7.1 Échelle visée

La carte historique de 96 × 96 représente 9 216 cases. Les paliers ci-dessous sont des profils de test, pas des capacités Android déjà démontrées.

| Profil proposé | Surface tactique d’une région | Surface relative au socle | Statut |
|---|---|---|---|
| Héritage | 96 × 96 | 1 | Compatibilité |
| Grande région | 256 × 256 | Environ 7,1 fois | Première cible T |
| Très grande région | 512 × 512 | Environ 28,4 fois | Cible T après mesure |

Le nombre de régions et de planètes est configuré séparément. Agrandir une région ne signifie pas qu’elle représente toute la sphère planétaire. Les coordonnées tactiques, régions, districts civils et positions du globe doivent avoir des correspondances explicites et testées.

### 7.2 Règles territoriales

- Découpage proposé en secteurs de 32 × 32 cases pour indexation, navigation et rendu ; taille à profiler.
- Identités et positions logiques continues lors du passage entre secteurs et régions.
- Ressources réparties en bassins, passages, carrefours et zones logistiques ; pas seulement une répétition uniforme du terrain existant.
- Minicarte, zoom stratégique, recentrage sur sélection et historique de navigation adaptés aux grandes distances.
- Routes, ponts, gués, occupation et brouillard cohérents aux frontières.
- Estimation des trajets et lieux de rassemblement qui tiennent compte du domaine de déplacement.
- Génération seedée ; mêmes cases et connexions pour une seed et une version de générateur données.
- Les territoires encore vierges peuvent être décrits par leur seed et leurs modifications persistantes. Les unités et installations existantes ne cessent pas de simuler lorsqu’un secteur graphique est déchargé.

### 7.3 Navigation

Proposer un graphe hiérarchique des connexions interrégions/intersecteurs, complété par une navigation fine locale. Invalider les connexions concernées lorsqu’une route, une structure ou un passage change. Mutualiser les demandes compatibles ; conserver des files de calcul bornées et équitables.

Une demande différée reste un ordre en attente clairement identifié. Aucune unité n’est abandonnée indéfiniment parce que son monde n’est pas affiché. Le budget historique de chemins doit être repensé à l’échelle de la campagne, pas multiplié sans contrôle pour chaque région ajoutée.

## 8. Départs dans des systèmes stellaires différents

### 8.1 Nouvelle campagne principale

**D :** système d’origine du joueur différent de celui de l’adversaire principal. Les deux camps ont dès le démarrage des états économiques et militaires réellement simulés.

**P :** départs à l’âge I, à conditions comparables selon le niveau de difficulté. La génération garantit les ressources et accès requis pour atteindre les technologies spatiales. Une difficulté asymétrique est annoncée et stockée dans la configuration.

- Les connaissances initiales portent sur l’environnement de départ autorisé. Les systèmes adverses ne sont pas découverts par un ancien réglage global de caméra ou de scénario.
- L’IA ne connaît ni les stocks ni les positions du joueur avant les informations obtenues dans le jeu.
- Les sondes et contacts diplomatiques débloquent l’information correspondante ; le déplacement reste soumis à ses propres technologies.
- Les empires explorent et colonisent à leur rythme. Les systèmes intermédiaires deviennent des relais et enjeux de contrôle.
- Les conditions de changement d’âge ne doivent pas exiger une bataille contre un adversaire inaccessible. Fournir dans ce mode des objectifs équivalents d’exploration ou de développement, annoncés et versionnés.
- Les scénarios historiques et le laboratoire conservent leur démarrage connu ; une ancienne partie n’est pas réorganisée rétroactivement entre systèmes.

### 8.2 Diplomatie et factions

Introduire un registre de factions à identités stables et une matrice de relations : guerre, neutralité, trêve, accord commercial, alliance et association politique. Les états ont des effets explicites sur le combat, les transports, l’accès et les échanges.

Le camp neutre historique reste identifiable mais n’occupe pas un identifiant supposé incompatible avec les factions dynamiques. Une migration traduit les anciens identifiants 0, 1 et 2 sans réutiliser une identité détruite. Une sécession crée une faction ; elle ne remplace pas l’adversaire principal dans un tableau à deux cases.

Le registre doit accepter au minimum les factions initiales et une faction sécessionniste distincte pour chaque planète colonisée du profil de campagne. Prévoir cette capacité dès la création de partie : une révolte ne doit pas être annulée par un plafond de factions atteint en cours de jeu. Les profils publiés annoncent le nombre de mondes et d’entités effectivement testé.

## 9. Politique : bien-être, loyauté et rendement

### 9.1 Données civiles

Le bien-être est calculé à partir des quartiers ou districts et agrégé selon la population concernée. Le joueur peut consulter le détail pour éviter qu’une moyenne planétaire masque une zone durablement en crise.

| Facteur | Données utilisables | Leviers du joueur |
|---|---|---|
| Subsistance | Besoins et livraisons alimentaires réels | Production, importations, priorité de distribution |
| Eau et énergie | Capacité disponible, accès et continuité du service | Réseaux, réserves et réparation |
| Habitat | Capacité, occupation et conditions de logement | Zonage, densification et desserte |
| Services | Couverture et capacité effective adaptées à l’âge | Construction, budget et accès routier |
| Activité | Emplois, postes disponibles et fonctionnement industriel | Équilibre R/C/I et investissements |
| Environnement | Pollution et exposition des zones habitées | Implantation, protections et technologies |
| Sécurité | Menaces, dégâts et protection réellement assurée | Défense, services et reconstruction |
| Niveau de vie | Charge fiscale et accès aux biens disponibles à l’âge local | Fiscalité et politique d’approvisionnement |

Une exigence non débloquée à l’âge local n’entre pas dans le calcul. Les pondérations actives sont normalisées et versionnées. Les pénuries physiques restent visibles séparément du score synthétique.

### 9.2 Deux indicateurs

- **Bien-être U, de 0 à 100 :** conditions matérielles, services et niveau de vie.
- **Loyauté L, de 0 à 100 :** adhésion à l’autorité impériale, influencée par l’autonomie, l’équité perçue, la protection, les engagements et les crises durables.

Une population satisfaite peut demander de l’autonomie. Une population loyale peut supporter temporairement une difficulté expliquée. La loyauté possède une inertie : les changements politiques ne résultent pas d’une oscillation instantanée d’une jauge.

Les effets de promesses, décisions et événements sont calculés à cadence logique fixe. Les valeurs exactes relèvent de l’équilibrage, sans tirage opaque décidant arbitrairement d’une sécession.

### 9.3 Effet économique proposé

Exemple de coefficient de productivité du travail, T :

```text
M(U) = clamp(0,75 + 0,005 × U ; 0,75 ; 1,15)
U = 0  : M = 0,75
U = 50 : M = 1,00
U ≥ 80 : M = 1,15
```

Ce coefficient modifie le débit du travail ou le temps de production éligible. Il ne multiplie pas gratuitement les biens après consommation des ingrédients. Ressources, énergie, machines, main-d’œuvre et capacité restent des contraintes réelles. Pour l’extraction, le débit final est retranché du gisement ; pour la transformation, les recettes conservent leurs entrées et sorties.

Appliquer cet effet une seule fois par chaîne de calcul documentée. Une grève ciblée est un effet distinct, explicité et plafonné, pas une pénalité cachée appliquée plusieurs fois. La distribution des biens essentiels peut être priorisée, mais leur existence et leur transport restent nécessaires.

### 9.4 Leviers politiques proposés

| Politique | Gain potentiel | Coût ou tension possible |
|---|---|---|
| Fiscalité | Financer l’empire | Niveau de vie et acceptation des prélèvements |
| Budget des services | Couverture, continuité et satisfaction | Dépenses et emplois nécessaires |
| Mobilisation | Accroître les effectifs militaires | Réduction des travailleurs disponibles et fatigue de guerre |
| Priorité industrielle | Accélérer certaines productions | Déséquilibre civil, pollution ou pénuries d’autres biens |
| Autonomie | Améliorer la légitimité et déléguer localement | Moins de contrôle impérial et partage des recettes |
| Aide d’urgence | Répondre à une crise locale | Coût, délai de transport et engagements à tenir |

Les politiques affichent leurs effets estimés, leur coût, leur délai et leurs limites. Le gouverneur peut exécuter une politique autorisée ; il ne déclare ni guerre ni sécession au nom du joueur.

## 10. Crises, revendications et sécession

### 10.1 Machine d’états proposée

| État | Déclenchement ou rôle | Sortie possible |
|---|---|---|
| Stable | Situation normale ou redressement confirmé | Mécontentement durable |
| Mécontentement | Besoins insatisfaits ou loyauté en baisse au-delà d’une durée de tolérance | Redressement ou contestation |
| Contestation | Crise persistante ; mouvements et grèves ciblés | Redressement ou revendications formelles |
| Revendications | Conditions explicites, délai, représentants et conséquences annoncées | Accord, contre-proposition ou refus |
| Accord sous surveillance | Engagements acceptés et mesurés dans le temps | Stabilisation ou rupture à l’échéance |
| Sécession | Refus à l’échéance ou conditions non respectées | Faction indépendante hostile à l’ancien pouvoir |
| Occupation / rapprochement | Processus de reprise militaire ou négociée | Réintégration, autonomie, association ou nouvelle crise |

Un bien-être bas déclenche d’abord une crise de besoins. Une loyauté durablement basse peut déclencher une crise d’autonomie même dans une planète prospère. L’ultimatum de sécession n’apparaît qu’après les étapes et avertissements prévus.

Exemples T à tester : mécontentement après 60 secondes de simulation sous les seuils ; contestation persistante avant un ultimatum ; délai de réponse et d’exécution de 180 à 300 secondes selon les travaux et transports requis. Ces durées ne sont pas des valeurs validées. Les conditions d’entrée et de sortie utilisent des seuils distincts et une durée minimale de rétablissement pour éviter les oscillations.

Tous les délais utilisent le temps de simulation. Une fermeture de l’application n’avance pas un ultimatum hors ligne. Si une pause politique est proposée, elle suspend toute la campagne, y compris les IA ; son comportement est explicite.

### 10.2 Conditions de sortie de crise

Une revendication contient : identifiant, auteur, causes, objectifs vérifiables, échéance, marge de négociation, engagements des deux parties et conséquence d’un échec. Une seule crise politique principale est active par autorité locale ; les causes supplémentaires alimentent le même dossier.

Exemples : livrer une quantité de vivres identifiée, rétablir un service à une couverture minimale, maintenir une fiscalité réduite pendant une période, financer un chantier existant ou reconnaître une autonomie définie.

La simulation vérifie la faisabilité au moment de proposer un accord : âge, technologies, emplacements, stock ou accès possible aux ressources et délai plausible. Si une demande maximale ne peut être réalisée, une contre-proposition réalisable doit exister. Une perte ultérieure de convoi n’efface pas automatiquement un engagement : elle peut justifier une renégociation dont les termes sont explicites.

Les travaux ou livraisons déjà accomplis sont pris en compte. Une cargaison en route reste en route ; elle n’est pas considérée comme livrée avant son arrivée. Un même stock ne satisfait pas simultanément plusieurs engagements incompatibles.

**D :** si les conditions de l’ultimatum ne sont pas respectées à l’échéance prévue, la planète fait sécession et devient un adversaire. Une fois l’accord conclu, le jeu ne remplace pas silencieusement ses conditions par de nouvelles exigences.

### 10.3 Changement d’autorité et biens

La souveraineté planétaire et le contrôle militaire local sont distincts. Une planète peut faire sécession tout en contenant une enclave ou une garnison fidèle à l’empire.

| Élément | Règle de transfert proposée |
|---|---|
| Administration et infrastructures civiles de l’autorité sécessionniste | Transfert à la nouvelle faction, avec stocks physiquement détenus et population concernée |
| Quartiers d’une autre faction déjà présents | Aucun transfert automatique |
| Milices locales | Peuvent rejoindre les insurgés selon leur allégeance locale déclarée et visible avant la crise |
| Armée régulière et forces expéditionnaires | Conservent leur faction ; peuvent se retrouver dans une enclave hostile |
| Bases et stations orbitales militaires régulières | Conservent leur contrôle jusqu’à capture ou destruction selon les règles applicables |
| Trésorerie impériale | Ne se duplique pas et ne bascule pas intégralement avec la planète ; seules les réserves locales attribuées sont concernées |
| Convois et cargaisons déjà en transit | Conservent propriétaire et inventaire ; attente, retour ou détournement explicitement résolu selon l’état diplomatique |
| Recrutements et recherches locaux | Revalider propriétaire, prérequis et ressources engagées ; aucune double production ou double restitution |
| Données de reconnaissance | La nouvelle faction reçoit la connaissance locale justifiée ; aucun dévoilement de toute la galaxie |

La sécession est une transaction logique atomique : vérifier le plan, réserver l’identité de faction, appliquer les transferts, modifier les relations, réviser les ordres affectés, publier les événements. En cas d’échec interne de validation, aucun transfert partiel n’est appliqué.

Les insurgés produisent et recrutent avec leurs stocks, installations et population. L’apparition de la faction ne crée pas une armée gratuite. Leur autonomie civile ne détruit pas automatiquement les unités restées fidèles dans la zone.

## 11. Reconquête, diplomatie et réintégration

| Voie | Conditions | Résultat et coût |
|---|---|---|
| Aide et réconciliation | Livraisons, services rétablis, engagements vérifiés et relations suffisantes | Réintégration progressive ; dépenses, délais et confiance à reconstruire |
| Autonomie négociée | Accord sur les pouvoirs locaux, recettes, défense et obligations | Appartenance à l’empire avec contrôle partagé |
| Fédération ou association | Intérêts communs, traité accepté et engagements réciproques | Coopération avec gouvernement propre ; ce n’est pas une annexion complète |
| Réunification politique | Soutien local durable et procédure acceptée | Vote déterminé par les états simulés et expliqué ; pas de résultat aléatoire opaque |
| Accord de protection | Menace extérieure identifiée et capacité réelle de protection | Engagement militaire ou diplomatique en échange d’un rapprochement |
| Reconquête militaire | Accès logistique, règle orbitale respectée et objectifs terrestres pris | Occupation, coûts de garnison, réparations et risque de nouvelle crise |

Les offres utilisent des leviers réellement modélisés. La dépense ne doit pas être un bouton qui achète instantanément une planète. Une IA sécessionniste peut refuser une offre qui ne satisfait pas ses objectifs ; le joueur doit comprendre les facteurs connus du refus.

La réussite militaire ouvre une période d’occupation. Réparer, approvisionner, rétablir des services et appliquer les engagements réduit progressivement le risque. L’âge local, la population survivante, les infrastructures et les unités survivantes sont conservés. Une reconquête ne réinitialise pas la planète à l’âge I ou VII.

Les règles de trêve précisent leurs effets : tirs, passages, débarquements, ravitaillement, échanges et traitement des unités déjà présentes. Une trêve politique n’ouvre pas implicitement tous les accès militaires.

Les accords comportent des périodes de maintien et un délai de stabilisation. Une stabilisation durable est nécessaire avant de clore la crise ; un bref changement de fiscalité ne suffit pas à déclencher des cycles de récompense et de sécession.

## 12. Interface et présentation

### 12.1 Écrans proposés

1. **Producteur militaire :** file, recrutement, drapeau, destination, contribution à une armée et réserves.
2. **Armée :** mission, composition, renforts attendus, ravitaillement, formation et intervention manuelle.
3. **Planète — population :** bien-être, loyauté, évolution, besoins dominants et districts concernés.
4. **Planète — politique :** fiscalité, autonomie, budgets, mobilisation et décisions du gouverneur.
5. **Dossier de crise :** causes, conditions, coût estimé, échéance et réponses possibles.
6. **Empire :** alertes regroupées, armées, convois, planètes fragiles et engagements en cours.

Les jauges affichent valeur, tendance et causes principales. Les couleurs sont accompagnées de texte et de symboles. Les données d’un monde étranger restent limitées aux informations diplomatiques ou de reconnaissance disponibles, avec date de dernière observation.

### 12.2 Présentation graphique

- Drapeaux et trajets lisibles au zoom courant ; formes distinctes pour les ordres et domaines.
- Calques dédiés routes, services, activité, bien-être, loyauté et zones de contrôle.
- Signaux visuels de crise proportionnés : icônes de quartiers, activité réduite et rassemblements en nombre borné.
- Changement de faction par bannières et marquages cohérents avec le contrôle des actifs ; pas de recoloration de toutes les troupes régulières à la sécession.
- Conservation des modèles natifs, LOD, rendu par lots et profils graphiques existants.
- Les animations illustrent les états logiques ; leur absence à distance ou en qualité basse ne change aucune règle.

## 13. Architecture de simulation et intégration Godot

### 13.1 Découpage proposé

Les noms ci-dessous sont indicatifs et ne correspondent pas à des fichiers déjà créés.

| Composant | Responsabilité | Point d’intégration existant |
|---|---|---|
| `FactionRegistry` | Identités, contrôle, relations, élimination et accès aux informations | `SimWorld`, `StarCampaign`, IA et sauvegardes |
| `CampaignSetup` | Profils, origines séparées et objectifs de progression adaptés | Création de `StarCampaign` |
| `RallyService` | Destinations, héritage, groupes en formation et renforts | Production et commandes de `SimWorld` |
| `ArmyPlan` | Composition, réservations, vagues et priorités | Escouades, délégation et production |
| `WorldLayout` | Dimensions, coordonnées et connexions de régions | Règles de carte, génération et brouillard |
| `SectorNavigation` | Graphe de passage, files de chemins et invalidation | Navigation et occupation existantes |
| `PoliticalState` | Besoins, bien-être, loyauté, tensions et engagements | Économie et colonies de `PlanetCampaign` |
| `RevoltTransaction` | Transfert atomique de souveraineté et des actifs concernés | Factions, stocks, ordres et journal comptable |
| `TreatyService` | Offres, trêves, accords et réintégration | Diplomatie IA et contrôle des accès |
| `VisualSectorStream` | Création et retrait des représentations visibles | `world_view`, vues planétaires et bibliothèque native |

### 13.2 Ordres et cadence

Les entrées tactiles produisent des commandes validées. Les vues n’écrivent jamais directement dans les stocks, les propriétaires ou les jauges politiques. Toute commande possède un tick d’application, un auteur, des cibles et une réponse explicite.

Conserver au départ le pas logique de 10 Hz du projet. Politique, économie et décisions de haut niveau sont exécutées à des périodes entières de ce tick, selon leur fréquence métier. Ces périodes sont identiques pour un monde visible ou hors écran ; elles ne constituent pas une simulation réduite à distance.

L’ordre d’exécution des sous-systèmes est versionné. Proposition : commandes, validation des transports et changements de contrôle déjà engagés, déplacement/combat, production/consommation, mise à jour économique périodique, politique périodique, transitions politiques, décisions IA pour ticks suivants, événements et empreinte de contrôle. Les phases exactes devront respecter les contrats historiques et les tests de conservation.

Les décisions irréversibles d’un tick ne sont pas évaluées sur un mélange d’états avant et après transfert. Toute nouvelle faction est visible par les sous-systèmes à une frontière de phase définie.

### 13.3 Grandes campagnes et performances

- Conserver des données de simulation compactes et des index spatiaux ; éviter un nœud de scène par élément civil simulé.
- Séparer les secteurs graphiques de l’état logique des unités et bâtiments.
- Répartir les calculs périodiques entre ticks selon un ordonnancement stable, avec un âge maximal des données documenté.
- Répartir équitablement les budgets de navigation entre mondes et factions ; mesurer le délai maximal d’exécution des demandes.
- En surcharge, adapter d’abord la qualité et le coût du rendu. Ne pas supprimer des actions hors écran pour maintenir artificiellement les FPS.
- Si la simulation ne tient plus son rythme, ralentir explicitement le temps global plutôt que supprimer des ticks. Réduire ensuite le profil de capacité publié selon les mesures.
- Le parallélisme de simulation n’est introduit qu’après profilage et vérification du déterminisme. Les résultats de tâches ne sont pas appliqués à un tick dépendant de leur vitesse d’achèvement.

### 13.4 Rendu et chargement

Les ressources de secteur peuvent être demandées en arrière-plan, puis récupérées une fois leur statut prêt ; une récupération anticipée peut bloquer le thread [R1]. Les opérations sur l’arbre de scène actif restent sur le thread principal et les données partagées doivent respecter les contraintes de concurrence [R2].

Utiliser des MultiMesh par zones pour les objets compatibles. Leur visibilité est évaluée à l’échelle du lot : une distribution sur toute la planète dans un seul objet annulerait une grande partie du bénéfice du découpage [R3]. LOD et distances de visibilité complètent cette stratégie [R4].

Conserver `sillons/data/assets_3d.pck` dans les exports et les sources GLB hors du dossier Godot jouable. L’ajout d’un panneau politique ou d’une carte ne doit pas réintroduire les milliers de GLB dans l’import Android.

Ces choix sont une architecture proposée, fondée sur la documentation officielle. Leur efficacité dans cette campagne devra être mesurée ; elle ne découle pas automatiquement de l’utilisation de MultiMesh ou de threads.

## 14. Données, configuration et sauvegardes

### 14.1 États persistants requis

| État | Informations minimales |
|---|---|
| Faction | ID stable, nature, dirigeant IA/joueur, relations, possessions et connaissances |
| Localisation | Système, planète, région, secteur et coordonnées cohérentes |
| Ralliement | Producteur, destination fixe/mobile, mode, héritage, repli et révision |
| Plan d’armée | Composition, membres, affectations, recrutements réservés, budgets et étapes |
| Politique locale | Facteurs de besoins, U, L, tendances, durées sous seuils et état de crise |
| Revendication | Causes, objectifs, quantités, mesures de maintien, échéance et résultat |
| Souveraineté | Autorité civile, contrôle des quartiers, enclaves et allégeance des actifs |
| Traité | Parties, obligations, accès autorisés, délais et conséquences de rupture |
| Monde | Dimensions, version du générateur, seed, modifications, occupation et brouillard |

Les configurations de gameplay contiennent les périodes, pondérations, coefficients, profils de carte, coûts et délais. L’interface utilise ces tables pour afficher les valeurs ; elle n’en conserve pas une copie divergente.

### 14.2 Migration et validation

- Introduire une version de schéma explicite et des migrations testées depuis la source candidate.
- Préserver seed, tick, stocks, population, unités, bâtiments, âges locaux et progrès existants.
- Une ancienne partie conserve ses positions de départ et ses dimensions ; ne pas déplacer son adversaire dans un autre système après chargement.
- Proposer les nouveaux départs et tailles à la création d’une partie compatible.
- Pour activer la politique sur une ancienne campagne, initialiser un état neutre documenté avec délai de grâce, sans sécession rétroactive ni crédit gratuit. L’activation est annoncée.
- Un mode historique conserve les systèmes nouveaux désactivés lorsque leur migration n’est pas explicitement prévue.
- Valider références, types, bornes, valeurs non finies, dimensions, propriétaires, quantités et unicité des identités avant remplacement de la partie active.
- Préserver l’écriture temporaire, la validation, la sauvegarde précédente et le remplacement contrôlé. Une migration échouée conserve l’ancienne partie intacte.
- Mesurer la taille des nouvelles sauvegardes. La limite historique de 128 MiB de l’enveloppe ne doit pas être simplement augmentée sans étude mémoire ; un format segmenté et versionné peut devenir nécessaire.
- L’état sauvegardé est constitué de données ; aucun objet exécutable ou objet de scène n’est désérialisé comme logique de jeu.

Le retour arrière utilise une copie de sauvegarde compatible et l’ancienne version conservée. Une version ancienne n’a pas l’obligation de lire une sauvegarde produite par une version plus récente.

## 15. IA et équité

L’adversaire principal et les factions indépendantes utilisent les mêmes commandes validées, coûts, règles de production, besoins, transports et contraintes politiques. Leurs informations respectent leur brouillard et leurs accords.

L’IA doit savoir : développer une origine isolée jusqu’au spatial, rechercher un contact, protéger ses chaînes, gérer sa population, répondre à des revendications, négocier une trêve, demander de l’aide et adapter un plan militaire à ses moyens.

Une faction insurgée poursuit des objectifs locaux avant une conquête galactique : survivre, satisfaire les besoins, défendre son autorité et chercher des partenaires. Les attitudes diplomatiques reposent sur des facteurs auditables. Les aides de difficulté, si utilisées, sont explicites dans le scénario.

L’IA principale peut aussi subir une sécession. Une planète rebelle au joueur n’est pas automatiquement alliée à son adversaire ; une alliance demande les conditions et décisions correspondantes.

## 16. Critères de recette

Les critères ci-dessous sont des tests à créer et à exécuter. Aucun n’est présenté comme déjà PASS. Les 33 scénarios de la candidate restent une suite de non-régression à rejouer dans leur configuration historique.

| ID | Scénario | Résultat attendu |
|---|---|---|
| R01 | Produire plusieurs unités après pose du drapeau | Chaque unité rejoint la destination avec un ordre unique |
| R02 | Déplacer le drapeau pendant qu’une escouade se forme | Les nouvelles recrues suivent le nouveau contrat ; les ordres des unités déjà parties sont conservés |
| R03 | Point invalide, bloqué ou d’un autre domaine | Refus ou attente locale explicités ; aucun empilement de tâches ou d’alertes |
| R04 | Sauver et reprendre en production | File, coûts, ralliement et départs identiques à une exécution continue |
| R05 | Deux producteurs renforcent la même composition cible | Pas de double réservation ni de recrutement au-delà de la cible autorisée |
| R06 | Cible mobile détruite et transport interrompu | Repli valide ; aucune référence recyclée, unité ou cargaison dupliquée |
| M01 | Départ du profil interstellaire | Origines dans deux systèmes distincts ; deux civilisations actives dès le premier tick |
| M02 | IA isolée jusqu’au spatial | Progression possible sans bataille contre un ennemi inaccessible et sans connaissance interdite |
| M03 | Traversée de frontières de secteurs et régions | Continuité de position, ordre, identité, stock porté et brouillard |
| M04 | Secteur graphique déchargé pendant un combat | Résultat logique identique à la même simulation observée |
| M05 | Changements de routes et obstacles | Navigation invalidée seulement où nécessaire ; demandes anciennes résolues ou annulées proprement |
| F01 | Trois factions actives et un neutre | Relations, tirs, échanges, victoire et brouillard cohérents sans hypothèse binaire |
| P01 | Faire varier un facteur de bien-être à la fois | Causes et poids compréhensibles ; absence d’exigence technologique indisponible |
| P02 | Appliquer le coefficient de rendement à une recette et à un gisement | Débit conforme ; conservation des entrées, sorties et réserves |
| P03 | Pénurie brève puis durable | Tolérance puis progression de crise ; aucune sécession immédiate sur une fluctuation |
| P04 | Planète prospère à loyauté basse | Crise d’autonomie possible avec causes politiques explicites |
| P05 | Accord respecté, partiellement tenu puis rompu | Résultats conformes aux conditions convenues et aux échéances |
| P06 | Offre irréalisable et absence de technologie | Contre-proposition réalisable ; aucun ultimatum exigeant un bâtiment verrouillé |
| P07 | Sécession avec stocks, garnison, milice, bases et convois | Transfert atomique et allégeances prévues ; aucun bien créé ou perdu sans règle |
| P08 | Sécession pendant une sauvegarde/reprise | État complet avant ou après transaction, jamais un état partiel |
| P09 | Reconquête avec station orbitale ennemie opérationnelle | Débarquement refusé conformément au verrou existant |
| P10 | Réintégration négociée ou prise militaire | Âge et actifs survivants conservés ; stabilisation progressive |
| P11 | Même crise chez l’IA principale | Mêmes calculs, coûts, délais et possibilités de rupture |
| S01 | Charger une ancienne campagne puis la sauvegarder | Migration explicite et conservation des actifs ; ancienne copie utilisable |
| S02 | Fichier corrompu, hors bornes ou références invalides | Refus sans altération de la partie active |
| D01 | Même seed et journal, avec caméra et cadence de rendu différentes | Même empreinte logique dans la même version et le même environnement de référence |
| D02 | Ordre et résultat de tâches asynchrones variables | Aucun changement logique lié au temps de chargement graphique |
| U01 | Gestes tactiles, retour Android et panneaux modaux | Pas de commande traversante ; annulation et reprise prévisibles |
| A01 | Lancer le projet extrait sous Android | Bibliothèque native intacte ; aucun import GLB réintroduit |
| A02 | Partie prolongée sur appareil, sauvegardes et bascules de vues | Mesures complètes, absence de perte d’état et limites de capacité documentées |

### 16.1 Mesures Android

Établir un scénario reproductible par profil : seed, nombre de systèmes et planètes colonisées, factions, unités simultanées, quartiers, transports et crises. Faire varier les populations et le nombre de mondes par paliers.

Mesurer : temps logique moyen et percentiles, retard de simulation, temps de navigation, latence d’ordre, FPS/temps de frame, mémoire, durée de chargement, taille et durée de sauvegarde, stabilité thermique et évolution sur session prolongée.

**Cibles T proposées :** profil fluide visant 60 FPS, profil soutenu visant 30 FPS, simulation à 10 Hz sans dérive et réponse visuelle immédiate à la prise en compte d’un ordre. Le temps logique doit conserver une marge dans son intervalle de 100 ms. Les plafonds d’unités et de mondes sont publiés après mesures ; aucun volume « illimité » n’est promis.

Comparer le même scénario à la candidate et répéter après chauffe stabilisée. Les captures Linux, les appels de dessin et les tests sans écran ne remplacent pas ces mesures sur téléphone.

## 17. Découpage de développement recommandé

Les identifiants E0–E7 évitent de confondre cette extension avec les jalons historiques J1–J13. Ils ne préjugent pas de la numérotation des versions livrées.

| Lot | Contenu | Dépendance | Porte de sortie |
|---|---|---|---|
| **E0 — Socle et mesures** | Confirmer l’ouverture Android de la candidate, préserver source et sauvegardes, enregistrer les scénarios de référence | Source complète disponible | Démarrage appareil et bilan initial reproductibles |
| **E1 — Commandes et ralliement** | Parcours tactile, ralliement individuel/commun, escouades, sauvegarde, causes de blocage, prévisualisation et routes | E0 pour recette appareil | R01–R04 et U01 ; aucune régression historique |
| **E2 — Factions et origines** | Registre, relations, contrôle des actifs, sauvegardes et démarrages dans des systèmes différents | E1, migration préparée | F01, M01–M02 et S01–S02 |
| **E3 — Grandes régions** | Dimensions configurables, secteurs, navigation, coordonnées, interface de carte et flux graphique | E2 | M03–M05 ; premier profil de grande carte mesuré |
| **E4 — Population et politiques** | U/L, budgets, rendement, explications, adaptation IA et gouverneur | E2 et E3 pour intégration grande campagne | P01–P04, P11 ; effets économiques conservatifs |
| **E5 — Crises et souveraineté** | Revendications, accords, sécession, trêves, autonomie, réunification et occupation | E4, registre E2 | P05–P10, S01–S02 ; nouveau camp réellement jouable par l’IA |
| **E6 — Renforts et plans militaires** | Armées mobiles, vagues, compositions, réserves, ordres successifs et logistique entre mondes | E1–E3 ; contrats d’accès E5 | R05–R06, conservation des transports et reprise d’ordres |
| **E7 — Campagne complète** | Joueur/IA du départ isolé à la guerre interstellaire, crises multiples, réglage et capacité Android | E0–E6 | D01–D02, A01–A02 et recette de campagne complète |

Dans chaque lot : comportement logique vérifiable, interface nécessaire, tests utiles, documentation et livraison complète. Les fonctions avancées peuvent être décomposées si leur présence rend le lot non testable. Ne pas activer une sécession avant que l’IA et les sauvegardes acceptent réellement une troisième faction.

## 18. Risques et arbitrages

| Risque | Réponse de cadrage |
|---|---|
| Premiers âges sans conflit principal | Objectifs économiques/exploration adaptés ; factions locales proposées en option distincte |
| Agrandissement de grille qui multiplie mémoire et chemins | Profils progressifs, secteurs, graphes hiérarchiques et budget de campagne |
| Anciennes hypothèses à deux camps | Audit transversal des relations, sauvegardes, IA, brouillard, transports et victoire |
| Spirale pénurie → malus → aggravation | Malus plafonnés, aides réalisables et distribution prioritaire des essentiels |
| Gouverneur qui contredit un accord | Engagements politiques transformés en contraintes de planification vérifiées |
| Révoltes illisibles ou successives sur toutes les planètes | Causes locales, inertie, seuils distincts, délais de grâce et regroupement d’alertes |
| Arrêt de la simulation hors écran pour gagner des FPS | Optimiser rendu et données ; mesurer puis annoncer une capacité compatible avec la simulation demandée |
| Régression de chargement Android | Maintien du PCK natif et absence de GLB sous la racine Godot |
| Sauvegarde trop volumineuse | Mesures et éventuel stockage segmenté versionné avant augmentation des limites |

### 18.1 Arbitrages proposés dans cette version

1. Deux jauges U/L ; l’autonomie reste un paramètre politique plutôt qu’une troisième jauge obligatoire.
2. Campagne principale à départs séparés ; scénarios classiques conservés.
3. Premier profil de grande région proposé à 256 × 256 ; 512 × 512 conditionné aux mesures.
4. Révoltes conditionnées par une crise durable et un ultimatum explicite.
5. Armée régulière fidèle ; allégeance locale distincte pour les milices.
6. Réunification, autonomie et fédération ont des résultats de souveraineté différents.
7. Calcul politique au niveau des quartiers/districts et des planètes, sans créer un agent IA individuel pour chaque habitant.
8. Factions locales préspatiales optionnelles ; leur présence n’est pas une décision déjà imposée par l’utilisateur.

## 19. Livrables et définition de terminé

Pour chaque version de code ultérieure : ZIP source complet, manifeste, comparaison avec la base, règles modifiées, procédure d’ouverture, migrations, sauvegardes de test non personnelles, scénarios, journaux réellement obtenus et limites connues. Fournir l’APK de test si l’export aboutit ; identifier séparément tout test non exécuté.

La version intégrant ces évolutions est terminée lorsque :

- les recrues rejoignent les destinations et armées selon les contrats définis ;
- les profils de grandes cartes sont jouables et mesurés sur Android ;
- les deux empires commencent dans des systèmes distincts et progressent honnêtement ;
- le bien-être agit sur le rendement sans casser les stocks et recettes ;
- une crise propose des conditions réalisables, peut aboutir à une faction indépendante et reste sauvegardable ;
- une planète peut être réintégrée par au moins une voie négociée et par la voie militaire ;
- les opérations hors écran et changements de vue préservent les résultats logiques ;
- les scénarios historiques compatibles et les nouveaux critères applicables ont été exécutés avec preuves ;
- l’export, le téléphone et les performances sont décrits selon leurs résultats réels.

**État de ce livrable :** document de cadrage uniquement. Aucun code du jeu, aucune sauvegarde et aucune archive candidate n’ont été modifiés pour sa rédaction. Les règles nouvelles, les recettes et les cibles ci-dessus restent à implémenter et à valider.

## 20. Références

### Sources de projet consultées

- Conversation courante : idées de jouabilité, gestion des unités, grandes cartes, départ adverse séparé et politique planétaire.
- Archive candidate 0.13.4 et ses fichiers `LIVRAISON.json`, `README-LIVRAISON.md`, `cadrage/CADRAGE-INTEGRAL-EXPERT-V3.0.md` et preuves de livraison.
- Sources ciblées : `sim/sim_world.gd`, `sim/rules.gd`, `sim/star_campaign.gd`, `sim/j13_rules.gd`, `sim/campaign_save.gd`, `sim/j13_save.gd` et recherche des références au ralliement dans `game/`, `views/`, `sim/` et `lab/`.

### Documentation officielle Godot consultée le 14 novembre 2026

- **[R1]** [Background loading](https://docs.godotengine.org/en/stable/tutorials/io/background_loading.html) — requêtes de chargement, statut et récupération potentiellement bloquante.
- **[R2]** [Thread-safe APIs](https://docs.godotengine.org/en/stable/tutorials/performance/thread_safe_apis.html) — limites de l’arbre de scène, ressources partagées et objets AStar.
- **[R3]** [MultiMesh](https://docs.godotengine.org/en/stable/classes/class_multimesh.html) — instanciation et limites de visibilité par lot.
- **[R4]** [Optimizing 3D performance](https://docs.godotengine.org/en/stable/tutorials/performance/optimizing_3d_performance.html) — niveaux de détail, distances et coûts de rendu.

Les choix de politique, coefficients, tailles et phases de développement sont des propositions originales de conception. Les références moteur documentent les mécanismes techniques ; elles ne certifient pas la capacité Android de ce projet.

