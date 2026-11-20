# J12 — État des validations

**Périmètre** : les trois modules J12 — commandement galactique, économie par système / fret multi-sauts, gouverneur Android — sont ajoutés aux sources et aux recettes.

**Validé dans cet environnement** : tests structurels Python, syntaxe des scripts shell, integrity ZIP/manifest SHA-256, conservation des fichiers hérités.

**NON validé** : import Godot, GDScript compilé, scénarios `lab/j12_empire_test.gd` et `lab/j12_perf_test.gd` réellement exécutés, génération APK, lancement S25 Ultra, FPS et mémoire à chaud. Ces contrôles requièrent Godot et un poste SDK Android. Leur état est `NOT_RUN` et ils bloquent une certification J12 stable.

Les tests de recette à lancer sur la machine Android sont décrits dans `README-J12.md`. En cas d'échec, conserver les logs et ne pas modifier la baseline J11.
