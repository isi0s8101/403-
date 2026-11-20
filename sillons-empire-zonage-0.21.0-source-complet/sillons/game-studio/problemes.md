# Problèmes connus et réserves (reproductibles)

| Id | Symptôme | Reproduction | Statut / piste |
|---|---|---|---|
| P-01 | Les assets sont des primitives stylisées : la direction « 3D réaliste » n'est pas atteinte. | Lancer la zone témoin. | Ouvert, arbitrage D-12. |
| P-02 | Le joueur peut emmurer son centre en accolant des bâtiments (l'IA garde des passages). Les ouvriers enfermés signalent « gisement inaccessible ». | Construire des fermes tout autour du centre. | Ouvert. Piste : refuser un placement qui coupe le centre de tous les gisements (contrôle de chemin à la pose). |
| P-03 | Coût de simulation ≈ 1 à 3,5 ms/tick sur le conteneur de build en fin de partie (≈ 100 unités) ; non mesuré sur S25 Ultra. | Menu pause > Mesures ; ou `lab_runner` (durées par scénario). | À mesurer sur l'appareil avant de fixer le budget. |
| P-04 | L'APK est signé avec une clé de debug générée pour ce build : une future version signée autrement exigera de désinstaller la précédente. | — | Normal pour un APK de test. |
| P-05 | Vitesse x2 : jusqu'à 6 ticks par image, la simulation peut ralentir si l'image dépasse 33 ms. | Menu x2 en fin de partie. | À mesurer sur l'appareil. |
| P-06 | Les ouvriers ne fuient pas et ne ripostent pas ; ils signalent seulement « attaqué en chemin ». | Raid sur des ouvriers. | Choix provisoire J1 ; amélioration possible J2. |
| P-07 | Messages « pénurie » / « de nouveau accessible » répétés toutes les 5 s quand les baies sont épuisées et les fermes pleines (≈ 60 à 100 messages par partie R10, déjà présent au J1). | R10, journal `preuves/labo_j2/r10_partie_complete.log` vers 9 min 30. | Ouvert. Piste : hystérésis (ne réannoncer qu'après 30 s stables). |
| P-08 | Un fort couvre 8 cases : placé au mauvais endroit, il ne protège pas l'extrémité du gué que l'ennemi attaque (constaté en laboratoire, R11 première version : 0 % de pertes). | R11 avec un fort en (65,76). | Comportement voulu (le placement compte) ; à rendre lisible : afficher la portée du fort au placement (J3). |
| P-09 | L'IA ne bâtit pas toujours de fort à l'âge III (condition minerai > 200) ; dans R10 elle bâtit atelier et canons mais pas de fort. | R10. | Ouvert, équilibrage. |
| P-10 | Charge 400 unités par front : sur le conteneur (Xeon 2,1 GHz), simulation front A 26,4 ms/tick en moyenne et 85 ms en pic pendant le siège, soit ≈ 40 ms/tick en moyenne pour les deux fronts (budget 100 ms à 10 ticks/s). Sur S25 Ultra : NOT_RUN. | `preuves/deux_fronts/reference_conteneur_headless.json`. | Mesure physique attendue ; budgets proposés après. |
| P-11 | Mesures de rendu nulles dans la référence du conteneur (pas de GPU, mode sans rendu). | — | Normal ; seules les mesures S25 Ultra comptent pour le rendu. |
| P-12 | Le capteur thermique `/sys/class/thermal` est souvent illisible sans droits sur Android récent : la chauffe peut n'être qu'« observée à la main ». | Écran deux fronts : « capteur illisible ». | Procédure B8 (relevé manuel toutes les 30 s). |
| P-13 | Budget de 24 recherches de chemin par tick : lors d'un ordre de masse, les dernières unités démarrent jusqu'à ≈ 1 s plus tard (250 unités). | Front A niveau 400, lancement de l'attaque. | Choix provisoire D-23, à réévaluer avec les mesures S25. |
