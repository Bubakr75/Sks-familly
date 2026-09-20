**Validation locale SKS Family — cible 4.8.11+524**

## Validation finale avant publication — 20 septembre 2026

Version source : **4.8.11+524**. Branche : `main`. Contrôle initial après `git fetch origin --tags --prune` : `HEAD...origin/main = 0 0`, référence `b0ad7627e504f0322e160d4c392d69e3e31caefb`. Toutes les modifications locales précédentes sont conservées et finalisées. La présente section décrit les résultats acquis avant le commit ; elle ne prétend pas que les déploiements ou la Release ont déjà eu lieu. Les preuves de production et de signature seront fournies dans le compte rendu de livraison.

### Résultats après changement de version

Journaux hors dépôt : `C:/Users/b2osi/AppData/Local/Temp/sks-release-524`.

| Commande | Code natif | Résultat |
| --- | ---: | --- |
| `dart format` sur les 6 fichiers Dart modifiés | 0 | 6 fichiers vérifiés, 2 reformatés |
| `git diff --check` | 0 | Aucun défaut d'espacement |
| `flutter analyze --no-pub` | 1 | 0 erreur, 68 avertissements, 132 informations ; les 200 diagnostics sont identiques à HEAD après neutralisation des positions ligne/colonne |
| `flutter test --no-pub --reporter json` | 0 | 360 tests réussis, 0 échec, 0 ignoré |
| `npm.cmd test` dans `functions` | 0 | 81 tests réussis, 0 échec, 0 ignoré, 0 annulé, 0 todo |
| `npm.cmd run test:rules` dans `functions` | 0 | 96 tests réussis, 0 échec, 0 ignoré, 0 annulé, 0 todo |
| `node --test tool/pwa_shell.test.cjs` | 0 | 4 tests réussis, 0 échec, 0 ignoré |
| `flutter build web --release --no-tree-shake-icons --pwa-strategy=none` | 0 | Build Web réussi avec les options du workflow |
| `flutter build apk --debug` dans la copie temporaire décrite ci-dessous | 0 | APK debug compilé ; package `com.bubakr.sks_family`, versionName `4.8.11`, versionCode `524`, vérifiés par `aapt dump badging` (code 0) |
| `node --test functions/web_shell.test.js` après finalisation du workflow | 0 | 6 tests de contrôle du shell/workflow réussis, déjà inclus dans les 81 Node ; ne pas les additionner au total unique |

Total unique : **541 tests réussis**. Les 96 tests Emulator incluent les 8 Storage, 15 point_actions et 3 nouveaux scénarios de rattachement (rejeu concurrent du déclencheur, panne push, répétition de requestFamilyJoin). Le premier essai de la suite étendue avait 92 réussites et 3 échecs : le contexte VM isolé du test produisait des Promise non reconnues par le SDK Firestore. Le chargeur du test utilise désormais le même contexte JavaScript que ce SDK, toujours avec FCM simulé et Firestore réel local. Aucune assertion assouplie, aucun test ignoré. La suite complète relancée passe à 96/96 après ajout du scénario requestFamilyJoin.

L'APK debug est généré dans `sks-release-524/android-debug-source`, copie temporaire des sources sans clés, keystore, `key.properties` ni `local.properties` du dépôt. La signature debug y est désactivée dans la copie de `build.gradle.kts`, afin de ne créer ni rechercher de clé. Aucun fichier Android de configuration/signature du dépôt n'est modifié. Cet APK non signé vérifie la compilation, pas l'installation ; seul GitHub Actions doit produire l'APK signé de livraison.

`build/web/version.json` contient exactement :

```json
{"app_name":"family_score","version":"4.8.11","build_number":"524","package_name":"family_score"}
```

Le service worker `firebase-messaging-sw.js` est conservé. La stratégie PWA reste `none`. Les trois avertissements Wasm de `flutter_tts` et la dépréciation de `--pwa-strategy` ne bloquent pas le build JavaScript. Les empreintes du build local sont enregistrées hors Git dans `web-local-sha256.json`. Le workflow utilise Flutter 3.41.4, l'environnement local 3.41.7 ; le workflow ajoute aussi son horodatage/commit dans index.html. Une identité binaire entre ces deux compilations n'est donc pas présumée : l'artefact exact du workflow Hosting est désormais conservé pour comparer ses empreintes aux fichiers servis.

### Contrôle fonctionnel et autorisations

- **Demande iPhone absente** : les anciennes règles réservaient la lecture `join_requests` au propriétaire/gestionnaire, alors que le client parent écoutait cette collection. Le push ciblait uniquement le propriétaire. La lecture est maintenant permise aux parents actifs et le push cible les destinataires autorisés. L'écoute Firestore alimente la boîte indépendamment de FCM ; la panne FCM est testée sans appel à une vraie famille.
- **Notifications réapparaissant** : le retrait d'affichage n'était pas conservé par utilisateur dans les données serveur et les chemins de fusion/restauration pouvaient réintroduire la demande. Le bouton appelle désormais `dismissFamilyNotification`, qui ajoute l'UID à `dismissedBy` et met à jour la date, sans refus de demande, remboursement ou suppression d'événement.
- **Persistance** : `dismissedBy` traverse la sérialisation du modèle ; le cache Hive est indexé par famille, UID et identifiant. Filtrage après fusion des snapshots, dans la liste exposée et dans la restauration des achats ; rechargement du cache au démarrage. Contrôle du code et suite Flutter réussie, sans prétendre à un essai manuel sur iPhone physique.
- **Droits de lecture/masquage** : owner cohérent, parent actif, manager/familyAdmin actif avec identité durable vérifiée. Enfant, membre inactif, non authentifié, UID incohérent, faux owner, autre famille et gestionnaire non vérifié refusés. Le demandeur conserve uniquement la lecture de sa propre demande. Les décisions d'approbation/rejet restent selon la politique serveur existante : propriétaire/gestionnaire autorisé ; la simple lecture parentale ne confère pas un nouveau droit d'administration.
- **Source d'autorité** : lecture réelle de `families/{familyId}` et `members/{uid}` ; aucun rôle transmis par le client n'est utilisé comme preuve. Pour le push des managers/familyAdmin, vérification supplémentaire du compte Firebase Auth (non désactivé, email vérifié, fournisseur durable).
- **Idempotence** : requestFamilyJoin utilise le document de l'UID et une transaction ; un rejeu conserve la demande. Le déclencheur réserve l'envoi via `notificationEventId` en transaction et déduplique les tokens. Il exclut l'appareil demandeur et transmet `sender`. Le masquage est transactionnel, rejouable et limité à 100 UID, y compris sous concurrence.
- **Limite du push** : l'envoi est réservé au plus une fois ; une panne après réservation peut empêcher la bannière, mais ne retire jamais la demande de la boîte. La disponibilité de la demande repose sur Firestore, pas sur une garantie de livraison FCM.
- **Confidentialité** : le texte push ne reprend plus le nom libre de l'appareil ni un nom familial. Les données de routage restent `sender`, `type`, `requestId`, `familyId` ; aucun code famille, email, secret ou contenu familial dans le message. Aucun changement du client Firebase Messaging, de ses permissions ou du service worker.

Audit limité aux règles `join_requests` modifiées :

```json
{"score":5,"summary":"Lectures limitées aux membres actifs cohérents avec les identités vérifiées requises ; le demandeur ne lit que sa demande. Toutes les écritures clientes restent interdites. Contrôles confirmés sur émulateur.","findings":[]}
```

### Ordre de publication préparé

Exports réellement vérifiés dans `functions/index.js` : `requestFamilyJoin`, `onJoinRequestCreated`, `dismissFamilyNotification`, **`markFamilyInboxRead`**. Les quatre sont concernés par la livraison ; région attendue `us-central1`. Puis déploiement `firestore:rules`. `storage.rules` est inchangé et ne doit pas être redéployé.

Le workflow Android était déclenché par tout push main et créait immédiatement tag/Release. Il est désormais déclenché par le push d'un tag `v*`, vérifie sa concordance avec pubspec, produit l'APK avec les secrets existants et vérifie version, package, absence de REQUEST_INSTALL_PACKAGES et identité du certificat avec l'APK officiel précédent. La Release stable utilise le nom demandé et l'APK `SKS-Family-4.8.11-build524.apk`.

Le push main déclenche uniquement le workflow Hosting. Aucun workflow ne déploie automatiquement les Functions ou les règles. Le workflow Functions reste manuel et ne sera pas lancé en doublon. Le tag `v4.8.11+524` ne sera poussé qu'après vérification des services et du Web. Aucun Play Store.

Contrôle des fichiers suivis : aucun `android/key.properties`, `android/local.properties`, keystore/JKS, APK/AAB, build/, journal temporaire, fichier TEMP ou clé de compte de service. Aucun secret détecté par les motifs de clés privées/tokens recherchés. Aucun secret local n'a été affiché ni ajouté. Les fichiers utiles seront ajoutés explicitement, sans ajout global du répertoire de travail.

## Reprise du 17 septembre 2026 — résultats actuels

Les validations ont été exécutées jusqu'au bout : **538 tests réussis, 0 échec, 0 ignoré** (360 Flutter + 81 Node + 4 PWA + 93 Firestore/Storage). Le build Web de production est réussi. L'analyse Flutter reste au **code 1**, avec **0 erreur, 68 avertissements et 132 informations**, tous déjà présents dans la référence `HEAD`. Elle ne doit donc pas être présentée comme une commande réussie.

Aucune correction de code nécessaire. Toutes les modifications locales existantes ont été conservées. La comparaison SHA-256 des diffs Git binaires avant et après les validations est identique. Les deux fichiers initialement non suivis sont conservés ; seul ce rapport est complété. Aucun reset, clean, stash, commit, push, tag, déploiement ou publication effectué. Aucune intervention sur les données Firebase distantes. La version reste **4.8.10+523** ; aucune montée de version n'a été effectuée dans cette reprise de validation.

### Commandes et résultats

Répertoire de travail : `C:/Users/b2osi/Documents/GitHub/Sks-familly`, sauf indication contraire. Les codes ci-dessous sont les codes natifs capturés par `$LASTEXITCODE`, et non le code du script PowerShell qui affiche les journaux.

| Commande | Code de sortie | Résultat exact | Journal |
| --- | ---: | --- | --- |
| `flutter --version` | 0 | Flutter 3.41.7, Dart 3.11.5 | `flutter-version.log` |
| `npx -y firebase-tools@latest --version` | 0 | Firebase CLI 15.30.1 | `firebase-version.log` |
| `flutter test --no-pub --reporter json` | 0 | 360 réussis, 0 échec, 0 ignoré | `flutter-tests.jsonl` |
| `npm test --prefix functions` | 0 | 81 réussis, 0 échec, 0 ignoré, 0 annulé, 0 todo | `node-tests.log` |
| `node --test tool/pwa_shell.test.cjs` | 0 | 4 réussis, 0 échec, 0 ignoré, 0 annulé, 0 todo | `pwa-tests.log` |
| `npm run test:rules` depuis `functions` | 0 | 93 réussis, 0 échec, 0 ignoré, 0 annulé, 0 todo | `firebase-rules.log` |
| `flutter analyze --no-pub` | 1 | 200 diagnostics : 0 erreur, 68 avertissements, 132 informations | `flutter-analyze.log` |
| `flutter analyze --no-pub` dans la copie temporaire de `HEAD` | 1 | Les mêmes 200 diagnostics ; 0 différence après neutralisation des numéros de ligne/colonne | `baseline-analyze.log` |
| `flutter build web --release --no-pub` | 0 | Build JavaScript réussi dans `build/web` | `web-build.log` |
| `git diff --check` | 0 | Aucune erreur d'espacement | `diff-check.log` |

Les 360 tests Flutter sont comptés à partir des événements JSON `testDone` avec `hidden == false` ; les événements internes de chargement ne sont pas comptés. L'événement final indique `success: true`.

### Firebase Emulator et Storage

Le script `test:rules` a réellement exécuté la commande suivante depuis `functions`, après `$env:JAVA_TOOL_OPTIONS='-Duser.language=en -Duser.country=US'` :

```powershell
npx -y firebase-tools@latest emulators:exec --only firestore,storage --project demo-sks-family "node --test --test-concurrency=1 family_inbox_emulator.test.js tribunal_emulator.test.js family_join_emulator.test.js family_ownership_emulator.test.js point_actions_emulator.test.js wallet_emulator.test.js firestore_rules.test.js wallet_rules.test.js storage_rules.test.js"
```

Firestore (édition Standard) et Storage ont démarré avec les règles du dépôt, sur les ports locaux 8080 et 9199. Les 93 tests incluent **8 tests Storage**, **15 tests point_actions_emulator** et les **70 autres tests**. Les contrôles Storage couvrent les preuves valides, les rôles autorisés/interdits, l'immuabilité après validation, les formats/noms/tailles invalides, l'isolation entre familles et les lectures des membres actifs. Tous passent. Les écritures et suppressions de préparation des tests concernent uniquement les données éphémères de `demo-sks-family` dans les émulateurs.

Les messages `PERMISSION_DENIED` correspondent aux refus attendus et vérifiés par les tests. Le CLI affiche aussi `Unexpected rules runtime error: Picked up JAVA_TOOL_OPTIONS...` lors de la prise en compte des options Java ; cela n'empêche ni le démarrage ni les 93 réussites. La commande se termine par `Script exited successfully (code 0)` et l'arrêt des deux émulateurs. Le signal `SIGINT` annoncé pour Firestore correspond à cet arrêt normal. L'envoi FCM du test de notification reste simulé.

### Analyse de référence et build Web

Référence : `b0ad7627e504f0322e160d4c392d69e3e31caefb`. Une archive de `HEAD` a été créée avec `git archive --format=zip --output="$vdir/baseline-head.zip" HEAD`, puis extraite avec `Expand-Archive` dans `baseline-head` sous le dossier de journaux. La configuration locale `.dart_tool/package_config.json` y a été copiée pour utiliser les mêmes dépendances. Aucun checkout ni remplacement de fichier du dépôt de travail. Les diagnostics ont été comparés par sévérité, message, chemin et règle, en ignorant uniquement les positions ligne/colonne : **0 différence**. La référence historique de 201 diagnostics figurant dans l'audit PWA est remplacée, pour cette comparaison, par cette mesure directe de `HEAD` à 200 diagnostics.

Le build produit notamment `build/web/main.dart.js` (**4 814 011 octets**) et `build/web/index.html` (**8 825 octets**). Trois signalements de compatibilité WebAssembly dans `flutter_tts-4.2.5` apparaissent lors du contrôle Wasm ; ils ne bloquent pas le build JavaScript demandé. Aucun avertissement n'a été masqué par une option supplémentaire. Les tests PWA utilisent un DOM simulé ; cette reprise ne constitue pas un essai sur un iPhone physique.

Journaux de cette reprise : `C:/Users/b2osi/AppData/Local/Temp/sks-verify-524-resume`. Les journaux de la session précédente restent dans `C:/Users/b2osi/AppData/Local/Temp/sks-verify-524`. Les anciens blocages d'accès au cache Pub et d'indisponibilité du CLI Firebase ne se reproduisent plus dans l'environnement actuel.

## Historique de la session précédente — conservé pour traçabilité

Les résultats incomplets et blocages décrits ci-dessous sont ceux de la session précédente ; les résultats de reprise ci-dessus font foi pour l'état actuel.

Validation incomplète : aucun commit, push, déploiement, tag ou Release. La version reste 4.8.10+523 tant que toutes les validations ne sont pas réussies. Les dix modifications initiales ont été conservées et complétées.

Les corrections autorisent les parents actifs à lire les demandes de rattachement et à recevoir leur notification. Les gestionnaires et familyAdmin doivent toujours avoir une identité vérifiée pour accéder aux demandes. Les clients ne peuvent ni créer, ni modifier, ni supprimer ces demandes directement.

Le masquage enregistre uniquement l’UID dans dismissedBy et une date de modification. Il ne refuse pas la demande et ne rembourse pas l’achat. Le cache local est isolé par famille et compte. Le filtrage intervient après fusion des données, au chargement de la liste affichée et lors de la restauration des achats. Le cache local de la notification est également retiré. Les textes dont l’encodage était corrompu ont été réparés.

| Vérification | Résultat de cette session |
| --- | --- |
| Node, suite habituelle | 81 réussis, 0 échec, 0 ignoré |
| PWA | 4 réussis, 0 échec, 0 ignoré |
| Firestore, suites indépendantes de Storage | 70 réussis, 0 échec, 0 ignoré |
| Rôles join_requests | Propriétaire, parent, gestionnaire vérifié, familyAdmin vérifié autorisés ; profils interdits refusés ; demandeur limité à sa propre demande ; écritures directes refusées |
| dismissFamilyNotification | Rejeu, appels concurrents, autorisations, identifiants invalides, document absent et limite de masquages vérifiés |
| Conservation métier | Demande toujours en attente ; achat, historique, portefeuille et demande de rattachement inchangés après masquage |
| Notification iPhone | Vrai déclencheur exécuté contre Firestore local ; parent actif et propriétaire ciblés ; envoi FCM simulé, aucun push réel |
| Réapparition côté Flutter | Chemins de restauration et cache corrigés ; confirmation dynamique complète encore bloquée |
| Storage et point_actions_emulator | Non validés : émulateur Storage indisponible ; les 15 tests point_actions échouent au prérequis FIREBASE_STORAGE_EMULATOR_HOST |
| Flutter | Tentative bloquée à la compilation par les accès refusés aux dépendances ; les 360 tests annoncés avant cette session ne sont pas reconfirmés |
| Analyse Flutter | Bloquée par les dépendances inaccessibles ; absence de nouveau diagnostic non confirmée |
| Build Web neuf | Tentative échouée, aucun build neuf validé |
| git diff --check | Réussi |

L’émulateur Firestore a utilisé uniquement demo-sks-family sur 127.0.0.1:8080, avec les règles du dépôt. Son erreur initiale de compilation liée à la langue Java a été résolue en lançant Java avec -Duser.language=en -Duser.country=US. Aucun assouplissement des règles n’a été nécessaire.

Les outils ont rencontré « Accès refusé » sous C:/Users/b2osi/AppData/Local/Pub/Cache/hosted/pub.dev : firebase_auth, provider, hive_flutter, test_api, flutter_lints et d’autres dépendances. Une copie du SDK Flutter dans le répertoire temporaire a permis de lancer les outils sans écrire dans le SDK installé, mais n’a pas rendu les dépendances accessibles. L’analyse a ainsi produit 1211 diagnostics non exploitables pour une comparaison de régression. La tentative de tests Flutter a été interrompue après répétition des erreurs de compilation ; aucun test n’a été désactivé ou modifié pour les masquer.

Firebase CLI n’est pas disponible dans le PATH ni dans le cache npm accessible. L’essai hors réseau renvoie ENOTCACHED. L’émulateur Storage nécessite cet outil ; le JAR de règles seul ne fournit pas son serveur HTTP. Aucun téléchargement réseau n’a été lancé pour résoudre ce blocage.

Les journaux de cette session sont hors dépôt, dans C:/Users/b2osi/AppData/Local/Temp/sks-verify-524 : firestore-final.log, inbox-emulator-final.log, node-tests.log, pwa-tests.log, flutter-tests.log, analyze-final.log, web-build.log et firebase-cli.log. Les journaux des essais précédents sont conservés dans ce même dossier.

Pour terminer : rendre le cache Pub accessible et disposer du CLI Firebase local, relancer toutes les suites Firestore/Storage (la commande test:rules inclut désormais family_inbox_emulator et tribunal_emulator), puis Flutter et PWA, comparer l’analyse à la référence et produire le build Web. Passer à 4.8.11+524 seulement après réussite complète. Aucun commit n’a été créé.

Évaluation de sécurité limitée aux règles join_requests modifiées, selon firebase-security-rules-auditor :

```json
{"score":5,"summary":"Les lectures utilisent les membres actifs cohérents et les identités vérifiées requises. Le demandeur ne lit que son propre document. Toutes les écritures clientes restent interdites. Audit limité aux règles join_requests modifiées, confirmé sur émulateur.","findings":[]}
```
