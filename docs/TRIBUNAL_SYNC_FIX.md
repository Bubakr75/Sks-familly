# Dépôt enfant et réception du tribunal — 17 septembre 2026

## Cause reproduite localement

Le formulaire annonçait un succès sans attendre `fileTribunalCase`. Le dépôt
enregistrait d’abord l’affaire localement, puis tentait une écriture directe
Firestore réservée aux parents. `saveTribunalCase` absorbait l’erreur.
En compte enfant, aucun document serveur n’était créé : le listener du parent
et le trigger de notification `onTribunalCreated` n’avaient rien à recevoir.
Ce mécanisme est reproduit avec les règles du dépôt et l’émulateur, sans accès
aux données familiales ou aux journaux des téléphones de production.

## Correctif

- Opération `tribunal_create` dans la callable existante `performFamilyOperation`.
- Membre actif obligatoire ; un enfant ne dépose qu’en son propre nom.
- Participants vérifiés dans la même famille ; état initial, votes et points
  construits par le serveur et non acceptés depuis le client.
- Création atomique avec identifiant stable : les nouvelles tentatives, même
  simultanées, ne créent pas une seconde affaire.
- Appareil émetteur vérifié avant son exclusion des notifications.
- Le trigger existant notifie les autres appareils ; pas de second envoi client.
- Formulaire bloqué pendant l’envoi, succès après confirmation seulement,
  message d’erreur et conservation du texte en cas d’échec.
- Règles Firestore et service worker Firebase Messaging inchangés.

## Vérifications

- 360 tests Flutter réussis, dont trois tests comportementaux du formulaire.
- 81 tests serveur réussis, dont l’appel au véritable handler de notification
  avec transport FCM simulé : parent destinataire, émetteur exclu.
- Test `functions/tribunal_emulator.test.js` réussi : deux dépôts concurrents
  donnent une seule affaire, lisible par parent et enfant ; écriture directe
  enfant, usurpation et lecture extérieure refusées. Les messages
  PERMISSION_DENIED de ce test sont attendus.
- Émulateur lancé avec `emulators:exec --only firestore --project demo-sks-family`
  puis `node --test functions/tribunal_emulator.test.js` depuis la racine.
- Analyse Flutter : zéro erreur, 68 warnings et 132 informations dans le projet.
  La commande n’est donc pas entièrement verte.
- Formatage Dart et `git diff --check` effectués.
- `flutter build web --release --pwa-strategy=none` réussi ; avertissements
  non bloquants sur l’option dépréciée et la compatibilité Wasm de flutter_tts.

## Mise en service

Correctif local uniquement. Publier `performFamilyOperation` avant les clients
qui utilisent `tribunal_create`. La réception réelle sur deux téléphones reste
à vérifier après publication, avec notifications autorisées et token valide.
Aucune publication, écriture de données de production ou récupération automatique
d’anciennes affaires locales n’a été effectuée. Les modifications antérieures,
y compris les corrections PWA, sont conservées.
