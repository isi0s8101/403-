# Interface et carte orbitale — périmètre 0.15.0

L’objectif est de rendre les actions locales immédiatement identifiables et de séparer les échelles de jeu.

| Échelle | Fonction | Commandes |
|---|---|---|
| Terrain | Construction, production et guerre locale | Sélection, déplacement, combat, production, ralliement |
| Planète | Aménagement et politique existants | Conseil et fonctions planétaires conservés |
| Orbite | Théâtre tactique spatial persistant | Flotte, implantations, production, combat, ralliement et départs |
| Système | Observer le trafic local | Sélection et navigation |
| Galaxie | Observer les routes interstellaires | Sélection et navigation |

La simulation orbitale tourne à 10 Hz, y compris hors de la vue active. Elle partage les stocks, les stations et les missions de la campagne. Les coûts et les délais sont ceux des règles existantes. Le basculement de vue ne crée ni ressources ni unités.

L’adversaire commande ses vaisseaux depuis ses capteurs locaux. Les armes respectent leur portée, leur cadence et l’obstacle planétaire. Les stations détruites sont retirées de l’état économique et lèvent le verrou de débarquement correspondant.

L’UI ne facture rien elle-même : elle transmet des commandes au modèle et affiche les refus. Les photos terrestres sont rendues depuis les mêmes modèles que le jeu ; les photos orbitales proviennent du catalogue fourni. Cache limité à 64 textures. Les deux paquets 3D natifs sont conservés, les GLB restent dans les sources externes.

La 0.14 sans positions orbitales est migrée à partir des stocks déjà détenus. Aucune dotation supplémentaire n’est ajoutée. Les sauvegardes 0.15 conservent chemins, intégrité, niveaux, ralliements et emplacements des chantiers en cours.

Les anciennes assertions qui recherchaient un panneau de commandement dans la carte système ou un masquage instantané ont été adaptées aux nouveaux contrats : carte orbitale jouable, observation à grande échelle, fermeture logique immédiate puis animation courte.

Limites de validation : Linux / Godot 4.7.2, rendu OpenGL logiciel. L’Android réel, Vulkan, les batailles maximales et une campagne complète I à X restent à qualifier.
