# Audit de la 0.15.1 R2 — 18 novembre 2026

Archive reçue en 4 morceaux : `sillons-empire-android-performances-0.15.1-r2-source-complet.zip`.

## Ce qui a été vérifié ici (exécuté réellement)

| Contrôle | Résultat |
|---|---|
| Reconstitution des 4 morceaux, SHA-256 attendu `c4c25119…f061b3` | identique |
| `MANIFEST-SOURCE.sha256` : 5 680 fichiers | 0 écart, aucun fichier en trop |
| 15 contrôles statiques `tools/verify-*-static.py` | PASS |
| Import Godot **4.7.2** (`--headless --editor --quit`), aucune erreur de script | PASS |
| `tools/verify-refonte.sh` : les **50 scénarios** annoncés (J9 à J13, évolutions 0.14, interface et orbite 0.15, performances 0.15.1) | **PASS 50/50**, reproduit indépendamment |
| Paquet natif : 800 modèles, 2 400 scènes, contrôle SHA-256 | PASS |

## Ce qui n'a pas pu être vérifié

- **L'APK** (`sillons-empire-test-0.15.1-r2-arm64.apk`) n'était pas dans les fichiers reçus : seule son empreinte est connue.
- **Android et Galaxy S25 Ultra** : rien n'a tourné sur un téléphone, ni ici ni d'après les propres rapports de l'archive (`device_validation: NOT_RUN`).

## Constats

1. **Filiation** : la 0.15.1 descend bien de la 0.13.2 de ce dépôt (elle contient ses recettes J13). Les versions 0.13.3 à 0.15.0 ont été faites ailleurs.
2. **Simulation** : 10 fichiers de `sim/` modifiés depuis la 0.13.2, tous déclarés par le contrôle `verify-refonte-static.py`.
3. **Évolution de la civilisation (avant 0.16)** : deux camps identiques, 10 recherches au total, un passage d'âge = ressources + un objectif simple, pas de choix stratégique d'époque, pas de héros ni de pouvoirs. La recette de progression ne vérifie que les âges III/IV.
4. **IA économique fragile sur la carte de 96 cases** (profil de laboratoire) : sur certaines graines, les ouvriers de l'IA récoltent très peu de nourriture (trajets interrompus vers les fermes, navigation limitée par monde) et les commerces de la colonie revendaient les vivres restants. Sur la carte de 256 cases du jeu, la progression fonctionne (âges IV pour les deux camps en ≈ 9 000 ticks).
5. **Portraits** : 710 photos pour 800 modèles ; la recette des portraits passe (chaque bâtiment et unité du jeu a une image), mais 90 modèles de la bibliothèque n'ont pas de photo.

## Suites données dans la 0.16.0

- Constat 3 : nouveau module d'évolution de la civilisation (voies, monuments, forge, héros, pouvoirs).
- Constat 4 : les commerces gardent désormais un stock de 400 vivres (`J13Rules.FOOD_SALE_FLOOR`) ; la recette IA contre IA de la civilisation tourne sur la carte de 256 cases. Le problème de navigation sur 96 cases reste ouvert.
