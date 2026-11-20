# Sillons d'Empire — J12 — 0.12.0 (candidate non validée Android)

Cette livraison **intègre** le J12 à la source J11 0.11.0. Les fichiers de base sont préservés ; seules les intégrations nécessaires ont été modifiées. Elle ne constitue PAS une certification de compilation, de recette réelle ou de performance matérielle.

## Commandement galactique

La carte galactique ouvre un panneau tactile J12 : sélectionner une étoile connue, puis donner une **directive persistante**.

- **Surveiller** (`observe`) : mémorise la fin de délégation ; aucune action automatique.
- **Défendre** (`defend`) : ordonne aux armées délégables des cartes du système de défendre un centre allié, sans détourner les escouades en contrôle direct.
- **Explorer** (`explore`) : à chaque cycle de 300 ticks, demande une sonde vers un voisin inconnu si l'âge X, le chantier orbital et les ressources du système sont disponibles ; aucun brouillard n'est révélé gratuitement.
- **Approvisionner** (`supply`) : tente un convoi de ressources depuis Sol vers un système allié en manque de stocks, si des relais accessibles existent et sans dupliquer un transport déjà en route.

Ces ordres agissent sur les mécanismes existants, sans simulation instantanée ni détermination automatique de la victoire. La défense reste centrée sur les centres des cartes matérialisées ; ce n'est pas une IA militaire galactique tactique exhaustive.

## Économie par système et acheminement

`StarCampaign.system_stocks` contient les **stocks physiques food/wood/ore par système et par camp**. Les planètes d'un même système partagent un dépôt local ; les autres systèmes ne consomment plus le trésor commun. `resources` demeure l'alias du système **Sol** pour préserver le code J1–J11 (et les scénarios historiques). Le centre de commande et l'âge restent globaux au camp pour le J12.

`ship_supplies(team, origine, destination, manifeste)` :
- exige âge X, systèmes connus, départ avec chantier orbital, arrivée contrôlée ;
- exige les relais intermédiaires **contrôlés et dotés de chantiers opérationnels** ;
- refuse les ressources inconnues, les valeurs non entières, négatives, nulles, les surcharges et les fonds insuffisants **avant débit** ;
- débite au départ l'intégralité de la cargaison et des frais **20 nourriture par saut** ;
- parcourt la route par étapes, chaque saut ayant un ETA, immobilise le fret si un relais est perdu et reprend à la restauration du relais ;
- dépose une seule fois les ressources à l'arrivée, même si le joueur observe une autre planète ;
- permet jusqu'à **64 transports logistiques actifs** (limite candidate à mesurer) ; les cargos de fret sont une abstraction logistique et non des frégates 3D pilotables.

**Attention migration J11** : le trésor anciennement partagé est intégralement attribué à Sol au premier chargement, jamais copié dans plusieurs systèmes. Les avant-postes éloignés démarrent sans stock local ; ils peuvent continuer à produire sur place ou être ravitaillés depuis Sol. Les anciennes sauvegardes originales restent inchangées. Les sauvegardes 0.12.0 portent des champs supplémentaires validés strictement à la restauration.

## Android et rendu

- Les simulateurs continuent à **pas logique fixe 10 Hz** ; la cadence et les commandes ne dépendent pas de la caméra.
- Un `MobilePerfBudget` ajuste uniquement le LOD décoratif et la fréquence de rafraîchissement des marqueurs galactiques après surcharge graphique prolongée ; il remonte progressivement à qualité normale. Il ne modifie **jamais les résultats de combat, l'ETA ni la vitesse de simulation**.
- Les marqueurs de fret sont réutilisés, bornés à **24** simultanément ; les convois réellement simulés restent tous actifs. Les marqueurs militaires existants sont bornés à 48.
- Les vitesses 0,5×, 1×, 2×, 4× et 8× et la mesure de FPS/p95/p99/ticks/s sont préservées. Aucune cible de FPS n'est déclarée atteinte sans essai S25 Ultra.

## Recette J1–J12

Depuis le dossier `sillons/` (outil externe non inclus : Godot version compatible et Android SDK) :

```bash
./tools/verify-j12.sh
./tools/export-android-j12.sh
```

`verify-j12.sh` : sept audits statiques historiques, audit J12, import de projet Godot puis scénarios J1–J12 et tests de performance visuelle. **Sans Godot, code 127 et `J12_RUNTIME=NOT_RUN`** ; ne pas déclarer PASS.

Dans le jeu, l'écran **RECETTE INTÉGRALE J1–J12** exécute les scénarios historiques et des vérifications de J9–J12. Treize validations matérielles, notamment changement de région, orbites, exploration, gestion des ordres, fret, FPS, chauffe et stabilité, restent **manuelles**. La recette approfondie des cas de fret interrompu est dans `lab/j12_empire_test.gd`.

## Limites non levées

- Compilations Godot et APK non prouvées par les tests statiques.
- Les batailles spatiales restent un modèle de convois/interceptions, pas un RTS de frégates pilotables en 3D.
- Les planètes J10/J11 non historiques n'héritent pas toutes du système régional J9 complet.
- L'IA de commandement J12 ne remplace pas une planification multi-fronts exhaustive ni une économie de marché profonde.
- Le système de fret logistique n'inclut pas encore l'interception militaire du fret ; une route coupée bloque le trafic, mais ne le détruit pas. Les escarmouches / frégates historiques conservent leurs interceptions.
- Le stockage et les fréquences de rendu doivent être évalués sur Galaxy S25 Ultra, notamment en vitesse ×8 et après 20 minutes.

## Réversibilité / précautions

L'archive J11 originale reste la baseline. Conserver une copie du dossier `user://` avant de changer de version. Une sauvegarde créée en 0.12.0 n'est **pas** garantie lisible par une ancienne branche J11 ; revenir à J11 nécessite de restaurer une **sauvegarde J11**. Il n'existe pas de rétro-conversion destructrice.
