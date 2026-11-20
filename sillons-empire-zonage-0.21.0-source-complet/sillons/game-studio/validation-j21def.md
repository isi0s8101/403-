# Validation J2.1-D/E/F — version 0.2.3

## Exécuté dans l'environnement de génération

- `python3 game-studio/verify_j21_static.py` : PASS (test statique).
- `python3 game-studio/verify_j21c_static.py` : PASS (test statique).
- `python3 game-studio/verify_j21def_static.py` : PASS (test statique, compare J2 et J2.1-C).
- Comparaison `sim/` avec ZIP J2 0.2.0 : IDENTIQUE octet par octet.
- Comparaison `game/textures/` avec ZIP J2.1-C 0.2.2 : IDENTIQUE octet par octet.
- Préservation de tous les fichiers du parent J2.1-C : PASS.

## Non exécuté

- Compilation Godot 4.7.2 : **NOT_RUN** (moteur indisponible).
- Shader Mobile / rendu graphique : **NOT_RUN**.
- Scénarios headless GDScript : **NOT_RUN** (scripts ajoutés, pas exécutés).
- Tests tactiles et performance Galaxy S25 Ultra : **NOT_RUN**.
- Export APK Android : **NOT_RUN**.

## Validation attendue par l'utilisateur

Se référer à `J21DEF-unites-batiments-tactile.md` pour les commandes et la recette. Ne pas promouvoir 0.2.3 comme nouvelle baseline avant un retour de test de Godot et du téléphone.
