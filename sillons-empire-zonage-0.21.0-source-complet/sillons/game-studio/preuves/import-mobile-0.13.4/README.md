# Preuves actuelles 0.13.4

`tests-godot.json` et les 33 journaux portent sur le paquet livré, sous Godot 4.7.2 Linux. `native-library.json` est l’index intègre inclus dans ce paquet. `cold-import.*` mesure le premier import avec un cache neuf : aucun GLB importé. `packaged-runtime.log` contrôle le chargement réel depuis un paquet autonome, sans sources ni cache.

`menu.png` et `terrain.png` sont deux captures du moteur OpenGL Compatibility/llvmpipe sous Linux, 1280×600. L’avertissement V-Sync signale la limite du pilote logiciel local.

`regeneration-*` valide séparément l’outil de préparation depuis les GLB originaux, avec un import de développement neuf. Ce second paquet de contrôle n’est pas livré. Les identifiants de sous-ressources Godot peuvent faire varier les octets d’une régénération ; les scènes natives livrées ont chacune leur empreinte vérifiée par le scénario `native_assets_test`.

Les preuves du dossier voisin `refonte-0.13.3/` sont historiques. Aucun de ces fichiers ne constitue un essai Android, un APK ou une mesure de FPS sur téléphone.
