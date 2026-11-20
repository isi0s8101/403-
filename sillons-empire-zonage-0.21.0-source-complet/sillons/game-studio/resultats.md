# Résultats J2 — 2026-11-09 (version 0.2.0-j2)

Environnement : Godot 4.4.1-stable officiel, Linux x86_64 (conteneur de build, 4 vCPU Xeon 2,1 GHz), sans GPU.
Départ : baseline J1 0.1.0-j1 **non approuvée** (départ provisoire).

| Catégorie | Contrôle | Statut | Preuve |
|---|---|---|---|
| Tranche jouable | Âge III, palissade, fort, atelier, canon ; siège d'un passage fortifié pendant qu'un second combat progresse hors écran ; IA qui choisit un autre accès | PASS (laboratoire et écran deux fronts) | R11-R16, `preuves/captures_j2/`, `preuves/deux_fronts/` |
| Automatisé | Recette de siège : tenir (R11), ouvrir par un siège et naviguer après destruction (R12), route alternative (R13) | **PASS** | `preuves/labo_j2/r11…r13*.log` |
| Automatisé | Âge III configurable (R14), délégation par un autre accès (R15), contraintes d'artillerie (R16), minuteur D-07 (R05e) | **PASS** | `preuves/labo_j2/` |
| Automatisé | Contrôles J1 rejoués : passage I→II (R03, R03b), collecte (R01, R02, R02b), conquête (R05-R05d, R10), délégation (R04), IA (R06, R06b), ouvertures (R07, R08), déterminisme (R09) | **PASS** | `preuves/labo_j2/resume.txt` |
| Automatisé | Laboratoire complet : **23 scénarios, 99 assertions** | **PASS** | `preuves/labo_j2/resume.txt` |
| Automatisé | Invariance deux fronts (empreintes à chaque tick, événements, ordres, états individuels ; 4 comparaisons + contrôle négatif) | **PASS** | `preuves/deux_fronts/invariance.txt` |
| Automatisé | Comparaison de réglages de navigation (budget de chemins, même graine) | PASS — 24 retenu | `preuves/comparaison_reglages.txt` |
| Automatisé | Recette tactile J1 (8 vérifications) | **PASS** | `preuves/tactile_j2.txt` |
| Export APK | APK de debug arm64-v8a, signé v1+v2+v3 (même clé que J1), vérifié, versionName 0.2.0-j2 | **PASS** | `preuves/apksigner-verify-j2.txt` |
| Essai physique | Recette B1-B10 sur Galaxy S25 Ultra, dont mesures deux fronts à 4 niveaux | **NOT_RUN** — prérequis : l'appareil ; procédure : `recette.md` §6 | — |
| Approbation | Baselines J1 et J2 | **NOT_RUN** — décision du créateur | — |

**Statut de livraison : NON VALIDÉE** (mesures physiques S25 Ultra obligatoires NOT_RUN ; baselines non approuvées).

APK : `sillons-j2-debug-0.2.0.apk`, 27 313 595 octets, SHA-256 `3ee0dac85fe029e39a1cf22c8927eb2929517763b4abefa22ee6aee71c784569`.

## Chiffres clés du laboratoire

- R11 : l'IA (6 lanciers, 6 tireurs, sans artillerie) assiège la palissade (70,67) sous le feu du fort, 16 % de pertes à
  60 s, abandonne à 77 s (« siège sans artillerie trop coûteux »), réévalue « Préparer l'artillerie » ; forts intacts,
  aucune unité n'a franchi.
- R12 : avec 3 canons, palissade détruite, « passage ouvert » à 39,8 s, franchissement à 83 s (9 unités côté sud-ouest).
- R13 : gué sud-est fermé → « route alternative : détour de 538 % (passage direct bloqué) », aucun siège, cible détruite.
- R16 : mise en batterie visible à 1,5 s, aucun dégât à 2,5 s, 210 dégâts au premier tir, recul au contact.
- R05e : centre détruit à 1 s, délai annoncé, camp toujours en jeu à 15 s (moyens présents), éliminé au contrôle de 26 s (minuteur réduit à 20 s pour le test ; 180 s en partie).

## Deux fronts (conteneur, simulation seulement)

Voir `mesures-rendu.md`. Les mesures de rendu, de fluidité, de mémoire sur l'appareil et de chauffe sont NOT_RUN.

---

# Résultats J1 — 2026-11-09

Environnement : Godot 4.4.1-stable officiel, Linux x86_64 (conteneur de build, 4 vCPU), sans GPU.
Captures : rendu Mobile Vulkan via llvmpipe (logiciel) — représentatives de l'image, **pas** des performances.

| Catégorie | Contrôle | Statut | Preuve |
|---|---|---|---|
| Tranche jouable | Escarmouche âges I-II contre l'IA, carte, deux ouvertures, conquête | PASS (en laboratoire et en démonstration IA contre IA) | `preuves/captures/`, R07, R08, R10 |
| Automatisé | Laboratoire, 16 scénarios, 67 assertions | **PASS** | `preuves/labo/resume.txt`, `preuves/labo/*.log` |
| Automatisé | Déterminisme (R09, 2 exécutions) | **PASS** | empreinte `de1a90c9a6e0d910…` identique |
| Automatisé | Recette tactile (8 vérifications) | **PASS** | `preuves/tactile.txt` |
| Automatisé | Démarrage sans erreur de script (menu, partie, zone témoin) | **PASS** | exécutions headless sans erreur |
| Export APK | APK de debug arm64-v8a, signé v2+v3, vérifié | **PASS** | `preuves/apksigner-verify.txt` |
| Essai physique | Recette A1-A13 sur Galaxy S25 Ultra | **NOT_RUN** — prérequis : l'appareil ; procédure : `recette.md` §3 | — |
| Mesures | Zone témoin et partie sur S25 Ultra | **NOT_RUN** | procédure A11-A12 |
| Approbation | Baseline J1 | **NOT_RUN** — décision du créateur | — |

**Statut de livraison : NON VALIDÉE** (essai physique obligatoire NOT_RUN).

APK : `sillons-j1-debug-0.1.0.apk`, 27 258 777 octets,
SHA-256 `bfaa61f35e26af3cb31c158e718f7d2de98706fa0dfdffa7725653216d1c9dd8`.

## Mesures indicatives (conteneur, non représentatives du S25 Ultra)

- Coût de simulation : 0,4 à 1 ms/tick en début de partie, ≈ 2 à 3,5 ms/tick vers 10-14 min avec ≈ 60 à 100 unités
  (durées des scénarios R07/R08/R10 et compteur en jeu). À 10 ticks/s, cela représente 1 à 3,5 % d'un cœur.
- Partie IA contre IA R10 : conquête à 41 min 24 (graine 2001) — profil prototype, la cible 60 min+ concerne le jeu complet.
- Rendu (llvmpipe, sans GPU) : 370 à 800 appels de dessin selon la scène ; les FPS mesurés ici n'ont pas de valeur.

## Retour utilisateur

À recueillir pendant la première partie guidée par le jeu (A13). Aucune correction d'interface ne peut être
validée avant ce retour.
