# Sillons d’Empire — J12 0.12.2 — Arbre d’évolution locale

Base : J12 0.12.0 et travaux de correction/accès aux vues 0.12.1 (pas de ZIP 0.12.1 déclaré stable).

- Dix âges I–X : les unités et bâtiments conservent leur âge d’origine et s’améliorent avec des recherches, et non automatiquement au passage d’âge.
- Pour chaque bâtiment producteur : niveaux architecturaux I/II/III, puis évolution individuelle de chaque type de troupe qu’il entraîne.
- Deux casernes identiques peuvent ainsi développer indépendamment piquiers, tireurs et cavaliers. Le joueur sélectionne une caserne et choisit ses recherches.
- Chaque recherche prend du temps, coûte des ressources, exige l’âge correspondant, et bloque les recherches locales concurrentes. Les refus ne retirent aucune ressource.
- Niv. II : +20% PV bâtiment, +10% cadence de production ; niv. III : +40% PV et +20% cadence.
- Niv. II des unités : +12% PV, +10% attaque ; niv. III : +24% PV, +20% attaque. Le pourcentage de santé courant est conservé.
- Une amélioration de troupe modernise les unités existantes issues de CE bâtiment ainsi que celles qu’il produira ensuite ; elle ne touche pas les autres bâtiments.
- Styles d’unité : 19 lignes distinctes ; noms et insignes colorés par niveau. Styles de bâtiment : 10 lignées nommées et insignes architecturaux de niveau.
- Le chemin d’accès aux vues reste : tactique (I), planète (II + cartographie), orbite (IX + observation), système (IX + navigation interplanétaire), galaxie (X + navigation stellaire puis cartographie).
- Sauvegardes antérieures : champs additionnels avec niveau 1 par défaut ; les nouvelles versions mémorisent les recherches locales. Les transports interplanétaires préservent le niveau d’évolution et les PV.
- Validation : `./tools/verify-j12.sh`, puis `./tools/export-android-j12.sh` avec Godot 4 et le SDK Android. Tests statiques ≠ compilation Godot.

## Progression détaillée I–X

| Âge | Unités et bâtiments débloqués (selon coûts/conditions de la partie) | Nouvelles échelles |
|---|---|---|
| I | Centre, ouvriers, éclaireurs, caserne et lanciers | Tactique |
| II | Tireurs, cavaliers, marché, caravanes, relais ; améliorations de caserne | Globe si Cartographie terrestre recherchée au marché |
| III | Fort, atelier et canons ; perfectionnement des structures plus anciennes | Globe |
| IV | Usine, fusiliers et obusiers | Globe |
| V | Académie, grenadiers et standardisation | Globe |
| VI | Chars, avions, défense antiaérienne, trains, gares et aérodromes | Globe |
| VII | Missiles, radars et antimissiles | Globe |
| VIII | Drones et brouillage électronique | Globe |
| IX | Spatioports, navettes, satellites, observation et navigation interplanétaire | Orbite puis système stellaire après recherches |
| X | Chantiers orbitaux, frégates, navigation stellaire et cartographie galactique | Galaxie après recherches |

Ces ouvertures d'âge sont déjà définies dans `Rules`. Les nouvelles évolutions locales sont une progression parallèle : le passage d'âge seul n'améliore pas automatiquement les troupes ni leurs producteurs.

## Parcours de recherche et d'évolution

**Vues** : marché → Cartographie terrestre (II) → spatioport → Observation orbitale (IX) → Navigation interplanétaire (IX) → chantier orbital → Navigation stellaire (X) → Cartographie galactique (X).

**Production** : choisir son bâtiment → niveau architectural II ou III → moderniser individuellement chacun des types d'unité qu'il produit → entraînement automatique dans la version acquise. Les unités préexistantes ayant ce producteur pour origine sont équipées également. Les unités indépendantes des bâtiments ne sont pas modifiées.

Le niveau II d'un producteur exige au minimum l'âge suivant son âge de construction ; le niveau III exige deux âges supplémentaires. Les technologies des âges IX–X ont encore des niveaux internes à l'âge X, avec coûts et durées. Les valeurs de bonus constituent une base d'équilibrage, non une validation du gameplay.

**Sécurité du chargement** : les nouvelles sauvegardes vérifient les niveaux (1 à 3), les unités autorisées par bâtiment, les recherches locales, les niveaux des convois et leurs données de progression. Les sauvegardes antérieures sans ces champs rétablissent le niveau I sans les altérer.

**Limite visuelle** : les styles se distinguent actuellement par leurs dénominations, des bonus de statistiques et un équipement/parement procédural léger sur le modèle 3D. Ce ne sont pas encore 57 modèles 3D distincts ni des animations exclusives.

**IA :** les camps IA peuvent investir dans les améliorations de leurs propres bâtiments et troupes à partir de l’âge IV, avec une réserve minimale de ressources et une seule décision toutes les 10 secondes de simulation. Ce budget est provisoire et doit être équilibré après les tests réels.

**Transferts interrégionaux :** l’équipement acquis est conservé. Le lien au bâtiment producteur est détaché après changement de région pour empêcher une collision entre identifiants locaux de bâtiments. Les unités expatriées ne reçoivent donc pas automatiquement une recherche lancée ensuite dans leur région d’origine.
