# Baseline

## Jalon en cours : J2 (version 0.2.0-j2)

| Champ | Valeur |
|---|---|
| Point de départ | Baseline J1 0.1.0-j1 : archive `sillons-empire-j1-src-0.1.0.zip`, SHA-256 `ca607a2bc9de15c549f8df4173f55d203ec1930cfe6dc89aca7f22d341f9f03a` ; étiquette git `j1-0.1.0`, commit `4def35e` |
| Statut du point de départ | **NON APPROUVÉ** par le créateur (essai S25 Ultra du J1 NOT_RUN). Utilisé comme départ **provisoire** ; toute correction demandée sur J1 sera reportée sur la branche J2. |
| Branche de travail | `j2` (copie dédiée ; `j1-0.1.0` reste intacte) |
| Version livrée | 0.2.0-j2 (versionCode 2), même identifiant de paquet `fr.sillons.empire.j1` (mise à jour par-dessus J1) |
| Archive source | `sillons-empire-j2-src-0.2.0.zip` — SHA-256 dans le fichier `.sha256` livré à côté |
| APK de test | `sillons-j2-debug-0.2.0.apk` — SHA-256 dans le fichier `.sha256` livré à côté |
| Moteur | Godot 4.4.1-stable (officiel), GDScript, rendu Mobile (Vulkan) |
| Environnement de build | Linux x86_64 (conteneur, 4 vCPU Xeon 2,1 GHz, sans GPU), OpenJDK 21, apksigner et zipalign Ubuntu, modèles d'export 4.4.1 officiels, export sans Gradle, arm64-v8a |
| Signature APK | même keystore de debug que J1 (non livré, non secret de production) : l'APK J2 s'installe par-dessus J1 |
| Statut | **NON VALIDÉE** — essai physique S25 Ultra (dont mesures deux fronts) NOT_RUN ; baseline J1 et J2 non approuvées |

Décisions approuvées par le créateur à ce jour : prompt maître, prompts J1 et J2, et **D-07** (conquête :
« ouvrier + moyens + minuteur », tranché le 2026-11-09). Toutes les autres décisions restent provisoires (`decisions.md`).

## Historique

| Version | Statut | Archive SHA-256 |
|---|---|---|
| 0.1.0-j1 | NON VALIDÉE, non approuvée | `ca607a2bc9de15c549f8df4173f55d203ec1930cfe6dc89aca7f22d341f9f03a` |
| 0.2.0-j2 | NON VALIDÉE, non approuvée | voir `sillons-empire-j2-src-0.2.0.zip.sha256` |

## Extension J2.1 — candidate, non encore validée

`0.2.1-j2.1-ui-touch` dérive de cette baseline J2 approuvée comme point de départ par le créateur le 9 novembre 2026. Cette extension ne change pas la simulation ni la roadmap d'âges. Elle reste **NON VALIDÉE** avant compilation, recettes tactiles et essais physiques. Voir `J21-mobile-ui.md`.
