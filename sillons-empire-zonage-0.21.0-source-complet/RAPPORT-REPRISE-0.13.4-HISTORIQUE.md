# Reprise — Sillons d’Empire 0.13.4 candidate

Priorité : vérifier sur Android le démarrage après suppression de l’import GLB. Lire `README-IMPORT-ANDROID-0.13.4.md` et `sillons/game-studio/J13-validation.md`.

Base directe : archive complète 0.13.3, SHA-256 fb3313033b086e1ee7ba098d2a221e59d6c28004f2b0a102551b4c321d9ac88b. Socle de simulation : archive 0.13.2 fournie, SHA-256 69c4669b14e2b1d4f87580eaac4c6cfd57d3a7cd378df6c40a2ef657753a0ea8.

## Correction

Le projet jouable ne contient aucun GLB. `sources-3d/` est le dossier `sillons/assets_3d/` de la livraison précédente, déplacé hors de `res://` et conservé intégralement. `data/assets_3d.pck` contient 2 400 scènes natives autonomes, 174 images RGBA8 avec mipmaps et les métadonnées. `game/asset_library.gd` monte ce paquet à la demande ; aucune dépendance vers le cache `.godot` de développement. Les fichiers `game-studio/` sont exclus du scan par `.gdignore`.

`tools/prepare-native-assets.py` régénère le paquet depuis les sources sur un ordinateur. Les deux scripts Godot associés préparent et empaquettent les scènes. `tools/verify-native-package.py` contrôle le code réel de chargement depuis un paquet autonome sans cache ni projet source.

## Invariants

Les 32 fichiers `sim/` restent identiques à la 0.13.2. Conserver les règles, âges locaux, stocks, refus sans effet, sauvegardes et déterminisme. Ne pas déplacer les sources GLB dans `sillons/`. Les dotations de capture sont des fixtures, jamais la dotation normale d’une partie.

## Preuves et limites

33 scénarios PASS sous Godot 4.7.2 Linux, import vierge sans GLB, catalogue complet et lancement empaqueté PASS. Deux captures actuelles sous OpenGL logiciel. Journaux : `sillons/game-studio/preuves/import-mobile-0.13.4/`. Les preuves 0.13.3 et le benchmark de rendu sont historiques ; ils ne mesurent pas les FPS sur téléphone.

La cause précise de la fermeture Android signalée n’est pas établie par la capture. Pas de test appareil, pas d’APK, pas de validation Mobile/Vulkan. La version reste candidate. Le travail artistique et les limites métier de la refonte restent décrits dans `RAPPORT-REPRISE-0.13.3-HISTORIQUE.md`.

Livrer les suites sous forme d’archives sources complètes avec manifestes et preuves. Ne pas qualifier la version de stable avant validation Android.
