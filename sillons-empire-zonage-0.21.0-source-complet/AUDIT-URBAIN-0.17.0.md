# Audit avant la 0.18.0 — gestion urbaine à l'âge de l'électricité et jeu en portrait

Base auditée : 0.17.0 (interface « grand RTS », 58 scénarios sur 58). Godot 4.7.2.
Objet : savoir quoi **faire évoluer**, **remplacer**, **garder** ou **intégrer** avant de modifier quoi que ce soit.

## 1. Décisions prises avec l'auteur (19/11/2026)

- Déclencheur : une **recherche « Électricité »** à l'usine, possible dès l'**âge IV Industrie**. Le joueur choisit quand basculer.
- Ancien système : **remplacement net**. Une fois la recherche achevée, fermes, maisons et récolte s'arrêtent : seules les zones produisent.
- TheoTown (APK joint) : **aucun contenu repris** (images, sons, textes, code, mises en page). Seules les règles courantes du genre « city builder » servent de repère : zones habitation / commerce / industrie, services à rayon d'action, réseaux électrique et d'eau, bien-être calculé.

## 2. Ce qui existe

| Domaine | Où | Constat |
|---|---|---|
| Ressources de la carte de bataille | `sim/rules.gd` (`RESOURCES`, `GATHER_RATE`, `NODE_RES`), `sim/sim_world.gd` (`_economy`, `_update_gather`, `_find_node`) | 3 ressources (nourriture, bois, minerai) récoltées par les ouvriers sur des gisements (baies, arbres, minerai) et des fermes, rapportées à un dépôt (centre, entrepôt, marché). |
| Population | `Rules.BUILDINGS[*].pop`, `Team.pop_cap` tenu par ajout/retrait (`spawn_building`, `_complete_building`, `_destroy_building`) | Centre +10, maison +6. La population compte les **unités**. |
| Recherches | `Rules.TECHNOLOGIES`, `sim/modern_systems.gd` | Achat unique par camp, au bâtiment indiqué ; en campagne : recherche depuis le secteur Val, **partagée par tout le camp** (`StarCampaign.technologies`). |
| Évolution de la civilisation | `sim/civ_evolution.gd` (`enabled`, `visible_building`, `build_lack`) | Actif seulement dans les nouvelles campagnes (règle `civ_evolution`). Escarmouches historiques et laboratoire gardent leurs règles. |
| Zones et services | `sim/j13_rules.gd`, `sim/planet_campaign.gd` | **Déjà présents, mais sur le globe** (72 districts, colonies à partir de l'âge VII) : zones H/C/I avec densité, centrale, station d'eau, hôpital, police, pompiers, délestage par priorité. Rien sur la carte de bataille. |
| IA | `sim/ai_controller.gd` (`_economy` : maisons, fermes, entrepôts, priorités de récolte ; `_modern` : recherches), `sim/civ_ai.gd` | Mêmes commandes que le joueur. Ne sait rien d'une ville. |
| Sauvegarde | `sim/save_game.gd` | Toutes les variables de script des unités, bâtiments et camps sont enregistrées automatiquement. |
| Modèles 3D | `game/tactical_models.gd`, bibliothèque native (800 modèles) | Familles **habitation, commerce, industrie** pour les 10 âges, et **caserne de pompiers, hôpital, police, centrale, station d'eau, entrepôt** : de quoi habiller la ville sans nouveau modèle. |
| Orientation | `project.godot` : `orientation=4` (**paysage seul**), base 1280×600, `canvas_items` + `expand` | En portrait, l'interface serait réduite à 58 % de sa taille : illisible. |
| Mise en page | `game/hud.gd` : **135** positions fixées à la main ; 13 dans `strategic_hud.gd`, 11 dans `planet_start.gd`, 10 dans `main_menu.gd`, quelques-unes dans les panneaux | Tout est pensé pour un écran large. |

## 3. Ce qu'on fait de chaque système

**Remplacé (à partir de la recherche Électricité, nouvelles campagnes seulement)**
- Récolte par les ouvriers (baies, arbres, minerai, fermes) → **zones commerciales** (nourriture, bois) et **zones industrielles** (minerai). Les ouvriers déposent ce qu'ils portent puis ne récoltent plus ; ils bâtissent et réparent toujours.
- Maisons → **zones résidentielles**. Chaque maison existante est convertie en zone d'habitation (même emplacement, même capacité) : le camp ne perd pas sa population d'un coup.
- Fermes : arrêtées, signalées comme remplacées (démolissables). Maison, ferme et entrepôt ne se construisent plus.

**Évolue**
- Plafond de population : centre + bâtiments, plus **une place d'unité pour 4 habitants** logés dans les zones résidentielles.
- `build_check` / `CivEvolution.visible_building` / `build_lack` : une ligne vers le nouveau module pour masquer ou refuser selon l'électricité.
- IA : un module dédié qui bâtit et équilibre sa ville avec les **mêmes commandes**.

**Gardé tel quel**
- Escarmouches historiques, scénarios de laboratoire, sauvegardes 0.16 / 0.17, campagnes sans évolution de la civilisation : règles inchangées.
- Économie du globe (J13) : elle reste à l'échelle planétaire ; la ville est à l'échelle de la carte de bataille.
- Armée, production, passages d'âge, monuments, forge, héros, pouvoirs, commerce par caravanes.

**Intégré (nouveau)**
- `sim/urban_rules.gd` (tables, valeurs provisoires) et `sim/urban_city.gd` (simulation au pas fixe, toutes les 2 s) : zones à 3 niveaux et densité qui se développe toute seule, réseaux électrique (centrale, postes électriques en chaîne) et d'eau (châteaux d'eau), services à rayon et capacité (commissariat, pompiers, hôpital, décharge), criminalité, incendies, maladies, pollution, bien-être.
- Garde-fous anti-blocage : le centre fournit un peu d'électricité et d'eau autour de lui ; aucune règle ne retire d'unité ni de ressource déjà acquise.
- Tirages déterministes (incendies, épidémies) par hachage de la graine, du pas et du bâtiment : la partie reste reproductible et les autres tirages ne bougent pas.

## 4. Portrait

- Orientation **capteur** (paysage et portrait), base de mise à l'échelle choisie selon le sens de l'écran pour garder des textes et boutons de taille identique.
- HUD tactique : une mise en page par sens d'écran (barre du haut sur deux rangées, colonnes empilées, carte de commandes en bas), recalculée à chaque rotation sans fermer les panneaux.
- Menus, fiches, panneaux et écrans globe / orbite / système / galaxie : largeur bornée, défilement vertical, aucun élément hors écran.
- Recettes en vraie scène : 1600×740, 2400×1110, **740×1600**, **1110×2400**, tablette 2560×1600 et 1600×2560, rotation en cours de partie.

## 5. Risques

- Blocage économique au moment de la bascule (plus de récolte, pas encore de zones) → garde-fous ci-dessus, et zones peu chères.
- IA désemparée après sa propre recherche → recette dédiée : l'IA doit garder une économie qui produit.
- Coût de calcul : la ville est recalculée toutes les 2 s, sur les seuls bâtiments urbains (moins de 200 par camp).
- Lisibilité sur téléphone : vues de couverture simples (une couleur par bâtiment), fiches courtes.
