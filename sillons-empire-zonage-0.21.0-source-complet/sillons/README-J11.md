# Sillons d'Empire — J11, version 0.11.0 (candidate)

## Périmètre réalisé

Cette livraison repart de la **version J10 0.10.0**, sans reconstruire le RTS historique.

- `GalaxyGenerator` génère **16 systèmes** (Sol, Proxima et 14 supplémentaires) et un réseau de routes connecté, reproductible par seed. Le nombre de systèmes est **une cible de cette candidate**, non une promesse de galaxie infinie.
- `StarSystemGenerator` conserve les identifiants de Sol/Proxima, leurs planètes et lunes J10, et ajoute 2–3 planètes et éventuellement une lune par nouveau système. Les mondes vierges ne sont instanciés qu'à la demande.
- Un brouillard de guerre **séparé par camp** masque le nom et l'état des étoiles inconnues. Sol et Proxima restent connus pour compatibilité J10.
- L'exploration interstellaire exige l'âge X, un chantier orbital achevé dans un système connu, une **route directe** vers un système inconnu, 90 nourriture + 240 minerai et un temps de vol de sonde. Les sondes ne créent pas de colonie.
- Les expéditions nécessitent une route directe entre deux systèmes connus, une frégate et une cargaison explicite. Le déplacement est simulé par ETA ; deux missions en sens inverse sur la même route sont susceptibles d'interception, même si leurs planètes d'origine diffèrent.
- Les voyages de plusieurs liaisons se font **par étapes**, en installant des relais sur les systèmes intermédiaires ; l'acheminement automatique multi-sauts est prévu pour J12.
- Le contrôle d'un système est calculé à partir de centres de commandement réels : neutre, allié, ennemi ou contesté. La découverte ne vaut jamais conquête. Les combats se poursuivent hors écran.
- La navigation tactile devient **surface → globe → orbite → système → galaxie**, puis retour par zoom. La carte galactique réutilise les transports simulés et limite à 48 les marqueurs visibles.
- Les sauvegardes incluent découvertes, sondes, mondes instanciés et vols en cours. Les instantanés de la J10 restent lisibles ; aucune conversion destructive n'est appliquée.

## Essai manuel Android

1. Ouvrir **« J11 · Laboratoire galactique · âge X »** dans le menu principal.
2. Dans la partie, ouvrir **SECTEURS → CARTE GALACTIQUE**, ou dézoomer surface → globe → orbite → système → galaxie.
3. Toucher une étoile grise reliée à Sol et choisir **Envoyer une sonde**. L'atelier doit contenir un chantier orbital allié. Vérifier le prélèvement des ressources et l'ETA.
4. À la fin de la mission, l'étoile doit afficher son nom et devenir accessible. Zoomer dessus, choisir une planète. Aucun centre allié ne doit y exister avant débarquement.
5. Depuis une planète dotée d'un chantier orbital, choisir une planète du système voisin dans la carte système et **Préparer une expédition** avec une frégate et un ouvrier.
6. Vérifier que la colonie n'apparaît qu'à l'arrivée du convoi, puis que la couleur du système reflète le contrôle effectif.
7. Sauvegarder au milieu d'une exploration et d'un trajet. Charger et vérifier les mêmes ETA, mêmes découvertes, mêmes armées.
8. Contrôler en vitesse 0,5×, 1×, 2×, 4× et 8×, y compris la fluidité du zoom et la stabilité à chaud sur Galaxy S25 Ultra.

## Recette automatisée

Depuis `sillons/` :

```bash
./tools/verify-j11.sh
./tools/export-android-j11.sh
```

`verify-j11.sh` lance les audits statiques hérités, importe le projet avec Godot, puis lance les scénarios de régression J9/J10 et les scénarios J11. Sans Godot, il s'arrête avec **127** après les contrôles statiques, en affichant `J11_RUNTIME=NOT_RUN`. L'APK ne peut alors pas être produit.

## Limites véridiques de la candidate

- La carte est une galaxie locale de **16 systèmes**, pas un univers infini. L'extension du nombre d'étoiles et le streaming galactique global sont des travaux ultérieurs.
- Les nouvelles planètes utilisent encore une **région tactique 96×96** ; l'atlas régional J9 traversable n'est pas encore généralisé sur tous les mondes J10/J11.
- Les combats spatiaux sont des interceptions déterministes de convois, **pas des batailles 3D de frégates pilotables**.
- Le modèle économique reste à **stocks par camp partagés entre planètes**, hérité des J6–J10 ; logistique galactique locale et approvisionnement intersystème seront à traiter au J12.
- Une route longue nécessite des missions de proche en proche ; il n'existe pas encore de gestionnaire de flotte multisaut ni d'IA galactique exhaustive.
- La compilation Godot, l'export Android, le FPS et la chauffe sur téléphone doivent être vérifiés sur un environnement équipé. Les contrôles statiques ne prouvent pas l'absence de bugs à l'exécution.

## Fichiers J11 centraux

- `procgen/galaxy_generator.gd`
- `procgen/star_system_generator.gd`
- `sim/star_campaign.gd`
- `sim/campaign_save.gd`
- `views/galaxy_map_view.gd`
- `views/galaxy_map_hud.gd`
- `game/game.gd`
- `lab/j11_galaxy_test.gd`
- `lab/j11_ui_test.gd`
- `tools/verify-j11.sh`
- `tools/export-android-j11.sh`
