# Les deux ouvertures de l'âge II

Mesures du laboratoire (sans rendu, Godot 4.4.1, graine indiquée, 8 400 ticks = 14 min de jeu).

| | Commerce | Assaut précoce |
|---|---|---|
| Investissement | relais 120 bois, marché 170 bois + 40 minerai, caravanes 60 nourriture + 60 bois | 2e caserne 150 bois, unités 85 à 165 ressources |
| Délai avant rendement | premier gain ≈ 1 min 30 après le relais (aller-retour) | dès que le seuil d'armée est atteint (8 à 10 unités) |
| Coût d'opportunité | armée faible pendant 4 à 6 min, relais isolé exposé | moins d'ouvriers (16 contre 20), pas de revenu passif |
| Gagne quand | l'adversaire n'attaque pas avant ≈ 8 min ; route courte et protégée | l'adversaire a investi dans le commerce sans défense ; relais à portée |
| Perd quand | raid de cavaliers sur le relais / les caravanes | défense supérieure au centre (le centre tire, tireurs groupés) : voir R06 |

## Situations reproductibles

- **R07 (graine 1701)** — commerce (camp 0) contre assaut tardif (seuil 30) : revenu cumulé **9 353 contre 4 746**,
  dont **4 621** de commerce. Le relais est finalement détruit vers 13 min par l'assaut tardif : le commerce doit
  convertir son avance en défense avant ce moment.
- **R08 (graine 1801)** — assaut précoce (seuil 8) contre commerce sans armée : **relais détruit à 5 min 30**,
  puis fermes, entrepôts, maisons ; **47 pertes infligées contre 21**.
- **R06 (graine 1601)** — l'assaut échoue contre 24 défenseurs : 66 % de pertes, abandon exposé, l'IA relève son
  seuil d'attaque et passe en consolidation.

Commande : `godot --headless --path . -s res://lab/lab_runner.gd -- r07_ouverture_commerce r08_ouverture_assaut`
