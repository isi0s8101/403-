# Sillons d'Empire 0.18.0 — la ville de l'âge de l'électricité, et le jeu en portrait

Base : 0.17.0. Audit fait avant toute modification : [AUDIT-URBAIN-0.17.0.md](AUDIT-URBAIN-0.17.0.md).
Ouvrir `sillons/project.godot` avec Godot 4.7.2, lancer **Nouvelle campagne · deux systèmes**.

## 1. Basculer vers la ville

- À partir de l'**âge IV (Industrie)**, l'usine propose la recherche **Électricité** (200 bois, 250 minerai, 40 s).
- Le joueur choisit le moment. Une fois la recherche finie, c'est un **remplacement net** :
  - les **maisons** deviennent des **zones d'habitation** (même place, mêmes habitants : on ne perd personne) ;
  - les **fermes** s'arrêtent (on peut les démolir) ; maison, ferme et entrepôt ne se construisent plus ;
  - les **ouvriers** rapportent ce qu'ils portent puis ne récoltent plus ; ils construisent et réparent toujours.
- Pour ne jamais rester bloqué, le centre de commandement fournit un peu d'électricité, d'eau et de ressources autour de lui.
- Les escarmouches historiques, les scénarios de laboratoire et les anciennes sauvegardes gardent leurs règles.

## 2. Les trois zones

| Zone | Remplace | Rôle |
|---|---|---|
| **Habitation** | les maisons | loge les habitants ; 4 habitants logés = 1 place d'unité (armée, ouvriers) |
| **Commerce** | nourriture et bois récoltés | emplois ; produit nourriture et bois si assez d'habitants viennent acheter |
| **Industrie** | mines et minerai récolté | emplois ; produit le minerai ; pollue |

Chaque zone a **3 niveaux** (pavillons → immeubles → tours ; boutiques → galerie → centre d'affaires ; ateliers → usines → complexe). Le niveau se paie depuis la fiche de la zone. La **densité** monte toute seule si les habitants sont heureux, et baisse sinon. Plus une zone est dense et haute, plus elle loge ou emploie de monde.

## 3. Réseaux et services

| Bâtiment | Effet |
|---|---|
| Centrale électrique (âge IV), centrale solaire (âge VIII) | produit l'électricité dans un rayon ; la centrale pollue |
| Poste électrique | prolonge le réseau, en chaîne |
| Château d'eau (âge IV), station de pompage (âge V, près de l'eau) | eau potable dans un rayon |
| Commissariat | fait baisser la criminalité dans son rayon |
| Caserne de pompiers | évite les incendies et les éteint vite |
| Hôpital | soigne, évite les épidémies |
| Décharge (âge IV), centre de recyclage (âge VI) | réduit la pollution |

Chaque service a un **rayon** et une **capacité** (nombre de bâtiments servis, les plus proches d'abord). En cas de pénurie d'électricité ou d'eau, les services passent avant les habitations, l'industrie et le commerce.

## 4. Ce qui arrive aux habitants

- **Criminalité** : monte avec la taille des zones et le chômage ; vole une partie de la production des commerces ; baisse le bien-être.
- **Incendies** : plus fréquents dans l'industrie et les bâtiments abîmés ; abîment ou détruisent les bâtiments et peuvent se propager ; les pompiers les éteignent en quelques secondes.
- **Maladies** : la pollution et le manque d'eau font baisser la santé ; sous un certain seuil, une épidémie fait perdre des habitants (beaucoup moins près d'un hôpital).
- **Pollution** : industrie, centrale, décharge ; elle baisse la santé et le bien-être autour.
- **Eau** et **électricité** : sans eau, santé et croissance chutent ; sans électricité, les zones produisent beaucoup moins.
- **Bien-être général** : calculé à partir de tout cela et de la couverture des services. Il règle la **productivité** (de ×0,5 à ×1,2) et la croissance des zones.

## 5. À l'écran

- Bouton **Ville** dans la barre du haut : bien-être et ses facteurs, habitants et emplois, électricité et eau (produit / demandé), production, incidents, **conseils** avec un bouton **Placer**.
- **Vues au sol** : électricité, eau, sécurité, pompiers, santé, pollution, bien-être (couleurs vert / orange / rouge sur chaque bâtiment).
- Pendant la pose d'un service, son **rayon** est dessiné au sol.
- Fiche d'une zone : niveau, densité, habitants ou emplois, indicateurs, bouton **Améliorer**.
- Alertes : incendie (et bâtiment détruit), épidémie, panne d'électricité, manque d'eau, criminalité, avec « Voir ».
- L'IA joue la même ville, avec les mêmes commandes et les mêmes règles.

## 6. Paysage et portrait

- Le jeu suit le sens du téléphone ou de la tablette (paysage **et** portrait), sans relancer la partie et sans fermer les panneaux.
- Les textes et boutons gardent la même taille dans les deux sens.
- En portrait : barre du haut sur deux rangées, groupes à gauche, mini-carte à droite, **commandes en bas sous le pouce**, fiches et panneaux en pleine largeur, vue du terrain plus plongeante.
- Menus, globe, système, galaxie et orbite sont aussi adaptés.
- En portrait, l'échelle d'interface 130 % est ramenée à 115 % pour que tout tienne à l'écran.

## 7. Repères

- Aucun contenu d'un jeu existant n'a été repris (ni images, ni sons, ni textes, ni code, ni mises en page) : seules les règles habituelles des jeux de construction de ville servent de repère (zones, services à rayon, réseaux, bien-être).
- Toutes les valeurs de la ville sont **provisoires** (`sim/urban_rules.gd`) et devront être équilibrées en jouant.
- Android et Galaxy S25 Ultra : **NOT_RUN**.
