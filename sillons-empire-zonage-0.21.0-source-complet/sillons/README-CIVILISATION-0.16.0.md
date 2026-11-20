# Sillons d'Empire — 0.16.0 (candidate) — Évolution de la civilisation

Base : 0.15.1 R2. Inspiration de **genre** (RTS à âges et RTS à grandes armées) : aucun nom, unité, visuel ou texte repris d'un jeu existant.
Actif dans **Nouvelle campagne · deux systèmes** (`GameConfig.civ_evolution`, vrai par défaut). Les escarmouches historiques, les scénarios de laboratoire et les sauvegardes 0.15 gardent exactement leurs anciennes règles.

## Ce que le joueur voit

Bouton **Civilisation** dans la barre du haut (et dans la fiche du centre de commandement) : un panneau avec cinq parties.

### 1. Voies (une par époque, définitive)

À l'âge **II**, **V** et **VIII**, on choisit une voie. Chaque voie donne un bonus permanent et débloque une unité spéciale ; l'IA choisit aussi.

| Époque | Voie marchande | Voie militaire | Voie savante |
|---|---|---|---|
| Antique (II) | +25 % commerce, +10 % nourriture · **Archer monté** (marché) | +15 % formation, +10 % mêlée · **Chevalier** (caserne) | +20 % recherche, +10 % construction · **Arbalétrier** (caserne) |
| Industrielle (V) | +25 % commerce, +10 % bois et minerai · **Compagnie mitrailleuse** (marché) | +10 % attaque, +10 % formation · **Garde impériale** (caserne) | +20 % recherche, +20 % construction · **Tireur d'élite** (caserne) |
| Spatiale (VIII) | +15 % collecte, +15 % commerce · **Robot de combat** (usine) | −10 % dégâts subis, +5 % attaque · **Exosquelette d'assaut** (caserne) | +50 % points de commandement, +25 % recherche · **Marine spatial** (caserne) |

### 2. Monuments d'âge (remplacent l'ancien passage d'âge)

Pour passer à l'âge suivant, on **bâtit un des deux monuments** proposés (on ne peut en choisir qu'un). Il coûte ce que coûtait le passage d'âge, exige le même objectif qu'avant (par exemple « achever une usine »), se construit avec les ouvriers, et **fait passer l'âge à son achèvement**. Son bonus dure tant qu'il est debout ; s'il est détruit, le bonus est perdu mais l'âge reste acquis.

| Âge | Monument A | Monument B |
|---|---|---|
| II | Grand Comptoir : +25 % commerce, +5 % nourriture | Bibliothèque des Cartes : +15 % recherche |
| III | Citadelle : −25 % dégâts sur les bâtiments | Temple des Bâtisseurs : +25 % construction |
| IV | Grande Forge : améliorations −25 %, +5 % mêlée | Manufacture royale : +10 % bois et minerai |
| V | Palais impérial : +15 % formation | Grande Université : +20 % recherche |
| VI | Arsenal national : véhicules +15 % attaque, −10 % dégâts | Gare centrale : +20 % commerce, +5 % collecte |
| VII | Bouclier national : −30 % dégâts sur les bâtiments | État-major stratégique : +40 % points, +5 % attaque |
| VIII | Centre de calcul : +25 % recherche | Usine robotisée : +20 % formation |
| IX | Ascenseur spatial : +10 % collecte, +10 % commerce | Observatoire profond : +50 % points |
| X | Porte stellaire : +10 % attaque, −10 % dégâts subis | Archive galactique : +30 % recherche, +20 % construction |

### 3. Améliorations d'armée et d'économie

Nouvelle **Forge** (âge II). Onze lignes à trois niveaux, achetées dans l'onglet **Évolutions** de la fiche du bâtiment :
armes de mêlée, armes de tir, armures d'infanterie, protection des montures, balistique (forge) ; blindage avancé (usine) ;
aérodynamique (aérodrome) ; outils de bûcheron, pioches, charrues, corporation des bâtisseurs (centre). Un bâtiment étudie une amélioration à la fois.

### 4. Héros

Un héros par époque — **Capitaine** (II), **Général** (V), **Commandante** (VIII) — recruté au centre de commandement, **unique**. Aura : +15 % d'attaque et −15 % de dégâts subis pour les troupes proches. Son titre et un effet dépendent de la voie de son époque : militaire → aura d'attaque +25 % ; savante → soigne les troupes proches ; marchande → rappel deux fois plus rapide. S'il tombe, il peut être **rappelé** au centre après 60 à 90 secondes.

### 5. Pouvoirs de commandement

Détruire des unités et des bâtiments ennemis rapporte des **points de commandement**. Ils débloquent pour toute la partie des pouvoirs, en trois rangs (il faut un pouvoir du rang inférieur) ; chaque usage a une recharge. On touche **Utiliser** puis la zone visée sur la carte.

| Rang | Pouvoir | Effet | Recharge |
|---|---|---|---|
| 1 (3 pts) | Ravitaillement | soigne 35 % des PV des alliés dans la zone | 90 s |
| 1 (3 pts) | Éclaireurs | révèle une zone 30 s | 60 s |
| 2 (8 pts) | Cri de ralliement | +25 % attaque des alliés 20 s | 120 s |
| 2 (8 pts) | Renforts | 4 soldats de l'âge près d'un de vos bâtiments (population et habitants requis) | 180 s |
| 3 (15 pts) | Bombardement | frappe une zone **visible** après 3 s, ennemis seulement | 150 s |
| 3 (15 pts) | Bouclier | −50 % de dégâts sur vos bâtiments de la zone 30 s | 180 s |

## Règles techniques

- Code : `sim/civ_rules.gd` (tables), `sim/civ_evolution.gd` (règles et commandes `civ_voie`, `civ_upgrade`, `civ_unlock`, `civ_power`), `sim/civ_ai.gd` (IA), `interface/civ_panel.gd` (panneau). Crochets d'une ligne dans `sim/sim_world.gd` (collecte, construction, formation, combat, morts, achèvements, commandes), `sim/modern_systems.gd` et `sim/age_progression.gd` (vitesse de recherche).
- Données ajoutées à `sim/rules.gd` : 12 unités (champ `civ`), la forge et 18 monuments. Modèles 3D et portraits : familles existantes de la bibliothèque (`game/tactical_models.gd`).
- État : `Team.civ` (sauvegardé avec chaque monde) ; dans une campagne, un seul état par empire partagé par tous ses mondes (`StarCampaign.civ_states`, sauvegarde V2, champ `civ_states`). Une sauvegarde 0.15 se relit sans civilisation ajoutée.
- Tout passe par le pas fixe et des commandes ; un refus n'a aucun effet (vérifié par empreinte d'état). L'IA utilise les mêmes commandes, coûts et informations que le joueur.
- Changement de règle J13 : les commerces ne vendent plus les vivres sous 400 (`J13Rules.FOOD_SALE_FLOOR`), pour que la survie et l'armée passent avant le commerce.

## Vérifier

```bash
cd sillons/sillons
GODOT_BIN=/chemin/Godot_v4.7.2-stable_linux.x86_64 bash tools/verify-refonte.sh   # 52 scénarios
```

Recettes ajoutées : `lab/civ_evolution_test.gd` (62 vérifications, dont un duel IA contre IA sur la carte de 256 cases) et `lab/civ_ui_test.gd` (14 vérifications dans la vraie scène de jeu).

## Limites connues

- Toutes les valeurs (bonus, coûts, recharges, points) sont **provisoires** et n'ont jamais été jouées par un humain.
- Les nouvelles unités et héros réutilisent des modèles existants (archer à cheval, chevalier, officier…) : pas de modèle propre au héros.
- Pas d'effet visuel dédié aux pouvoirs (seul un repère sur la carte) ; pas d'aura visible autour des héros.
- L'IA débloque et utilise les pouvoirs, mais dans la recette les deux camps ne se rencontrent pas avant la fin : son usage des pouvoirs n'est vérifié qu'en laboratoire.
- Android et Galaxy S25 Ultra : `NOT_RUN`.
