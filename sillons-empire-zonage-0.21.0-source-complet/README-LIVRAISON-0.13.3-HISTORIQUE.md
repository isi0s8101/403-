# Sillons d’Empire — 0.13.3 — refonte visuelle et mobile (candidate)

Archive source complète issue de la 0.13.2 fournie. Ouvrir **`sillons/project.godot`** dans Godot 4.7.1.

- Menu principal simplifié ; outils de laboratoire conservés dans un écran dédié.
- HUD cohérent, icônes vectorielles, réglages mémorisés, retour Android, panneaux modaux protégés des clics traversants.
- Modèles de la bibliothèque utilisés sur le terrain, pour les stations et pour les transports ; animations des personnages proches.
- LOD statiques et rendu par lots régionaux des unités éloignées, caches bornés, profils graphiques adaptatifs.
- Éclairage et matériaux revus ; globe texturé progressivement, repères R/C/I et calques des services.
- Les **32 fichiers de `sim/` sont identiques octet pour octet à la 0.13.2**. Les coûts, règles, sauvegardes et résultats de simulation sont conservés.

**Validation :** 32 scénarios Godot PASS ; 140 contrôles dans la nouvelle recette de refonte ; 4 contrôles tactiles des panneaux modaux. Les contrôles structurels, le catalogue et les empreintes sont vérifiables par `bash tools/verify-refonte.sh`.

**Mesure locale :** sur une scène de 100 renforts, 1 778 → 137 appels de dessin (−92,29 %) sous OpenGL logiciel. Ce résultat ne mesure pas les FPS Android.

**Limites :** pas d’APK, pas de test sur S25 Ultra, ni de mesures mémoire/chauffe sur Android. La géométrie procédurale héritée reste souvent low-poly ; cette version ne constitue pas une livraison photoréaliste. Les 42 modèles signalés à reprendre et les 220 non revus du catalogue historique restent à traiter. La version reste candidate.

- Détails et utilisation : `sillons/README-REFONTE-0.13.3.md`.
- Galerie des captures du vrai moteur : **`APERCU-VISUEL.html`**.
- Preuves : `sillons/game-studio/preuves/refonte-0.13.3/`.
- Retour arrière : rouvrir l’archive 0.13.2 d’origine avec une copie de la sauvegarde conservée avant les essais.
