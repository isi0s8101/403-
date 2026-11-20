# Fiches de design — mécaniques majeures J1

Chaque fiche : choix du joueur, informations disponibles, coût ou risque, contre-jeu, scénario de validation.

## F1 — Priorités économiques et réaffectation automatique

- **Choix** : quelle ressource privilégier (nourriture, bois, minerai), de 0 à 3, à tout moment.
- **Information** : bandeau du haut — stock, nombre d'ouvriers par ressource, jauge de priorité,
  mention « aucun gisement disponible » ; messages de réaffectation, d'épuisement et de pénurie ; dans le panneau
  d'un ouvrier, sa tâche et la cause d'un blocage (« trajet interrompu », « fermes toutes occupées »…).
- **Coût / risque** : un ouvrier réaffecté perd le trajet en cours ; des gisements lointains allongent les trajets
  (un entrepôt les raccourcit, contre du bois).
- **Contre-jeu** : l'adversaire peut harceler les ouvriers éloignés ou s'emparer des gisements du centre.
- **Validation** : R01 (changement de priorité → 5 ouvriers réaffectés), R02 (épuisement → recherche, pénurie
  explicite, réaffectation, reprise après exploration), R02b (îlot visible mais inaccessible ignoré).

## F2 — Passage d'âge I → II

- **Choix** : quand investir 400 nourriture + 200 bois et 35 s, plutôt que des ouvriers ou des soldats.
- **Information** : bouton d'âge avec état « prêt », panneau détaillant coût (OK/insuffisant), objectif (atteint ou non),
  manques chiffrés et astuce d'exploration ; refus d'ordre motivé.
- **Coût / risque** : ressources immobilisées, éclaireur exposé pendant l'exploration.
- **Contre-jeu** : tuer l'éclaireur, contester le comptoir, attaquer pendant le passage.
- **Validation** : R03 (ressources seules : refus « objectif » ; objectif seul : refus « manque … » ; les deux : passage),
  R03b (l'IA passe seule, le joueur reste à l'âge I).

## F3 — Ouvertures de l'âge II : commerce ou assaut précoce

- **Choix** : investir dans un relais marchand (120 bois) + marché (170 bois, 40 minerai) + caravanes (60/60 chacune)
  ou dans une seconde caserne et une armée de tireurs/cavaliers.
- **Information** : comptoirs découverts sur la carte et la mini-carte, gains des caravanes affichés, taux d'échange,
  messages « relais détruit » et « route commerciale coupée ».
- **Coût / risque** : commerce = ≈ 650 ressources avant le premier gain, relais isolé et caravanes sans défense ;
  assaut = ouvriers et économie en retard si l'attaque échoue.
- **Contre-jeu** : contre le commerce, raid de cavaliers sur le relais et les caravanes ; contre l'assaut, défense
  déléguée près du centre (le centre tire), lanciers contre cavaliers, repli derrière la rivière.
- **Validation** : R07 (commerce sans pression : revenu cumulé 9 353 contre 4 746 à 14 min, dont 4 621 de commerce),
  R08 (assaut précoce contre commerce sans armée : relais détruit à 5 min 30, 47 pertes infligées contre 21 subies).
  Voir `ouvertures.md`.

## F4 — Escouades, délégation et ordre direct

- **Choix** : commander une escouade, une unité seule, ou déléguer la défense d'un secteur à l'armée.
- **Information** : numéros d'escouade au-dessus des troupes, liste des escouades avec rôle (« Réserve », « Poste n »,
  « Interception », « Ordre direct »), cercle du secteur délégué, panneau indiquant le niveau de contrôle.
- **Coût / risque** : une escouade reprise en main n'est plus redistribuée par l'armée tant qu'elle n'est pas rendue.
- **Contre-jeu** : l'adversaire peut attirer l'armée déléguée hors de position ou attaquer deux points.
- **Règle** : ordre direct à une unité > ordre direct à son escouade > délégation. « Rendre à l'escouade » /
  « Rendre à l'armée » rétablit le niveau inférieur.
- **Validation** : R04 (16 assertions), `touch_test.gd` (gestes).

## F5 — Conquête

- **Choix** : viser le centre, puis les ouvriers et dépôts qui permettraient de le rebâtir ; ou protéger un ouvrier et
  des moyens pour survivre à la perte du centre.
- **Information** : messages de destruction et d'élimination avec la cause ; le débogage IA montre les cibles.
- **Règle provisoire** : D-07 (arbitrage demandé).
- **Validation** : R05, R05b, R05c, R05d, R10 (partie IA contre IA conclue par élimination en 41 min 24, graine 2001).

## F6 — Exploration et brouillard de guerre

- **Choix** : où envoyer l'éclaireur (comptoirs, gués, base ennemie).
- **Information** : brouillard en trois états (inconnu noir, exploré assombri, visible) ; structures ennemies mémorisées.
- **Coût / risque** : éclaireur isolé ; l'IA ne voit que ce que son camp voit.
- **Validation** : R03 (découverte), R03b (l'IA découvre par exploration), R06 (cible IA issue de sa mémoire).

# Fiches de design — mécaniques majeures J2

## F7 — Passage d'âge II → III « Forteresses »

- **Choix** : quand investir 700 nourriture, 450 bois, 300 minerai et 45 s, et où s'implanter près d'un gué.
- **Information** : bouton « Âge II → III (prêt) », panneau avec coût, objectif « Achever un bâtiment à moins de
  9 cases d'un gué » (astuce : une palissade suffit), manques chiffrés, liste de ce que l'âge débloque.
- **Coût / risque** : grosse dépense en minerai ; le bâtiment de l'objectif est exposé près de la rivière.
- **Contre-jeu** : détruire le chantier près du gué, attaquer pendant le passage.
- **Validation** : R14 (canon refusé avant l'âge III ; ressources seules / objectif seul refusés avec cause ;
  les deux : passage ; adversaire indépendant).

## F8 — Fort et palissades : tenir un passage

- **Choix** : fermer un gué (ligne de palissades à 25 bois la case), le couvrir d'un fort (250 bois + 250 minerai),
  ou garder la mobilité.
- **Information** : palissades et fort visibles et mémorisés sous le brouillard ; PV en sélection ; messages de
  destruction ; l'IA annonce « passage bloqué par Palissade — siège ».
- **Coût / risque** : ressources immobilisées ; un fort mal placé laisse un bout du gué hors de portée (8 cases) ;
  fermer un gué peut aussi bloquer sa propre contre-attaque.
- **Contre-jeu** : artillerie (portée 9 > portée du fort 8), autre gué, cavalerie contre les canons adverses.
- **Validation** : R11 (deux gués fermés et couverts : l'IA sans artillerie assiège, perd des unités sous le feu,
  abandonne après son budget de siège, réévalue « Préparer l'artillerie » ; forts intacts, aucun franchissement).

## F9 — Artillerie de siège

- **Choix** : produire des canons (atelier, 150 bois + 150 minerai, 3 pop.) et choisir où les mettre en batterie.
- **Information** : état « mise en batterie (n %) », fût qui se relève, boulet en cloche, fumée et impact ;
  « cible trop proche : recule » sous 3 cases.
- **Coût / risque** : lent (1,3), 3 s d'arrêt avant chaque premier tir, faible contre les unités (×0,25),
  vulnérable au contact et aux cavaliers (×2,5).
- **Contre-jeu** : sortie de cavaliers, tireurs, fort qui tire sur l'escorte, autre passage.
- **Validation** : R16 (batterie visible à 1,5 s ; aucun tir avant 3 s ; 210 dégâts au premier tir sur une maison ;
  lancier au contact → recul), R12 (siège qui ouvre un gué fermé, puis franchissement).

## F10 — Routes : siège ou autre accès (IA et armée déléguée)

- **Choix (IA)** : attaquer par la route directe, faire un détour par l'autre gué, ou assiéger la structure qui bloque.
- **Information** : débogage IA — « route : directe », « route alternative : détour de N % », « passage bloqué par X —
  siège », « passage ouvert, reprise de la marche », causes d'abandon. Délégation : rôles « Poste n (autre accès) » ou
  « (repli, accès bloqué) ».
- **Coût / risque** : un détour allonge l'exposition ; un siège sans artillerie coûte des unités sous le feu.
- **Contre-jeu** : fermer aussi le second gué, couvrir les palissades par un fort, intercepter l'artillerie.
- **Validation** : R12 (siège puis franchissement), R13 (gué sud-est fermé, gué nord-ouest ouvert : détour annoncé,
  pas de siège inutile, cible détruite), R15 (armée déléguée qui rejoint son secteur par l'autre gué).

## F11 — Essai technique deux fronts (hors jeu normal)

- **But** : mesurer deux cartes actives sur Android ; une seule affichée.
- **Conditions** : front A « siège du gué sud-est » (graine 3101 : fort + ligne de palissades contre canons, lanciers,
  cavaliers), front B « bataille du gué nord-ouest » (graine 3202 : deux armées IA). Charges 40 / 100 / 200 / 400 unités
  par front (ouvriers et éclaireurs compris). Toutes les unités gardent position, ordre et combat individuels.
- **Validation** : invariance A/B/C (sans vue, bascule toutes les 100 ticks, bascule tous les 37 ticks avec les deux vues
  synchronisées) + contrôle négatif ; mesures physiques S25 Ultra (NOT_RUN).
