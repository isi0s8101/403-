# Rapport de reprise — Sillons d'Empire 0.18.0 (ville de l'âge de l'électricité, paysage et portrait)

Pour reprendre le travail dans une nouvelle session. Version précédente : `RAPPORT-REPRISE-0.17.0-HISTORIQUE.md`.

## Où en est le projet

- Version **0.18.0-ville-candidate** (code Android 180). Projet : `sillons/project.godot`, **Godot 4.7.2**, rendu Mobile, orientation **capteur**.
- Base : 0.17.0 (58 scénarios sur 58). Audit avant modification : `AUDIT-URBAIN-0.17.0.md` (avec les décisions de l'auteur).
- Le jeu fourni en référence (APK) n'a été ni décompilé ni réutilisé : seules les règles habituelles du genre servent de repère.

## Ce que la 0.18.0 ajoute

**Simulation (par composition, crochets d'une ligne)**
- `sim/urban_rules.gd` (UrbanRules) : tables de la ville, toutes **PROVISOIRES**.
- `sim/urban_city.gd` (UrbanCity) : activée après la recherche `electricite` (usine, âge IV) dans les parties avec évolution de la civilisation (ou règle de laboratoire `urban`). Bascule (`_switch`) : maisons → `zone_r` (places conservées), fermes arrêtées, récolte stoppée après dépôt. Calcul toutes les 20 ticks (`_update`) : électricité (sources, postes en chaîne, délestage par priorité), eau, services (rayon + capacité, plus proches d'abord), pollution, criminalité, incendies, santé / épidémies, croissance des zones, emplois, production, bien-être (7 facteurs) et productivité. État dans `Building.city` et `Team.city` (sauvegardés). Tirages par hachage (`roll`) : partie reproductible.
- `sim/urban_ai.gd` (UrbanAI) : ville de l'IA par les commandes `build` et `urban_upgrade`, une décision toutes les 2 s au plus.
- Crochets : `sim/sim_world.gd`, `sim/ai_controller.gd`, `sim/civ_evolution.gd`, `sim/modern_systems.gd`, `sim/unit_commands.gd`, `sim/rules.gd` (bâtiments `urban: true`, recherche).

**Interface**
- `interface/city_panel.gd` (panneau Ville), `interface/city_overlay.gd` (vues au sol et rayon pendant la pose) ; fiche de zone dans `interface/building_drawer.gd` ; alertes dans `interface/alert_feed.gd` ; modèles existants (`game/tactical_models.gd`), flammes (`game/world_view.gd`).
- `interface/responsive_layout.gd` (ResponsiveLayout) : base d'échelle selon le sens de l'écran (1280×600 / 600×1280), plafond 115 % en portrait, mémoire de la disposition paysage et application d'une disposition portrait.
- `game/hud.gd` : `apply_orientation`, `_portrait_specs` (table des positions portrait), `_portrait_top` (hauteur réelle de la barre du haut), recalcul à chaque redimensionnement en portrait. `game/game.gd` : vue plus plongeante en portrait (`portrait_view`). Menus, globe, orbite, départ planétaire : `_apply_orientation` locaux.

## Vérifier

```
cd sillons
GODOT_BIN=godot bash tools/verify-refonte.sh      # statique (17 suites), import, compilation, 61 scénarios
python3 -I tools/verify-urbain-static.py          # contrôle statique 0.18 seul
```
Les 3 recettes 0.18 : `urban_city`, `ui_city`, `ui_portrait`. Après toute modification : `git add` puis `python3 -I tools/update-manifest-j13.py`.
Captures : `tools/capture-ui-017.gd` (modes 0.18 : `ville`, `ville_vue`, `ville_panneau`) ; pour le portrait, lancer xvfb et Godot en `--resolution 740x1600`.

## Ce qui reste (honnêtement)

- **Android : NOT_RUN** (recette manuelle dans `sillons/game-studio/VALIDATION-VILLE-0.18.0.md`). La rotation a été simulée en changeant la taille de la fenêtre.
- **Équilibrage** : toutes les valeurs de la ville sont provisoires ; une partie complète doit servir à les régler (vitesse de croissance, production, fréquence des incendies, coût des services).
- **Ville et globe** : l'économie planétaire du globe (J13, colonies dès l'âge VII) reste séparée de la ville de la carte de bataille.
- **Routes** : la ville n'a pas de réseau routier ; la desserte se fait par rayon d'action.
- **Portrait** : l'échelle 130 % est ramenée à 115 % ; les écrans orbite / système / galaxie sont lisibles mais gardent leur disposition d'origine resserrée.
- Points restants de la 0.17.0 (voir le rapport précédent) : planche des âges VI à X à capturer, mesure chiffrée des performances, commandes complètes sur le globe et dans l'espace.
