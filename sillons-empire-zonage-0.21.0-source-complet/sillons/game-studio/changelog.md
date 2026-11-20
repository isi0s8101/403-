# 0.20.0 — zonage dynamique, LOT B — 2026-11-20

- Filtres de la carte : zonage, population, densité, criminalité, prospérité, production, pollution, état, incidents, infrastructures ; bouton « Filtre » du mode Zones (un toucher par filtre) et vues du panneau Ville ; teintes lisibles par-dessus les bâtiments ; filtre « Zonage » hors du mode.
- Événements urbains extensibles (`sim/urban_events.gd`, décrits par des données) : séisme, inondation, tempête, crise économique, vague de migration, exode ; tirage déterministe, délai de grâce de 15 minutes, sauvegardés ; mêmes règles pour l'IA ; commande de recette `lab_urban_event`.
- Villes à plusieurs échelles : ville détaillée dans le monde affiché, calcul abrégé ailleurs (une période sur 3, durées et probabilités ajustées : `UrbanCity.time_scale`) ; résumés d'une ville et de toutes les villes du camp (`sim/urban_abstract.gd`), section « Toutes vos villes » du panneau Ville.
- Calcul réparti : camps calculés à des ticks différents, mondes décalés (`urban_phase`) ; accès à la route gardé pour le tick (coût au carré supprimé : ville de 136 bâtiments 15–16 ms → 9–11 ms sous Linux) ; outil `tools/profile-urban.gd`.
- IA : petit quartier zoné dès l'âge I avant l'électricité, sur ses surplus, mêmes commandes ; réserve des routes selon ce qu'elles coûtent à l'âge.
- Architecture : une palette par âge et une toiture d'époque (chaume, bois, pierre, colombages, brique, brique industrielle, béton, panneaux solaires, toits jardins, anneau lumineux) ; capture des 10 âges.
- Godot 4.7.2 Linux : 64 scénarios (nouveau `urban_lotb`, 36 vérifications ; `ui_zoning` 34) ; `urban_city` A01 adapté (raison écrite) ; Android NOT_RUN.

# 0.19.0 — zonage dynamique : la ville se construit seule (LOT A) — 2026-11-19

- Audit avant modification (`AUDIT-ZONAGE-0.18.1.md`) ; décisions de l'auteur : zonage dès l'âge I à côté de la récolte, pose manuelle des zones remplacée (parties 0.18 converties), routes ajoutées.
- Zonage par camp (`sim/urban_zoning.gd`, sauvegardé) : habitat bas / moyen / dense, commerce, industrie, agricole ; codes réservés aux zones spécialisées futures ; routes payées selon l'âge, reliées au centre ; commandes validées par la simulation (`zone_paint`, `zone_clear`, `road_paint`, `road_remove`, `zone_historic`), refus sans effet (territoire, eau, autre camp, règles historiques).
- Croissance organique (`sim/urban_growth.gd`) : parcelles 2 × 2 à 2 cases d'une route reliée, demande par catégorie tirée de l'économie réelle, chantiers sans ouvrier payés en ressources, refus sans route, sans ressources, sans demande, avec un ennemi proche ou une criminalité forte ; niveaux automatiques payés (plafonds par zonage et par âge, services exigés) ; densification ; architecture de l'âge de construction, transformation progressive, quartiers historiques ; états persistants ; ruines et reconstruction ; agglomération classée.
- Avant l'électricité : puits (eau, lutte contre le feu), garde de la caserne et du fort (sécurité), production réduite ; les habitants mangent (famine possible).
- Criminalité (pauvreté, chômage, services, ennemi proche) : vols, pillages, dégradation, départs, émeutes (dégâts limités), fin par l'armée ou la police. Incendies : intensité, matériaux selon l'âge, cycle sec / humide, propagation, pompiers reliés par la route, fumée et flammes.
- IA : routes et zones selon sa demande, mêmes commandes, aucun privilège.
- Interface : bouton « Zones » (Bâtir), barre compacte (types, pinceau 1 à 3, rectangle, parcelle, inspecter, annuler, fermer, demande), calque coloré seulement dans ce mode, fiche de quartier, « Conserver l'architecture », conseils « Zoner : … » du panneau Ville ; routes et calque dessinés par le terrain ; modèles composés selon catégorie, niveau, âge et état (`game/urban_visual.gd`) ; portrait.
- Correctifs trouvés en recette : routes peintes invisibles tant que la partie était en pause ; libellé du bouton actif coupé ; fiche de quartier disant « route reliée : non » quand toutes les parcelles étaient bâties ; portraits manquants du puits, de l'exploitation agricole et des ruines (fiche et catalogue).
- Godot 4.7.2 Linux : 63 scénarios (nouveaux `zoning` 79 vérifications et `ui_zoning` 26) ; `urban_city` et `ui_city` adaptés (raison écrite) ; Android NOT_RUN.

# 0.18.1 — correctifs vus sur téléphone — 2026-11-19

- Capture de l'auteur sur Android en portrait : le bouton d'ajout à la sélection affichait un carré « FF0B » (le « ＋ » pleine chasse n'existe pas dans les polices livrées, et Android ne fournit pas de police de secours) ; la mini-carte était étirée sur la hauteur de la colonne de boutons.
- Tous les symboles des textes d'interface sont désormais pris dans les polices livrées (Fira Sans) : 33 caractères remplacés (+, ×, ←, ∞, ‖, √, †, ◊, ↑, ↓…), bouton « lecture » dessiné (`game/icons/play.svg`), textes « oui / non » dans la fiche des zones, thème neutre des menus en Fira Sans, étiquettes 3D en Fira Sans.
- Nouveau contrôle `tools/check-glyphs.gd`, ajouté à `verify-refonte.sh` (étape REFONTE_GLYPHS) : tout caractère d'interface absent des polices fait échouer la vérification.
- Mini-carte carrée dans les deux sens (108 points en paysage, 188 en portrait) ; toucher la mini-carte vise toujours le bon endroit.
- `ui_portrait` : 44 vérifications (mini-carte carrée, bouton « + », toucher de la mini-carte).

# 0.18.0 — la ville de l'âge de l'électricité, et le jeu en portrait — 2026-11-19

- Audit avant modification (`AUDIT-URBAIN-0.17.0.md`) ; décisions de l'auteur : recherche « Électricité » à l'usine dès l'âge IV, remplacement net, aucun contenu repris d'un jeu existant.
- Nouvelle recherche « Électricité » : maisons converties en zones d'habitation (habitants conservés), fermes arrêtées, récolte arrêtée après dépôt de la charge ; maison, ferme et entrepôt ne se construisent plus. Nouvelles campagnes seulement : escarmouches historiques, laboratoire et anciennes sauvegardes inchangés.
- Zones habitation / commerce / industrie à 3 niveaux et densité qui évolue avec le bien-être ; population d'unités liée aux habitants logés (4 habitants = 1 place) ; commerce → nourriture et bois, industrie → minerai.
- Réseaux électrique (centrale, centrale solaire, postes en chaîne) et d'eau (château d'eau, station de pompage) avec délestage par priorité ; services à rayon et capacité (commissariat, pompiers, hôpital, décharge, recyclage).
- Criminalité (vols sur la production), incendies (dégâts, destruction, propagation), santé et épidémies, pollution, eau, électricité, bien-être général qui règle productivité et croissance ; tirages déterministes (partie reproductible) ; garde-fous anti-blocage autour du centre.
- IA de la ville avec les mêmes commandes et les mêmes conditions que le joueur.
- Interface : panneau Ville (facteurs, réseaux, production, incidents, conseils avec « Placer »), vues au sol (électricité, eau, sécurité, pompiers, santé, pollution, bien-être), rayon d'action pendant la pose, fiche de zone avec amélioration, alertes, modèles 3D existants, flammes.
- Paysage et portrait : orientation capteur, base d'échelle choisie selon le sens de l'écran (textes et boutons de même taille), HUD tactique en portrait (commandes en bas sous le pouce, panneaux en pleine largeur, vue plus plongeante), menus, globe, système, galaxie et orbite adaptés, bascule sans fermer les panneaux ; échelle 130 % ramenée à 115 % en portrait.
- Godot 4.7.2 Linux : contrôles statiques (17 suites, dont `verify-urbain-static.py`), compilation de tous les scripts et 61 scénarios (dont `urban_city`, `ui_city`, `ui_portrait`) ; recettes `modern_ui` (rangée de pose trop longue) et `ui_theme` (échec aléatoire de la cérémonie) rendues robustes ; Android et Galaxy S25 Ultra NOT_RUN.

# 0.17.0 — interface et commandes de niveau « grand RTS », thème qui suit l'âge — 2026-11-19

- Sélection au pouce : double appui (tous les mêmes à l'écran), rectangle sans bouton (glisser depuis une unité, ou appui long puis glisser), sélection additive, barre de sélection par type, boutons Inactifs / Armée / Héros.
- Six groupes de contrôle (appui long = enregistrer, toucher = rappeler, double toucher = centrer), enregistrés avec la sauvegarde.
- Carte de commandes contextuelle et menu circulaire enrichi ; bouton « Enchaîner » : files d'ordres A → B → C (16 étapes, militaires, ouvriers, éclaireurs), visibles au sol, modifiables (déplacer, supprimer, insérer, annuler, vider, boucle), suivies en groupe avec attente des retardataires, étape impossible sautée avec alerte, ordres possibles en pause active.
- Nouvelles commandes simulées (pas fixe, validation, refus sans effet, sauvegarde, mêmes conditions pour l'IA) : arrêt, tenir, postures, formations orientées, repli, garnison, réparation, ordres manuels aux ouvriers (bâtir, récolter, déposer, automatique), démolition, cible prioritaire, suivre, exploration automatique, production répétée, ralliement sur ressource, annulation d'un élément précis de la file.
- Production ×5, appui maintenu, production répétée, file annulable élément par élément, production globale ; pose en ligne et multiple, raison du refus écrite sur le fantôme ; bouton « Monument ! » sur la barre d'âge.
- File d'alertes cliquables regroupées, signaux d'attaque sur la mini-carte, barre de héros, barre de pouvoirs avec aperçu du rayon au sol, barres de vie, suivi caméra, revenus par minute.
- Dix habillages d'interface (pierre et bois à l'âge I … application « next-gen » irisée à l'âge X) : jetons de style, polices libres (Fira Sans, Cardo, Anonymous Pro), textures 9-tranches et sons générés par code, micro-interactions, compteurs animés, cérémonie de passage d'âge non bloquante ; contraste WCAG mesuré ≥ 4,5:1 à chaque âge.
- Réglages : thème (suit l'âge ou fixe), sons, vibrations, main gauche, échelle de l'interface, réduire les animations.
- Godot 4.7.2 Linux : contrôles statiques, compilation de tous les scripts et 58 scénarios ; Android et Galaxy S25 Ultra NOT_RUN.

---

# 0.13.5 — priorité réalisme — 2026-11-14

- 57 modèles supplémentaires préparés dans un paquet natif : architecture, figures articulées et nature.
- Matériaux photographiques PBR CC0, réglages de mipmaps conservés et shaders de terrain/eau revus.
- Feuillage et herbe animés ; ressources connues compactées avant soumission au rendu.
- Éclairage revu ; globe 1024 × 512 progressif, nuages et atmosphère.
- Recette graphique supplémentaire, comparaison de captures, sources Blender et GLB fournies.
- Simulation préservée ; vérifications Linux ; Android et APK non exécutés.

---

# 0.13.4 — correctif d’import Android — 2026-11-14

- Sources GLB intégralement conservées hors du projet jouable pour éviter leur import sur téléphone.
- Bibliothèque native prête à charger : 800 modèles, 2 400 scènes autonomes et 174 images avec mipmaps dans un paquet PCK.
- Chargement à la demande, matériaux, collisions, LOD et animations conservés ; aucun changement de simulation.
- Outil de préparation sur ordinateur, vérification du paquet depuis un jeu autonome, recette native et guide Android.
- Godot 4.7.2 Linux : 33 scénarios PASS ; import vierge sans GLB ; appareil Android et APK NOT_RUN.

---

# 0.13.3 — refonte de présentation et optimisation mobile

- Menu principal simplifié, laboratoire préservé, thème commun et icônes vectorielles.
- Panneaux de colonie à onglets, calques de services et repères R/C/I.
- Retours Android/Échap, nettoyage des gestes annulés et protection modale des boutons.
- Bibliothèque GLB sur le terrain, stations et transports ; animations proches et LOD statiques.
- Géométrie fusionnée par matériau, lots régionaux pour les unités éloignées, caches bornés.
- Profils de résolution 3D/ombres et adaptation à la charge, sans changement du tick logique.
- Terrain PBR 512 px, éclairage revu, globe texturé progressivement et cache de trois planètes.
- Fuite d’un nœud graphique de terrain corrigée ; preuves de laboratoire écrites sous user://.
- Simulation préservée ; 32 scénarios Godot PASS ; Android NOT_RUN.

---

# 0.5.0 — J3–J5 — 2026-11-09

Âges IV–VIII, 10 unités, 8 bâtiments, 4 technologies, industrie, sauvegardes versionnées, logistique, trains, aéronefs, missiles, interception, brouillage, IA et interface. Base : archive 0.2.3 fournie. Statut candidat, essais Android non réalisés. Détails : `../README-J345.md`.

## J2.1 — 0.2.1-j2.1-ui-touch (candidat non validé) — 2026-11-09

- HUD tactique compact sombre/turquoise, mini-carte escamotable, liste d'escouades repliable, barre d'actions défilante.
- Menu principal remaquetté sans retirer les entrées labo, mesure ou escarmouche.
- Sélection multiple par rectangle explicite ; menu contextuel « Marcher / Assaut / Cibler ».
- Caméra : inertie de glissement, zoom progressif, rotation + pan à deux doigts et transition mono-doigt contrôlée.
- Nouveau test `lab/ui_j21_test.gd` et recette Galaxy `game-studio/J21-mobile-ui.md`.
- Règles/IA/économie/simulation inchangées ; compilation et tests Godot à réaliser.

# Changelog

## 0.2.0-j2 — jalon J2 (départ : 0.1.0-j1, non approuvée)

- Âge III « Forteresses » : coût et objectif configurables (objectif provisoire « tenir un gué »), panneau d'âge
  générique (I→II→III), plafond d'âge par scénario (`max_age`).
- Palissade (âge II, constructible sur un gué), fort (âge III, tire à 8 cases), atelier de siège, canon de siège
  (mise en batterie 3 s, portée minimale 3, ×3 contre bâtiments, recul au contact). Modèles 3D, boulet en cloche,
  fumée et impact ; états lisibles dans le panneau de sélection.
- Conquête : minuteur de reconstruction (D-07 approuvé), 180 s provisoires, annonce du délai.
- IA : rapport de route (directe, détour, bloquée), identification de la structure qui bloque, siège puis reprise de
  la marche, budget de siège sans artillerie puis « Préparer l'artillerie », route alternative par l'autre gué,
  palissade près du gué, atelier, fort et canons à l'âge III, ralliement au fort.
- Armée déléguée : poste de repli quand l'accès est bloqué, « autre accès » signalé.
- Simulation : budget de 24 recherches de chemin par tick (pics ÷ 4,4), grille spatiale pour la recherche de cibles
  (résultat identique) ; réémissions d'ordres identiques évitées dans l'IA.
- Essai technique deux fronts : `Theater` (deux simulations au même pas fixe), écran de mesure (une carte affichée,
  bascule, niveaux 40/100/200/400, protocole automatique, JSON), test d'invariance avec contrôle négatif,
  comparaison de réglages.
- Laboratoire : 7 nouveaux scénarios (R05e, R11 à R16), nouvelles vérifications (`count_side`, `building_hp`,
  `building_alive`, `squad_role_sub`), commande `lab_block_ford`, groupes de charge `scalable`.

## 0.1.0-j1 — jalon J1 (projet neuf)

- Projet Godot 4.4.1 initialisé (rendu Mobile, paysage, Android arm64).
- Simulation déterministe : carte « Val des Deux Gués », brouillard à trois états, ouvriers avec priorités et
  réaffectation automatique, gisements épuisables, fermes, entrepôts, construction, production, population.
- Âges I Exploration et II Commerce : passage avec coût + objectif provisoire (comptoir neutre).
- Âge II : tireurs, cavaliers, marché, relais marchand, caravanes, échanges.
- Escouades, sélection individuelle, reprise en main, défense déléguée d'un secteur, rendre la main.
- Combat avec bonus de rôle, tir défensif du centre, règle de conquête complète (capacité de reconstruction provisoire).
- IA adverse sur informations propres : économie, exploration, passage d'âge, choix d'ouverture, défense, attaque,
  réévaluation après échec ou passage bloqué, état exposé.
- Interface tactile, mini-carte, messages de cause, panneau de passage d'âge, menu pause, mesures, débogage IA.
- Laboratoire : 16 scénarios, rejeu d'ordres, assertions, exécution sans rendu, mode visuel depuis le menu.
- Zone témoin avec mesure de rendu enregistrée.

### J2.1 FIX1 (Godot 4.7.2)

- Correction des trois erreurs `Cannot infer the type` dans `lab/ui_j21_test.gd` (lignes 32, 44 et 62).
- Typage explicite de `original: bool`, `initial_squads: Array` et `selection_squads: Array`.
- Renommage des variables des branches du test pour éviter toute ambiguïté de portée.
- Ajout de gardes statiques anti-régression, sans modification de `sim/` ni des commandes tactiles.
- Compilation et exécution sous Godot : **à valider sur appareil**.


## 0.2.2 — J2.1-C (candidate, vérification Godot/Android non exécutée)
- Import de 5 textures PBR originales et d'un mélange terrain/berges/brouillard sans modifier la simulation.
- Matériau de rivière amélioré, éclairage et palette de ciel ajustés, feuillages d'arbres revisités.
- Deux `MultiMesh` de décor par front, respectant visibilité et occupation, cachés en vue lointaine.
- Script `lab/visual_j21c_test.gd` et tests statiques ; retour arrière sur FIX1 documenté.

## 0.2.3-j2.1def-visual — candidate non validée (2026-11-09)
- J2.1-D : rigs procéduraux à bras/jambes articulés pour les unités de proximité, démarche liée à la vitesse, équipements par rôle ; fallback J2 au LOD.
- J2.1-E : détails architecturaux, marques de santé et fissures sur bâtiments, ruines animées, impacts de canon bornés.
- J2.1-F : profils graphiques économie/équilibré/détaillé et aide tactile, indicateurs de budget d'effets et de rigs, retour d'erreur sur ordre rejeté.
- Vérification : scripts statiques et lab headless fournis, mais compilation / mesures Android NOT_RUN.
- `sim/` identique à la baseline J2.0 ; J2.1 FIX1 dernière version validée par retour utilisateur.


## 0.8.2 — Correctifs d’audit, candidate (2026-11-09)

Correction des 11 anomalies de code de l’audit 0.8.1 : schéma vol complet, reprise backup, recette isolée par exécution, alertes des secteurs, IA symétrique, choix d’embarquement, interception par croisement, contrôle population, réservation coloniale, copie JSON Android et benchmark réel de vitesse. Tests de régression enrichis (tests Godot non exécutés). La qualification Android reste PENDING.

## J10 — 0.10.0 candidate

- Catalogue astronomique déterministe (Sol et Proxima, planètes/lunes), chargement tactique paresseux des nouvelles destinations.
- Passage du zoom planétaire vers les vues orbitale et stellaire, navigation retour et UI tactile de planification des convois.
- Sauvegarde des mondes supplémentaires, validation des graines et des trajets, compatibilité de lecture des instantanés 0.9.1.
- Tests J10 moteurs/UI, audits J1–J9 préservés, scripts d'export à condition de validation réelle Godot.
- **Pas de compilation, APK ou essais matériels dans l'environnement de livraison.**

## J13 — 0.13.0 candidate (2026-11-13)

- Première version **importée et exécutée dans Godot** (4.7.1 headless) : 4 défauts de la 0.12.3 et 3 recettes fausses corrigés, toutes les recettes J1–J12 passent.
- Colonies à âge local (naissance à VII), stocks manufacturés par planète, trésorerie impériale à écritures, transports auditables.
- Districts d'aire égale, zonage R/C/I, population, industrie, commerce, eau, électricité, santé, police, pompiers par graphe et capacité.
- Gouverneur civil à l'âge X local ; stations de commandement multiples et verrou orbital des débarquements, appliqué aussi à l'IA.
- Bloc de sauvegarde `j13` validé, migration 0.12.3 sans crédit ni station ajoutés.
- **Export Android et recette S25 Ultra : NOT_RUN.** Ville 3D (lot J13-G) non livrée.

## J13.1 — 0.13.1 candidate (2026-11-13)

- Chaîne d'approvisionnement sur les nouvelles parties : les unités prélèvent des habitants des zones d'habitation ; dès l'âge IV, troupes et bâtiments consomment les matériaux des zones industrielles.
- Intendant civil pour les camps pilotés par l'IA, gouverneur plus robuste (repli sur le zonage, zones inconnues ignorées), eau et électricité sans crédits.
- Panneau de colonie : niveaux supérieurs (immeubles, centre commercial, complexe) et stocks fabriqués.
- Recette `j13_supply_test` ; **export Android et recette S25 Ultra : NOT_RUN.**

## J13.2 — 0.13.2 candidate (2026-11-13)

- Bibliothèque de 800 modèles 3D (`assets_3d/`, 3 niveaux de détail) et chargeur `AssetLibrary`.
- Vue planétaire : zones R/C/I, équipements et routes de la colonie affichés en 3D sur le globe, au modèle de l'âge local.
- Recettes `assets_3d_test` et `j13_globe_test` ajoutées à `verify-j13.sh`. **Android : NOT_RUN.**

## 0.16.0 — Évolution de la civilisation (candidate, 2026-11-18)

- Base 0.15.1 R2 auditée (manifeste exact, 50/50 scénarios reproduits, APK non reçu, Android NOT_RUN).
- Voies marchande / militaire / savante aux âges II, V et VIII : bonus et une unité spéciale par voie (9 unités).
- Passage d'âge par monument : deux monuments au choix par âge (18), bonus tant qu'il est debout.
- Forge et onze lignes d'améliorations à trois niveaux ; trois héros uniques avec aura et rappel ;
  points et six pouvoirs de commandement en trois rangs.
- IA : choix de voie, monuments, forge, améliorations, héros, déblocage et usage des pouvoirs.
- Panneau « Civilisation », cartes de la fiche des bâtiments, ciblage tactile des pouvoirs.
- Commerces J13 : 400 vivres gardés en réserve. Recettes civ_evolution et civ_ui ; 52 scénarios.
