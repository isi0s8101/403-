# Validation 0.13.4 — candidate

Session du 14 novembre 2026. **Godot 4.7.2.stable.official.ed1daf0bf**, Linux x86_64.

| Contrôle | Résultat |
|---|---|
| Import éditeur sans cache | PASS, 0 import GLB ; 12 images/icônes (24 fichiers de cache) |
| Bibliothèque native | PASS 800 modèles, 2 400 scènes, 174 images |
| Dépendances externes des scènes | 0 ; aucun besoin du cache `.godot` d’origine |
| Jeep `veh.ground.jeep.a07` de la capture | Instanciée sans import GLB |
| Scénarios historiques et nouveaux | **33/33 PASS**, aucune erreur de script relevée |
| Recette intégrale J1–J8 | PASS 202/202 |
| Colonies / approvisionnement J13 | PASS 128/128 et 22/22 |
| Recette de refonte / parcours tactile modal | PASS 140/140 et 4/4 |
| Nouvelle recette bibliothèque native | PASS 9/9 |
| Chargement depuis un paquet de jeu autonome | PASS ; code réel `AssetLibrary`, sans projet source ni cache |
| Simulation comparée à la 0.13.2 | 32 fichiers identiques |
| Contrôles structurels, catalogue et empreintes | Voir `validation-statique.json` et les journaux |
| Captures actuelles | Menu + terrain, OpenGL Compatibility, llvmpipe, 1280×600 |
| Sonde GPU héritée J2.1-C | 1 SKIP headless |
| Test appareil Android / export APK / FPS / RAM / chauffe | **NOT_RUN** |

Dans `preuves/import-mobile-0.13.4/` : les 33 journaux, résultats JSON, import vierge, empreintes natives, test de chargement empaqueté et deux captures actuelles. Les 12 captures et le benchmark 0.13.3 dans `preuves/refonte-0.13.3/` sont historiques.

L’import vierge a duré 6,285 s dans cet environnement Linux sans écran. Ce chiffre, comme sa mémoire de processus, n’est pas une mesure Android. La capture utilisateur ne confirme pas la cause précise de la fermeture. Ce correctif supprime l’étape d’import GLB observée ; il reste à valider sur le téléphone.

Les validations antérieures sont archivées dans `J13-validation-0.13.3-HISTORIQUE.md` et `J13-validation-0.13.2-HISTORIQUE.md`. La version ne doit pas être qualifiée de stable.
