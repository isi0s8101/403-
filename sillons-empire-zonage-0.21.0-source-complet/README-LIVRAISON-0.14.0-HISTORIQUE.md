# Sillons d'Empire — 0.14.0 candidate

Cette version applique les évolutions du cadrage au jeu Godot et conserve la refonte visuelle 0.13.5 : modèles natifs, matériaux photographiques, relief, eau, végétation et planètes.

## Ouvrir et jouer

1. Décompresser **tout** le ZIP.
2. Dans Godot **4.7.2**, importer uniquement **`sillons/project.godot`**.
3. Lancer le projet puis **Nouvelle campagne · deux systèmes**.

Le dossier `sillons` est le projet jouable. Les fichiers de travail 3D sont conservés dans `sources-3d` et `art-source`, en dehors de `res://`. Le jeu charge deux paquets de scènes natives ; l'éditeur n'a pas à réimporter les milliers de GLB. Les 27 préréglages d'import des textures avec mipmaps sont livrés. Le moteur n'est pas inclus dans le ZIP.

## Commandes principales

- **Ralliement** : sélectionner une caserne achevée, puis **Point de ralliement**. Toucher un terrain libre ou une unité militaire amie. Le drapeau reste visible tant que le producteur est sélectionné. Les recrues suivantes reçoivent ce contrat dès leur création ; les unités déjà parties conservent leur destination.
- **Conseil → Production** : drapeau commun, composition cible, départ par vagues, suspension du recrutement et acheminement interplanétaire. Un transport requiert un vaisseau existant, des ressources, un port et les accès réels. Un bâtisseur doit rejoindre le port pour établir un premier débarquement.
- **Appui long sur le terrain** avec des soldats sélectionnés : marcher, assaut, patrouille, attendre, tenir ou escorter. Les étapes sont sauvegardées.
- **Conseil → Politique** : bien-être, loyauté, causes, fiscalité, autonomie, mobilisation et budget des services. Les quartiers habités ont leur propre bilan, agrégé selon leur population.
- **Conseil → Aménagement** : quartiers R/C/I, eau, énergie, services, recettes industrielles et plafond du gouverneur. Accessible avant les vues spatiales.
- **Conseil → Routes** : glisser le doigt sur l'atlas depuis un district relié ; valider le coût total du tracé. Une erreur refuse l'ensemble du tracé sans débit partiel.
- **Conseil → Diplomatie** : aide, autonomie, fédération, protection, vote de réunification ou occupation militaire. Les conditions de refus et les délais sont affichés.

## Nouvelle campagne

Le joueur débute sur Val dans Sol, l'adversaire sur Némésis dans Proxima. Les deux commencent à l'âge I avec les mêmes dotations. Chacun connaît son système d'origine. La carte tactique principale mesure **256 × 256 cellules**, soit environ **7,1 fois** la surface historique. Les 10 âges et les colonies fondées à l'âge VII local sont conservés.

Le terrain est affiché par secteurs de 32 cellules, à raison de deux créations par frame et 16 maillages résidents au maximum. Les éléments décoratifs proches sont compactés ; le brouillard ne remet à jour que les cellules précédemment visibles. Les mondes occupés restent simulés à chaque tick, même hors écran.

## Politique et sécession

Une crise progresse avec le temps simulé : mécontentement, protestation, ultimatum puis sécession si les engagements ne sont pas tenus. Accepter, contre-proposer ou refuser a des effets vérifiables ; les termes signés ne changent pas silencieusement. Une crise stabilisée bénéficie d'un délai de grâce.

Une planète séparatiste reçoit une identité, sa population, ses réserves locales et ses infrastructures civiles. L'armée régulière, ses centres, casernes, usines militaires et stations gardent leur allégeance. La trésorerie impériale et les convois ne basculent pas. Les milices explicitement locales peuvent rejoindre les insurgés. Aucun soldat ni vaisseau gratuit n'apparaît lors de la sécession.

Le rendement modifie le débit du travail : `clamp(0,75 + 0,005 × bien-être ; 0,75 ; 1,15)`. L'extraction retranche la quantité réellement récoltée du gisement ; l'industrie applique le même débit aux ingrédients et aux produits.

L'aide réserve ses ressources au départ et les livre une fois après transport. L'autonomie et la fédération conservent un gouvernement propre. Le vote de réunification demande un soutien durable. La force exige l'orbite libre, l'absence de commandement et d'armée ennemis, et une garnison près de la capitale pendant 30 secondes ; elle ouvre une occupation. Une trêve arrête les tirs et ne vaut pas permission de débarquer.

## Sauvegardes et compatibilité

La nouvelle campagne utilise une enveloppe V2 avec somme SHA-256, écriture temporaire, remplacement atomique et backup. Les mondes, factions, relations, crises, engagements, stocks, files et missions sont persistés. Le chargeur V1 reste présent : les anciennes parties conservent leurs dimensions 96 et leurs règles historiques. Les scénarios de laboratoire sont conservés.

## Validation et limites

Voir **`sillons/game-studio/VALIDATION-EVOLUTIONS-0.14.0.md`**, les journaux et captures dans `game-studio/preuves/evolutions-0.14.0`.

Cette livraison est le **source complet**, pas un APK. L'ouverture sur appareil Android, les FPS sur téléphone, le tactile matériel, Vulkan et l'export APK ne sont pas validés ici. La recette longue de la nouvelle IA prouve la progression I → IV sans connaissance du système adverse ; elle ne certifie pas encore une partie autonome complète I → X avec toutes les crises et guerres possibles. Le profil 512 est un banc d'essai expérimental, accessible par configuration de simulation, et n'est pas le défaut du menu. L'équilibrage et la capacité maximale de grande campagne restent à mesurer sur l'appareil cible.
