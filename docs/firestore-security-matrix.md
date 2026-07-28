# Matrice de sécurité Firestore

Audit local réalisé sans accès à Firebase. Le projet de tests est exclusivement
`demo-sks-family`.

`familyId` est porté par le chemin `families/{familyId}` pour toutes les
collections métier. Il n'est donc pas nécessaire de modifier les documents
existants. L'autorité vient uniquement de
`families/{familyId}/members/{request.auth.uid}` : le membre doit être actif,
son champ `uid` doit correspondre à l'utilisateur authentifié et son rôle doit
autoriser l'opération.

| Chemin | `familyId` | Lecture client | Écriture client | Requêtes Flutter principales |
|---|---|---|---|---|
| `families/{familyId}` | ID du document | Membre actif | Refusée, callable uniquement | `firestore_service.dart`: connexion ; ancien rattachement direct désormais bloqué |
| `children/{childId}` | Chemin | Membre actif | Parent/propriétaire | Listener, sauvegarde, suppression, transferts |
| `history/{entryId}` | Chemin | Membre actif | Parent/propriétaire | Listener, sauvegarde, purge par lots |
| `goals/{goalId}` | Chemin | Membre actif | Parent/propriétaire | Listener, sauvegarde, suppression |
| `punishments/{punishmentId}` | Chemin | Membre actif | Parent/propriétaire | Listener, sauvegarde, suppression |
| `notes/{noteId}` | Chemin | Membre actif | Parent/propriétaire | Listener, sauvegarde, suppression |
| `immunities/{immunityId}` | Chemin | Membre actif | Parent/propriétaire | Listener, sauvegarde, suppression |
| `trades/{tradeId}` | Chemin | Membre actif | Parent/propriétaire | Listener et remplacement complet |
| `tribunal/{caseId}` | Chemin | Membre actif | Parent/propriétaire | Listener et remplacement complet |
| `custom_badges/{badgeId}` | Chemin | Membre actif | Parent/propriétaire | Listener, sauvegarde, suppression |
| `screen_time/{key}` | Chemin | Membre actif | Parent/propriétaire | Listener et sauvegarde clé/valeur |
| `screen_time_accounts/{childId}` | Chemin | Membre actif | Parent/propriétaire | Lecture complète et remplacement du compte |
| `parent_profiles/{profileId}` | Chemin | Parent/propriétaire | Parent/propriétaire | Listener et sauvegarde ; contient les données de récupération |
| `requests/{requestId}` | Chemin | Membre actif | Parent, ou création `pending` par l'enfant rattaché au même `childId` | Listener complet, création et suppression |
| `chores/{choreId}` | Chemin | Membre actif | Parent/propriétaire | Listener, sauvegarde, suppression |
| `rewards/{rewardId}` | Chemin | Membre actif | Parent/propriétaire | Listener, sauvegarde et tombstone |
| `purchases/{purchaseId}` | Chemin | Membre actif | Parent/propriétaire | Listener et création |
| `wallets/{childId}` | Chemin | Parent, ou enfant rattaché à ce `childId` | Refusée, callable uniquement | Listener global parent ou document ciblé enfant |
| `wallets/{childId}/operations/{operationId}` | Chemin | Même portée que le wallet | Refusée, callable uniquement | Requête ordonnée par `createdAt` |
| `fcm_tokens/{deviceId}` | Chemin | Refusée | Membre actif, UID authentifié et `deviceId` cohérents | Enregistrement direct du token de l'appareil |
| `join_requests/{requestId}` | Chemin | Propriétaire réel | Refusée, callable uniquement | Requête `status == pending` |
| `members/{uid}` | Chemin | Propriétaire réel | Refusée, Firebase Admin uniquement | Aucun accès Flutter direct |
| `family_codes/{code}` | Champ `familyId` interne | Refusée | Refusée, Firebase Admin uniquement | Aucun accès Flutter direct |
| `join_rate_limits/{uid}` | Aucun | Refusée | Refusée, Firebase Admin uniquement | Aucun accès Flutter direct |
| `legacy_family_migration_claims/{familyId}` | ID du document | Refusée | Refusée, Firebase Admin uniquement | Callable de migration uniquement |
| `_diagnostic_test/{id}` | Aucun | Refusée | Refusée | Ancien diagnostic client volontairement bloqué |

## Collections bloquées pour les écritures enfant

- `purchases` : l'achat enfant modifie actuellement plusieurs documents
  (`children`, `history`, `immunities`, `requests`, `screen_time` et
  `purchases`) depuis Flutter. Migration nécessaire vers une callable
  transactionnelle validant le prix, le stock, le solde et le `childId`.
- `tribunal` : les votes sont intégrés dans le document complet. Migration
  nécessaire vers une callable transactionnelle ou une sous-collection
  `votes/{uid}`.
- `screen_time_accounts` : le solde, l'historique et la session sont réunis
  dans le même document. Migration nécessaire vers une callable ou une
  séparation entre compte protégé et session modifiable.
- `trades` : les actions enfant remplacent le document complet. Une callable
  transactionnelle ou des transitions strictes liées au `member.childId` sont
  nécessaires avant de réautoriser ces écritures.

Les familles historiques dépourvues de document `members/{uid}` actif restent
bloquées. Elles doivent passer par le mécanisme de migration existant ; aucune
règle de compatibilité permissive n'est ajoutée.
