# J2.1-D + E + F — Lot graphique et ergonomique 0.2.3

## Références et statut

- Base de développement : `sillons-empire-j21c-terrain-pbr-0.2.2-source-complet.zip` (candidate non validée).
- Dernière version fonctionnelle rapportée par l'utilisateur : `sillons-empire-j21-ui-tactile-0.2.1-fix1-source-complet.zip`.
- Baseline préservée : `sillons-empire-j2-src-0.2.0.zip` ; `sim/` inchangé (SHA-256 dans `game-studio/j2-sim.sha256`).
- Statut 0.2.3 : **CANDIDATE / NON VALIDÉE** jusqu'à compilation Godot 4.7.2, recettes et test sur Galaxy S25 Ultra.
- Développement du lot en un bloc : J2.1-D (unités), E (architecture et siège), F (UI et contrôle mobile).

## Implémentation détaillée

**J2.1-D — Unités :** `game/unit_visual.gd` ajoute un personnage procédural articulé de proximité pour ouvriers, fantassins, cavaliers et servant du canon. Silhouette humanoïde détaillée : tête, visage, épaules, cou, plastron, cuir, ceinture, bras, coudes, jambes, genoux, bottes, casque et équipement par rôle. Marche proportionnelle à la distance parcourue entre ticks, geste d'attaque/rechargement et animation de travail. Le modèle J2 de faible détail est conservé pour les unités éloignées et les caravanes. **Limite : ce sont des personnages 3D procéduraux, pas des modèles photoréalistes sculptés avec texture peau/visage ni des animations mocap.** Prévoir des assets sous licence compatible pour cette étape plus tard, sans abandonner les LOD.

**J2.1-E — Bâtiments :** `game/building_visual.gd` ajoute encadrements de portes/fenêtres, volets, cheminées, charpentes, portes renforcées du fort et détails sur palissades/fermes. Marques de dégâts à moins de 65 % de santé, fissures à moins de 30 %, sans modifier la simulation. Ruines animées (effondrement d'environ 1,35 s) lors de la disparition d'un bâtiment. Impact de canon avec onde au sol et trois fragments, purement visuels, sans dégâts supplémentaires.

**J2.1-F — Mobile :** sélection multiple, minimap et menu contextuel J2.1 restent en place. Pause : profils de qualité Économie / Équilibré / Détaillé ; aide aux gestes, retour utilisateur si ordre rejeté ; FPS, appels et nombres de rigs/effets accessibles sur demande. En Économie : rig complexe masqué, petits détails de terrain désactivés au grand zoom, ombres désactivées. Les préférences ne sont pas persistées. La simulation J2 continue toujours sur 10 ticks/s.

### Budgets d'exécution (garde-fous, pas des performances mesurées)

| Ressource | Équilibré (défaut) | Détaillé | Économie |
|---|---:|---:|---:|
| Unités 3D articulées maximum par vue | 24 | 56 | 0 nouvelles |
| Bâtiments détaillés maximum par vue | 24 | 48 | 0 nouveaux |
| Effets visuels actifs maximum | 72 | 72 | 72 (émissions nouvelles réduites) |
| Ombres temps réel | selon choix utilisateur | selon choix utilisateur | désactivées |

Le cap de rigs est appliqué par `WorldView`; les objets déjà construits restent alloués quand on s'éloigne, mais leur géométrie détaillée est masquée au profit des anciennes silhouettes. Ce choix réduit le coût de géométrie, **pas nécessairement le coût mémoire total**. Il devra être revu après profilage instrumenté.

## Commandes de vérification

Depuis la racine du projet Godot `sillons/` :

```bash
# Vérifications statiques Python, éventuellement comparées à la baseline et au parent.
python3 game-studio/verify_j21def_static.py /chemin/sillons-empire-j2-src-0.2.0.zip /chemin/sillons-empire-j21c-terrain-pbr-0.2.2-source-complet.zip

# Godot 4.7.2 installé : importer, démarrer les laboratoires.
godot --headless --path . --import
godot --headless --path . -s res://lab/lab_runner.gd -- all
godot --headless --path . -s res://lab/touch_test.gd
godot --headless --path . -s res://lab/ui_j21_test.gd
godot --headless --path . -s res://lab/visual_j21c_test.gd
godot --headless --path . -s res://lab/visual_j21def_test.gd
godot --headless --path . -s res://lab/fronts_test.gd
```

Tester l'export Android de debug depuis l'éditeur Godot installé sur la machine possédant les export templates et le SDK Android. **Aucun APK n'est fourni sans compilation et export réussis.**

## Recette Galaxy S25 Ultra (J2.1-F — non exécutée par l'agent)

1. Installer et ouvrir le projet **en paysage** dans Godot 4.7.2. Vérifier erreurs GDScript (0) et compilation shader (0). Réinitialiser les erreurs avant la recette.
2. Escarmouche, zoom avant : vérifier les bras/jambes des ouvriers, lances, tireurs, cavaliers et servant du canon. Observer la marche, l'arrêt, les combats et l'absence de déformation, scintillement et clipping excessifs.
3. Zoom arrière puis avant : vérifier la transition des modèles de proximité vers les silhouettes J2 ; aucun personnage ne doit disparaître ou révéler une unité sous brouillard.
4. Construire une maison et une palissade ; examiner les portes, fenêtres et charpentes. Attaquer un fort : marques de dégâts, fissures puis ruine à destruction. Aucune perte de commandes ni dégâts additionnels dans la simulation.
5. Taper une escouade, retaper une unité, appui long pour les ordres, glisser, sélectionner par rectangle, pincer/rotation à deux doigts. Effectuer 20 répétitions, vérifier les faux ordres et les chevauchements des panneaux.
6. Menu Pause > Gestes et commandes ; fermer puis Reprendre. Faire défiler Qualité Économie / Équilibré / Détaillé et comparer visuel et FPS ; vérifier que la préférence d'ombres réapparaît après Économie.
7. Lancer le laboratoire « Deux fronts », tester 40, 100, 200 et 400 unités ; basculer plusieurs fois, relever FPS, simulation ms/tick, draw calls, mémoire, chauffe, pertes d'images, latence de bascule et stabilité de la sélection.
8. Tester une partie d'au moins 20 minutes en qualité Équilibré, puis Détaillé, et relever chauffe/batterie. Cibles proposées, **non validées** : ≥60 FPS en escarmouche courante, ≥30 FPS en charge lourde, 0 erreur GDScript, 0 ordre incorrect.

### Conditions d'acceptation

- Aucun `ERROR` ni `Parse Error` au démarrage et dans les laboratoires.
- Tous les laboratoires J1/J2/J2.1 PASS ; simulation SHA-256 identique à J2.
- Pas de fuite de brouillard par les détails, FX ou sélections.
- Aucune régression tactile (un tap sur une zone d'UI ne donne jamais un ordre au sol).
- Résultats réels renseignés dans `game-studio/resultats-android.md` et joints avec export du banc deux fronts.

## Risques et retour arrière

- Les rigs proches comportent plusieurs objets 3D, susceptibles d'augmenter les draw calls. Profilage Android obligatoire.
- Les nouveaux FX ne doivent pas être considérés comme des événements de simulation ni modifier les PV.
- Si défaut de compilation ou performance, revenir à **J2.1 FIX1**, dernier état confirmé ; le parent 0.2.2 est lui-même non validé. Ne pas promouvoir 0.2.3 comme nouvelle baseline tant que les recettes ne passent pas.
- Pour analyser rapidement le rendu, utiliser le mode Économie qui masque les nouveaux détails et désactive les ombres sans changer les règles.
