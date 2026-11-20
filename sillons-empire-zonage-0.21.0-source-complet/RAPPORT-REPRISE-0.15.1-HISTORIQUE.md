# Reprise — 0.15.1 R2

Base : `sillons-empire-interface-orbite-0.15.0-source-complet.zip`, SHA-256 `094a091a066ac218853465d468d8e2df32a44366a8b6a4b1a452da534404e3a5`.

Cette réédition restaure l’export APK et les diagnostics perdus avec la première session. Le paquet de recette est désormais `fr.sillons.empire.recette.r2`, distinct de la première recette et du jeu historique. La nouvelle signature est une clé de debug locale.

Aucun fichier `sillons/sim/` n’est modifié. Les charges de laboratoire utilisent les mêmes systèmes de simulation et la scène de jeu ; elles n’ouvrent aucune sauvegarde de l’utilisateur. Les trois mondes restent actifs hors écran.

Les 50 scénarios source passent sous Linux, ainsi que trois parcours sur les ressources compilées de l’APK. Le code natif Android n’a pas été exécuté : aucun téléphone connecté. Ne pas déclarer la version stable avant la recette S25 Ultra. Le calcul de trois fronts conserve des pointes CPU.

Voir `README-ANDROID-0.15.1-R2.md`, `sillons/game-studio/resultats-android.md` et les preuves de la R2.
