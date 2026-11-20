# Sillons d'Empire 0.18.1 — la ville de l'âge de l'électricité, et le jeu en portrait (candidate)

**0.18.1** corrige ce qui se voyait sur téléphone : le bouton « + » affiché en carré « FF0B » (symbole absent des polices) et la mini-carte étirée en hauteur. Tous les symboles de l'interface viennent maintenant des polices livrées, et un contrôle automatique l'impose.

Base : 0.17.0 (auditée : voir [AUDIT-URBAIN-0.17.0.md](AUDIT-URBAIN-0.17.0.md)). Le projet s'ouvre avec `sillons/project.godot` dans **Godot 4.7.2**.
Lancer **Nouvelle campagne · deux systèmes**.

- **Recherche Électricité** (usine, dès l'âge IV) : la ville remplace la récolte. Les maisons deviennent des zones d'habitation (sans perdre d'habitants), les fermes et la récolte s'arrêtent.
- **Zones** habitation, commerce, industrie, à 3 niveaux, avec une densité qui grandit quand les habitants vont bien. Le commerce donne nourriture et bois, l'industrie le minerai ; les habitants logés donnent des places d'unités.
- **Réseaux et services** : centrales et postes électriques, châteaux d'eau et stations de pompage, commissariat, pompiers, hôpital, décharge, recyclage, chacun avec un rayon d'action et une capacité.
- **Vie de la ville** : criminalité, incendies, maladies, pollution, eau, électricité ; un **bien-être général** qui règle la production et la croissance.
- **Panneau Ville**, vues au sol (électricité, eau, sécurité, pompiers, santé, pollution, bien-être), conseils avec « Placer », alertes.
- **L'IA** bâtit sa ville avec les mêmes commandes et les mêmes règles que le joueur.
- **Paysage et portrait** : le jeu suit le sens du téléphone ou de la tablette, sans fermer les panneaux ; en portrait, commandes en bas sous le pouce, panneaux en pleine largeur.

Les escarmouches historiques, le laboratoire et les anciennes sauvegardes gardent leurs règles. Les valeurs de la ville sont provisoires (`sillons/sim/urban_rules.gd`).

Guide : [README-VILLE-0.18.0.md](README-VILLE-0.18.0.md). Validation : `sillons/game-studio/VALIDATION-VILLE-0.18.0.md`. Aperçu : [APERCU-VISUEL.html](APERCU-VISUEL.html).
Les **61 scénarios** Godot passent sous Linux (58 anciens + 3 nouveaux). **Aucun APK n'est fourni avec cette version ; Android et Galaxy S25 Ultra : NOT_RUN.**
Aucun contenu d'un jeu existant n'a été repris.
