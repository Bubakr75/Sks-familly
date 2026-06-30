# AGENTS.md — Mémoire permanente du projet SKS Family

> Ce fichier est lu automatiquement par l'agent IA au démarrage de chaque session.
> Il contient TOUT le contexte critique du projet pour éviter les redécouvertes.

## 📋 Vue d'ensemble du projet

**SKS Family** (Family Score) — Application Flutter de gestion familiale de points,
récompenses et comportements des enfants.

- **Repo GitHub** : https://github.com/Bubakr75/Sks-familly
- **Langage** : Flutter / Dart (94%)
- **Backend** : Firebase (Firestore, Cloud Functions, Auth, Messaging)
- **Plateformes** : Android (principal) + Web (PWA pour iPhone)
- **Version actuelle** : 4.8.0+378
- **Package ID** : `com.bubakr.sks_family`
- **Projet Firebase** : `sks-familly-3f205` (région us-central1)

## 🏗️ Architecture

### Structure des dossiers
```
lib/
├── main.dart              → Démarrage non-bloquant (SKSBootstrap avec timeouts)
├── config/                → Thèmes (emerald_theme.dart) + configs
├── models/                → Modèles de données (child, goal, punishment, etc.)
├── providers/             → family_provider (état central), pin_provider, theme_provider
├── screens/               → 30+ écrans
├── services/              → auth, fcm, notification, voice, gemini, update, firestore
├── utils/                 → pin_guard, web_reconnect
└── widgets/               → Composants UI réutilisables
functions/
└── index.js               → Cloud Functions (notifications push)
```

### Stack technique
- **State management** : Provider (ChangeNotifier)
- **Base locale** : Hive (persistance offline)
- **Sync temps réel** : Firestore snapshots (12 listeners)
- **Auth** : Firebase Auth anonyme (chaque appareil se connecte automatiquement)
- **Notifications** : FCM (push) + flutter_local_notifications (programmées Android)
- **Voix** : flutter_tts (VoiceService)
- **Vidéo** : video_player (intro au démarrage)

## 🔑 Règles et conventions de code

### Style
- **Design** : Theme Emerald Premium (vert nuit #051410 + or #D4AF37 + crème)
- **Couleurs** : Utiliser EmeraldPalette (PAS de couleurs hardcodées quand possible)
- **API dépréciée** : Utiliser `.withValues(alpha: x)` (PAS `.withOpacity()`)
- **Commentaires** : En français
- **Emojis** : OK dans l'UI et les notifications (UTF-8 PROPRE)

### Patterns importants
- **Anti-écrasement** : `_markPending(id)` après chaque écriture locale (protection 30s)
- **Anti-dédoublement notifs** : `FcmService._localDeviceId` compare avec `sender` dans data
- **Demandes supprimées** : `_deletedRequestIds` filtre pendant 60s
- **Démarrage** : Chaque service a un timeout (jamais de blocage)
- **Notifications web** : `showOverlayOnly` (pas de double avec le service worker)

## 🔒 Sécurité (IMPORTANT)

### Authentification
- **Firebase Auth anonyme** activé (obligatoire pour Firestore)
- `AuthService.ensureConnected()` appelé après Firebase init, avant Firestore
- Règles Firestore : `allow if request.auth != null` (PAS de `if true`)

### Secrets (⚠️ À NE JAMAIS COMMITTER)
- `.gitignore` protège : service_account, keystore, key.properties, vapid_key, google-services
- **Clé Gemini** : via `--dart-define=GEMINI_API_KEY` (PAS en dur)
- ⚠️ ANCIENS SECRETS compromis dans l'historique git → doivent être révoqués

## 📱 Fonctionnalités principales

### Flux utilisateurs (tous validés ✅)
1. **Points** : addPoints → history → notif (anti-dédoublement)
2. **Punitions/Immunités** : addPunishment/addImmunity → déduction auto → notif
3. **Demandes enfants** : createRequest (mode enfant) → notif parent → badge cloche → PendingRequestsScreen → approve/reject
4. **Objectifs** : addGoal → toggleGoal (⚠️ pas de notif à l'atteinte)
5. **Badges** : débloqués auto via `_checkBadgeUnlock`
6. **Tribunal** : fileTribunalCase → votes → verdict → addPoints
7. **Ventes** : createTrade → accept → complete (transfert immunités)
8. **Temps d'écran** : calcul auto (notes école + comportement)
9. **Réinitialisation** : resetChildPoints / resetChildCompletely (menu parent)

### Cloud Functions (functions/index.js)
Triggers sur TOUTES les collections : children, history, punishments, immunities, trades, tribunal, **requests**, goals, notes, custom_badges.
- `sendToFamily(familyId, senderDeviceId, ...)` : exclut l'émetteur + inclut `sender` dans data
- ⚠️ Toujours déployer après modif : `firebase deploy --only functions`

### Navigation
- **Home** (bottom nav 5 onglets) : Dashboard(0), AddPoints(1), Calendar(2), Stats(3), Settings(4)
- **Drawer** : accès à toutes les fonctionnalités + Mode Parent/Enfant
- **Profils enfants** : ChildDashboardScreen (4 onglets : Profil, Écran, Historique, Badges)
- **PIN** : PinProvider, anti-brute-force (3 essais → lockout 2min), SHA-256 hashé

## 🧰 Outils & Commandes

### Build
```bash
# Web (PWA pour iPhone)
flutter build web --release

# Avec Gemini (clé API)
flutter build web --release --dart-define=GEMINI_API_KEY=TA_CLE

# Android APK
flutter build apk --release
```

### Déploiement Firebase
```bash
firebase deploy --only functions --project sks-familly-3f205
firebase deploy --only firestore:rules --project sks-familly-3f205
firebase deploy --only functions,firestore:rules --project sks-familly-3f205
```

### Test local
- **Serveur web** : Double-cliquer sur `Lancer-SKS-Family.bat` (dossier build/web)
- **URL** : http://127.0.0.1:8080

## ⚠️ Pièges connus

1. **Jamais déployer depuis `Documents\Sks-familly`** → ancien repo. Toujours depuis `ZCodeProject\Sks-familly`
2. **firestore.rules** : la collection s'appelle `requests` (PAS `pending_requests`)
3. **Photos base64** : risque de dépasser 1MB/document Firestore → envisager Firebase Storage
4. **Notifications multiples** : corrigé par `sender` dans data + `_localDeviceId`
5. **Profil parent disparu** : corrigé par persistance Hive (`_parentProfilesBox`)
6. **flutter_local_notifications** : ne marche PAS sur web → court-circuité par `kIsWeb`

## 📝 Notes de session

- L'utilisateur préfère le **design Emerald original** (a testé Aurora Verre mais est revenu)
- L'utilisateur travaille sur **Android** (pas de dev iOS, passe par le web PWA pour iPhone)
- L'utilisateur a les 4 serveurs MCP Z.AI configurés dans ZCode (vision, web-search, web-reader, zread)
- L'utilisateur veut de la **voix/son** dans l'app (TTS ajouté)
- L'utilisateur a une **vidéo d'intro** (assets/videos/intro.mp4)
