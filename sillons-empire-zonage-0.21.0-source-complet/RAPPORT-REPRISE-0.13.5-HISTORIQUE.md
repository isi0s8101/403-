# Reprise — Sillons d’Empire 0.13.5 candidate

Priorité active : réalisme visuel. Les lots de jouabilité, grandes cartes, politique et révoltes restent à développer après validation de ce rendu.

Base directe : ZIP complet 0.13.4, SHA-256 db7d425a8905c8d563e9f100a14dd346d7830361a58c1823caf6bd10dbd54783. L’archive de base est conservée.

Lire `README-REALISME-0.13.5.md` et `sillons/game-studio/J13-validation.md`. La nouvelle bibliothèque native de 57 modèles complète la bibliothèque de 800 modèles ; les 32 fichiers de `sim/` n’ont pas été modifiés. Les sources sont hors de la racine Godot pour préserver l’ouverture Android sans import GLB.

Points d’intégration : `RealismAssets`, `TacticalModels`, shaders sous `game/realism`, végétation et masques de `WorldView`, éclairage de `game.gd`, globe de `PlanetGlobeView`. Préserver les contrats de brouillard, d’animation et de cache. Les modifications de shader ne doivent pas écrire dans la simulation.

Conserver les réglages `.jpg.import` de la nouvelle matière. Les caches `.godot` ne sont pas une source à livrer. Le rebuild GLB/SCN se fait sur un ordinateur ; les paquets natifs sont prêts dans le projet jouable.

Les preuves Linux/OpenGL ne sont pas une validation Vulkan ou S25 Ultra. Aucun APK ; les limites artistiques des unités héritées et le coût de géométrie supplémentaire restent à traiter. Ne pas qualifier la version de stable ou de photoréaliste complète.

Pour la suite, fournir un ZIP source complet, les migrations utiles, des preuves réellement obtenues et une comparaison de conservation. Le cadrage des évolutions reste distinct du code de cette livraison.
