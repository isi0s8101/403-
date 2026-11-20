# Sillons d'Empire — J13 — 0.13.2 (candidate) — Colonies, économie planétaire, verrou orbital

Source complète dérivée de la 0.12.3, sans suppression de fichier historique. Référence : `CADRAGE-INTEGRAL-EXPERT-V3.0`.
Cette version a été **réellement importée et exécutée dans Godot 4.7.1 (headless, Linux)**. Elle n'a **pas** été exportée ni testée sur Android : voir `game-studio/J13-validation.md`.

## Nouveau dans la 0.13.2 — la colonie en 3D sur le globe

- La vue planétaire affiche la colonie avec les modèles de la bibliothèque `assets_3d/` (800 modèles, voir `assets_3d/README.md`) :
  quartiers d'**habitation, de commerce et d'industrie** au modèle de l'**âge local**, en groupes de 3 à 5 bâtiments selon la densité ;
  commandement (à la couleur du camp), centrale, station d'eau, hôpital, pompiers, police ; routes de l'époque et ponts sur l'océan.
- L'affichage relit la colonie toutes les 0,7 s et ne se reconstruit que si elle a changé. Il ne modifie jamais la simulation
  (vérifié par empreinte d'état). Seule la colonie du joueur est montrée.
- Fichiers : `views/planet_globe_view.gd` (`show_districts`), `game/asset_library.gd`, recettes `lab/j13_globe_test.gd` et
  `lab/assets_3d_test.gd`. Image de contrôle : `game-studio/preuves/j13/globe-districts-age-x.png` (rendu OpenGL **logiciel**
  sur serveur, pas sur Android).
- Pas encore fait : modèles 3D sur la carte tactique (unités, bâtiments), calques (énergie, eau, secours), vue orbite.

## Nouveau dans la 0.13.1 — chaîne d'approvisionnement

Sur toute **nouvelle partie** (réglage `GameConfig.supply_chain`, activé par défaut ; les parties migrées et les recettes historiques gardent les règles 0.13.0) :

- **Habitation → troupes et colons.** Former une unité (soldat, ouvrier, colon) retire ses habitants de la population de la colonie. Sans habitants logés, pas de troupe. Le monde fondateur démarre avec 12 habitants ; les maisons, puis immeubles et tours (densité 2 et 3) font grandir la réserve.
- **Industrie → troupes et bâtiments.** En plus du coût historique : unités d'âge IV+ : 2 alliages par habitant ; âge VI+ : + 1 carburant ; âge VIII+ : + 1 électronique. Bâtiments d'âge IV+ : béton (surface au sol) ; âge VI+ : + alliage ; âge VIII+ : + électronique. Les âges I à III ne demandent que des habitants.
- **Commerce → bénéfices.** Petits commerces, marché, centre commercial (densité 1 à 3) : inchangé, les bénéfices nets remontent à la trésorerie de l'empire.
- **IA.** Un camp piloté par l'IA confie ses zones à un intendant dès le départ (mêmes coûts, mêmes règles) : logements et commerces d'abord, secours quand les crédits le permettent.
- Eau et électricité ne coûtent plus de crédits (matériaux seulement), pour qu'une colonie sans crédit ne soit jamais bloquée. Le panneau de colonie gagne les boutons ▲ (niveau supérieur) et l'affichage des stocks fabriqués.
- Le gouverneur ne gèle plus tout quand un équipement est trop cher : il poursuit par le zonage et retente plus tard.

Fichiers : `sim/colony_gate.gd`, tables `unit_needs` / `building_needs` dans `sim/j13_rules.gd`, recette `lab/j13_supply_test.gd` (22 vérifications dont une partie IA contre IA de 9 000 ticks).
Limite connue : annuler une formation en file rend le coût historique mais pas encore les habitants ni les équipements.

## Ce que J13 ajoute

| Lot du cadrage | Livré dans la 0.13.0 | Fichiers |
|---|---|---|
| J13-0 | Import Godot réel, recettes J1–J12 exécutées, 4 défauts hérités corrigés | voir « Défauts 0.12.3 corrigés » |
| J13-A | Âge **local** par colonie ; une colonie fondée naît à l'âge VII ; renforts X utilisables sans débloquer la production locale | `sim/planet_campaign.gd` |
| J13-B | Stocks de biens manufacturés **par planète**, dépôt de base par système (inchangé), trésorerie impériale à écritures, transports auditables | `sim/planet_campaign.gd`, `sim/j13_rules.gd` |
| J13-C | 72 districts d'aire égale par planète, zonage R/C/I, densité, population, emplois, recettes industrielles, commerce | idem |
| J13-D | Routes et liaisons maritimes, eau, électricité, hôpitaux, police, pompiers : couverture par **graphe routier et capacité** | idem |
| J13-E | Gouverneur civil à l'âge X local, jusqu'à 100 % du périmètre éligible | `sim/planet_governor.gd` |
| J13-F | Stations de commandement multiples, verrou orbital des débarquements, siège par l'IA | `sim/planet_campaign.gd`, `sim/orbital_industry.gd` |
| J13-G | **Partiel (0.13.2)** : bibliothèque de 800 modèles, districts en 3D sur le globe, tableau de colonie tactile ; pas encore de modèles sur la carte tactique ni de calques | `assets_3d/`, `views/planet_globe_view.gd`, `views/colony_panel.gd` |
| J13-H | Recette J13 (128 vérifications) + lanceur `verify-j13.sh` ; APK et recette S25 Ultra **non exécutés** | `lab/j13_colony_test.gd`, `lab/j13_ui_test.gd` |

## Règles en jeu

**Âge local.** Le monde fondateur (et les mondes déjà tenus dans une partie migrée) suit l'âge du camp. Une colonie fondée après J13 démarre à `min(âge du camp, VII)`. Sur une colonie, le terrain tactique, le chantier naval et les recettes n'utilisent que l'âge local. Passage VII→VIII→IX→X par `advance_colony_age` : industrie locale, matériaux locaux, crédits, réseau électrique (IX), station orbitale locale (X), puis un délai. Une frégate importée reste utilisable ; elle ne débloque rien.

**Districts.** Chaque planète est découpée en 12 × 6 districts de même surface (bandes à `sin(latitude)` uniforme). Le masque (océan, constructible, relief, réserve naturelle) vient de la graine et n'est jamais sauvegardé. Périmètre « 100 % » = constructible, accessible depuis le commandement, non protégé, non réservé par le joueur, non tenu par l'adversaire. L'océan se traverse par une liaison maritime payante mais ne se bâtit jamais.

**Zonage.** Cible R/C/I réglable (somme 100 %, chaque part entre 5 % et 90 %), 4 préréglages. Le ratio ne compte que les districts zonés, pas les services. Densité 1 à 3 selon l'âge local.

**Économie.** Par tranche de 20 ticks : vivres consommés dans le dépôt du système ; les soldats présents sur le monde sont retirés de la main-d'œuvre ; une usine sans électricité, eau, personnel ou intrants ne produit rien et affiche la cause ; un commerce ne vend qu'un produit réel (biens manufacturés, sinon vivres) à des clients employés. Aucune recette ne sort plus qu'elle ne consomme.

**Services.** Eau et électricité : capacité réelle sur le réseau relié, délestage par priorité (commandement, hôpital, eau, pompiers, police, habitat, industrie, commerce). Hôpital, police, pompiers : un district est desservi s'il est joignable par la route, dans le temps de trajet, et si le poste a encore la capacité. Une route coupée interrompt réellement le service.

**Trésorerie.** Les crédits naissent des ventes dans la réserve locale ; tous les 200 ticks, ce qui dépasse la réserve d'exploitation (50) est viré à la trésorerie impériale par une écriture. Invariant vérifié à chaque chargement : trésorerie + réserves = créé − dépensé. Les matériaux ne sont jamais centralisés.

**Transports.** `transfer_materials` / `found_colony` : colons et fret retirés du départ après tous les contrôles, mission avec identifiant, origine, destination, cargaison, capacité, ETA, état, cause d'échec et `delivered_once`. Porteur : une navette réelle en orbite, sinon un lancement payant depuis un spatioport. Vivres, bois et minerai ne voyagent pas à l'intérieur d'un même système (dépôt commun).

**Gouverneur.** Accordé et activé à l'âge X local, suspendable. Tous les 100 ticks, au plus 2 actions, par les mêmes commandes que le joueur et sous un plafond de budget. Ordre : route coupée, eau/énergie, secours (dimensionnés pour des logements pleins), puis zone la plus en retard sur la cible, puis densification. Il ne démolit jamais, ne touche ni aux réserves ni aux bâtiments manuels, ne change pas le ratio, gèle l'extension si une escadre ennemie est en orbite, et s'arrête en expliquant pourquoi quand il manque quelque chose.

**Verrou orbital.** Un débarquement (convoi tactique ou transport) est refusé tant qu'une station de commandement ennemie **opérationnelle** protège le monde ; il est re-vérifié à l'arrivée. Le chantier naval 0.12.3 est la première station ; jusqu'à 2 stations supplémentaires par planète (`start_orbital_station`). Chaque vague armée attaque une station ; il faut les détruire toutes. Les troupes déjà au sol restent ; une vague en vol attend en orbite sans perte si une station est reconstruite. Exceptions : le monde fondateur d'un camp, et un monde où ce camp tient lui-même une station. L'attribution automatique du premier chantier reste réservée au monde fondateur ; une colonie doit bâtir le sien à l'âge IX local.

## Commandes (API métier unique)

`zone_planet`, `build_road`, `build_civic`, `set_zoning_balance`, `set_governor_policy`, `advance_colony_age`, `start_orbital_station`, `attack_orbital_station`, `request_hostile_landing`, `transfer_materials`, `found_colony`, `transfer_credits` — toutes dans `StarCampaign`, toutes renvoient `{ok, reason, reason_code, …}`. Un refus n'a aucun effet (vérifié par empreinte d'état).

Dans le jeu : vue planétaire (globe) → panneau **J13 · COLONIE** à droite : état, boutons de zone et de service, cible R/C/I, gouverneur, âge local.

## Sauvegarde et migration

Bloc `j13` (schéma 13) ajouté à l'enveloppe de campagne, validé champ par champ (bornes, identifiants, comptes équilibrés, transport actif jamais « déjà livré »). Une sauvegarde 0.12.3 sans ce bloc est migrée au chargement : âges conservés, stocks et chantiers inchangés, trésorerie 0, aucune station offerte. Une sauvegarde J13 n'est pas relisible par la 0.12.3 : le retour arrière est l'archive 0.12.3 avec le fichier d'avant migration.

## Défauts 0.12.3 corrigés (J13-0)

1. **Reprise non déterministe** : l'instantané partageait ses tableaux avec la partie vivante (`save_game.gd`, `campaign_save.gd`) → copies profondes.
2. **Couture de longitude** : le bord est du dernier secteur et le bord ouest du premier ne donnaient pas la même hauteur (`planet_generator.gd`).
3. **Délégation « défendre » impossible sur Sol**, toujours contesté au départ (`star_campaign.gd` → `system_held`).
4. **`TerrainChunkStreamer`** inutilisable sans `setup()` en mode régions.

Trois recettes étaient elles-mêmes fausses et ont été corrigées (`strategic_test`, `j9_planet_test`, `j12_perf_test`) : détail dans `game-studio/J13-validation.md`.

## Vérifier

```bash
cd sillons
GODOT_BIN=/chemin/vers/godot ./tools/verify-j13.sh
./tools/export-android-j13.sh      # nécessite le SDK Android et les modèles d'export : NON EXÉCUTÉ ici
```

## Limites connues

- Toutes les valeurs de `sim/j13_rules.gd` sont provisoires, non équilibrées par des parties réelles.
- Les districts sont une couche macro : ils ne sont pas encore reliés aux bâtiments posés sur la carte tactique, ni dessinés en 3D.
- Pas d'incendies ni de catastrophes, pas de pollution, pas de doctrines, pas de rail ; le temps de trajet des secours est un nombre d'étapes de district.
- L'IA assiège les stations mais ne gère pas encore le zonage de ses colonies avant l'âge X (ensuite le gouverneur s'en charge).
- Combat orbital : résolution déterministe simplifiée héritée de la 0.12.3.
