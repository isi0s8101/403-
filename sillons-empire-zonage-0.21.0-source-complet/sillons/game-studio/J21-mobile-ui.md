# J2.1 — interface tactique mobile et gestes (A+B)

**Version candidate** : `0.2.1-j2.1-ui-touch` — dérivée de `sillons-empire-j2-src-0.2.0.zip`.
**Cible** : Godot 4.4.1, Android, Galaxy S25 Ultra en paysage.
**Périmètre** : HUD, menu principal, caméra, sélection et gestes. Les âges, règles, IA, économie, combats et laboratoires J1–J2 sont inchangés.

## Fonctionnalités

- HUD graphite/turquoise sans flou coûteux : ressources et priorités, population, âge.
- Mini-carte masquable, panneau d'escouades repliable et défilant ; champs de bataille dégagés.
- Panneau de sélection contextuel, actions longues défilables horizontalement.
- Menu principal retravaillé ; toutes les entrées (solo, démo IA, deux fronts, zone témoin, labo) conservées.
- Nouveau mode de sélection rectangulaire explicite (`Sélect.`). La sélection groupée prend le contrôle direct des unités uniquement **lorsqu'un ordre est réellement envoyé**.
- Maintien des interactions : premier toucher sur une unité = escouade ; second toucher = unité ; appui long sur unité = sélection isolée.
- Appui long sur terrain avec sélection = palette tactique en losange avec **Marcher** (`move`) / **Assaut** (`amove`) ; **Cibler** (`attack`) si un ennemi est sous le point d'appui, sinon **Déf. armée** (`army_defend`) pour déléguer la défense d'un secteur.
- Glissement à un doigt = caméra avec inertie décroissante ; deux doigts = zoom + rotation et pan du centre des doigts. Le zoom est interpolé, sans changer le tick de simulation.
- Le menu pause et le panneau de fin de partie bloquent les entrées tactiques ; un test en pause technique reste possible.

## Gestes en jeu

| Geste | Résultat |
|---|---|
| Toucher unité amie | Sélection escouade ; un deuxième toucher sélectionne l'unité |
| Toucher bâtiment ami | Affichage production/construction |
| Toucher le terrain après sélection | Déplacement direct (`move`) |
| Toucher un ennemi après sélection | Attaque ciblée (`attack`) |
| Appui long sur terrain après sélection | Menu tactique contextuel |
| Bouton Sélect. puis glisser | Encadrer plusieurs unités, sans ordre de mouvement |
| Glisser un doigt hors sélection rectangulaire | Déplacer la caméra |
| Pincer et tourner deux doigts | Zoom / rotation / déplacement du centre |
| Toucher la mini-carte | Centrer la caméra |
| Bouton Armées | Déployer la liste d'escouades et la délégation |
| Bouton Bâtir | Ouvrir le catalogue de constructions |

## Contrôles techniques à exécuter dans Godot

Depuis la racine `sillons/` :

```bash
godot --headless --path . --import
godot --headless --path . -s res://lab/lab_runner.gd -- all
godot --headless --path . -s res://lab/touch_test.gd
godot --headless --path . -s res://lab/ui_j21_test.gd
godot --headless --path . -s res://lab/fronts_test.gd
```

**Statut dans cette livraison** : tests de compilation et runtime `NOT_RUN` (Godot non installé dans l'environnement de création). Les 23 scénarios / 99 assertions PASS mentionnés dans le dossier J2 sont **des preuves historiques J2** et ne doivent pas être présentés comme de nouvelles exécutions J2.1.

## Recette sur Galaxy S25 Ultra

1. Vérifier l'affichage des ressources, de la population et de l'âge ; ouvrir/masquer la mini-carte et la liste d'escouades. Aucune zone d'action ne doit masquer une autre.
2. Appuyer sur une unité, puis une deuxième fois, et commander un déplacement ; vérifier le marqueur au sol et l'absence d'ordre si l'interface est touchée.
3. Activer `Sélect.`, encadrer au moins deux unités, déplacer le groupe. Vérifier que la caméra ne bouge pas pendant l'encadrement.
4. Sélectionner une escouade et maintenir le doigt au sol : menu tactique, puis **Assaut**. Vérifier l'ordre d'attaque en mouvement.
5. Effectuer des pincements/rotations à deux doigts, puis poursuivre à un doigt ; aucun saut brutal de caméra attendu.
6. Ouvrir le menu pause, glisser hors du menu : aucune interaction tactique ne doit être enregistrée. Reprendre.
7. Construire et produire avec un bâtiment ; vérifier le défilement horizontal des actions nombreuses.
8. Exécuter les bancs d'essai J2 avec deux fronts ; relever FPS, consommation mémoire, température et toute fermeture.

## Limites connues

- Aucune nouvelle géométrie 3D, texture PBR ou animation d'unité : ces travaux relèvent de J2.1-C/D/E. Les performances de la refonte UI ne sont pas mesurées sur S25 Ultra.
- Interface conçue pour paysage **1280×600 logique** ; les écrans significativement plus petits restent à qualifier.
- La sélection rectangulaire est volontairement explicite pour éviter la confusion avec le déplacement de caméra.
- L'inertie et la sensibilité du zoom sont des réglages provisoires à affiner par mesure tactile sur appareil.

## Retour arrière

Le ZIP `sillons-empire-j2-src-0.2.0.zip` reste la baseline stable de comparaison. La mise à jour J2.1 ne modifie aucune source `sim/`. Restaurer la baseline J2 ou les quatre fichiers `game/game.gd`, `game/hud.gd`, `game/main_menu.gd`, `project.godot` (ainsi que `export_presets.cfg`) pour revenir au comportement précédent.
