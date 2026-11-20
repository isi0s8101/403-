# Sillons d'Empire 0.19.0 — la ville se construit seule sur les zones peintes (LOT A)

Guide du nouveau système. Audit préalable : [AUDIT-ZONAGE-0.18.1.md](AUDIT-ZONAGE-0.18.1.md).
Rapport de tests : `sillons/game-studio/VALIDATION-ZONAGE-0.19.0.md`.

## En une phrase

Vous peignez des zones et vous tracez des routes ; les habitants bâtissent eux-mêmes, quand la demande, la route, les ressources et la sécurité le permettent. La ville grandit, se densifie, change d'architecture avec les âges, connaît la criminalité, les émeutes et les incendies, et se reconstruit.

## Pour jouer

1. **Nouvelle campagne** (parties avec l'évolution de la civilisation). Le zonage est possible **dès l'âge I**, à côté de la récolte par les ouvriers.
2. Bouton **Zones** dans la rangée **Bâtir**. Un calque coloré apparaît sur le terrain (seulement dans ce mode).
3. Choisissez un type :
   - **Hab. bas**, **Hab. moyen**, **Hab. dense** : habitations (niveau II, IV ou VI au plus).
   - **Commerce** : vivres et bois.
   - **Industrie** : minerai, mais aussi pollution.
   - **Agricole** : vivres.
   - **Route** : à relier au centre-ville.
   - **Gomme** : retire le zonage ou la route.
4. Choisissez un outil :
   - **Pinceau** : on peint au doigt. Toucher le bouton de nouveau change la taille : 1, 2 ou 3 cases.
   - **Rectangle** : on glisse pour couvrir une zone.
   - **Parcelle** : un toucher couvre 2 × 2 cases.
   - **Inspecter** : un toucher affiche la fiche du quartier.
   - Autres boutons : **Annuler** (30 gestes), **Fermer**. Le bouton retour d'Android ferme aussi le mode.
5. Deux doigts déplacent la caméra sans peindre. Le jeu peut rester en pause pendant qu'on peint.
6. Un bâtiment ne pousse qu'à **2 cases au plus d'une route reliée au centre**. Pas de route, pas de ville.

Les boutons et les gestes sont les mêmes à tous les âges : seul l'habillage change.

## Ce que fait la ville toute seule

- **Construction** : un chantier s'ouvre sur une parcelle libre de 2 × 2 cases. Il est payé avec vos vraies ressources (par exemple 30 bois pour une habitation) et se termine en 12 s, sans ouvrier. Le nombre de chantiers dépend du nombre d'habitants.
- **Pas de chantier** dans ces cas, et la fiche dit pourquoi :
  - pas de demande ;
  - pas de route reliée au centre ;
  - pas assez de ressources ;
  - un ennemi armé à moins de 9 cases ;
  - un quartier trop criminel.
  Certaines parcelles restent donc vides.
- **Demande** (barres en bas du mode Zonage) : calculée à partir de la vraie économie.
  - Les habitants veulent des commerces et des emplois.
  - L'industrie et le commerce veulent des habitants.
  - La faim fait monter la demande agricole.
- **Niveaux** : un bâtiment monte seul de niveau quand le quartier est dense, heureux, assez riche, demandé, desservi par la route et équipé. Le niveau est payé, puis suivi de 12 s de travaux.
  - Plafond selon l'âge : II aux âges I–II, III à l'âge III, IV aux âges IV–V, V aux âges VI–VII, VI à partir de l'âge VIII.
  - Services exigés : police à partir du niveau III, plus l'eau au niveau IV. Le niveau V exige aussi les pompiers et l'électricité, et le niveau VI la santé en plus.
- **Architecture** : chaque bâtiment garde l'âge de sa construction. Les nouveaux et ceux qui montent de niveau prennent le style de l'âge actuel : la ville change peu à peu, pas d'un coup. Dans la fiche d'un bâtiment, **Conserver l'architecture** crée un quartier historique.
- **États** : en chantier, opérationnel, prospère, dégradé, endommagé, en feu, brûlé, abandonné, en reconstruction. L'état change la production et se voit sur le modèle (volets fermés, barricades, fumée…).
- **Nourriture** : les habitants mangent. Sans vivres, c'est la famine : les habitants partent et la demande agricole monte.

## Criminalité, émeutes

- **Causes** : pauvreté, chômage, manque de services, ennemi à proximité.
- **Conséquences** :
  - vols sur la production et pillages (de vraies ressources) ;
  - quartiers dégradés ;
  - habitants qui partent ;
  - émeutes, qui abîment sans raser (les bâtiments gardent au moins 40 % de leur solidité).
- **Remèdes** :
  - avant la police, la garde de la caserne ou du fort ;
  - le commissariat (âge III) ;
  - des emplois et de la richesse.
  L'armée ou la police mettent fin à une émeute.

## Incendies

- Un feu a une **intensité** qui monte sans secours.
- Les quartiers de bois des premiers âges brûlent plus vite.
- Le temps qu'il fait compte : un cycle sec / humide de 10 minutes de jeu.
- Le feu **se propage** aux voisins.
- Les **puits** aident avant les pompiers. La **caserne de pompiers** doit être reliée par la route.
- Un bâtiment détruit laisse des **ruines**, qui restent (et sont sauvegardées) jusqu'à ce que la ville reconstruise par-dessus, plus cher.

## L'IA

L'IA trace ses routes et peint ses zones selon sa propre demande. Elle passe par les **mêmes commandes et les mêmes règles** que vous, sans aucun privilège.

## Anciennes parties

Une partie 0.18 se charge : chaque zone posée à la main devient une parcelle zonée, avec son niveau. La conversion se fait une seule fois. La bascule de la recherche Électricité (âge IV) reste : elle ajoute les réseaux d'électricité et d'eau, et les niveaux élevés.

## Pour les développeurs

- `sim/urban_zoning.gd` (UrbanZoning) : calques par camp, sauvegardés dans `Team.zoning` :
  - `zone` (code par case) et `road` ;
  - commandes `zone_paint`, `zone_clear`, `road_paint`, `road_remove`, `zone_historic` ;
  - parcelles, accès, fiche de quartier, migration 0.18.
  Codes 20 à 28 réservés aux zones spécialisées futures (minière, énergétique, militaire, scientifique, administrative, portuaire…).
- `sim/urban_growth.gd` (UrbanGrowth) : demande, chantiers, niveaux, états, ruines, météo, sécurité.
- `sim/urban_city.gd` (UrbanCity) : calcul toutes les 20 ticks (2 s). Il est déterministe : même graine, même ville. Valeurs dans `sim/urban_rules.gd`, **toutes provisoires**.
- `game/urban_visual.gd` (UrbanVisual) : modèles composés selon la catégorie, le niveau, l'âge et l'état ; reconstruits seulement quand leur signature change.
- Routes et calque dessinés par le shader du terrain (`game/realism/terrain.gdshader`), sans géométrie ajoutée.
- `interface/zoning_tool.gd`, `interface/zoning_panel.gd` : outil et barre du mode Zonage.
- Recettes : `lab/zoning_test.gd` (79 vérifications), `lab/ui_zoning_test.gd` (26).

## Ce qui viendra au LOT B (0.20.0)

- Âges : silhouettes plus distinctes pour chacun des 10 âges.
- IA plus fine.
- Simulation abrégée des villes lointaines : colonies, orbite, système, galaxie.
- Filtres visuels : population, densité, criminalité, prospérité, production, pollution, état, incidents, infrastructures.
- Événements : séisme, inondation, tempête, crise, migration.
- Performances : seuils mesurés et calcul de la ville réparti sur plusieurs ticks.
