> **État courant : 0.5.0 J3–J5 candidate.** Voir `../README-J345.md` et `J345-validation.md`. Les sections suivantes sont l’historique J1–J2.1 ; leurs mentions « simulation inchangée » ne concernent pas J3–J5.

> **J2.1 candidat (2026-11-09)** : refonte interface et tactile sur la baseline J2 0.2.0. Voir `J21-mobile-ui.md` et `validation-j21.md`. J1-J2 et simulation inchangés ; validation Godot/Android J2.1 en attente.

# Sillons d'Empire — dossier de reprise (game-studio)

RTS original en dix âges pour Android, Godot 4 / GDScript. Ce dossier est la mémoire du projet :
baseline, décisions, fiches de design, recettes, preuves, problèmes et prochaine action.

## État au jalon J2 (version 0.2.0-j2)

- **Statut de livraison : NON VALIDÉE** — les mesures physiques sur Galaxy S25 Ultra (recette B1-B10, dont le test
  deux fronts) sont NOT_RUN. Départ : baseline J1 **non approuvée**, utilisée à titre provisoire (`baseline.md`).
- Tranche jouable : escarmouche hors ligne âges I à III ; palissades et forts pour tenir un gué, atelier et canons de
  siège ; l'IA assiège un passage fermé ou prend l'autre gué ; minuteur de reconstruction (D-07 approuvé).
- Essai technique séparé : deux cartes simulées en parallèle, une seule affichée, mesures enregistrées
  (menu > « Test technique : deux fronts »).
- Laboratoire : 23 scénarios seedés (99 assertions), test d'invariance deux fronts avec contrôle négatif,
  comparaison de réglages, recette tactile. Tout est PASS sur le conteneur.

### État au jalon J1 (0.1.0-j1)

- Escarmouche âges I-II, 16 scénarios (67 assertions) ; essai S25 Ultra NOT_RUN ; baseline non approuvée.

## Structure

| Dossier | Rôle |
|---|---|
| `sim/` | Règles et simulation déterministe (aucune dépendance au rendu ni aux entrées). `rules.gd` = données d'âges, unités, bâtiments, coûts (valeurs PROVISOIRES identifiées). |
| `game/` | Rendu 3D, caméra, gestes tactiles, interface, menu, zone témoin, écran deux fronts (`fronts.gd`). Lit la simulation, n'agit que par `SimWorld.issue()`. |
| `lab/` | Laboratoire : `lab_scenario.gd` (moteur de scénario), `lab_runner.gd` (sans rendu), `touch_test.gd` (gestes), `scenarios/*.json` ; J2 : `theater.gd` (deux fronts), `fronts/*.json`, `fronts_test.gd` (invariance), `compare_settings.gd`. |
| `tools/` | Capture d'écran de contrôle (hors APK). |
| `game-studio/` | Ce dossier. Exclu de l'APK. |

## Commandes

```bash
# Import (une fois, génère le cache des classes)
godot --headless --path . --import
# Laboratoire complet sans rendu (code de sortie 0 = PASS)
godot --headless --path . -s res://lab/lab_runner.gd -- all
# Un scénario, graine forcée, journaux dans un dossier
godot --headless --path . -s res://lab/lab_runner.gd -- r04_delegation --seed=77 --out=/tmp/labo
# Recette tactile automatisée
godot --headless --path . -s res://lab/touch_test.gd
# J2 : invariance deux fronts, comparaison de réglages, protocole de mesure automatique
godot --headless --path . -s res://lab/fronts_test.gd
godot --headless --path . -s res://lab/compare_settings.gd
godot --headless --path . -- --fronts-auto --fronts-sec=40 --fronts-quit
# Export APK de test (SDK Android et keystore de debug configurés dans les réglages de l'éditeur)
godot --headless --path . --export-debug "Android" build/sillons-j2-debug.apk
```

Journaux du laboratoire : `user://lab_logs/<scenario>.log` et `resume.txt`
(sous Linux : `~/.local/share/godot/app_userdata/Sillons d'Empire/lab_logs/`).

## Prochaine action concrète

1. Le créateur installe l'APK J2 sur le Galaxy S25 Ultra et déroule `recette.md` §6 (B1-B10), en particulier le
   protocole deux fronts deux fois d'affilée avec relevé de chauffe.
2. Il renvoie `resultats-android.md` rempli et les fichiers `deux_fronts_*.json` (et, si possible, J1 A10-A13).
3. Il approuve ou corrige les baselines J1 puis J2 et tranche D-03, D-16 et D-12 (`decisions.md`).
4. À partir des mesures : fixer la limite observée et les budgets de référence (`mesures-rendu.md`), puis ajuster
   D-23 (budget de chemins) si besoin.

En parallèle : hystérésis des messages de pénurie (P-07), portée du fort affichée au placement (P-08), équilibrage
du fort de l'IA (P-09).


## Complément J2.1-C (0.2.2, non validé sur appareil)
L'implémentation du terrain PBR, des berges, de l'éclairage et des détails `MultiMesh` est documentée dans `J21C-terrain-pbr-eclairage.md`. La baseline J2 0.2.0 reste protégée ; J2.1 FIX1 est le parent de ce lot. Le projet 0.2.2 est une **candidate** et demande une compilation dans Godot et des mesures S25 Ultra avant promotion.

## Candidat J2.1-D/E/F (0.2.3, NON VALIDÉ)
Lot unique de personnages procéduraux articulés, bâtiments détaillés, dégâts visuels, siège et profils d'interface mobile. **Aucune modification de `sim/`**. Recette, limites et rollback : `game-studio/J21DEF-unites-batiments-tactile.md`. Le Galaxy S25 Ultra et la compilation Godot 4.7.2 restent à tester avant toute nouvelle baseline.
