# Sillons d'Empire — J12.3 — Commandement orbital (candidate)

## Changement de doctrine (âge IX)

Le chantier naval orbital est désormais un **centre de commandement spatial autonome**, distinct du `centre` terrestre. À l'accession à l'âge IX, le premier chantier naval est **déployé automatiquement** au-dessus du monde où le camp possède un centre terrestre. Son assemblage dure 180 ticks (18 secondes à vitesse 1×). À son achèvement, il dispose d'un drone constructeur. Chaque camp suit sa propre progression.

Le vieux bâtiment tactique `chantier_orbital` (âge X) a été **conservé pour compatibilité** avec les parties et recettes J1–J12. Il est renommé « Terminal orbital terrestre (hérité) ». Il ne doit pas être confondu avec la nouvelle infrastructure orbitale.

| Équivalent terrestre | Infrastructure ou unité orbitale | Fonction réelle dans la 0.12.3 |
|---|---|---|
| Centre de commandement | Chantier naval orbital | Noyau, queue de production, amélioration locale, comptabilisation pour la victoire |
| Ouvrier | Drone constructeur | Autorise la construction de modules et de nouveaux chantiers |
| Éclaireur | Sonde | Mission de découverte d'une étoile voisine |
| Maison | Habitat orbital | Capacité de population de +6 |
| Ferme | Hydroponie | Production de nourriture dans les stocks locaux du système |
| Mine | Extracteur | Production de minerai dans les stocks locaux du système |
| Entrepôt/dépôt | Dépôt orbital | Réduction du coût alimentaire des convois galactiques |
| Caserne | Hangar | Déblocage des intercepteurs orbitaux |
| Atelier / arsenal | Arsenal stellaire (âge X) | Déblocage des frégates |
| Radar | Réseau de capteurs | Balayage orbital sans satellite (coût et recharge conservés) |
| Fort | Batterie orbitale | Réduction des dégâts des attaques orbitales entrantes |
| Caravane / navire de transport | Navette | Transporte les drones entre orbites planétaires |

Le joueur peut créer d'autres chantiers autour de mondes accessibles moyennant coût, avec un spatioport au sol **ou** un drone déjà transféré dans cette orbite. Le premier chantier est gratuit et unique par camp ; les suivants consomment 350 bois et 600 minerai du système concerné. Aucun objet orbital n'est instancié comme un bâtiment posé au sol.

## Commandes Android

La vue **Orbite / Système**, accessible seulement après les recherches correspondantes, affiche un panneau « CHANTIER NAVAL » : état de construction, populations et modules, sélection du module à bâtir, unité à produire, amélioration du chantier, mission navette + drone, mission frégate et exploration par sonde. Toutes les commandes sont revalidées dans la simulation (âge, origine, propriétaire, ressources, capacités, prérequis, missions, ETA).

Les chantiers sont visualisés par une silhouette 3D légère, indépendante du sol. Les ordres et inventaires restent persistants hors écran et à n'importe quelle vitesse. Les flottes sont **simulées par ordres et ETA**, et non pilotables manuellement en combat 3D. Le combat orbital contre les chantiers reste une résolution déterministe simplifiée, destinée à être approfondie.

## Compatibilité et sécurité de la persistance

Les sauvegardes J12.2 restent lisibles avec les nouveaux champs optionnels vides. Au tick suivant, un camp déjà à l'âge IX peut recevoir son premier chantier, s'il lui reste un centre terrestre et qu'aucun premier chantier n'a déjà été attribué. L'attribution initiale est enregistrée et ne se répète pas après destruction. Les snapshots 0.12.3 enregistrent les chantiers, la garnison, les vols, les niveaux et l'attribution initiale ; le chargeur valide les types, bornes, corps célestes, noms et ETA avant de restaurer la partie.

L'archive J12.2 reste le rollback. Aucun APK ni mesure sur S25 Ultra ne peut être considéré validé sans exécution réelle du moteur et de l'export Android.

## Tests

Depuis `sillons/` :

```bash
python3 tools/verify-orbital-static.py
./tools/verify-j12.sh
./tools/export-android-j12.sh
```

Scénario réel ajouté : `res://lab/j12_orbital_shipyard_test.gd`.
