# Validation de livraison — 0.5.0 J3–J5

Date : 9 novembre 2026. Exécution réelle avec Godot 4.5.1 stable, Linux, sans affichage.
Archive parent SHA-256 : `28cad84fecc091a14a22491af639258991b29988fc60ac49105f4346822a4aab`.

| Contrôle | Résultat observé |
|---|---|
| Import neuf sans cache `.godot` | PASS, aucune erreur GDScript |
| Régression J1–J2 | 23 scénarios, 99/99 assertions PASS |
| Mécaniques J3–J5 | 44/44 PASS |
| Catalogue nouveau | 10/10 unités : âge requis, ordre et production vérifiés |
| IA moderne | Atteint VIII depuis VI, produit des unités et termine les 4 technologies |
| Sauvegarde | Écriture, remplacement, secours rechargeable, corruption refusée ; état complet identique après 100 ticks de reprise |
| Interface/modèles J3–J5 | Instanciation sans erreur, actions des 8 bâtiments et informations des unités |
| Atelier VIII | 9 bâtiments modernes placés (dont 2 gares), lancement PASS |
| UI J2.1 | 15/15 PASS |
| Commandes tactiles simulées | PASS |
| Visuels structurels J2.1-D/E/F | 22/22 PASS |
| Visuels structurels J2.1-C | 15/15 PASS, 1 SKIP (lecture GPU MultiMesh) |
| Deux fronts | 100 unités nominales/front, 300 ticks, variantes B/C identiques à A ; contrôle négatif détecté |
| APK, rendu GPU réel, S25 Ultra | NON EXÉCUTÉS / NON VALIDÉS |

Les journaux bruts sont joints dans `preuves/j345/` et `preuves/j345-regression/`.
Les chiffres sont des résultats de tests, pas une validation de l’équilibrage ou des performances Android.

## Contrôle graphique non vérifiable ici

Le moteur sans affichage utilise un serveur de rendu sans lecture réelle des transformations MultiMesh.
Une sonde minimale envoie une base de déterminant 0 et relit un déterminant 1.
Le test hérité J2.1-C interprétait cela comme une fuite de décor dans le brouillard.
Sa recette détecte maintenant cette incapacité, affiche **SKIP**, et maintient l’assertion
lorsque la lecture des transformations fonctionne. La logique de masquage du décor n’a pas été modifiée.
Le contrôle visuel du brouillard est obligatoire sur appareil ; il n’est pas déclaré PASS.

## Clarification du test IA

La première recette atteignait VII puis la partie se terminait par victoire avant la fin du radar.
Pour tester la progression jusqu’à VIII indépendamment de la conquête, le centre adverse reçoit
une grande réserve de PV dans cette recette uniquement. La simulation normale n’utilise pas ce réglage.
Le résultat ne constitue pas une mesure du rythme de progression depuis l’âge I avec des ressources normales.

## Arbitrages de portée

- Industrie et ravitaillement utilisent les trois ressources existantes.
- Les chemins ferroviaires sont automatiques entre gares ; pas de construction segment par segment.
- Le train fournit une couverture de ravitaillement, pas des cargaisons physiques.
- Les aéronefs sont des unités tactiques permanentes, sans décollage/atterrissage ni carburant distinct.
- Les missiles sont conventionnels et abstraits ; aucune simulation nucléaire ou diplomatique.
- Le brouillage affecte les unités électroniques, pas les bâtiments radar.
- Les modèles mécaniques sont procéduraux simplifiés ; les nouveaux fantassins réutilisent le rig existant.
- Sauvegarde locale à un emplacement ; pas de cloud ni de migration depuis les anciennes versions.

Ces choix livrent une tranche jouable intégrée des jalons, à affiner après recette appareil.
J6–J8 et la promotion de la candidate restent hors du périmètre réalisé.
