# Audit local PWA iOS standalone — 17 septembre 2026

Le symptôme signalé concerne l’icône d’accueil iPhone, pas l’onglet Safari.
Les tests ci-dessous sont locaux et simulés : aucun iPhone physique ni Safari iOS
installé n’a été piloté. La cause globale des ralentissements n’est donc pas prouvée.

## Protection du travail existant

Inventaire initial : `git status --short`, `git diff --check`, `git diff --stat`,
`git diff --name-status`. Quinze fichiers déjà modifiés, dont une suppression,
411 insertions et 796 suppressions. Aucun de ces quinze fichiers n’a été édité
pour cet audit. Aucun reset, checkout, stash, commit, push, déploiement ou accès
en écriture aux données Firebase. Aucun changement des requêtes Firestore.

## Constats et correctifs

| Axe | Constat et traitement |
| --- | --- |
| Arrière-plan/reprise | Gestion de `pagehide` et `pageshow` ajoutée aux événements existants. Annulation du délai en arrière-plan et vérification de la visibilité à son expiration. |
| Focus et réseau | Un focus de PWA déjà visible ne reconstruit plus les abonnements. `online` reste une raison de reprise. Le comportement focus de l’onglet Safari est conservé. |
| Listeners/timers | Avant : trois abonnements Web, déjà détachés avant rattachement. Après : cinq, un propriétaire, un timer annulable. Aucune fuite initiale de listeners prouvée. Test de 20 cycles avec rattachement : cinq actifs, puis zéro après detach. |
| Coordonnées tactiles | Aucune transformation CSS du viewport ou conversion manuelle des coordonnées ajoutée. Vidéo décorative protégée par `IgnorePointer` et `pointer-events: none` côté DOM, sans désactiver les contrôles HTML natifs éventuels. |
| Viewport/SafeArea/orientation | Le moteur Flutter 3.41.7 local écoute déjà `visualViewport.resize` (ou window), et utilise les dimensions du document sur iOS. Pas de second listener resize applicatif. Test paysage et SafeArea sur les boutons. Le manifeste reste portrait-primary ; vérification réelle iOS encore nécessaire. |
| Overlays | Loading déjà non interceptant et retiré. Bannières d’installation absentes en standalone dans les tests JavaScript. Boutons Flutter réellement frappés dans les tests widgets. Les notifications sont des bannières localisées ; aucun overlay global bloquant identifié dans cette lecture. |
| Vidéo/mémoire | Contrôleur désormais détaché et libéré dès fin, Passer ou Retour, sans attendre la destruction du widget. Vérifications après chaque attente d’initialisation, traitement de hidden, timeout de cinq secondes pour une activation sonore sans réponse. Tests de libération unique, y compris initialisation en cours. |
| Ancienne/nouvelle installation | Détection par display-mode ou navigator.standalone ; reconnaissance iPadOS ajoutée au shell. Tests avec anciens workers et sans worker. L’intro dépend déjà d’une préférence locale par version : une ancienne installation peut donc suivre un chemin différent. Aucune préférence utilisateur effacée. |
| Cache/service workers | Le code existant désinscrivait tout worker hors scope FCM. Il ne cible désormais que les registrations dont tous les workers présents sont identifiés comme flutter_service_worker.js de même origine. Firebase Messaging, workers inconnus et registrations mixtes sont préservés. Aucun cache supprimé, aucun rechargement forcé ajouté. |

Le lecteur alternatif `WebIntroPlayer` conserve un risque de libération manquante,
mais n’est pas utilisé par le démarrage courant (`main.dart` utilise
`IntroVideoScreen`). Il n’est pas modifié. Les deux fichiers intro.mp4 font chacun
1 919 925 octets ; cela ne mesure pas la mémoire vidéo décodée. Aucune fuite mémoire
sur appareil n’est démontrée.

## Avant / après des reprises

| Situation | Avant | Après |
| --- | --- | --- |
| Rafale visible/focus/online dans 700 ms | Déjà un appel regroupé | Un appel regroupé, pageshow inclus |
| Focus seul, PWA déjà visible | Peut relancer la reconnexion | Aucun appel |
| Focus tardif après une reprise achevée | Peut lancer une seconde reconnexion | Aucun second appel |
| 20 cycles simulés | Pas de mesure appareil initiale | 20 reprises et 20 pauses, jamais plus de cinq listeners |
| Timer arrivé après perte de visibilité | Pas de nouvelle vérification à l’expiration | Reprise refusée |

La temporisation Firestore de 750 ms reste inchangée. Les chiffres ci-dessus
concernent les callbacks Web, pas un comptage des abonnements Firebase en production.

## Diagnostic et confidentialité

`PwaDiagnostics` est désactivé par défaut. Quand explicitement activé dans les tests,
il ne conserve que deux compteurs entiers, événements et reprises. Pas de texte
arbitraire, identité, UID, message, motif, photo, token, donnée familiale, stockage,
envoi réseau ou journal console. Aucun diagnostic activé dans le raccordement Web.

## Vérifications

- `dart format` exécuté sur les six fichiers Dart concernés.
- `flutter test --no-pub` : 357 tests réussis lors de la dernière passe complète.
- `git diff --check` sans erreur ; avertissements de conversion LF/CRLF seulement.
- Tests ciblés Flutter : 24 réussis, incluant standalone, 20 cycles, regroupement,
  Passer, son, Retour, libération vidéo, orientation et diagnostic.
- `node --test tool/pwa_shell.test.cjs` : 4 réussis ; JavaScript exécuté dans un DOM
  simulé, pas dans Safari réel.
- `flutter analyze --no-pub` : zéro erreur, 68 warnings et 133 informations,
  soit 201 diagnostics. La commande reste en échec à cause des warnings.
  Le fichier Web conserve notamment la dépréciation préexistante de dart:html.
- `flutter build web --release --pwa-strategy=none` : réussi. Option pwa-strategy
  dépréciée ; trois signalements de compatibilité Wasm dans flutter_tts, non
  bloquants pour cette compilation JavaScript.

## Validation restante sur iPhone

Comparer une installation ancienne et une installation neuve sur appareil de test,
sans supprimer les données de l’installation familiale existante. Vérifier 20
retours arrière-plan, verrouillage/déverrouillage, perte/retour réseau, rotation,
ouverture/fermeture du clavier, Passer, son et Retour. Observer le viewport et
la cible des taps avec l’inspecteur Safari ; comparer la mémoire avant/après intro.
Une désinscription de worker ne remplace pas à elle seule la page déjà en cours :
une ancienne instance peut continuer à exécuter son ancien JavaScript jusqu’à sa
fermeture. Les hypothèses restantes sont cet état ancien et les différences de
viewport/composition WebKit après suspension. Aucun déploiement effectué pour ce test.
